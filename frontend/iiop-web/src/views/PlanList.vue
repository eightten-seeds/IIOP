<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, onUnmounted, reactive, ref, watch } from 'vue';
import { onBeforeRouteLeave } from 'vue-router';
import { ElMessage, ElMessageBox } from 'element-plus';
import { request } from '../api/request';
import { useAuthStore } from '../stores/auth';
import type { Device, PageResult, UserSummary } from '../types/device';
import { emptyPlanForm, type InspectionPlan, type InspectionTemplate, type PlanForm, type PlanStatus, type ScheduleType, type TemplateItem } from '../types/inspection';
import { displayValue } from '../utils/display';

const SCHEDULES: ScheduleType[] = ['DAILY', 'WEEKLY', 'MONTHLY', 'CRON'];
const STATUSES: PlanStatus[] = ['ENABLED', 'DISABLED'];
const auth = useAuthStore();
const rows = ref<InspectionPlan[]>([]);
const total = ref(0);
const page = ref(1);
const pageSize = 20;
const loading = ref(false);
const errorMessage = ref('');
const generatingId = ref('');
const filters = reactive<{ keyword: string; status: '' | PlanStatus; deviceId: string }>({ keyword: '', status: '', deviceId: '' });
const deviceOptions = ref<Device[]>([]);
const templateOptions = ref<InspectionTemplate[]>([]);
const inspectorOptions = ref<UserSummary[]>([]);
const deviceLoading = ref(false);
const templateLoading = ref(false);
const inspectorLoading = ref(false);
const deviceNames = reactive<Record<string, string>>({});
const templateNames = reactive<Record<string, string>>({});
const inspectorNames = reactive<Record<string, string>>({});
const formVisible = ref(false);
const formLoading = ref(false);
const saving = ref(false);
const editingId = ref('');
const templateBlocked = ref(false);
const form = reactive<PlanForm>(emptyPlanForm());
const initialSnapshot = ref('');
const formDirty = computed(() => formVisible.value && JSON.stringify(form) !== initialSnapshot.value);

const deviceLabel = (device: Device) => `${device.deviceName}（${device.deviceCode}）`;
const templateLabel = (template: InspectionTemplate) => `${template.templateName}（${template.templateCode} / v${template.version}）`;
const userLabel = (user: UserSummary) => `${user.realName || user.username}（${user.username}）`;
const dateTime = (value: string | null) => value ? value.replace('T', ' ').slice(0, 16) : '尚未生成';
const localDate = () => {
  const now = new Date();
  const year = now.getFullYear();
  const month = String(now.getMonth() + 1).padStart(2, '0');
  const day = String(now.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
};

function scheduleRuleText(plan: InspectionPlan) {
  const typeMap: Record<string, string> = {
    DAILY: '每日执行',
    WEEKLY: '每周执行',
    MONTHLY: '每月执行',
    CRON: `CRON 规则 (${plan.cronExpression || '-'})`
  };
  return typeMap[plan.scheduleType] || displayValue(plan.scheduleType);
}

function executionPeriodText(plan: InspectionPlan) {
  if (!plan.startDate && !plan.endDate) return '长期有效';
  if (plan.startDate && !plan.endDate) return `${plan.startDate} 起有效`;
  if (!plan.startDate && plan.endDate) return `截止 ${plan.endDate}`;
  return `${plan.startDate} 至 ${plan.endDate}`;
}

function friendlyTime(value: string | null) {
  if (!value) return '尚未生成';
  const clean = value.replace('T', ' ').slice(0, 16);
  const today = localDate();
  if (clean.startsWith(today)) {
    return `今日 ${clean.slice(11)}`;
  }
  return clean;
}

async function searchDevices(keyword = '') {
  deviceLoading.value = true;
  try {
    const data = await request.get<never, PageResult<Device>>('/api/device/devices', { params: { pageNum: 1, pageSize: 20, keyword: keyword || undefined } });
    deviceOptions.value = (data.records ?? []).filter(device => device.status !== 'SCRAPPED');
    deviceOptions.value.forEach(device => { deviceNames[device.id] = deviceLabel(device); });
  } finally { deviceLoading.value = false; }
}

async function searchTemplates(keyword = '') {
  templateLoading.value = true;
  try {
    const data = await request.get<never, PageResult<InspectionTemplate>>('/api/inspection/templates', { params: { pageNum: 1, pageSize: 20, keyword: keyword || undefined, status: 'ENABLED' } });
    templateOptions.value = data.records ?? [];
    templateOptions.value.forEach(template => { templateNames[template.id] = templateLabel(template); });
  } finally { templateLoading.value = false; }
}

async function searchInspectors(keyword = '') {
  inspectorLoading.value = true;
  try {
    const data = await request.get<never, PageResult<UserSummary>>('/api/auth/users', { params: { pageNum: 1, pageSize: 20, keyword: keyword || undefined, status: 'ENABLED', roleCode: 'INSPECTOR' } });
    inspectorOptions.value = data.records ?? [];
    inspectorOptions.value.forEach(user => { inspectorNames[user.id] = userLabel(user); });
  } finally { inspectorLoading.value = false; }
}

async function resolveNames(plans: InspectionPlan[]) {
  const deviceIds = [...new Set(plans.map(plan => plan.deviceId))].filter(id => !deviceNames[id]);
  const templateIds = [...new Set(plans.map(plan => plan.templateId))].filter(id => !templateNames[id]);
  const userIds = [...new Set(plans.map(plan => plan.assigneeUserId))].filter(id => !inspectorNames[id]);
  await Promise.allSettled([
    ...deviceIds.map(async id => { const value = await request.get<never, Device>(`/api/device/devices/${id}`); deviceNames[id] = deviceLabel(value); }),
    ...templateIds.map(async id => { const value = await request.get<never, InspectionTemplate>(`/api/inspection/templates/${id}`); templateNames[id] = templateLabel(value); }),
    ...userIds.map(async id => {
      try {
        const value = await request.get<never, UserSummary>(`/api/auth/users/${id}`, { silentStatuses: [404] });
        inspectorNames[id] = userLabel(value);
      } catch (err: any) {
        if (err.response?.status === 404) {
          inspectorNames[id] = '原巡检员（账号已删除）';
        } else {
          inspectorNames[id] = '人员信息暂不可用';
        }
      }
    })
  ]);
}

async function load() {
  loading.value = true;
  errorMessage.value = '';
  try {
    const data = await request.get<never, PageResult<InspectionPlan>>('/api/inspection/plans', { params: {
      pageNum: page.value, pageSize, keyword: filters.keyword || undefined,
      status: filters.status || undefined, deviceId: filters.deviceId || undefined
    } });
    rows.value = data.records ?? [];
    total.value = data.total ?? 0;
    await resolveNames(rows.value);
  } catch { errorMessage.value = '巡检计划加载失败，请检查服务状态后重试。'; }
  finally { loading.value = false; }
}

function search() { page.value = 1; void load(); }
function resetFilters() { Object.assign(filters, { keyword: '', status: '', deviceId: '' }); search(); }

async function ensureDevice(id: string) {
  if (!id || deviceOptions.value.some(value => value.id === id)) return;
  const value = await request.get<never, Device>(`/api/device/devices/${id}`);
  deviceOptions.value = [value, ...deviceOptions.value];
  deviceNames[id] = deviceLabel(value);
}
async function ensureTemplate(id: string) {
  if (!id || templateOptions.value.some(value => value.id === id)) return;
  const value = await request.get<never, InspectionTemplate>(`/api/inspection/templates/${id}`);
  templateOptions.value = [value, ...templateOptions.value];
  templateNames[id] = templateLabel(value);
}
async function ensureInspector(id: string) {
  if (!id || inspectorOptions.value.some(value => value.id === id)) return;
  try {
    const value = await request.get<never, UserSummary>(`/api/auth/users/${id}`, { silentStatuses: [404] });
    inspectorOptions.value = [value, ...inspectorOptions.value];
    inspectorNames[id] = userLabel(value);
  } catch (err: any) {
    if (err.response?.status === 404) {
      inspectorNames[id] = '原巡检员（账号已删除）';
    } else {
      inspectorNames[id] = '人员信息暂不可用';
    }
  }
}

async function checkTemplate(id: string) {
  templateBlocked.value = false;
  if (!id) return;
  try {
    const items = await request.get<never, TemplateItem[]>(`/api/inspection/templates/${id}/items`);
    templateBlocked.value = items.some(item => item.itemType === 'PHOTO' && item.requiredFlag === 1);
    if (templateBlocked.value) ElMessage.warning('该模板包含第一版无法执行的必填 PHOTO 检查项，请先调整模板。');
  } catch { templateBlocked.value = true; }
}

async function openCreate() {
  editingId.value = '';
  templateBlocked.value = false;
  Object.assign(form, emptyPlanForm());
  await Promise.all([searchDevices(''), searchTemplates(''), searchInspectors('')]);
  initialSnapshot.value = JSON.stringify(form);
  formVisible.value = true;
}

async function openEdit(row: InspectionPlan) {
  editingId.value = row.id;
  formLoading.value = true;
  try {
    const [detail] = await Promise.all([
      request.get<never, InspectionPlan>(`/api/inspection/plans/${row.id}`),
      searchDevices(''), searchTemplates(''), searchInspectors('')
    ]);
    await Promise.all([ensureDevice(detail.deviceId), ensureTemplate(detail.templateId), ensureInspector(detail.assigneeUserId)]);
    Object.assign(form, {
      planCode: detail.planCode, planName: detail.planName, deviceId: detail.deviceId, templateId: detail.templateId,
      scheduleType: detail.scheduleType, cronExpression: detail.cronExpression ?? '', startDate: detail.startDate,
      endDate: detail.endDate, assigneeUserId: detail.assigneeUserId, status: detail.status
    });
    await checkTemplate(detail.templateId);
    initialSnapshot.value = JSON.stringify(form);
    formVisible.value = true;
  } finally { formLoading.value = false; }
}

async function beforeClosePlan(done: () => void) {
  if (saving.value) return;
  if (!formDirty.value) return done();
  try {
    await ElMessageBox.confirm('巡检计划尚未保存，确定放弃吗？', '放弃编辑', { type: 'warning' });
    done();
  } catch { /* 保留表单 */ }
}

watch(() => form.scheduleType, value => { if (value !== 'CRON') form.cronExpression = ''; });

async function savePlan() {
  if (saving.value) return;
  if (!form.planCode.trim() || !form.planName.trim()) return void ElMessage.warning('请填写计划编码和计划名称');
  if (!form.deviceId || !form.templateId || !form.assigneeUserId) return void ElMessage.warning('请选择设备、巡检模板和巡检人员');
  if (form.scheduleType === 'CRON' && !form.cronExpression.trim()) return void ElMessage.warning('CRON 计划必须填写表达式');
  if (templateBlocked.value) return void ElMessage.warning('该模板包含第一版无法执行的必填 PHOTO 检查项，请先调整模板。');
  saving.value = true;
  try {
    const payload = { ...form, startDate: form.startDate || localDate(), cronExpression: form.scheduleType === 'CRON' ? form.cronExpression.trim() : null };
    if (editingId.value) await request.put(`/api/inspection/plans/${editingId.value}`, payload);
    else await request.post('/api/inspection/plans', payload);
    ElMessage.success(editingId.value ? '巡检计划更新成功' : '巡检计划创建成功');
    initialSnapshot.value = JSON.stringify(form);
    formVisible.value = false;
    await load();
  } finally { saving.value = false; }
}

async function generateTask(row: InspectionPlan) {
  if (generatingId.value) return;
  try {
    await ElMessageBox.confirm('确认根据当前巡检计划生成新的待执行任务？', '生成巡检任务', { type: 'warning', confirmButtonText: '确认生成', cancelButtonText: '取消' });
  } catch { return; }
  generatingId.value = row.id;
  try {
    await request.post(`/api/inspection/plans/${row.id}/generate-task`);
    ElMessage.success('新的待执行巡检任务已生成');
    await load();
  } finally { generatingId.value = ''; }
}

function beforeUnload(event: BeforeUnloadEvent) {
  if (!formDirty.value) return;
  event.preventDefault();
  event.returnValue = '';
}

onBeforeRouteLeave(async () => {
  if (!formDirty.value) return true;
  try {
    await ElMessageBox.confirm('巡检计划尚未保存，确定离开当前页面吗？', '未保存修改', {
      type: 'warning',
      confirmButtonText: '离开',
      cancelButtonText: '继续编辑'
    });
    return true;
  } catch {
    return false;
  }
});

onMounted(() => {
  window.addEventListener('beforeunload', beforeUnload);
  void load();
});

onBeforeUnmount(() => {
  window.removeEventListener('beforeunload', beforeUnload);
});
</script>

<template>
  <section class="inspection-page">
    <div class="page-head">
      <div><h1>巡检计划</h1><p>为设备绑定已启用模板和巡检人员，并按周期生成待执行任务。</p></div>
      <el-button v-if="auth.can('inspection:plan:manage')" type="primary" @click="openCreate">新增计划</el-button>
    </div>
    <el-card class="filter-card" shadow="never">
      <el-form inline @submit.prevent="search">
        <el-form-item label="关键词"><el-input v-model="filters.keyword" clearable placeholder="计划编码或名称" @keyup.enter="search" /></el-form-item>
        <el-form-item label="设备"><el-select v-model="filters.deviceId" filterable remote clearable reserve-keyword :remote-method="searchDevices" :loading="deviceLoading" placeholder="按设备名称或编码搜索"><el-option v-for="device in deviceOptions" :key="device.id" :label="deviceLabel(device)" :value="device.id" /></el-select></el-form-item>
        <el-form-item label="计划状态"><el-select v-model="filters.status" clearable placeholder="全部状态"><el-option v-for="status in STATUSES" :key="status" :label="displayValue(status)" :value="status" /></el-select></el-form-item>
        <el-form-item><el-button type="primary" @click="search">查询</el-button><el-button @click="resetFilters">重置</el-button></el-form-item>
      </el-form>
    </el-card>
    <el-card shadow="never">
      <el-alert v-if="errorMessage" :title="errorMessage" type="error" show-icon :closable="false"><template #default><el-button link type="primary" @click="load">重新加载</el-button></template></el-alert>
      <el-table v-else v-loading="loading" :data="rows" row-key="id">
        <el-table-column label="计划信息" min-width="190">
          <template #default="scope">
            <div class="plan-cell">
              <strong>{{ scope.row.planName }}</strong>
              <span class="muted-code">{{ scope.row.planCode }}</span>
            </div>
          </template>
        </el-table-column>
        <el-table-column label="检查对象（设备 / 模板）" min-width="260">
          <template #default="scope">
            <div class="target-cell">
              <span class="device-target">{{ deviceNames[scope.row.deviceId] || '设备加载中' }}</span>
              <span class="template-target">{{ templateNames[scope.row.templateId] || '模板加载中' }}</span>
            </div>
          </template>
        </el-table-column>
        <el-table-column label="执行周期与规则" min-width="170">
          <template #default="scope">
            <div>
              <el-tag size="small" type="info">{{ scheduleRuleText(scope.row) }}</el-tag>
              <div class="rule-hint">{{ executionPeriodText(scope.row) }}</div>
            </div>
          </template>
        </el-table-column>
        <el-table-column label="巡检责任人" min-width="160">
          <template #default="scope">{{ inspectorNames[scope.row.assigneeUserId] || '人员信息加载中' }}</template>
        </el-table-column>
        <el-table-column label="计划状态" width="95">
          <template #default="scope">
            <el-tag :type="scope.row.status==='ENABLED'?'success':'info'">
              {{ displayValue(scope.row.status) }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="下次执行" min-width="140">
          <template #default="scope">
            <span :class="{ 'highlight-time': scope.row.nextGenerateTime && scope.row.nextGenerateTime.includes(localDate()) }">
              {{ friendlyTime(scope.row.nextGenerateTime) }}
            </span>
          </template>
        </el-table-column>
        <el-table-column label="核心操作" width="215" fixed="right">
          <template #default="scope">
            <el-button v-if="auth.can('inspection:plan:manage')" link :loading="formLoading&&editingId===scope.row.id" @click="openEdit(scope.row)">编辑</el-button>
            <el-button v-if="auth.can('inspection:plan:manage')&&scope.row.status==='ENABLED'" link type="primary" :loading="generatingId===scope.row.id" @click="generateTask(scope.row)">生成巡检任务</el-button>
          </template>
        </el-table-column>
      </el-table>
      <el-empty v-if="!loading&&!errorMessage&&!rows.length" description="暂无符合条件的巡检计划"><el-button v-if="auth.can('inspection:plan:manage')" type="primary" @click="openCreate">创建第一个计划</el-button></el-empty>
      <el-pagination v-if="!errorMessage&&total>pageSize" v-model:current-page="page" layout="prev, pager, next, total" :page-size="pageSize" :total="total" @current-change="load" />
    </el-card>

    <el-dialog v-model="formVisible" :title="editingId?'编辑巡检计划':'新增巡检计划'" width="780px" :close-on-click-modal="!saving" :before-close="beforeClosePlan">
      <el-alert v-if="templateBlocked" title="该模板包含第一版无法执行的必填 PHOTO 检查项，请先调整模板。" type="error" show-icon :closable="false" />
      <el-form label-width="105px" class="plan-form">
        <el-row :gutter="18">
          <el-col :span="12"><el-form-item label="计划编码" required><el-input v-model="form.planCode" :disabled="saving" /></el-form-item></el-col>
          <el-col :span="12"><el-form-item label="计划名称" required><el-input v-model="form.planName" :disabled="saving" /></el-form-item></el-col>
          <el-col :span="12"><el-form-item label="设备" required><el-select v-model="form.deviceId" filterable remote reserve-keyword :remote-method="searchDevices" :loading="deviceLoading" :disabled="saving" placeholder="按名称或编码搜索"><el-option v-for="device in deviceOptions" :key="device.id" :label="deviceLabel(device)" :value="device.id" :disabled="device.status==='SCRAPPED'" /></el-select></el-form-item></el-col>
          <el-col :span="12"><el-form-item label="巡检模板" required><el-select v-model="form.templateId" filterable remote reserve-keyword :remote-method="searchTemplates" :loading="templateLoading" :disabled="saving" placeholder="仅可选择已启用模板" @change="checkTemplate"><el-option v-for="template in templateOptions" :key="template.id" :label="templateLabel(template)" :value="template.id" :disabled="template.status!=='ENABLED'" /></el-select></el-form-item></el-col>
          <el-col :span="12"><el-form-item label="巡检人员" required><el-select v-model="form.assigneeUserId" filterable remote reserve-keyword :remote-method="searchInspectors" :loading="inspectorLoading" :disabled="saving" placeholder="仅可选择启用的巡检人员"><el-option v-for="user in inspectorOptions" :key="user.id" :label="userLabel(user)" :value="user.id" :disabled="user.status!=='ENABLED'" /></el-select></el-form-item></el-col>
          <el-col :span="12"><el-form-item label="周期类型" required><el-select v-model="form.scheduleType" :disabled="saving"><el-option v-for="schedule in SCHEDULES" :key="schedule" :label="displayValue(schedule)" :value="schedule" /></el-select></el-form-item></el-col>
          <el-col v-if="form.scheduleType==='CRON'" :span="24"><el-form-item label="CRON 表达式" required><el-input v-model="form.cronExpression" :disabled="saving" placeholder="例如：0 0 8 * * ?" /></el-form-item></el-col>
          <el-col :span="12"><el-form-item label="开始日期"><el-date-picker v-model="form.startDate" type="date" value-format="YYYY-MM-DD" clearable :disabled="saving" /></el-form-item></el-col>
          <el-col :span="12"><el-form-item label="结束日期"><el-date-picker v-model="form.endDate" type="date" value-format="YYYY-MM-DD" clearable :disabled="saving" /></el-form-item></el-col>
          <el-col :span="12"><el-form-item label="计划状态" required><el-select v-model="form.status" :disabled="saving"><el-option v-for="status in STATUSES" :key="status" :label="displayValue(status)" :value="status" /></el-select></el-form-item></el-col>
        </el-row>
      </el-form>
      <template #footer><el-button :disabled="saving" @click="beforeClosePlan(() => { formVisible = false; })">取消</el-button><el-button type="primary" :loading="saving" :disabled="templateBlocked" @click="savePlan">保存计划</el-button></template>
    </el-dialog>
  </section>
</template>

<style scoped>
.inspection-page{display:flex;flex-direction:column;gap:16px}.plan-cell{display:flex;flex-direction:column;gap:2px}.muted-code{color:#64748b;font-size:12px}.target-cell{display:flex;flex-direction:column;gap:3px}.device-target{font-weight:600;color:#1e293b}.template-target{color:#64748b;font-size:12px}.rule-hint{font-size:11px;color:#64748b;margin-top:2px}.highlight-time{color:#0284c7;font-weight:600}.plan-form{margin-top:18px}.plan-form :deep(.el-select),.plan-form :deep(.el-date-editor){width:100%}.inspection-page :deep(.el-pagination){justify-content:flex-end;margin-top:18px}.filter-card :deep(.el-select){width:230px}
</style>
