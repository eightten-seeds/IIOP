package com.iiop.maintenance.client;
import com.iiop.common.api.Result;import org.springframework.cloud.openfeign.FeignClient;import org.springframework.web.bind.annotation.*;
@FeignClient(name="iiop-auth") public interface AuthClient {
 @PostMapping("/internal/auth/notifications") Result<Object> notify(@RequestBody NotificationRequest request);
 record NotificationRequest(Long recipientUserId,String notificationType,String title,String content,String bizType,Long bizId){}
}
