<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, onUnmounted, reactive, ref } from 'vue';
import { ElMessage, ElMessageBox } from 'element-plus';
import { onBeforeRouteLeave, useRouter } from 'vue-router';
import { request } from '../api/request';
import { useAuthStore } from '../stores/auth';
import { categoryNameMap, categoryOptions, type CategoryOption, type CategoryTree, type PageResult } from '../types/device';
import { emptyTemplateForm, type InspectionTemplate, type TemplateForm, type TemplateStatus } from '../types/inspection';
import { displayValue } from '../utils/display';

const STATUSES: TemplateStatus[] = ['DRAFT', 'ENABLED', 'DISABLED'];
const auth = useAuthStore();
const router = useRouter();
const rows = ref<InspectionTemplate[]>([]);
const total = ref(0);
const page = ref(1);
const pageSize = 20;
const loading = ref(false);
const errorMessage = ref('');
const filters = reactive<{ keyword: string; categoryId: string; status: '' | TemplateStatus }>({ keyword: '', categoryId: '', status: '' });
const categoryTree = ref<CategoryTree[]>([]);
const categorySelect = ref<CategoryOption[]>([]);
const categoryNames = reactive<Record<string, string>>({});
const formVisible = ref(false);
const formLoading = ref(false);
const saving = ref(false);
const editingId = ref('');
const form = reactive<TemplateForm>(emptyTemplateForm());
const initialSnapshot = ref('');
const formDirty = computed(() => formVisible.value && JSON.stringify(form) !== initialSnapshot.value);
const formTitle = computed(() => editingId.value ? '编辑巡检模板' : '新增巡检模板');

function statusTag(status: TemplateStatus) {
  return status === 'ENABLED' ? 'success' : status === 'DRAFT' ? 'warning' : 'info';
}

async function ensureCategories() {
  if (categoryTree.value.length) return;
  const tree = await request.get<never, CategoryTree[]>('/api/device/categories/tree');
  categoryTree.value = tree ?? [];
  categorySelect.value = categoryOptions(categoryTree.value);
  Object.assign(categoryNames, categoryNameMap(categoryTree.value));
}

async function load() {
  loading.value = true;
  errorMessage.value = '';
  try {
    const [, data] = await Promise.all([
      ensureCategories(),
      request.get<never, PageResult<InspectionTemplate>>('/api/inspection/templates', { params: {
        pageNum: page.value, pageSize, keyword: filters.keyword || undefined,
        categoryId: filters.categoryId || undefined, status: filters.status || undefined
      } })
    ]);
    rows.value = data.records ?? [];
    total.value = data.total ?? 0;
  } catch {
    errorMessage.value = '巡检模板加载失败，请检查服务状态后重试。';
  } finally {
    loading.value = false;
  }
}

function search() { page.value = 1; void load(); }
function resetFilters() { Object.assign(filters, { keyword: '', categoryId: '', status: '' }); search(); }

async function openCreate() {
  editingId.value = '';
  Object.assign(form, emptyTemplateForm());
  await ensureCategories();
  initialSnapshot.value = JSON.stringify(form);
  formVisible.value = true;
}

async function openEdit(row: InspectionTemplate) {
  editingId.value = row.id;
  formLoading.value = true;
  try {
    const [detail] = await Promise.all([
      request.get<never, InspectionTemplate>(`/api/inspection/templates/${row.id}`),
      ensureCategories()
    ]);
    Object.assign(form, {
      templateCode: detail.templateCode, templateName: detail.templateName, categoryId: detail.categoryId,
      version: detail.version, description: detail.description ?? '', status: detail.status
    });
    initialSnapshot.value = JSON.stringify(form);
    formVisible.value = true;
  } finally { formLoading.value = false; }
}

async function beforeCloseTemplate(done: () => void) {
  if (saving.value) return;
  if (!formDirty.value) return done();
  try {
    await ElMessageBox.confirm('巡检模板尚未保存，确定放弃吗？', '放弃编辑', { type: 'warning' });
    done();
  } catch { /* 保留表单 */ }
}

async function saveTemplate() {
  if (saving.value) return;
  if (!form.templateCode.trim() || !form.templateName.trim()) return void ElMessage.warning('请填写模板编码和模板名称');
  if (!form.categoryId) return void ElMessage.warning('请选择设备分类');
  saving.value = true;
  try {
    if (editingId.value) await request.put(`/api/inspection/templates/${editingId.value}`, { ...form });
    else await request.post('/api/inspection/templates', { ...form });
    ElMessage.success(editingId.value ? '巡检模板更新成功' : '巡检模板创建成功');
    initialSnapshot.value = JSON.stringify(form);
    formVisible.value = false;
    await load();
  } finally { saving.value = false; }
}

function beforeUnload(event: BeforeUnloadEvent) {
  if (!formDirty.value) return;
  event.preventDefault();
  event.returnValue = '';
}

onBeforeRouteLeave(async () => {
  if (!formDirty.value) return true;
  try {
    await ElMessageBox.confirm('巡检模板尚未保存，确定离开当前页面吗？', '未保存修改', {
      type: 'warning',
      confirmButtonText: '离开',
      cancelButtonText: '继续编辑'
    });
    return true;
  } catch {
    return false;
  }
});

onMounted(() => {
  window.addEventListener('beforeunload', beforeUnload);
  void load();
});

onBeforeUnmount(() => {
  window.removeEventListener('beforeunload', beforeUnload);
});
</script>

<template>
  <section class="inspection-page">
    <div class="page-head">
      <div><h1>巡检模板</h1><p>配置设备类别对应的检查标准与检查项，启用后可供巡检计划选择。</p></div>
      <el-button v-if="auth.can('inspection:template:manage')" type="primary" @click="openCreate">新增模板</el-button>
    </div>
    <el-card class="filter-card" shadow="never">
      <el-form inline @submit.prevent="search">
        <el-form-item label="关键词"><el-input v-model="filters.keyword" clearable placeholder="模板编码或名称" @keyup.enter="search" /></el-form-item>
        <el-form-item label="设备分类"><el-tree-select v-model="filters.categoryId" :data="categorySelect" clearable check-strictly placeholder="全部分类" /></el-form-item>
        <el-form-item label="模板状态"><el-select v-model="filters.status" clearable placeholder="全部状态"><el-option v-for="status in STATUSES" :key="status" :label="displayValue(status)" :value="status" /></el-select></el-form-item>
        <el-form-item><el-button type="primary" @click="search">查询</el-button><el-button @click="resetFilters">重置</el-button></el-form-item>
      </el-form>
    </el-card>
    <el-card shadow="never">
      <el-alert v-if="errorMessage" :title="errorMessage" type="error" show-icon :closable="false"><template #default><el-button link type="primary" @click="load">重新加载</el-button></template></el-alert>
      <el-table v-else v-loading="loading" :data="rows" row-key="id">
        <el-table-column prop="templateCode" label="模板编码" min-width="150" />
        <el-table-column prop="templateName" label="模板名称" min-width="180" />
        <el-table-column label="设备分类" min-width="140"><template #default="scope">{{ categoryNames[scope.row.categoryId] || '未知分类' }}</template></el-table-column>
        <el-table-column label="版本" width="90"><template #default="scope">v{{ scope.row.version }}</template></el-table-column>
        <el-table-column label="状态" width="100"><template #default="scope"><el-tag :type="statusTag(scope.row.status)">{{ displayValue(scope.row.status) }}</el-tag></template></el-table-column>
        <el-table-column label="描述" min-width="220" show-overflow-tooltip><template #default="scope">{{ scope.row.description || '暂无描述' }}</template></el-table-column>
        <el-table-column label="操作" width="180" fixed="right"><template #default="scope">
          <el-button link @click="router.push(`/inspection/templates/${scope.row.id}`)">查看详情</el-button>
          <el-button v-if="auth.can('inspection:template:manage')" link :loading="formLoading&&editingId===scope.row.id" @click="openEdit(scope.row)">编辑</el-button>
        </template></el-table-column>
      </el-table>
      <el-empty v-if="!loading&&!errorMessage&&!rows.length" description="暂无符合条件的巡检模板"><el-button v-if="auth.can('inspection:template:manage')" type="primary" @click="openCreate">创建第一个模板</el-button></el-empty>
      <el-pagination v-if="!errorMessage&&total>pageSize" v-model:current-page="page" layout="prev, pager, next, total" :page-size="pageSize" :total="total" @current-change="load" />
    </el-card>

    <el-dialog v-model="formVisible" :title="formTitle" width="680px" :close-on-click-modal="!saving" :before-close="beforeCloseTemplate">
      <el-form label-width="105px" class="dialog-form">
        <el-form-item label="模板编码" required><el-input v-model="form.templateCode" :disabled="saving" /></el-form-item>
        <el-form-item label="模板名称" required><el-input v-model="form.templateName" :disabled="saving" /></el-form-item>
        <el-form-item label="设备分类" required><el-tree-select v-model="form.categoryId" :data="categorySelect" filterable check-strictly :disabled="saving" placeholder="请选择设备分类" /></el-form-item>
        <el-form-item label="版本" required><el-input-number v-model="form.version" :min="1" :step="1" :disabled="saving" /></el-form-item>
        <el-form-item label="模板状态" required><el-select v-model="form.status" :disabled="saving"><el-option v-for="status in STATUSES" :key="status" :label="displayValue(status)" :value="status" /></el-select></el-form-item>
        <el-form-item label="模板描述"><el-input v-model="form.description" type="textarea" :rows="4" maxlength="500" show-word-limit :disabled="saving" /></el-form-item>
      </el-form>
      <template #footer><el-button :disabled="saving" @click="beforeCloseTemplate(() => { formVisible = false; })">取消</el-button><el-button type="primary" :loading="saving" @click="saveTemplate">保存模板</el-button></template>
    </el-dialog>
  </section>
</template>

<style scoped>
.inspection-page{display:flex;flex-direction:column;gap:16px}.dialog-form :deep(.el-select),.dialog-form :deep(.el-tree-select){width:100%}.inspection-page :deep(.el-pagination){justify-content:flex-end;margin-top:18px}
</style>
