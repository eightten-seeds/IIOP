package com.iiop.ai.workflow;
import com.iiop.ai.domain.AiDtos.*; import com.iiop.ai.domain.AiModels.Diagnosis; import java.io.Serializable; import java.util.*;
public class WorkflowData implements Serializable { public final Diagnosis diagnosis; public final WorkflowInput input; public Map<String,Object> context=new LinkedHashMap<>(); public ModelResult model; public String risk; public boolean humanConfirmationRequired; public WorkOrderDraft draft; public WorkflowData(Diagnosis d,WorkflowInput i){diagnosis=d;input=i;} }
