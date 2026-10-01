<script setup lang="ts">
import { computed, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useAuthStore } from '../stores/auth';

const auth = useAuthStore();
const route = useRoute();
const router = useRouter();
const retrying = ref(false);
const retryFailed = ref(false);

const isNetworkError = computed(() => route.query.reason === 'network');
const detail = computed(() => isNetworkError.value
  ? '网络连接失败，登录凭据已保留。请检查网络或服务状态后重试。'
  : '认证服务暂时不可用，登录凭据已保留。请稍后重试。');

function destination() {
  const redirect = typeof route.query.redirect === 'string' && route.query.redirect.startsWith('/')
    ? route.query.redirect
    : auth.defaultHome();
  return redirect === '/login' || redirect === '/identity-unavailable' ? auth.defaultHome() : redirect;
}

async function retry() {
  if (retrying.value) return;
  retrying.value = true;
  retryFailed.value = false;
  try {
    await auth.ensureIdentity();
    await router.replace(destination());
  } catch (err: any) {
    if (err?.response?.status === 401 || !auth.token) {
      await router.replace('/login');
      return;
    }
    retryFailed.value = true;
  } finally {
    retrying.value = false;
  }
}
</script>

<template>
  <main class="identity-unavailable">
    <el-result icon="warning" title="当前无法验证登录状态" :sub-title="detail">
      <template #extra>
        <el-button type="primary" :loading="retrying" @click="retry">重试验证</el-button>
      </template>
    </el-result>
    <el-alert
      v-if="retryFailed"
      title="仍无法验证登录状态，请检查网络或服务状态后再试。"
      type="error"
      show-icon
      :closable="false"
    />
  </main>
</template>

<style scoped>
.identity-unavailable {
  min-height: 100vh;
  display: grid;
  place-content: center;
  gap: 16px;
  padding: 24px;
  background: #f3f6fa;
}

.identity-unavailable :deep(.el-result),
.identity-unavailable :deep(.el-alert) {
  width: min(620px, calc(100vw - 48px));
  background: #fff;
  border-radius: 12px;
}
</style>
