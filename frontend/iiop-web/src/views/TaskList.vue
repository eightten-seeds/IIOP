<script setup lang="ts">
import { onMounted, reactive, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { request } from '../api/request';
import { useAuthStore } from '../stores/auth';
import type { Device, PageResult, UserSummary } from '../types/device';
import type { InspectionTask, ResultStatus, TaskStatus } from '../types/inspection';
import { displayValue } from '../utils/display';

const TASK_STATUSES: TaskStatus[] = ['PENDING', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED'];
const RESULT_STATUSES: ResultStatus[] = ['UNKNOWN', 'PENDING', 'NORMAL', 'ABNORMAL'];
const auth = useAuthStore();
const route = useRoute();
const router = useRouter();
const rows = ref<InspectionTask[]>([]);
const total = ref(0);
const page = ref(1);
const pageSize = 20;
const loading = ref(false);
const errorMessage = ref('');
const filters = reactive<{ taskStatus: '' | TaskStatus; resultStatus: '' | ResultStatus; deviceId: string }>({ taskStatus: '', resultStatus: '', deviceId: '' });
const deviceOptions = ref<Device[]>([]);
const deviceLoading = ref(false);
const deviceNames = reactive<Record<string, string>>({});
const assigneeNames = reactive<Record<string, string>>({});
const pureInspector = () => auth.roles.includes('INSPECTOR') && !auth.roles.includes('ADMIN') && !auth.roles.includes('SUPER_ADMIN');
const dateTime = (value: string | null) => value ? value.replace('T', ' ').slice(0, 16) : '-';
const taskStatusLabel = (status: TaskStatus) => ({ PENDING: '待巡检', IN_PROGRESS: '巡检中', COMPLETED: '已完成', CANCELLED: '已取消' })[status];
const deviceLabel = (device: Device) => `${device.deviceName}（${device.deviceCode}）`;

function taskTag(status: TaskStatus) { return status === 'COMPLETED' ? 'success' : status === 'IN_PROGRESS' ? 'primary' : status === 'PENDING' ? 'warning' : 'info'; }
function resultTag(status: ResultStatus) { return status === 'ABNORMAL' ? 'danger' : status === 'NORMAL' ? 'success' : 'info'; }

async function searchDevices(keyword = '') {
  deviceLoading.value = true;
  try {
    const data = await request.get<never, PageResult<Device>>('/api/device/devices', { params: { pageNum: 1, pageSize: 20, keyword: keyword || undefined } });
    deviceOptions.value = data.records ?? [];
    deviceOptions.value.forEach(device => { deviceNames[device.id] = deviceLabel(device); });
  } finally { deviceLoading.value = false; }
}

async function ensureDevice(id: string) {
  if (!id || deviceOptions.value.some(device => device.id === id)) return;
  const device = await request.get<never, Device>(`/api/device/devices/${id}`);
  deviceOptions.value = [device, ...deviceOptions.value];
  deviceNames[id] = deviceLabel(device);
}

async function resolveNames(tasks: InspectionTask[]) {
  const deviceIds = [...new Set(tasks.map(task => task.deviceId))].filter(id => !deviceNames[id]);
  const assigneeIds = [...new Set(tasks.map(task => task.assigneeUserId))].filter(id => !assigneeNames[id]);
  if (auth.currentUser) assigneeNames[auth.currentUser.id] = `${auth.currentUser.realName || auth.currentUser.username}（${auth.currentUser.username}）`;
  const userRequests = auth.can('system:user:view') ? assigneeIds.map(async id => {
    try {
      const user = await request.get<never, UserSummary>(`/api/auth/users/${id}`, { silentStatuses: [404] });
      assigneeNames[id] = `${user.realName || user.username}（${user.username}）`;
    } catch (err: any) {
      if (err.response?.status === 404) {
        assigneeNames[id] = '原巡检员（账号已删除）';
      } else {
        assigneeNames[id] = '人员信息暂不可用';
      }
    }
  }) : [];
  await Promise.allSettled([
    ...deviceIds.map(async id => { const device = await request.get<never, Device>(`/api/device/devices/${id}`); deviceNames[id] = deviceLabel(device); }),
    ...userRequests
  ]);
}

async function load() {
  loading.value = true;
  errorMessage.value = '';
  try {
    const data = await request.get<never, PageResult<InspectionTask>>('/api/inspection/tasks', { params: {
      pageNum: page.value, pageSize, status: filters.taskStatus || undefined,
      resultStatus: filters.resultStatus || undefined, deviceId: filters.deviceId || undefined
    } });
    rows.value = data.records ?? [];
    total.value = data.total ?? 0;
    await resolveNames(rows.value);
  } catch { errorMessage.value = '巡检任务加载失败，请检查服务状态后重试。'; }
  finally { loading.value = false; }
}

function search() { page.value = 1; void load(); }
function resetFilters() { Object.assign(filters, { taskStatus: '', resultStatus: '', deviceId: '' }); void router.replace({ query: {} }); search(); }
function applyQuickStatus(value: '' | TaskStatus) { filters.taskStatus = value; search(); }

watch(() => route.query.deviceId, async value => {
  const id = typeof value === 'string' ? value : '';
  filters.deviceId = id;
  if (id) await ensureDevice(id);
  search();
});

onMounted(async () => {
  const id = typeof route.query.deviceId === 'string' ? route.query.deviceId : '';
  filters.deviceId = id;
  await Promise.all([searchDevices(''), id ? ensureDevice(id) : Promise.resolve()]);
  await load();
});
</script>

<template>
  <section class="inspection-page">
    <div class="page-head"><div><h1>{{ pureInspector() ? '我的巡检任务' : '巡检任务' }}</h1><p>{{ pureInspector() ? '查看分配给你的待执行、进行中和已完成任务。' : '查看全部巡检任务及其执行状态。' }}</p></div></div>
    <el-card class="quick-card" shadow="never">
      <span class="quick-label">任务视图</span>
      <el-radio-group :model-value="filters.taskStatus" @change="(value:string|number|boolean|undefined)=>applyQuickStatus(value as ''|TaskStatus)"><el-radio-button value="">全部</el-radio-button><el-radio-button value="PENDING">待执行</el-radio-button><el-radio-button value="IN_PROGRESS">进行中</el-radio-button><el-radio-button value="COMPLETED">已完成</el-radio-button></el-radio-group>
      <el-tag type="danger" effect="plain">逾期任务将在列表中醒目标记</el-tag>
    </el-card>
    <el-card class="filter-card" shadow="never"><el-form inline @submit.prevent="search">
      <el-form-item label="任务状态"><el-select v-model="filters.taskStatus" clearable placeholder="全部状态"><el-option v-for="status in TASK_STATUSES" :key="status" :label="taskStatusLabel(status)" :value="status" /></el-select></el-form-item>
      <el-form-item label="结果状态"><el-select v-model="filters.resultStatus" clearable placeholder="全部结果"><el-option v-for="status in RESULT_STATUSES" :key="status" :label="displayValue(status)" :value="status" /></el-select></el-form-item>
      <el-form-item label="设备"><el-select v-model="filters.deviceId" filterable remote clearable reserve-keyword :remote-method="searchDevices" :loading="deviceLoading" placeholder="按设备名称或编码搜索"><el-option v-for="device in deviceOptions" :key="device.id" :label="deviceLabel(device)" :value="device.id" /></el-select></el-form-item>
      <el-form-item><el-button type="primary" @click="search">查询</el-button><el-button @click="resetFilters">重置</el-button></el-form-item>
    </el-form></el-card>
    <el-card shadow="never">
      <el-alert v-if="errorMessage" :title="errorMessage" type="error" show-icon :closable="false"><template #default><el-button link type="primary" @click="load">重新加载</el-button></template></el-alert>
      <el-table v-else v-loading="loading" :data="rows" row-key="id">
        <el-table-column prop="taskCode" label="任务编号" min-width="170" />
        <el-table-column label="设备" min-width="210"><template #default="scope">{{ deviceNames[scope.row.deviceId] || '设备信息加载中' }}</template></el-table-column>
        <el-table-column label="巡检人员" min-width="170"><template #default="scope">{{ assigneeNames[scope.row.assigneeUserId] || '巡检人员' }}</template></el-table-column>
        <el-table-column label="任务状态" width="105"><template #default="scope"><el-tag :type="taskTag(scope.row.taskStatus)">{{ taskStatusLabel(scope.row.taskStatus) }}</el-tag></template></el-table-column>
        <el-table-column label="结果状态" width="100"><template #default="scope"><el-tag :type="resultTag(scope.row.resultStatus)" effect="plain">{{ displayValue(scope.row.resultStatus) }}</el-tag></template></el-table-column>
        <el-table-column label="计划开始" min-width="145"><template #default="scope">{{ dateTime(scope.row.scheduledStartTime) }}</template></el-table-column>
        <el-table-column label="计划结束" min-width="145"><template #default="scope">{{ dateTime(scope.row.scheduledEndTime) }}</template></el-table-column>
        <el-table-column label="完成进度" width="130"><template #default="scope"><el-progress :percentage="Number(scope.row.completionRate || 0)" :stroke-width="8" /></template></el-table-column>
        <el-table-column label="逾期" width="80"><template #default="scope"><el-tag v-if="scope.row.overdueFlag===1" type="danger">已逾期</el-tag><span v-else>-</span></template></el-table-column>
        <el-table-column label="操作" width="100" fixed="right"><template #default="scope"><el-button link type="primary" @click="router.push(`/inspection/tasks/${scope.row.id}`)">查看详情</el-button></template></el-table-column>
      </el-table>
      <el-empty v-if="!loading&&!errorMessage&&!rows.length" :description="pureInspector()?'当前没有分配给你的巡检任务':'暂无符合条件的巡检任务'" />
      <el-pagination v-if="!errorMessage&&total>pageSize" v-model:current-page="page" layout="prev, pager, next, total" :page-size="pageSize" :total="total" @current-change="load" />
    </el-card>
  </section>
</template>

<style scoped>
.inspection-page{display:flex;flex-direction:column;gap:16px}.quick-card :deep(.el-card__body){display:flex;align-items:center;gap:18px;flex-wrap:wrap}.quick-label{font-weight:600}.inspection-page :deep(.el-pagination){justify-content:flex-end;margin-top:18px}.filter-card :deep(.el-select){width:225px}
</style>
