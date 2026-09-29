package com.iiop.ai.workflow;
public record WorkflowInput(String triggerType,Long triggerId,Long deviceId,String abnormalSummary,String userDescription){}
