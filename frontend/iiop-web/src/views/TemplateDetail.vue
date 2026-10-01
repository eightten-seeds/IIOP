<script setup lang="ts">
import { computed, onMounted, reactive, ref } from 'vue';
import { ElMessage, ElMessageBox } from 'element-plus';
import { useRoute, useRouter } from 'vue-router';
import { request } from '../api/request';
import { useAuthStore } from '../stores/auth';
import { categoryNameMap, type CategoryTree } from '../types/device';
import type { InspectionTemplate, ItemType, TemplateItem } from '../types/inspection';
import { displayValue } from '../utils/display';

interface ItemForm {
  itemCode: string; itemName: string; itemType: ItemType; unit: string; standardValue: string;
  lowerLimit: number | null; upperLimit: number | null; requiredFlag: number; inspectionMethod: string;
  abnormalHint: string; sortOrder: number;
}
const emptyItem = (): ItemForm => ({ itemCode: '', itemName: '', itemType: 'NUMBER', unit: '', standardValue: '', lowerLimit: null, upperLimit: null, requiredFlag: 1, inspectionMethod: '', abnormalHint: '', sortOrder: 0 });

const route = useRoute();
const router = useRouter();
const auth = useAuthStore();
const detail = ref<InspectionTemplate>();
const items = ref<TemplateItem[]>([]);
const categoryNames = reactive<Record<string, string>>({});
const loading = ref(false);
const errorMessage = ref('');
const flow = ref('');
const flowSaving = ref(false);
const flowSections = ref<string[]>([]);
const itemVisible = ref(false);
const editingItemId = ref('');
const itemSaving = ref(false);
const deletingItemId = ref('');
const itemForm = reactive<ItemForm>(emptyItem());
const requiredPhoto = computed(() => items.value.some(item => item.itemType === 'PHOTO' && item.requiredFlag === 1));
const editingPhoto = computed(() => Boolean(editingItemId.value) && itemForm.itemType === 'PHOTO');

function typeTag(type: ItemType) { return type === 'PHOTO' ? 'danger' : type === 'NUMBER' ? 'primary' : type === 'BOOLEAN' ? 'success' : 'info'; }

async function load() {
  loading.value = true;
  errorMessage.value = '';
  try {
    const id = String(route.params.id);
    const [template, templateItems, categories] = await Promise.all([
      request.get<never, InspectionTemplate>(`/api/inspection/templates/${id}`),
      request.get<never, TemplateItem[]>(`/api/inspection/templates/${id}/items`),
      request.get<never, CategoryTree[]>('/api/device/categories/tree')
    ]);
    detail.value = template;
    items.value = templateItems ?? [];
    flow.value = template.flowDefinition ?? '';
    Object.assign(categoryNames, categoryNameMap(categories ?? []));
  } catch { errorMessage.value = '模板详情加载失败，请检查服务状态后重试。'; }
  finally { loading.value = false; }
}

function openCreateItem() {
  editingItemId.value = '';
  Object.assign(itemForm, emptyItem(), { sortOrder: items.value.length + 1 });
  itemVisible.value = true;
}

function openEditItem(item: TemplateItem) {
  editingItemId.value = item.id;
  Object.assign(itemForm, {
    itemCode: item.itemCode, itemName: item.itemName, itemType: item.itemType, unit: item.unit ?? '',
    standardValue: item.standardValue ?? '', lowerLimit: item.lowerLimit, upperLimit: item.upperLimit,
    requiredFlag: item.requiredFlag, inspectionMethod: item.inspectionMethod ?? '', abnormalHint: item.abnormalHint ?? '', sortOrder: item.sortOrder
  });
  itemVisible.value = true;
}

function changeItemType(type: ItemType) {
  if (type !== 'NUMBER') { itemForm.unit = ''; itemForm.lowerLimit = null; itemForm.upperLimit = null; }
  if (type === 'TEXT') itemForm.standardValue = '';
}

async function saveItem() {
  if (!itemForm.itemCode.trim() || !itemForm.itemName.trim()) return void ElMessage.warning('请填写检查项编码和名称');
  itemSaving.value = true;
  try {
    const payload = { ...itemForm };
    const templateId = String(route.params.id);
    if (editingItemId.value) await request.put(`/api/inspection/templates/${templateId}/items/${editingItemId.value}`, payload);
    else await request.post(`/api/inspection/templates/${templateId}/items`, payload);
    ElMessage.success(editingItemId.value ? '检查项更新成功' : '检查项创建成功');
    itemVisible.value = false;
    await load();
  } finally { itemSaving.value = false; }
}

async function deleteItem(item: TemplateItem) {
  try {
    await ElMessageBox.confirm(`确认删除检查项“${item.itemName}”吗？`, '删除检查项', { type: 'error', confirmButtonText: '删除', cancelButtonText: '取消' });
  } catch { return; }
  deletingItemId.value = item.id;
  try {
    await request.delete(`/api/inspection/template-items/${item.id}`);
    ElMessage.success('检查项已删除');
    await load();
  } finally { deletingItemId.value = ''; }
}

async function saveFlow() {
  flowSaving.value = true;
  try {
    await request.put(`/api/inspection/templates/${route.params.id}/flow-definition`, { flowDefinition: flow.value || null });
    ElMessage.success('流程定义已保存');
    await load();
  } finally { flowSaving.value = false; }
}

onMounted(load);
</script>

<template>
  <section class="template-detail">
    <div class="page-head"><div><el-button link @click="router.push('/inspection/templates')">← 返回模板列表</el-button><h1>巡检模板详情</h1><p>维护模板基本信息、检查项与已保存的流程定义。</p></div></div>
    <el-alert v-if="errorMessage" :title="errorMessage" type="error" show-icon :closable="false"><template #default><el-button link type="primary" @click="load">重新加载</el-button></template></el-alert>
    <template v-else>
      <el-card v-loading="loading" shadow="never">
        <template #header><strong>模板基本信息</strong></template>
        <el-descriptions v-if="detail" :column="3" border>
          <el-descriptions-item label="模板编码">{{ detail.templateCode }}</el-descriptions-item><el-descriptions-item label="模板名称">{{ detail.templateName }}</el-descriptions-item>
          <el-descriptions-item label="模板状态"><el-tag :type="detail.status==='ENABLED'?'success':detail.status==='DRAFT'?'warning':'info'">{{ displayValue(detail.status) }}</el-tag></el-descriptions-item>
          <el-descriptions-item label="设备分类">{{ categoryNames[detail.categoryId] || '未知分类' }}</el-descriptions-item><el-descriptions-item label="版本">v{{ detail.version }}</el-descriptions-item>
          <el-descriptions-item label="模板描述" :span="3">{{ detail.description || '暂无描述' }}</el-descriptions-item>
        </el-descriptions>
      </el-card>
      <el-alert v-if="requiredPhoto" title="该模板包含必填 PHOTO 检查项，第一版巡检执行暂不支持，请先调整模板后再用于巡检计划。" type="error" show-icon :closable="false" />
      <el-card shadow="never">
        <template #header><div class="card-head"><div><strong>检查项管理</strong><p>第一版支持数值、正常/异常与文本检查；历史图片项仅保留查看和调整。</p></div><el-button v-if="auth.can('inspection:template:manage')" type="primary" @click="openCreateItem">新增检查项</el-button></div></template>
        <el-table :data="items" row-key="id">
          <el-table-column prop="itemCode" label="检查项编码" min-width="130" /><el-table-column prop="itemName" label="检查项名称" min-width="150" />
          <el-table-column label="类型" width="110"><template #default="scope"><el-tag :type="typeTag(scope.row.itemType)">{{ displayValue(scope.row.itemType) }}</el-tag></template></el-table-column>
          <el-table-column prop="unit" label="单位" width="80"><template #default="scope">{{ scope.row.unit || '-' }}</template></el-table-column>
          <el-table-column prop="standardValue" label="标准值" min-width="110"><template #default="scope">{{ scope.row.standardValue ? displayValue(scope.row.standardValue) : '-' }}</template></el-table-column>
          <el-table-column label="下限 / 上限" min-width="130"><template #default="scope">{{ scope.row.lowerLimit ?? '-' }} / {{ scope.row.upperLimit ?? '-' }}</template></el-table-column>
          <el-table-column label="是否必填" width="90"><template #default="scope">{{ scope.row.requiredFlag===1?'必填':'选填' }}</template></el-table-column>
          <el-table-column prop="inspectionMethod" label="检查方法" min-width="170"><template #default="scope">{{ scope.row.inspectionMethod || '-' }}</template></el-table-column>
          <el-table-column prop="abnormalHint" label="异常提示" min-width="170"><template #default="scope">{{ scope.row.itemType==='PHOTO'?'第一版暂不支持图片巡检执行':scope.row.abnormalHint || '-' }}</template></el-table-column>
          <el-table-column prop="sortOrder" label="排序" width="70" />
          <el-table-column v-if="auth.can('inspection:template:manage')" label="操作" width="130" fixed="right"><template #default="scope"><el-button link @click="openEditItem(scope.row)">编辑</el-button><el-button link type="danger" :loading="deletingItemId===scope.row.id" @click="deleteItem(scope.row)">删除</el-button></template></el-table-column>
        </el-table>
        <el-empty v-if="!items.length&&!loading" description="尚未配置检查项"><el-button v-if="auth.can('inspection:template:manage')" type="primary" @click="openCreateItem">新增检查项</el-button></el-empty>
      </el-card>
      <el-card shadow="never">
        <el-collapse v-model="flowSections"><el-collapse-item title="流程定义（可视化将在 S4-B 配置）" name="flow">
          <el-empty v-if="!flow" description="流程图将在可视化阶段配置" />
          <template v-if="flow||auth.can('inspection:template:manage')"><p class="section-note">当前仅保留已有 flowDefinition 的保存与回显，不修改流程结构。</p><el-input v-model="flow" type="textarea" :rows="7" :disabled="!auth.can('inspection:template:manage')||flowSaving" placeholder="可继续维护已有流程定义；可视化编辑将在 S4-B 完成" /><el-button v-if="auth.can('inspection:template:manage')" type="primary" :loading="flowSaving" @click="saveFlow">保存流程定义</el-button></template>
        </el-collapse-item></el-collapse>
      </el-card>
    </template>

    <el-dialog v-model="itemVisible" :title="editingItemId?'编辑检查项':'新增检查项'" width="760px" :close-on-click-modal="!itemSaving">
      <el-alert v-if="editingPhoto" title="这是历史 PHOTO 检查项。第一版不支持图片巡检执行，也不提供上传控件；可调整为其他支持类型。" type="warning" show-icon :closable="false" />
      <el-form label-width="105px" class="item-form"><el-row :gutter="18">
        <el-col :span="12"><el-form-item label="检查项编码" required><el-input v-model="itemForm.itemCode" :disabled="itemSaving" /></el-form-item></el-col><el-col :span="12"><el-form-item label="检查项名称" required><el-input v-model="itemForm.itemName" :disabled="itemSaving" /></el-form-item></el-col>
        <el-col :span="12"><el-form-item label="检查项类型" required><el-select v-model="itemForm.itemType" :disabled="itemSaving" @change="changeItemType"><el-option label="数值检查" value="NUMBER" /><el-option label="正常/异常检查" value="BOOLEAN" /><el-option label="文本检查" value="TEXT" /><el-option v-if="editingPhoto" label="图片检查（历史数据）" value="PHOTO" disabled /></el-select></el-form-item></el-col>
        <el-col :span="12"><el-form-item label="是否必填"><el-switch v-model="itemForm.requiredFlag" :active-value="1" :inactive-value="0" active-text="必填" inactive-text="选填" :disabled="itemSaving" /></el-form-item></el-col>
        <template v-if="itemForm.itemType==='NUMBER'"><el-col :span="12"><el-form-item label="单位"><el-input v-model="itemForm.unit" :disabled="itemSaving" placeholder="例如 ℃、MPa" /></el-form-item></el-col><el-col :span="12"><el-form-item label="标准值"><el-input v-model="itemForm.standardValue" :disabled="itemSaving" /></el-form-item></el-col><el-col :span="12"><el-form-item label="允许下限"><el-input-number v-model="itemForm.lowerLimit" controls-position="right" :disabled="itemSaving" /></el-form-item></el-col><el-col :span="12"><el-form-item label="允许上限"><el-input-number v-model="itemForm.upperLimit" controls-position="right" :disabled="itemSaving" /></el-form-item></el-col></template>
        <el-col v-else-if="itemForm.itemType==='BOOLEAN'" :span="24"><el-alert title="巡检人员将明确选择“正常”或“异常”；请设置符合标准的结果。" type="info" show-icon :closable="false" /><el-form-item label="标准结果"><el-radio-group v-model="itemForm.standardValue" :disabled="itemSaving"><el-radio value="NORMAL">正常</el-radio><el-radio value="ABNORMAL">异常</el-radio></el-radio-group></el-form-item></el-col>
        <el-col v-else-if="itemForm.itemType==='TEXT'" :span="24"><el-alert title="文本检查用于记录观察结果，请在检查方法中写明需要填写的内容。" type="info" show-icon :closable="false" /></el-col>
        <el-col :span="24"><el-form-item label="检查方法"><el-input v-model="itemForm.inspectionMethod" type="textarea" :rows="2" :disabled="itemSaving" placeholder="说明现场如何完成本项检查" /></el-form-item></el-col><el-col :span="24"><el-form-item label="异常提示"><el-input v-model="itemForm.abnormalHint" type="textarea" :rows="2" :disabled="itemSaving" placeholder="说明何种情况应判定为异常" /></el-form-item></el-col><el-col :span="12"><el-form-item label="排序"><el-input-number v-model="itemForm.sortOrder" :min="0" :step="1" :disabled="itemSaving" /></el-form-item></el-col>
      </el-row></el-form>
      <template #footer><el-button :disabled="itemSaving" @click="itemVisible=false">取消</el-button><el-button type="primary" :loading="itemSaving" @click="saveItem">保存检查项</el-button></template>
    </el-dialog>
  </section>
</template>

<style scoped>
.template-detail{display:flex;flex-direction:column;gap:16px}.card-head{display:flex;align-items:flex-start;justify-content:space-between}.card-head p,.section-note{margin:6px 0;color:#667085;font-size:13px}.item-form{margin-top:18px}.item-form :deep(.el-select),.item-form :deep(.el-input-number){width:100%}.item-form :deep(.el-alert){margin-bottom:16px}.template-detail :deep(.el-collapse){border:0}.template-detail :deep(.el-collapse-item__header){font-weight:600}.template-detail :deep(.el-textarea)+.el-button{margin-top:12px}
</style>
