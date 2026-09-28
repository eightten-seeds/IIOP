package com.iiop.auth.service;

import cn.dev33.satoken.stp.SaLoginModel;
import cn.dev33.satoken.stp.StpUtil;
import com.baomidou.mybatisplus.core.toolkit.Wrappers;
import com.iiop.auth.domain.dto.*;
import com.iiop.auth.domain.entity.*;
import com.iiop.auth.mapper.*;
import com.iiop.common.api.ErrorCode;
import com.iiop.common.exception.BizException;
import java.time.LocalDateTime;
import java.util.*;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AuthService {
    public static final String SESSION_ROLES = "iiop:roles";
    public static final String SESSION_PERMISSIONS = "iiop:permissions";
    private final SysUserMapper users; private final SysRoleMapper roles; private final SysPermissionMapper permissions;
    private final SysUserRoleMapper userRoles; private final SysRolePermissionMapper rolePermissions; private final PasswordEncoder encoder;

    public AuthService(SysUserMapper users, SysRoleMapper roles, SysPermissionMapper permissions,
            SysUserRoleMapper userRoles, SysRolePermissionMapper rolePermissions, PasswordEncoder encoder) {
        this.users=users; this.roles=roles; this.permissions=permissions; this.userRoles=userRoles;
        this.rolePermissions=rolePermissions; this.encoder=encoder;
    }

    @Transactional
    public LoginResponse login(LoginRequest request) {
        SysUser user = users.selectOne(Wrappers.<SysUser>lambdaQuery().eq(SysUser::getUsername, request.username()));
        if (user == null || !encoder.matches(request.password(), user.getPasswordHash())) throw loginFailed();
        if (!"ENABLED".equals(user.getStatus())) throw loginFailed();
        AuthSnapshot snapshot = snapshot(user.getId());
        StpUtil.login(user.getId(), new SaLoginModel().setDevice("api"));
        StpUtil.getSession().set(SESSION_ROLES, snapshot.roles()).set(SESSION_PERMISSIONS, snapshot.permissions());
        user.setLastLoginTime(LocalDateTime.now()); users.updateById(user);
        return new LoginResponse(StpUtil.getTokenName(), StpUtil.getTokenValue(), summary(user), snapshot.roles(), snapshot.permissions());
    }

    public MeResponse me() {
        Long id = StpUtil.getLoginIdAsLong();
        SysUser user = requireUser(id);
        return new MeResponse(summary(user), sessionList(SESSION_ROLES), sessionList(SESSION_PERMISSIONS));
    }

    public void logout() { StpUtil.logout(); }

    public AuthSnapshot snapshot(Long userId) {
        List<Long> roleIds = userRoles.selectList(Wrappers.<SysUserRole>lambdaQuery().eq(SysUserRole::getUserId,userId))
                .stream().map(SysUserRole::getRoleId).toList();
        if (roleIds.isEmpty()) return new AuthSnapshot(List.of(), List.of());
        List<String> roleCodes = roles.selectBatchIds(roleIds).stream().filter(r -> "ENABLED".equals(r.getStatus()))
                .map(SysRole::getRoleCode).distinct().sorted().toList();
        List<Long> permissionIds = rolePermissions.selectList(Wrappers.<SysRolePermission>lambdaQuery().in(SysRolePermission::getRoleId,roleIds))
                .stream().map(SysRolePermission::getPermissionId).distinct().toList();
        List<String> permissionCodes = permissionIds.isEmpty() ? List.of() : permissions.selectBatchIds(permissionIds).stream()
                .filter(p -> "ENABLED".equals(p.getStatus())).map(SysPermission::getPermissionCode).distinct().sorted().toList();
        return new AuthSnapshot(roleCodes, permissionCodes);
    }

    @SuppressWarnings("unchecked")
    public List<String> sessionList(String key) {
        Object value = StpUtil.getSession().get(key);
        return value instanceof List<?> list ? list.stream().map(String::valueOf).toList() : List.of();
    }

    public SysUser requireUser(Long id) {
        SysUser user=users.selectById(id); if(user==null) throw new BizException(ErrorCode.NOT_FOUND,"用户不存在"); return user;
    }
    public UserSummary summary(SysUser user) { return new UserSummary(String.valueOf(user.getId()),user.getUsername(),user.getRealName(),user.getStatus()); }
    private BizException loginFailed(){return new BizException(ErrorCode.UNAUTHORIZED,"用户名或密码错误，或账号不可用");}
    public record AuthSnapshot(List<String> roles,List<String> permissions) { }
}
