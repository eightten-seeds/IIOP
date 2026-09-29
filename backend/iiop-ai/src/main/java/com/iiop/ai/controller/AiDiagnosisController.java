package com.iiop.ai.controller;

import cn.dev33.satoken.annotation.SaCheckPermission;
import com.iiop.ai.domain.AiDtos.*;
import com.iiop.ai.domain.AiModels.*;
import com.iiop.ai.service.AiDiagnosisService;
import com.iiop.common.api.*;
import jakarta.validation.Valid;
import java.util.List;
import org.springframework.web.bind.annotation.*;

@RestController @RequestMapping("/api/ai/diagnoses") public class AiDiagnosisController {
 private final AiDiagnosisService service;public AiDiagnosisController(AiDiagnosisService s){service=s;}
 @SaCheckPermission("ai:diagnosis") @PostMapping public Result<DiagnosisView> create(@Valid @RequestBody CreateRequest r){return Result.success(service.create(r));}
 @SaCheckPermission("ai:view") @GetMapping public Result<PageResult<Diagnosis>> list(@RequestParam(defaultValue="1") long pageNum,@RequestParam(defaultValue="20") long pageSize){return Result.success(service.list(pageNum,pageSize));}
 @SaCheckPermission("ai:view") @GetMapping("/{id}") public Result<DiagnosisView> detail(@PathVariable Long id){return Result.success(service.detail(id));}
 @SaCheckPermission("ai:view") @GetMapping("/{id}/workflow") public Result<List<WorkflowTrace>> workflow(@PathVariable Long id){return Result.success(service.workflow(id));}
 @SaCheckPermission("ai:confirm") @PostMapping("/{id}/confirm") public Result<DiagnosisView> confirm(@PathVariable Long id,@RequestBody(required=false) ConfirmRequest r){return Result.success(service.confirm(id,r==null?null:r.comment(),true));}
 @SaCheckPermission("ai:confirm") @PostMapping("/{id}/reject") public Result<DiagnosisView> reject(@PathVariable Long id,@RequestBody(required=false) ConfirmRequest r){return Result.success(service.confirm(id,r==null?null:r.comment(),false));}
}
