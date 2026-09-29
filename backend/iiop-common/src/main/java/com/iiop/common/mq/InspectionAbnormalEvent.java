package com.iiop.common.mq;

import java.time.LocalDateTime;

public record InspectionAbnormalEvent(
        String eventId,
        Long abnormalId,
        Long deviceId,
        String severity,
        String title,
        LocalDateTime occurredAt) {
}
