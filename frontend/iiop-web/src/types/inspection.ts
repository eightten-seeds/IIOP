export type TemplateStatus = 'DRAFT' | 'ENABLED' | 'DISABLED';
export type ItemType = 'NUMBER' | 'BOOLEAN' | 'TEXT' | 'PHOTO';
export type PlanStatus = 'ENABLED' | 'DISABLED';
export type ScheduleType = 'DAILY' | 'WEEKLY' | 'MONTHLY' | 'CRON';
export type TaskStatus = 'PENDING' | 'IN_PROGRESS' | 'COMPLETED' | 'CANCELLED';
export type ResultStatus = 'UNKNOWN' | 'PENDING' | 'NORMAL' | 'ABNORMAL';
export type Severity = 'LOW' | 'MEDIUM' | 'HIGH' | 'CRITICAL';

export interface InspectionTemplate {
  id: string;
  templateCode: string;
  templateName: string;
  categoryId: string;
  version: number;
  description: string | null;
  flowDefinition: string | null;
  status: TemplateStatus;
}

export interface TemplateItem {
  id: string;
  templateId: string;
  itemCode: string;
  itemName: string;
  itemType: ItemType;
  unit: string | null;
  standardValue: string | null;
  lowerLimit: number | null;
  upperLimit: number | null;
  requiredFlag: number;
  inspectionMethod: string | null;
  abnormalHint: string | null;
  sortOrder: number;
}

export interface InspectionPlan {
  id: string;
  planCode: string;
  planName: string;
  deviceId: string;
  templateId: string;
  scheduleType: ScheduleType;
  cronExpression: string | null;
  startDate: string | null;
  endDate: string | null;
  assigneeUserId: string;
  status: PlanStatus;
  lastGenerateTime: string | null;
  nextGenerateTime: string | null;
}

export interface InspectionTask {
  id: string;
  taskCode: string;
  planId: string;
  deviceId: string;
  templateId: string;
  assigneeUserId: string;
  taskStatus: TaskStatus;
  overdueFlag: number;
  resultStatus: ResultStatus;
  scheduledStartTime: string | null;
  scheduledEndTime: string | null;
  actualStartTime: string | null;
  actualEndTime: string | null;
  completionRate: number;
  remark: string | null;
}

export interface TaskItem {
  id: string;
  taskId: string;
  templateItemId: string;
  itemCode: string;
  itemName: string;
  itemType: ItemType;
  unit: string | null;
  standardValue: string | null;
  lowerLimit: number | null;
  upperLimit: number | null;
  requiredFlag: number;
  inspectionMethod: string | null;
  actualValue: string | null;
  resultStatus: ResultStatus;
  remark: string | null;
  evidenceUrls: string | null;
  sortOrder: number;
  checkedAt: string | null;
}

export interface InspectionAbnormal {
  id: string;
  abnormalCode: string;
  taskId: string;
  taskItemId: string | null;
  deviceId: string;
  abnormalType: string | null;
  severity: Severity;
  title: string;
  description: string | null;
  reportedBy: string;
  reportedAt: string;
  status: string;
  aiDiagnosisId: string | null;
  resolvedAt: string | null;
}

export interface TaskDetailData {
  task: InspectionTask;
  items: TaskItem[];
  abnormals: InspectionAbnormal[];
}

export interface DefectSummary {
  id: string; defectCode: string; title: string; status: string; severity: Severity;
}

export interface DiagnosisSummary {
  id: string; diagnosisCode: string; diagnosisStatus: string; riskLevel: string; confirmationStatus: string;
}

export interface TemplateForm {
  templateCode: string;
  templateName: string;
  categoryId: string;
  version: number;
  description: string;
  status: TemplateStatus;
}

export interface PlanForm {
  planCode: string;
  planName: string;
  deviceId: string;
  templateId: string;
  scheduleType: ScheduleType;
  cronExpression: string;
  startDate: string | null;
  endDate: string | null;
  assigneeUserId: string;
  status: PlanStatus;
}

export const emptyTemplateForm = (): TemplateForm => ({
  templateCode: '', templateName: '', categoryId: '', version: 1, description: '', status: 'DRAFT'
});

export const emptyPlanForm = (): PlanForm => ({
  planCode: '', planName: '', deviceId: '', templateId: '', scheduleType: 'DAILY', cronExpression: '',
  startDate: null, endDate: null, assigneeUserId: '', status: 'DISABLED'
});
