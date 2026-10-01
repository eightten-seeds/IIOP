<script setup lang="ts">
import { useRouter } from 'vue-router';
import { useAuthStore } from '../stores/auth';

const router = useRouter();
const auth = useAuthStore();
</script>

<template>
  <main class="not-found-page">
    <el-result icon="error" title="页面不存在" sub-title="你访问的页面不存在或地址已失效。">
      <template #extra>
        <el-button type="primary" @click="router.replace(auth.defaultHome())">返回我的首页</el-button>
      </template>
    </el-result>
  </main>
</template>

<style scoped>
.not-found-page {
  min-height: 60vh;
  display: grid;
  place-items: center;
  padding: 32px 16px;
}
</style>
