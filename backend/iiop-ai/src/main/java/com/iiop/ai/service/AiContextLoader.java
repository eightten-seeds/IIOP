package com.iiop.ai.service;

import com.iiop.ai.client.AiClients.*;
import com.iiop.ai.workflow.WorkflowData;
import com.iiop.common.api.Result;
import com.iiop.common.exception.BizException;
import com.iiop.common.api.ErrorCode;
import java.util.*;
import org.springframework.stereotype.Service;

@Service public class AiContextLoader {
 private final DeviceClient devices;private final InspectionClient inspection;private final MaintenanceClient maintenance;
 public AiContextLoader(DeviceClient d,InspectionClient i,MaintenanceClient m){devices=d;inspection=i;maintenance=m;}
 public Map<String,Object> load(WorkflowData data){Map<String,Object> context=new LinkedHashMap<>();List<String> missing=new ArrayList<>();String risk="LOW";String summary=data.input.abnormalSummary();if("INSPECTION_ABNORMAL".equals(data.input.triggerType())){AbnormalDto a=body(inspection.abnormal(data.input.triggerId()),"巡检异常不存在");match(a.deviceId(),data.input.deviceId());risk=a.severity();summary=join(a.title(),a.description());context.put("trigger",nullableMap("id",a.id(),"deviceId",a.deviceId(),"severity",a.severity(),"title",a.title(),"description",a.description()));}else if("ALARM".equals(data.input.triggerType())){AlarmDto a=body(maintenance.alarm(data.input.triggerId()),"告警不存在");match(a.deviceId(),data.input.deviceId());risk=alarmRisk(a.alarmLevel());summary=join(a.alarmTitle(),a.alarmContent());context.put("trigger",nullableMap("id",a.id(),"deviceId",a.deviceId(),"alarmLevel",a.alarmLevel(),"title",a.alarmTitle(),"content",a.alarmContent()));}else context.put("triggerType","MANUAL");try{context.put("device",body(devices.context(data.input.deviceId()),"设备上下文不可用"));context.put("sop",body(devices.sop(data.input.deviceId()),"SOP 上下文不可用"));}catch(Exception e){throw new IllegalStateException("设备上下文加载失败",e);}try{context.put("inspectionHistory",body(inspection.history(data.input.deviceId()),"巡检历史不可用"));}catch(Exception e){context.put("inspectionHistory",Map.of());missing.add("inspectionHistory");}try{context.put("maintenanceHistory",body(maintenance.history(data.input.deviceId()),"维修历史不可用"));}catch(Exception e){context.put("maintenanceHistory",Map.of());missing.add("maintenanceHistory");}context.put("missingItems",missing);context.put("triggerRisk",risk);context.put("abnormalSummary",summary);context.put("userDescription",data.input.userDescription());data.risk=risk;data.diagnosis.setAbnormalSummary(summary);return context;}
 private Map<String,Object> nullableMap(Object... values){Map<String,Object> result=new LinkedHashMap<>();for(int i=0;i<values.length;i+=2)result.put((String)values[i],values[i+1]);return result;}
 private void match(Long actual,Long request){if(!Objects.equals(actual,request))throw new BizException(ErrorCode.BAD_REQUEST,"触发对象与设备不匹配");}private <T>T body(Result<T> r,String message){if(r==null||r.code()!=0||r.data()==null)throw new BizException(ErrorCode.NOT_FOUND,message);return r.data();}private String alarmRisk(String v){return Map.of("INFO","LOW","WARNING","MEDIUM","MAJOR","HIGH","CRITICAL","CRITICAL").getOrDefault(v,"LOW");}private String join(String a,String b){return (a==null?"":a)+(b==null?"":"："+b);}
}
