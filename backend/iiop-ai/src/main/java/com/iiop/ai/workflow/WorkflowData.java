package com.iiop.ai.workflow;
import com.iiop.ai.domain.AiDtos.*; import com.iiop.ai.domain.AiModels.Diagnosis; import java.util.*;
public class WorkflowData { public final Diagnosis diagnosis; public final Map<String,Object> context; public ModelResult model; public String risk; public WorkOrderDraft draft; public WorkflowData(Diagnosis d,Map<String,Object> c){diagnosis=d;context=c;} }
