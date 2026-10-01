import axios, { AxiosError } from 'axios';
import { ElMessage } from 'element-plus';
import { useAuthStore } from '../stores/auth';

declare module 'axios' {
  export interface AxiosRequestConfig {
    silentStatuses?: number[];
  }
}

interface ApiEnvelope<T = unknown> {
  code?: number;
  message?: string;
  msg?: string;
  data?: T;
}

let handlingUnauthorized = false;

export const request = axios.create({
  baseURL: import.meta.env.VITE_GATEWAY_URL || 'http://127.0.0.1:8080',
  timeout: 20000
});

request.interceptors.request.use((config) => {
  const auth = useAuthStore();
  if (auth.token) config.headers.satoken = auth.token;
  return config;
});

request.interceptors.response.use(
  (response) => {
    const body = response.data as ApiEnvelope;
    if (body?.code === 0) return body.data as never;
    const message = body?.message || body?.msg || '请求失败';
    ElMessage.error(message);
    return Promise.reject(new Error(message));
  },
  (error: AxiosError<ApiEnvelope>) => {
    const status = error.response?.status;
    const silentStatuses = error.config?.silentStatuses || [];
    if (status && silentStatuses.includes(status)) {
      return Promise.reject(error);
    }
    const backendMessage = error.response?.data?.message || error.response?.data?.msg;
    if (status === 401) {
      if (!handlingUnauthorized) {
        handlingUnauthorized = true;
        useAuthStore().logoutLocal();
        window.location.hash = '#/login';
        window.setTimeout(() => { handlingUnauthorized = false; }, 800);
      }
    } else if (status === 403) {
      ElMessage.error(backendMessage ? `当前账号无权执行此操作：${backendMessage}` : '当前账号无权执行此操作');
    } else if (status === 409) {
      ElMessage.warning(backendMessage || '业务状态已变化，请刷新后重试');
    } else if (status === 429) {
      ElMessage.warning('操作过于频繁，请稍后重试');
    } else if (status === 400 || status === 404 || status === 503) {
      ElMessage.error(backendMessage || '请求处理失败');
    } else if (!error.response) {
      ElMessage.error('网络连接失败，请检查服务状态后重试');
    } else {
      ElMessage.error(backendMessage || '服务请求失败');
    }
    return Promise.reject(error);
  }
);
