package com.iiop.auth.domain.dto;
import jakarta.validation.constraints.NotBlank;
public record RoleRequest(@NotBlank String roleCode, @NotBlank String roleName, String description, String status) { }
