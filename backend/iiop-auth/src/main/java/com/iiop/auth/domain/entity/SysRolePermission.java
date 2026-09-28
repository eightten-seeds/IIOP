package com.iiop.auth.domain.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import java.time.LocalDateTime;

@TableName("sys_role_permission")
public class SysRolePermission {
    @TableId(type=IdType.ASSIGN_ID) private Long id; private Long roleId; private Long permissionId; private LocalDateTime createdAt;
    public Long getId(){return id;} public void setId(Long v){id=v;} public Long getRoleId(){return roleId;} public void setRoleId(Long v){roleId=v;}
    public Long getPermissionId(){return permissionId;} public void setPermissionId(Long v){permissionId=v;} public LocalDateTime getCreatedAt(){return createdAt;} public void setCreatedAt(LocalDateTime v){createdAt=v;}
}
