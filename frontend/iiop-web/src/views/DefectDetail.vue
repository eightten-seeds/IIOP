<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { ElMessage, ElMessageBox } from 'element-plus';
import { request } from '../api/request';
import WorkOrderCreateDialog from '../components/WorkOrderCreateDialog.vue';
import { useAuthStore } from '../stores/auth';
import type { Device, PageResult, UserSummary } from '../types/device';
import type { Defect, Diagnosis, DiagnosisView, WorkOrder } from '../types/maintenance';
import { displayValue } from '../utils/display';

const route=useRoute(),router=useRouter(),auth=useAuthStore();
const defect=ref<Defect>(),device=ref<Device>(),reporter=ref('原上报人'),diagnoses=ref<Diagnosis[]>([]),workOrder=ref<WorkOrder>();
const loading=ref(false),busy=ref(''),errorMessage=ref(''),orderVisible=ref(false),diagnosing=ref(false);
const deviceLabel=computed(()=>device.value?`${device.value.deviceName}（${device.value.deviceCode}）`:'设备信息加载中');
const canProcess=computed(()=>auth.can('maintenance:defect:process')&&(auth.roles.includes('ADMIN')||auth.roles.includes('SUPER_ADMIN')||auth.roles.includes('MAINTAINER')));
const usableAiId=computed(()=>{const id=defect.value?.aiDiagnosisId;const d=diagnoses.value.find(x=>x.id===id);return d?.diagnosisStatus==='SUCCEEDED'&&d.confirmationStatus==='CONFIRMED'?id:null});
const dateTime=(v:string|null|undefined)=>v?v.replace('T',' ').slice(0,19):'-';
const sourcePath=computed(()=>!defect.value?.sourceId?'':defect.value.sourceType==='INSPECTION_ABNORMAL'?`/inspection/abnormals/${defect.value.sourceId}`:'');

async function load(){loading.value=true;errorMessage.value='';try{const d=await request.get<never,Defect>(`/api/maintenance/defects/${route.params.id}`);defect.value=d;const jobs:Promise<unknown>[]=[request.get<never,Device>(`/api/device/devices/${d.deviceId}`).then(x=>device.value=x),request.get<never,PageResult<Diagnosis>>('/api/ai/diagnoses',{params:{triggerType:d.sourceType,triggerId:d.sourceId||undefined,deviceId:d.deviceId,pageNum:1,pageSize:20}}).then(x=>diagnoses.value=x.records??[]),request.get<never,PageResult<WorkOrder>>('/api/maintenance/work-orders',{params:{defectId:d.id,pageNum:1,pageSize:2}}).then(x=>workOrder.value=x.records?.[0])];if(d.reportedBy&&auth.can('system:user:view'))jobs.push(request.get<never,UserSummary>(`/api/auth/users/${d.reportedBy}`,{silentStatuses:[404]}).then(u=>reporter.value=u.realName?`${u.realName}（${u.username}）`:u.username).catch((e:any)=>reporter.value=e.response?.status===404?'原上报人（账号已删除）':'人员信息暂不可用'));await Promise.allSettled(jobs);}catch{errorMessage.value='缺陷详情加载失败，可能无权访问或服务暂不可用。';}finally{loading.value=false;}}
async function action(name:'confirm'|'close'){
  if(!defect.value)return;
  try{
    await ElMessageBox.confirm(
      name==='confirm'?'确认该缺陷事实属实并进入待处理状态吗？':'确认维修工作已完结验收并正式关闭该缺陷吗？',
      name==='confirm'?'确认缺陷':'关闭缺陷',
      {type:'warning'}
    );
  }catch{return}
  busy.value=name;
  try{
    await request.post(`/api/maintenance/defects/${defect.value.id}/${name}`);
    ElMessage.success(name==='confirm'?'缺陷已确认，可进行工单创建与AI诊断绑定':'缺陷已关闭归档，维修流程完整闭环');
    await load();
  }catch(e:any){
    if(e.response?.status===409)await load();
  }finally{busy.value='';}
}
async function startDiagnosis(){
  if(!defect.value)return;
  diagnosing.value=true;
  try{
    const v=await request.post<never,DiagnosisView>('/api/ai/diagnoses',{
      triggerType:defect.value.sourceType,
      triggerId:defect.value.sourceType==='MANUAL'?null:defect.value.sourceId,
      deviceId:defect.value.deviceId,
      abnormalSummary:defect.value.title,
      userDescription:defect.value.description
    });
    ElMessage.success('AI 智能研判已完成，请核验诊断建议');
    await router.push(`/ai/diagnoses/${v.diagnosis.id}`);
  }catch(e:any){
    if(e.code==='ECONNABORTED'||e.message?.includes('timeout')){
      ElMessage.warning('请求处理较久，结果可能已在生成中，请稍后刷新关联诊断。');
      await load();
    }
  }finally{diagnosing.value=false;}
}
async function bindAi(id:string){
  if(!defect.value)return;
  busy.value='bind';
  try{
    await request.put(`/api/maintenance/defects/${defect.value.id}/ai-diagnosis`,{aiDiagnosisId:id});
    ElMessage.success('AI 诊断处置建议已绑定至本缺陷');
    await load();
  }catch(e:any){
    if(e.response?.status===409)await load();
  }finally{busy.value='';}
}
function created(o:WorkOrder){workOrder.value=o;void load();void router.push(`/maintenance/work-orders/${o.id}`)}
onMounted(load);
</script>

<template>
  <section class="detail-page">
    <div class="page-head">
      <div>
        <el-button link @click="router.push('/maintenance/defects')">← 返回缺陷列表</el-button>
        <h1>缺陷详情</h1>
        <p>确认缺陷事实、绑定已审核的 AI 诊断方案，并推进维修工单全流程闭环。</p>
      </div>
      <div v-if="defect" class="head-actions">
        <el-button v-if="canProcess&&defect.status==='OPEN'" type="primary" :loading="busy==='confirm'" @click="action('confirm')">确认缺陷</el-button>
        <el-button v-if="canProcess&&defect.status==='RESOLVED'" type="success" :loading="busy==='close'" @click="action('close')">关闭缺陷</el-button>
      </div>
    </div>

    <!-- Lifecycle Steps -->
    <el-card v-if="defect" shadow="never" class="steps-card">
      <el-steps :active="['OPEN','CONFIRMED','PROCESSING','RESOLVED','CLOSED'].indexOf(defect.status)" finish-status="success" align-center>
        <el-step title="发现上报" :description="defect.status==='OPEN'?'待确认事实':''" />
        <el-step title="缺陷确认" :description="defect.status==='CONFIRMED'?'待创建工单/绑定AI':''" />
        <el-step title="维修中" :description="defect.status==='PROCESSING'?'现场处理中':''" />
        <el-step title="维修解决" :description="defect.status==='RESOLVED'?'待关闭归档':''" />
        <el-step title="关闭归档" :description="defect.status==='CLOSED'?'流程已完结':''" />
      </el-steps>
    </el-card>

    <!-- Contextual Guidance Banner -->
    <div v-if="defect" class="guidance-banner">
      <el-alert
        v-if="defect.status==='OPEN'"
        title="【缺陷待确认】请管理员或维修主管确认缺陷真实性，确认后可绑定 AI 诊断并派发维修工单。"
        type="warning"
        show-icon
        :closable="false"
      />
      <el-alert
        v-else-if="defect.status==='CONFIRMED'&&!workOrder"
        title="【缺陷待派工】缺陷已确认。可发起或绑定已审核的 AI 诊断方案，并创建维修工单指派给维修工程师。"
        type="info"
        show-icon
        :closable="false"
      />
      <el-alert
        v-else-if="defect.status==='PROCESSING'||(defect.status==='CONFIRMED'&&workOrder)"
        :title="`【维修处理中】关联工单【${workOrder?.workOrderCode || ''}】处理中，等待维修人员现场检修并提交验收。`"
        type="info"
        show-icon
        :closable="false"
      />
      <el-alert
        v-else-if="defect.status==='RESOLVED'"
        title="【维修已完成】现场工单已验收合格，缺陷已标记为解决。请管理员点击右上角【关闭缺陷】完成归档闭环。"
        type="success"
        show-icon
        :closable="false"
      />
      <el-alert
        v-else-if="defect.status==='CLOSED'"
        title="【缺陷已归档】缺陷处理已全流程闭环归档。"
        type="success"
        show-icon
        :closable="false"
      />
    </div>

    <el-alert v-if="errorMessage" :title="errorMessage" type="error" show-icon :closable="false">
      <template #default><el-button link @click="load">重新加载</el-button></template>
    </el-alert>

    <template v-else-if="defect">
      <el-card v-loading="loading" shadow="never">
        <template #header><strong>缺陷事实</strong></template>
        <el-descriptions :column="3" border>
          <el-descriptions-item label="缺陷编号">{{defect.defectCode}}</el-descriptions-item>
          <el-descriptions-item label="状态"><el-tag>{{displayValue(defect.status)}}</el-tag></el-descriptions-item>
          <el-descriptions-item label="严重程度">
            <el-tag :type="defect.severity==='HIGH'||defect.severity==='CRITICAL'?'danger':'warning'">{{displayValue(defect.severity)}}</el-tag>
          </el-descriptions-item>
          <el-descriptions-item label="标题" :span="2">{{defect.title}}</el-descriptions-item>
          <el-descriptions-item label="上报时间">{{dateTime(defect.reportedAt)}}</el-descriptions-item>
          <el-descriptions-item label="描述" :span="3">{{defect.description||'-'}}</el-descriptions-item>
          <el-descriptions-item label="上报人员">{{reporter}}</el-descriptions-item>
          <el-descriptions-item label="解决时间">{{dateTime(defect.resolvedAt)}}</el-descriptions-item>
          <el-descriptions-item label="更新时间">{{dateTime(defect.updatedAt)}}</el-descriptions-item>
        </el-descriptions>
      </el-card>

      <el-row :gutter="16">
        <el-col :xs="24" :lg="12">
          <el-card shadow="never" class="full-card">
            <template #header><strong>来源与设备</strong></template>
            <el-descriptions :column="1" border>
              <el-descriptions-item label="设备">
                {{deviceLabel}}
                <el-button link type="primary" @click="router.push(`/devices/${defect.deviceId}`)">查看设备详情</el-button>
              </el-descriptions-item>
              <el-descriptions-item label="缺陷来源">
                {{displayValue(defect.sourceType)}}
                <el-button v-if="sourcePath&&auth.can('inspection:view')" link type="primary" @click="router.push(sourcePath)">查看巡检异常事实 →</el-button>
              </el-descriptions-item>
            </el-descriptions>
          </el-card>
        </el-col>
        <el-col :xs="24" :lg="12">
          <el-card shadow="never" class="full-card">
            <template #header>
              <div class="card-head">
                <strong>维修工单</strong>
                <el-button v-if="auth.can('maintenance:workorder:create')&&defect.status==='CONFIRMED'&&!workOrder" type="primary" size="small" @click="orderVisible=true">创建工单</el-button>
              </div>
            </template>
            <el-descriptions v-if="workOrder" :column="2" border>
              <el-descriptions-item label="工单编号">{{workOrder.workOrderCode}}</el-descriptions-item>
              <el-descriptions-item label="状态"><el-tag>{{displayValue(workOrder.status)}}</el-tag></el-descriptions-item>
              <el-descriptions-item label="标题" :span="2">{{workOrder.title}}</el-descriptions-item>
              <el-descriptions-item label="操作" :span="2">
                <el-button link type="primary" @click="router.push(`/maintenance/work-orders/${workOrder.id}`)">进入工单详情 →</el-button>
              </el-descriptions-item>
            </el-descriptions>
            <el-empty v-else description="尚未创建维修工单" />
          </el-card>
        </el-col>
      </el-row>

      <el-card shadow="never">
        <template #header>
          <div class="card-head">
            <strong>AI 辅助诊断</strong>
            <el-button v-if="auth.can('ai:diagnosis')&&!auth.roles.includes('INSPECTOR')" type="primary" plain :loading="diagnosing" @click="startDiagnosis">发起同步研判</el-button>
          </div>
        </template>
        <el-alert v-if="diagnosing" title="AI 智能诊断正在执行五节点研判，请保持页面打开；通常需要数十秒。" type="info" show-icon :closable="false"/>
        <el-table v-if="diagnoses.length" :data="diagnoses">
          <el-table-column prop="diagnosisCode" label="诊断编号" min-width="180"/>
          <el-table-column label="诊断状态" width="110">
            <template #default="s">{{displayValue(s.row.diagnosisStatus)}}</template>
          </el-table-column>
          <el-table-column label="确认状态" width="110">
            <template #default="s">{{displayValue(s.row.confirmationStatus)}}</template>
          </el-table-column>
          <el-table-column label="风险" width="100">
            <template #default="s">{{displayValue(s.row.riskLevel)}}</template>
          </el-table-column>
          <el-table-column label="操作" width="200">
            <template #default="s">
              <el-button link @click="router.push(`/ai/diagnoses/${s.row.id}`)">查看方案</el-button>
              <el-button v-if="canProcess&&defect.status==='CONFIRMED'&&s.row.diagnosisStatus==='SUCCEEDED'&&s.row.confirmationStatus==='CONFIRMED'&&defect.aiDiagnosisId!==s.row.id" link type="primary" :loading="busy==='bind'" @click="bindAi(s.row.id)">绑定到缺陷</el-button>
              <el-tag v-if="defect.aiDiagnosisId===s.row.id" type="success">已绑定</el-tag>
            </template>
          </el-table-column>
        </el-table>
        <el-empty v-else description="尚无关联 AI 诊断"/>
      </el-card>
    </template>
    <WorkOrderCreateDialog v-if="defect" v-model:visible="orderVisible" :device-id="defect.deviceId" :device-label="deviceLabel" :defect-id="defect.id" :ai-diagnosis-id="usableAiId" @created="created" />
  </section>
</template>

<style scoped>
.detail-page{display:flex;flex-direction:column;gap:16px}
.head-actions,.card-head{display:flex;gap:10px;align-items:center}
.card-head{justify-content:space-between}
.full-card{height:100%}
.steps-card{padding:8px 0}
.guidance-banner{margin-bottom:0}
.detail-page :deep(.el-descriptions__content .el-button){margin-left:8px}
</style>
