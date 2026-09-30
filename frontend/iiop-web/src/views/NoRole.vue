<script setup lang="ts">
import { ref } from 'vue';
import { useRouter } from 'vue-router';
import { useAuthStore } from '../stores/auth';

const auth = useAuthStore();
const router = useRouter();
const loggingOut = ref(false);

async function logout() {
  loggingOut.value = true;
  try {
    await auth.logout();
    await router.replace('/login');
  } finally {
    loggingOut.value = false;
  }
}
</script>

<template>
  <main class="no-role-page">
    <el-card class="no-role-card" shadow="always">
      <el-result icon="warning" title="尚未分配岗位" sub-title="账号尚未分配岗位，请联系管理员">
        <template #extra>
          <p class="no-role-user">当前用户：{{ auth.currentUser?.username || '-' }}</p>
          <el-button type="primary" :loading="loggingOut" @click="logout">退出登录</el-button>
        </template>
      </el-result>
    </el-card>
  </main>
</template>
