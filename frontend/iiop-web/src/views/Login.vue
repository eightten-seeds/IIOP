<script setup lang="ts">
import { onMounted, reactive, ref } from 'vue';
import { useRouter } from 'vue-router';
import { User, Lock, Key, Refresh } from '@element-plus/icons-vue';
import { ElMessage } from 'element-plus';
import { useAuthStore } from '../stores/auth';
import { request } from '../api/request';

interface CaptchaData {
  captchaId: string;
  image: string;
}

const router = useRouter();
const auth = useAuthStore();

const loginForm = reactive({
  username: '',
  password: '',
  captchaCode: ''
});

const rememberUsername = ref(false);
const loading = ref(false);
const captchaLoading = ref(false);
const captchaId = ref('');
const captchaImage = ref('');
const loginError = ref('');

const REMEMBER_KEY = 'iiop_remembered_username';

async function fetchCaptcha() {
  captchaLoading.value = true;
  loginForm.captchaCode = '';
  try {
    const data = await request.get<never, CaptchaData>('/api/auth/captcha');
    captchaId.value = data.captchaId;
    captchaImage.value = data.image;
  } catch {
    ElMessage.error('获取验证码失败，请检查网络或服务状态');
  } finally {
    captchaLoading.value = false;
  }
}

async function handleLogin() {
  loginError.value = '';
  if (!loginForm.username.trim()) {
    return void ElMessage.warning('请输入用户名');
  }
  if (!loginForm.password) {
    return void ElMessage.warning('请输入密码');
  }
  if (!loginForm.captchaCode.trim()) {
    return void ElMessage.warning('请输入验证码');
  }

  loading.value = true;
  try {
    await auth.login(
      loginForm.username.trim(),
      loginForm.password,
      captchaId.value,
      loginForm.captchaCode.trim()
    );

    if (rememberUsername.value) {
      localStorage.setItem(REMEMBER_KEY, loginForm.username.trim());
    } else {
      localStorage.removeItem(REMEMBER_KEY);
    }

    ElMessage.success('登录成功');
    await router.replace(auth.defaultHome());
  } catch (error: any) {
    const message = error.response?.data?.message || error.response?.data?.msg || error.message || '登录失败';
    loginError.value = message;
    // Refresh captcha immediately on failure
    await fetchCaptcha();
  } finally {
    loading.value = false;
  }
}

onMounted(() => {
  const saved = localStorage.getItem(REMEMBER_KEY);
  if (saved) {
    loginForm.username = saved;
    rememberUsername.value = true;
  }
  void fetchCaptcha();
});
</script>

<template>
  <main class="login-wrapper">
    <div class="login-card">
      <div class="brand-header">
        <div class="brand-badge">IIOP</div>
        <h1 class="brand-title">工业设备智能巡检运维平台</h1>
        <p class="brand-subtitle">Industrial Intelligent Operation Platform</p>
      </div>

      <el-alert
        v-if="loginError"
        :title="loginError"
        type="error"
        show-icon
        :closable="false"
        class="login-alert"
      />

      <el-form
        :model="loginForm"
        class="login-form"
        size="large"
        @submit.prevent="handleLogin"
      >
        <el-form-item>
          <el-input
            v-model="loginForm.username"
            placeholder="用户名"
            :prefix-icon="User"
            clearable
            autocomplete="username"
          />
        </el-form-item>

        <el-form-item>
          <el-input
            v-model="loginForm.password"
            type="password"
            placeholder="密码"
            :prefix-icon="Lock"
            show-password
            autocomplete="current-password"
          />
        </el-form-item>

        <el-form-item class="captcha-form-item">
          <div class="captcha-row">
            <el-input
              v-model="loginForm.captchaCode"
              placeholder="验证码"
              :prefix-icon="Key"
              maxlength="4"
              class="captcha-input"
              @keyup.enter="handleLogin"
            />
            <div
              class="captcha-img-box"
              title="看不清？点击刷新验证码"
              @click="fetchCaptcha"
            >
              <img
                v-if="captchaImage"
                :src="captchaImage"
                alt="验证码"
                class="captcha-img"
              />
              <el-icon v-else-if="captchaLoading" class="is-loading"><Refresh /></el-icon>
              <span v-else class="captcha-tip">获取中</span>
            </div>
          </div>
        </el-form-item>

        <div class="form-options">
          <el-checkbox v-model="rememberUsername">记住用户名</el-checkbox>
        </div>

        <el-button
          type="primary"
          class="submit-button"
          :loading="loading"
          native-type="submit"
        >
          {{ loading ? '登录中...' : '登 录 平 台' }}
        </el-button>
      </el-form>

      <div class="brand-footer">
        <span class="auth-notice">内部工业运维系统，账号由系统管理员创建与分配</span>
      </div>
    </div>
  </main>
</template>

<style scoped>
.login-wrapper {
  min-height: 100vh;
  width: 100vw;
  display: flex;
  align-items: center;
  justify-content: center;
  background: radial-gradient(circle at 50% 20%, #17325c 0%, #0d1a30 70%, #070d18 100%);
  padding: 20px;
  box-sizing: border-box;
}

.login-card {
  width: 440px;
  max-width: 100%;
  background: rgba(255, 255, 255, 0.98);
  border-radius: 12px;
  padding: 40px 36px;
  box-shadow: 0 16px 48px rgba(0, 0, 0, 0.35);
  box-sizing: border-box;
}

.brand-header {
  text-align: center;
  margin-bottom: 28px;
}

.brand-badge {
  display: inline-block;
  padding: 4px 14px;
  background: #10233f;
  color: #58a6ff;
  font-weight: 700;
  font-size: 15px;
  letter-spacing: 2px;
  border-radius: 4px;
  margin-bottom: 12px;
}

.brand-title {
  margin: 0;
  font-size: 20px;
  font-weight: 600;
  color: #1a2d48;
}

.brand-subtitle {
  margin: 6px 0 0;
  font-size: 12px;
  color: #6a7c92;
  letter-spacing: 0.5px;
}

.login-alert {
  margin-bottom: 18px;
}

.login-form {
  margin-bottom: 20px;
}

.captcha-row {
  display: flex;
  width: 100%;
  gap: 12px;
  align-items: center;
}

.captcha-input {
  flex: 1;
}

.captcha-img-box {
  width: 120px;
  height: 40px;
  background: #f1f4f8;
  border: 1px solid #dcdfe6;
  border-radius: 4px;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  overflow: hidden;
  user-select: none;
  flex-shrink: 0;
  transition: border-color 0.2s;
}

.captcha-img-box:hover {
  border-color: #409eff;
}

.captcha-img {
  width: 100%;
  height: 100%;
  display: block;
}

.captcha-tip {
  font-size: 12px;
  color: #909399;
}

.form-options {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 20px;
}

.submit-button {
  width: 100%;
  height: 44px;
  font-size: 15px;
  font-weight: 600;
  letter-spacing: 1px;
}

.brand-footer {
  text-align: center;
  border-top: 1px solid #ebeef5;
  padding-top: 16px;
}

.auth-notice {
  font-size: 12px;
  color: #8c9ba5;
}
</style>
