package com.iiop.inspection.domain;
import com.iiop.inspection.domain.InspectionModels.*;
import java.util.List;
public final class InspectionDtos {private InspectionDtos(){}
    public record FlowRequest(String flowDefinition){}
    public record TaskItemSubmitRequest(String actualValue,String resultStatus,String remark,String evidenceUrls){}
    public record TaskDetail(Task task,List<TaskItem> items,List<Abnormal> abnormals){}
    public record RecentHistory(Long deviceId,List<Task> tasks,List<Abnormal> abnormals){}
    public record AbnormalAiContext(Long id,Long taskId,Long deviceId,Long assigneeUserId,String severity,String title,String description){}
    public record AbnormalAiAssociationRequest(Long aiDiagnosisId){}
}
