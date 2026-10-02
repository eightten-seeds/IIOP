package com.iiop.ai.service;

import com.baomidou.mybatisplus.core.toolkit.Wrappers;
import com.iiop.ai.domain.AiModels.*;
import com.iiop.ai.mapper.*;
import java.time.LocalDateTime;
import java.util.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.*;

@Service public class AiPersistenceService {
 public static final List<String> NODES=List.of("LOAD_CONTEXT","ANALYZE_WITH_DEEPSEEK","RISK_CHECK","GENERATE_ADVICE","PREPARE_WORK_ORDER_DRAFT");
 public static final Map<String,String> NODE_NAMES=Map.of("LOAD_CONTEXT","加载诊断上下文","ANALYZE_WITH_DEEPSEEK","DeepSeek 智能分析","RISK_CHECK","风险校验","GENERATE_ADVICE","生成处理建议","PREPARE_WORK_ORDER_DRAFT","准备维修工单草稿");
 private final AiDiagnosisMapper diagnoses; private final AiWorkflowTraceMapper traces; private final AiWorkflowEventPublisher events;
 public AiPersistenceService(AiDiagnosisMapper d,AiWorkflowTraceMapper t,AiWorkflowEventPublisher e){diagnoses=d;traces=t;events=e;}
 @Transactional(propagation=Propagation.REQUIRES_NEW) public void create(Diagnosis d){diagnoses.insert(d);for(String node:NODES){WorkflowTrace t=new WorkflowTrace();t.setDiagnosisId(d.getId());t.setNodeCode(node);t.setNodeName(NODE_NAMES.get(node));t.setNodeStatus("PENDING");t.setCreatedAt(LocalDateTime.now());traces.insert(t);}}
 @Transactional(propagation=Propagation.REQUIRES_NEW) public void markRunning(Long id){diagnoses.update(null,Wrappers.<Diagnosis>lambdaUpdate().eq(Diagnosis::getId,id).eq(Diagnosis::getDiagnosisStatus,"PENDING").set(Diagnosis::getDiagnosisStatus,"RUNNING"));events.publish(id,"RUNNING",null,null,"诊断任务开始执行");}
 @Transactional(propagation=Propagation.REQUIRES_NEW) public void start(Long id,String node){int n=traces.update(null,Wrappers.<WorkflowTrace>lambdaUpdate().eq(WorkflowTrace::getDiagnosisId,id).eq(WorkflowTrace::getNodeCode,node).eq(WorkflowTrace::getNodeStatus,"PENDING").set(WorkflowTrace::getNodeStatus,"RUNNING").set(WorkflowTrace::getInputSummary,node).set(WorkflowTrace::getStartedAt,LocalDateTime.now()));if(n!=1)throw new IllegalStateException("工作流节点状态已变化: "+node);events.publish(id,"RUNNING",node,"RUNNING","节点开始执行");}
 @Transactional(propagation=Propagation.REQUIRES_NEW) public void success(Long id,String node,String output){int n=traces.update(null,Wrappers.<WorkflowTrace>lambdaUpdate().eq(WorkflowTrace::getDiagnosisId,id).eq(WorkflowTrace::getNodeCode,node).eq(WorkflowTrace::getNodeStatus,"RUNNING").set(WorkflowTrace::getNodeStatus,"SUCCEEDED").set(WorkflowTrace::getOutputData,output).set(WorkflowTrace::getFinishedAt,LocalDateTime.now()));if(n!=1)throw new IllegalStateException("工作流节点未处于执行中: "+node);events.publish(id,"RUNNING",node,"SUCCEEDED","节点执行完成");}
 @Transactional(propagation=Propagation.REQUIRES_NEW) public void fail(Long id,String node,String error){int index=NODES.indexOf(node);String message=trim(error);traces.update(null,Wrappers.<WorkflowTrace>lambdaUpdate().eq(WorkflowTrace::getDiagnosisId,id).eq(WorkflowTrace::getNodeCode,node).in(WorkflowTrace::getNodeStatus,List.of("PENDING","RUNNING")).set(WorkflowTrace::getNodeStatus,"FAILED").set(WorkflowTrace::getErrorMessage,message).set(WorkflowTrace::getFinishedAt,LocalDateTime.now()));for(int i=index+1;i<NODES.size();i++)traces.update(null,Wrappers.<WorkflowTrace>lambdaUpdate().eq(WorkflowTrace::getDiagnosisId,id).eq(WorkflowTrace::getNodeCode,NODES.get(i)).eq(WorkflowTrace::getNodeStatus,"PENDING").set(WorkflowTrace::getNodeStatus,"SKIPPED").set(WorkflowTrace::getFinishedAt,LocalDateTime.now()));diagnoses.update(null,Wrappers.<Diagnosis>lambdaUpdate().eq(Diagnosis::getId,id).in(Diagnosis::getDiagnosisStatus,List.of("PENDING","RUNNING")).set(Diagnosis::getDiagnosisStatus,"FAILED").set(Diagnosis::getErrorMessage,message));events.publish(id,"FAILED",node,"FAILED",message);}
 @Transactional(propagation=Propagation.REQUIRES_NEW) public void failWorkflow(Long id,String error){String node=fallbackNode(traces(id).stream().collect(java.util.stream.Collectors.toMap(WorkflowTrace::getNodeCode,WorkflowTrace::getNodeStatus,(a,b)->a,LinkedHashMap::new)));if(node!=null){fail(id,node,error);return;}diagnoses.update(null,Wrappers.<Diagnosis>lambdaUpdate().eq(Diagnosis::getId,id).set(Diagnosis::getDiagnosisStatus,"FAILED").set(Diagnosis::getErrorMessage,trim(error)));}
 @Transactional(propagation=Propagation.REQUIRES_NEW) public void finish(Diagnosis d){diagnoses.updateById(d);events.publish(d.getId(),"SUCCEEDED",null,null,"诊断任务执行成功");}
 public List<WorkflowTrace> traces(Long id){Map<String,Integer> order=new HashMap<>();for(int i=0;i<NODES.size();i++)order.put(NODES.get(i),i);return traces.selectList(Wrappers.<WorkflowTrace>lambdaQuery().eq(WorkflowTrace::getDiagnosisId,id)).stream().sorted(Comparator.comparingInt(t->order.getOrDefault(t.getNodeCode(),Integer.MAX_VALUE))).toList();}
 public static String fallbackNode(Map<String,String> statuses){for(String node:NODES)if("RUNNING".equals(statuses.get(node)))return node;for(String node:NODES)if("PENDING".equals(statuses.get(node)))return node;return null;}
 private String trim(String v){return v==null?"诊断失败":v.length()>500?v.substring(0,500):v;}
}
