package com.iiop.auth.domain.dto;
import java.time.LocalDateTime;
public record NotificationView(String id,String notificationType,String title,String content,String bizType,String bizId,
        String readStatus,LocalDateTime readTime,LocalDateTime createdAt) { }
