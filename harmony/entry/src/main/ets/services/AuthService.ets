import { ApiClient } from '../network/ApiClient';
import { Captcha, Identity } from '../models/CommonModels';
import { SessionStore } from '../stores/SessionStore';

export interface LoginPayload { username: string; password: string; captchaId: string; captchaCode: string }

export class AuthService {
  static captcha(): Promise<Captcha> { return ApiClient.get<Captcha>('/api/auth/captcha'); }
  static async login(payload: LoginPayload): Promise<Identity> {
    const identity = await ApiClient.post<Identity>('/api/auth/login', payload);
    await SessionStore.applyIdentity(identity);
    return identity;
  }
  static async me(): Promise<Identity> {
    const identity = await ApiClient.get<Identity>('/api/auth/me');
    await SessionStore.applyIdentity(identity);
    return identity;
  }
  static async logout(): Promise<void> {
    try { await ApiClient.post<Object>('/api/auth/logout'); } finally { await SessionStore.clearIdentity(); }
  }
}
