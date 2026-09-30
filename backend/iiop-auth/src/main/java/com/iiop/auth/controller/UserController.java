package com.iiop.auth.controller;

import cn.dev33.satoken.annotation.SaCheckPermission;
import com.iiop.auth.domain.dto.*;
import com.iiop.auth.service.AdminService;
import com.iiop.common.api.PageResult;
import com.iiop.common.api.Result;
import jakarta.validation.Valid;
import java.util.List;
import org.springframework.web.bind.annotation.*;

@RestController @RequestMapping("/api/auth/users")
public class UserController {
    private final AdminService service; public UserController(AdminService service){this.service=service;}
    @SaCheckPermission("system:user:view") @GetMapping public Result<PageResult<UserSummary>> list(@RequestParam(defaultValue="1") long pageNum,@RequestParam(defaultValue="20") long pageSize,@RequestParam(required=false) String keyword,@RequestParam(required=false) String status,@RequestParam(required=false) String roleCode){return Result.success(service.users(pageNum,pageSize,keyword,status,roleCode));}
    @SaCheckPermission("system:user:view") @GetMapping("/{id}") public Result<UserSummary> detail(@PathVariable Long id){return Result.success(service.user(id));}
    @SaCheckPermission("system:user:view") @GetMapping("/{id}/roles") public Result<List<RoleView>> roles(@PathVariable Long id){return Result.success(service.userRoles(id));}
    @SaCheckPermission("system:user:create") @PostMapping public Result<UserSummary> create(@Valid @RequestBody UserCreateRequest request){return Result.success(service.createUser(request));}
    @SaCheckPermission("system:user:update") @PutMapping("/{id}") public Result<UserSummary> update(@PathVariable Long id,@RequestBody UserUpdateRequest request){return Result.success(service.updateUser(id,request));}
    @SaCheckPermission("system:user:update") @PutMapping("/{id}/status") public Result<Void> status(@PathVariable Long id,@Valid @RequestBody StatusRequest request){service.updateStatus(id,request);return Result.success();}
    @SaCheckPermission("system:user:role") @PutMapping("/{id}/roles") public Result<Void> roles(@PathVariable Long id,@Valid @RequestBody IdListRequest request){service.updateUserRoles(id,request);return Result.success();}
    @SaCheckPermission("system:user:delete") @DeleteMapping("/{id}") public Result<Void> delete(@PathVariable Long id){service.deleteUser(id);return Result.success();}
}
