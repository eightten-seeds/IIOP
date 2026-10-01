package com.iiop.device.controller;

import cn.dev33.satoken.annotation.SaCheckPermission;
import com.iiop.common.api.PageResult;
import com.iiop.common.api.Result;
import com.iiop.device.domain.DeviceDtos.*;
import com.iiop.device.domain.DeviceModels.*;
import com.iiop.device.service.DeviceService;
import java.util.List;
import java.util.Map;
import org.springframework.web.bind.annotation.*;

@RestController
public class DeviceController {
    private final DeviceService service; public DeviceController(DeviceService service){this.service=service;}
    @SaCheckPermission("device:view") @GetMapping("/api/device/categories") public Result<List<Category>> categories(){return Result.success(service.categories());}
    @SaCheckPermission("device:view") @GetMapping("/api/device/categories/tree") public Result<List<CategoryTree>> categoryTree(){return Result.success(service.categoryTree());}
    @SaCheckPermission("device:create") @PostMapping("/api/device/categories") public Result<Category> createCategory(@RequestBody Category value){return Result.success(service.saveCategory(value,null));}
    @SaCheckPermission("device:update") @PutMapping("/api/device/categories/{id}") public Result<Category> updateCategory(@PathVariable Long id,@RequestBody Category value){return Result.success(service.saveCategory(value,id));}
    @SaCheckPermission("device:delete") @DeleteMapping("/api/device/categories/{id}") public Result<Void> deleteCategory(@PathVariable Long id){service.deleteCategory(id);return Result.success();}
    @SaCheckPermission("device:view") @GetMapping("/api/device/devices") public Result<PageResult<Device>> devices(@RequestParam(defaultValue="1") long pageNum,@RequestParam(defaultValue="20") long pageSize,@RequestParam(required=false) String keyword,@RequestParam(required=false) Long categoryId,@RequestParam(required=false) String status,@RequestParam(required=false) String riskLevel){return Result.success(service.devicePage(pageNum,pageSize,keyword,categoryId,status,riskLevel));}
    @SaCheckPermission("device:view") @GetMapping("/api/device/devices/{id}") public Result<Device> device(@PathVariable Long id){return Result.success(service.device(id));}
    @SaCheckPermission("device:create") @PostMapping("/api/device/devices") public Result<Device> createDevice(@RequestBody Device value){return Result.success(service.saveDevice(value,null));}
    @SaCheckPermission("device:update") @PutMapping("/api/device/devices/{id}") public Result<Device> updateDevice(@PathVariable Long id,@RequestBody Device value){return Result.success(service.saveDevice(value,id));}
    @SaCheckPermission("device:delete") @DeleteMapping("/api/device/devices/{id}") public Result<Void> deleteDevice(@PathVariable Long id){service.deleteDevice(id);return Result.success();}
    @SaCheckPermission("device:update") @PutMapping("/api/device/devices/{id}/status-risk") public Result<Device> statusRisk(@PathVariable Long id,@RequestBody StatusRiskRequest value){return Result.success(service.statusRisk(id,value));}
    @SaCheckPermission("device:view") @GetMapping("/api/device/devices/{id}/metrics") public Result<List<Metric>> metrics(@PathVariable Long id){return Result.success(service.metrics(id));}
    @SaCheckPermission("device:create") @PostMapping("/api/device/metrics") public Result<Metric> createMetric(@RequestBody Metric value){return Result.success(service.saveMetric(value,null));}
    @SaCheckPermission("device:update") @PutMapping("/api/device/metrics/{id}") public Result<Metric> updateMetric(@PathVariable Long id,@RequestBody Metric value){return Result.success(service.saveMetric(value,id));}
    @SaCheckPermission("device:delete") @DeleteMapping("/api/device/metrics/{id}") public Result<Void> deleteMetric(@PathVariable Long id){service.deleteMetric(id);return Result.success();}
    @SaCheckPermission("device:update") @PostMapping("/api/device/metrics/{id}/data") public Result<MetricData> addData(@PathVariable Long id,@RequestBody MetricData value){return Result.success(service.addData(id,value));}
    @SaCheckPermission("device:view") @GetMapping("/api/device/metrics/{id}/history") public Result<List<MetricData>> history(@PathVariable Long id,@RequestParam(defaultValue="100") int limit){return Result.success(service.history(id,limit));}
    @SaCheckPermission("device:view") @GetMapping("/api/device/metrics/{id}/trend") public Result<Map<String,Object>> trend(@PathVariable Long id,@RequestParam(defaultValue="100") int limit){return Result.success(service.trend(id,limit));}
    @SaCheckPermission("device:view") @GetMapping("/api/device/devices/{id}/metrics/snapshot") public Result<List<MetricData>> snapshot(@PathVariable Long id){return Result.success(service.snapshot(id));}
    @SaCheckPermission("device:view") @GetMapping("/api/device/sops") public Result<PageResult<Sop>> sops(@RequestParam(defaultValue="1") long pageNum,@RequestParam(defaultValue="20") long pageSize){return Result.success(service.sopPage(pageNum,pageSize));}
    @SaCheckPermission("device:create") @PostMapping("/api/device/sops") public Result<Sop> createSop(@RequestBody Sop value){return Result.success(service.saveSop(value,null));}
    @SaCheckPermission("device:update") @PutMapping("/api/device/sops/{id}") public Result<Sop> updateSop(@PathVariable Long id,@RequestBody Sop value){return Result.success(service.saveSop(value,id));}
    @SaCheckPermission("device:delete") @DeleteMapping("/api/device/sops/{id}") public Result<Void> deleteSop(@PathVariable Long id){service.deleteSop(id);return Result.success();}
    @SaCheckPermission("device:view") @GetMapping("/api/device/devices/{id}/sops") public Result<List<Sop>> applicableSops(@PathVariable Long id){return Result.success(service.applicableSops(id));}
    @SaCheckPermission("dashboard:view") @GetMapping("/api/device/statistics/overview") public Result<Overview> overview(){return Result.success(service.overview());}
    @GetMapping("/internal/device/devices/{id}/ai-context") public Result<AiContext> aiContext(@PathVariable Long id){return Result.success(service.aiContext(id));}
    @GetMapping("/internal/device/devices/{id}/sop-context") public Result<SopContext> sopContext(@PathVariable Long id){return Result.success(service.sopContext(id));}
}
