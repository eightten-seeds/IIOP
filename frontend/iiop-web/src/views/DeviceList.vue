<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, onUnmounted, reactive, ref } from 'vue';
import { onBeforeRouteLeave, useRouter } from 'vue-router';
import { ElMessage, ElMessageBox } from 'element-plus';
import { request } from '../api/request';
import { useAuthStore } from '../stores/auth';
import { displayValue } from '../utils/display';
import { categoryNameMap, categoryOptions, editableDeviceForm, emptyDeviceForm, type CategoryOption, type CategoryTree, type Device, type DeviceForm, type DeviceStatus, type PageResult, type RiskLevel, type UserSummary } from '../types/device';

const DEVICE_STATUSES: DeviceStatus[] = ['ONLINE', 'OFFLINE', 'FAULT', 'MAINTENANCE', 'SCRAPPED'];
const RISK_LEVELS: RiskLevel[] = ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL'];
const auth = useAuthStore();
const router = useRouter();
const rows = ref<Device[]>([]);
const total = ref(0);
const page = ref(1);
const pageSize = 20;
const loading = ref(false);
const errorMessage = ref('');
const deletingId = ref('');
const categoryTree = ref<CategoryTree[]>([]);
const categorySelect = ref<CategoryOption[]>([]);
const categoryNames = reactive<Record<string, string>>({});
const responsibleNames = reactive<Record<string, string>>({});
const filters = reactive<{ keyword: string; categoryId: string; status: '' | DeviceStatus; riskLevel: '' | RiskLevel }>({ keyword: '', categoryId: '', status: '', riskLevel: '' });

const formVisible = ref(false);
const editingId = ref('');
const formLoading = ref(false);
const saving = ref(false);
const form = reactive<DeviceForm>(emptyDeviceForm());
const initialSnapshot = ref('');
const formDirty = computed(() => formVisible.value && JSON.stringify(form) !== initialSnapshot.value);
const spatialSections = ref<string[]>([]);
const userOptions = ref<UserSummary[]>([]);
const userLoading = ref(false);

const formTitle = computed(() => editingId.value ? '编辑设备档案' : '新增设备');

function userLabel(user: UserSummary) {
  return user.realName ? `${user.realName}（${user.username}）` : user.username;
}

function statusTag(status: DeviceStatus) {
  return status === 'ONLINE' ? 'success' : status === 'FAULT' ? 'danger' : status === 'MAINTENANCE' ? 'warning' : 'info';
}

function riskTag(risk: RiskLevel) {
  return risk === 'CRITICAL' ? 'danger' : risk === 'HIGH' ? 'warning' : risk === 'MEDIUM' ? 'primary' : 'success';
}

async function ensureCategories() {
  if (categoryTree.value.length) return;
  const tree = await request.get<never, CategoryTree[]>('/api/device/categories/tree');
  categoryTree.value = tree ?? [];
  categorySelect.value = categoryOptions(categoryTree.value);
  Object.assign(categoryNames, categoryNameMap(categoryTree.value));
}

async function resolveResponsibleNames(devices: Device[]) {
  if (!auth.can('system:user:view')) return;
  const ids = [...new Set(devices.map((device) => device.responsibleUserId).filter((id): id is string => Boolean(id)))].filter((id) => !responsibleNames[id]);
  await Promise.allSettled(ids.map(async (id) => {
    try {
      const user = await request.get<never, UserSummary>(`/api/auth/users/${id}`, { silentStatuses: [404] });
      responsibleNames[id] = userLabel(user);
    } catch (err: any) {
      if (err.response?.status === 404) {
        responsibleNames[id] = '原负责人（账号已删除）';
      } else {
        responsibleNames[id] = '人员信息暂不可用';
      }
    }
  }));
}

function responsibleLabel(id: string | null) {
  if (!id) return '未指定';
  return responsibleNames[id] || (auth.can('system:user:view') ? '人员信息加载中' : '已指定负责人');
}

async function load() {
  loading.value = true;
  errorMessage.value = '';
  try {
    const [, data] = await Promise.all([
      ensureCategories(),
      request.get<never, PageResult<Device>>('/api/device/devices', {
        params: { pageNum: page.value, pageSize, keyword: filters.keyword || undefined, categoryId: filters.categoryId || undefined, status: filters.status || undefined, riskLevel: filters.riskLevel || undefined }
      })
    ]);
    rows.value = data.records ?? [];
    total.value = data.total ?? 0;
    await resolveResponsibleNames(rows.value);
  } catch {
    errorMessage.value = '设备列表加载失败，请检查服务状态后重试。';
  } finally {
    loading.value = false;
  }
}

function search() {
  page.value = 1;
  void load();
}

function resetFilters() {
  Object.assign(filters, { keyword: '', categoryId: '', status: '', riskLevel: '' });
  search();
}

async function searchUsers(keyword = '') {
  if (!auth.can('system:user:view')) return;
  userLoading.value = true;
  try {
    const data = await request.get<never, PageResult<UserSummary>>('/api/auth/users', { params: { pageNum: 1, pageSize: 20, status: 'ENABLED', keyword: keyword || undefined } });
    userOptions.value = data.records ?? [];
  } finally {
    userLoading.value = false;
  }
}

async function ensureResponsibleOption(id: string | null) {
  if (!id || userOptions.value.some((user) => user.id === id) || !auth.can('system:user:view')) return;
  try {
    const user = await request.get<never, UserSummary>(`/api/auth/users/${id}`, { silentStatuses: [404] });
    userOptions.value = [user, ...userOptions.value];
  } catch (err: any) {
    if (err.response?.status === 404) {
      responsibleNames[id] = '原负责人（账号已删除）';
    } else {
      responsibleNames[id] = '人员信息暂不可用';
    }
  }
}

async function openCreate() {
  editingId.value = '';
  Object.assign(form, emptyDeviceForm());
  spatialSections.value = [];
  await Promise.all([ensureCategories(), searchUsers('')]);
  initialSnapshot.value = JSON.stringify(form);
  formVisible.value = true;
}

async function openEdit(row: Device) {
  formLoading.value = true;
  editingId.value = row.id;
  try {
    const [device] = await Promise.all([
      request.get<never, Device>(`/api/device/devices/${row.id}`),
      ensureCategories(),
      searchUsers('')
    ]);
    Object.assign(form, emptyDeviceForm(), editableDeviceForm(device));
    await ensureResponsibleOption(device.responsibleUserId);
    spatialSections.value = device.modelUrl || device.positionX != null || device.positionY != null || device.positionZ != null ? ['spatial'] : [];
    initialSnapshot.value = JSON.stringify(form);
    formVisible.value = true;
  } finally {
    formLoading.value = false;
  }
}

async function beforeCloseDevice(done: () => void) {
  if (saving.value) return;
  if (!formDirty.value) return done();
  try {
    await ElMessageBox.confirm('设备档案尚未保存，确定放弃吗？', '放弃编辑', { type: 'warning' });
    done();
  } catch { /* 保留表单 */ }
}

async function saveDevice() {
  if (saving.value) return;
  if (!form.deviceCode.trim() || !form.deviceName.trim()) return void ElMessage.warning('请填写设备编码和设备名称');
  if (!form.categoryId) return void ElMessage.warning('请选择设备分类');
  saving.value = true;
  try {
    const payload: DeviceForm = { ...form, responsibleUserId: form.responsibleUserId || null };
    if (editingId.value) await request.put(`/api/device/devices/${editingId.value}`, payload);
    else await request.post('/api/device/devices', payload);
    ElMessage.success(editingId.value ? '设备档案更新成功' : '设备创建成功');
    initialSnapshot.value = JSON.stringify(form);
    formVisible.value = false;
    await load();
  } finally {
    saving.value = false;
  }
}

async function deleteDevice(row: Device) {
  if (deletingId.value) return;
  try {
    await ElMessageBox.confirm(`确认删除设备“${row.deviceName}（${row.deviceCode}）”吗？不会自动级联删除关联业务数据。`, '删除设备', { type: 'error', confirmButtonText: '删除', cancelButtonText: '取消' });
  } catch { return; }
  deletingId.value = row.id;
  try {
    await request.delete(`/api/device/devices/${row.id}`);
    ElMessage.success('设备已删除');
    if (rows.value.length === 1 && page.value > 1) page.value -= 1;
    await load();
  } finally {
    deletingId.value = '';
  }
}

function beforeUnload(event: BeforeUnloadEvent) {
  if (!formDirty.value) return;
  event.preventDefault();
  event.returnValue = '';
}

onBeforeRouteLeave(async () => {
  if (!formDirty.value) return true;
  try {
    await ElMessageBox.confirm('设备档案尚未保存，确定离开当前页面吗？', '未保存修改', {
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
  <section class="device-page">
    <div class="page-head">
      <div><h1>设备档案</h1><p>集中查看设备状态、风险与责任信息；管理操作按权限开放。</p></div>
      <div class="head-actions">
        <el-button @click="router.push('/devices/scene')">设备空间视图</el-button>
        <el-button v-if="auth.can('device:create')" type="primary" @click="openCreate">新增设备</el-button>
      </div>
    </div>

    <el-card class="filter-card" shadow="never">
      <el-form inline @submit.prevent="search">
        <el-form-item label="关键词"><el-input v-model="filters.keyword" clearable placeholder="设备编码或名称" @keyup.enter="search" /></el-form-item>
        <el-form-item label="设备分类"><el-tree-select v-model="filters.categoryId" :data="categorySelect" clearable check-strictly placeholder="全部分类" /></el-form-item>
        <el-form-item label="设备状态"><el-select v-model="filters.status" clearable placeholder="全部状态"><el-option v-for="status in DEVICE_STATUSES" :key="status" :label="displayValue(status)" :value="status" /></el-select></el-form-item>
        <el-form-item label="风险等级"><el-select v-model="filters.riskLevel" clearable placeholder="全部风险"><el-option v-for="risk in RISK_LEVELS" :key="risk" :label="displayValue(risk)" :value="risk" /></el-select></el-form-item>
        <el-form-item><el-button type="primary" @click="search">查询</el-button><el-button @click="resetFilters">重置</el-button></el-form-item>
      </el-form>
    </el-card>

    <el-card shadow="never">
      <el-alert v-if="errorMessage" :title="errorMessage" type="error" show-icon :closable="false"><template #default><el-button link type="primary" @click="load">重新加载</el-button></template></el-alert>
      <el-table v-else v-loading="loading" :data="rows" row-key="id">
        <el-table-column label="设备信息" min-width="210">
          <template #default="scope">
            <div class="device-identity">
              <strong class="device-name">{{ scope.row.deviceName }}</strong>
              <span class="device-code">{{ scope.row.deviceCode }}</span>
            </div>
          </template>
        </el-table-column>
        <el-table-column label="分类" min-width="130"><template #default="scope">{{ categoryNames[scope.row.categoryId] || '未知分类' }}</template></el-table-column>
        <el-table-column prop="model" label="型号" min-width="120"><template #default="scope">{{ scope.row.model || '-' }}</template></el-table-column>
        <el-table-column label="区域与位置" min-width="180">
          <template #default="scope">
            <span>{{ [scope.row.workshop, scope.row.installLocation].filter(Boolean).join(' · ') || '-' }}</span>
          </template>
        </el-table-column>
        <el-table-column label="运行状态" width="115">
          <template #default="scope">
            <el-tag :type="statusTag(scope.row.status)" :effect="scope.row.status==='FAULT'?'dark':'light'">
              {{ displayValue(scope.row.status) }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="安全风险" width="115">
          <template #default="scope">
            <el-tag :type="riskTag(scope.row.riskLevel)" :effect="scope.row.riskLevel==='CRITICAL'?'dark':'plain'">
              {{ displayValue(scope.row.riskLevel) }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="责任人" min-width="160"><template #default="scope">{{ responsibleLabel(scope.row.responsibleUserId) }}</template></el-table-column>
        <el-table-column label="核心操作" width="220" fixed="right"><template #default="scope">
          <el-button link type="primary" @click="router.push(`/devices/${scope.row.id}`)">查看详情</el-button>
          <el-button v-if="auth.can('device:update')" link :loading="formLoading && editingId===scope.row.id" @click="openEdit(scope.row)">编辑</el-button>
          <el-button v-if="auth.can('device:delete')" link type="danger" :loading="deletingId===scope.row.id" @click="deleteDevice(scope.row)">删除</el-button>
        </template></el-table-column>
      </el-table>
      <el-empty v-if="!loading&&!errorMessage&&!rows.length" description="暂无符合条件的设备档案"><el-button v-if="auth.can('device:create')" type="primary" @click="openCreate">新增第一台设备</el-button></el-empty>
      <el-pagination v-if="!errorMessage&&total>pageSize" v-model:current-page="page" layout="prev, pager, next, total" :page-size="pageSize" :total="total" @current-change="load" />
    </el-card>

    <el-dialog v-model="formVisible" :title="formTitle" width="920px" :close-on-click-modal="!saving" :before-close="beforeCloseDevice">
      <el-form label-width="110px" class="device-form">
        <el-row :gutter="18">
          <el-col :span="12"><el-form-item label="设备编码" required><el-input v-model="form.deviceCode" :disabled="saving" /></el-form-item></el-col>
          <el-col :span="12"><el-form-item label="设备名称" required><el-input v-model="form.deviceName" :disabled="saving" /></el-form-item></el-col>
          <el-col :span="12"><el-form-item label="设备分类" required><el-tree-select v-model="form.categoryId" :data="categorySelect" check-strictly filterable :disabled="saving" placeholder="请选择分类" /></el-form-item></el-col>
          <el-col :span="12"><el-form-item label="负责人"><el-select v-model="form.responsibleUserId" filterable remote clearable reserve-keyword :remote-method="searchUsers" :loading="userLoading" :disabled="saving" placeholder="按姓名或用户名搜索"><el-option v-for="user in userOptions" :key="user.id" :label="userLabel(user)" :value="user.id" /></el-select></el-form-item></el-col>
          <el-col :span="12"><el-form-item label="设备型号"><el-input v-model="form.model" :disabled="saving" /></el-form-item></el-col>
          <el-col :span="12"><el-form-item label="制造商"><el-input v-model="form.manufacturer" :disabled="saving" /></el-form-item></el-col>
          <el-col :span="12"><el-form-item label="序列号"><el-input v-model="form.serialNumber" :disabled="saving" /></el-form-item></el-col>
          <el-col :span="12"><el-form-item label="安装位置"><el-input v-model="form.installLocation" :disabled="saving" /></el-form-item></el-col>
          <el-col :span="12"><el-form-item label="车间"><el-input v-model="form.workshop" :disabled="saving" /></el-form-item></el-col>
          <el-col :span="12"><el-form-item label="生产线"><el-input v-model="form.productionLine" :disabled="saving" /></el-form-item></el-col>
          <el-col :span="12"><el-form-item label="设备状态" required><el-select v-model="form.status" :disabled="saving"><el-option v-for="status in DEVICE_STATUSES" :key="status" :label="displayValue(status)" :value="status" /></el-select></el-form-item></el-col>
          <el-col :span="12"><el-form-item label="风险等级" required><el-select v-model="form.riskLevel" :disabled="saving"><el-option v-for="risk in RISK_LEVELS" :key="risk" :label="displayValue(risk)" :value="risk" /></el-select></el-form-item></el-col>
          <el-col :span="12"><el-form-item label="安装日期"><el-date-picker v-model="form.installDate" type="date" value-format="YYYY-MM-DD" clearable :disabled="saving" /></el-form-item></el-col>
          <el-col :span="12"><el-form-item label="质保截止"><el-date-picker v-model="form.warrantyExpireDate" type="date" value-format="YYYY-MM-DD" clearable :disabled="saving" /></el-form-item></el-col>
          <el-col :span="24"><el-form-item label="备注"><el-input v-model="form.remark" type="textarea" :rows="3" :disabled="saving" /></el-form-item></el-col>
        </el-row>
        <el-collapse v-model="spatialSections"><el-collapse-item title="空间 / 模型信息（供后续 Three.js 使用）" name="spatial"><el-row :gutter="18">
          <el-col :span="24"><el-form-item label="模型地址"><el-input v-model="form.modelUrl" :disabled="saving" placeholder="可选 glTF / glb 地址" /></el-form-item></el-col>
          <el-col :span="8"><el-form-item label="X 坐标"><el-input-number v-model="form.positionX" :precision="3" controls-position="right" :disabled="saving" /></el-form-item></el-col>
          <el-col :span="8"><el-form-item label="Y 坐标"><el-input-number v-model="form.positionY" :precision="3" controls-position="right" :disabled="saving" /></el-form-item></el-col>
          <el-col :span="8"><el-form-item label="Z 坐标"><el-input-number v-model="form.positionZ" :precision="3" controls-position="right" :disabled="saving" /></el-form-item></el-col>
        </el-row></el-collapse-item></el-collapse>
      </el-form>
      <template #footer><el-button :disabled="saving" @click="beforeCloseDevice(() => { formVisible = false; })">取消</el-button><el-button type="primary" :loading="saving" @click="saveDevice">保存设备</el-button></template>
    </el-dialog>
  </section>
</template>

<style scoped>
.device-page{display:flex;flex-direction:column;gap:16px}.device-identity{display:flex;flex-direction:column;gap:2px}.device-name{color:#1e293b;font-size:14px;font-weight:600}.device-code{color:#64748b;font-size:12px}.device-form :deep(.el-select),.device-form :deep(.el-tree-select),.device-form :deep(.el-date-editor){width:100%}.device-form :deep(.el-input-number){width:100%}.device-form :deep(.el-collapse){border-top:0}.device-form :deep(.el-collapse-item__header){font-weight:600;color:#344054}
</style>
