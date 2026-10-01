<script setup lang="ts">
import { computed, nextTick, onMounted, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import {
  Odometer,
  Cpu,
  DocumentChecked,
  Tools,
  DataAnalysis,
  Management,
  Bell,
  Fold,
  Expand,
  ArrowDown
} from '@element-plus/icons-vue';
import { useAuthStore } from '../stores/auth';
import { displayValue } from '../utils/display';
import {
  buildNavigation,
  getActiveGroupKey,
  type BreadcrumbItem
} from '../utils/navigation';

const auth = useAuthStore();
const router = useRouter();
const route = useRoute();

const isCollapse = ref(false);
const menuRef = ref<{ open: (index: string) => void; close: (index: string) => void }>();
const openedMenus = ref<string[]>(['group-inspection', 'group-maintenance', 'group-system']);

const iconMap: Record<string, any> = {
  Odometer,
  Cpu,
  DocumentChecked,
  Tools,
  DataAnalysis,
  Management,
  Bell
};

const navItems = computed(() => buildNavigation(router.getRoutes(), auth));

const currentActiveMenu = computed(() => {
  return (route.meta.activeMenu as string) || route.path;
});

const breadcrumbs = computed<BreadcrumbItem[]>(() => {
  return (route.meta.breadcrumb as BreadcrumbItem[]) || (route.meta.title ? [{ title: route.meta.title as string }] : []);
});

const userDisplayName = computed(() => {
  const user = auth.currentUser;
  if (!user) return '当前用户';
  if (user.realName) return `${user.realName}（${user.username}）`;
  return user.username;
});

const userInitial = computed(() => {
  const name = auth.currentUser?.realName || auth.currentUser?.username || 'U';
  return name.slice(0, 1).toUpperCase();
});

function ensureActiveGroupOpened() {
  if (isCollapse.value) return;
  const group = getActiveGroupKey(route.path, route.meta.activeMenu as string | undefined);
  if (group && menuRef.value) {
    menuRef.value.open(group);
  }
}

watch(
  () => [route.path, route.meta.activeMenu],
  () => {
    nextTick(() => {
      ensureActiveGroupOpened();
    });
  },
  { immediate: true }
);

onMounted(() => {
  auth.refreshUnread();
  nextTick(() => {
    ensureActiveGroupOpened();
  });
});

import ChangePasswordDialog from '../components/ChangePasswordDialog.vue';

const changePasswordVisible = ref(false);

async function handleUserCommand(command: string) {
  if (command === 'logout') {
    await auth.logout();
    await router.push('/login');
  } else if (command === 'password') {
    changePasswordVisible.value = true;
  }
}
</script>

<template>
  <el-container class="shell">
    <el-aside :width="isCollapse ? '64px' : '220px'" class="app-aside">
      <div class="brand">
        <h2 class="brand-title">IIOP</h2>
        <p v-show="!isCollapse" class="brand-sub">工业设备智能巡检</p>
      </div>
      <el-menu
        ref="menuRef"
        router
        :collapse="isCollapse"
        :collapse-transition="false"
        :default-active="currentActiveMenu"
        :default-openeds="openedMenus"
        class="aside-menu"
      >
        <template v-for="item in navItems" :key="item.isGroup ? item.key : item.path">
          <!-- Standalone Item -->
          <el-menu-item v-if="!item.isGroup" :index="item.path">
            <el-icon v-if="item.icon && iconMap[item.icon]"><component :is="iconMap[item.icon]" /></el-icon>
            <template #title>{{ item.label }}</template>
          </el-menu-item>

          <!-- SubMenu Group -->
          <el-sub-menu v-else :index="item.key">
            <template #title>
              <el-icon v-if="item.icon && iconMap[item.icon]"><component :is="iconMap[item.icon]" /></el-icon>
              <span>{{ item.label }}</span>
            </template>
            <el-menu-item
              v-for="sub in item.children"
              :key="sub.path"
              :index="sub.path"
            >
              {{ sub.label }}
            </el-menu-item>
          </el-sub-menu>
        </template>
      </el-menu>
    </el-aside>
    <el-container>
      <el-header class="app-header">
        <div class="header-left">
          <el-button
            link
            class="collapse-toggle"
            :title="isCollapse ? '展开侧边栏' : '收起侧边栏'"
            @click="isCollapse = !isCollapse"
          >
            <el-icon :size="18"><Expand v-if="isCollapse" /><Fold v-else /></el-icon>
          </el-button>
          <el-breadcrumb separator="/" class="app-breadcrumb">
            <el-breadcrumb-item :to="auth.defaultHome()">首页</el-breadcrumb-item>
            <el-breadcrumb-item
              v-for="(crumb, idx) in breadcrumbs"
              :key="idx"
              :to="crumb.path"
            >
              {{ crumb.title }}
            </el-breadcrumb-item>
          </el-breadcrumb>
        </div>
        <div class="header-account">
          <el-button
            link
            class="header-notify-btn"
            title="通知中心"
            @click="router.push('/notifications')"
          >
            <el-badge :value="auth.unread" :hidden="!auth.unread" :max="99">
              <el-icon :size="18"><Bell /></el-icon>
            </el-badge>
          </el-button>
          <span class="user-name" :title="userDisplayName">{{ userDisplayName }}</span>
          <span class="header-roles" aria-label="当前岗位">
            <el-tag
              v-for="role in auth.roles"
              :key="role"
              size="small"
              effect="plain"
            >
              {{ displayValue(role) }}
            </el-tag>
          </span>
          <el-dropdown trigger="click" @command="handleUserCommand">
            <span class="user-dropdown-link" title="用户操作">
              <el-avatar :size="28" class="user-avatar">{{ userInitial }}</el-avatar>
              <el-icon class="el-icon--right"><ArrowDown /></el-icon>
            </span>
            <template #dropdown>
              <el-dropdown-menu>
                <el-dropdown-item command="password">修改密码</el-dropdown-item>
                <el-dropdown-item divided command="logout">退出登录</el-dropdown-item>
              </el-dropdown-menu>
            </template>
          </el-dropdown>
        </div>
      </el-header>
      <el-main><RouterView /></el-main>
    </el-container>
    <ChangePasswordDialog v-model:visible="changePasswordVisible" />
  </el-container>
</template>

<style scoped>
.app-aside {
  background: #10233f;
  color: #d5e5f7;
  padding: 16px 8px;
  transition: width 0.2s ease;
  overflow-x: hidden;
  display: flex;
  flex-direction: column;
}
.brand {
  padding: 8px 12px 16px;
  text-align: center;
  border-bottom: 1px solid rgba(255, 255, 255, 0.08);
  margin-bottom: 12px;
  white-space: nowrap;
}
.brand-title {
  margin: 0;
  color: #fff;
  letter-spacing: 2px;
  font-size: 20px;
}
.brand-sub {
  margin: 4px 0 0;
  font-size: 11px;
  color: #8eaccb;
}
.aside-menu {
  border: 0;
  background: transparent;
  flex: 1;
}
.app-header {
  background: #fff;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  border-bottom: 1px solid #e7ebf1;
  padding: 0 20px;
  height: 56px;
}
.header-left {
  display: flex;
  align-items: center;
  gap: 12px;
  min-width: 0;
  flex: 1;
}
.collapse-toggle {
  font-size: 18px;
  color: #475467;
  padding: 4px;
}
.collapse-toggle:hover {
  color: #1769aa;
}
.app-breadcrumb {
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.header-account {
  display: flex;
  align-items: center;
  gap: 12px;
  flex-shrink: 0;
}
.header-notify-btn {
  padding: 4px 8px;
  color: #475467;
}
.header-notify-btn:hover {
  color: #1769aa;
}
.user-name {
  font-size: 13px;
  color: #344054;
  font-weight: 500;
  max-width: 160px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.header-roles {
  display: flex;
  align-items: center;
  gap: 4px;
  flex-wrap: wrap;
}
.user-dropdown-link {
  display: flex;
  align-items: center;
  cursor: pointer;
  outline: none;
  gap: 4px;
}
.user-avatar {
  background: #1769aa;
  color: #fff;
  font-weight: 600;
  font-size: 13px;
}
</style>
