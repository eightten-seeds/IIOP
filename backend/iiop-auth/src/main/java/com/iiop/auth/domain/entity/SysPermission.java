package com.iiop.auth.domain.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableLogic;
import com.baomidou.mybatisplus.annotation.TableName;
import java.time.LocalDateTime;

@TableName("sys_permission")
public class SysPermission {
    @TableId(type=IdType.ASSIGN_ID) private Long id;
    private Long parentId; private String permissionCode; private String permissionName; private String permissionType;
    private String routePath; private String apiPath; private String httpMethod; private Integer sortOrder; private String status;
    private LocalDateTime createdAt; private LocalDateTime updatedAt; @TableLogic private Integer deleted;
    public Long getId(){return id;} public void setId(Long v){id=v;} public Long getParentId(){return parentId;} public void setParentId(Long v){parentId=v;}
    public String getPermissionCode(){return permissionCode;} public void setPermissionCode(String v){permissionCode=v;} public String getPermissionName(){return permissionName;} public void setPermissionName(String v){permissionName=v;}
    public String getPermissionType(){return permissionType;} public void setPermissionType(String v){permissionType=v;} public String getRoutePath(){return routePath;} public void setRoutePath(String v){routePath=v;}
    public String getApiPath(){return apiPath;} public void setApiPath(String v){apiPath=v;} public String getHttpMethod(){return httpMethod;} public void setHttpMethod(String v){httpMethod=v;}
    public Integer getSortOrder(){return sortOrder;} public void setSortOrder(Integer v){sortOrder=v;} public String getStatus(){return status;} public void setStatus(String v){status=v;}
    public LocalDateTime getCreatedAt(){return createdAt;} public void setCreatedAt(LocalDateTime v){createdAt=v;} public LocalDateTime getUpdatedAt(){return updatedAt;} public void setUpdatedAt(LocalDateTime v){updatedAt=v;}
    public Integer getDeleted(){return deleted;} public void setDeleted(Integer v){deleted=v;}
}
