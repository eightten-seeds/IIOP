package com.iiop.auth.domain.dto;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
public record PermissionRequest(Long parentId, @NotBlank String permissionCode, @NotBlank String permissionName,
        @NotBlank String permissionType, String routePath, String apiPath, String httpMethod,
        @NotNull Integer sortOrder, String status) { }
