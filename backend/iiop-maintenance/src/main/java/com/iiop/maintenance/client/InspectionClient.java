package com.iiop.maintenance.client;

import com.iiop.common.api.Result;
import org.springframework.cloud.openfeign.FeignClient;
import org.springframework.web.bind.annotation.*;

@FeignClient(name="iiop-inspection")
public interface InspectionClient {
    @PutMapping("/internal/inspection/abnormals/{id}/ai-association")
    Result<Object> associateAi(@PathVariable("id") Long id,@RequestBody AbnormalAiAssociationRequest request);
    record AbnormalAiAssociationRequest(Long aiDiagnosisId){}
}
