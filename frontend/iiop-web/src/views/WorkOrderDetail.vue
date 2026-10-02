<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, reactive, ref } from 'vue';
import { onBeforeRouteLeave, useRoute, useRouter } from 'vue-router';
import { ElMessage, ElMessageBox } from 'element-plus';
import { request } from '../api/request';
import { useAuthStore } from '../stores/auth';
import type { Device, PageResult, UserSummary } from '../types/device';
import type { Defect, DiagnosisView, WorkOrderDetailData } from '../types/maintenance';
import { displayValue } from '../utils/display';
const route=useRoute(),router=useRouter(),auth=useAuthStore(),detail=ref<WorkOrderDetailData>(),device=ref<Device>(),defect=ref<Defect>(),diagnosis=ref<DiagnosisView>(),loading=ref(false),errorMessage=ref(''),busy=ref('');
const userNames=reactive<Record<string,string>>({}),maintainers=ref<UserSummary[]>([]),assignVisible=ref(false),repairVisible=ref(false),acceptVisible=ref(false);
const assignForm=reactive({assigneeUserId:'',comment:''}),repairForm=reactive({faultCause:'',solution:'',partsUsed:'',downtimeMinutes:null as number|null,maintenanceCost:null as number|null,result:'SUCCESS',comment:''}),acceptForm=reactive({acceptanceResult:'PASSED',acceptanceContent:'',comment:''}),snapshots=reactive({assign:'',repair:'',accept:''});
const order=computed(()=>detail.value?.workOrder),isAdmin=computed(()=>auth.roles.includes('ADMIN')||auth.roles.includes('SUPER_ADMIN')),isAssignee=computed(()=>order.value?.assigneeUserId===auth.currentUser?.id),canRepair=computed(()=>auth.roles.includes('MAINTAINER')&&auth.can('maintenance:workorder:process')&&isAssignee.value),dirty=computed(()=>assignVisible.value&&JSON.stringify(assignForm)!==snapshots.assign||repairVisible.value&&JSON.stringify(repairForm)!==snapshots.repair||acceptVisible.value&&JSON.stringify(acceptForm)!==snapshots.accept);
const dateTime=(v:string|null|undefined)=>v?v.replace('T',' ').slice(0,19):'-',userLabel=(u:UserSummary)=>u.realName?`${u.realName}（${u.username}）`:u.username;
function person(id:string|null|undefined){if(!id)return '未分派';if(id===auth.currentUser?.id)return `${auth.currentUser.realName||auth.currentUser.username}（本人）`;return userNames[id]||(auth.can('system:user:view')?'人员信息加载中':'业务人员')}
async function resolveUsers(ids:(string|null|undefined)[]){if(!auth.can('system:user:view'))return;await Promise.allSettled([...new Set(ids.filter(Boolean) as string[])].filter(id=>!userNames[id]).map(async id=>{try{const u=await request.get<never,UserSummary>(`/api/auth/users/${id}`,{silentStatuses:[404]});userNames[id]=userLabel(u);}catch(e:any){userNames[id]=e.response?.status===404?'原操作人（账号已删除）':'人员信息暂不可用';}}));}
async function load(){loading.value=true;errorMessage.value='';try{const d=await request.get<never,WorkOrderDetailData>(`/api/maintenance/work-orders/${route.params.id}`);detail.value=d;const o=d.workOrder;const jobs:Promise<unknown>[]=[request.get<never,Device>(`/api/device/devices/${o.deviceId}`).then(x=>device.value=x)];if(o.defectId)jobs.push(request.get<never,Defect>(`/api/maintenance/defects/${o.defectId}`).then(x=>defect.value=x));else defect.value=undefined;if(o.aiDiagnosisId)jobs.push(request.get<never,DiagnosisView>(`/api/ai/diagnoses/${o.aiDiagnosisId}`).then(x=>diagnosis.value=x));else diagnosis.value=undefined;jobs.push(resolveUsers([o.creatorUserId,o.assigneeUserId,...d.logs.map(x=>x.operatorUserId),...d.records.map(x=>x.repairedBy),...d.acceptances.map(x=>x.acceptedBy)]));await Promise.allSettled(jobs);}catch{errorMessage.value='工单详情加载失败，可能超出当前维修人员的数据范围。';}finally{loading.value=false;}}
async function searchMaintainers(keyword=''){if(!auth.can('system:user:view'))return;const p=await request.get<never,PageResult<UserSummary>>('/api/auth/users',{params:{pageNum:1,pageSize:20,keyword:keyword||undefined,status:'ENABLED',roleCode:'MAINTAINER'}});maintainers.value=p.records??[];maintainers.value.forEach(u=>userNames[u.id]=userLabel(u));}
function openAssign(){Object.assign(assignForm,{assigneeUserId:'',comment:''});snapshots.assign=JSON.stringify(assignForm);assignVisible.value=true;void searchMaintainers()}function openRepair(){Object.assign(repairForm,{faultCause:'',solution:'',partsUsed:'',downtimeMinutes:null,maintenanceCost:null,result:'SUCCESS',comment:''});snapshots.repair=JSON.stringify(repairForm);repairVisible.value=true}function openAccept(){Object.assign(acceptForm,{acceptanceResult:'PASSED',acceptanceContent:'',comment:''});snapshots.accept=JSON.stringify(acceptForm);acceptVisible.value=true}
async function closeDialog(kind:'assign'|'repair'|'accept'){const visible={assign:assignVisible,repair:repairVisible,accept:acceptVisible}[kind],form={assign:assignForm,repair:repairForm,accept:acceptForm}[kind];if(JSON.stringify(form)!==snapshots[kind]){try{await ElMessageBox.confirm('表单尚未提交，确定放弃吗？','放弃编辑',{type:'warning'});}catch{return}}visible.value=false}
const successMessages: Record<string, string> = {
  assign: '工单已成功分派给责任维修工程师。',
  start: '现场维修已开始，工单进入处理中状态。',
  'repair-result': '现场维修记录已提交，工单进入待验收状态。'
};

const nextStepGuidance = computed(() => {
  if (!order.value) return null;
  switch (order.value.status) {
    case 'PENDING':
      return isAdmin.value
        ? { title: '【待分派】工单已创建，请选择启用的维修工程师进行派工。', type: 'warning' as const, canAction: true, actionType: 'assign' }
        : { title: '【待分派】工单尚未分派责任工程师，请等待主管分派。', type: 'info' as const, canAction: false };
    case 'ASSIGNED':
      return canRepair.value
        ? { title: '【待开工】工单已分派给您，请核对设备与故障事实，到场后点击【开始维修】进入处理。', type: 'warning' as const, canAction: true, actionType: 'start' }
        : { title: `【已分派】已指派给【${person(order.value.assigneeUserId)}】，等待工程师到场开工。`, type: 'info' as const, canAction: false };
    case 'PROCESSING':
      return canRepair.value
        ? { title: '【维修中】现场检修正在进行。维修完成后，请录入故障根本原因、解决方案、停机时间及备件消耗并提交验收。', type: 'warning' as const, canAction: true, actionType: 'repair' }
        : { title: `【维修中】责任工程师【${person(order.value.assigneeUserId)}】正在现场检修中。`, type: 'info' as const, canAction: false };
    case 'WAITING_ACCEPTANCE':
      return isAdmin.value && !isAssignee.value
        ? { title: '【待验收】维修人员已提交现场维修记录。请核实修复质量并执行验收合格或驳回返修。', type: 'warning' as const, canAction: true, actionType: 'accept' }
        : isAssignee.value
        ? { title: '【等待验收】您已成功提交维修记录，等待业务管理员复核验收。', type: 'info' as const, canAction: false }
        : { title: '【等待验收】现场维修记录已提交，等待业务管理员复核验收。', type: 'info' as const, canAction: false };
    case 'COMPLETED':
      return { title: '【已完结】维修工单已通过验收，现场已恢复正常运行，关联缺陷已同步解决闭环。', type: 'success' as const, canAction: false };
    default:
      return null;
  }
});

async function execute(kind:'assign'|'start'|'repair-result'|'acceptance',body?:unknown,params?:unknown){if(!order.value||busy.value)return;busy.value=kind;try{await request.post(`/api/maintenance/work-orders/${order.value.id}/${kind}`,body,{params});if(kind==='acceptance'){const result=(body as any)?.acceptanceResult;ElMessage.success(result==='PASSED'?'验收通过，维修工单已完结，关联缺陷已同步解决。':'验收已驳回，工单已退回维修中，请维修人员返修。');}else{ElMessage.success(successMessages[kind]||'工单操作成功');}assignVisible.value=repairVisible.value=acceptVisible.value=false;await load();}catch(e:any){if(e.response?.status===409)await load();}finally{busy.value='';}}
async function submitAssign(){if(busy.value)return;if(!assignForm.assigneeUserId)return void ElMessage.warning('请选择启用的维修人员');try{await ElMessageBox.confirm('确认将工单分派给所选维修人员吗？','确认分派',{type:'warning'});await execute('assign',{...assignForm})}catch{/* 取消 */}}async function start(){if(busy.value)return;try{const {value}=await ElMessageBox.prompt('可填写开工说明','开始维修',{inputPlaceholder:'选填'});await execute('start',undefined,{comment:value||undefined});}catch{/* 取消 */}}async function submitRepair(){if(busy.value)return;if(!repairForm.solution.trim())return void ElMessage.warning('请填写维修方案');try{await ElMessageBox.confirm('确认提交维修结果并进入待验收吗？','提交维修结果',{type:'warning'});await execute('repair-result',{...repairForm})}catch{/* 取消 */}}async function submitAccept(){if(busy.value)return;if(!acceptForm.acceptanceContent.trim())return void ElMessage.warning('请填写验收说明');if(acceptForm.acceptanceResult==='REJECTED'&&!acceptForm.comment.trim())return void ElMessage.warning('驳回时必须填写原因');try{await ElMessageBox.confirm(acceptForm.acceptanceResult==='PASSED'?'验收通过将完成工单并解决关联缺陷，确认提交吗？':'确认驳回并退回维修中吗？','提交验收',{type:'warning'});await execute('acceptance',{...acceptForm})}catch{/* 取消 */}}
function beforeUnload(event:BeforeUnloadEvent){if(!dirty.value)return;event.preventDefault();event.returnValue='';}
onBeforeRouteLeave(async()=>{if(!dirty.value)return true;try{await ElMessageBox.confirm('当前表单尚未提交，确定离开吗？','离开页面',{type:'warning'});return true}catch{return false}});onMounted(()=>{window.addEventListener('beforeunload',beforeUnload);void load();});onBeforeUnmount(()=>window.removeEventListener('beforeunload',beforeUnload));
</script>

<template>
  <section class="detail-page">
    <div class="page-head">
      <div>
        <el-button link @click="router.push('/maintenance/work-orders')">← 返回工单列表</el-button>
        <h1>维修工单详情</h1>
        <p>按分派派工、现场开始维修、录入维修记录以及业务管理员验收的闭环职责链推进。</p>
      </div>
      <div v-if="order" class="head-actions">
        <el-button v-if="isAdmin&&auth.can('maintenance:workorder:process')&&order.status==='PENDING'" type="primary" @click="openAssign">分派工单</el-button>
        <el-button v-if="canRepair&&order.status==='ASSIGNED'" type="primary" :loading="busy==='start'" @click="start">开始维修</el-button>
        <el-button v-if="canRepair&&order.status==='PROCESSING'" type="primary" @click="openRepair">提交维修结果</el-button>
        <el-button v-if="isAdmin&&auth.can('maintenance:workorder:accept')&&!isAssignee&&order.status==='WAITING_ACCEPTANCE'" type="success" @click="openAccept">验收工单</el-button>
      </div>
    </div>

    <!-- Steps -->
    <el-card v-if="order" shadow="never" class="steps-card">
      <el-steps :active="['PENDING','ASSIGNED','PROCESSING','WAITING_ACCEPTANCE','COMPLETED'].indexOf(order.status)" finish-status="success" align-center>
        <el-step title="待分派" :description="order.status==='PENDING'?'待指派工程师':''" />
        <el-step title="已分派" :description="order.status==='ASSIGNED'?'待到场开工':''" />
        <el-step title="维修中" :description="order.status==='PROCESSING'?'现场处理中':''" />
        <el-step title="待验收" :description="order.status==='WAITING_ACCEPTANCE'?'待管理员复核':''" />
        <el-step title="已完结" :description="order.status==='COMPLETED'?'闭环完成':''" />
      </el-steps>
    </el-card>

    <!-- Context Guidance Banner -->
    <div v-if="nextStepGuidance" class="guidance-banner">
      <el-alert
        :title="nextStepGuidance.title"
        :type="nextStepGuidance.type"
        show-icon
        :closable="false"
      >
        <template v-if="nextStepGuidance.canAction" #default>
          <div class="banner-action-row">
            <el-button
              v-if="nextStepGuidance.actionType==='assign'"
              size="small"
              type="primary"
              @click="openAssign"
            >
              立即分派工单
            </el-button>
            <el-button
              v-else-if="nextStepGuidance.actionType==='start'"
              size="small"
              type="primary"
              :loading="busy==='start'"
              @click="start"
            >
              确认开工
            </el-button>
            <el-button
              v-else-if="nextStepGuidance.actionType==='repair'"
              size="small"
              type="primary"
              @click="openRepair"
            >
              录入维修记录
            </el-button>
            <el-button
              v-else-if="nextStepGuidance.actionType==='accept'"
              size="small"
              type="success"
              @click="openAccept"
            >
              执行验收评定
            </el-button>
          </div>
        </template>
      </el-alert>
    </div>

    <el-alert v-if="errorMessage" :title="errorMessage" type="error" show-icon :closable="false">
      <template #default><el-button link @click="load">重新加载</el-button></template>
    </el-alert>

    <template v-else-if="order">
      <el-card v-loading="loading" shadow="never">
        <template #header><strong>工单基础信息</strong></template>
        <el-descriptions :column="3" border>
          <el-descriptions-item label="工单编号">{{order.workOrderCode}}</el-descriptions-item>
          <el-descriptions-item label="工单状态"><el-tag>{{displayValue(order.status)}}</el-tag></el-descriptions-item>
          <el-descriptions-item label="优先级">
            <el-tag :type="order.priority==='URGENT'||order.priority==='HIGH'?'danger':'info'">{{displayValue(order.priority)}}</el-tag>
          </el-descriptions-item>
          <el-descriptions-item label="工单标题" :span="2">{{order.title}}</el-descriptions-item>
          <el-descriptions-item label="工单类型">{{displayValue(order.workOrderType)}}</el-descriptions-item>
          <el-descriptions-item label="工单描述" :span="3">{{order.description||'-'}}</el-descriptions-item>
          <el-descriptions-item label="创建人员">{{person(order.creatorUserId)}}</el-descriptions-item>
          <el-descriptions-item label="责任维修人员">
            <span v-if="order.assigneeUserId">{{person(order.assigneeUserId)}}</span>
            <el-tag v-else type="info">尚未分派</el-tag>
          </el-descriptions-item>
          <el-descriptions-item label="创建时间">{{dateTime(order.createdAt)}}</el-descriptions-item>
          <el-descriptions-item label="计划时段" :span="2">{{dateTime(order.plannedStartTime)}} 至 {{dateTime(order.plannedEndTime)}}</el-descriptions-item>
          <el-descriptions-item label="实际执行时段">{{dateTime(order.actualStartTime)}} 至 {{dateTime(order.actualEndTime)}}</el-descriptions-item>
          <el-descriptions-item v-if="order.closeResult" label="完工结论" :span="3">{{order.closeResult}}</el-descriptions-item>
        </el-descriptions>
      </el-card>

      <el-row :gutter="16">
        <el-col :xs="24" :lg="8">
          <el-card class="full-card" shadow="never">
            <template #header><strong>关联设备</strong></template>
            <p class="card-entity-title">{{device?`${device.deviceName}（${device.deviceCode}）`:'设备信息加载中'}}</p>
            <el-button link type="primary" @click="router.push(`/devices/${order.deviceId}`)">查看设备详情 →</el-button>
          </el-card>
        </el-col>
        <el-col :xs="24" :lg="8">
          <el-card class="full-card" shadow="never">
            <template #header><strong>关联维修缺陷</strong></template>
            <template v-if="defect">
              <p class="card-entity-title">{{defect.defectCode}} · {{defect.title}}</p>
              <div class="card-entity-sub">
                <el-tag size="small">{{displayValue(defect.status)}}</el-tag>
                <el-button link type="primary" @click="router.push(`/maintenance/defects/${defect.id}`)">查看缺陷 →</el-button>
              </div>
            </template>
            <el-empty v-else description="无关联缺陷" :image-size="60" />
          </el-card>
        </el-col>
        <el-col :xs="24" :lg="8">
          <el-card class="full-card" shadow="never">
            <template #header><strong>AI 辅助研判建议</strong></template>
            <template v-if="diagnosis">
              <p class="card-entity-title">{{diagnosis.diagnosis.diagnosisCode}}</p>
              <div class="ai-advice-preview">
                <el-tag size="small" :type="diagnosis.diagnosis.riskLevel==='CRITICAL'||diagnosis.diagnosis.riskLevel==='HIGH'?'danger':'warning'">
                  风险：{{displayValue(diagnosis.diagnosis.riskLevel)}}
                </el-tag>
                <p v-if="diagnosis.diagnosis.maintenanceAdvice" class="advice-text">
                  建议方案：{{diagnosis.diagnosis.maintenanceAdvice}}
                </p>
              </div>
              <el-button link type="primary" @click="router.push(`/ai/diagnoses/${diagnosis.diagnosis.id}`)">查看 AI 诊断详情 →</el-button>
            </template>
            <el-empty v-else description="本工单未采用 AI 诊断" :image-size="60" />
          </el-card>
        </el-col>
      </el-row>

      <el-card shadow="never">
        <template #header><strong>维修记录</strong></template>
        <el-table v-if="detail?.records.length" :data="detail.records">
          <el-table-column prop="faultCause" label="故障根本原因" min-width="170"/>
          <el-table-column prop="solution" label="实施方案" min-width="210"/>
          <el-table-column prop="partsUsed" label="消耗备件" min-width="140">
            <template #default="s">{{s.row.partsUsed || '无消耗'}}</template>
          </el-table-column>
          <el-table-column label="修复结果" width="105">
            <template #default="s">
              <el-tag :type="s.row.result==='SUCCESS'?'success':s.row.result==='PARTIAL'?'warning':'danger'">
                {{displayValue(s.row.result)}}
              </el-tag>
            </template>
          </el-table-column>
          <el-table-column label="停机 / 费用" min-width="150">
            <template #default="s">{{s.row.downtimeMinutes??0}} 分钟 / ¥{{s.row.maintenanceCost??0}}</template>
          </el-table-column>
          <el-table-column label="维修人员" min-width="140">
            <template #default="s">{{person(s.row.repairedBy)}}</template>
          </el-table-column>
          <el-table-column label="完成时间" min-width="165">
            <template #default="s">{{dateTime(s.row.repairedAt)}}</template>
          </el-table-column>
        </el-table>
        <el-empty v-else description="尚无现场维修记录" />
      </el-card>

      <el-card shadow="never">
        <template #header><strong>验收记录</strong></template>
        <el-table v-if="detail?.acceptances.length" :data="detail.acceptances">
          <el-table-column label="验收结论" width="120">
            <template #default="s"><el-tag :type="s.row.acceptanceResult==='PASSED'?'success':'danger'">{{displayValue(s.row.acceptanceResult)}}</el-tag></template>
          </el-table-column>
          <el-table-column prop="acceptanceContent" label="验收说明与核验内容" min-width="260"/>
          <el-table-column label="验收人员" min-width="140">
            <template #default="s">{{person(s.row.acceptedBy)}}</template>
          </el-table-column>
          <el-table-column label="验收时间" min-width="165">
            <template #default="s">{{dateTime(s.row.acceptedAt)}}</template>
          </el-table-column>
        </el-table>
        <el-empty v-else description="尚未进行验收评定" />
      </el-card>

      <el-card shadow="never">
        <template #header><strong>全流程流转日志</strong></template>
        <el-timeline v-if="detail?.logs.length">
          <el-timeline-item v-for="x in detail.logs" :key="x.id" :timestamp="dateTime(x.createdAt)" placement="top">
            <strong>{{displayValue(x.action)}}：{{displayValue(x.fromStatus)}} → {{displayValue(x.toStatus)}}</strong>
            <div class="muted">操作人员：{{person(x.operatorUserId)}}<span v-if="x.comment"> · 备注：{{x.comment}}</span></div>
          </el-timeline-item>
        </el-timeline>
        <el-empty v-else description="暂无流转日志"/>
      </el-card>
    </template>

    <el-dialog v-model="assignVisible" title="分派维修工单" width="560px" :close-on-click-modal="!busy" :before-close="()=>closeDialog('assign')">
      <el-form label-width="90px">
        <el-form-item label="维修人员" required>
          <el-select v-model="assignForm.assigneeUserId" filterable remote :remote-method="searchMaintainers" :disabled="Boolean(busy)" placeholder="仅可选择启用的维修人员">
            <el-option v-for="u in maintainers" :key="u.id" :label="userLabel(u)" :value="u.id"/>
          </el-select>
        </el-form-item>
        <el-form-item label="分派说明">
          <el-input v-model="assignForm.comment" type="textarea" :disabled="Boolean(busy)" placeholder="可填写派工要求或特殊注意事项"/>
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button :disabled="Boolean(busy)" @click="closeDialog('assign')">取消</el-button>
        <el-button type="primary" :loading="busy==='assign'" :disabled="Boolean(busy)" @click="submitAssign">确认分派</el-button>
      </template>
    </el-dialog>

    <el-dialog v-model="repairVisible" title="录入维修结果" width="680px" :close-on-click-modal="!busy" :before-close="()=>closeDialog('repair')">
      <el-form label-width="105px">
        <el-form-item label="故障原因">
          <el-input v-model="repairForm.faultCause" type="textarea" :disabled="Boolean(busy)" placeholder="简要说明导致设备故障的根本原因"/>
        </el-form-item>
        <el-form-item label="维修方案" required>
          <el-input v-model="repairForm.solution" type="textarea" :rows="3" :disabled="Boolean(busy)" placeholder="详细说明采取的维修技术手段、更换步骤及处理结果"/>
        </el-form-item>
        <el-form-item label="使用备件">
          <el-input v-model="repairForm.partsUsed" :disabled="Boolean(busy)" placeholder="例如：滚动轴承 6205-2RS 1个、润滑油脂 100g"/>
        </el-form-item>
        <el-row :gutter="16">
          <el-col :span="12">
            <el-form-item label="停机时间">
              <el-input-number v-model="repairForm.downtimeMinutes" :min="0" :disabled="Boolean(busy)"/>
              <span class="input-unit">分钟</span>
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="维修费用">
              <el-input-number v-model="repairForm.maintenanceCost" :min="0" :precision="2" :disabled="Boolean(busy)"/>
              <span class="input-unit">元</span>
            </el-form-item>
          </el-col>
        </el-row>
        <el-form-item label="修复结果" required>
          <el-radio-group v-model="repairForm.result" :disabled="Boolean(busy)">
            <el-radio-button v-for="x in ['SUCCESS','PARTIAL','FAILED']" :key="x" :value="x">{{displayValue(x)}}</el-radio-button>
          </el-radio-group>
        </el-form-item>
        <el-form-item label="处理备注">
          <el-input v-model="repairForm.comment" type="textarea" :disabled="Boolean(busy)" placeholder="选填"/>
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button :disabled="Boolean(busy)" @click="closeDialog('repair')">取消</el-button>
        <el-button type="primary" :loading="busy==='repair-result'" :disabled="Boolean(busy)" @click="submitRepair">提交维修记录</el-button>
      </template>
    </el-dialog>

    <el-dialog v-model="acceptVisible" title="工单验收评定" width="620px" :close-on-click-modal="!busy" :before-close="()=>closeDialog('accept')">
      <el-alert title="验收通过将正式完结工单，并同步将关联缺陷更新为【已解决】；若驳回将退回【维修处理中】由工程师重新检修。" type="info" show-icon :closable="false"/>
      <el-form label-width="95px" class="dialog-form">
        <el-form-item label="验收结论" required>
          <el-radio-group v-model="acceptForm.acceptanceResult" :disabled="Boolean(busy)">
            <el-radio-button value="PASSED">验收合格通过</el-radio-button>
            <el-radio-button value="REJECTED">驳回要求返修</el-radio-button>
          </el-radio-group>
        </el-form-item>
        <el-form-item label="验收评定" required>
          <el-input v-model="acceptForm.acceptanceContent" type="textarea" :rows="3" :disabled="Boolean(busy)" placeholder="请录入现场查验情况，如试运行平稳、参数在正常区间等"/>
        </el-form-item>
        <el-form-item label="驳回/审核备注" :required="acceptForm.acceptanceResult==='REJECTED'">
          <el-input v-model="acceptForm.comment" type="textarea" :disabled="Boolean(busy)" :placeholder="acceptForm.acceptanceResult==='REJECTED'?'请详细填写驳回原因与返修要求':'选填'"/>
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button :disabled="Boolean(busy)" @click="closeDialog('accept')">取消</el-button>
        <el-button type="primary" :loading="busy==='acceptance'" :disabled="Boolean(busy)" @click="submitAccept">提交验收结论</el-button>
      </template>
    </el-dialog>
  </section>
</template>

<style scoped>
.detail-page{display:flex;flex-direction:column;gap:16px}
.head-actions{display:flex;gap:10px}
.full-card{height:100%}
.steps-card{padding:8px 0}
.guidance-banner{margin-bottom:0}
.banner-action-row{margin-top:8px}
.card-entity-title{font-weight:600;margin:0 0 8px 0}
.card-entity-sub{display:flex;align-items:center;gap:8px}
.ai-advice-preview{margin:6px 0 10px 0}
.advice-text{font-size:13px;color:var(--el-text-color-regular);margin-top:6px;line-height:1.4}
.muted{color:var(--el-text-color-secondary);margin-top:6px}
.dialog-form{margin-top:18px}
.input-unit{margin-left:8px;font-size:13px;color:var(--el-text-color-secondary)}
.detail-page :deep(.el-dialog .el-select){width:100%}
</style>
