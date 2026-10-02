import { PageResult } from '../models/CommonModels';
import { Defect, RepairSubmit, WorkOrder, WorkOrderDetail } from '../models/MaintenanceModels';
import { ApiClient } from '../network/ApiClient';

export class MaintenanceService {
  static orders(): Promise<PageResult<WorkOrder>> { return ApiClient.get<PageResult<WorkOrder>>('/api/maintenance/work-orders?pageNum=1&pageSize=100'); }
  static detail(id: string): Promise<WorkOrderDetail> { return ApiClient.get<WorkOrderDetail>('/api/maintenance/work-orders/' + id); }
  static defect(id: string): Promise<Defect> { return ApiClient.get<Defect>('/api/maintenance/defects/' + id); }
  static start(id: string, comment: string): Promise<WorkOrder> { return ApiClient.post<WorkOrder>('/api/maintenance/work-orders/' + id + '/start?comment=' + encodeURIComponent(comment)); }
  static submitRepair(id: string, body: RepairSubmit): Promise<WorkOrder> { return ApiClient.post<WorkOrder>('/api/maintenance/work-orders/' + id + '/repair-result', body); }
}
