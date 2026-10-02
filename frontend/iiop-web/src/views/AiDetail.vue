<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, reactive, ref } from 'vue';
import { onBeforeRouteLeave, useRoute, useRouter } from 'vue-router';
import { ElMessage, ElMessageBox } from 'element-plus';
import { request } from '../api/request';
import AiWorkflowVisualizer from '../components/AiWorkflowVisualizer.vue';
import WorkOrderCreateDialog from '../components/WorkOrderCreateDialog.vue';
import { useAuthStore } from '../stores/auth';
import type { Device, PageResult, UserSummary } from '../types/device';
import type { Defect, DiagnosisView, WorkflowTrace, WorkOrder } from '../types/maintenance';
import { displayValue } from '../utils/display';
import { notificationSocket, type ConnectionState, type NotificationMessage } from '../services/notificationSocket';

type AnyRecord = Record<string, unknown>;
type EvidenceCard = { title: string; state: string; rows: { label: string; value: string }[]; note?: string };

const route = useRoute();
const router = useRouter();
const auth = useAuthStore();
const view = ref<DiagnosisView>();
const trace = ref<WorkflowTrace[]>([]);
const device = ref<Device>();
const defect = ref<Defect>();
const workOrder = ref<WorkOrder>();
const confirmer = ref('未确认');
const loading = ref(false);
const errorMessage = ref('');
const busy = ref('');
const confirmVisible = ref(false);
const orderVisible = ref(false);
const technicalOpen = ref<string[]>([]);
const confirmForm = reactive({ decision: 'CONFIRMED' as 'CONFIRMED' | 'REJECTED', comment: '' });
const snapshot = ref('');
const connectionState = ref<ConnectionState>('disconnected');
let unsubscribeMessage: undefined | (() => void);
let unsubscribeState: undefined | (() => void);
let refreshTimer: number | undefined;
let lastConnection: ConnectionState = 'disconnected';
let connectedOnce = false;

const workflowCatalog = [
  { code: 'LOAD_CONTEXT', name: '数据汇聚', running: '正在汇聚设备与运维上下文' },
  { code: 'ANALYZE_WITH_DEEPSEEK', name: 'AI 智能研判', running: '正在进行 AI 智能研判' },
  { code: 'RISK_CHECK', name: '风险校验', running: '正在校验风险等级' },
  { code: 'GENERATE_ADVICE', name: '处置方案', running: '正在生成处置建议' },
  { code: 'PREPARE_WORK_ORDER_DRAFT', name: '工单草案', running: '正在准备维修工单草案' }
] as const;

const diagnosis = computed(() => view.value?.diagnosis);
const context = computed<AnyRecord>(() => asRecord(diagnosis.value?.contextSnapshot));
const deviceLabel = computed(() => device.value ? `${device.value.deviceName}（${device.value.deviceCode}）` : '设备信息加载中');
const dirty = computed(() => confirmVisible.value && JSON.stringify(confirmForm) !== snapshot.value);
const canDecide = computed(() => auth.can('ai:confirm') && diagnosis.value?.diagnosisStatus === 'SUCCEEDED' && diagnosis.value?.confirmationStatus === 'PENDING');
const canBind = computed(() => auth.can('maintenance:defect:process') && defect.value?.status === 'CONFIRMED' && diagnosis.value?.diagnosisStatus === 'SUCCEEDED' && diagnosis.value?.confirmationStatus === 'CONFIRMED' && defect.value.aiDiagnosisId !== diagnosis.value.id);
const canCreate = computed(() => auth.can('maintenance:workorder:create') && diagnosis.value?.diagnosisStatus === 'SUCCEEDED' && diagnosis.value?.confirmationStatus === 'CONFIRMED' && Boolean(view.value?.workOrderDraft) && !workOrder.value && (!defect.value || defect.value.aiDiagnosisId === diagnosis.value.id));
const completedCount = computed(() => trace.value.filter((item) => item.status === 'SUCCEEDED').length);
const currentStep = computed(() => {
  const item = trace.value.find((row) => row.status === 'RUNNING') ?? trace.value.find((row) => row.status === 'FAILED');
  return workflowCatalog.find((step) => step.code === item?.nodeCode);
});
const missingKeys = computed(() => Array.isArray(context.value.missingItems) ? context.value.missingItems.map(String) : []);
const trigger = computed(() => asRecord(context.value.trigger));
const deviceSnapshot = computed(() => asRecord(asRecord(context.value.device).device));
const sopSnapshot = computed(() => asRecord(context.value.sop));
const inspectionSnapshot = computed(() => asRecord(context.value.inspectionHistory));
const maintenanceSnapshot = computed(() => asRecord(context.value.maintenanceHistory));
const sops = computed(() => asArray(sopSnapshot.value.sops));
const inspectionTasks = computed(() => asArray(inspectionSnapshot.value.tasks));
const inspectionAbnormals = computed(() => asArray(inspectionSnapshot.value.abnormals));
const maintenanceOrders = computed(() => asArray(maintenanceSnapshot.value.workOrders));
const maintenanceRecords = computed(() => asArray(maintenanceSnapshot.value.records));

const heroTitle = computed(() => {
  if (diagnosis.value?.diagnosisStatus === 'FAILED') return '智能诊断未完成';
  if (diagnosis.value?.diagnosisStatus === 'SUCCEEDED') return '智能诊断已完成';
  return 'AI 正在执行智能诊断';
});
const heroSubtitle = computed(() => {
  if (diagnosis.value?.diagnosisStatus === 'FAILED') return currentStep.value ? `未能完成：${currentStep.value.name}` : '诊断任务未能完成';
  if (diagnosis.value?.diagnosisStatus === 'SUCCEEDED') return diagnosis.value.confirmationStatus === 'PENDING' ? '诊断报告已生成，等待人工审核' : '诊断报告与人工结论均已记录';
  return currentStep.value?.running ?? '正在准备诊断上下文';
});
const sourceLabel = computed(() => diagnosis.value ? displayValue(diagnosis.value.triggerType) : '-');
const riskClass = computed(() => `risk-${(diagnosis.value?.riskLevel || 'unknown').toLowerCase()}`);
const failedReason = computed(() => friendlyError(diagnosis.value?.errorMessage));

const completeness = computed(() => [
  { label: '设备信息', loaded: Boolean(context.value.device), unavailable: false },
  { label: 'SOP 标准', loaded: Boolean(context.value.sop), unavailable: false },
  { label: '巡检历史', loaded: Boolean(context.value.inspectionHistory) && !missingKeys.value.includes('inspectionHistory'), unavailable: missingKeys.value.includes('inspectionHistory') },
  { label: '维修历史', loaded: Boolean(context.value.maintenanceHistory) && !missingKeys.value.includes('maintenanceHistory'), unavailable: missingKeys.value.includes('maintenanceHistory') },
  { label: '异常来源', loaded: diagnosis.value?.triggerType === 'MANUAL' ? Boolean(diagnosis.value?.abnormalSummary) : Boolean(context.value.trigger), unavailable: false }
]);

const evidenceCards = computed<EvidenceCard[]>(() => {
  const snapshotDevice = deviceSnapshot.value;
  const triggerTitle = text(trigger.value.title) || diagnosis.value?.abnormalSummary || '-';
  const triggerDescription = text(trigger.value.description) || text(trigger.value.content) || diagnosis.value?.userDescription || '';
  return [
    { title: '设备状态', state: context.value.device ? '已读取' : '待加载', rows: [
      { label: '设备', value: text(snapshotDevice.deviceName) || device.value?.deviceName || '-' },
      { label: '编码', value: text(snapshotDevice.deviceCode) || device.value?.deviceCode || '-' },
      { label: '当前状态', value: displayValue(text(snapshotDevice.status) || device.value?.status || '-') },
      { label: '安装位置', value: [text(snapshotDevice.workshop), text(snapshotDevice.installLocation)].filter(Boolean).join(' · ') || device.value?.installLocation || '-' }
    ] },
    { title: '异常来源', state: sourceLabel.value, rows: [
      { label: '异常摘要', value: triggerTitle },
      { label: '严重程度', value: displayValue(text(trigger.value.severity) || text(trigger.value.alarmLevel) || text(context.value.triggerRisk) || diagnosis.value?.riskLevel || '-') }
    ], note: triggerDescription },
    { title: '巡检记录', state: missingKeys.value.includes('inspectionHistory') ? '暂不可用' : '已读取', rows: [
      { label: '近期任务', value: `${inspectionTasks.value.length} 条` }, { label: '异常记录', value: `${inspectionAbnormals.value.length} 条` }
    ] },
    { title: '维修记录', state: missingKeys.value.includes('maintenanceHistory') ? '暂不可用' : '已读取', rows: [
      { label: '历史工单', value: `${maintenanceOrders.value.length} 条` }, { label: '维修记录', value: `${maintenanceRecords.value.length} 条` }
    ] },
    { title: 'SOP / 标准依据', state: context.value.sop ? '已读取' : '待加载', rows: [{ label: '有效标准', value: `${sops.value.length} 项` }], note: sops.value.slice(0, 2).map((item) => text(asRecord(item).title)).filter(Boolean).join('；') }
  ];
});

const workflowSummaries = computed<Record<string, string[]>>(() => ({
  LOAD_CONTEXT: completeness.value.map((item) => `${item.label}：${item.loaded ? '已加载' : item.unavailable ? '暂不可用' : '等待加载'}`),
  ANALYZE_WITH_DEEPSEEK: [diagnosis.value?.abnormalSummary ? '已生成诊断摘要' : '诊断摘要等待生成', `识别到 ${view.value?.possibleCauses.length ?? 0} 个可能原因`],
  RISK_CHECK: [`业务原始风险：${displayValue(text(context.value.triggerRisk) || '-')}`, `AI 辅助判断：${displayValue(diagnosis.value?.riskLevel || '-')}`],
  GENERATE_ADVICE: [`已形成 ${view.value?.investigationSteps.length ?? 0} 项排查建议`, diagnosis.value?.safetyNotice ? '已生成安全提示' : '安全提示等待生成'],
  PREPARE_WORK_ORDER_DRAFT: view.value?.workOrderDraft ? [`建议标题：${view.value.workOrderDraft.title}`, `建议优先级：${displayValue(view.value.workOrderDraft.priority)}`] : ['工单草案等待生成']
}));

const decisionStage = computed(() => {
  if (workOrder.value) return 3;
  if (diagnosis.value?.diagnosisStatus !== 'SUCCEEDED') return 0;
  if (diagnosis.value.confirmationStatus !== 'CONFIRMED') return 1;
  if (diagnosis.value.triggerType !== 'MANUAL' && defect.value?.aiDiagnosisId !== diagnosis.value.id) return 2;
  return 3;
});
const decisionStages = ['AI 分析', '人工审核', '缺陷关联', '维修工单'];
const nextAction = computed(() => {
  const d = diagnosis.value;
  if (!d) return { title: '等待诊断数据', description: '正在加载当前任务。', action: '', label: '' };
  if (d.diagnosisStatus === 'FAILED') return { title: '重新发起诊断', description: '本次任务不会被改写，可返回诊断中心发起一条新任务。', action: 'retry', label: '返回中心重新发起' };
  if (d.diagnosisStatus !== 'SUCCEEDED') return { title: '等待 AI 完成分析', description: '任务仍在后台执行，实时连接中断不会改变任务结果。', action: '', label: '' };
  if (d.confirmationStatus === 'REJECTED') return { title: '该诊断已拒绝', description: d.confirmationComment || '该报告不能用于创建正式维修工单。', action: '', label: '' };
  if (d.confirmationStatus === 'PENDING') return canDecide.value ? { title: '等待人工审核', description: '请核对诊断依据、风险判断和处置建议后作出决定。', action: 'review', label: '审核 AI 诊断' } : { title: '等待有权限人员审核', description: '当前账号没有诊断确认权限。', action: '', label: '' };
  if (workOrder.value) return { title: '正式工单已创建', description: `${workOrder.value.workOrderCode} · ${displayValue(workOrder.value.status)}`, action: 'workorder', label: '查看维修工单' };
  if (defect.value && defect.value.aiDiagnosisId !== d.id) return canBind.value ? { title: '关联来源缺陷', description: '确认诊断与来源缺陷的关系后，才能进入工单创建。', action: 'bind', label: '绑定来源缺陷' } : { title: '等待缺陷关联', description: '需要具备缺陷处理权限，且来源缺陷处于可绑定状态。', action: '', label: '' };
  if (canCreate.value) return { title: '创建正式维修工单', description: '草案不会自动落单，请核对后显式创建正式工单。', action: 'create', label: '创建维修工单' };
  return { title: '等待创建维修工单', description: auth.can('maintenance:workorder:create') ? '当前业务条件尚未满足。' : '当前账号没有工单创建权限。', action: '', label: '' };
});

function asRecord(value: unknown): AnyRecord { return value && typeof value === 'object' && !Array.isArray(value) ? value as AnyRecord : {}; }
function asArray(value: unknown): unknown[] { return Array.isArray(value) ? value : []; }
function text(value: unknown): string { return value == null ? '' : String(value); }
function friendlyError(value: unknown): string {
  const raw = text(value).trim();
  if (!raw) return '智能分析服务未能完成本次任务，请稍后重新发起。';
  if (/timeout|timed out|超时/i.test(raw)) return '智能分析等待超时，本次任务已安全终止。';
  if (/connect|connection|refused|unavailable|503|网络/i.test(raw)) return '智能分析服务暂时不可用，请稍后重新发起。';
  if (/context|device|设备上下文|设备信息/i.test(raw)) return '设备业务上下文读取不完整，无法继续诊断。';
  if (/exception|\bat\b|\.java:|org\.|com\.|stack|trace/i.test(raw)) return '智能分析执行异常，本次任务未生成可用结论。';
  return raw.length > 120 ? `${raw.slice(0, 120)}…` : raw;
}
const dateTime = (value: string | null | undefined) => value ? value.replace('T', ' ').slice(0, 19) : '-';
function scheduleRefresh() { if (refreshTimer) window.clearTimeout(refreshTimer); if (['RUNNING', 'PENDING'].includes(diagnosis.value?.diagnosisStatus ?? '')) refreshTimer = window.setTimeout(() => void load(true), 5000); }

async function load(background = false) {
  if (loading.value) return;
  if (!background) loading.value = true;
  errorMessage.value = '';
  try {
    const id = String(route.params.id);
    const [result, workflow] = await Promise.all([request.get<never, DiagnosisView>(`/api/ai/diagnoses/${id}`), request.get<never, WorkflowTrace[]>(`/api/ai/diagnoses/${id}/workflow`)]);
    view.value = result;
    trace.value = workflow ?? [];
    defect.value = undefined;
    workOrder.value = undefined;
    const d = result.diagnosis;
    const jobs: Promise<unknown>[] = [request.get<never, Device>(`/api/device/devices/${d.deviceId}`).then((item) => device.value = item)];
    if (auth.can('maintenance:view')) {
      if (d.triggerType !== 'MANUAL' && d.triggerId) jobs.push(request.get<never, PageResult<Defect>>('/api/maintenance/defects', { params: { sourceType: d.triggerType, sourceId: d.triggerId, pageNum: 1, pageSize: 2 } }).then((page) => defect.value = page.records?.[0]));
      jobs.push(request.get<never, PageResult<WorkOrder>>('/api/maintenance/work-orders', { params: { aiDiagnosisId: d.id, pageNum: 1, pageSize: 2 } }).then((page) => workOrder.value = page.records?.[0]));
    }
    if (d.confirmedBy && auth.can('system:user:view')) jobs.push(request.get<never, UserSummary>(`/api/auth/users/${d.confirmedBy}`, { silentStatuses: [404] }).then((user) => confirmer.value = user.realName ? `${user.realName}（${user.username}）` : user.username).catch((error: any) => confirmer.value = error.response?.status === 404 ? '原确认人（账号已删除）' : '人员信息暂不可用'));
    await Promise.allSettled(jobs);
  } catch { errorMessage.value = '智能诊断报告加载失败，可能无权访问或服务暂不可用。'; }
  finally { loading.value = false; scheduleRefresh(); }
}

function onWorkflowEvent(message: NotificationMessage) { if (message.notificationType === 'AI_WORKFLOW' && message.bizType === 'AI_DIAGNOSIS' && message.bizId === String(route.params.id)) void load(true); }
function openDecision() { Object.assign(confirmForm, { decision: 'CONFIRMED', comment: '' }); snapshot.value = JSON.stringify(confirmForm); confirmVisible.value = true; }
async function closeDecision() { if (dirty.value) { try { await ElMessageBox.confirm('审核意见尚未提交，确定放弃吗？', '放弃审核', { type: 'warning' }); } catch { return; } } confirmVisible.value = false; }
async function decide() { if (!diagnosis.value) return; if (confirmForm.decision === 'REJECTED' && !confirmForm.comment.trim()) return void ElMessage.warning('拒绝时必须填写原因'); busy.value = 'decision'; try { await request.post(`/api/ai/diagnoses/${diagnosis.value.id}/${confirmForm.decision === 'CONFIRMED' ? 'confirm' : 'reject'}`, { comment: confirmForm.comment }); confirmVisible.value = false; ElMessage.success(confirmForm.decision === 'CONFIRMED' ? '诊断已确认' : '诊断已拒绝'); await load(); } catch (error: any) { if (error.response?.status === 409) await load(); } finally { busy.value = ''; } }
async function bind() { if (!diagnosis.value || !defect.value) return; busy.value = 'bind'; try { await request.put(`/api/maintenance/defects/${defect.value.id}/ai-diagnosis`, { aiDiagnosisId: diagnosis.value.id }); ElMessage.success('诊断已绑定到来源缺陷'); await load(); } finally { busy.value = ''; } }
function runNextAction() { if (nextAction.value.action === 'review') openDecision(); else if (nextAction.value.action === 'bind') void bind(); else if (nextAction.value.action === 'create') orderVisible.value = true; else if (nextAction.value.action === 'workorder' && workOrder.value) void router.push(`/maintenance/work-orders/${workOrder.value.id}`); else if (nextAction.value.action === 'retry' && diagnosis.value) void router.push({ path: '/ai/diagnoses', query: { deviceId: diagnosis.value.deviceId } }); }
function created(order: WorkOrder) { workOrder.value = order; void router.push(`/maintenance/work-orders/${order.id}`); }

onBeforeRouteLeave(async () => { if (!dirty.value) return true; try { await ElMessageBox.confirm('审核意见尚未提交，确定离开吗？', '离开页面', { type: 'warning' }); return true; } catch { return false; } });
onMounted(() => {
  unsubscribeMessage = notificationSocket.subscribe(onWorkflowEvent);
  unsubscribeState = notificationSocket.subscribeState((state) => {
    connectionState.value = state;
    if (state === 'connected') {
      if (connectedOnce && lastConnection === 'disconnected') ElMessage.success('实时状态已恢复');
      connectedOnce = true;
      if (lastConnection === 'disconnected') void load(true);
    }
    lastConnection = state;
  });
  void load();
});
onBeforeUnmount(() => { unsubscribeMessage?.(); unsubscribeState?.(); if (refreshTimer) window.clearTimeout(refreshTimer); });
</script>

<template>
  <section class="diagnosis-workbench" v-loading="loading && !diagnosis">
    <button class="back-link" type="button" @click="router.push('/ai/diagnoses')">← 返回智能诊断中心</button>
    <el-alert v-if="errorMessage" :title="errorMessage" type="error" show-icon :closable="false"><template #default><el-button link @click="load()">重新加载</el-button></template></el-alert>
    <template v-else-if="diagnosis && view">
      <header class="diagnosis-hero" :class="[{ running: ['RUNNING', 'PENDING'].includes(diagnosis.diagnosisStatus), failed: diagnosis.diagnosisStatus === 'FAILED' }, riskClass]">
        <div class="hero-glow"></div>
        <div class="hero-main">
          <div class="hero-kicker"><span class="ai-orb">AI</span><span>INDUSTRIAL INTELLIGENCE</span></div>
          <h1>{{ heroTitle }}</h1><p class="hero-subtitle">{{ heroSubtitle }}</p>
          <div v-if="['RUNNING', 'PENDING'].includes(diagnosis.diagnosisStatus)" class="real-progress"><span></span><strong>已完成 {{ completedCount }} / 5</strong><small>基于真实步骤状态</small></div>
          <div v-else-if="diagnosis.diagnosisStatus === 'SUCCEEDED'" class="hero-summary">{{ diagnosis.abnormalSummary || '诊断结论已生成' }}</div>
          <div v-else class="hero-summary failure-summary"><strong>{{ currentStep ? `失败阶段：${currentStep.name}` : '任务执行未完成' }}</strong><span>{{ failedReason }}</span></div>
        </div>
        <div class="hero-device"><span>分析对象</span><strong>{{ device?.deviceName || '设备信息加载中' }}</strong><code>{{ device?.deviceCode || '-' }}</code><button type="button" @click="router.push(`/devices/${diagnosis.deviceId}`)">查看设备档案 →</button></div>
        <dl class="hero-metrics">
          <div><dt>异常来源</dt><dd>{{ sourceLabel }}</dd></div><div><dt>AI 当前状态</dt><dd>{{ displayValue(diagnosis.diagnosisStatus) }}</dd></div><div><dt>风险等级</dt><dd class="risk-value">{{ displayValue(diagnosis.riskLevel) }}</dd></div><div><dt>诊断时间</dt><dd>{{ dateTime(diagnosis.createdAt) }}</dd></div><div><dt>人工状态</dt><dd>{{ displayValue(diagnosis.confirmationStatus) }}</dd></div><div><dt>当前下一步</dt><dd>{{ nextAction.title }}</dd></div>
        </dl>
      </header>
      <div v-if="['RUNNING', 'PENDING'].includes(diagnosis.diagnosisStatus) && connectionState !== 'connected'" class="recovery-notice">实时更新暂时中断，诊断仍在后台继续；页面将通过查询恢复真实状态。</div>
      <AiWorkflowVisualizer :trace="trace" :summaries="workflowSummaries" />
      <div class="workspace-grid">
        <main class="report-column">
          <section class="report-section conclusion-section">
            <div class="section-heading"><div><span class="eyebrow">AI DIAGNOSIS</span><h2>智能诊断结论</h2></div><span class="assist-label">AI 辅助判断</span></div>
            <div class="risk-conclusion"><div><span>AI 风险判断</span><strong>{{ displayValue(diagnosis.riskLevel) }}</strong></div><p>{{ diagnosis.abnormalSummary || '尚未生成诊断摘要。' }}</p></div>
            <div v-if="view.investigationSteps.length" class="priority-direction"><strong>建议优先处理方向</strong><p>{{ view.investigationSteps[0] }}</p></div>
          </section>
          <section class="report-section">
            <div class="section-heading"><div><span class="eyebrow">POSSIBLE CAUSES</span><h2>AI 推测原因</h2></div><span class="section-note">推测不等于业务事实</span></div>
            <div v-if="view.possibleCauses.length" class="cause-list"><article v-for="(item, index) in view.possibleCauses" :key="item"><span>{{ String(index + 1).padStart(2, '0') }}</span><div><small>AI 推测</small><p>{{ item }}</p></div></article></div><el-empty v-else description="暂无可能原因" :image-size="72" />
          </section>
          <section class="report-section">
            <div class="section-heading"><div><span class="eyebrow">INVESTIGATION</span><h2>智能排查路径</h2></div><span class="section-note">建议路径，不记录完成状态</span></div>
            <div v-if="view.investigationSteps.length" class="investigation-list"><div v-for="(item, index) in view.investigationSteps" :key="item"><span>{{ String(index + 1).padStart(2, '0') }}</span><p>{{ item }}</p></div></div><el-empty v-else description="暂无排查建议" :image-size="72" />
          </section>
          <div class="recommendation-grid">
            <section class="recommendation-card" :class="{ full: !diagnosis.safetyNotice }"><span class="card-icon">策</span><div><small>AI 辅助建议</small><h2>AI 维修建议</h2><p>{{ diagnosis.maintenanceAdvice || '暂无维修建议。' }}</p><div class="advice-meta"><span>优先级：{{ displayValue(view.workOrderDraft?.priority || diagnosis.riskLevel) }}</span><span>维修方向：以现场核验结果为准</span></div></div></section>
            <section v-if="diagnosis.safetyNotice" class="safety-card"><span class="card-icon">!</span><div><small>工业作业警示</small><h2>安全注意事项</h2><p>{{ diagnosis.safetyNotice }}</p></div></section>
          </div>
        </main>
        <aside class="side-column">
          <section class="side-panel evidence-panel">
            <div class="section-heading"><div><span class="eyebrow">BUSINESS EVIDENCE</span><h2>业务证据</h2></div></div>
            <article v-for="card in evidenceCards" :key="card.title" class="evidence-card"><header><strong>{{ card.title }}</strong><span>{{ card.state }}</span></header><dl><div v-for="row in card.rows" :key="row.label"><dt>{{ row.label }}</dt><dd>{{ row.value }}</dd></div></dl><p v-if="card.note">{{ card.note }}</p></article>
          </section>
          <section class="side-panel completeness-panel">
            <div class="section-heading"><div><span class="eyebrow">CONTEXT</span><h2>诊断数据完整性</h2></div></div>
            <ul><li v-for="item in completeness" :key="item.label" :class="{ missing: !item.loaded }"><span>{{ item.loaded ? '✓' : '!' }}</span><strong>{{ item.label }}</strong><small>{{ item.loaded ? '已加载' : item.unavailable ? '暂不可用' : '等待加载' }}</small></li></ul>
          </section>
          <section class="side-panel next-panel">
            <span class="eyebrow">NEXT ACTION</span><h2>{{ nextAction.title }}</h2><p>{{ nextAction.description }}</p><el-button v-if="nextAction.action" type="primary" size="large" :loading="busy === 'bind'" @click="runNextAction">{{ nextAction.label }}</el-button>
            <div class="decision-path"><strong>AI 决策闭环</strong><div><template v-for="(stage, index) in decisionStages" :key="stage"><span :class="{ active: index === decisionStage, done: index < decisionStage }">{{ stage }}</span><i v-if="index < decisionStages.length - 1">→</i></template></div></div>
          </section>
        </aside>
      </div>
      <section class="draft-section">
        <div class="section-heading"><div><span class="eyebrow">WORK ORDER DRAFT</span><h2>维修工单草案</h2></div><span class="section-note">仅供人工核对，不会自动创建</span></div>
        <div v-if="view.workOrderDraft" class="draft-grid"><div><span>建议标题</span><strong>{{ view.workOrderDraft.title || '-' }}</strong></div><div><span>建议优先级</span><strong>{{ displayValue(view.workOrderDraft.priority) }}</strong></div><div class="wide"><span>建议描述</span><p>{{ view.workOrderDraft.description || '-' }}</p></div><div class="wide"><span>维修建议</span><p>{{ view.workOrderDraft.maintenanceAdvice || '-' }}</p></div><div class="wide safety-line"><span>安全注意事项</span><p>{{ view.workOrderDraft.safetyNotice || '-' }}</p></div></div><el-empty v-else description="工作流尚未生成工单草案" :image-size="72" />
      </section>
      <section v-if="auth.can('maintenance:view')" class="relations-section">
        <article><span>关联缺陷</span><template v-if="defect"><h3>{{ defect.defectCode }}</h3><p>{{ defect.title }}</p><div><el-tag>{{ displayValue(defect.status) }}</el-tag><el-tag v-if="defect.aiDiagnosisId === diagnosis.id" type="success">已关联本诊断</el-tag><el-button link @click="router.push(`/maintenance/defects/${defect.id}`)">查看缺陷 →</el-button></div></template><p v-else class="empty-copy">该诊断没有来源缺陷</p></article>
        <article><span>关联维修工单</span><template v-if="workOrder"><h3>{{ workOrder.workOrderCode }}</h3><p>{{ workOrder.title }}</p><div><el-tag>{{ displayValue(workOrder.status) }}</el-tag><el-button link @click="router.push(`/maintenance/work-orders/${workOrder.id}`)">查看工单 →</el-button></div></template><p v-else class="empty-copy">尚未创建正式维修工单</p></article>
      </section>
       <el-collapse v-model="technicalOpen" class="technical-collapse"><el-collapse-item name="technical"><template #title><strong>诊断技术信息</strong><span>默认收起</span></template><dl class="technical-grid"><div><dt>诊断编号</dt><dd>{{ diagnosis.diagnosisCode }}</dd></div><div><dt>模型名称</dt><dd>{{ diagnosis.modelName || '-' }}</dd></div><div><dt>提示版本</dt><dd>{{ diagnosis.promptVersion || '-' }}</dd></div><div><dt>创建时间</dt><dd>{{ dateTime(diagnosis.createdAt) }}</dd></div><div><dt>任务状态</dt><dd>{{ displayValue(diagnosis.diagnosisStatus) }}</dd></div><div><dt>实时连接</dt><dd>{{ connectionState === 'connected' ? '已连接' : connectionState === 'connecting' ? '连接中' : '已断开（查询恢复启用）' }}</dd></div><div><dt>审核人员</dt><dd>{{ diagnosis.confirmedBy ? confirmer : '待人工审核' }}</dd></div><div v-if="diagnosis.confirmationComment" class="wide"><dt>审核意见</dt><dd>{{ diagnosis.confirmationComment }}</dd></div><div v-if="diagnosis.errorMessage" class="wide"><dt>失败说明</dt><dd>{{ failedReason }}</dd></div><div class="wide"><dt>节点耗时明细</dt><dd class="timing-list"><span v-for="item in trace" :key="item.id"><b>{{ item.nodeName }}</b>{{ item.duration == null ? '—' : item.duration < 1000 ? `${item.duration} ms` : `${(item.duration / 1000).toFixed(1)} s` }}</span></dd></div></dl></el-collapse-item></el-collapse>
    </template>
    <el-dialog v-model="confirmVisible" title="审核 AI 诊断" width="680px" :close-on-click-modal="false" :before-close="closeDecision"><p class="review-intro">请基于业务证据和现场判断作出人工决定。确认不会自动创建维修工单。</p><div v-if="diagnosis" class="review-summary"><div><span>AI 风险结论</span><strong>{{ displayValue(diagnosis.riskLevel) }}</strong></div><div><span>异常摘要</span><p>{{ diagnosis.abnormalSummary || '-' }}</p></div><div><span>建议维修方向</span><p>{{ diagnosis.maintenanceAdvice || '-' }}</p></div><div v-if="diagnosis.safetyNotice" class="review-warning"><span>安全注意事项</span><p>{{ diagnosis.safetyNotice }}</p></div></div><el-radio-group v-model="confirmForm.decision" class="decision-options"><el-radio-button value="CONFIRMED">确认诊断</el-radio-button><el-radio-button value="REJECTED">拒绝诊断</el-radio-button></el-radio-group><el-form label-width="88px" class="dialog-form"><el-form-item label="审核意见" :required="confirmForm.decision === 'REJECTED'"><el-input v-model="confirmForm.comment" type="textarea" :rows="4" :placeholder="confirmForm.decision === 'REJECTED' ? '请填写拒绝原因' : '可填写现场核对依据'" /></el-form-item></el-form><template #footer><el-button @click="closeDecision">取消</el-button><el-button :type="confirmForm.decision === 'CONFIRMED' ? 'primary' : 'danger'" :loading="busy === 'decision'" @click="decide">{{ confirmForm.decision === 'CONFIRMED' ? '确认诊断' : '拒绝诊断' }}</el-button></template></el-dialog>
    <WorkOrderCreateDialog v-if="diagnosis" v-model:visible="orderVisible" :device-id="diagnosis.deviceId" :device-label="deviceLabel" :defect-id="defect?.id" :ai-diagnosis-id="diagnosis.id" :draft="view?.workOrderDraft" @created="created" />
  </section>
</template>

<style scoped>
.diagnosis-workbench{display:flex;flex-direction:column;gap:18px;color:#273540}.back-link{align-self:flex-start;padding:0;border:0;background:transparent;color:#547286;cursor:pointer}.diagnosis-hero{position:relative;display:grid;grid-template-columns:minmax(0,1.45fr) minmax(230px,.55fr);gap:24px;overflow:hidden;padding:34px;border:1px solid #273e50;border-radius:16px;background:linear-gradient(125deg,#0f1922 0%,#172b3a 58%,#183546 100%);box-shadow:0 18px 42px rgba(12,31,45,.18);color:#edf8fb}.hero-glow{position:absolute;right:5%;top:-120px;width:370px;height:260px;border-radius:50%;background:radial-gradient(circle,rgba(45,194,214,.22),transparent 68%);pointer-events:none}.diagnosis-hero.running .hero-glow{animation:hero-breathe 3s ease-in-out infinite}.diagnosis-hero.failed{background:linear-gradient(125deg,#211719,#2d2023 58%,#34252a)}.hero-main,.hero-device,.hero-metrics{position:relative;z-index:1}.hero-kicker{display:flex;align-items:center;gap:10px;color:#75cfda;font-size:11px;font-weight:700;letter-spacing:.16em}.ai-orb{display:grid;width:31px;height:31px;place-items:center;border:1px solid #49c1d0;border-radius:50%;background:rgba(61,204,224,.1);letter-spacing:0}.diagnosis-hero h1{margin:18px 0 6px;font-size:32px;letter-spacing:.02em}.hero-subtitle{margin:0;color:#a9c1cc;font-size:16px}.real-progress{display:flex;align-items:center;gap:10px;margin-top:22px}.real-progress>span{width:9px;height:9px;border-radius:50%;background:#48d1df;box-shadow:0 0 0 6px rgba(72,209,223,.12);animation:status-pulse 1.7s infinite}.real-progress strong{font-size:14px}.real-progress small{color:#718c9a}.hero-summary{max-width:720px;margin-top:20px;color:#c8dbe2;font-size:14px;line-height:1.65}.hero-device{align-self:center;padding:20px;border:1px solid rgba(127,190,207,.2);border-radius:12px;background:rgba(7,20,28,.32)}.hero-device span,.hero-device code{display:block;color:#7795a5;font-size:11px}.hero-device strong{display:block;margin:7px 0 3px;font-size:20px}.hero-device code{font-family:inherit;letter-spacing:.08em}.hero-device button{margin-top:18px;padding:0;border:0;background:transparent;color:#65d3e1;cursor:pointer}.hero-metrics{grid-column:1/-1;display:grid;grid-template-columns:repeat(6,minmax(0,1fr));margin:8px -34px -34px;padding:19px 34px;background:rgba(5,14,20,.34)}.hero-metrics div{padding:0 17px;border-left:1px solid rgba(138,179,194,.16)}.hero-metrics div:first-child{padding-left:0;border-left:0}.hero-metrics dt{color:#718d9b;font-size:11px}.hero-metrics dd{margin:6px 0 0;color:#e3f1f4;font-size:13px;font-weight:600}.risk-high .risk-value,.risk-critical .risk-value{color:#ff9b83}.risk-medium .risk-value{color:#f0c26e}.risk-low .risk-value{color:#79d5a6}.recovery-notice{padding:12px 16px;border:1px solid #e6c47a;border-radius:9px;background:#fff9e9;color:#8b6519;font-size:13px}.workspace-grid{display:grid;grid-template-columns:minmax(0,2fr) minmax(300px,1fr);gap:18px}.report-column,.side-column{display:flex;flex-direction:column;gap:18px}.report-section,.side-panel,.draft-section,.relations-section article{border:1px solid #dce4e9;border-radius:13px;background:#fff;box-shadow:0 8px 24px rgba(19,48,67,.05)}.report-section,.side-panel,.draft-section{padding:24px}.section-heading{display:flex;align-items:flex-end;justify-content:space-between;gap:16px}.section-heading h2{margin:4px 0 0;font-size:20px;color:#1f313d}.eyebrow{color:#278da0;font-size:10px;font-weight:800;letter-spacing:.16em}.assist-label,.section-note{color:#71828d;font-size:12px}.assist-label{padding:5px 9px;border:1px solid #9ed4dc;border-radius:999px;color:#218194}.risk-conclusion{display:grid;grid-template-columns:155px 1fr;gap:22px;align-items:center;margin-top:21px;padding:22px;border-radius:11px;background:linear-gradient(135deg,#eef7f8,#f7fafb)}.risk-conclusion div span{display:block;color:#6c818d;font-size:11px}.risk-conclusion div strong{display:block;margin-top:5px;color:#d2634b;font-size:27px}.risk-conclusion p{margin:0;font-size:15px;line-height:1.75}.priority-direction{margin-top:14px;padding:14px 17px;border-left:3px solid #2ba7b8;background:#f7fafb}.priority-direction strong{font-size:12px}.priority-direction p{margin:5px 0 0;line-height:1.6}.cause-list{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:12px;margin-top:20px}.cause-list article{display:flex;gap:14px;padding:17px;border:1px solid #e1e8ec;border-radius:10px;background:#fbfcfd}.cause-list article>span{color:#b7c4cb;font-size:23px;font-weight:800}.cause-list small{color:#b16b43;font-size:10px;font-weight:700}.cause-list p{margin:5px 0 0;line-height:1.6}.investigation-list{margin-top:20px}.investigation-list>div{display:grid;grid-template-columns:43px 1fr;gap:13px;align-items:center;padding:13px 0;border-bottom:1px solid #edf1f3}.investigation-list>div:last-child{border-bottom:0}.investigation-list span{display:grid;width:35px;height:35px;place-items:center;border-radius:8px;background:#e9f5f6;color:#248b9a;font-size:12px;font-weight:700}.investigation-list p{margin:0;line-height:1.55}.recommendation-grid{display:grid;grid-template-columns:1fr 1fr;gap:18px}.recommendation-card,.safety-card{display:flex;gap:15px;padding:22px;border:1px solid #cfe1e5;border-radius:13px;background:#f5fafb}.safety-card{border-color:#efcfac;background:#fff9f2}.card-icon{display:grid;flex:0 0 auto;width:39px;height:39px;place-items:center;border-radius:10px;background:#dfeff2;color:#258697;font-weight:800}.safety-card .card-icon{background:#f9e3ca;color:#a8642e}.recommendation-card small,.safety-card small{color:#72858f}.recommendation-card h2,.safety-card h2{margin:3px 0 9px;font-size:17px}.recommendation-card p,.safety-card p{margin:0;line-height:1.7}.evidence-panel{background:#f8fafb}.evidence-card{margin-top:12px;padding:15px;border:1px solid #e0e7eb;border-radius:10px;background:#fff}.evidence-card header{display:flex;justify-content:space-between;gap:12px;margin-bottom:10px}.evidence-card header span{color:#2a8897;font-size:11px}.evidence-card dl{margin:0}.evidence-card dl div{display:grid;grid-template-columns:82px 1fr;gap:8px;padding:4px 0}.evidence-card dt{color:#86949c;font-size:11px}.evidence-card dd{margin:0;text-align:right;font-size:12px;font-weight:600;word-break:break-word}.evidence-card>p{margin:9px 0 0;padding-top:9px;border-top:1px solid #eef2f4;color:#687b86;font-size:12px;line-height:1.55}.completeness-panel ul{margin:16px 0 0;padding:0;list-style:none}.completeness-panel li{display:grid;grid-template-columns:24px 1fr auto;align-items:center;padding:9px 0}.completeness-panel li>span{color:#2b9f75;font-weight:800}.completeness-panel li small{color:#73858f}.completeness-panel li.missing>span,.completeness-panel li.missing small{color:#bf792c}.next-panel{position:sticky;top:16px;border-color:#bddfe4;background:linear-gradient(145deg,#f2fafb,#fff)}.next-panel h2{margin:9px 0 7px;font-size:21px}.next-panel>p{margin:0 0 17px;color:#667b86;line-height:1.6}.next-panel>.el-button{width:100%}.decision-path{margin-top:22px;padding-top:17px;border-top:1px solid #dfeaec}.decision-path>strong{font-size:12px}.decision-path>div{display:flex;align-items:center;justify-content:space-between;gap:4px;margin-top:12px}.decision-path span{color:#9ba8af;font-size:10px}.decision-path span.active{color:#258a9b;font-weight:800}.decision-path span.done{color:#388b6d}.decision-path i{color:#c2ccd1;font-style:normal}.draft-grid{display:grid;grid-template-columns:2fr 1fr;gap:12px;margin-top:20px}.draft-grid>div{padding:16px;border-radius:9px;background:#f6f8f9}.draft-grid .wide{grid-column:1/-1}.draft-grid span{display:block;color:#7c8b93;font-size:11px}.draft-grid strong,.draft-grid p{display:block;margin:6px 0 0;line-height:1.6}.draft-grid .safety-line{border-left:3px solid #de9c5d;background:#fff7ee}.relations-section{display:grid;grid-template-columns:1fr 1fr;gap:18px}.relations-section article{padding:21px}.relations-section article>span{color:#72858e;font-size:11px}.relations-section h3{margin:8px 0 3px}.relations-section p{margin:0 0 12px}.relations-section .el-tag{margin-right:8px}.empty-copy{margin-top:11px!important;color:#8b999f}.technical-collapse{padding:0 20px;border:1px solid #dce4e9;border-radius:11px;background:#fff}.technical-collapse :deep(.el-collapse-item__header){gap:10px}.technical-collapse :deep(.el-collapse-item__header span){color:#8b989f;font-size:11px}.technical-grid{display:grid;grid-template-columns:repeat(3,1fr);gap:14px;margin:0 0 18px}.technical-grid>div{padding:12px;background:#f6f8f9}.technical-grid .wide{grid-column:1/-1}.technical-grid dt{color:#819099;font-size:11px}.technical-grid dd{margin:5px 0 0;word-break:break-word}.review-intro{color:#687c87;line-height:1.6}.decision-options{margin:4px 0 18px}.dialog-form{margin-top:4px}@keyframes status-pulse{50%{opacity:.45;transform:scale(.85)}}@keyframes hero-breathe{50%{opacity:.62;transform:scale(1.08)}}@media(max-width:1100px){.workspace-grid{grid-template-columns:1fr}.side-column{display:grid;grid-template-columns:1fr 1fr}.evidence-panel{grid-row:span 2}.next-panel{position:static}.hero-metrics{grid-template-columns:repeat(3,1fr);row-gap:18px}.hero-metrics div:nth-child(4){padding-left:0;border-left:0}}@media(max-width:760px){.diagnosis-hero{grid-template-columns:1fr;padding:24px}.hero-metrics{grid-template-columns:1fr 1fr;margin:0 -24px -24px;padding:18px 24px}.hero-metrics div:nth-child(odd){padding-left:0;border-left:0}.workspace-grid,.side-column,.relations-section,.recommendation-grid,.cause-list{grid-template-columns:1fr}.risk-conclusion{grid-template-columns:1fr}.draft-grid,.technical-grid{grid-template-columns:1fr}.draft-grid>div,.draft-grid .wide,.technical-grid .wide{grid-column:1}.section-heading{align-items:flex-start;flex-direction:column}}
.failure-summary{display:flex;flex-direction:column;gap:3px;padding-left:13px;border-left:3px solid #df776c}.failure-summary strong{color:#ffaaa0}.recommendation-card.full{grid-column:1/-1}.safety-card{background:linear-gradient(90deg,#fff4e7,#fffaf4)}.advice-meta{display:flex;flex-wrap:wrap;gap:8px;margin-top:13px}.advice-meta span{padding:5px 9px;border-radius:6px;background:#e6f2f4;color:#46717c;font-size:11px}.timing-list{display:grid;grid-template-columns:repeat(5,minmax(0,1fr));gap:8px}.timing-list span{display:flex;flex-direction:column;gap:3px;padding:9px;border-radius:6px;background:#fff;color:#687b85;font-size:11px}.timing-list b{color:#2f4652}.review-summary{display:grid;grid-template-columns:1fr 1fr;gap:10px;margin:0 0 18px}.review-summary>div{padding:13px 15px;border:1px solid #e2eaed;border-radius:8px;background:#f7fafb}.review-summary>div:nth-child(n+2){grid-column:1/-1}.review-summary span{color:#71838c;font-size:11px}.review-summary strong{display:block;margin-top:5px;color:#d2634b;font-size:20px}.review-summary p{margin:5px 0 0;line-height:1.55}.review-summary .review-warning{border-color:#efcfac;background:#fff8ef}@media(max-width:760px){.timing-list,.review-summary{grid-template-columns:1fr}}
</style>
