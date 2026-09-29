package com.iiop.gateway.filter;

import com.iiop.common.constant.HeaderConstants;
import java.util.UUID;
import org.springframework.cloud.gateway.filter.GatewayFilterChain;
import org.springframework.cloud.gateway.filter.GlobalFilter;
import org.springframework.core.Ordered;
import org.springframework.http.server.reactive.ServerHttpRequest;
import org.springframework.stereotype.Component;
import org.springframework.web.server.ServerWebExchange;
import reactor.core.publisher.Mono;

@Component
public class RequestContextFilter implements GlobalFilter, Ordered {
    @Override public Mono<Void> filter(ServerWebExchange exchange, GatewayFilterChain chain) {
        String requestId=exchange.getRequest().getHeaders().getFirst(HeaderConstants.REQUEST_ID);
        if(requestId==null||requestId.isBlank())requestId=UUID.randomUUID().toString();
        String finalRequestId=requestId;
        ServerHttpRequest request=exchange.getRequest().mutate().headers(headers->{
            headers.set(HeaderConstants.REQUEST_ID,finalRequestId);
            headers.set(HeaderConstants.TRACE_ID,finalRequestId);
        }).build();
        exchange.getResponse().getHeaders().set(HeaderConstants.REQUEST_ID,finalRequestId);
        exchange.getResponse().getHeaders().set(HeaderConstants.TRACE_ID,finalRequestId);
        return chain.filter(exchange.mutate().request(request).build());
    }
    @Override public int getOrder(){return Ordered.HIGHEST_PRECEDENCE+100;}
}
