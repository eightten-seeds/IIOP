import { http } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { ApiEnvelope } from '../models/CommonModels';
import { ApiError, ApiErrorKind } from './ApiError';
import { NetworkConfig } from './NetworkConfig';
import { SessionStore } from '../stores/SessionStore';

interface AuthLoginLogPayload { username?: string; captchaId?: string }

export class ApiClient {
  static async get<T>(path: string): Promise<T> { return ApiClient.request<T>(path, http.RequestMethod.GET); }
  static async post<T>(path: string, body?: Object): Promise<T> { return ApiClient.request<T>(path, http.RequestMethod.POST, body); }
  static async put<T>(path: string, body?: Object): Promise<T> { return ApiClient.request<T>(path, http.RequestMethod.PUT, body); }
  static async delete<T>(path: string, body?: Object): Promise<T> { return ApiClient.request<T>(path, http.RequestMethod.DELETE, body); }

  private static async request<T>(path: string, method: http.RequestMethod, body?: Object): Promise<T> {
    const client = http.createHttp();
    const startedAt = Date.now();
    const token = SessionStore.token;
    const headers: Record<string, string> = { 'Content-Type': 'application/json', 'Accept': 'application/json' };
    if (token.length > 0) headers['satoken'] = token;
    const options: http.HttpRequestOptions = {
      method: method,
      header: headers,
      connectTimeout: NetworkConfig.timeoutMs,
      readTimeout: NetworkConfig.timeoutMs
    };
    if (body !== undefined) {
      options.extraData = JSON.stringify(body);
    }
    try {
      const response = await client.request(NetworkConfig.gatewayBaseUrl + path, options);
      const status = response.responseCode;
      const elapsed = Date.now() - startedAt;
      if (status === 401) {
        const rawUnauthorized = typeof response.result === 'string' ? response.result : JSON.stringify(response.result);
        let unauthorizedCode: number | undefined = undefined;
        let unauthorizedMessage = 'UNAUTHORIZED';
        try {
          const unauthorizedEnvelope = JSON.parse(rawUnauthorized) as ApiEnvelope<Object>;
          unauthorizedCode = unauthorizedEnvelope.code;
          unauthorizedMessage = ApiClient.sanitizeMessage(unauthorizedEnvelope.message ?? unauthorizedEnvelope.msg ?? unauthorizedMessage);
        } catch (error) {}
        ApiClient.logAuth(path, method, status, unauthorizedCode, elapsed, body, unauthorizedMessage);
        await SessionStore.clearIdentity();
        SessionStore.notifyUnauthorized();
        throw new ApiError('登录已失效，请重新登录', ApiErrorKind.Unauthorized, status);
      }
      if (status === 403) throw new ApiError('无权执行该操作', ApiErrorKind.Forbidden, status);
      if (status === 404) throw new ApiError('业务对象不存在', ApiErrorKind.NotFound, status);
      const raw = typeof response.result === 'string' ? response.result : JSON.stringify(response.result);
      const envelope = JSON.parse(raw) as ApiEnvelope<T>;
      const backendMessage = envelope.message ?? envelope.msg ?? '请求失败';
      ApiClient.logAuth(path, method, status, envelope.code, elapsed, body,
        status >= 200 && status < 300 && envelope.code === 0 ? undefined : ApiClient.sanitizeMessage(backendMessage));
      if (!ApiClient.isAuthPath(path)) {
        console.info(`[IIOP HTTP] ${method} ${path} host=${NetworkConfig.gatewayHost} status=${status} elapsed=${elapsed}ms`);
      }
      if (status === 409) throw new ApiError(backendMessage, ApiErrorKind.Conflict, status);
      if (status >= 500) throw new ApiError('服务暂时不可用，请稍后重试', ApiErrorKind.Service, status);
      if (status < 200 || status >= 300 || envelope.code !== 0) throw new ApiError(backendMessage, ApiErrorKind.Business, status);
      return envelope.data;
    } catch (error) {
      if (error instanceof ApiError) throw error;
      const networkError = error as BusinessError;
      const code = networkError.code === undefined ? 'UNKNOWN' : `${networkError.code}`;
      const elapsed = Date.now() - startedAt;
      if (ApiClient.isAuthPath(path)) {
        console.error(`[AUTH] ${ApiClient.authOperation(path, method)} -> status=NETWORK_ERROR code=NA elapsed=${elapsed}ms networkErrorCode=${code}`);
      } else {
        console.error(`[IIOP HTTP] ${method} ${path} host=${NetworkConfig.gatewayHost} status=NETWORK_ERROR elapsed=${elapsed}ms code=${code}`);
      }
      throw new ApiError('网络连接失败，请检查网络后重试', ApiErrorKind.Network);
    } finally {
      client.destroy();
    }
  }

  private static isAuthPath(path: string): boolean {
    return path === '/api/auth/captcha' || path === '/api/auth/login' || path === '/api/auth/me';
  }

  private static authOperation(path: string, method: http.RequestMethod): string {
    if (path === '/api/auth/captcha') return 'captcha GET';
    if (path === '/api/auth/login') return 'login POST';
    if (path === '/api/auth/me') return 'me GET';
    return `${method} auth`;
  }

  private static sanitizeMessage(message: string): string {
    return message.replace(/[\r\n\t]/g, ' ').substring(0, 80);
  }

  private static logAuth(path: string, method: http.RequestMethod, status: number, businessCode: number | undefined,
    elapsed: number, body?: Object, message?: string): void {
    if (!ApiClient.isAuthPath(path)) return;
    const code = businessCode === undefined ? 'NA' : `${businessCode}`;
    const messagePart = message === undefined ? '' : ` message=${message}`;
    if (path === '/api/auth/login') {
      const payload = body as AuthLoginLogPayload;
      const captchaIdPresent = payload !== undefined && typeof payload.captchaId === 'string' && payload.captchaId.length > 0;
      const usernamePresent = payload !== undefined && typeof payload.username === 'string' && payload.username.length > 0;
      console.info(`[AUTH] login POST -> status=${status} code=${code} elapsed=${elapsed}ms captchaIdPresent=${captchaIdPresent} usernamePresent=${usernamePresent}${messagePart}`);
      return;
    }
    const headerPart = path === '/api/auth/me' ? ` satokenHeaderPresent=${SessionStore.token.length > 0}` : '';
    console.info(`[AUTH] ${ApiClient.authOperation(path, method)} -> status=${status} code=${code} elapsed=${elapsed}ms${headerPart}${messagePart}`);
  }
}
