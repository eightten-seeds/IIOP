import { defineStore } from 'pinia';
import { request } from '../api/request';

const HOME_ROLE_PRIORITY = ['SUPER_ADMIN', 'ADMIN', 'MAINTAINER', 'INSPECTOR'] as const;

interface CurrentUser {
  id: string;
  username: string;
  realName?: string | null;
  status: string;
}

interface IdentityResponse {
  tokenValue?: string;
  user: CurrentUser | null;
  roles: string[];
  permissions: string[];
}

interface UnreadResponse {
  count: number;
}

export const useAuthStore = defineStore('auth', {
  state: () => ({
    token: '',
    currentUser: null as CurrentUser | null,
    roles: [] as string[],
    permissions: [] as string[],
    identityLoaded: false,
    unread: 0
  }),
  // Only a credential can survive a reload. Identity is always revalidated by
  // /api/auth/me before protected routes render, preventing stale role views.
  persist: { pick: ['token'] },
  actions: {
    applyIdentity(data: IdentityResponse) {
      this.currentUser = data?.user ?? null;
      this.roles = Array.isArray(data?.roles) ? data.roles : [];
      this.permissions = Array.isArray(data?.permissions) ? data.permissions : [];
      this.identityLoaded = true;
    },
    defaultHome() {
      const role = HOME_ROLE_PRIORITY.find((item) => this.roles.includes(item));
      if (!role) return '/no-role';
      if (role === 'INSPECTOR') return '/inspection/tasks';
      if (role === 'MAINTAINER') return '/maintenance/work-orders';
      return '/dashboard';
    },
    async login(username: string, password: string, captchaId: string, captchaCode: string) {
      const data = await request.post<never, IdentityResponse>('/api/auth/login', { username, password, captchaId, captchaCode });
      this.token = data.tokenValue ?? '';
      this.applyIdentity(data);
      await this.refreshUnread();
    },
    async me() {
      const data = await request.get<never, IdentityResponse>('/api/auth/me');
      this.applyIdentity(data);
    },
    async ensureIdentity() {
      if (this.token) await this.me();
    },
    async refreshUnread() {
      if (!this.token || !this.roles.length) return;
      try {
        const data = await request.get<never, UnreadResponse>('/api/auth/notifications/unread-count');
        this.unread = Number(data.count || 0);
      } catch {
        // 通知失败不阻断身份与主页面加载。
      }
    },
    logoutLocal() {
      this.$reset();
    },
    async logout() {
      try {
        await request.post('/api/auth/logout');
      } finally {
        this.logoutLocal();
      }
    },
    can(permission: string) {
      return this.permissions.includes(permission);
    }
  }
});
