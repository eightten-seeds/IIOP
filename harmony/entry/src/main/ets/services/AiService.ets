import { DiagnosisView, WorkflowTrace } from '../models/AiModels';
import { ApiClient } from '../network/ApiClient';

export class AiService {
  static detail(id: string): Promise<DiagnosisView> { return ApiClient.get<DiagnosisView>('/api/ai/diagnoses/' + id); }
  static workflow(id: string): Promise<WorkflowTrace[]> { return ApiClient.get<WorkflowTrace[]>('/api/ai/diagnoses/' + id + '/workflow'); }
}
