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
 private final AiDiagnosisMapper diagnoses; private final AiWorkflowTraceMapper traces;
 public AiPersistenceService(AiDiagnosisMapper d,AiWorkflowTraceMapper t){diagnoses=d;traces=t;}
 @Transactional(propagation=Propagation.REQUIRES_NEW) public void create(Diagnosis d){diagnoses.insert(d);for(String node:NODES){WorkflowTrace t=new WorkflowTrace();t.setDiagnosisId(d.getId());t.setNodeCode(node);t.setNodeName(node);t.setNodeStatus("PENDING");t.setCreatedAt(LocalDateTime.now());traces.insert(t);}}
 @Transactional(propagation=Propagation.REQUIRES_NEW) public void start(Long id,String node){traces.update(null,Wrappers.<WorkflowTrace>lambdaUpdate().eq(WorkflowTrace::getDiagnosisId,id).eq(WorkflowTrace::getNodeCode,node).set(WorkflowTrace::getNodeStatus,"RUNNING").set(WorkflowTrace::getInputSummary,node).set(WorkflowTrace::getStartedAt,LocalDateTime.now()));}
 @Transactional(propagation=Propagation.REQUIRES_NEW) public void success(Long id,String node,String output){traces.update(null,Wrappers.<WorkflowTrace>lambdaUpdate().eq(WorkflowTrace::getDiagnosisId,id).eq(WorkflowTrace::getNodeCode,node).set(WorkflowTrace::getNodeStatus,"SUCCEEDED").set(WorkflowTrace::getOutputData,output).set(WorkflowTrace::getFinishedAt,LocalDateTime.now()));}
 @Transactional(propagation=Propagation.REQUIRES_NEW) public void fail(Long id,String node,String error){int index=NODES.indexOf(node);traces.update(null,Wrappers.<WorkflowTrace>lambdaUpdate().eq(WorkflowTrace::getDiagnosisId,id).eq(WorkflowTrace::getNodeCode,node).set(WorkflowTrace::getNodeStatus,"FAILED").set(WorkflowTrace::getErrorMessage,trim(error)).set(WorkflowTrace::getFinishedAt,LocalDateTime.now()));for(int i=index+1;i<NODES.size();i++)traces.update(null,Wrappers.<WorkflowTrace>lambdaUpdate().eq(WorkflowTrace::getDiagnosisId,id).eq(WorkflowTrace::getNodeCode,NODES.get(i)).eq(WorkflowTrace::getNodeStatus,"PENDING").set(WorkflowTrace::getNodeStatus,"SKIPPED").set(WorkflowTrace::getFinishedAt,LocalDateTime.now()));diagnoses.update(null,Wrappers.<Diagnosis>lambdaUpdate().eq(Diagnosis::getId,id).set(Diagnosis::getDiagnosisStatus,"FAILED").set(Diagnosis::getErrorMessage,trim(error)));}
 @Transactional(propagation=Propagation.REQUIRES_NEW) public void finish(Diagnosis d){diagnoses.updateById(d);}
 public List<WorkflowTrace> traces(Long id){return traces.selectList(Wrappers.<WorkflowTrace>lambdaQuery().eq(WorkflowTrace::getDiagnosisId,id).orderByAsc(WorkflowTrace::getCreatedAt));}
 private String trim(String v){return v==null?"诊断失败":v.length()>500?v.substring(0,500):v;}
}
