<script setup lang="ts">
import { onMounted, reactive, ref } from 'vue';
import { useRouter } from 'vue-router';
import { request } from '../api/request';
import type { Device, PageResult } from '../types/device';
import type { Defect } from '../types/maintenance';
import { displayValue } from '../utils/display';

const router=useRouter(), rows=ref<Defect[]>([]), total=ref(0), page=ref(1), loading=ref(false), errorMessage=ref('');
const pageSize=20, deviceOptions=ref<Device[]>([]), deviceNames=reactive<Record<string,string>>({});
const filters=reactive({ status:'', severity:'', deviceId:'', sourceType:'' });
const dateTime=(v:string|null)=>v?v.replace('T',' ').slice(0,19):'-';
const deviceLabel=(d:Device)=>`${d.deviceName}（${d.deviceCode}）`;
async function searchDevices(keyword=''){const p=await request.get<never,PageResult<Device>>('/api/device/devices',{params:{pageNum:1,pageSize:20,keyword:keyword||undefined}});deviceOptions.value=p.records??[];deviceOptions.value.forEach(d=>deviceNames[d.id]=deviceLabel(d));}
async function resolveDevices(data:Defect[]){await Promise.allSettled([...new Set(data.map(x=>x.deviceId))].filter(id=>!deviceNames[id]).map(async id=>{const d=await request.get<never,Device>(`/api/device/devices/${id}`,{silentStatuses:[404]});deviceNames[id]=deviceLabel(d);}));}
async function load(){loading.value=true;errorMessage.value='';try{const p=await request.get<never,PageResult<Defect>>('/api/maintenance/defects',{params:{pageNum:page.value,pageSize,...Object.fromEntries(Object.entries(filters).map(([k,v])=>[k,v||undefined]))}});rows.value=p.records??[];total.value=p.total??0;await resolveDevices(rows.value);}catch{errorMessage.value='缺陷列表加载失败，请检查服务状态后重试。';}finally{loading.value=false;}}
function search(){page.value=1;void load()} function reset(){Object.assign(filters,{status:'',severity:'',deviceId:'',sourceType:''});search()}
onMounted(()=>{void searchDevices();void load()});
</script>

<template><section class="business-page">
  <div class="page-head"><div><h1>缺陷管理</h1><p>跟踪巡检异常或设备告警形成的缺陷，以及 AI 诊断和维修闭环。</p></div></div>
  <el-card shadow="never" class="filter-card"><el-form inline @submit.prevent="search">
    <el-form-item label="缺陷状态"><el-select v-model="filters.status" clearable placeholder="全部状态"><el-option v-for="x in ['OPEN','CONFIRMED','PROCESSING','RESOLVED','CLOSED']" :key="x" :label="displayValue(x)" :value="x" /></el-select></el-form-item>
    <el-form-item label="严重程度"><el-select v-model="filters.severity" clearable placeholder="全部等级"><el-option v-for="x in ['LOW','MEDIUM','HIGH','CRITICAL']" :key="x" :label="displayValue(x)" :value="x" /></el-select></el-form-item>
    <el-form-item label="来源"><el-select v-model="filters.sourceType" clearable placeholder="全部来源"><el-option v-for="x in ['INSPECTION_ABNORMAL','ALARM','MANUAL']" :key="x" :label="displayValue(x)" :value="x" /></el-select></el-form-item>
    <el-form-item label="设备"><el-select v-model="filters.deviceId" filterable remote clearable reserve-keyword :remote-method="searchDevices" placeholder="按设备名称或编码搜索"><el-option v-for="d in deviceOptions" :key="d.id" :label="deviceLabel(d)" :value="d.id" /></el-select></el-form-item>
    <el-form-item><el-button type="primary" @click="search">查询</el-button><el-button @click="reset">重置</el-button></el-form-item>
  </el-form></el-card>
  <el-card shadow="never"><el-alert v-if="errorMessage" :title="errorMessage" type="error" show-icon :closable="false"><template #default><el-button link @click="load">重新加载</el-button></template></el-alert>
    <el-table v-else v-loading="loading" :data="rows" row-key="id"><el-table-column prop="defectCode" label="缺陷编号" min-width="175"/><el-table-column prop="title" label="缺陷标题" min-width="190" show-overflow-tooltip/><el-table-column label="设备" min-width="220"><template #default="s">{{deviceNames[s.row.deviceId]||'设备信息加载中'}}</template></el-table-column><el-table-column label="来源" width="125"><template #default="s">{{displayValue(s.row.sourceType)}}</template></el-table-column><el-table-column label="等级" width="100"><template #default="s"><el-tag :type="s.row.severity==='CRITICAL'||s.row.severity==='HIGH'?'danger':s.row.severity==='MEDIUM'?'warning':'success'">{{displayValue(s.row.severity)}}</el-tag></template></el-table-column><el-table-column label="状态" width="105"><template #default="s"><el-tag>{{displayValue(s.row.status)}}</el-tag></template></el-table-column><el-table-column label="关联 AI" width="100"><template #default="s"><el-tag v-if="s.row.aiDiagnosisId" type="success">已绑定</el-tag><span v-else>未绑定</span></template></el-table-column><el-table-column label="上报时间" min-width="165"><template #default="s">{{dateTime(s.row.reportedAt)}}</template></el-table-column><el-table-column label="操作" width="100" fixed="right"><template #default="s"><el-button link type="primary" @click="router.push(`/maintenance/defects/${s.row.id}`)">查看详情</el-button></template></el-table-column></el-table>
    <el-empty v-if="!loading&&!errorMessage&&!rows.length" description="暂无符合条件的缺陷"/><el-pagination v-if="!errorMessage&&total>pageSize" v-model:current-page="page" :page-size="pageSize" :total="total" layout="prev, pager, next, total" @current-change="load" />
  </el-card>
</section></template>
<style scoped>.business-page{display:flex;flex-direction:column;gap:16px}.filter-card :deep(.el-select){width:210px}.business-page :deep(.el-pagination){justify-content:flex-end;margin-top:18px}</style>
