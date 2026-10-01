package com.iiop.auth.domain.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record ChangePasswordRequest(
    @NotBlank(message = "原密码不能为空") String oldPassword,
    @NotBlank(message = "新密码不能为空") @Size(min = 8, max = 72, message = "密码长度必须为 8~72 位") String newPassword
) { }
