package com.iiop.ai.workflow;
import java.io.Serializable;
public record WorkflowInput(String triggerType,Long triggerId,Long deviceId,String abnormalSummary,String userDescription) implements Serializable {}
