export type TemplateStatus = 'DRAFT' | 'ENABLED' | 'DISABLED';
export type ItemType = 'NUMBER' | 'BOOLEAN' | 'TEXT' | 'PHOTO';
export type PlanStatus = 'ENABLED' | 'DISABLED';
export type ScheduleType = 'DAILY' | 'WEEKLY' | 'MONTHLY' | 'CRON';

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
