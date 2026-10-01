<script setup lang="ts">
import { onMounted, reactive, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { request } from '../api/request';
import { useAuthStore } from '../stores/auth';
import type { Device, PageResult } from '../types/device';
import type { InspectionAbnormal, Severity, TaskDetailData } from '../types/inspection';
import { displayValue } from '../utils/display';

const SEVERITIES: Severity[] = ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL'];
const STATUSES = ['OPEN', 'PROCESSING', 'RESOLVED', 'CLOSED'];
const route = useRoute();
const router = useRouter();
const auth = useAuthStore();
const rows = ref<InspectionAbnormal[]>([]);
const total = ref(0);
const page = ref(1);
const pageSize = 20;
const loading = ref(false);
const errorMessage = ref('');
const filters = reactive<{ severity: '' | Severity; status: string; deviceId: string; taskId: string }>({ severity: '', status: '', deviceId: '', taskId: '' });
const deviceOptions = ref<Device[]>([]);
const deviceLoading = ref(false);
const deviceNames = reactive<Record<string, string>>({});
const taskCodes = reactive<Record<string, string>>({});
const pureInspector = () => auth.roles.includes('INSPECTOR') && !auth.roles.includes('ADMIN') && !auth.roles.includes('SUPER_ADMIN');
const deviceLabel = (device: Device) => `${device.deviceName}（${device.deviceCode}）`;
const dateTime = (value: string) => value ? value.replace('T', ' ').slice(0, 19) : '-';

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

async function resolveSources(abnormals: InspectionAbnormal[]) {
  const deviceIds = [...new Set(abnormals.map(value => value.deviceId))].filter(id => !deviceNames[id]);
  const taskIds = [...new Set(abnormals.map(value => value.taskId))].filter(id => !taskCodes[id]);
  await Promise.allSettled([
    ...deviceIds.map(async id => { const device = await request.get<never, Device>(`/api/device/devices/${id}`); deviceNames[id] = deviceLabel(device); }),
    ...taskIds.map(async id => { const detail = await request.get<never, TaskDetailData>(`/api/inspection/tasks/${id}`); taskCodes[id] = detail.task.taskCode; })
  ]);
}

async function load() {
  loading.value = true;
  errorMessage.value = '';
  try {
    const data = await request.get<never, PageResult<InspectionAbnormal>>('/api/inspection/abnormals', { params: {
      pageNum: page.value, pageSize, severity: filters.severity || undefined, status: filters.status || undefined,
      deviceId: filters.deviceId || undefined, taskId: filters.taskId || undefined
    } });
    rows.value = data.records ?? [];
    total.value = data.total ?? 0;
    await resolveSources(rows.value);
  } catch { errorMessage.value = '巡检异常加载失败，请检查服务状态后重试。'; }
  finally { loading.value = false; }
}

function applyQuery() {
  filters.deviceId = typeof route.query.deviceId === 'string' ? route.query.deviceId : '';
  filters.taskId = typeof route.query.taskId === 'string' ? route.query.taskId : '';
}
function search() { page.value = 1; void load(); }
function resetFilters() { Object.assign(filters, { severity: '', status: '', deviceId: '', taskId: '' }); void router.replace({ query: {} }); search(); }
function clearTaskContext() { filters.taskId = ''; void router.replace({ query: filters.deviceId ? { deviceId: filters.deviceId } : {} }); search(); }

watch(() => [route.query.deviceId, route.query.taskId], async () => {
  applyQuery();
  if (filters.deviceId) await ensureDevice(filters.deviceId);
  search();
});
onMounted(async () => { applyQuery(); await Promise.all([searchDevices(''), filters.deviceId ? ensureDevice(filters.deviceId) : Promise.resolve()]); await load(); });
</script>

<template>
  <section class="inspection-page">
    <div class="page-head"><div><h1>{{ pureInspector() ? '我的巡检异常' : '巡检异常' }}</h1><p>查看现场上报的异常事实及其来源任务，不在此维护第二套处理状态机。</p></div></div>
    <el-alert v-if="filters.taskId" title="当前仅显示指定巡检任务产生的异常" type="info" show-icon :closable="false"><template #default><el-button link type="primary" @click="clearTaskContext">清除任务范围</el-button></template></el-alert>
    <el-card class="filter-card" shadow="never"><el-form inline @submit.prevent="search">
      <el-form-item label="严重程度"><el-select v-model="filters.severity" clearable placeholder="全部等级"><el-option v-for="severity in SEVERITIES" :key="severity" :label="displayValue(severity)" :value="severity" /></el-select></el-form-item>
      <el-form-item label="异常状态"><el-select v-model="filters.status" clearable placeholder="全部状态"><el-option v-for="status in STATUSES" :key="status" :label="displayValue(status)" :value="status" /></el-select></el-form-item>
      <el-form-item label="设备"><el-select v-model="filters.deviceId" filterable remote clearable reserve-keyword :remote-method="searchDevices" :loading="deviceLoading" placeholder="按设备名称或编码搜索"><el-option v-for="device in deviceOptions" :key="device.id" :label="deviceLabel(device)" :value="device.id" /></el-select></el-form-item>
      <el-form-item><el-button type="primary" @click="search">查询</el-button><el-button @click="resetFilters">重置</el-button></el-form-item>
    </el-form></el-card>
    <el-card shadow="never">
      <el-alert v-if="errorMessage" :title="errorMessage" type="error" show-icon :closable="false"><template #default><el-button link type="primary" @click="load">重新加载</el-button></template></el-alert>
      <el-table v-else v-loading="loading" :data="rows" row-key="id">
        <el-table-column prop="abnormalCode" label="异常编号" min-width="165" /><el-table-column prop="title" label="异常标题" min-width="190" show-overflow-tooltip />
        <el-table-column label="设备" min-width="210"><template #default="scope">{{ deviceNames[scope.row.deviceId] || '设备信息加载中' }}</template></el-table-column>
        <el-table-column label="来源任务" min-width="170"><template #default="scope"><el-button link @click="router.push(`/inspection/tasks/${scope.row.taskId}`)">{{ taskCodes[scope.row.taskId] || '任务信息加载中' }}</el-button></template></el-table-column>
        <el-table-column label="严重程度" width="110"><template #default="scope"><el-tag :type="scope.row.severity==='CRITICAL'||scope.row.severity==='HIGH'?'danger':scope.row.severity==='MEDIUM'?'warning':'success'">{{ displayValue(scope.row.severity) }}</el-tag></template></el-table-column>
        <el-table-column label="状态" width="100"><template #default="scope">{{ displayValue(scope.row.status) }}</template></el-table-column><el-table-column label="上报时间" min-width="160"><template #default="scope">{{ dateTime(scope.row.reportedAt) }}</template></el-table-column>
        <el-table-column label="操作" width="100" fixed="right"><template #default="scope"><el-button link type="primary" @click="router.push(`/inspection/abnormals/${scope.row.id}`)">查看详情</el-button></template></el-table-column>
      </el-table>
      <el-empty v-if="!loading&&!errorMessage&&!rows.length" :description="pureInspector()?'当前没有你的巡检任务上报的异常':'暂无符合条件的巡检异常'" />
      <el-pagination v-if="!errorMessage&&total>pageSize" v-model:current-page="page" layout="prev, pager, next, total" :page-size="pageSize" :total="total" @current-change="load" />
    </el-card>
  </section>
</template>

<style scoped>
.inspection-page{display:flex;flex-direction:column;gap:16px}.inspection-page :deep(.el-pagination){justify-content:flex-end;margin-top:18px}.filter-card :deep(.el-select){width:225px}
</style>
