package com.iiop.ai.workflow;
import java.util.Map; import org.bsc.langgraph4j.state.AgentState;
public class AiGraphState extends AgentState {public AiGraphState(Map<String,Object> data){super(data);} public WorkflowData workflow(){return value("workflow",null);} }
