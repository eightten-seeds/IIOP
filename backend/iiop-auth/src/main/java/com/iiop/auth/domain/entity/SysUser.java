package com.iiop.auth.domain.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableLogic;
import com.baomidou.mybatisplus.annotation.TableName;
import java.time.LocalDateTime;

@TableName("sys_user")
public class SysUser {
    @TableId(type = IdType.ASSIGN_ID) private Long id;
    private String username;
    private String passwordHash;
    private String realName;
    private String phone;
    private String email;
    private String avatarUrl;
    private String status;
    private LocalDateTime lastLoginTime;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
    @TableLogic private Integer deleted;
    public Long getId(){return id;} public void setId(Long v){id=v;}
    public String getUsername(){return username;} public void setUsername(String v){username=v;}
    public String getPasswordHash(){return passwordHash;} public void setPasswordHash(String v){passwordHash=v;}
    public String getRealName(){return realName;} public void setRealName(String v){realName=v;}
    public String getPhone(){return phone;} public void setPhone(String v){phone=v;}
    public String getEmail(){return email;} public void setEmail(String v){email=v;}
    public String getAvatarUrl(){return avatarUrl;} public void setAvatarUrl(String v){avatarUrl=v;}
    public String getStatus(){return status;} public void setStatus(String v){status=v;}
    public LocalDateTime getLastLoginTime(){return lastLoginTime;} public void setLastLoginTime(LocalDateTime v){lastLoginTime=v;}
    public LocalDateTime getCreatedAt(){return createdAt;} public void setCreatedAt(LocalDateTime v){createdAt=v;}
    public LocalDateTime getUpdatedAt(){return updatedAt;} public void setUpdatedAt(LocalDateTime v){updatedAt=v;}
    public Integer getDeleted(){return deleted;} public void setDeleted(Integer v){deleted=v;}
}
