package com.iiop.ai.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.iiop.ai.client.AiClients.AuthClient;
import com.iiop.ai.client.AiClients.WebSocketEventRequest;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import org.springframework.stereotype.Service;

@Service
public class AiWorkflowEventPublisher {
    private final AuthClient auth;
    private final ObjectMapper json;
    private final Map<Long,Long> recipients=new ConcurrentHashMap<>();

    public AiWorkflowEventPublisher(AuthClient auth,ObjectMapper json){this.auth=auth;this.json=json;}
    public void begin(Long diagnosisId,Long userId){recipients.put(diagnosisId,userId);}
    public void end(Long diagnosisId){recipients.remove(diagnosisId);}
    public void publish(Long diagnosisId,String taskStatus,String nodeCode,String nodeStatus,String message){
        Long userId=recipients.get(diagnosisId);if(userId==null)return;
        try{
            Map<String,Object> body=new LinkedHashMap<>();body.put("diagnosisId",String.valueOf(diagnosisId));body.put("taskStatus",taskStatus);body.put("nodeCode",nodeCode);body.put("nodeStatus",nodeStatus);body.put("message",message);
            auth.websocketEvent(new WebSocketEventRequest(userId,"AI_WORKFLOW","AI 诊断进度",json.writeValueAsString(body),"AI_DIAGNOSIS",diagnosisId));
        }catch(Exception ignored){/* WebSocket 通知失败不能改变已持久化的工作流状态。 */}
    }
}
