package com.iiop.ai.workflow;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.iiop.ai.domain.AiDtos.ModelResult;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;
class AiWorkflowTest {
 @Test void highestRiskWins(){assertEquals("HIGH",AiWorkflow.maxRisk("HIGH","MEDIUM"));assertEquals("CRITICAL",AiWorkflow.maxRisk("CRITICAL","LOW"));}
 @Test void invalidModelJsonFails(){assertThrows(Exception.class,()->new ObjectMapper().readValue("not-json",ModelResult.class));}
}
