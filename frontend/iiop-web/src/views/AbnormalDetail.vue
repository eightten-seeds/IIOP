<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { request } from '../api/request';
import { useAuthStore } from '../stores/auth';
import type { Device, PageResult, UserSummary } from '../types/device';
import type { DefectSummary, DiagnosisSummary, InspectionAbnormal, TaskDetailData } from '../types/inspection';
import { displayValue } from '../utils/display';

const route = useRoute();
const router = useRouter();
const auth = useAuthStore();
const abnormal = ref<InspectionAbnormal>();
const taskDetail = ref<TaskDetailData>();
const device = ref<Device>();
const reporterName = ref('上报人员');
const defect = ref<DefectSummary>();
const diagnoses = ref<DiagnosisSummary[]>([]);
const loading = ref(false);
const errorMessage = ref('');
const relatedMessage = ref('');
const sourceItem = computed(() => taskDetail.value?.items.find(item => item.id === abnormal.value?.taskItemId));
const dateTime = (value: string | null | undefined) => value ? value.replace('T', ' ').slice(0, 19) : '-';

async function loadRelated() {
  if (!abnormal.value) return;
  relatedMessage.value = '';
  const current = abnormal.value;
  const jobs: Promise<unknown>[] = [];
  if (auth.can('maintenance:view')) jobs.push(request.get<never, PageResult<DefectSummary>>('/api/maintenance/defects', { params: { sourceType: 'INSPECTION_ABNORMAL', sourceId: current.id, pageNum: 1, pageSize: 5 } }).then(page => { defect.value = page.records?.[0]; }));
  if (auth.can('ai:view')) jobs.push(request.get<never, PageResult<DiagnosisSummary>>('/api/ai/diagnoses', { params: { triggerType: 'INSPECTION_ABNORMAL', triggerId: current.id, deviceId: current.deviceId, pageNum: 1, pageSize: 5 } }).then(page => { diagnoses.value = page.records ?? []; }));
  const results = await Promise.allSettled(jobs);
  if (results.some(result => result.status === 'rejected')) relatedMessage.value = '部分关联业务信息暂时无法加载，可稍后重试。';
}

async function load() {
  loading.value = true;
  errorMessage.value = '';
  defect.value = undefined;
  diagnoses.value = [];
  try {
    const id = String(route.params.id);
    const current = await request.get<never, InspectionAbnormal>(`/api/inspection/abnormals/${id}`);
    abnormal.value = current;
    const [taskResult, deviceResult] = await Promise.all([
      request.get<never, TaskDetailData>(`/api/inspection/tasks/${current.taskId}`),
      request.get<never, Device>(`/api/device/devices/${current.deviceId}`)
    ]);
    taskDetail.value = taskResult;
    device.value = deviceResult;
    if (auth.currentUser?.id === current.reportedBy) reporterName.value = `${auth.currentUser.realName || auth.currentUser.username}（${auth.currentUser.username}）`;
    else if (auth.can('system:user:view')) {
      try {
        const user = await request.get<never, UserSummary>(`/api/auth/users/${current.reportedBy}`, { silentStatuses: [404] });
        reporterName.value = `${user.realName || user.username}（${user.username}）`;
      } catch (err: any) {
        if (err.response?.status === 404) {
          reporterName.value = '原上报人（账号已删除）';
        } else {
          reporterName.value = '人员信息暂不可用';
        }
      }
    }
    await loadRelated();
  } catch { errorMessage.value = '巡检异常详情加载失败，可能无权访问或服务暂不可用。'; }
  finally { loading.value = false; }
}

function openAiList() {
  if (!abnormal.value) return;
  void router.push({ path: '/ai/diagnoses', query: { triggerType: 'INSPECTION_ABNORMAL', triggerId: abnormal.value.id, deviceId: abnormal.value.deviceId } });
}
onMounted(load);
</script>

<template>
  <section class="abnormal-detail">
    <div class="page-head"><div><el-button link @click="router.push('/inspection/abnormals')">← 返回异常列表</el-button><h1>巡检异常详情</h1><p>查看异常现场事实、来源任务以及后续缺陷和 AI 诊断关联。</p></div></div>
    <el-alert v-if="errorMessage" :title="errorMessage" type="error" show-icon :closable="false"><template #default><el-button link type="primary" @click="load">重新加载</el-button></template></el-alert>
    <template v-else>
      <el-card v-loading="loading" shadow="never"><template #header><strong>异常基本信息</strong></template>
        <el-descriptions v-if="abnormal" :column="3" border>
          <el-descriptions-item label="异常编号">{{ abnormal.abnormalCode }}</el-descriptions-item><el-descriptions-item label="异常标题">{{ abnormal.title }}</el-descriptions-item><el-descriptions-item label="异常状态"><el-tag>{{ displayValue(abnormal.status) }}</el-tag></el-descriptions-item>
          <el-descriptions-item label="严重程度"><el-tag :type="abnormal.severity==='CRITICAL'||abnormal.severity==='HIGH'?'danger':abnormal.severity==='MEDIUM'?'warning':'success'">{{ displayValue(abnormal.severity) }}</el-tag></el-descriptions-item><el-descriptions-item label="上报人员">{{ reporterName }}</el-descriptions-item><el-descriptions-item label="上报时间">{{ dateTime(abnormal.reportedAt) }}</el-descriptions-item>
          <el-descriptions-item label="异常描述" :span="3">{{ abnormal.description || '-' }}</el-descriptions-item>
        </el-descriptions>
      </el-card>
      <el-card shadow="never"><template #header><strong>异常来源</strong></template>
        <el-descriptions v-if="abnormal" :column="2" border>
          <el-descriptions-item label="设备"><span>{{ device ? `${device.deviceName}（${device.deviceCode}）` : '设备信息加载中' }}</span><el-button link type="primary" @click="router.push(`/devices/${abnormal.deviceId}`)">查看设备</el-button></el-descriptions-item>
          <el-descriptions-item label="巡检任务"><span>{{ taskDetail?.task.taskCode || '任务信息加载中' }}</span><el-button link type="primary" @click="router.push(`/inspection/tasks/${abnormal.taskId}`)">查看巡检任务</el-button></el-descriptions-item>
          <el-descriptions-item label="关联检查项" :span="2">{{ sourceItem ? `${sourceItem.itemName}（${sourceItem.itemCode}）` : abnormal.taskItemId ? '关联检查项已不存在' : '未关联具体检查项' }}</el-descriptions-item>
        </el-descriptions>
      </el-card>
      <el-alert v-if="relatedMessage" :title="relatedMessage" type="warning" show-icon :closable="false"><template #default><el-button link type="primary" @click="loadRelated">重试关联查询</el-button></template></el-alert>
      <el-row :gutter="16">
        <el-col :xs="24" :lg="12"><el-card shadow="never" class="related-card"><template #header><strong>维修缺陷关联</strong></template>
          <template v-if="auth.can('maintenance:view')"><el-descriptions v-if="defect" :column="2" border><el-descriptions-item label="缺陷编号">{{ defect.defectCode }}</el-descriptions-item><el-descriptions-item label="状态">{{ displayValue(defect.status) }}</el-descriptions-item><el-descriptions-item label="标题" :span="2">{{ defect.title }}</el-descriptions-item><el-descriptions-item label="严重程度">{{ displayValue(defect.severity) }}</el-descriptions-item><el-descriptions-item label="操作"><el-button link type="primary" @click="router.push(`/maintenance/defects/${defect.id}`)">查看维修缺陷</el-button></el-descriptions-item></el-descriptions><el-empty v-else description="尚未查询到由该异常形成的维修缺陷" /></template>
          <el-empty v-else description="当前岗位无维修缺陷查看权限" />
        </el-card></el-col>
        <el-col :xs="24" :lg="12"><el-card shadow="never" class="related-card"><template #header><strong>AI 诊断关联</strong></template>
          <template v-if="auth.can('ai:view')"><el-table v-if="diagnoses.length" :data="diagnoses" size="small"><el-table-column prop="diagnosisCode" label="诊断编号" min-width="145" /><el-table-column label="诊断状态" width="95"><template #default="scope">{{ displayValue(scope.row.diagnosisStatus) }}</template></el-table-column><el-table-column label="风险" width="90"><template #default="scope">{{ displayValue(scope.row.riskLevel) }}</template></el-table-column><el-table-column label="操作" width="90"><template #default="scope"><el-button link @click="router.push(`/ai/diagnoses/${scope.row.id}`)">查看诊断</el-button></template></el-table-column></el-table><el-empty v-else description="尚无关联 AI 诊断"><el-button type="primary" plain @click="openAiList">查看/发起 AI 诊断</el-button></el-empty></template>
          <el-empty v-else description="当前岗位无 AI 诊断查看权限" />
        </el-card></el-col>
      </el-row>
    </template>
  </section>
</template>

<style scoped>
.abnormal-detail{display:flex;flex-direction:column;gap:16px}.related-card{height:100%}.abnormal-detail :deep(.el-descriptions__content .el-button){margin-left:10px}
</style>
