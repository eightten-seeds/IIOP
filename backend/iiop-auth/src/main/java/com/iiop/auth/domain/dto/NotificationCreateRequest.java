package com.iiop.auth.domain.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

public record NotificationCreateRequest(
        @NotNull Long recipientUserId,
        @NotBlank String notificationType,
        @NotBlank String title,
        @NotBlank String content,
        String bizType,
        Long bizId) {
}
