package com.iiop.gateway.filter;

import com.alibaba.csp.sentinel.Entry;
import com.alibaba.csp.sentinel.SphU;
import com.alibaba.csp.sentinel.slots.block.BlockException;
import com.alibaba.csp.sentinel.slots.block.RuleConstant;
import com.alibaba.csp.sentinel.slots.block.flow.FlowRule;
import com.alibaba.csp.sentinel.slots.block.flow.FlowRuleManager;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.iiop.common.api.ErrorCode;
import com.iiop.common.api.Result;
import com.iiop.common.trace.TraceContext;
import java.util.List;
import org.springframework.cloud.gateway.filter.GatewayFilterChain;
import org.springframework.cloud.gateway.filter.GlobalFilter;
import org.springframework.core.Ordered;
import org.springframework.core.io.buffer.DataBuffer;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.web.server.ServerWebExchange;
import reactor.core.publisher.Mono;

@Component
public class LoginRateLimitFilter implements GlobalFilter, Ordered {
    static final String RESOURCE_LOGIN="gateway-login";
    static final String RESOURCE_CAPTCHA="gateway-captcha";
    private final ObjectMapper objectMapper;
    public LoginRateLimitFilter(ObjectMapper objectMapper){
        this.objectMapper=objectMapper;
        FlowRule loginRule=new FlowRule(RESOURCE_LOGIN);loginRule.setGrade(RuleConstant.FLOW_GRADE_QPS);loginRule.setCount(2);
        FlowRule captchaRule=new FlowRule(RESOURCE_CAPTCHA);captchaRule.setGrade(RuleConstant.FLOW_GRADE_QPS);captchaRule.setCount(5);
        FlowRuleManager.loadRules(List.of(loginRule, captchaRule));
    }
    @Override public Mono<Void> filter(ServerWebExchange exchange,GatewayFilterChain chain){
        String path = exchange.getRequest().getPath().value();
        HttpMethod method = exchange.getRequest().getMethod();
        String resource = null;
        if(method == HttpMethod.POST && "/api/auth/login".equals(path)) resource = RESOURCE_LOGIN;
        else if(method == HttpMethod.GET && "/api/auth/captcha".equals(path)) resource = RESOURCE_CAPTCHA;
        if(resource == null) return chain.filter(exchange);

        Entry entry;
        try{entry=SphU.entry(resource);}catch(BlockException ex){return blocked(exchange);}
        return chain.filter(exchange).doFinally(signal->entry.exit());
    }
    private Mono<Void> blocked(ServerWebExchange exchange){
        exchange.getResponse().setStatusCode(HttpStatus.TOO_MANY_REQUESTS);exchange.getResponse().getHeaders().setContentType(MediaType.APPLICATION_JSON);
        String trace=exchange.getRequest().getHeaders().getFirst("X-Request-Id");TraceContext.setTraceId(trace);
        try{byte[] body=objectMapper.writeValueAsBytes(Result.failure(ErrorCode.TOO_MANY_REQUESTS,ErrorCode.TOO_MANY_REQUESTS.getMessage()));DataBuffer buffer=exchange.getResponse().bufferFactory().wrap(body);return exchange.getResponse().writeWith(Mono.just(buffer));}
        catch(Exception ex){return exchange.getResponse().setComplete();}finally{TraceContext.clear();}
    }
    @Override public int getOrder(){return -90;}
}
