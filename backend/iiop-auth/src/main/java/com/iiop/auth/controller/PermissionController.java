package com.iiop.auth.controller;

import cn.dev33.satoken.annotation.SaCheckPermission;
import com.iiop.auth.domain.dto.PermissionRequest;
import com.iiop.auth.domain.dto.PermissionNode;
import com.iiop.auth.domain.dto.PermissionView;
import com.iiop.auth.service.AdminService;
import com.iiop.common.api.Result;
import jakarta.validation.Valid;
import java.util.List;
import org.springframework.web.bind.annotation.*;

@RestController @RequestMapping("/api/auth/permissions")
public class PermissionController {
    private final AdminService service; public PermissionController(AdminService service){this.service=service;}
    @SaCheckPermission("system:permission:view") @GetMapping public Result<List<PermissionView>> list(){return Result.success(service.permissions());}
    @SaCheckPermission("system:permission:view") @GetMapping("/tree") public Result<List<PermissionNode>> tree(){return Result.success(service.permissionTree());}
    @SaCheckPermission("system:permission:create") @PostMapping public Result<PermissionView> create(@Valid @RequestBody PermissionRequest request){return Result.success(service.createPermission(request));}
    @SaCheckPermission("system:permission:update") @PutMapping("/{id}") public Result<PermissionView> update(@PathVariable Long id,@Valid @RequestBody PermissionRequest request){return Result.success(service.updatePermission(id,request));}
    @SaCheckPermission("system:permission:delete") @DeleteMapping("/{id}") public Result<Void> delete(@PathVariable Long id){service.deletePermission(id);return Result.success();}
}
