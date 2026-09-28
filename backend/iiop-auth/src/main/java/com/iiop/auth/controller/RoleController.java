package com.iiop.auth.controller;

import cn.dev33.satoken.annotation.SaCheckPermission;
import com.iiop.auth.domain.dto.IdListRequest;
import com.iiop.auth.domain.dto.RoleRequest;
import com.iiop.auth.domain.dto.RoleView;
import com.iiop.auth.service.AdminService;
import com.iiop.common.api.Result;
import jakarta.validation.Valid;
import java.util.List;
import org.springframework.web.bind.annotation.*;

@RestController @RequestMapping("/api/auth/roles")
public class RoleController {
    private final AdminService service; public RoleController(AdminService service){this.service=service;}
    @SaCheckPermission("system:role:view") @GetMapping public Result<List<RoleView>> list(){return Result.success(service.roles());}
    @SaCheckPermission("system:role:view") @GetMapping("/{id}") public Result<RoleView> detail(@PathVariable Long id){return Result.success(service.role(id));}
    @SaCheckPermission("system:role:create") @PostMapping public Result<RoleView> create(@Valid @RequestBody RoleRequest request){return Result.success(service.createRole(request));}
    @SaCheckPermission("system:role:update") @PutMapping("/{id}") public Result<RoleView> update(@PathVariable Long id,@Valid @RequestBody RoleRequest request){return Result.success(service.updateRole(id,request));}
    @SaCheckPermission("system:role:delete") @DeleteMapping("/{id}") public Result<Void> delete(@PathVariable Long id){service.deleteRole(id);return Result.success();}
    @SaCheckPermission("system:role:permission") @PutMapping("/{id}/permissions") public Result<Void> permissions(@PathVariable Long id,@Valid @RequestBody IdListRequest request){service.updateRolePermissions(id,request);return Result.success();}
}
