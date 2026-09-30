<script setup lang="ts">
import {onMounted,ref} from 'vue'
import {request} from '../api/request'
import {useRoute} from 'vue-router'
import {ElMessage} from 'element-plus'
import {useAuthStore} from '../stores/auth'
const route=useRoute(),auth=useAuthStore(),d=ref<any>(),busy=ref(false),repair=ref<any>({}),accept=ref<any>({acceptanceResult:'PASS'})
async function load(){d.value=await request.get('/api/maintenance/work-orders/'+route.params.id)}
async function go(x:string,b?:any){busy.value=true;try{await request.post('/api/maintenance/work-orders/'+route.params.id+'/'+x,b);ElMessage.success('操作成功');load()}finally{busy.value=false}}
onMounted(load)
</script>
<template><section><h1>工单详情</h1><el-card v-loading="!d"><pre>{{d?.workOrder}}</pre><el-button v-if="auth.can('maintenance:workorder:process')" :loading="busy" @click="go('start')">开始维修</el-button><el-input v-if="auth.can('maintenance:workorder:process')" v-model="repair.solution" placeholder="维修方案"/><el-button v-if="auth.can('maintenance:workorder:process')" :loading="busy" @click="go('repair-result',repair)">提交维修结果</el-button><template v-if="auth.can('maintenance:workorder:accept')"><el-input v-model="accept.acceptanceContent" placeholder="验收说明"/><el-button :loading="busy" @click="go('acceptance',accept)">提交验收</el-button></template><h3>日志</h3><pre>{{d?.logs}}</pre><h3>维修/验收记录</h3><pre>{{d?.records}} {{d?.acceptances}}</pre></el-card></section></template>
