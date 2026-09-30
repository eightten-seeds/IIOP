<script setup lang="ts">
import { useRouter } from 'vue-router';
import { useAuthStore } from '../stores/auth';
const router=useRouter(),auth=useAuthStore();
</script>
<template><main class="forbidden"><el-result icon="warning" title="无权访问当前功能" sub-title="请联系管理员确认您的功能权限。"><template #extra><el-button type="primary" @click="router.replace(auth.defaultHome())">返回工作台</el-button></template></el-result></main></template>
