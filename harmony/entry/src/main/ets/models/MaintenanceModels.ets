export interface WorkOrder { id: string; workOrderCode: string; defectId?: string; deviceId: string; title: string; description?: string; priority: string; status: string; assigneeUserId?: string; aiDiagnosisId?: string; actualStartTime?: string; updatedAt: string }
export interface WorkOrderLog { id: string; action: string; fromStatus: string; toStatus: string; operatorUserId: string; comment?: string; createdAt: string }
export interface MaintenanceRecord { id: string; faultCause?: string; solution?: string; partsUsed?: string; downtimeMinutes?: number; maintenanceCost?: number; result: string; repairedAt: string }
export interface Acceptance { id: string; acceptanceResult: string; acceptanceContent?: string; acceptedAt: string }
export interface WorkOrderDetail { workOrder: WorkOrder; logs: WorkOrderLog[]; records: MaintenanceRecord[]; acceptances: Acceptance[] }
export interface Defect { id: string; defectCode: string; deviceId: string; title: string; description?: string; severity: string; status: string; aiDiagnosisId?: string }
export interface RepairSubmit { faultCause: string; solution: string; partsUsed: string; downtimeMinutes?: number; maintenanceCost?: number; result: string; comment: string }
