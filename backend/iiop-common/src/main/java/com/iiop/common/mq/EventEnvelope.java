package com.iiop.common.mq;

import java.time.LocalDateTime;

public record EventEnvelope<T>(
        String eventId,
        String eventType,
        LocalDateTime occurredAt,
        String source,
        String traceId,
        T payload) {
}
