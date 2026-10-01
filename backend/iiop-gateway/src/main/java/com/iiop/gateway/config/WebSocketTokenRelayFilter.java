package com.iiop.gateway.config;

import java.util.List;
import org.springframework.cloud.gateway.filter.GatewayFilterChain;
import org.springframework.cloud.gateway.filter.GlobalFilter;
import org.springframework.core.Ordered;
import org.springframework.http.server.reactive.ServerHttpRequest;
import org.springframework.stereotype.Component;
import org.springframework.web.server.ServerWebExchange;
import reactor.core.publisher.Mono;

/** Relays the browser WebSocket query token as Sa-Token's standard header. */
@Component
public class WebSocketTokenRelayFilter implements GlobalFilter, Ordered {
    @Override
    public Mono<Void> filter(ServerWebExchange exchange, GatewayFilterChain chain) {
        ServerHttpRequest request = exchange.getRequest();
        if (!request.getURI().getPath().startsWith("/ws/")) {
            return chain.filter(exchange);
        }
        List<String> tokens = request.getQueryParams().get("token");
        String token = tokens == null || tokens.isEmpty() ? null : tokens.get(0);
        if (token == null || token.isBlank()) {
            return chain.filter(exchange);
        }
        ServerHttpRequest relayed = request.mutate().headers(headers -> headers.set("satoken", token)).build();
        return chain.filter(exchange.mutate().request(relayed).build());
    }

    @Override
    public int getOrder() {
        return Ordered.HIGHEST_PRECEDENCE;
    }
}
