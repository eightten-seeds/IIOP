package com.iiop.auth.domain.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import java.time.LocalDateTime;

@TableName("sys_user_role")
public class SysUserRole {
    @TableId(type=IdType.ASSIGN_ID) private Long id; private Long userId; private Long roleId; private LocalDateTime createdAt;
    public Long getId(){return id;} public void setId(Long v){id=v;} public Long getUserId(){return userId;} public void setUserId(Long v){userId=v;}
    public Long getRoleId(){return roleId;} public void setRoleId(Long v){roleId=v;} public LocalDateTime getCreatedAt(){return createdAt;} public void setCreatedAt(LocalDateTime v){createdAt=v;}
}
