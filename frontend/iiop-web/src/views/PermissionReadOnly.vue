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
    <div class="page-head"><div><h1>固定权限</h1><p>查看第一版固定 permission code 与路由/API 信息。</p></div></div>
    <el-alert title="第一版角色与权限基线已冻结，仅供查看。本页面不提供新增、编辑、删除或权限矩阵保存。" type="info" show-icon :closable="false" />
    <el-card shadow="never">
      <el-alert v-if="errorMessage" :title="errorMessage" type="error" show-icon :closable="false"><template #default><el-button link type="primary" @click="load">重新加载</el-button></template></el-alert>
      <el-table v-else v-loading="loading" :data="rows" row-key="id" default-expand-all>
        <el-table-column prop="permissionCode" label="权限编码" min-width="250" />
        <el-table-column prop="permissionName" label="权限名称" min-width="170" />
        <el-table-column prop="permissionType" label="类型" width="100"><template #default="scope">{{ displayValue(scope.row.permissionType) }}</template></el-table-column>
        <el-table-column prop="routePath" label="页面路由" min-width="170"><template #default="scope">{{ scope.row.routePath || '-' }}</template></el-table-column>
        <el-table-column label="API" min-width="260"><template #default="scope"><span v-if="scope.row.apiPath"><el-tag size="small" effect="plain">{{ scope.row.httpMethod || 'API' }}</el-tag> {{ scope.row.apiPath }}</span><span v-else>-</span></template></el-table-column>
        <el-table-column prop="status" label="状态" width="100"><template #default="scope"><el-tag :type="scope.row.status==='ENABLED'?'success':'info'">{{ displayValue(scope.row.status) }}</el-tag></template></el-table-column>
      </el-table>
      <el-empty v-if="!loading&&!errorMessage&&!rows.length" description="暂无权限数据" />
    </el-card>
  </section>
</template>
