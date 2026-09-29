package com.iiop.auth.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.iiop.auth.domain.dto.NotificationView;
import java.io.IOException;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.CloseStatus;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketSession;
import org.springframework.web.socket.handler.TextWebSocketHandler;

@Component
public class NotificationWebSocketHandler extends TextWebSocketHandler {
    public static final String USER_ID = "userId";
    private final Map<Long,WebSocketSession> sessions=new ConcurrentHashMap<>();
    private final ObjectMapper objectMapper;
    public NotificationWebSocketHandler(ObjectMapper objectMapper){this.objectMapper=objectMapper;}
    @Override public void afterConnectionEstablished(WebSocketSession session){sessions.put((Long)session.getAttributes().get(USER_ID),session);}
    @Override public void afterConnectionClosed(WebSocketSession session, CloseStatus status){sessions.remove((Long)session.getAttributes().get(USER_ID),session);}
    public void push(Long userId, NotificationView notification){
        WebSocketSession session=sessions.get(userId); if(session==null||!session.isOpen())return;
        try{session.sendMessage(new TextMessage(objectMapper.writeValueAsString(notification)));}catch(IOException ex){try{session.close();}catch(IOException ignored){}sessions.remove(userId,session);}
    }
}
