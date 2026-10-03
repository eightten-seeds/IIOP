import { ApiClient } from '../network/ApiClient';
import { Captcha, Identity, LoginIdentity } from '../models/CommonModels';
import { SessionStore } from '../stores/SessionStore';

export interface LoginPayload { username: string; password: string; captchaId: string; captchaCode: string }

export class AuthService {
  static captcha(): Promise<Captcha> { return ApiClient.get<Captcha>('/api/auth/captcha'); }
  static async login(payload: LoginPayload): Promise<Identity> {
    const identity = await ApiClient.post<LoginIdentity>('/api/auth/login', payload);
    if (identity.tokenName !== 'satoken' || identity.tokenValue.length === 0 || identity.user === undefined ||
      !Array.isArray(identity.roles) || !Array.isArray(identity.permissions)) {
      throw new Error('登录响应格式无效');
    }
    await SessionStore.applyIdentity(identity);
    console.info(`[AUTH] tokenPresent=${SessionStore.token.length > 0}`);
    return AuthService.me();
  }
  static async me(): Promise<Identity> {
    const identity = await ApiClient.get<Identity>('/api/auth/me');
    await SessionStore.applyIdentity(identity);
    return identity;
  }
  static async logout(): Promise<void> {
    try { await ApiClient.post<Object>('/api/auth/logout'); } catch (error) {} finally { await SessionStore.clearIdentity(); }
  }
}
