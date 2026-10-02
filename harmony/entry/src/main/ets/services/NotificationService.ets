import { NotificationItem, PageResult } from '../models/CommonModels';
import { ApiClient } from '../network/ApiClient';

export class NotificationService {
  static list(): Promise<PageResult<NotificationItem>> { return ApiClient.get<PageResult<NotificationItem>>('/api/auth/notifications?pageNum=1&pageSize=30'); }
  static read(id: string): Promise<Object> { return ApiClient.put<Object>('/api/auth/notifications/' + id + '/read'); }
}
