package com.iiop.inspection.client;
import com.iiop.common.api.Result;
import java.util.List;
import org.springframework.cloud.openfeign.FeignClient;
import org.springframework.web.bind.annotation.*;
@FeignClient(name="iiop-auth") public interface AuthClient {
 @GetMapping("/internal/auth/users/{id}/job-summary") Result<UserJobSummary> job(@PathVariable("id") Long id);
 record UserJobSummary(String id,String status,List<String> roleCodes){}
}
