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
import com.iiop.common.exception.BizException;
import java.time.LocalDateTime;
import java.util.*;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AdminService {
    private final SysUserMapper users; private final SysRoleMapper roles; private final SysPermissionMapper permissions;
    private final SysUserRoleMapper userRoles; private final SysRolePermissionMapper rolePermissions; private final PasswordEncoder encoder;
    public AdminService(SysUserMapper u,SysRoleMapper r,SysPermissionMapper p,SysUserRoleMapper ur,SysRolePermissionMapper rp,PasswordEncoder e){users=u;roles=r;permissions=p;userRoles=ur;rolePermissions=rp;encoder=e;}

    public PageResult<UserSummary> users(long pageNum,long pageSize){
        IPage<SysUser> page=users.selectPage(new Page<>(pageNum,Math.min(pageSize,100)),Wrappers.<SysUser>lambdaQuery().orderByDesc(SysUser::getCreatedAt));
        return new PageResult<>(page.getCurrent(),page.getSize(),page.getTotal(),page.getRecords().stream().map(this::summary).toList());
    }
    public UserSummary user(Long id){return summary(requireUser(id));}
    @Transactional public UserSummary createUser(UserCreateRequest req){
        if(users.selectCount(Wrappers.<SysUser>lambdaQuery().eq(SysUser::getUsername,req.username()))>0)throw new BizException(ErrorCode.CONFLICT,"用户名已存在");
        SysUser u=new SysUser();u.setUsername(req.username());u.setPasswordHash(encoder.encode(req.password()));u.setRealName(req.realName());u.setPhone(req.phone());u.setEmail(req.email());u.setAvatarUrl(req.avatarUrl());u.setStatus(normalStatus(req.status()));u.setDeleted(0);users.insert(u);return summary(u);
    }
    @Transactional public UserSummary updateUser(Long id,UserUpdateRequest req){SysUser u=requireUser(id);u.setRealName(req.realName());u.setPhone(req.phone());u.setEmail(req.email());u.setAvatarUrl(req.avatarUrl());users.updateById(u);return summary(u);}
    @Transactional public void updateStatus(Long id,StatusRequest req){if(!List.of("ENABLED","DISABLED","LOCKED").contains(req.status()))throw new BizException(ErrorCode.BAD_REQUEST,"用户状态无效");SysUser u=requireUser(id);u.setStatus(req.status());users.updateById(u);if(!"ENABLED".equals(req.status()))StpUtil.logout(id);}
    @Transactional public void updateUserRoles(Long id,IdListRequest req){requireUser(id);if(!req.ids().isEmpty()&&roles.selectBatchIds(req.ids()).size()!=req.ids().stream().distinct().count())throw new BizException(ErrorCode.BAD_REQUEST,"角色不存在");userRoles.delete(Wrappers.<SysUserRole>lambdaQuery().eq(SysUserRole::getUserId,id));for(Long roleId:req.ids().stream().distinct().toList()){SysUserRole x=new SysUserRole();x.setUserId(id);x.setRoleId(roleId);x.setCreatedAt(LocalDateTime.now());userRoles.insert(x);}StpUtil.logout(id);}
    @Transactional public void deleteUser(Long id){requireUser(id);StpUtil.logout(id);userRoles.delete(Wrappers.<SysUserRole>lambdaQuery().eq(SysUserRole::getUserId,id));users.deleteById(id);}

    public List<RoleView> roles(){return roles.selectList(Wrappers.<SysRole>lambdaQuery().orderByAsc(SysRole::getRoleCode)).stream().map(this::view).toList();}
    public RoleView role(Long id){return view(requireRole(id));}
    @Transactional public RoleView createRole(RoleRequest req){if(roles.selectCount(Wrappers.<SysRole>lambdaQuery().eq(SysRole::getRoleCode,req.roleCode()))>0)throw new BizException(ErrorCode.CONFLICT,"角色编码已存在");SysRole r=new SysRole();apply(r,req);r.setDeleted(0);roles.insert(r);return view(r);}
    @Transactional public RoleView updateRole(Long id,RoleRequest req){SysRole r=requireRole(id);apply(r,req);roles.updateById(r);return view(r);}
    @Transactional public void deleteRole(Long id){requireRole(id);if(userRoles.selectCount(Wrappers.<SysUserRole>lambdaQuery().eq(SysUserRole::getRoleId,id))>0)throw new BizException(ErrorCode.CONFLICT,"角色仍被用户使用");rolePermissions.delete(Wrappers.<SysRolePermission>lambdaQuery().eq(SysRolePermission::getRoleId,id));roles.deleteById(id);}
    @Transactional public void updateRolePermissions(Long id,IdListRequest req){requireRole(id);if(!req.ids().isEmpty()&&permissions.selectBatchIds(req.ids()).size()!=req.ids().stream().distinct().count())throw new BizException(ErrorCode.BAD_REQUEST,"权限不存在");rolePermissions.delete(Wrappers.<SysRolePermission>lambdaQuery().eq(SysRolePermission::getRoleId,id));for(Long permissionId:req.ids().stream().distinct().toList()){SysRolePermission x=new SysRolePermission();x.setRoleId(id);x.setPermissionId(permissionId);x.setCreatedAt(LocalDateTime.now());rolePermissions.insert(x);}List<Long> affected=userRoles.selectList(Wrappers.<SysUserRole>lambdaQuery().eq(SysUserRole::getRoleId,id)).stream().map(SysUserRole::getUserId).distinct().toList();affected.forEach(StpUtil::logout);}

    public List<PermissionView> permissions(){return permissionEntities().stream().map(this::view).toList();}
    public List<PermissionNode> permissionTree(){
        List<SysPermission> all=permissionEntities(); Map<Long,PermissionNode> nodes=new LinkedHashMap<>();
        all.forEach(p->nodes.put(p.getId(),new PermissionNode(view(p)))); List<PermissionNode> roots=new ArrayList<>();
        for(SysPermission p:all){PermissionNode node=nodes.get(p.getId());PermissionNode parent=p.getParentId()==null?null:nodes.get(p.getParentId());if(parent==null)roots.add(node);else parent.children().add(node);}
        return roots;
    }
    @Transactional public PermissionView createPermission(PermissionRequest req){if(permissions.selectCount(Wrappers.<SysPermission>lambdaQuery().eq(SysPermission::getPermissionCode,req.permissionCode()))>0)throw new BizException(ErrorCode.CONFLICT,"权限编码已存在");SysPermission p=new SysPermission();apply(p,req);p.setDeleted(0);permissions.insert(p);return view(p);}
    @Transactional public PermissionView updatePermission(Long id,PermissionRequest req){SysPermission p=requirePermission(id);apply(p,req);permissions.updateById(p);return view(p);}
    @Transactional public void deletePermission(Long id){requirePermission(id);rolePermissions.delete(Wrappers.<SysRolePermission>lambdaQuery().eq(SysRolePermission::getPermissionId,id));permissions.deleteById(id);}

    private SysUser requireUser(Long id){SysUser u=users.selectById(id);if(u==null)throw new BizException(ErrorCode.NOT_FOUND,"用户不存在");return u;}
    private SysRole requireRole(Long id){SysRole r=roles.selectById(id);if(r==null)throw new BizException(ErrorCode.NOT_FOUND,"角色不存在");return r;}
    private SysPermission requirePermission(Long id){SysPermission p=permissions.selectById(id);if(p==null)throw new BizException(ErrorCode.NOT_FOUND,"权限不存在");return p;}
    private List<SysPermission> permissionEntities(){return permissions.selectList(Wrappers.<SysPermission>lambdaQuery().orderByAsc(SysPermission::getSortOrder));}
    private UserSummary summary(SysUser u){return new UserSummary(String.valueOf(u.getId()),u.getUsername(),u.getRealName(),u.getStatus());}
    private String normalStatus(String s){return s==null||s.isBlank()?"ENABLED":s;}
    private void apply(SysRole r,RoleRequest q){r.setRoleCode(q.roleCode());r.setRoleName(q.roleName());r.setDescription(q.description());r.setStatus(normalStatus(q.status()));}
    private void apply(SysPermission p,PermissionRequest q){p.setParentId(q.parentId());p.setPermissionCode(q.permissionCode());p.setPermissionName(q.permissionName());p.setPermissionType(q.permissionType());p.setRoutePath(q.routePath());p.setApiPath(q.apiPath());p.setHttpMethod(q.httpMethod());p.setSortOrder(q.sortOrder());p.setStatus(normalStatus(q.status()));}
    private RoleView view(SysRole r){return new RoleView(String.valueOf(r.getId()),r.getRoleCode(),r.getRoleName(),r.getDescription(),r.getStatus());}
    private PermissionView view(SysPermission p){return new PermissionView(String.valueOf(p.getId()),p.getParentId()==null?null:String.valueOf(p.getParentId()),p.getPermissionCode(),p.getPermissionName(),p.getPermissionType(),p.getRoutePath(),p.getApiPath(),p.getHttpMethod(),p.getSortOrder(),p.getStatus());}
}
