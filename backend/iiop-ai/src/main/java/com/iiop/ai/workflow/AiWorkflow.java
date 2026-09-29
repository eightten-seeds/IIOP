package com.iiop.ai.workflow;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.iiop.ai.domain.AiDtos.*;
import com.iiop.ai.domain.AiModels.Diagnosis;
import com.iiop.ai.service.*;
import java.util.*;
import org.bsc.langgraph4j.*;
import org.bsc.langgraph4j.action.AsyncNodeAction;
import org.bsc.langgraph4j.state.AgentStateFactory;
import org.springframework.stereotype.Component;

@Component public class AiWorkflow {
 private final AiPersistenceService persistence;private final DeepSeekDiagnosisClient deepSeek;private final ObjectMapper json;
 public AiWorkflow(AiPersistenceService p,DeepSeekDiagnosisClient d,ObjectMapper j){persistence=p;deepSeek=d;json=j;}
 public WorkflowData execute(Diagnosis diagnosis,Map<String,Object> context){WorkflowData data=new WorkflowData(diagnosis,context);try{StateGraph<AiGraphState> graph=new StateGraph<>((AgentStateFactory<AiGraphState>)AiGraphState::new);graph.addNode("LOAD_CONTEXT",AsyncNodeAction.node_async(s->node(s,"LOAD_CONTEXT",()->Map.of("loaded",true))));graph.addNode("ANALYZE_WITH_DEEPSEEK",AsyncNodeAction.node_async(s->node(s,"ANALYZE_WITH_DEEPSEEK",()->{data.model=deepSeek.diagnose(asJson(context));return Map.of("risk",data.model.riskLevel());})));graph.addNode("RISK_CHECK",AsyncNodeAction.node_async(s->node(s,"RISK_CHECK",()->{validate(data.model);data.risk=maxRisk(String.valueOf(context.getOrDefault("triggerRisk","LOW")),data.model.riskLevel());return Map.of("risk",data.risk);})));graph.addNode("GENERATE_ADVICE",AsyncNodeAction.node_async(s->node(s,"GENERATE_ADVICE",()->Map.of("advice",data.model.maintenanceAdvice()))));graph.addNode("PREPARE_WORK_ORDER_DRAFT",AsyncNodeAction.node_async(s->node(s,"PREPARE_WORK_ORDER_DRAFT",()->{data.draft=new WorkOrderDraft(data.model.abnormalSummary(),data.model.maintenanceAdvice(),data.risk,"CORRECTIVE",data.model.maintenanceAdvice(),data.model.safetyNotice());return Map.of("draft",data.draft.title());})));graph.addEdge(GraphDefinition.START,"LOAD_CONTEXT");graph.addEdge("LOAD_CONTEXT","ANALYZE_WITH_DEEPSEEK");graph.addEdge("ANALYZE_WITH_DEEPSEEK","RISK_CHECK");graph.addEdge("RISK_CHECK","GENERATE_ADVICE");graph.addEdge("GENERATE_ADVICE","PREPARE_WORK_ORDER_DRAFT");graph.addEdge("PREPARE_WORK_ORDER_DRAFT",GraphDefinition.END);CompiledGraph<AiGraphState> compiled=graph.compile();compiled.invoke(Map.of("workflow",data));return data;}catch(Exception e){throw e instanceof RuntimeException r?r:new IllegalStateException("AI 工作流执行失败",e);}}
 private Map<String,Object> node(AiGraphState state,String name,Action action) throws Exception {WorkflowData data=state.workflow();persistence.start(data.diagnosis.getId(),name);try{Map<String,Object> output=action.run();persistence.success(data.diagnosis.getId(),name,asJson(output));return Map.of("workflow",data);}catch(Exception e){persistence.fail(data.diagnosis.getId(),name,e.getMessage());throw e;}}
 private String asJson(Object value){try{return json.writeValueAsString(value);}catch(Exception e){throw new IllegalStateException(e);}}
 private void validate(ModelResult r){if(r==null||!Set.of("LOW","MEDIUM","HIGH","CRITICAL").contains(r.riskLevel())||r.abnormalSummary()==null||r.abnormalSummary().isBlank()||r.possibleCauses()==null||r.investigationSteps()==null||r.maintenanceAdvice()==null||r.maintenanceAdvice().isBlank()||r.safetyNotice()==null||r.safetyNotice().isBlank())throw new IllegalStateException("DeepSeek 结构化结果不符合约束");}
 @FunctionalInterface private interface Action {Map<String,Object> run() throws Exception;}
 public static String maxRisk(String a,String b){List<String> order=List.of("LOW","MEDIUM","HIGH","CRITICAL");String x=order.contains(a)?a:"LOW";String y=order.contains(b)?b:"LOW";return order.indexOf(x)>=order.indexOf(y)?x:y;}
 public String modelName(){return deepSeek.model();}
}
