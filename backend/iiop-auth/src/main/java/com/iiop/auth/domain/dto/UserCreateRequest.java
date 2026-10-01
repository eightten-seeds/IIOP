package com.iiop.auth.domain.dto;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
public record UserCreateRequest(@NotBlank String username,
        @NotBlank @Size(min = 8, max = 72, message = "密码长度必须为 8~72 位") String password,
        String realName, String phone, String email, String avatarUrl, String status) { }
