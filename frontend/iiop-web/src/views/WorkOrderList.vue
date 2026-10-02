<script setup lang="ts">
import { computed, onMounted, reactive, ref } from 'vue';
import { useRouter } from 'vue-router';
import { request } from '../api/request';
import { useAuthStore } from '../stores/auth';
import type { Device, PageResult, UserSummary } from '../types/device';
import type { WorkOrder } from '../types/maintenance';
import { displayValue } from '../utils/display';

const router = useRouter();
const auth = useAuthStore();
const rows = ref<WorkOrder[]>([]);
const total = ref(0);
const page = ref(1);
const loading = ref(false);
const errorMessage = ref('');
const deviceOptions = ref<Device[]>([]);
const maintainers = ref<UserSummary[]>([]);
const pageSize = 20;
const deviceNames = reactive<Record<string, string>>({});
const userNames = reactive<Record<string, string>>({});
const defectNames = reactive<Record<string, string>>({});
const filters = reactive({ status: '', priority: '', deviceId: '', assigneeUserId: '' });
const activeTab = ref('ALL');

const isAdmin = computed(() => auth.roles.includes('ADMIN') || auth.roles.includes('SUPER_ADMIN'));
const isPureMaintainer = computed(() => auth.roles.includes('MAINTAINER') && !isAdmin.value);

const dateTime = (v: string | null) => (v ? v.replace('T', ' ').slice(0, 19) : '-');
const deviceLabel = (d: Device) => `${d.deviceName}（${d.deviceCode}）`;
const userLabel = (u: UserSummary) => (u.realName ? `${u.realName}（${u.username}）` : u.username);

async function searchDevices(keyword = '') {
  const p = await request.get<never, PageResult<Device>>('/api/device/devices', {
    params: { pageNum: 1, pageSize: 20, keyword: keyword || undefined }
  });
  deviceOptions.value = p.records ?? [];
  deviceOptions.value.forEach((d) => (deviceNames[d.id] = deviceLabel(d)));
}

async function searchMaintainers(keyword = '') {
  if (!auth.can('system:user:view')) return;
  const p = await request.get<never, PageResult<UserSummary>>('/api/auth/users', {
    params: { pageNum: 1, pageSize: 20, keyword: keyword || undefined, status: 'ENABLED', roleCode: 'MAINTAINER' }
  });
  maintainers.value = p.records ?? [];
  maintainers.value.forEach((u) => (userNames[u.id] = userLabel(u)));
}

async function resolveRelations(data: WorkOrder[]) {
  await Promise.allSettled([
    ...[...new Set(data.map((x) => x.deviceId))].filter((id) => !deviceNames[id]).map(async (id) => {
      const d = await request.get<never, Device>(`/api/device/devices/${id}`, { silentStatuses: [404] });
      deviceNames[id] = deviceLabel(d);
    })
  ]);
  await Promise.allSettled([
    ...[...new Set(data.map((x) => x.defectId).filter(Boolean) as string[])].filter((id) => !defectNames[id]).map(async (id) => {
      try {
        const d = await request.get<never, import('../types/maintenance').Defect>(`/api/maintenance/defects/${id}`, { silentStatuses: [404] });
        defectNames[id] = `${d.defectCode} · ${d.title}`;
      } catch (e: any) {
        defectNames[id] = e.response?.status === 404 ? '原缺陷（已不存在）' : '缺陷信息暂不可用';
      }
    })
  ]);
  if (auth.can('system:user:view')) {
    await Promise.allSettled([
      ...[...new Set(data.map((x) => x.assigneeUserId).filter(Boolean) as string[])].filter((id) => !userNames[id]).map(async (id) => {
        try {
          const u = await request.get<never, UserSummary>(`/api/auth/users/${id}`, { silentStatuses: [404] });
          userNames[id] = userLabel(u);
        } catch (e: any) {
          userNames[id] = e.response?.status === 404 ? '原维修人员（账号已删除）' : '人员信息暂不可用';
        }
      })
    ]);
  }
}

async function load() {
  loading.value = true;
  errorMessage.value = '';
  try {
    const p = await request.get<never, PageResult<WorkOrder>>('/api/maintenance/work-orders', {
      params: {
        pageNum: page.value,
        pageSize,
        ...Object.fromEntries(Object.entries(filters).map(([k, v]) => [k, v || undefined]))
      }
    });
    rows.value = p.records ?? [];
    total.value = p.total ?? 0;
    await resolveRelations(rows.value);
  } catch {
    errorMessage.value = '维修工单列表加载失败，请稍后重试。';
  } finally {
    loading.value = false;
  }
}

function handleTabChange(tabVal: string | number | undefined) {
  const val = String(tabVal);
  activeTab.value = val;
  filters.status = val === 'ALL' ? '' : val;
  page.value = 1;
  void load();
}

function search() {
  activeTab.value = filters.status || 'ALL';
  page.value = 1;
  void load();
}

function reset() {
  activeTab.value = 'ALL';
  Object.assign(filters, { status: '', priority: '', deviceId: '', assigneeUserId: '' });
  search();
}

function actionLabel(row: WorkOrder) {
  if (row.status === 'ASSIGNED' && row.assigneeUserId === auth.currentUser?.id) return '前往开工';
  if (row.status === 'PROCESSING' && row.assigneeUserId === auth.currentUser?.id) return '录入结果';
  if (row.status === 'WAITING_ACCEPTANCE' && isAdmin.value) return '前往验收';
  if (row.status === 'PENDING' && isAdmin.value) return '前往分派';
  return '查看详情';
}

function emptyDescription() {
  if (isPureMaintainer.value && activeTab.value === 'ASSIGNED') return '当前暂无待您开工的工单';
  if (isAdmin.value && activeTab.value === 'WAITING_ACCEPTANCE') return '当前暂无待您验收的工单';
  if (isAdmin.value && activeTab.value === 'PENDING') return '当前暂无待分派的工单';
  return '暂无符合条件的维修工单';
}

onMounted(() => {
  void searchDevices();
  void searchMaintainers();
  void load();
});
</script>

<template>
  <section class="business-page">
    <div class="page-head">
      <div>
        <h1>{{ isPureMaintainer ? '我的维修工单' : '维修工单' }}</h1>
        <p>
          {{
            isPureMaintainer
              ? '查看由您负责处理的工单，完成现场检修后录入原因、备件与工时并提交验收。'
              : '管理全厂设备维修工单，指派维修人员、监督维修进展并在完成后严格组织验收闭环。'
          }}
        </p>
      </div>
    </div>

    <!-- Quick Role Tabs -->
    <el-tabs v-model="activeTab" type="card" class="quick-tabs" @tab-change="handleTabChange">
      <el-tab-pane label="全部工单" name="ALL" />
      <template v-if="isAdmin">
        <el-tab-pane label="待分派" name="PENDING" />
        <el-tab-pane label="维修处理中" name="PROCESSING" />
        <el-tab-pane label="待我验收" name="WAITING_ACCEPTANCE" />
        <el-tab-pane label="已完结" name="COMPLETED" />
      </template>
      <template v-else>
        <el-tab-pane label="待我开工" name="ASSIGNED" />
        <el-tab-pane label="维修处理中" name="PROCESSING" />
        <el-tab-pane label="待验收" name="WAITING_ACCEPTANCE" />
        <el-tab-pane label="已完结" name="COMPLETED" />
      </template>
    </el-tabs>

    <el-card shadow="never" class="filter-card">
      <el-form inline @submit.prevent="search">
        <el-form-item label="优先级">
          <el-select v-model="filters.priority" clearable placeholder="全部优先级">
            <el-option v-for="x in ['LOW', 'MEDIUM', 'HIGH', 'URGENT']" :key="x" :label="displayValue(x)" :value="x" />
          </el-select>
        </el-form-item>
        <el-form-item label="设备">
          <el-select
            v-model="filters.deviceId"
            filterable
            remote
            clearable
            :remote-method="searchDevices"
            placeholder="按设备名称或编码搜索"
          >
            <el-option v-for="d in deviceOptions" :key="d.id" :label="deviceLabel(d)" :value="d.id" />
          </el-select>
        </el-form-item>
        <el-form-item v-if="auth.can('system:user:view')" label="维修人员">
          <el-select
            v-model="filters.assigneeUserId"
            filterable
            remote
            clearable
            :remote-method="searchMaintainers"
            placeholder="全部维修人员"
          >
            <el-option v-for="u in maintainers" :key="u.id" :label="userLabel(u)" :value="u.id" />
          </el-select>
        </el-form-item>
        <el-form-item>
          <el-button type="primary" @click="search">查询</el-button>
          <el-button @click="reset">重置</el-button>
        </el-form-item>
      </el-form>
    </el-card>

    <el-card shadow="never">
      <el-alert v-if="errorMessage" :title="errorMessage" type="error" show-icon :closable="false">
        <template #default><el-button link @click="load">重新加载</el-button></template>
      </el-alert>

      <el-table v-else v-loading="loading" :data="rows" row-key="id">
        <el-table-column prop="workOrderCode" label="工单编号" min-width="170" />
        <el-table-column prop="title" label="工单标题" min-width="190" show-overflow-tooltip />
        <el-table-column label="设备" min-width="210">
          <template #default="s">{{ deviceNames[s.row.deviceId] || '设备信息加载中' }}</template>
        </el-table-column>
        <el-table-column label="关联缺陷" min-width="200" show-overflow-tooltip>
          <template #default="s">
            <span v-if="s.row.defectId">{{ defectNames[s.row.defectId] || '缺陷信息加载中' }}</span>
            <span v-else class="text-muted">无关联缺陷</span>
          </template>
        </el-table-column>
        <el-table-column label="优先级" width="95">
          <template #default="s">
            <el-tag :type="s.row.priority === 'URGENT' || s.row.priority === 'HIGH' ? 'danger' : 'info'">
              {{ displayValue(s.row.priority) }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="状态" width="115">
          <template #default="s">
            <el-tag>{{ displayValue(s.row.status) }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="维修人员" min-width="160">
          <template #default="s">
            <template v-if="!s.row.assigneeUserId">
              <el-tag type="info" size="small">待分派</el-tag>
            </template>
            <template v-else-if="auth.currentUser?.id === s.row.assigneeUserId">
              <el-tag type="success" size="small">本人负责</el-tag>
              <span class="user-inline">{{ auth.currentUser?.realName || auth.currentUser?.username }}</span>
            </template>
            <template v-else>
              <span>{{ userNames[s.row.assigneeUserId] || (auth.can('system:user:view') ? '加载中' : '已分派') }}</span>
            </template>
          </template>
        </el-table-column>
        <el-table-column label="创建时间" min-width="165">
          <template #default="s">{{ dateTime(s.row.createdAt) }}</template>
        </el-table-column>
        <el-table-column label="操作" width="110" fixed="right">
          <template #default="s">
            <el-button link type="primary" @click="router.push(`/maintenance/work-orders/${s.row.id}`)">
              {{ actionLabel(s.row) }}
            </el-button>
          </template>
        </el-table-column>
      </el-table>

      <el-empty v-if="!loading && !errorMessage && !rows.length" :description="emptyDescription()" />
      <el-pagination
        v-if="!errorMessage && total > pageSize"
        v-model:current-page="page"
        :total="total"
        :page-size="pageSize"
        layout="prev, pager, next, total"
        @current-change="load"
      />
    </el-card>
  </section>
</template>

<style scoped>
.business-page {
  display: flex;
  flex-direction: column;
  gap: 16px;
}
.quick-tabs {
  margin-bottom: -6px;
}
.filter-card :deep(.el-select) {
  width: 210px;
}
.business-page :deep(.el-pagination) {
  justify-content: flex-end;
  margin-top: 18px;
}
.text-muted {
  color: var(--el-text-color-secondary);
}
.user-inline {
  margin-left: 6px;
  font-size: 13px;
}
</style>
