package com.iiop.ai.domain;
import jakarta.validation.constraints.NotBlank;
import java.util.List;
public final class AiDtos {private AiDtos(){}
 public record CreateRequest(@NotBlank String triggerType,Long triggerId,Long deviceId,String abnormalSummary,String userDescription){}
 public record ConfirmRequest(String comment){}
 public record ModelResult(String riskLevel,String abnormalSummary,List<String> possibleCauses,List<String> investigationSteps,String maintenanceAdvice,String safetyNotice,Boolean humanConfirmationRequired){}
 public record WorkOrderDraft(String title,String description,String priority,String workOrderType,String maintenanceAdvice,String safetyNotice){}
 public record DiagnosisView(AiModels.Diagnosis diagnosis,List<String> possibleCauses,List<String> investigationSteps,WorkOrderDraft workOrderDraft){}
}
