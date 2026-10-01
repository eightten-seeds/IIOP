<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { Check, Search } from '@element-plus/icons-vue';
import { request } from '../api/request';
import { displayValue } from '../utils/display';

interface RoleView {
  id: string;
  roleCode: string;
  roleName: string;
  description: string | null;
  status: string;
}

interface PermissionView {
  id: string;
  parentId: string | null;
  permissionCode: string;
  permissionName: string;
  permissionType: string;
  routePath: string | null;
  apiPath: string | null;
  httpMethod: string | null;
  sortOrder: number;
  status: string;
}

interface MatrixRow {
  permissionCode: string;
  permissionName: string;
  module: string;
  moduleName: string;
  sortOrder: number;
  roles: Record<string, boolean>;
}

const roles = ref<RoleView[]>([]);
const rolePermissionsMap = ref<Record<string, Set<string>>>({});
const allPermissions = ref<PermissionView[]>([]);
const loading = ref(false);
const errorMessage = ref('');
const searchKeyword = ref('');
const selectedModule = ref('ALL');

const MODULE_DEFINITIONS: Record<string, { name: string; tagType: '' | 'success' | 'warning' | 'danger' | 'info' }> = {
  dashboard: { name: '总览驾驶舱', tagType: '' },
  device: { name: '设备档案与指标', tagType: 'success' },
  inspection: { name: '巡检配置与执行', tagType: 'warning' },
  maintenance: { name: '运维、告警与工单', tagType: 'danger' },
  ai: { name: 'AI 智能诊断', tagType: 'info' },
  system: { name: '系统与权限治理', tagType: '' }
};

function getModuleKey(code: string): string {
  const prefix = code.split(':')[0];
  return MODULE_DEFINITIONS[prefix] ? prefix : 'system';
}

const matrixRows = computed<MatrixRow[]>(() => {
  return allPermissions.value.map((p) => {
    const modKey = getModuleKey(p.permissionCode);
    const roleMap: Record<string, boolean> = {};
    roles.value.forEach((r) => {
      const set = rolePermissionsMap.value[r.roleCode] || new Set();
      roleMap[r.roleCode] = set.has(p.permissionCode);
    });
    return {
      permissionCode: p.permissionCode,
      permissionName: p.permissionName,
      module: modKey,
      moduleName: MODULE_DEFINITIONS[modKey]?.name || modKey,
      sortOrder: p.sortOrder || 999,
      roles: roleMap
    };
  });
});

const filteredRows = computed(() => {
  return matrixRows.value.filter((row) => {
    const matchesModule = selectedModule.value === 'ALL' || row.module === selectedModule.value;
    const kw = searchKeyword.value.trim().toLowerCase();
    const matchesKeyword = !kw || row.permissionCode.toLowerCase().includes(kw) || row.permissionName.toLowerCase().includes(kw);
    return matchesModule && matchesKeyword;
  });
});

const moduleCounts = computed(() => {
  const counts: Record<string, number> = { ALL: matrixRows.value.length };
  matrixRows.value.forEach((r) => {
    counts[r.module] = (counts[r.module] || 0) + 1;
  });
  return counts;
});

async function load() {
  loading.value = true;
  errorMessage.value = '';
  try {
    const [roleList, permList] = await Promise.all([
      request.get<never, RoleView[]>('/api/auth/roles'),
      request.get<never, PermissionView[]>('/api/auth/permissions')
    ]);
    roles.value = roleList ?? [];
    allPermissions.value = (permList ?? []).sort((a, b) => a.sortOrder - b.sortOrder);

    // Load permissions for each role in parallel
    const permMap: Record<string, Set<string>> = {};
    await Promise.all(
      roles.value.map(async (r) => {
        try {
          const rolePerms = await request.get<never, PermissionView[]>(`/api/auth/roles/${r.id}/permissions`);
          permMap[r.roleCode] = new Set(rolePerms.map((p) => p.permissionCode));
        } catch {
          permMap[r.roleCode] = new Set();
        }
      })
    );
    rolePermissionsMap.value = permMap;
  } catch {
    errorMessage.value = '角色与权限矩阵加载失败，请检查服务状态后重试。';
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
        <h1>角色与权限矩阵</h1>
        <p>系统固定 4 个预置角色与 33 项系统权限，运行时模型冻结，仅供只读查验。</p>
      </div>
    </div>

    <el-alert
      title="第一版角色与权限基线已严格冻结，不可在 UI 中动态创建、删除角色或修改权限绑定。用户岗位分配请前往【用户管理】。"
      type="info"
      show-icon
      :closable="false"
      class="notice-alert"
    />

    <!-- Role Summary Cards -->
    <el-row :gutter="16" class="role-cards-row">
      <el-col v-for="role in roles" :key="role.id" :xs="24" :sm="12" :md="6">
        <el-card shadow="never" class="role-stat-card">
          <div class="card-header-bar">
            <span class="role-code-badge">{{ role.roleCode }}</span>
            <el-tag size="small" type="success">{{ displayValue(role.status) }}</el-tag>
          </div>
          <div class="role-stat-name">{{ role.roleName || displayValue(role.roleCode) }}</div>
          <div class="role-stat-desc">{{ role.description || '固定预置角色' }}</div>
          <div class="role-stat-perms">
            <span>拥有权限：</span>
            <strong>{{ rolePermissionsMap[role.roleCode]?.size ?? 0 }}</strong>
            <span class="perm-total"> / {{ allPermissions.length }} 项</span>
          </div>
        </el-card>
      </el-col>
    </el-row>

    <!-- Matrix Card -->
    <el-card shadow="never" class="matrix-card">
      <template #header>
        <div class="matrix-header">
          <div class="matrix-tabs">
            <el-radio-group v-model="selectedModule" size="default">
              <el-radio-button value="ALL">全部 ({{ moduleCounts.ALL || 0 }})</el-radio-button>
              <el-radio-button
                v-for="(mod, key) in MODULE_DEFINITIONS"
                :key="key"
                :value="key"
              >
                {{ mod.name }} ({{ moduleCounts[key] || 0 }})
              </el-radio-button>
            </el-radio-group>
          </div>
          <el-input
            v-model="searchKeyword"
            placeholder="按权限编码或名称搜索..."
            :prefix-icon="Search"
            clearable
            class="matrix-search"
          />
        </div>
      </template>

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

      <el-table
        v-else
        v-loading="loading"
        :data="filteredRows"
        row-key="permissionCode"
        border
        stripe
        class="matrix-table"
      >
        <el-table-column label="所属模块" width="160">
          <template #default="{ row }">
            <el-tag
              size="small"
              :type="MODULE_DEFINITIONS[row.module]?.tagType || ''"
              effect="plain"
            >
              {{ row.moduleName }}
            </el-tag>
          </template>
        </el-table-column>

        <el-table-column prop="permissionCode" label="权限编码" min-width="210">
          <template #default="{ row }">
            <code class="perm-code">{{ row.permissionCode }}</code>
          </template>
        </el-table-column>

        <el-table-column prop="permissionName" label="权限名称" min-width="160" />

        <el-table-column
          v-for="role in roles"
          :key="role.id"
          :label="role.roleName || displayValue(role.roleCode)"
          align="center"
          width="135"
        >
          <template #header>
            <div class="col-role-header">
              <span>{{ role.roleName || displayValue(role.roleCode) }}</span>
              <span class="sub-role-code">{{ role.roleCode }}</span>
            </div>
          </template>
          <template #default="{ row }">
            <el-tag
              v-if="row.roles[role.roleCode]"
              type="success"
              size="small"
              effect="light"
              class="authorized-tag"
            >
              <el-icon><Check /></el-icon> 已授权
            </el-tag>
            <span v-else class="unauthorized-dash">—</span>
          </template>
        </el-table-column>
      </el-table>

      <el-empty
        v-if="!loading && !errorMessage && !filteredRows.length"
        description="未找到匹配的权限项"
      />
    </el-card>
  </section>
</template>

<style scoped>
.notice-alert {
  margin-bottom: 16px;
}

.role-cards-row {
  margin-bottom: 20px;
}

.role-stat-card {
  height: 100%;
  display: flex;
  flex-direction: column;
}

.role-stat-card :deep(.el-card__body) {
  padding: 18px 20px;
  display: flex;
  flex-direction: column;
  height: 100%;
  box-sizing: border-box;
}

.card-header-bar {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 10px;
}

.role-code-badge {
  font-family: monospace;
  font-size: 13px;
  font-weight: 700;
  color: #10233f;
  background: #eef3f9;
  padding: 2px 8px;
  border-radius: 4px;
}

.role-stat-name {
  font-size: 16px;
  font-weight: 600;
  color: #1a2d48;
  margin-bottom: 6px;
}

.role-stat-desc {
  font-size: 12px;
  color: #8c9ba5;
  line-height: 1.5;
  flex: 1;
  margin-bottom: 14px;
}

.role-stat-perms {
  border-top: 1px solid #f0f2f5;
  padding-top: 10px;
  font-size: 13px;
  color: #556270;
}

.role-stat-perms strong {
  color: #409eff;
  font-size: 16px;
}

.perm-total {
  color: #909399;
  font-size: 12px;
}

.matrix-card {
  margin-top: 8px;
}

.matrix-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 16px;
  flex-wrap: wrap;
}

.matrix-tabs {
  overflow-x: auto;
}

.matrix-search {
  width: 260px;
}

.perm-code {
  font-family: 'Consolas', 'Courier New', monospace;
  font-size: 12.5px;
  color: #2c3e50;
  background: #f6f8fa;
  padding: 2px 6px;
  border-radius: 4px;
  border: 1px solid #e1e4e8;
}

.col-role-header {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 2px;
}

.sub-role-code {
  font-size: 11px;
  color: #909399;
  font-weight: normal;
}

.authorized-tag {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  font-weight: 500;
}

.unauthorized-dash {
  color: #dcdfe6;
  font-size: 16px;
}

.matrix-table {
  width: 100%;
}
</style>
