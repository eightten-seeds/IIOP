<script setup lang="ts">
import { onMounted, ref } from 'vue';
import { request } from '../api/request';
import { displayValue } from '../utils/display';

interface RoleView { id: string; roleCode: string; roleName: string; description: string | null; status: string }

const roles = ref<RoleView[]>([]);
const loading = ref(false);
const errorMessage = ref('');

async function load() {
  loading.value = true;
  errorMessage.value = '';
  try {
    roles.value = await request.get<never, RoleView[]>('/api/auth/roles');
  } catch {
    errorMessage.value = '角色基线加载失败，请检查服务状态后重试。';
  } finally {
    loading.value = false;
  }
}

onMounted(load);
</script>

<template>
  <section class="system-page">
    <div class="page-head"><div><h1>固定角色</h1><p>查看第一版四个固定业务岗位。</p></div></div>
    <el-alert title="第一版角色与权限基线已冻结，仅供查看。用户岗位分配请前往用户管理。" type="info" show-icon :closable="false" />
    <el-card shadow="never">
      <el-alert v-if="errorMessage" :title="errorMessage" type="error" show-icon :closable="false"><template #default><el-button link type="primary" @click="load">重新加载</el-button></template></el-alert>
      <el-table v-else v-loading="loading" :data="roles" row-key="id">
        <el-table-column prop="roleCode" label="角色编码" min-width="180" />
        <el-table-column prop="roleName" label="角色名称" min-width="150"><template #default="scope">{{ scope.row.roleName || displayValue(scope.row.roleCode) }}</template></el-table-column>
        <el-table-column prop="description" label="职责说明" min-width="300"><template #default="scope">{{ scope.row.description || '-' }}</template></el-table-column>
        <el-table-column prop="status" label="状态" width="110"><template #default="scope"><el-tag :type="scope.row.status==='ENABLED'?'success':'info'">{{ displayValue(scope.row.status) }}</el-tag></template></el-table-column>
      </el-table>
      <el-empty v-if="!loading&&!errorMessage&&!roles.length" description="暂无角色数据" />
    </el-card>
  </section>
</template>
