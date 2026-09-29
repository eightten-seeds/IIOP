<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { request } from '../api/request'
import { useRoute } from 'vue-router'
const p=defineProps<{title:string,api:string,kind:string}>()
const d=ref<any>(),route=useRoute()
onMounted(async()=>{ d.value=await request.get(p.api+'/'+route.params.id) })
</script>
<template><section><h1>{{title}}详情</h1><el-card v-loading="!d"><el-descriptions v-if="d" :column="2"><el-descriptions-item v-for="(v,k) in d" :key="String(k)" :label="String(k)"><RouterLink v-if="String(k)==='deviceId'&&v" :to="'/devices/'+v">{{v}}</RouterLink><RouterLink v-else-if="String(k)==='taskId'&&v" :to="'/inspection/tasks/'+v">{{v}}</RouterLink><RouterLink v-else-if="String(k)==='aiDiagnosisId'&&v" :to="'/ai/diagnoses/'+v">{{v}}</RouterLink><span v-else>{{typeof v==='object'?JSON.stringify(v):v}}</span></el-descriptions-item></el-descriptions></el-card></section></template>
