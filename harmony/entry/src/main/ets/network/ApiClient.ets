import { http } from '@kit.NetworkKit';
import { ApiEnvelope } from '../models/CommonModels';
import { ApiError, ApiErrorKind } from './ApiError';
import { NetworkConfig } from './NetworkConfig';
import { SessionStore } from '../stores/SessionStore';

export class ApiClient {
  static async get<T>(path: string): Promise<T> { return ApiClient.request<T>(path, http.RequestMethod.GET); }
  static async post<T>(path: string, body?: Object): Promise<T> { return ApiClient.request<T>(path, http.RequestMethod.POST, body); }
  static async put<T>(path: string, body?: Object): Promise<T> { return ApiClient.request<T>(path, http.RequestMethod.PUT, body); }

  private static async request<T>(path: string, method: http.RequestMethod, body?: Object): Promise<T> {
    const client = http.createHttp();
    const token = SessionStore.token;
    const headers: Record<string, string> = { 'Content-Type': 'application/json', 'Accept': 'application/json' };
    if (token.length > 0) headers['satoken'] = token;
    try {
      const response = await client.request(NetworkConfig.gatewayBaseUrl + path, {
        method: method,
        header: headers,
        extraData: body === undefined ? '' : JSON.stringify(body),
        connectTimeout: NetworkConfig.timeoutMs,
        readTimeout: NetworkConfig.timeoutMs
      });
      const status = response.responseCode;
      if (status === 401) {
        await SessionStore.clearIdentity();
        throw new ApiError('登录已失效，请重新登录', ApiErrorKind.Unauthorized, status);
      }
      if (status === 403) throw new ApiError('无权执行该操作', ApiErrorKind.Forbidden, status);
      if (status === 404) throw new ApiError('业务对象不存在', ApiErrorKind.NotFound, status);
      const raw = typeof response.result === 'string' ? response.result : JSON.stringify(response.result);
      const envelope = JSON.parse(raw) as ApiEnvelope<T>;
      const backendMessage = envelope.message ?? envelope.msg ?? '请求失败';
      if (status === 409) throw new ApiError(backendMessage, ApiErrorKind.Conflict, status);
      if (status >= 500) throw new ApiError('服务暂时不可用，请稍后重试', ApiErrorKind.Service, status);
      if (status < 200 || status >= 300 || envelope.code !== 0) throw new ApiError(backendMessage, ApiErrorKind.Business, status);
      return envelope.data;
    } catch (error) {
      if (error instanceof ApiError) throw error;
      throw new ApiError('网络连接失败，请检查网络后重试', ApiErrorKind.Network);
    } finally {
      client.destroy();
    }
  }
}
