package com.iiop.inspection.service;

import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

@Component
public class InspectionScheduler {
    private static final Logger log=LoggerFactory.getLogger(InspectionScheduler.class);
    private final InspectionService service;

    public InspectionScheduler(InspectionService service){this.service=service;}

    @Scheduled(fixedDelayString="${iiop.inspection.scheduler-delay-ms:30000}")
    public void generateDueTasks(){
        service.refreshOverdueFlags();
        service.initializeMissingSchedules();
        List<Long> due=service.duePlanIds();
        for(Long planId:due){
            try{for(int generated=0;generated<100&&service.isPlanDue(planId);generated++)service.generateScheduled(planId);}
            catch(Exception e){log.error("巡检计划自动生成失败 planId={}",planId,e);}
        }
    }
}
