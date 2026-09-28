package com.iiop.auth.domain.dto;
public record PermissionView(String id,String parentId,String permissionCode,String permissionName,String permissionType,
        String routePath,String apiPath,String httpMethod,Integer sortOrder,String status) { }
