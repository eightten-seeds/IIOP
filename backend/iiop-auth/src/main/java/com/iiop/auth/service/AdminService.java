package com.iiop.auth.service;

import cn.dev33.satoken.stp.StpUtil;
import com.baomidou.mybatisplus.core.metadata.IPage;
import com.baomidou.mybatisplus.core.toolkit.Wrappers;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.iiop.auth.domain.dto.*;
import com.iiop.auth.domain.entity.*;
import com.iiop.auth.mapper.*;
import com.iiop.common.api.ErrorCode;
import com.iiop.common.api.PageResult;
import com.iiop.common.api.PaginationGuard;
import com.iiop.common.exception.BizException;
import java.time.LocalDateTime;
import java.util.*;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AdminService {
    private static final Set<String> FIXED_ROLES=Set.of("SUPER_ADMIN","ADMIN","INSPECTOR","MAINTAINER");
    private final SysUserMapper users; private final SysRoleMapper roles; private final SysPermissionMapper permissions;
    private final SysUserRoleMapper userRoles; private final SysRolePermissionMapper rolePermissions; private final PasswordEncoder encoder;
    public AdminService(SysUserMapper u,SysRoleMapper r,SysPermissionMapper p,SysUserRoleMapper ur,SysRolePermissionMapper rp,PasswordEncoder e){users=u;roles=r;permissions=p;userRoles=ur;rolePermissions=rp;encoder=e;}

    public PageResult<UserSummary> users(long pageNum,long pageSize,String keyword,String status,String roleCode){
        long safePageSize=PaginationGuard.limit(pageNum,pageSize);
        var q=Wrappers.<SysUser>lambdaQuery().eq(status!=null&&!status.isBlank(),SysUser::getStatus,status).and(keyword!=null&&!keyword.isBlank(),w->w.like(SysUser::getUsername,keyword).or().like(SysUser::getRealName,keyword));
        if(roleCode!=null&&!roleCode.isBlank()){SysRole role=roles.selectOne(Wrappers.<SysRole>lambdaQuery().eq(SysRole::getRoleCode,roleCode));if(role==null)return new PageResult<>(pageNum,safePageSize,0,List.of());q.inSql(SysUser::getId,"select user_id from sys_user_role where role_id="+role.getId());}
        IPage<SysUser> page=users.selectPage(new Page<>(pageNum,safePageSize),q.orderByDesc(SysUser::getCreatedAt));
        return new PageResult<>(page.getCurrent(),page.getSize(),page.getTotal(),page.getRecords().stream().map(this::summary).toList());
    }
    public UserSummary user(Long id){return summary(requireUser(id));}
    public List<RoleView> userRoles(Long id){requireUser(id);List<Long> ids=userRoles.selectList(Wrappers.<SysUserRole>lambdaQuery().eq(SysUserRole::getUserId,id)).stream().map(SysUserRole::getRoleId).toList();return ids.isEmpty()?List.of():roles.selectBatchIds(ids).stream().filter(r->FIXED_ROLES.contains(r.getRoleCode())).map(this::view).toList();}
    public UserJobSummary jobSummary(Long id){SysUser u=requireUser(id);List<Long> ids=userRoles.selectList(Wrappers.<SysUserRole>lambdaQuery().eq(SysUserRole::getUserId,id)).stream().map(SysUserRole::getRoleId).toList();List<String> codes=ids.isEmpty()?List.of():roles.selectBatchIds(ids).stream().filter(r->"ENABLED".equals(r.getStatus())).map(SysRole::getRoleCode).sorted().toList();return new UserJobSummary(String.valueOf(id),u.getStatus(),codes);}
    @Transactional public UserSummary createUser(UserCreateRequest req){
        if(users.selectCount(Wrappers.<SysUser>lambdaQuery().eq(SysUser::getUsername,req.username()))>0)throw new BizException(ErrorCode.CONFLICT,"用户名已存在");
        SysUser u=new SysUser();u.setUsername(req.username());u.setPasswordHash(encoder.encode(req.password()));u.setRealName(req.realName());u.setPhone(req.phone());u.setEmail(req.email());u.setAvatarUrl(req.avatarUrl());u.setStatus(normalStatus(req.status()));u.setDeleted(0);users.insert(u);return summary(u);
    }
    @Transactional public UserSummary updateUser(Long id,UserUpdateRequest req){SysUser u=requireUser(id);u.setRealName(req.realName());u.setPhone(req.phone());u.setEmail(req.email());u.setAvatarUrl(req.avatarUrl());users.updateById(u);return summary(u);}
    @Transactional public void updateStatus(Long id,StatusRequest req){
        if(!List.of("ENABLED","DISABLED","LOCKED").contains(req.status()))throw new BizException(ErrorCode.BAD_REQUEST,"用户状态无效");
        SysUser u=requireUser(id);
        if(hasSuperAdminRole(id)){ requireRolePermissionForSuperAdminChange(); if(isSelf(id))throw new BizException(ErrorCode.CONFLICT,"超级管理员不能禁用、锁定自己"); }
        u.setStatus(req.status());users.updateById(u);if(!"ENABLED".equals(req.status()))StpUtil.logout(id);
    }
    @Transactional public void updateUserRoles(Long id,IdListRequest req){
        requireUser(id);
        List<Long> requestedRoleIds=req.ids().stream().distinct().toList();
        List<SysRole> requestedRoles=requestedRoleIds.isEmpty()?List.of():roles.selectBatchIds(requestedRoleIds);
        if(requestedRoles.size()!=requestedRoleIds.size())throw new BizException(ErrorCode.BAD_REQUEST,"角色不存在");
        if(requestedRoles.stream().anyMatch(r->!FIXED_ROLES.contains(r.getRoleCode())))throw new BizException(ErrorCode.BAD_REQUEST,"只能分配固定业务角色");
        boolean hadSuperAdmin=hasSuperAdminRole(id);
        boolean willHaveSuperAdmin=requestedRoles.stream().anyMatch(role->"SUPER_ADMIN".equals(role.getRoleCode()));
        if(hadSuperAdmin!=willHaveSuperAdmin){requireRolePermissionForSuperAdminChange();if(isSelf(id)&&hadSuperAdmin)throw new BizException(ErrorCode.CONFLICT,"超级管理员不能移除自己的超级管理员角色");}
        userRoles.delete(Wrappers.<SysUserRole>lambdaQuery().eq(SysUserRole::getUserId,id));
        for(Long roleId:requestedRoleIds){SysUserRole x=new SysUserRole();x.setUserId(id);x.setRoleId(roleId);x.setCreatedAt(LocalDateTime.now());userRoles.insert(x);}
        StpUtil.logout(id);
    }
    @Transactional public void deleteUser(Long id){requireUser(id);if(hasSuperAdminRole(id)){requireRolePermissionForSuperAdminChange();if(isSelf(id))throw new BizException(ErrorCode.CONFLICT,"超级管理员不能删除自己");throw new BizException(ErrorCode.CONFLICT,"仍拥有超级管理员角色的用户不能删除");}StpUtil.logout(id);userRoles.delete(Wrappers.<SysUserRole>lambdaQuery().eq(SysUserRole::getUserId,id));users.deleteById(id);}
    @Transactional public void resetPassword(Long id, ResetPasswordRequest req){
        if(isSelf(id))throw new BizException(ErrorCode.BAD_REQUEST,"不能在用户列表中重置自身密码，请使用个人中心修改密码");
        SysUser u=requireUser(id);
        if(hasSuperAdminRole(id))requireRolePermissionForSuperAdminChange();
        u.setPasswordHash(encoder.encode(req.newPassword()));
        users.updateById(u);
        StpUtil.logout(id);
    }

    public List<RoleView> roles(){return roles.selectList(Wrappers.<SysRole>lambdaQuery().orderByAsc(SysRole::getRoleCode)).stream().map(this::view).toList();}
    public RoleView role(Long id){return view(requireRole(id));}
    public List<PermissionView> rolePermissions(Long id){
        requireRole(id);
        List<Long> pids=rolePermissions.selectList(Wrappers.<SysRolePermission>lambdaQuery().eq(SysRolePermission::getRoleId,id)).stream().map(SysRolePermission::getPermissionId).toList();
        return pids.isEmpty()?List.of():permissions.selectBatchIds(pids).stream().filter(p->"ENABLED".equals(p.getStatus())).sorted(Comparator.comparing(SysPermission::getSortOrder)).map(this::view).toList();
    }
    @Transactional public RoleView createRole(RoleRequest req){throw frozen();}
    @Transactional public RoleView updateRole(Long id,RoleRequest req){throw frozen();}
    @Transactional public void deleteRole(Long id){throw frozen();}
    @Transactional public void updateRolePermissions(Long id,IdListRequest req){throw frozen();}

    public List<PermissionView> permissions(){return permissionEntities().stream().map(this::view).toList();}
    public List<PermissionNode> permissionTree(){
        List<SysPermission> all=permissionEntities(); Map<Long,PermissionNode> nodes=new LinkedHashMap<>();
        all.forEach(p->nodes.put(p.getId(),new PermissionNode(view(p)))); List<PermissionNode> roots=new ArrayList<>();
        for(SysPermission p:all){PermissionNode node=nodes.get(p.getId());PermissionNode parent=p.getParentId()==null?null:nodes.get(p.getParentId());if(parent==null)roots.add(node);else parent.children().add(node);}
        return roots;
    }
    @Transactional public PermissionView createPermission(PermissionRequest req){throw frozen();}
    @Transactional public PermissionView updatePermission(Long id,PermissionRequest req){throw frozen();}
    @Transactional public void deletePermission(Long id){throw frozen();}

    private SysUser requireUser(Long id){SysUser u=users.selectById(id);if(u==null)throw new BizException(ErrorCode.NOT_FOUND,"用户不存在");return u;}
    private SysRole requireRole(Long id){SysRole r=roles.selectById(id);if(r==null)throw new BizException(ErrorCode.NOT_FOUND,"角色不存在");return r;}
    private SysPermission requirePermission(Long id){SysPermission p=permissions.selectById(id);if(p==null)throw new BizException(ErrorCode.NOT_FOUND,"权限不存在");return p;}
    private boolean hasSuperAdminRole(Long userId){
        List<Long> roleIds=userRoles.selectList(Wrappers.<SysUserRole>lambdaQuery().eq(SysUserRole::getUserId,userId)).stream().map(SysUserRole::getRoleId).toList();
        return !roleIds.isEmpty()&&roles.selectBatchIds(roleIds).stream().anyMatch(role->"SUPER_ADMIN".equals(role.getRoleCode()));
    }
    private void requireRolePermissionForSuperAdminChange(){
        if(!StpUtil.hasPermission("system:role:permission")||!StpUtil.hasRole("SUPER_ADMIN"))throw new BizException(ErrorCode.FORBIDDEN,"仅超级管理员可以修改超级管理员角色或状态");
    }
    private boolean isSelf(Long id){return Objects.equals(StpUtil.getLoginIdAsLong(),id);}
    private BizException frozen(){return new BizException(ErrorCode.CONFLICT,"第一版固定角色、权限及权限矩阵不可修改");}
    private List<SysPermission> permissionEntities(){return permissions.selectList(Wrappers.<SysPermission>lambdaQuery().orderByAsc(SysPermission::getSortOrder));}
    private UserSummary summary(SysUser u){return new UserSummary(String.valueOf(u.getId()),u.getUsername(),u.getRealName(),u.getStatus());}
    private String normalStatus(String s){return s==null||s.isBlank()?"ENABLED":s;}
    private void apply(SysRole r,RoleRequest q){r.setRoleCode(q.roleCode());r.setRoleName(q.roleName());r.setDescription(q.description());r.setStatus(normalStatus(q.status()));}
    private void apply(SysPermission p,PermissionRequest q){p.setParentId(q.parentId());p.setPermissionCode(q.permissionCode());p.setPermissionName(q.permissionName());p.setPermissionType(q.permissionType());p.setRoutePath(q.routePath());p.setApiPath(q.apiPath());p.setHttpMethod(q.httpMethod());p.setSortOrder(q.sortOrder());p.setStatus(normalStatus(q.status()));}
    private RoleView view(SysRole r){return new RoleView(String.valueOf(r.getId()),r.getRoleCode(),r.getRoleName(),r.getDescription(),r.getStatus());}
    private PermissionView view(SysPermission p){return new PermissionView(String.valueOf(p.getId()),p.getParentId()==null?null:String.valueOf(p.getParentId()),p.getPermissionCode(),p.getPermissionName(),p.getPermissionType(),p.getRoutePath(),p.getApiPath(),p.getHttpMethod(),p.getSortOrder(),p.getStatus());}
}
