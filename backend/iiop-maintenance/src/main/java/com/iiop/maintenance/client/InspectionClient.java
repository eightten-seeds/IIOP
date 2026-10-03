package com.iiop.maintenance.client;

import com.iiop.common.api.Result;
import org.springframework.cloud.openfeign.FeignClient;
import org.springframework.web.bind.annotation.*;

@FeignClient(name="iiop-inspection")
public interface InspectionClient {
    @PutMapping("/internal/inspection/abnormals/{id}/sync")
    Result<Object> sync(@PathVariable("id") Long id,@RequestBody AbnormalSyncRequest request);
    record AbnormalSyncRequest(String status,Long aiDiagnosisId){}
}
