package com.iiop.auth.config;

import cn.dev33.satoken.stp.StpUtil;
import com.iiop.auth.service.NotificationWebSocketHandler;
import java.util.Map;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpStatus;
import org.springframework.http.server.ServerHttpRequest;
import org.springframework.http.server.ServerHttpResponse;
import org.springframework.util.MultiValueMap;
import org.springframework.web.socket.WebSocketHandler;
import org.springframework.web.socket.config.annotation.EnableWebSocket;
import org.springframework.web.socket.config.annotation.WebSocketConfigurer;
import org.springframework.web.socket.config.annotation.WebSocketHandlerRegistry;
import org.springframework.web.socket.server.HandshakeInterceptor;
import org.springframework.web.util.UriComponentsBuilder;

@Configuration @EnableWebSocket
public class WebSocketConfig implements WebSocketConfigurer {
    private final NotificationWebSocketHandler handler;
    public WebSocketConfig(NotificationWebSocketHandler handler){this.handler=handler;}
    @Override public void registerWebSocketHandlers(WebSocketHandlerRegistry registry){
        registry.addHandler(handler,"/ws/notifications").addInterceptors(new TokenHandshakeInterceptor()).setAllowedOriginPatterns("*");
    }
    static class TokenHandshakeInterceptor implements HandshakeInterceptor {
        @Override public boolean beforeHandshake(ServerHttpRequest request,ServerHttpResponse response,WebSocketHandler wsHandler,Map<String,Object> attributes){
            MultiValueMap<String,String> query=UriComponentsBuilder.fromUri(request.getURI()).build().getQueryParams();
            String token=query.getFirst("token"); Object loginId=token==null?null:StpUtil.getLoginIdByToken(token);
            if(loginId==null){response.setStatusCode(HttpStatus.UNAUTHORIZED);return false;}
            attributes.put(NotificationWebSocketHandler.USER_ID,Long.valueOf(String.valueOf(loginId)));return true;
        }
        @Override public void afterHandshake(ServerHttpRequest request,ServerHttpResponse response,WebSocketHandler wsHandler,Exception exception){}
    }
}
