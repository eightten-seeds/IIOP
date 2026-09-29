package com.iiop.ai.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.iiop.ai.domain.AiDtos.ModelResult;
import dev.langchain4j.data.message.*;
import dev.langchain4j.model.chat.response.ChatResponse;
import dev.langchain4j.model.openai.OpenAiChatModel;
import java.time.Duration;
import java.util.List;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

@Service public class DeepSeekDiagnosisClient {
 private final ObjectMapper json; private final String key,baseUrl,model;
 public DeepSeekDiagnosisClient(ObjectMapper json,@Value("${iiop.ai.deepseek.api-key:}") String key,@Value("${iiop.ai.deepseek.base-url:https://api.deepseek.com/v1}") String baseUrl,@Value("${iiop.ai.deepseek.model:deepseek-flash}") String model){this.json=json;this.key=key;this.baseUrl=baseUrl;this.model=model;}
 public ModelResult diagnose(String context){if(key==null||key.isBlank())throw new IllegalStateException("DEEPSEEK_API_KEY 未配置");OpenAiChatModel chat=OpenAiChatModel.builder().apiKey(key).baseUrl(baseUrl).modelName(model).responseFormat("json_object").timeout(Duration.ofSeconds(60)).maxRetries(0).logRequests(false).logResponses(false).build();String system="你是工业设备巡检运维辅助诊断助手，只根据提供的上下文分析。只输出严格 JSON，不输出推理、reasoning_content、Markdown 或额外解释；不自动控制设备，不宣称已完成维修，高风险建议人工确认。输出示例：{\"riskLevel\":\"HIGH\",\"abnormalSummary\":\"...\",\"possibleCauses\":[\"...\"],\"investigationSteps\":[\"...\"],\"maintenanceAdvice\":\"...\",\"safetyNotice\":\"...\",\"humanConfirmationRequired\":true}。riskLevel 仅 LOW/MEDIUM/HIGH/CRITICAL，possibleCauses 和 investigationSteps 必须是数组。";RuntimeException last=null;for(int i=0;i<2;i++)try{ChatResponse response=chat.chat(List.of(SystemMessage.from(system),UserMessage.from(context)));return json.readValue(response.aiMessage().text(),ModelResult.class);}catch(Exception e){last=new IllegalStateException("DeepSeek 调用或 JSON 解析失败",e);}throw last;}
 public String model(){return model;}
}
