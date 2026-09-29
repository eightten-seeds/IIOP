package com.iiop.ai.workflow;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.iiop.ai.domain.AiDtos.ModelResult;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;
class AiWorkflowTest {
 @Test void highestRiskWins(){assertEquals("HIGH",AiWorkflow.maxRisk("HIGH","MEDIUM"));assertEquals("CRITICAL",AiWorkflow.maxRisk("CRITICAL","LOW"));}
 @Test void draftPriorityAndConfirmationFollowJavaRules(){assertEquals("URGENT",AiWorkflow.priorityFor("CRITICAL"));assertTrue(AiWorkflow.requiresConfirmation("HIGH"));assertTrue(AiWorkflow.requiresConfirmation("CRITICAL"));assertFalse(AiWorkflow.requiresConfirmation("LOW"));}
 @Test void workflowOrderIsFixed(){assertEquals(java.util.List.of("LOAD_CONTEXT","ANALYZE_WITH_DEEPSEEK","RISK_CHECK","GENERATE_ADVICE","PREPARE_WORK_ORDER_DRAFT"),com.iiop.ai.service.AiPersistenceService.NODES);}
 @Test void invalidModelJsonFails(){assertThrows(Exception.class,()->new ObjectMapper().readValue("not-json",ModelResult.class));}
}
