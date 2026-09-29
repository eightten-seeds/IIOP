package com.iiop.inspection.controller;

import cn.dev33.satoken.annotation.SaCheckPermission;
import com.iiop.common.api.*;
import com.iiop.inspection.domain.InspectionDtos.*;
import com.iiop.inspection.domain.InspectionModels.*;
import com.iiop.inspection.service.InspectionService;
import java.util.List;
import org.springframework.web.bind.annotation.*;

@RestController
public class InspectionController {
    private final InspectionService service;public InspectionController(InspectionService service){this.service=service;}
    @SaCheckPermission("inspection:view") @GetMapping("/api/inspection/templates") public Result<PageResult<Template>> templates(@RequestParam(defaultValue="1") long pageNum,@RequestParam(defaultValue="20") long pageSize){return Result.success(service.templates(pageNum,pageSize));}
    @SaCheckPermission("inspection:view") @GetMapping("/api/inspection/templates/{id}") public Result<Template> template(@PathVariable Long id){return Result.success(service.template(id));}
    @SaCheckPermission("inspection:template:manage") @PostMapping("/api/inspection/templates") public Result<Template> createTemplate(@RequestBody Template v){return Result.success(service.saveTemplate(v,null));}
    @SaCheckPermission("inspection:template:manage") @PutMapping("/api/inspection/templates/{id}") public Result<Template> updateTemplate(@PathVariable Long id,@RequestBody Template v){return Result.success(service.saveTemplate(v,id));}
    @SaCheckPermission("inspection:template:manage") @DeleteMapping("/api/inspection/templates/{id}") public Result<Void> deleteTemplate(@PathVariable Long id){service.deleteTemplate(id);return Result.success();}
    @SaCheckPermission("inspection:template:manage") @PutMapping("/api/inspection/templates/{id}/flow-definition") public Result<Template> flow(@PathVariable Long id,@RequestBody FlowRequest v){return Result.success(service.flow(id,v));}
    @SaCheckPermission("inspection:view") @GetMapping("/api/inspection/templates/{id}/items") public Result<List<TemplateItem>> templateItems(@PathVariable Long id){return Result.success(service.templateItems(id));}
    @SaCheckPermission("inspection:template:manage") @PostMapping("/api/inspection/templates/{id}/items") public Result<TemplateItem> createItem(@PathVariable Long id,@RequestBody TemplateItem v){return Result.success(service.saveTemplateItem(id,v,null));}
    @SaCheckPermission("inspection:template:manage") @PutMapping("/api/inspection/templates/{templateId}/items/{id}") public Result<TemplateItem> updateItem(@PathVariable Long templateId,@PathVariable Long id,@RequestBody TemplateItem v){return Result.success(service.saveTemplateItem(templateId,v,id));}
    @SaCheckPermission("inspection:template:manage") @DeleteMapping("/api/inspection/template-items/{id}") public Result<Void> deleteItem(@PathVariable Long id){service.deleteTemplateItem(id);return Result.success();}
    @SaCheckPermission("inspection:view") @GetMapping("/api/inspection/plans") public Result<PageResult<Plan>> plans(@RequestParam(defaultValue="1") long pageNum,@RequestParam(defaultValue="20") long pageSize){return Result.success(service.plans(pageNum,pageSize));}
    @SaCheckPermission("inspection:view") @GetMapping("/api/inspection/plans/{id}") public Result<Plan> plan(@PathVariable Long id){return Result.success(service.plan(id));}
    @SaCheckPermission("inspection:plan:manage") @PostMapping("/api/inspection/plans") public Result<Plan> createPlan(@RequestBody Plan v){return Result.success(service.savePlan(v,null));}
    @SaCheckPermission("inspection:plan:manage") @PutMapping("/api/inspection/plans/{id}") public Result<Plan> updatePlan(@PathVariable Long id,@RequestBody Plan v){return Result.success(service.savePlan(v,id));}
    @SaCheckPermission("inspection:plan:manage") @DeleteMapping("/api/inspection/plans/{id}") public Result<Void> deletePlan(@PathVariable Long id){service.deletePlan(id);return Result.success();}
    @SaCheckPermission("inspection:plan:manage") @PostMapping("/api/inspection/plans/{id}/generate-task") public Result<Task> generate(@PathVariable Long id){return Result.success(service.generate(id));}
    @SaCheckPermission("inspection:view") @GetMapping("/api/inspection/tasks") public Result<PageResult<Task>> tasks(@RequestParam(defaultValue="1") long pageNum,@RequestParam(defaultValue="20") long pageSize,@RequestParam(required=false) String status){return Result.success(service.tasks(pageNum,pageSize,status));}
    @SaCheckPermission("inspection:view") @GetMapping("/api/inspection/tasks/{id}") public Result<TaskDetail> task(@PathVariable Long id){return Result.success(service.taskDetail(id));}
    @SaCheckPermission("inspection:execute") @PostMapping("/api/inspection/tasks/{id}/start") public Result<Task> start(@PathVariable Long id){return Result.success(service.start(id));}
    @SaCheckPermission("inspection:execute") @PutMapping("/api/inspection/tasks/{taskId}/items/{itemId}") public Result<TaskItem> submitItem(@PathVariable Long taskId,@PathVariable Long itemId,@RequestBody TaskItemSubmitRequest v){return Result.success(service.submitItem(taskId,itemId,v));}
    @SaCheckPermission("inspection:execute") @PostMapping("/api/inspection/tasks/{id}/complete") public Result<Task> complete(@PathVariable Long id){return Result.success(service.complete(id));}
    @SaCheckPermission("inspection:view") @GetMapping("/api/inspection/abnormals") public Result<PageResult<Abnormal>> abnormals(@RequestParam(defaultValue="1") long pageNum,@RequestParam(defaultValue="20") long pageSize){return Result.success(service.abnormals(pageNum,pageSize));}
    @SaCheckPermission("inspection:view") @GetMapping("/api/inspection/abnormals/{id}") public Result<Abnormal> abnormal(@PathVariable Long id){return Result.success(service.abnormal(id));}
    @SaCheckPermission("inspection:execute") @PostMapping("/api/inspection/abnormals") public Result<Abnormal> createAbnormal(@RequestBody Abnormal v){return Result.success(service.createAbnormal(v));}
    @GetMapping("/internal/inspection/devices/{deviceId}/recent-history") public Result<RecentHistory> recent(@PathVariable Long deviceId){return Result.success(service.recent(deviceId));}
    @GetMapping("/internal/inspection/abnormals/{id}") public Result<Abnormal> internalAbnormal(@PathVariable Long id){return Result.success(service.abnormal(id));}
}
