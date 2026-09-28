package com.iiop.auth.domain.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableLogic;
import com.baomidou.mybatisplus.annotation.TableName;
import java.time.LocalDateTime;

@TableName("sys_role")
public class SysRole {
    @TableId(type=IdType.ASSIGN_ID) private Long id;
    private String roleCode; private String roleName; private String description; private String status;
    private LocalDateTime createdAt; private LocalDateTime updatedAt; @TableLogic private Integer deleted;
    public Long getId(){return id;} public void setId(Long v){id=v;} public String getRoleCode(){return roleCode;} public void setRoleCode(String v){roleCode=v;}
    public String getRoleName(){return roleName;} public void setRoleName(String v){roleName=v;} public String getDescription(){return description;} public void setDescription(String v){description=v;}
    public String getStatus(){return status;} public void setStatus(String v){status=v;} public LocalDateTime getCreatedAt(){return createdAt;} public void setCreatedAt(LocalDateTime v){createdAt=v;}
    public LocalDateTime getUpdatedAt(){return updatedAt;} public void setUpdatedAt(LocalDateTime v){updatedAt=v;} public Integer getDeleted(){return deleted;} public void setDeleted(Integer v){deleted=v;}
}
