import axios, { AxiosError } from 'axios';
import { ElMessage } from 'element-plus';
import { useAuthStore } from '../stores/auth';

declare module 'axios' {
  export interface AxiosRequestConfig {
    silentStatuses?: number[];
    silentGlobalError?: boolean;
  }
}

interface ApiEnvelope<T = unknown> {
  code?: number;
  message?: string;
  msg?: string;
  data?: T;
}

let handlingUnauthorized = false;
const recentMessages = new Map<string, number>();

function notify(type: 'error' | 'warning' | 'info' | 'success', message: string, duration = 3000) {
  const now = Date.now();
  const key = `${type}:${message}`;
  const lastTime = recentMessages.get(key) || 0;
  if (now - lastTime < 1500) return;
  recentMessages.set(key, now);
  if (recentMessages.size > 50) {
    for (const [k, time] of recentMessages.entries()) {
      if (now - time > 10000) recentMessages.delete(k);
    }
  }
  ElMessage({ type, message, grouping: true, duration });
}

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
    notify('error', message);
    return Promise.reject(new Error(message));
  },
  (error: AxiosError<ApiEnvelope>) => {
    const status = error.response?.status;
    if (status === 401) {
      if (!handlingUnauthorized) {
        handlingUnauthorized = true;
        notify('error', '未登录或登录已失效，请重新登录');
        useAuthStore().logoutLocal();
        window.location.hash = '#/login';
        window.setTimeout(() => { handlingUnauthorized = false; }, 800);
      }
      return Promise.reject(error);
    }
    const silentStatuses = error.config?.silentStatuses || [];
    if (error.config?.silentGlobalError) return Promise.reject(error);
    if (status && silentStatuses.includes(status)) {
      return Promise.reject(error);
    }
    const backendMessage = error.response?.data?.message || error.response?.data?.msg;
    if (status === 403) {
      const isTech = backendMessage && (backendMessage.includes('403') || backendMessage.includes('Request') || backendMessage.includes('Axios') || backendMessage.includes('Forbidden'));
      notify('error', backendMessage && !isTech ? `无权限执行该操作：${backendMessage}` : '无权限执行该操作');
    } else if (status === 409) {
      notify('warning', backendMessage || '业务状态已变化，请刷新后重试');
    } else if (status === 429) {
      notify('warning', '操作过于频繁，请稍后重试');
    } else if (status === 404) {
      notify('error', backendMessage || '目标数据不存在或已删除');
    } else if (status === 503 || (status && status >= 500)) {
      notify('error', '服务暂时不可用，请稍后重试');
    } else if (status === 400) {
      notify('error', backendMessage || '请求参数无效');
    } else if (!error.response) {
      notify('error', '网络连接失败，请检查服务状态后重试');
    } else {
      notify('error', backendMessage || '服务请求失败');
    }
    return Promise.reject(error);
  }
);
