package com.iiop.maintenance.config;

import com.iiop.common.mq.InspectionAbnormalEvent;
import com.iiop.maintenance.service.MaintenanceService;
import java.util.function.Consumer;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class MqConsumerConfig {

    @Bean
    public Consumer<InspectionAbnormalEvent> abnormalEvent(MaintenanceService maintenanceService) {
        return maintenanceService::consumeAbnormal;
    }
}
