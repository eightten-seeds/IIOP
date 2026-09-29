package com.iiop.inspection.client;
import com.iiop.common.api.Result;
import java.util.Map;
import org.springframework.cloud.openfeign.FeignClient;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
@FeignClient(name="iiop-device") public interface DeviceClient {
    @GetMapping("/internal/device/devices/{id}/ai-context") Result<Map<String,Object>> context(@PathVariable("id") Long id);
}
