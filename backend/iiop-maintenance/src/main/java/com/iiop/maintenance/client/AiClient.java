package com.iiop.maintenance.client;
import com.iiop.common.api.Result;import org.springframework.cloud.openfeign.FeignClient;import org.springframework.web.bind.annotation.*;
@FeignClient(name="iiop-ai")public interface AiClient{@GetMapping("/internal/ai/diagnoses/{id}/summary")Result<DiagnosisSummary>summary(@PathVariable("id")Long id);record DiagnosisSummary(Long id,String triggerType,Long triggerId,Long deviceId,String diagnosisStatus,String confirmationStatus,String riskLevel){}}
