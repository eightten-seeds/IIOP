package com.iiop.ai.client;

import com.iiop.common.api.Result;
import java.util.*;
import org.springframework.cloud.openfeign.FeignClient;
import org.springframework.web.bind.annotation.*;

public final class AiClients {private AiClients(){}
 @FeignClient(name="iiop-device") public interface DeviceClient {
  @GetMapping("/internal/device/devices/{id}/ai-context") Result<Map<String,Object>> context(@PathVariable Long id);
  @GetMapping("/internal/device/devices/{id}/sop-context") Result<Map<String,Object>> sop(@PathVariable Long id);
 }
 @FeignClient(name="iiop-inspection") public interface InspectionClient {
  @GetMapping("/internal/inspection/devices/{id}/recent-history") Result<Map<String,Object>> history(@PathVariable Long id);
  @GetMapping("/internal/inspection/abnormals/{id}/ai-context") Result<AbnormalDto> abnormal(@PathVariable Long id);
  @GetMapping("/internal/inspection/assignees/{userId}/abnormal-ids") Result<List<Long>> abnormalIds(@PathVariable Long userId);
 }
 @FeignClient(name="iiop-maintenance") public interface MaintenanceClient {
  @GetMapping("/internal/maintenance/devices/{id}/history") Result<Map<String,Object>> history(@PathVariable Long id);
  @GetMapping("/internal/maintenance/alarms/{id}") Result<AlarmDto> alarm(@PathVariable Long id);
 }
 public record AbnormalDto(Long id,Long taskId,Long deviceId,Long assigneeUserId,String severity,String title,String description){}
 public record AlarmDto(Long id,Long deviceId,String alarmLevel,String alarmTitle,String alarmContent){}
}
