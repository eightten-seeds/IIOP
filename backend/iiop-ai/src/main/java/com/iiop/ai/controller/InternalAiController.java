package com.iiop.ai.controller;
import com.iiop.ai.domain.AiDtos.DiagnosisSummary;import com.iiop.ai.service.AiDiagnosisService;import com.iiop.common.api.Result;import org.springframework.web.bind.annotation.*;
@RestController @RequestMapping("/internal/ai") public class InternalAiController {private final AiDiagnosisService service;public InternalAiController(AiDiagnosisService s){service=s;}@GetMapping("/diagnoses/{id}/summary")public Result<DiagnosisSummary>summary(@PathVariable Long id){return Result.success(service.summary(id));}}
