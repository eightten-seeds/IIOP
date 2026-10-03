export interface InspectionTask { id: string; taskCode: string; deviceId: string; assigneeUserId?: string; taskStatus: string; resultStatus: string; scheduledStartTime?: string; actualStartTime?: string; actualEndTime?: string; completionRate: number; overdueFlag: number }
export interface TaskItem { id: string; itemCode: string; itemName: string; itemType: string; unit?: string; standardValue?: string; lowerLimit?: number; upperLimit?: number; requiredFlag: number; inspectionMethod?: string; actualValue?: string; resultStatus: string; remark?: string; checkedAt?: string }
export interface InspectionAbnormal { id: string; abnormalCode: string; taskId: string; taskItemId?: string; deviceId: string; severity: string; title: string; description?: string; reportedAt: string; status: string; aiDiagnosisId?: string }
export interface TaskDetail { task: InspectionTask; items: TaskItem[]; abnormals: InspectionAbnormal[] }
export interface ItemSubmit { actualValue: string; resultStatus: string; remark: string; evidenceUrls?: string }
export interface AbnormalSubmit { taskId: string; taskItemId?: string; severity: string; title: string; description: string }
