package com.iiop.maintenance.config;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.iiop.common.mq.InspectionAbnormalEvent;
import com.iiop.maintenance.service.MaintenanceService;
import java.time.LocalDateTime;
import java.util.function.Consumer;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

class MqConsumerConfigTest {

    @Test
    void propagatesProcessingFailureToBinder() {
        MaintenanceService maintenanceService = mock(MaintenanceService.class);
        doThrow(new RuntimeException("db unavailable"))
                .when(maintenanceService).consumeAbnormal(any(InspectionAbnormalEvent.class));

        Consumer<Object> consumer = new MqConsumerConfig()
                .abnormalEvent(maintenanceService, new ObjectMapper());

        InspectionAbnormalEvent event = new InspectionAbnormalEvent(
                "event-1", 1L, 2L, "HIGH", "temperature abnormal", LocalDateTime.now());

        assertThrows(IllegalStateException.class, () -> consumer.accept(event));
    }
}
