package com.iiop.device.client;

import com.iiop.common.api.Result;
import org.springframework.cloud.openfeign.FeignClient;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;

@FeignClient(name = "iiop-inspection")
public interface InspectionReferenceClient {

    @GetMapping("/internal/inspection/devices/{deviceId}/active-reference-count")
    Result<Long> activeReferenceCount(@PathVariable("deviceId") Long deviceId);
}
