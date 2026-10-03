package com.iiop.maintenance.config;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.iiop.common.mq.InspectionAbnormalEvent;
import com.iiop.maintenance.service.MaintenanceService;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.Map;
import java.util.Objects;
import java.util.function.Consumer;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class MqConsumerConfig {

    private static final Logger log = LoggerFactory.getLogger(MqConsumerConfig.class);

    @Bean
    public Consumer<Object> abnormalEvent(MaintenanceService maintenanceService, ObjectMapper objectMapper) {
        return payload -> {
            try {
                InspectionAbnormalEvent event = null;
                if (payload instanceof InspectionAbnormalEvent e) {
                    event = e;
                } else if (payload instanceof Map<?, ?> map) {
                    String eventId = Objects.toString(map.get("eventId"), null);
                    Long abnormalId = map.get("abnormalId") != null ? Long.valueOf(map.get("abnormalId").toString()) : null;
                    Long deviceId = map.get("deviceId") != null ? Long.valueOf(map.get("deviceId").toString()) : null;
                    String severity = Objects.toString(map.get("severity"), null);
                    String title = Objects.toString(map.get("title"), null);
                    LocalDateTime occurredAt = LocalDateTime.now();
                    Object occ = map.get("occurredAt");
                    if (occ != null) {
                        try {
                            if (occ instanceof Number num) {
                                occurredAt = LocalDateTime.ofInstant(Instant.ofEpochMilli(num.longValue()), ZoneId.systemDefault());
                            } else {
                                String s = occ.toString();
                                if (s.matches("^\\d+$")) {
                                    occurredAt = LocalDateTime.ofInstant(Instant.ofEpochMilli(Long.parseLong(s)), ZoneId.systemDefault());
                                } else {
                                    occurredAt = LocalDateTime.parse(s);
                                }
                            }
                        } catch (Exception ignored) {
                        }
                    }
                    event = new InspectionAbnormalEvent(eventId, abnormalId, deviceId, severity, title, occurredAt);
                } else {
                    String json = payload instanceof byte[] b ? new String(b, StandardCharsets.UTF_8) : payload.toString();
                    JsonNode node = objectMapper.readTree(json);
                    String eventId = node.hasNonNull("eventId") ? node.get("eventId").asText() : null;
                    Long abnormalId = node.hasNonNull("abnormalId") ? node.get("abnormalId").asLong() : null;
                    Long deviceId = node.hasNonNull("deviceId") ? node.get("deviceId").asLong() : null;
                    String severity = node.hasNonNull("severity") ? node.get("severity").asText() : null;
                    String title = node.hasNonNull("title") ? node.get("title").asText() : null;
                    LocalDateTime occurredAt = LocalDateTime.now();
                    if (node.hasNonNull("occurredAt")) {
                        try {
                            JsonNode occNode = node.get("occurredAt");
                            if (occNode.isNumber()) {
                                occurredAt = LocalDateTime.ofInstant(Instant.ofEpochMilli(occNode.asLong()), ZoneId.systemDefault());
                            } else {
                                String s = occNode.asText();
                                if (s.matches("^\\d+$")) {
                                    occurredAt = LocalDateTime.ofInstant(Instant.ofEpochMilli(Long.parseLong(s)), ZoneId.systemDefault());
                                } else {
                                    occurredAt = LocalDateTime.parse(s);
                                }
                            }
                        } catch (Exception ignored) {
                        }
                    }
                    event = new InspectionAbnormalEvent(eventId, abnormalId, deviceId, severity, title, occurredAt);
                }
                if (event != null) {
                    maintenanceService.consumeAbnormal(event);
                }
            } catch (Exception ex) {
                log.error("Failed to deserialize or process InspectionAbnormalEvent: {}", payload, ex);
                throw new IllegalStateException("InspectionAbnormalEvent processing failed", ex);
            }
        };
    }
}
