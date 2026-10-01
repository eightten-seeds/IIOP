<script setup lang="ts">
import { computed, reactive, ref, watch } from 'vue';
import { ElMessage, ElMessageBox } from 'element-plus';
import { onBeforeRouteLeave } from 'vue-router';
import { request } from '../api/request';
import type { WorkOrder, WorkOrderDraft } from '../types/maintenance';
import { displayValue } from '../utils/display';

const props = defineProps<{ visible:boolean; deviceId:string; deviceLabel:string; defectId?:string|null; aiDiagnosisId?:string|null; draft?:WorkOrderDraft|null }>();
const emit = defineEmits<{ 'update:visible':[value:boolean]; created:[value:WorkOrder] }>();
const saving = ref(false);
const initial = ref('');
const form = reactive({ title:'', description:'', workOrderType:'REPAIR', priority:'MEDIUM', plannedStartTime:null as string|null, plannedEndTime:null as string|null });
const dirty = computed(() => props.visible && JSON.stringify(form) !== initial.value);

watch(() => props.visible, (visible) => {
  if (!visible) return;
  Object.assign(form, { title:(props.draft?.title || '').slice(0, 100), description:[props.draft?.description, props.draft?.maintenanceAdvice, props.draft?.safetyNotice].filter(Boolean).join('\n'), workOrderType:'REPAIR', priority:props.draft?.priority || 'MEDIUM', plannedStartTime:null, plannedEndTime:null });
  initial.value = JSON.stringify(form);
});

async function beforeClose(done:()=>void) {
  if (!dirty.value || saving.value) return done();
  try { await ElMessageBox.confirm('工单内容尚未保存，确定放弃吗？', '放弃编辑', { type:'warning' }); done(); } catch { /* 保留表单 */ }
}

async function save() {
  if (!form.title.trim()) return void ElMessage.warning('请填写工单标题');
  if (!form.description.trim()) return void ElMessage.warning('请填写工单描述');
  if (form.plannedStartTime && form.plannedEndTime && form.plannedEndTime <= form.plannedStartTime) return void ElMessage.warning('计划结束时间应晚于开始时间');
  saving.value = true;
  try {
    const created = await request.post<never, WorkOrder>('/api/maintenance/work-orders', { ...form, deviceId:props.deviceId, defectId:props.defectId || null, aiDiagnosisId:props.aiDiagnosisId || null });
    initial.value = JSON.stringify(form);
    emit('update:visible', false); emit('created', created); ElMessage.success('维修工单已创建');
  } finally { saving.value = false; }
}
onBeforeRouteLeave(async () => {
  if (!dirty.value) return true;
  try { await ElMessageBox.confirm('工单内容尚未保存，确定离开吗？', '离开页面', { type:'warning' }); return true; }
  catch { return false; }
});
</script>

<template>
  <el-dialog :model-value="visible" title="创建维修工单" width="700px" :before-close="beforeClose" :close-on-click-modal="false" @update:model-value="emit('update:visible',$event)">
    <el-alert title="创建后需要管理员分派给维修人员，AI 草案不会自动落单。" type="info" show-icon :closable="false" />
    <el-form label-width="105px" class="order-form">
      <el-form-item label="关联设备"><el-input :model-value="deviceLabel" disabled /></el-form-item>
      <el-form-item label="工单标题" required><el-input v-model="form.title" maxlength="100" show-word-limit /></el-form-item>
      <el-form-item label="工单描述" required><el-input v-model="form.description" type="textarea" :rows="5" /></el-form-item>
      <el-row :gutter="16"><el-col :span="12"><el-form-item label="工单类型" required><el-select v-model="form.workOrderType"><el-option v-for="x in ['REPAIR','PREVENTIVE','EMERGENCY']" :key="x" :label="displayValue(x)" :value="x" /></el-select></el-form-item></el-col><el-col :span="12"><el-form-item label="优先级" required><el-select v-model="form.priority"><el-option v-for="x in ['LOW','MEDIUM','HIGH','URGENT']" :key="x" :label="displayValue(x)" :value="x" /></el-select></el-form-item></el-col></el-row>
      <el-row :gutter="16"><el-col :span="12"><el-form-item label="计划开始"><el-date-picker v-model="form.plannedStartTime" type="datetime" value-format="YYYY-MM-DDTHH:mm:ss" /></el-form-item></el-col><el-col :span="12"><el-form-item label="计划结束"><el-date-picker v-model="form.plannedEndTime" type="datetime" value-format="YYYY-MM-DDTHH:mm:ss" /></el-form-item></el-col></el-row>
    </el-form>
    <template #footer><el-button :disabled="saving" @click="beforeClose(()=>emit('update:visible',false))">取消</el-button><el-button type="primary" :loading="saving" @click="save">创建工单</el-button></template>
  </el-dialog>
</template>

<style scoped>.order-form{margin-top:18px}.order-form :deep(.el-select),.order-form :deep(.el-date-editor){width:100%}</style>
