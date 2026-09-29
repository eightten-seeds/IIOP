package com.iiop.ai.service;

import cn.dev33.satoken.stp.StpUtil;
import com.baomidou.mybatisplus.core.toolkit.Wrappers;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.iiop.ai.domain.AiDtos.*;
import com.iiop.ai.domain.AiModels.*;
import com.iiop.ai.mapper.AiDiagnosisMapper;
import com.iiop.ai.workflow.*;
import com.iiop.common.api.*;
import com.iiop.common.exception.BizException;
import java.time.LocalDateTime;
import java.util.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service public class AiDiagnosisService {
 private static final Set<String> TYPES=Set.of("INSPECTION_ABNORMAL","ALARM","MANUAL");private final AiDiagnosisMapper diagnoses;private final AiPersistenceService persistence;private final AiWorkflow workflow;private final ObjectMapper json;
 public AiDiagnosisService(AiDiagnosisMapper d,AiPersistenceService p,AiWorkflow w,ObjectMapper j){diagnoses=d;persistence=p;workflow=w;json=j;}
 public DiagnosisView create(CreateRequest r){validateRequest(r);if(!"MANUAL".equals(r.triggerType())&&diagnoses.selectCount(Wrappers.<Diagnosis>lambdaQuery().eq(Diagnosis::getTriggerType,r.triggerType()).eq(Diagnosis::getTriggerId,r.triggerId()))>0)throw new BizException(ErrorCode.CONFLICT,"该触发对象已存在诊断");Diagnosis d=new Diagnosis();d.setDiagnosisCode("AI"+System.currentTimeMillis());d.setTriggerType(r.triggerType());d.setTriggerId(r.triggerId());d.setDeviceId(r.deviceId());d.setAbnormalSummary(blank(r.abnormalSummary())?"待加载异常摘要":r.abnormalSummary());d.setUserDescription(r.userDescription());d.setDiagnosisStatus("PENDING");d.setConfirmationStatus("PENDING");d.setPromptVersion("iiop-diagnosis-v1");d.setCreatedAt(LocalDateTime.now());persistence.create(d);persistence.markRunning(d.getId());try{WorkflowData result=workflow.execute(d,new WorkflowInput(r.triggerType(),r.triggerId(),r.deviceId(),r.abnormalSummary(),r.userDescription()));applySuccess(d,result);persistence.finish(d);return view(d);}catch(Exception e){return view(require(d.getId()));}}
 public PageResult<Diagnosis> list(long page,long size){var p=diagnoses.selectPage(new com.baomidou.mybatisplus.extension.plugins.pagination.Page<Diagnosis>(page,Math.min(size,100)),Wrappers.<Diagnosis>lambdaQuery().orderByDesc(Diagnosis::getCreatedAt));return new PageResult<>(p.getCurrent(),p.getSize(),p.getTotal(),p.getRecords());}
 public DiagnosisView detail(Long id){return view(require(id));}public List<WorkflowTrace> workflow(Long id){require(id);return persistence.traces(id);}
 @Transactional public DiagnosisView confirm(Long id,String comment,boolean accepted){Diagnosis d=require(id);if(!"SUCCEEDED".equals(d.getDiagnosisStatus()))throw new BizException(ErrorCode.CONFLICT,"诊断尚未成功");if(!"PENDING".equals(d.getConfirmationStatus()))throw new BizException(ErrorCode.CONFLICT,"诊断已确认或已拒绝");d.setConfirmationStatus(accepted?"CONFIRMED":"REJECTED");d.setConfirmedBy(StpUtil.getLoginIdAsLong());d.setConfirmedAt(LocalDateTime.now());d.setConfirmationComment(comment);diagnoses.updateById(d);return view(d);}
 private void validateRequest(CreateRequest r){if(!TYPES.contains(r.triggerType()))throw bad("触发类型不正确");if(r.deviceId()==null)throw bad("deviceId 必填");if("MANUAL".equals(r.triggerType())){if(r.triggerId()!=null||blank(r.abnormalSummary()))throw bad("MANUAL 诊断需要异常摘要且不能传 triggerId");}else if(r.triggerId()==null)throw bad("非 MANUAL 诊断需要 triggerId");}
 private void applySuccess(Diagnosis d,WorkflowData r){ModelResult m=r.model;d.setRiskLevel(r.risk);d.setAbnormalSummary(m.abnormalSummary());d.setPossibleCauses(m.possibleCauses());d.setInvestigationSteps(m.investigationSteps());d.setMaintenanceAdvice(m.maintenanceAdvice());d.setSafetyNotice(m.safetyNotice());d.setContextSnapshot(r.context);d.setModelName(workflow.modelName());d.setDiagnosisStatus("SUCCEEDED");d.setConfirmationStatus("PENDING");d.setErrorMessage(null);}
 private Diagnosis require(Long id){Diagnosis d=diagnoses.selectById(id);if(d==null)throw new BizException(ErrorCode.NOT_FOUND,"AI 诊断不存在");return d;}private DiagnosisView view(Diagnosis d){WorkOrderDraft draft=null;for(WorkflowTrace t:persistence.traces(d.getId()))if("PREPARE_WORK_ORDER_DRAFT".equals(t.getNodeCode())&&"SUCCEEDED".equals(t.getNodeStatus())&&t.getOutputData()!=null)try{draft=json.readValue(t.getOutputData(),WorkOrderDraft.class);}catch(Exception ignored){}return new DiagnosisView(d,d.getPossibleCauses()==null?List.of():d.getPossibleCauses(),d.getInvestigationSteps()==null?List.of():d.getInvestigationSteps(),draft,AiWorkflow.requiresConfirmation(d.getRiskLevel()));}private boolean blank(String v){return v==null||v.isBlank();}private BizException bad(String m){return new BizException(ErrorCode.BAD_REQUEST,m);}
}
