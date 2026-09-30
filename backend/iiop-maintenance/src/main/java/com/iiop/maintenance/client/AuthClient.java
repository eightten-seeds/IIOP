package com.iiop.maintenance.client;
import com.iiop.common.api.Result;import java.util.List;import org.springframework.cloud.openfeign.FeignClient;import org.springframework.web.bind.annotation.*;
@FeignClient(name="iiop-auth") public interface AuthClient {
 @PostMapping("/internal/auth/notifications") Result<Object> notify(@RequestBody NotificationRequest request);
 @GetMapping("/internal/auth/users/{id}/job-summary") Result<UserJobSummary> job(@PathVariable("id") Long id);
 record NotificationRequest(Long recipientUserId,String notificationType,String title,String content,String bizType,Long bizId){}
 record UserJobSummary(String id,String status,List<String> roleCodes){}
}
