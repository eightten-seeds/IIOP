<script setup lang="ts">
import { computed, reactive, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { ElMessage } from 'element-plus';
import { request } from '../api/request';
import { useAuthStore } from '../stores/auth';
import { displayValue } from '../utils/display';
import { categoryNameMap, type CategoryTree, type Device, type DeviceStatus, type Metric, type RiskLevel, type Sop, type UserSummary } from '../types/device';

const DEVICE_STATUSES: DeviceStatus[] = ['ONLINE', 'OFFLINE', 'FAULT', 'MAINTENANCE', 'SCRAPPED'];
const RISK_LEVELS: RiskLevel[] = ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL'];
const route = useRoute();
const router = useRouter();
const auth = useAuthStore();
const device = ref<Device | null>(null);
const metrics = ref<Metric[]>([]);
const sops = ref<Sop[]>([]);
const categoryNames = reactive<Record<string, string>>({});
const responsibleName = ref('');
const loading = ref(false);
const errorMessage = ref('');
const statusRiskVisible = ref(false);
const saving = ref(false);
const statusRisk = reactive<{ status: DeviceStatus; riskLevel: RiskLevel }>({ status: 'OFFLINE', riskLevel: 'LOW' });

const deviceId = computed(() => String(route.params.id ?? ''));
const categoryName = computed(() => device.value ? categoryNames[device.value.categoryId] || '未知分类' : '-');
const responsibleLabel = computed(() => {
  if (!device.value?.responsibleUserId) return '未指定';
  if (responsibleName.value) return responsibleName.value;
  return auth.can('system:user:view') ? '人员信息加载中' : '已指定负责人';
});

function userLabel(user: UserSummary) {
  return user.realName ? `${user.realName}（${user.username}）` : user.username;
}

function threshold(low: number | null, high: number | null) {
  if (low == null && high == null) return '-';
  if (low != null && high != null) return `${low} ～ ${high}`;
  return low != null ? `≥ ${low}` : `≤ ${high}`;
}

async function load() {
  loading.value = true;
  errorMessage.value = '';
  responsibleName.value = '';
  try {
    const [current, tree, metricRows, sopRows] = await Promise.all([
      request.get<never, Device>(`/api/device/devices/${deviceId.value}`),
      request.get<never, CategoryTree[]>('/api/device/categories/tree'),
      request.get<never, Metric[]>(`/api/device/devices/${deviceId.value}/metrics`),
      request.get<never, Sop[]>(`/api/device/devices/${deviceId.value}/sops`)
    ]);
    device.value = current;
    metrics.value = metricRows ?? [];
    sops.value = sopRows ?? [];
    Object.keys(categoryNames).forEach((key) => delete categoryNames[key]);
    Object.assign(categoryNames, categoryNameMap(tree ?? []));
    if (current.responsibleUserId && auth.can('system:user:view')) {
      try {
        const user = await request.get<never, UserSummary>(`/api/auth/users/${current.responsibleUserId}`);
        responsibleName.value = userLabel(user);
      } catch {
        responsibleName.value = '负责人信息暂不可用';
      }
    }
  } catch {
    device.value = null;
    metrics.value = [];
    sops.value = [];
    errorMessage.value = '设备详情加载失败，设备可能不存在或服务暂不可用。';
  } finally {
    loading.value = false;
  }
}

function openStatusRisk() {
  if (!device.value) return;
  Object.assign(statusRisk, { status: device.value.status, riskLevel: device.value.riskLevel });
  statusRiskVisible.value = true;
}

async function saveStatusRisk() {
  if (!device.value) return;
  saving.value = true;
  try {
    await request.put(`/api/device/devices/${device.value.id}/status-risk`, { ...statusRisk });
    ElMessage.success('设备状态与风险已更新');
    statusRiskVisible.value = false;
    await load();
  } finally {
    saving.value = false;
  }
}

function related(path: string) {
  if (!device.value) return;
  void router.push({ path, query: { deviceId: device.value.id } });
}

watch(() => route.params.id, load, { immediate: true });
</script>

<template>
  <section class="device-detail-page">
    <div class="page-head">
      <div><el-button link @click="router.push('/devices')">← 返回设备列表</el-button><h1>{{ device?.deviceName || '设备详情' }}</h1><p v-if="device">{{ device.deviceCode }} · {{ categoryName }}</p></div>
      <el-button v-if="device&&auth.can('device:update')" type="primary" :disabled="loading" @click="openStatusRisk">更新状态与风险</el-button>
    </div>

    <el-skeleton v-if="loading" :rows="10" animated />
    <el-alert v-else-if="errorMessage" :title="errorMessage" type="error" show-icon :closable="false"><template #default><el-button link type="primary" @click="load">重新加载</el-button><el-button link @click="router.push('/devices')">返回列表</el-button></template></el-alert>
    <template v-else-if="device">
      <el-card shadow="never">
        <template #header><div class="card-title"><span>基础档案</span><div><el-tag :type="device.status==='ONLINE'?'success':device.status==='FAULT'?'danger':device.status==='MAINTENANCE'?'warning':'info'">{{ displayValue(device.status) }}</el-tag><el-tag :type="device.riskLevel==='CRITICAL'?'danger':device.riskLevel==='HIGH'?'warning':device.riskLevel==='MEDIUM'?'primary':'success'" effect="plain">{{ displayValue(device.riskLevel) }}</el-tag></div></div></template>
        <el-descriptions :column="3" border>
          <el-descriptions-item label="设备编码">{{ device.deviceCode }}</el-descriptions-item>
          <el-descriptions-item label="设备名称">{{ device.deviceName }}</el-descriptions-item>
          <el-descriptions-item label="设备分类">{{ categoryName }}</el-descriptions-item>
          <el-descriptions-item label="型号">{{ device.model || '-' }}</el-descriptions-item>
          <el-descriptions-item label="制造商">{{ device.manufacturer || '-' }}</el-descriptions-item>
          <el-descriptions-item label="序列号">{{ device.serialNumber || '-' }}</el-descriptions-item>
          <el-descriptions-item label="车间">{{ device.workshop || '-' }}</el-descriptions-item>
          <el-descriptions-item label="生产线">{{ device.productionLine || '-' }}</el-descriptions-item>
          <el-descriptions-item label="安装位置">{{ device.installLocation || '-' }}</el-descriptions-item>
          <el-descriptions-item label="负责人">{{ responsibleLabel }}</el-descriptions-item>
          <el-descriptions-item label="安装日期">{{ device.installDate || '-' }}</el-descriptions-item>
          <el-descriptions-item label="质保截止">{{ device.warrantyExpireDate || '-' }}</el-descriptions-item>
          <el-descriptions-item label="备注" :span="3">{{ device.remark || '暂无备注' }}</el-descriptions-item>
        </el-descriptions>
      </el-card>

      <el-card shadow="never">
        <template #header><div class="card-title"><span>关联业务入口</span><small>目标列表将携带当前 deviceId 筛选条件</small></div></template>
        <div class="related-actions">
          <el-button v-if="auth.can('inspection:view')" @click="related('/inspection/tasks')">巡检任务</el-button>
          <el-button v-if="auth.can('inspection:view')" @click="related('/inspection/abnormals')">巡检异常</el-button>
          <el-button v-if="auth.can('maintenance:view')" @click="related('/maintenance/defects')">维修缺陷</el-button>
          <el-button v-if="auth.can('maintenance:view')" @click="related('/maintenance/work-orders')">维修工单</el-button>
          <el-button v-if="auth.can('ai:view')" @click="related('/ai/diagnoses')">AI 诊断</el-button>
        </div>
        <el-alert title="最近巡检与维修摘要暂不在浏览器调用 internal API；请通过上方真实业务入口查看。" type="info" :closable="false" show-icon />
      </el-card>

      <el-card shadow="never">
        <template #header><div class="card-title"><span>监测指标</span><small>结构化查看当前设备指标定义</small></div></template>
        <el-table v-if="metrics.length" :data="metrics" row-key="id">
          <el-table-column prop="metricCode" label="指标编码" min-width="135" />
          <el-table-column prop="metricName" label="指标名称" min-width="150" />
          <el-table-column label="类型" width="100"><template #default="scope">{{ displayValue(scope.row.valueType) }}</template></el-table-column>
          <el-table-column prop="unit" label="单位" width="90"><template #default="scope">{{ scope.row.unit || '-' }}</template></el-table-column>
          <el-table-column label="预警范围" min-width="140"><template #default="scope">{{ threshold(scope.row.warningLow, scope.row.warningHigh) }}</template></el-table-column>
          <el-table-column label="严重范围" min-width="140"><template #default="scope">{{ threshold(scope.row.criticalLow, scope.row.criticalHigh) }}</template></el-table-column>
          <el-table-column label="状态" width="100"><template #default="scope"><el-tag :type="scope.row.status==='ENABLED'?'success':'info'">{{ displayValue(scope.row.status) }}</el-tag></template></el-table-column>
        </el-table>
        <el-empty v-else description="该设备尚未配置监测指标" />
      </el-card>

      <el-card shadow="never">
        <template #header><div class="card-title"><span>适用 SOP</span><small>设备专属与分类通用的生效规程</small></div></template>
        <el-table v-if="sops.length" :data="sops" row-key="id">
          <el-table-column prop="sopCode" label="SOP 编码" min-width="140" />
          <el-table-column prop="title" label="标题" min-width="220" />
          <el-table-column label="类型" width="120"><template #default="scope">{{ displayValue(scope.row.sopType) }}</template></el-table-column>
          <el-table-column prop="version" label="版本" width="100" />
          <el-table-column label="状态" width="100"><template #default="scope"><el-tag :type="scope.row.status==='EFFECTIVE'?'success':'info'">{{ displayValue(scope.row.status) }}</el-tag></template></el-table-column>
          <el-table-column prop="effectiveDate" label="生效日期" width="130"><template #default="scope">{{ scope.row.effectiveDate || '-' }}</template></el-table-column>
        </el-table>
        <el-empty v-else description="该设备暂无适用的生效 SOP" />
      </el-card>
    </template>

    <el-dialog v-model="statusRiskVisible" title="更新设备状态与风险" width="480px" :close-on-click-modal="!saving">
      <el-form label-width="100px">
        <el-form-item label="设备状态"><el-select v-model="statusRisk.status" :disabled="saving"><el-option v-for="status in DEVICE_STATUSES" :key="status" :label="displayValue(status)" :value="status" /></el-select></el-form-item>
        <el-form-item label="风险等级"><el-select v-model="statusRisk.riskLevel" :disabled="saving"><el-option v-for="risk in RISK_LEVELS" :key="risk" :label="displayValue(risk)" :value="risk" /></el-select></el-form-item>
      </el-form>
      <template #footer><el-button :disabled="saving" @click="statusRiskVisible=false">取消</el-button><el-button type="primary" :loading="saving" @click="saveStatusRisk">保存并刷新</el-button></template>
    </el-dialog>
  </section>
</template>

<style scoped>
.device-detail-page{display:flex;flex-direction:column;gap:16px}.device-detail-page .page-head h1{margin-top:8px}.card-title{display:flex;align-items:center;justify-content:space-between;gap:12px;font-weight:600}.card-title>div{display:flex;gap:8px}.card-title small{font-weight:400;color:#667085}.related-actions{display:flex;flex-wrap:wrap;gap:10px;margin-bottom:16px}.device-detail-page :deep(.el-descriptions__label){width:110px}.device-detail-page :deep(.el-select){width:100%}
</style>
