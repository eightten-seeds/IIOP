<script setup lang="ts">
import axios from 'axios';
import { computed, onBeforeUnmount, onMounted, reactive, ref } from 'vue';
import { onBeforeRouteLeave, useRoute, useRouter } from 'vue-router';
import { ElMessage, ElMessageBox } from 'element-plus';
import { Warning } from '@element-plus/icons-vue';
import { request } from '../api/request';
import { useAuthStore } from '../stores/auth';
import type { Device, UserSummary } from '../types/device';
import type { InspectionAbnormal, ResultStatus, Severity, TaskDetailData, TaskItem } from '../types/inspection';
import { displayValue } from '../utils/display';

interface ItemDraft { actualValue: string | number | null; resultStatus: ResultStatus; remark: string; }
const SEVERITIES: Severity[] = ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL'];
const route = useRoute();
const router = useRouter();
const auth = useAuthStore();
const data = ref<TaskDetailData>();
const loading = ref(false);
const errorMessage = ref('');
const device = ref<Device>();
const assigneeName = ref('巡检人员');
const starting = ref(false);
const completing = ref(false);
const savingIds = ref<Set<string>>(new Set());
const dirtyIds = ref<Set<string>>(new Set());
const drafts = reactive<Record<string, ItemDraft>>({});
const abnormalVisible = ref(false);
const abnormalSaving = ref(false);
const abnormalForm = reactive<{ title: string; description: string; severity: Severity; taskItemId: string }>({ title: '', description: '', severity: 'MEDIUM', taskItemId: '' });
const task = computed(() => data.value?.task);
const items = computed(() => data.value?.items ?? []);
const abnormals = computed(() => data.value?.abnormals ?? []);
const canExecuteIdentity = computed(() => Boolean(task.value && auth.can('inspection:execute') && auth.roles.includes('INSPECTOR') && auth.currentUser?.id === task.value.assigneeUserId));
const canEdit = computed(() => canExecuteIdentity.value && task.value?.taskStatus === 'IN_PROGRESS');
const completedCount = computed(() => items.value.filter(item => item.resultStatus !== 'PENDING').length);
const abnormalCount = computed(() => items.value.filter(item => item.resultStatus === 'ABNORMAL').length);
const uncompletedCount = computed(() => items.value.filter(item => item.resultStatus === 'PENDING').length);
const remainingRequired = computed(() => items.value.filter(item => item.requiredFlag === 1 && item.resultStatus === 'PENDING').length);
const requiredPhotoPending = computed(() => items.value.some(item => item.itemType === 'PHOTO' && item.requiredFlag === 1 && item.resultStatus === 'PENDING'));
const computedRate = computed(() => items.value.length ? Math.round(completedCount.value * 100 / items.value.length) : 0);
const hasDirty = computed(() => dirtyIds.value.size > 0);

const cannotCompleteReason = computed(() => {
  if (task.value?.taskStatus !== 'IN_PROGRESS') {
    return '当前任务尚未开始或已结束，无法提交完成。';
  }
  if (hasDirty.value) {
    return `存在 ${dirtyIds.value.size} 项已修改但尚未保存的检查项，请先点击“保存本项”。`;
  }
  if (remainingRequired.value > 0) {
    return `仍有 ${remainingRequired.value} 个必填检查项未录入结果，全部必填项完成后方可提交完成。`;
  }
  if (requiredPhotoPending.value) {
    return '包含当前版本无法执行的必填图片检查项，请联系管理员调整。';
  }
  return '';
});

const dateTime = (value: string | null | undefined) => value ? value.replace('T', ' ').slice(0, 19) : '-';
const taskStatusLabel = (status?: string) => ({ PENDING: '待巡检', IN_PROGRESS: '巡检中', COMPLETED: '已完成', CANCELLED: '已取消' }[status ?? ''] ?? displayValue(status));

function initDraft(item: TaskItem) {
  drafts[item.id] = {
    actualValue: item.itemType === 'NUMBER' && item.actualValue !== null && item.actualValue !== '' ? Number(item.actualValue) : item.actualValue,
    resultStatus: item.resultStatus,
    remark: item.remark ?? ''
  };
}

async function resolveRelated() {
  if (!task.value) return;
  const currentTask = task.value;
  const jobs: Promise<unknown>[] = [request.get<never, Device>(`/api/device/devices/${currentTask.deviceId}`).then(value => { device.value = value; })];
  if (auth.currentUser?.id === currentTask.assigneeUserId) assigneeName.value = `${auth.currentUser.realName || auth.currentUser.username}（${auth.currentUser.username}）`;
  else if (auth.can('system:user:view')) {
    jobs.push(
      request.get<never, UserSummary>(`/api/auth/users/${currentTask.assigneeUserId}`, { silentStatuses: [404] })
        .then(user => { assigneeName.value = `${user.realName || user.username}（${user.username}）`; })
        .catch((err: any) => {
          if (err.response?.status === 404) {
            assigneeName.value = '原巡检员（账号已删除）';
          } else {
            assigneeName.value = '人员信息暂不可用';
          }
        })
    );
  }
  await Promise.allSettled(jobs);
}

async function load() {
  loading.value = true;
  errorMessage.value = '';
  try {
    const value = await request.get<never, TaskDetailData>(`/api/inspection/tasks/${route.params.id}`);
    data.value = value;
    Object.keys(drafts).forEach(key => delete drafts[key]);
    value.items.forEach(initDraft);
    dirtyIds.value = new Set();
    await resolveRelated();
  } catch { errorMessage.value = '巡检任务详情加载失败，可能无权访问或服务暂不可用。'; }
  finally { loading.value = false; }
}

function markDirty(id: string) { dirtyIds.value = new Set(dirtyIds.value).add(id); }
function numberHint(item: TaskItem) {
  const raw = drafts[item.id]?.actualValue;
  if (raw === null || raw === undefined || raw === '') return null;
  const value = Number(raw);
  if (!Number.isFinite(value) || (item.lowerLimit == null && item.upperLimit == null)) return null;
  if (item.lowerLimit != null && value < Number(item.lowerLimit)) {
    const diff = Number((Number(item.lowerLimit) - value).toFixed(4));
    return { abnormal: true, text: `当前值低于下限 ${diff}${item.unit || ''}，建议判定为异常` };
  }
  if (item.upperLimit != null && value > Number(item.upperLimit)) {
    const diff = Number((value - Number(item.upperLimit)).toFixed(4));
    return { abnormal: true, text: `当前值高于上限 ${diff}${item.unit || ''}，建议判定为异常` };
  }
  return { abnormal: false, text: `当前值在允许范围内（${item.lowerLimit ?? '-∞'} ～ ${item.upperLimit ?? '∞'}${item.unit || ''}），建议判定为正常` };
}
function updateNumberResult(item: TaskItem) {
  const hint = numberHint(item);
  if (hint) drafts[item.id].resultStatus = hint.abnormal ? 'ABNORMAL' : 'NORMAL';
  markDirty(item.id);
}
function setBoolean(item: TaskItem, value: 'NORMAL' | 'ABNORMAL') {
  drafts[item.id].actualValue = value === 'NORMAL' ? '正常' : '异常';
  drafts[item.id].resultStatus = value;
  markDirty(item.id);
}
function isConflict(error: unknown) { return axios.isAxiosError(error) && error.response?.status === 409; }

async function startTask() {
  if (starting.value) return;
  starting.value = true;
  try {
    await request.post(`/api/inspection/tasks/${route.params.id}/start`);
    ElMessage.success('巡检已开始，请逐项填写检查结果');
    await load();
  } catch (error) { if (isConflict(error)) await load(); }
  finally { starting.value = false; }
}

async function saveItem(item: TaskItem) {
  if (savingIds.value.has(item.id)) return;
  const draft = drafts[item.id];
  if (item.itemType !== 'PHOTO' && draft.resultStatus !== 'NORMAL' && draft.resultStatus !== 'ABNORMAL') return void ElMessage.warning('请选择正常或异常结果');
  if (item.itemType === 'NUMBER' && (draft.actualValue === null || draft.actualValue === '')) return void ElMessage.warning('请输入数值检查结果');
  if (item.itemType === 'TEXT' && !String(draft.actualValue ?? '').trim()) return void ElMessage.warning('请输入文本检查结果');
  savingIds.value = new Set(savingIds.value).add(item.id);
  try {
    const saved = await request.put<never, TaskItem>(`/api/inspection/tasks/${route.params.id}/items/${item.id}`, {
      actualValue: String(draft.actualValue ?? ''), resultStatus: draft.resultStatus, remark: draft.remark || null, evidenceUrls: null
    });
    const index = data.value?.items.findIndex(value => value.id === item.id) ?? -1;
    if (data.value && index >= 0) data.value.items[index] = saved;
    initDraft(saved);
    const nextDirty = new Set(dirtyIds.value); nextDirty.delete(item.id); dirtyIds.value = nextDirty;
    ElMessage.success(`检查项“${item.itemName}”已保存，结果：${draft.resultStatus === 'ABNORMAL' ? '异常' : '正常'}`);
  } catch (error) { if (isConflict(error)) await load(); }
  finally { const next = new Set(savingIds.value); next.delete(item.id); savingIds.value = next; }
}

function openAbnormal() {
  Object.assign(abnormalForm, { title: '', description: '', severity: 'MEDIUM', taskItemId: '' });
  abnormalVisible.value = true;
}

async function refreshAbnormals() {
  const latest = await request.get<never, TaskDetailData>(`/api/inspection/tasks/${route.params.id}`);
  if (data.value) data.value.abnormals = latest.abnormals;
}

async function createAbnormal() {
  if (abnormalSaving.value) return;
  if (!abnormalForm.title.trim() || !abnormalForm.description.trim()) return void ElMessage.warning('请填写异常标题和详细描述');
  abnormalSaving.value = true;
  try {
    await request.post('/api/inspection/abnormals', {
      taskId: task.value?.id, taskItemId: abnormalForm.taskItemId || null,
      title: abnormalForm.title.trim(), description: abnormalForm.description.trim(), severity: abnormalForm.severity
    });
    ElMessage.success('巡检异常已上报，系统已发布后续处理事件');
    abnormalVisible.value = false;
    await refreshAbnormals();
  } catch (error) { if (isConflict(error)) await load(); }
  finally { abnormalSaving.value = false; }
}

async function completeTask() {
  if (completing.value || remainingRequired.value > 0 || hasDirty.value) return;
  try {
    await ElMessageBox.confirm('确认完成本次巡检？完成后检查结果将进入只读状态。', '完成巡检', { type: 'warning', confirmButtonText: '确认完成', cancelButtonText: '取消' });
  } catch { return; }
  completing.value = true;
  try {
    await request.post(`/api/inspection/tasks/${route.params.id}/complete`);
    const abnormalCount = items.value.filter(i => i.resultStatus === 'ABNORMAL').length;
    ElMessage.success(abnormalCount > 0 ? `巡检任务已完成，发现 ${abnormalCount} 项异常。` : '巡检任务已完成，未发现异常。');
    await load();
  } catch (error) { if (isConflict(error)) await load(); }
  finally { completing.value = false; }
}

async function beforeCloseAbnormal(done: () => void) {
  if (abnormalSaving.value) return;
  if (!abnormalForm.title.trim() && !abnormalForm.description.trim()) return done();
  try {
    await ElMessageBox.confirm('异常内容尚未上报，确定放弃吗？', '放弃上报', { type: 'warning' });
    done();
  } catch { /* 保留表单 */ }
}

const isAbnormalDirty = computed(() => abnormalVisible.value && Boolean(abnormalForm.title.trim() || abnormalForm.description.trim()));

function beforeUnload(event: BeforeUnloadEvent) {
  if (!hasDirty.value && !isAbnormalDirty.value) return;
  event.preventDefault(); event.returnValue = '';
}
onBeforeRouteLeave(async () => {
  if (!hasDirty.value && !isAbnormalDirty.value) return true;
  try { await ElMessageBox.confirm('存在尚未保存的修改，确定离开当前页面吗？', '未保存修改', { type: 'warning', confirmButtonText: '离开', cancelButtonText: '继续填写' }); return true; }
  catch { return false; }
});
onMounted(() => { window.addEventListener('beforeunload', beforeUnload); void load(); });
onBeforeUnmount(() => window.removeEventListener('beforeunload', beforeUnload));
</script>

<template>
  <section class="task-detail">
    <div class="page-head">
      <div><el-button link @click="router.push('/inspection/tasks')">← 返回任务列表</el-button><h1>巡检任务详情</h1><p>按任务状态完成现场检查、保存结果并上报真实异常。</p></div>
      <div class="head-actions">
        <el-button v-if="canExecuteIdentity&&task?.taskStatus==='PENDING'" type="primary" :loading="starting" @click="startTask">开始巡检</el-button>
        <el-button v-if="canEdit" type="danger" plain @click="openAbnormal">上报异常</el-button>
        <el-tooltip v-if="canEdit && cannotCompleteReason" :content="cannotCompleteReason" placement="bottom">
          <span>
            <el-button type="success" :disabled="true">完成巡检</el-button>
          </span>
        </el-tooltip>
        <el-button v-else-if="canEdit" type="success" :loading="completing" @click="completeTask">完成巡检</el-button>
      </div>
    </div>
    <el-alert v-if="errorMessage" :title="errorMessage" type="error" show-icon :closable="false"><template #default><el-button link type="primary" @click="load">重新加载</el-button></template></el-alert>
    <template v-else>
      <el-card v-loading="loading" shadow="never"><template #header><strong>任务信息</strong></template>
        <el-descriptions v-if="task" :column="3" border>
          <el-descriptions-item label="任务编号">{{ task.taskCode }}</el-descriptions-item><el-descriptions-item label="任务状态"><el-tag>{{ taskStatusLabel(task.taskStatus) }}</el-tag></el-descriptions-item><el-descriptions-item label="结果状态"><el-tag :type="task.resultStatus==='ABNORMAL'?'danger':task.resultStatus==='NORMAL'?'success':'info'">{{ displayValue(task.resultStatus) }}</el-tag></el-descriptions-item>
          <el-descriptions-item label="设备">{{ device ? `${device.deviceName}（${device.deviceCode}）` : '设备信息加载中' }} <el-button link type="primary" @click="router.push(`/devices/${task.deviceId}`)">查看设备</el-button></el-descriptions-item><el-descriptions-item label="巡检人员">{{ assigneeName }}</el-descriptions-item><el-descriptions-item label="是否逾期"><el-tag v-if="task.overdueFlag===1" type="danger">已逾期</el-tag><span v-else>未逾期</span></el-descriptions-item>
          <el-descriptions-item label="计划时间" :span="2">{{ dateTime(task.scheduledStartTime) }} 至 {{ dateTime(task.scheduledEndTime) }}</el-descriptions-item><el-descriptions-item label="完成率">{{ computedRate }}%</el-descriptions-item>
          <el-descriptions-item label="实际开始">{{ dateTime(task.actualStartTime) }}</el-descriptions-item><el-descriptions-item label="实际完成">{{ dateTime(task.actualEndTime) }}</el-descriptions-item><el-descriptions-item label="备注">{{ task.remark || '-' }}</el-descriptions-item>
        </el-descriptions>
        <el-alert v-if="task?.taskStatus==='CANCELLED'" title="该巡检任务已取消，所有检查结果均为只读。" type="info" show-icon :closable="false" />
      </el-card>

      <el-alert v-if="requiredPhotoPending" title="该任务包含第一版无法执行的必填图片检查项，请联系管理员处理模板/任务数据。" type="error" show-icon :closable="false" />
      <el-card shadow="never">
        <template #header>
          <div class="section-head">
            <div>
              <strong>检查项填写</strong>
              <div class="execution-stats-row">
                <el-tag type="info">已完成：{{ completedCount }} / {{ items.length }} 项</el-tag>
                <el-tag :type="abnormalCount > 0 ? 'danger' : 'success'" :effect="abnormalCount > 0 ? 'dark' : 'plain'">
                  发现异常：{{ abnormalCount }} 项
                </el-tag>
                <el-tag :type="uncompletedCount > 0 ? 'warning' : 'info'" effect="plain">
                  待完成：{{ uncompletedCount }} 项
                </el-tag>
                <span v-if="hasDirty" class="dirty-badge">（存在 {{ dirtyIds.size }} 项未保存的修改）</span>
              </div>
            </div>
            <div v-if="canEdit && cannotCompleteReason" class="completion-reason-callout">
              <el-icon><Warning /></el-icon>
              <span>{{ cannotCompleteReason }}</span>
            </div>
          </div>
        </template>
        <el-progress :percentage="computedRate" :status="computedRate===100?'success':undefined" />
        <el-empty v-if="!items.length" description="该任务没有检查项" />
        <div v-for="item in items" :key="item.id" class="item-card" :class="{dirty:dirtyIds.has(item.id)}">
          <div class="item-title"><div><strong>{{ item.itemName }}</strong><span>{{ item.itemCode }}</span></div><div><el-tag v-if="item.requiredFlag===1" type="warning" effect="plain">必填</el-tag><el-tag effect="plain">{{ displayValue(item.itemType) }}</el-tag><el-tag :type="item.resultStatus==='ABNORMAL'?'danger':item.resultStatus==='NORMAL'?'success':'info'">{{ displayValue(item.resultStatus) }}</el-tag></div></div>
          <el-descriptions :column="4" size="small"><el-descriptions-item label="标准值">{{ item.standardValue ? displayValue(item.standardValue) : '-' }}</el-descriptions-item><el-descriptions-item label="单位">{{ item.unit || '-' }}</el-descriptions-item><el-descriptions-item label="允许范围">{{ item.lowerLimit ?? '-' }} ～ {{ item.upperLimit ?? '-' }}</el-descriptions-item><el-descriptions-item label="检查方法">{{ item.inspectionMethod || '-' }}</el-descriptions-item></el-descriptions>
          <el-alert v-if="item.itemType==='PHOTO'" title="第一版暂不支持图片巡检执行" type="warning" show-icon :closable="false" />
          <el-form v-else label-width="90px" class="result-form">
            <el-form-item label="实际结果" required>
              <el-input-number v-if="item.itemType==='NUMBER'" v-model="drafts[item.id].actualValue as number" :disabled="!canEdit" controls-position="right" @change="updateNumberResult(item)" />
              <el-radio-group v-else-if="item.itemType==='BOOLEAN'" :model-value="drafts[item.id].resultStatus" :disabled="!canEdit" @change="(value:string|number|boolean|undefined)=>setBoolean(item,value as 'NORMAL'|'ABNORMAL')"><el-radio-button value="NORMAL">正常</el-radio-button><el-radio-button value="ABNORMAL">异常</el-radio-button></el-radio-group>
              <el-input v-else v-model="drafts[item.id].actualValue" type="textarea" :rows="2" :disabled="!canEdit" placeholder="填写现场观察结果" @input="markDirty(item.id)" />
            </el-form-item>
            <el-alert v-if="item.itemType === 'NUMBER' && numberHint(item)" :title="numberHint(item)?.text" :type="numberHint(item)?.abnormal ? 'error' : 'success'" :closable="false" show-icon />
            <el-form-item v-if="item.itemType!=='BOOLEAN'" label="结果判定" required><el-radio-group v-model="drafts[item.id].resultStatus" :disabled="!canEdit" @change="markDirty(item.id)"><el-radio value="NORMAL">正常</el-radio><el-radio value="ABNORMAL">异常</el-radio></el-radio-group></el-form-item>
            <el-form-item label="检查备注"><el-input v-model="drafts[item.id].remark" :disabled="!canEdit" placeholder="选填" @input="markDirty(item.id)" /></el-form-item>
            <el-form-item v-if="canEdit"><el-button type="primary" :loading="savingIds.has(item.id)" :disabled="!dirtyIds.has(item.id)" @click="saveItem(item)">保存本项</el-button></el-form-item>
          </el-form>
        </div>
      </el-card>

      <el-card shadow="never"><template #header><div class="section-head"><div><strong>本次巡检异常</strong><p>异常成功上报后会发布后续处理事件，不代表维修缺陷已经生成。</p></div><el-button v-if="canEdit" type="danger" plain @click="openAbnormal">上报异常</el-button></div></template>
        <el-table v-if="abnormals.length" :data="abnormals" row-key="id"><el-table-column prop="abnormalCode" label="异常编号" min-width="160" /><el-table-column prop="title" label="标题" min-width="180" /><el-table-column label="严重程度" width="110"><template #default="scope"><el-tag :type="scope.row.severity==='CRITICAL'||scope.row.severity==='HIGH'?'danger':'warning'">{{ displayValue(scope.row.severity) }}</el-tag></template></el-table-column><el-table-column label="状态" width="100"><template #default="scope">{{ displayValue(scope.row.status) }}</template></el-table-column><el-table-column label="上报时间" min-width="160"><template #default="scope">{{ dateTime(scope.row.reportedAt) }}</template></el-table-column><el-table-column label="操作" width="100"><template #default="scope"><el-button link @click="router.push(`/inspection/abnormals/${scope.row.id}`)">查看详情</el-button></template></el-table-column></el-table>
        <el-empty v-else description="本次巡检暂未上报异常" />
      </el-card>
    </template>

    <el-dialog v-model="abnormalVisible" title="上报巡检异常" width="620px" :close-on-click-modal="!abnormalSaving" :before-close="beforeCloseAbnormal"><el-form label-width="95px" class="abnormal-form">
      <el-form-item label="异常标题" required><el-input v-model="abnormalForm.title" maxlength="128" :disabled="abnormalSaving" /></el-form-item><el-form-item label="严重程度" required><el-select v-model="abnormalForm.severity" :disabled="abnormalSaving"><el-option v-for="severity in SEVERITIES" :key="severity" :label="displayValue(severity)" :value="severity" /></el-select></el-form-item>
      <el-form-item label="关联检查项"><el-select v-model="abnormalForm.taskItemId" clearable :disabled="abnormalSaving" placeholder="可选"><el-option v-for="item in items" :key="item.id" :label="`${item.itemName}（${item.itemCode}）`" :value="item.id" /></el-select></el-form-item><el-form-item label="异常描述" required><el-input v-model="abnormalForm.description" type="textarea" :rows="5" maxlength="2000" show-word-limit :disabled="abnormalSaving" /></el-form-item>
    </el-form><template #footer><el-button :disabled="abnormalSaving" @click="beforeCloseAbnormal(()=>{ abnormalVisible = false; })">取消</el-button><el-button type="danger" :loading="abnormalSaving" @click="createAbnormal">确认上报</el-button></template></el-dialog>
  </section>
</template>

<style scoped>
.task-detail{display:flex;flex-direction:column;gap:16px}.head-actions,.section-head,.item-title{display:flex;align-items:center;justify-content:space-between;gap:12px}.execution-stats-row{display:flex;align-items:center;gap:10px;margin-top:8px;flex-wrap:wrap}.completion-reason-callout{display:inline-flex;align-items:center;gap:6px;padding:6px 12px;border-radius:6px;background:#fef3c7;color:#b45309;font-size:12px;max-width:480px}.dirty-badge{color:#d97706;font-size:12px;font-weight:600}.section-head p{margin:6px 0 0;color:#667085}.item-card{margin-top:16px;padding:18px;border:1px solid #e4e7ed;border-radius:10px;background:#fafcff}.item-card.dirty{border-color:#e6a23c;background:#fffaf0}.item-title{margin-bottom:14px}.item-title>div{display:flex;align-items:center;gap:8px}.item-title span{color:#667085;font-size:13px}.result-form{margin-top:14px;max-width:820px}.result-form :deep(.el-input-number),.abnormal-form :deep(.el-select){width:100%}.item-card :deep(.el-alert),.task-detail>.el-alert{margin-top:12px}
</style>
