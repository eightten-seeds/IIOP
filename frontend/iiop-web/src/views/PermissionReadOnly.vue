<script setup lang="ts">
import { onMounted, ref } from 'vue';
import { request } from '../api/request';
import { displayValue } from '../utils/display';

interface PermissionView {
  id: string;
  permissionCode: string;
  permissionName: string;
  permissionType: string;
  routePath: string | null;
  apiPath: string | null;
  httpMethod: string | null;
  status: string;
}
interface PermissionNode { permission: PermissionView; children: PermissionNode[] }
interface PermissionRow extends PermissionView { children?: PermissionRow[] }

const rows = ref<PermissionRow[]>([]);
const loading = ref(false);
const errorMessage = ref('');

function toRow(node: PermissionNode): PermissionRow {
  return { ...node.permission, children: node.children?.length ? node.children.map(toRow) : undefined };
}

async function load() {
  loading.value = true;
  errorMessage.value = '';
  try {
    const tree = await request.get<never, PermissionNode[]>('/api/auth/permissions/tree');
    rows.value = tree.map(toRow);
  } catch {
    errorMessage.value = '权限基线加载失败，请检查服务状态后重试。';
  } finally {
    loading.value = false;
  }
}

onMounted(load);
</script>

<template>
  <section class="system-page">
    <div class="page-head">
      <div>
        <h1>系统权限基线</h1>
        <p>查看系统已预置的 33 项功能权限、层级划分与对应的路由与接口配置。</p>
      </div>
    </div>
    <el-alert title="系统角色与权限基线已严格冻结，仅供只读查验。如需调整用户岗位分配，请前往【用户管理】。" type="info" show-icon :closable="false" style="margin-bottom: 16px;" />
    <el-card shadow="never">
      <el-alert v-if="errorMessage" :title="errorMessage" type="error" show-icon :closable="false">
        <template #default><el-button link type="primary" @click="load">重新加载</el-button></template>
      </el-alert>
      <el-table v-else v-loading="loading" :data="rows" row-key="id" default-expand-all border>
        <el-table-column prop="permissionName" label="功能权限名称" min-width="220" />
        <el-table-column prop="permissionCode" label="权限编码" min-width="220">
          <template #default="scope">
            <code class="perm-code">{{ scope.row.permissionCode }}</code>
          </template>
        </el-table-column>
        <el-table-column prop="permissionType" label="类型" width="100">
          <template #default="scope">
            <el-tag size="small" :type="scope.row.permissionType === 'MENU' ? 'primary' : 'info'">
              {{ displayValue(scope.row.permissionType) }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="routePath" label="页面路由" min-width="170">
          <template #default="scope">{{ scope.row.routePath || '-' }}</template>
        </el-table-column>
        <el-table-column label="后端接口" min-width="260">
          <template #default="scope">
            <span v-if="scope.row.apiPath">
              <el-tag size="small" effect="plain">{{ scope.row.httpMethod || 'API' }}</el-tag>
              <span class="api-path">{{ scope.row.apiPath }}</span>
            </span>
            <span v-else class="text-muted">-</span>
          </template>
        </el-table-column>
        <el-table-column prop="status" label="状态" width="100" align="center">
          <template #default="scope">
            <el-tag size="small" :type="scope.row.status==='ENABLED'?'success':'info'">{{ displayValue(scope.row.status) }}</el-tag>
          </template>
        </el-table-column>
      </el-table>
      <el-empty v-if="!loading&&!errorMessage&&!rows.length" description="暂无权限数据" />
    </el-card>
  </section>
</template>

<style scoped>
.perm-code {
  font-family: 'Consolas', 'Courier New', monospace;
  font-size: 12px;
  color: #2c3e50;
  background: #f6f8fa;
  padding: 2px 6px;
  border-radius: 4px;
  border: 1px solid #e1e4e8;
}
.api-path {
  margin-left: 6px;
  font-size: 13px;
  color: var(--el-text-color-regular);
}
.text-muted {
  color: var(--el-text-color-placeholder);
}
</style>
