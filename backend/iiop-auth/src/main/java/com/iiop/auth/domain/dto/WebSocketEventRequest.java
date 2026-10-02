package com.iiop.auth.domain.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

public record WebSocketEventRequest(
        @NotNull Long recipientUserId,
        @NotBlank String eventType,
        @NotBlank String title,
        @NotBlank String content,
        @NotBlank String bizType,
        @NotNull Long bizId) { }
