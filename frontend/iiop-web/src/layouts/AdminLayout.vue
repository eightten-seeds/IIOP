<script setup lang="ts">
import { computed, onMounted } from 'vue';
import { useAuthStore } from '../stores/auth';
import { useRoute, useRouter } from 'vue-router';
import { displayValue } from '../utils/display';

const auth = useAuthStore();
const router = useRouter();
const route = useRoute();
const menus: Array<[path: string, label: string, permission: string, roles: string[]]> = [
  ['/dashboard', '工作台', 'dashboard:view', ['SUPER_ADMIN', 'ADMIN']],
  ['/devices', '设备管理', 'device:view', ['SUPER_ADMIN', 'ADMIN', 'INSPECTOR', 'MAINTAINER']],
  ['/inspection/templates', '巡检模板', 'inspection:view', ['SUPER_ADMIN', 'ADMIN']],
  ['/inspection/plans', '巡检计划', 'inspection:view', ['SUPER_ADMIN', 'ADMIN']],
  ['/inspection/tasks', '巡检任务', 'inspection:view', ['SUPER_ADMIN', 'ADMIN', 'INSPECTOR']],
  ['/inspection/abnormals', '巡检异常', 'inspection:view', ['SUPER_ADMIN', 'ADMIN', 'INSPECTOR']],
  ['/maintenance/defects', '维修缺陷', 'maintenance:view', ['SUPER_ADMIN', 'ADMIN', 'MAINTAINER']],
  ['/maintenance/work-orders', '维修工单', 'maintenance:view', ['SUPER_ADMIN', 'ADMIN', 'MAINTAINER']],
  ['/ai/diagnoses', 'AI诊断', 'ai:view', ['SUPER_ADMIN', 'ADMIN', 'INSPECTOR', 'MAINTAINER']],
  ['/system/users', '用户管理', 'system:user:view', ['SUPER_ADMIN', 'ADMIN']],
  ['/system/roles', '角色查看', 'system:role:view', ['SUPER_ADMIN', 'ADMIN']],
  ['/system/permissions', '权限查看', 'system:permission:view', ['SUPER_ADMIN', 'ADMIN']],
  ['/notifications', '通知中心', '', ['SUPER_ADMIN', 'ADMIN', 'INSPECTOR', 'MAINTAINER']]
];
const visibleMenus = computed(() => menus.filter((menu) => menu[3].some((role) => auth.roles.includes(role)) && (!menu[2] || auth.can(menu[2]))));

onMounted(() => auth.refreshUnread());

async function logout() {
  await auth.logout();
  await router.push('/login');
}
</script>

<template>
  <el-container class="shell">
    <el-aside width="220px">
      <h2>IIOP</h2>
      <p>工业设备智能巡检</p>
      <el-menu router :default-active="route.path">
        <el-menu-item v-for="menu in visibleMenus" :key="menu[0]" :index="menu[0]">{{ menu[1] }}</el-menu-item>
      </el-menu>
    </el-aside>
    <el-container>
      <el-header>
        <el-breadcrumb>
          <el-breadcrumb-item>首页</el-breadcrumb-item>
          <el-breadcrumb-item>{{ route.meta.title }}</el-breadcrumb-item>
        </el-breadcrumb>
        <div class="header-account">
          <el-button link @click="router.push('/notifications')">通知 <el-badge :value="auth.unread" :hidden="!auth.unread" /></el-button>
          <span>{{ auth.currentUser?.username || '当前用户' }}</span>
          <span class="header-roles" aria-label="当前岗位">
            <el-tag v-for="role in auth.roles" :key="role" size="small" effect="plain">{{ displayValue(role) }}</el-tag>
          </span>
          <el-button link @click="logout">退出</el-button>
        </div>
      </el-header>
      <el-main><RouterView /></el-main>
    </el-container>
  </el-container>
</template>
