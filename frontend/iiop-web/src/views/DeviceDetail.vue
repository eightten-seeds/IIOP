<script setup lang="ts">
import { computed, reactive, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { ElMessage } from 'element-plus';
import { View, Refresh } from '@element-plus/icons-vue';
import { request } from '../api/request';
import { useAuthStore } from '../stores/auth';
import { displayValue } from '../utils/display';
import { categoryNameMap, type CategoryTree, type Device, type DeviceStatus, type Metric, type RiskLevel, type Sop, type UserSummary, type PageResult } from '../types/device';
import type { InspectionTask, InspectionAbnormal } from '../types/inspection';
import type { Defect, WorkOrder, Diagnosis } from '../types/maintenance';

const DEVICE_STATUSES: DeviceStatus[] = ['ONLINE', 'OFFLINE', 'FAULT', 'MAINTENANCE', 'SCRAPPED'];
const RISK_LEVELS: RiskLevel[] = ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL'];
const route = useRoute();
const router = useRouter();
const auth = useAuthStore();
const device = ref<Device | null>(null);
const metrics = ref<Metric[]>([]);
const sops = ref<Sop[]>([]);
const recentTasks = ref<InspectionTask[]>([]);
const recentAbnormals = ref<InspectionAbnormal[]>([]);
const recentDefects = ref<Defect[]>([]);
const recentWorkOrders = ref<WorkOrder[]>([]);
const recentDiagnoses = ref<Diagnosis[]>([]);
const categoryNames = reactive<Record<string, string>>({});
const responsibleName = ref('');
const loading = ref(false);
const errorMessage = ref('');
const statusRiskVisible = ref(false);
const saving = ref(false);
const statusRisk = reactive<{ status: DeviceStatus; riskLevel: RiskLevel }>({ status: 'OFFLINE', riskLevel: 'LOW' });
const activeTab = ref('operations');

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

const dateTime = (v: string | null | undefined) => v ? v.replace('T', ' ').slice(0, 16) : '-';

async function load() {
  loading.value = true;
  errorMessage.value = '';
  responsibleName.value = '';
  try {
    const id = deviceId.value;
    const [current, tree, metricRows, sopRows] = await Promise.all([
      request.get<never, Device>(`/api/device/devices/${id}`),
      request.get<never, CategoryTree[]>('/api/device/categories/tree'),
      request.get<never, Metric[]>(`/api/device/devices/${id}/metrics`),
      request.get<never, Sop[]>(`/api/device/devices/${id}/sops`)
    ]);
    device.value = current;
    metrics.value = metricRows ?? [];
    sops.value = sopRows ?? [];
    Object.keys(categoryNames).forEach((key) => delete categoryNames[key]);
    Object.assign(categoryNames, categoryNameMap(tree ?? []));
    if (current.responsibleUserId && auth.can('system:user:view')) {
      try {
        const user = await request.get<never, UserSummary>(`/api/auth/users/${current.responsibleUserId}`, { silentStatuses: [404] });
        responsibleName.value = userLabel(user);
      } catch (err: any) {
        if (err.response?.status === 404) {
          responsibleName.value = '原负责人（账号已删除）';
        } else {
          responsibleName.value = '人员信息暂不可用';
        }
      }
    }

    const asyncJobs: Promise<unknown>[] = [];
    if (auth.can('inspection:view')) {
      asyncJobs.push(
        request.get<never, PageResult<InspectionTask>>('/api/inspection/tasks', { params: { deviceId: id, pageNum: 1, pageSize: 5 }, silentGlobalError: true })
          .then((res) => { recentTasks.value = res.records ?? []; })
          .catch(() => { recentTasks.value = []; })
      );
      asyncJobs.push(
        request.get<never, PageResult<InspectionAbnormal>>('/api/inspection/abnormals', { params: { deviceId: id, pageNum: 1, pageSize: 5 }, silentGlobalError: true })
          .then((res) => { recentAbnormals.value = res.records ?? []; })
          .catch(() => { recentAbnormals.value = []; })
      );
    }
    if (auth.can('maintenance:view')) {
      asyncJobs.push(
        request.get<never, PageResult<Defect>>('/api/maintenance/defects', { params: { deviceId: id, pageNum: 1, pageSize: 5 }, silentGlobalError: true })
          .then((res) => { recentDefects.value = res.records ?? []; })
          .catch(() => { recentDefects.value = []; })
      );
      asyncJobs.push(
        request.get<never, PageResult<WorkOrder>>('/api/maintenance/work-orders', { params: { deviceId: id, pageNum: 1, pageSize: 5 }, silentGlobalError: true })
          .then((res) => { recentWorkOrders.value = res.records ?? []; })
          .catch(() => { recentWorkOrders.value = []; })
      );
    }
    if (auth.can('ai:view')) {
      asyncJobs.push(
        request.get<never, PageResult<Diagnosis>>('/api/ai/diagnoses', { params: { deviceId: id, pageNum: 1, pageSize: 5 }, silentGlobalError: true })
          .then((res) => { recentDiagnoses.value = res.records ?? []; })
          .catch(() => { recentDiagnoses.value = []; })
      );
    }
    await Promise.allSettled(asyncJobs);
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
    ElMessage.success('设备状态与风险等级已更新');
    statusRiskVisible.value = false;
    await load();
  } finally {
    saving.value = false;
  }
}

function locateInScene() {
  if (!device.value) return;
  void router.push({ path: '/devices/scene', query: { deviceId: device.value.id } });
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
      <div>
        <el-button link @click="router.push('/devices')">← 返回设备档案</el-button>
        <div class="header-device-title">
          <h1>{{ device?.deviceName || '设备详情' }}</h1>
          <span v-if="device" class="header-code">{{ device.deviceCode }}</span>
        </div>
      </div>
      <div v-if="device" class="head-actions">
        <el-button :icon="View" @click="locateInScene">在三维场景中定位</el-button>
        <el-button v-if="auth.can('device:update')" type="primary" :disabled="loading" @click="openStatusRisk">更新状态与风险</el-button>
      </div>
    </div>

    <el-skeleton v-if="loading" :rows="10" animated />
    <el-alert v-else-if="errorMessage" :title="errorMessage" type="error" show-icon :closable="false">
      <template #default>
        <el-button link type="primary" @click="load">重新加载</el-button>
        <el-button link @click="router.push('/devices')">返回列表</el-button>
      </template>
    </el-alert>

    <template v-else-if="device">
      <!-- Top Priority Hero Banner: Identity, Status, Risk, Location, Responsible -->
      <section class="device-hero-card">
        <div class="hero-left">
          <div class="hero-tags">
            <el-tag :type="device.status==='ONLINE'?'success':device.status==='FAULT'?'danger':device.status==='MAINTENANCE'?'warning':'info'" size="large" :effect="device.status==='FAULT'?'dark':'light'">
              运行状态：{{ displayValue(device.status) }}
            </el-tag>
            <el-tag :type="device.riskLevel==='CRITICAL'?'danger':device.riskLevel==='HIGH'?'warning':device.riskLevel==='MEDIUM'?'primary':'success'" size="large" :effect="device.riskLevel==='CRITICAL'?'dark':'plain'">
              安全风险：{{ displayValue(device.riskLevel) }}
            </el-tag>
            <el-tag type="info" size="large" effect="plain">{{ categoryName }}</el-tag>
          </div>
          <div class="hero-meta-grid">
            <div class="meta-item">
              <span class="meta-label">安装区域 / 位置</span>
              <strong class="meta-val">{{ [device.workshop, device.installLocation].filter(Boolean).join(' · ') || '未登记位置' }}</strong>
            </div>
            <div class="meta-item">
              <span class="meta-label">设备责任人</span>
              <strong class="meta-val">{{ responsibleLabel }}</strong>
            </div>
            <div class="meta-item">
              <span class="meta-label">设备型号 / 制造商</span>
              <strong class="meta-val">{{ [device.model, device.manufacturer].filter(Boolean).join(' / ') || '-' }}</strong>
            </div>
            <div class="meta-item">
              <span class="meta-label">空间三维坐标</span>
              <strong class="meta-val">
                {{ device.positionX != null ? `(${device.positionX}, ${device.positionY}, ${device.positionZ})` : '未完成三维定位' }}
              </strong>
            </div>
          </div>
        </div>
      </section>

      <!-- Business Operations Cockpit -->
      <el-card shadow="never" class="cockpit-card">
        <el-tabs v-model="activeTab">
          <!-- Tab 1: 运维闭环动态 -->
          <el-tab-pane label="运维闭环动态" name="operations">
            <div class="cockpit-grid">
              <!-- Recent Inspection Tasks -->
              <div class="cockpit-section" v-if="auth.can('inspection:view')">
                <div class="cockpit-section-head">
                  <strong>最近巡检任务</strong>
                  <el-button link type="primary" size="small" @click="related('/inspection/tasks')">查看全部 →</el-button>
                </div>
                <el-table v-if="recentTasks.length" :data="recentTasks" size="small">
                  <el-table-column prop="taskCode" label="任务编号" min-width="140" />
                  <el-table-column label="状态" width="90">
                    <template #default="s"><el-tag size="small">{{ displayValue(s.row.taskStatus) }}</el-tag></template>
                  </el-table-column>
                  <el-table-column label="结果" width="85">
                    <template #default="s"><el-tag size="small" :type="s.row.resultStatus==='ABNORMAL'?'danger':'success'" effect="plain">{{ displayValue(s.row.resultStatus) }}</el-tag></template>
                  </el-table-column>
                  <el-table-column label="时间" min-width="130">
                    <template #default="s">{{ dateTime(s.row.createdAt) }}</template>
                  </el-table-column>
                  <el-table-column label="操作" width="80" fixed="right">
                    <template #default="s"><el-button link type="primary" size="small" @click="router.push(`/inspection/tasks/${s.row.id}`)">详情</el-button></template>
                  </el-table-column>
                </el-table>
                <el-empty v-else description="暂无该设备的巡检任务" :image-size="60" />
              </div>

              <!-- Recent Abnormalities -->
              <div class="cockpit-section" v-if="auth.can('inspection:view')">
                <div class="cockpit-section-head">
                  <strong>现场巡检异常</strong>
                  <el-button link type="primary" size="small" @click="related('/inspection/abnormals')">查看全部 →</el-button>
                </div>
                <el-table v-if="recentAbnormals.length" :data="recentAbnormals" size="small">
                  <el-table-column prop="abnormalCode" label="异常编号" min-width="140" />
                  <el-table-column prop="title" label="标题" min-width="130" show-overflow-tooltip />
                  <el-table-column label="严重度" width="90">
                    <template #default="s"><el-tag size="small" :type="s.row.severity==='CRITICAL'||s.row.severity==='HIGH'?'danger':'warning'">{{ displayValue(s.row.severity) }}</el-tag></template>
                  </el-table-column>
                  <el-table-column label="状态" width="85">
                    <template #default="s"><el-tag size="small">{{ displayValue(s.row.status) }}</el-tag></template>
                  </el-table-column>
                  <el-table-column label="操作" width="80" fixed="right">
                    <template #default="s"><el-button link type="primary" size="small" @click="router.push(`/inspection/abnormals/${s.row.id}`)">详情</el-button></template>
                  </el-table-column>
                </el-table>
                <el-empty v-else description="设备运行良好，暂无异常" :image-size="60" />
              </div>

              <!-- Recent Defects -->
              <div class="cockpit-section" v-if="auth.can('maintenance:view')">
                <div class="cockpit-section-head">
                  <strong>维修缺陷</strong>
                  <el-button link type="primary" size="small" @click="related('/maintenance/defects')">查看全部 →</el-button>
                </div>
                <el-table v-if="recentDefects.length" :data="recentDefects" size="small">
                  <el-table-column prop="defectCode" label="缺陷编码" min-width="140" />
                  <el-table-column prop="title" label="描述" min-width="130" show-overflow-tooltip />
                  <el-table-column label="状态" width="90">
                    <template #default="s"><el-tag size="small">{{ displayValue(s.row.status) }}</el-tag></template>
                  </el-table-column>
                  <el-table-column label="操作" width="80" fixed="right">
                    <template #default="s"><el-button link type="primary" size="small" @click="router.push(`/maintenance/defects/${s.row.id}`)">处理</el-button></template>
                  </el-table-column>
                </el-table>
                <el-empty v-else description="暂无未闭环缺陷" :image-size="60" />
              </div>

              <!-- Recent Work Orders -->
              <div class="cockpit-section" v-if="auth.can('maintenance:view')">
                <div class="cockpit-section-head">
                  <strong>维修工单</strong>
                  <el-button link type="primary" size="small" @click="related('/maintenance/work-orders')">查看全部 →</el-button>
                </div>
                <el-table v-if="recentWorkOrders.length" :data="recentWorkOrders" size="small">
                  <el-table-column prop="workOrderCode" label="工单编号" min-width="140" />
                  <el-table-column prop="title" label="工单标题" min-width="130" show-overflow-tooltip />
                  <el-table-column label="状态" width="95">
                    <template #default="s"><el-tag size="small">{{ displayValue(s.row.status) }}</el-tag></template>
                  </el-table-column>
                  <el-table-column label="操作" width="80" fixed="right">
                    <template #default="s"><el-button link type="primary" size="small" @click="router.push(`/maintenance/work-orders/${s.row.id}`)">详情</el-button></template>
                  </el-table-column>
                </el-table>
                <el-empty v-else description="暂无该设备的维修工单" :image-size="60" />
              </div>

              <!-- Recent AI Diagnoses -->
              <div class="cockpit-section full-width" v-if="auth.can('ai:view')">
                <div class="cockpit-section-head">
                  <strong>AI 智能诊断记录</strong>
                  <el-button link type="primary" size="small" @click="related('/ai/diagnoses')">查看全部 →</el-button>
                </div>
                <el-table v-if="recentDiagnoses.length" :data="recentDiagnoses" size="small">
                  <el-table-column prop="diagnosisCode" label="诊断编号" min-width="170" />
                  <el-table-column label="诊断状态" width="120">
                    <template #default="s"><el-tag size="small">{{ displayValue(s.row.diagnosisStatus) }}</el-tag></template>
                  </el-table-column>
                  <el-table-column label="人工确认" width="110">
                    <template #default="s"><el-tag size="small" :type="s.row.confirmationStatus==='CONFIRMED'?'success':s.row.confirmationStatus==='REJECTED'?'danger':'info'">{{ displayValue(s.row.confirmationStatus) }}</el-tag></template>
                  </el-table-column>
                  <el-table-column label="研判风险" width="105">
                    <template #default="s"><el-tag size="small" :type="s.row.riskLevel==='CRITICAL'||s.row.riskLevel==='HIGH'?'danger':'warning'">{{ displayValue(s.row.riskLevel) }}</el-tag></template>
                  </el-table-column>
                  <el-table-column label="诊断时间" min-width="150">
                    <template #default="s">{{ dateTime(s.row.createdAt) }}</template>
                  </el-table-column>
                  <el-table-column label="操作" width="100" fixed="right">
                    <template #default="s"><el-button link type="primary" size="small" @click="router.push(`/ai/diagnoses/${s.row.id}`)">查看报告</el-button></template>
                  </el-table-column>
                </el-table>
                <el-empty v-else description="暂无 AI 诊断记录" :image-size="60" />
              </div>
            </div>
          </el-tab-pane>

          <!-- Tab 2: 监测指标 -->
          <el-tab-pane label="监测指标" name="metrics">
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
          </el-tab-pane>

          <!-- Tab 3: 适用 SOP -->
          <el-tab-pane label="适用 SOP 规程" name="sops">
            <el-table v-if="sops.length" :data="sops" row-key="id">
              <el-table-column prop="sopCode" label="SOP 编码" min-width="140" />
              <el-table-column prop="title" label="标题" min-width="220" />
              <el-table-column label="类型" width="120"><template #default="scope">{{ displayValue(scope.row.sopType) }}</template></el-table-column>
              <el-table-column prop="version" label="版本" width="100" />
              <el-table-column label="状态" width="100"><template #default="scope"><el-tag :type="scope.row.status==='EFFECTIVE'?'success':'info'">{{ displayValue(scope.row.status) }}</el-tag></template></el-table-column>
              <el-table-column prop="effectiveDate" label="生效日期" width="130"><template #default="scope">{{ scope.row.effectiveDate || '-' }}</template></el-table-column>
            </el-table>
            <el-empty v-else description="该设备暂无适用的生效 SOP" />
          </el-tab-pane>

          <!-- Tab 4: 完整档案信息 -->
          <el-tab-pane label="完整档案属性" name="archive">
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
              <el-descriptions-item label="空间模型">{{ device.modelUrl || '内置工业模型' }}</el-descriptions-item>
              <el-descriptions-item label="备注" :span="2">{{ device.remark || '暂无备注' }}</el-descriptions-item>
            </el-descriptions>
          </el-tab-pane>
        </el-tabs>
      </el-card>
    </template>

    <el-dialog v-model="statusRiskVisible" title="更新设备状态与风险等级" width="480px" :close-on-click-modal="!saving">
      <el-form label-width="100px">
        <el-form-item label="设备状态">
          <el-select v-model="statusRisk.status" :disabled="saving">
            <el-option v-for="status in DEVICE_STATUSES" :key="status" :label="displayValue(status)" :value="status" />
          </el-select>
        </el-form-item>
        <el-form-item label="风险等级">
          <el-select v-model="statusRisk.riskLevel" :disabled="saving">
            <el-option v-for="risk in RISK_LEVELS" :key="risk" :label="displayValue(risk)" :value="risk" />
          </el-select>
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button :disabled="saving" @click="statusRiskVisible=false">取消</el-button>
        <el-button type="primary" :loading="saving" @click="saveStatusRisk">保存修改</el-button>
      </template>
    </el-dialog>
  </section>
</template>

<style scoped>
.device-detail-page {
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.header-device-title {
  display: flex;
  align-items: baseline;
  gap: 10px;
  margin-top: 4px;
}

.header-device-title h1 {
  margin: 0;
  font-size: 22px;
}

.header-code {
  color: #64748b;
  font-size: 14px;
}

.head-actions {
  display: flex;
  gap: 10px;
}

.device-hero-card {
  padding: 20px 24px;
  border-radius: 12px;
  background: linear-gradient(135deg, #1e293b, #0f172a);
  color: #f8fafc;
  box-shadow: 0 4px 16px rgba(15, 23, 42, 0.12);
}

.hero-tags {
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
  margin-bottom: 18px;
}

.hero-meta-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
  gap: 16px;
}

.meta-item {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.meta-label {
  font-size: 12px;
  color: #94a3b8;
}

.meta-val {
  font-size: 15px;
  color: #f1f5f9;
}

.cockpit-card {
  border-radius: 8px;
}

.cockpit-grid {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 16px;
  padding: 8px 0;
}

.cockpit-section {
  padding: 16px;
  border-radius: 8px;
  border: 1px solid #e2e8f0;
  background: #f8fafc;
}

.cockpit-section.full-width {
  grid-column: 1 / -1;
}

.cockpit-section-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 12px;
}

.cockpit-section-head strong {
  font-size: 14px;
  color: #334155;
}

@media (max-width: 900px) {
  .cockpit-grid {
    grid-template-columns: 1fr;
  }
}
</style>
