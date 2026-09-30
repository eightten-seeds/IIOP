package com.iiop.maintenance.domain;
import com.iiop.maintenance.domain.MaintenanceModels.*;import java.math.BigDecimal;import java.util.List;
public final class MaintenanceDtos {private MaintenanceDtos(){}
 public record StatusRequest(String status){} public record AssignRequest(Long assigneeUserId,String comment){}
 public record RepairRequest(String faultCause,String solution,String partsUsed,Integer downtimeMinutes,BigDecimal maintenanceCost,String result,String comment){}
 public record AcceptanceRequest(String acceptanceResult,String acceptanceContent,String comment){}
 public record BindAiDiagnosisRequest(Long aiDiagnosisId){}
 public record WorkOrderDetail(WorkOrder workOrder,List<WorkOrderLog> logs,List<MaintenanceRecord> records,List<Acceptance> acceptances){}
 public record MaintenanceHistory(Long deviceId,List<WorkOrder> workOrders,List<MaintenanceRecord> records,List<Acceptance> acceptances){}
}
