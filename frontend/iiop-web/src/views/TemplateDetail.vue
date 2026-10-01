<script setup lang="ts">
import { computed, nextTick, onMounted, reactive, ref } from 'vue';
import { ElMessage, ElMessageBox } from 'element-plus';
import { useRoute, useRouter } from 'vue-router';
import {
  VueFlow,
  Handle,
  Position,
  useVueFlow,
  type Node,
  type Edge,
  type Connection
} from '@vue-flow/core';
import '@vue-flow/core/dist/style.css';
import '@vue-flow/core/dist/theme-default.css';
import { request } from '../api/request';
import { useAuthStore } from '../stores/auth';
import { categoryNameMap, type CategoryTree } from '../types/device';
import type { InspectionTemplate, ItemType, TemplateItem } from '../types/inspection';
import { displayValue } from '../utils/display';

interface ItemForm {
  itemCode: string;
  itemName: string;
  itemType: ItemType;
  unit: string;
  standardValue: string;
  lowerLimit: number | null;
  upperLimit: number | null;
  requiredFlag: number;
  inspectionMethod: string;
  abnormalHint: string;
  sortOrder: number;
}

const emptyItem = (): ItemForm => ({
  itemCode: '',
  itemName: '',
  itemType: 'NUMBER',
  unit: '',
  standardValue: '',
  lowerLimit: null,
  upperLimit: null,
  requiredFlag: 1,
  inspectionMethod: '',
  abnormalHint: '',
  sortOrder: 0
});

const route = useRoute();
const router = useRouter();
const auth = useAuthStore();

const detail = ref<InspectionTemplate>();
const items = ref<TemplateItem[]>([]);
const categoryNames = reactive<Record<string, string>>({});
const loading = ref(false);
const errorMessage = ref('');

// Flow state
const flowNodes = ref<any[]>([]);
const flowEdges = ref<any[]>([]);
const flowSaving = ref(false);
const flowWarning = ref('');
const selectedEdgeId = ref<string | null>(null);

const { fitView } = useVueFlow();

// Template Items Dialog state
const itemVisible = ref(false);
const editingItemId = ref('');
const itemSaving = ref(false);
const deletingItemId = ref('');
const itemForm = reactive<ItemForm>(emptyItem());

const requiredPhoto = computed(() =>
  items.value.some((item) => item.itemType === 'PHOTO' && item.requiredFlag === 1)
);
const editingPhoto = computed(
  () => Boolean(editingItemId.value) && itemForm.itemType === 'PHOTO'
);

function typeTag(type: ItemType) {
  return type === 'PHOTO'
    ? 'danger'
    : type === 'NUMBER'
    ? 'primary'
    : type === 'BOOLEAN'
    ? 'success'
    : 'info';
}

function parseFlowDefinition(raw: string | null | undefined) {
  flowWarning.value = '';
  flowNodes.value = [];
  flowEdges.value = [];
  if (!raw || !raw.trim()) {
    return;
  }
  try {
    const parsed = JSON.parse(raw);
    if (parsed && typeof parsed === 'object' && Array.isArray(parsed.nodes) && Array.isArray(parsed.edges)) {
      flowNodes.value = parsed.nodes;
      flowEdges.value = parsed.edges;
    } else {
      flowWarning.value =
        '历史流程定义格式暂无法可视化解析。您可以保留原数据，或点击“从检查项重新生成”。';
    }
  } catch {
    flowWarning.value =
      '历史流程定义格式暂无法可视化解析。您可以保留原数据，或点击“从检查项重新生成”。';
  }
}

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
    Object.assign(categoryNames, categoryNameMap(categories ?? []));
    parseFlowDefinition(template.flowDefinition);
  } catch {
    errorMessage.value = '模板详情加载失败，请检查服务状态后重试。';
  } finally {
    loading.value = false;
  }
}

function generateFlowFromItems() {
  if (!items.value.length) {
    return void ElMessage.warning('该模板尚未配置检查项，无法生成流程');
  }
  flowWarning.value = '';
  const sorted = [...items.value].sort((a, b) => (a.sortOrder || 0) - (b.sortOrder || 0));
  const newNodes: Node[] = [];
  const newEdges: Edge[] = [];

  sorted.forEach((item, index) => {
    const nodeId = `node_${item.id}`;
    newNodes.push({
      id: nodeId,
      type: 'item',
      position: { x: 260, y: 40 + index * 120 },
      data: {
        itemId: item.id,
        itemCode: item.itemCode,
        itemName: item.itemName,
        itemType: item.itemType,
        requiredFlag: item.requiredFlag
      }
    });

    if (index > 0) {
      const prevId = `node_${sorted[index - 1].id}`;
      newEdges.push({
        id: `edge_${sorted[index - 1].id}_${item.id}`,
        source: prevId,
        target: nodeId,
        animated: true,
        style: { stroke: '#1769aa', strokeWidth: 2 }
      });
    }
  });

  flowNodes.value = newNodes;
  flowEdges.value = newEdges;
  ElMessage.success(`已根据 ${sorted.length} 个检查项生成顺序流程图`);
  nextTick(() => {
    void fitView({ padding: 0.2 });
  });
}

function onConnect(connection: Connection) {
  if (!connection.source || !connection.target) return;
  if (connection.source === connection.target) return;
  const edgeId = `edge_${connection.source}_${connection.target}`;
  if (flowEdges.value.some((e) => e.source === connection.source && e.target === connection.target)) {
    return;
  }
  flowEdges.value.push({
    id: edgeId,
    source: connection.source,
    target: connection.target,
    animated: true,
    style: { stroke: '#1769aa', strokeWidth: 2 }
  });
}

function onEdgeClick(event: any) {
  selectedEdgeId.value = event?.edge?.id || event?.id || null;
}

function deleteSelectedEdge() {
  if (!selectedEdgeId.value) return;
  flowEdges.value = flowEdges.value.filter((e) => e.id !== selectedEdgeId.value);
  selectedEdgeId.value = null;
  ElMessage.success('已删除选中的连线');
}

async function saveFlow() {
  flowSaving.value = true;
  try {
    const payload = {
      version: 1,
      nodes: flowNodes.value.map((n) => ({
        id: n.id,
        type: n.type || 'item',
        position: { x: Math.round(n.position.x), y: Math.round(n.position.y) },
        data: n.data
      })),
      edges: flowEdges.value.map((e) => ({
        id: e.id,
        source: e.source,
        target: e.target,
        animated: Boolean(e.animated),
        style: e.style
      }))
    };
    await request.put(`/api/inspection/templates/${route.params.id}/flow-definition`, {
      flowDefinition: JSON.stringify(payload)
    });
    ElMessage.success('流程定义已成功保存');
    await load();
  } finally {
    flowSaving.value = false;
  }
}

function openCreateItem() {
  editingItemId.value = '';
  Object.assign(itemForm, emptyItem(), { sortOrder: items.value.length + 1 });
  itemVisible.value = true;
}

function openEditItem(item: TemplateItem) {
  editingItemId.value = item.id;
  Object.assign(itemForm, {
    itemCode: item.itemCode,
    itemName: item.itemName,
    itemType: item.itemType,
    unit: item.unit ?? '',
    standardValue: item.standardValue ?? '',
    lowerLimit: item.lowerLimit,
    upperLimit: item.upperLimit,
    requiredFlag: item.requiredFlag,
    inspectionMethod: item.inspectionMethod ?? '',
    abnormalHint: item.abnormalHint ?? '',
    sortOrder: item.sortOrder
  });
  itemVisible.value = true;
}

function changeItemType(type: ItemType) {
  if (type !== 'NUMBER') {
    itemForm.unit = '';
    itemForm.lowerLimit = null;
    itemForm.upperLimit = null;
  }
  if (type === 'TEXT') itemForm.standardValue = '';
}

async function saveItem() {
  if (!itemForm.itemCode.trim() || !itemForm.itemName.trim())
    return void ElMessage.warning('请填写检查项编码和名称');
  itemSaving.value = true;
  try {
    const payload = { ...itemForm };
    const templateId = String(route.params.id);
    if (editingItemId.value)
      await request.put(
        `/api/inspection/templates/${templateId}/items/${editingItemId.value}`,
        payload
      );
    else await request.post(`/api/inspection/templates/${templateId}/items`, payload);
    ElMessage.success(editingItemId.value ? '检查项更新成功' : '检查项创建成功');
    itemVisible.value = false;
    await load();
  } finally {
    itemSaving.value = false;
  }
}

async function deleteItem(item: TemplateItem) {
  try {
    await ElMessageBox.confirm(
      `确认删除检查项“${item.itemName}”吗？`,
      '删除检查项',
      { type: 'error', confirmButtonText: '删除', cancelButtonText: '取消' }
    );
  } catch {
    return;
  }
  deletingItemId.value = item.id;
  try {
    await request.delete(`/api/inspection/template-items/${item.id}`);
    ElMessage.success('检查项已删除');
    await load();
  } finally {
    deletingItemId.value = '';
  }
}

onMounted(load);
</script>

<template>
  <section class="template-detail">
    <div class="page-head">
      <div>
        <el-button link @click="router.push('/inspection/templates')">← 返回模板列表</el-button>
        <h1>巡检模板详情</h1>
        <p>维护模板基本信息、检查项与已保存的流程定义。</p>
      </div>
    </div>

    <el-alert
      v-if="errorMessage"
      :title="errorMessage"
      type="error"
      show-icon
      :closable="false"
    >
      <template #default>
        <el-button link type="primary" @click="load">重新加载</el-button>
      </template>
    </el-alert>

    <template v-else>
      <el-card v-loading="loading" shadow="never">
        <template #header><strong>模板基本信息</strong></template>
        <el-descriptions v-if="detail" :column="3" border>
          <el-descriptions-item label="模板编码">{{ detail.templateCode }}</el-descriptions-item>
          <el-descriptions-item label="模板名称">{{ detail.templateName }}</el-descriptions-item>
          <el-descriptions-item label="模板状态">
            <el-tag :type="detail.status === 'ENABLED' ? 'success' : detail.status === 'DRAFT' ? 'warning' : 'info'">
              {{ displayValue(detail.status) }}
            </el-tag>
          </el-descriptions-item>
          <el-descriptions-item label="设备分类">
            {{ categoryNames[detail.categoryId] || '未知分类' }}
          </el-descriptions-item>
          <el-descriptions-item label="版本">v{{ detail.version }}</el-descriptions-item>
          <el-descriptions-item label="模板描述" :span="3">
            {{ detail.description || '暂无描述' }}
          </el-descriptions-item>
        </el-descriptions>
      </el-card>

      <el-alert
        v-if="requiredPhoto"
        title="该模板包含必填 PHOTO 检查项，第一版巡检执行暂不支持，请先调整模板后再用于巡检计划。"
        type="error"
        show-icon
        :closable="false"
      />

      <!-- Inspection Items Table -->
      <el-card shadow="never">
        <template #header>
          <div class="card-head">
            <div>
              <strong>检查项管理</strong>
              <p>第一版支持数值、正常/异常与文本检查；历史图片项仅保留查看和调整。</p>
            </div>
            <el-button
              v-if="auth.can('inspection:template:manage')"
              type="primary"
              @click="openCreateItem"
            >
              新增检查项
            </el-button>
          </div>
        </template>

        <el-table :data="items" row-key="id">
          <el-table-column prop="itemCode" label="检查项编码" min-width="130" />
          <el-table-column prop="itemName" label="检查项名称" min-width="150" />
          <el-table-column label="类型" width="110">
            <template #default="scope">
              <el-tag :type="typeTag(scope.row.itemType)">{{ displayValue(scope.row.itemType) }}</el-tag>
            </template>
          </el-table-column>
          <el-table-column prop="unit" label="单位" width="80">
            <template #default="scope">{{ scope.row.unit || '-' }}</template>
          </el-table-column>
          <el-table-column prop="standardValue" label="标准值" min-width="110">
            <template #default="scope">{{ scope.row.standardValue ? displayValue(scope.row.standardValue) : '-' }}</template>
          </el-table-column>
          <el-table-column label="下限 / 上限" min-width="130">
            <template #default="scope">{{ scope.row.lowerLimit ?? '-' }} / {{ scope.row.upperLimit ?? '-' }}</template>
          </el-table-column>
          <el-table-column label="是否必填" width="90">
            <template #default="scope">{{ scope.row.requiredFlag === 1 ? '必填' : '选填' }}</template>
          </el-table-column>
          <el-table-column prop="inspectionMethod" label="检查方法" min-width="170">
            <template #default="scope">{{ scope.row.inspectionMethod || '-' }}</template>
          </el-table-column>
          <el-table-column prop="abnormalHint" label="异常提示" min-width="170">
            <template #default="scope">
              {{ scope.row.itemType === 'PHOTO' ? '第一版暂不支持图片巡检执行' : scope.row.abnormalHint || '-' }}
            </template>
          </el-table-column>
          <el-table-column prop="sortOrder" label="排序" width="70" />
          <el-table-column
            v-if="auth.can('inspection:template:manage')"
            label="操作"
            width="130"
            fixed="right"
          >
            <template #default="scope">
              <el-button link @click="openEditItem(scope.row)">编辑</el-button>
              <el-button
                link
                type="danger"
                :loading="deletingItemId === scope.row.id"
                @click="deleteItem(scope.row)"
              >
                删除
              </el-button>
            </template>
          </el-table-column>
        </el-table>

        <el-empty v-if="!items.length && !loading" description="尚未配置检查项">
          <el-button
            v-if="auth.can('inspection:template:manage')"
            type="primary"
            @click="openCreateItem"
          >
            新增检查项
          </el-button>
        </el-empty>
      </el-card>

      <!-- Vue Flow Visual Editor -->
      <el-card shadow="never" class="flow-card">
        <template #header>
          <div class="card-head">
            <div>
              <strong>巡检流程图定义（Vue Flow）</strong>
              <p>可视化维护检查项先后顺序与流转拓扑，支持拖拽节点、连线与保存。</p>
            </div>
            <div v-if="auth.can('inspection:template:manage')" class="flow-actions">
              <el-button @click="generateFlowFromItems">从检查项生成流程</el-button>
              <el-button @click="fitView({ padding: 0.2 })">适应视图</el-button>
              <el-button
                v-if="selectedEdgeId"
                type="danger"
                plain
                @click="deleteSelectedEdge"
              >
                删除选中连线
              </el-button>
              <el-button
                type="primary"
                :loading="flowSaving"
                @click="saveFlow"
              >
                保存流程定义
              </el-button>
            </div>
          </div>
        </template>

        <el-alert
          v-if="flowWarning"
          :title="flowWarning"
          type="warning"
          show-icon
          :closable="false"
          class="flow-warning-alert"
        />

        <div class="flow-container">
          <VueFlow
            v-if="flowNodes.length"
            v-model:nodes="flowNodes"
            v-model:edges="flowEdges"
            :fit-view-on-init="true"
            class="vue-flow-box"
            @connect="onConnect"
            @edge-click="onEdgeClick"
          >
            <template #node-item="{ data }">
              <div class="custom-flow-node" :class="{ 'is-required': data.requiredFlag === 1 }">
                <Handle type="target" :position="Position.Top" class="flow-handle" />
                <div class="flow-node-head">
                  <span class="node-title" :title="data.itemName">{{ data.itemName }}</span>
                  <el-tag size="small" :type="typeTag(data.itemType)">{{ displayValue(data.itemType) }}</el-tag>
                </div>
                <div class="flow-node-body">
                  <span class="node-code">{{ data.itemCode }}</span>
                  <span class="node-req" :class="{ 'req-yes': data.requiredFlag === 1 }">
                    {{ data.requiredFlag === 1 ? '必填' : '选填' }}
                  </span>
                </div>
                <Handle type="source" :position="Position.Bottom" class="flow-handle" />
              </div>
            </template>
          </VueFlow>

          <el-empty
            v-else
            description="该模板暂未生成流程图定义"
            :image-size="80"
          >
            <el-button
              v-if="auth.can('inspection:template:manage') && items.length"
              type="primary"
              @click="generateFlowFromItems"
            >
              从检查项生成流程
            </el-button>
          </el-empty>
        </div>
      </el-card>
    </template>

    <!-- Inspection Item Edit Dialog -->
    <el-dialog
      v-model="itemVisible"
      :title="editingItemId ? '编辑检查项' : '新增检查项'"
      width="760px"
      :close-on-click-modal="!itemSaving"
    >
      <el-alert
        v-if="editingPhoto"
        title="这是历史 PHOTO 检查项。第一版不支持图片巡检执行，也不提供上传控件；可调整为其他支持类型。"
        type="warning"
        show-icon
        :closable="false"
      />
      <el-form label-width="105px" class="item-form">
        <el-row :gutter="18">
          <el-col :span="12">
            <el-form-item label="检查项编码" required>
              <el-input v-model="itemForm.itemCode" :disabled="itemSaving" />
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="检查项名称" required>
              <el-input v-model="itemForm.itemName" :disabled="itemSaving" />
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="检查项类型" required>
              <el-select v-model="itemForm.itemType" :disabled="itemSaving" @change="changeItemType">
                <el-option label="数值检查" value="NUMBER" />
                <el-option label="正常/异常检查" value="BOOLEAN" />
                <el-option label="文本检查" value="TEXT" />
                <el-option v-if="editingPhoto" label="图片检查（历史数据）" value="PHOTO" disabled />
              </el-select>
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="是否必填">
              <el-switch
                v-model="itemForm.requiredFlag"
                :active-value="1"
                :inactive-value="0"
                active-text="必填"
                inactive-text="选填"
                :disabled="itemSaving"
              />
            </el-form-item>
          </el-col>
          <template v-if="itemForm.itemType === 'NUMBER'">
            <el-col :span="12">
              <el-form-item label="单位">
                <el-input v-model="itemForm.unit" :disabled="itemSaving" placeholder="例如 ℃、MPa" />
              </el-form-item>
            </el-col>
            <el-col :span="12">
              <el-form-item label="标准值">
                <el-input v-model="itemForm.standardValue" :disabled="itemSaving" />
              </el-form-item>
            </el-col>
            <el-col :span="12">
              <el-form-item label="允许下限">
                <el-input-number
                  v-model="itemForm.lowerLimit"
                  controls-position="right"
                  :disabled="itemSaving"
                />
              </el-form-item>
            </el-col>
            <el-col :span="12">
              <el-form-item label="允许上限">
                <el-input-number
                  v-model="itemForm.upperLimit"
                  controls-position="right"
                  :disabled="itemSaving"
                />
              </el-form-item>
            </el-col>
          </template>
          <el-col v-else-if="itemForm.itemType === 'BOOLEAN'" :span="24">
            <el-alert
              title="巡检人员将明确选择“正常”或“异常”；请设置符合标准的结果。"
              type="info"
              show-icon
              :closable="false"
            />
            <el-form-item label="标准结果">
              <el-radio-group v-model="itemForm.standardValue" :disabled="itemSaving">
                <el-radio value="NORMAL">正常</el-radio>
                <el-radio value="ABNORMAL">异常</el-radio>
              </el-radio-group>
            </el-form-item>
          </el-col>
          <el-col v-else-if="itemForm.itemType === 'TEXT'" :span="24">
            <el-alert
              title="文本检查用于记录观察结果，请在检查方法中写明需要填写的内容。"
              type="info"
              show-icon
              :closable="false"
            />
          </el-col>
          <el-col :span="24">
            <el-form-item label="检查方法">
              <el-input
                v-model="itemForm.inspectionMethod"
                type="textarea"
                :rows="2"
                :disabled="itemSaving"
                placeholder="说明现场如何完成本项检查"
              />
            </el-form-item>
          </el-col>
          <el-col :span="24">
            <el-form-item label="异常提示">
              <el-input
                v-model="itemForm.abnormalHint"
                type="textarea"
                :rows="2"
                :disabled="itemSaving"
                placeholder="说明何种情况应判定为异常"
              />
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="排序">
              <el-input-number
                v-model="itemForm.sortOrder"
                :min="0"
                :step="1"
                :disabled="itemSaving"
              />
            </el-form-item>
          </el-col>
        </el-row>
      </el-form>
      <template #footer>
        <el-button :disabled="itemSaving" @click="itemVisible = false">取消</el-button>
        <el-button type="primary" :loading="itemSaving" @click="saveItem">保存检查项</el-button>
      </template>
    </el-dialog>
  </section>
</template>

<style scoped>
.template-detail {
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.card-head {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
}

.card-head p {
  margin: 6px 0 0;
  color: #667085;
  font-size: 13px;
}

.flow-actions {
  display: flex;
  gap: 10px;
}

.flow-warning-alert {
  margin-bottom: 12px;
}

.flow-container {
  height: 480px;
  width: 100%;
  border-radius: 6px;
  background: #f8fafc;
  border: 1px solid #e2e8f0;
  position: relative;
  overflow: hidden;
  display: flex;
  align-items: center;
  justify-content: center;
}

.vue-flow-box {
  width: 100%;
  height: 100%;
}

.custom-flow-node {
  background: #ffffff;
  border: 1.5px solid #cbd5e1;
  border-radius: 8px;
  padding: 10px 14px;
  min-width: 200px;
  box-shadow: 0 2px 6px rgba(0, 0, 0, 0.06);
  transition: all 0.2s ease;
}

.custom-flow-node:hover {
  border-color: #1769aa;
  box-shadow: 0 4px 12px rgba(23, 105, 170, 0.15);
}

.custom-flow-node.is-required {
  border-left: 4px solid #1769aa;
}

.flow-node-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
  margin-bottom: 6px;
}

.node-title {
  font-size: 13px;
  font-weight: 600;
  color: #1e293b;
  max-width: 130px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.flow-node-body {
  display: flex;
  align-items: center;
  justify-content: space-between;
  font-size: 11px;
}

.node-code {
  color: #64748b;
}

.node-req {
  color: #94a3b8;
}

.node-req.req-yes {
  color: #1769aa;
  font-weight: 600;
}

.flow-handle {
  width: 9px;
  height: 9px;
  background: #1769aa;
  border: 2px solid #ffffff;
}

.item-form {
  margin-top: 18px;
}

.item-form :deep(.el-select),
.item-form :deep(.el-input-number) {
  width: 100%;
}

.item-form :deep(.el-alert) {
  margin-bottom: 16px;
}
</style>
