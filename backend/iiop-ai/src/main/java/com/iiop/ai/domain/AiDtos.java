package com.iiop.ai.domain;
import jakarta.validation.constraints.NotBlank;
import java.io.Serializable;
import java.util.List;
public final class AiDtos {private AiDtos(){}
 public record CreateRequest(@NotBlank String triggerType,Long triggerId,Long deviceId,String abnormalSummary,String userDescription){}
 public record ConfirmRequest(String comment){}
 public record ModelResult(String riskLevel,String abnormalSummary,List<String> possibleCauses,List<String> investigationSteps,String maintenanceAdvice,String safetyNotice,Boolean humanConfirmationRequired) implements Serializable {}
 public record WorkOrderDraft(String title,String description,String priority,String maintenanceAdvice,String safetyNotice) implements Serializable {}
 public record DiagnosisView(AiModels.Diagnosis diagnosis,List<String> possibleCauses,List<String> investigationSteps,WorkOrderDraft workOrderDraft,boolean humanConfirmationRequired){}
}
