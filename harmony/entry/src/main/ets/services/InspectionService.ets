import { PageResult } from '../models/CommonModels';
import { AbnormalSubmit, InspectionAbnormal, InspectionTask, ItemSubmit, TaskDetail, TaskItem } from '../models/InspectionModels';
import { ApiClient } from '../network/ApiClient';

export class InspectionService {
  static tasks(): Promise<PageResult<InspectionTask>> { return ApiClient.get<PageResult<InspectionTask>>('/api/inspection/tasks?pageNum=1&pageSize=100'); }
  static detail(id: string): Promise<TaskDetail> { return ApiClient.get<TaskDetail>('/api/inspection/tasks/' + id); }
  static start(id: string): Promise<InspectionTask> { return ApiClient.post<InspectionTask>('/api/inspection/tasks/' + id + '/start'); }
  static saveItem(taskId: string, itemId: string, body: ItemSubmit): Promise<TaskItem> { return ApiClient.put<TaskItem>('/api/inspection/tasks/' + taskId + '/items/' + itemId, body); }
  static report(body: AbnormalSubmit): Promise<InspectionAbnormal> { return ApiClient.post<InspectionAbnormal>('/api/inspection/abnormals', body); }
  static complete(id: string): Promise<InspectionTask> { return ApiClient.post<InspectionTask>('/api/inspection/tasks/' + id + '/complete'); }
}
