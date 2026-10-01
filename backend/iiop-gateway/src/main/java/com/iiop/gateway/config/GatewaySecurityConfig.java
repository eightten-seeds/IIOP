package com.iiop.gateway.config;

import cn.dev33.satoken.context.SaHolder;
import cn.dev33.satoken.reactor.filter.SaReactorFilter;
import cn.dev33.satoken.router.SaRouter;
import cn.dev33.satoken.stp.StpUtil;
import cn.dev33.satoken.exception.NotPermissionException;
import cn.dev33.satoken.exception.NotRoleException;
import cn.dev33.satoken.util.SaResult;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.beans.factory.annotation.Value;

import java.util.Arrays;
import java.util.Set;
import java.util.stream.Collectors;

@Configuration
public class GatewaySecurityConfig {
    @Value("${IIOP_CORS_ORIGINS:http://localhost:5173,http://127.0.0.1:5173}")
    private String corsOrigins;
    @Bean
    SaReactorFilter saReactorFilter() {
        return new SaReactorFilter()
                .addInclude("/api/**", "/ws/**")
                .setAuth(obj -> SaRouter.match("/api/**")
                        .notMatch("/api/auth/login", "/api/auth/captcha")
                        .notMatchMethod("OPTIONS")
                        .check(StpUtil::checkLogin))
                .setError(error -> {
                    String origin = SaHolder.getRequest().getHeader("Origin");
                    Set<String> allowedOrigins = Arrays.stream(corsOrigins.split(","))
                            .map(String::trim).filter(value -> !value.isEmpty()).collect(Collectors.toSet());
                    if (origin != null && (allowedOrigins.contains(origin) || allowedOrigins.contains("*"))) {
                        SaHolder.getResponse().setHeader("Access-Control-Allow-Origin", origin);
                        SaHolder.getResponse().setHeader("Access-Control-Allow-Credentials", "true");
                        SaHolder.getResponse().setHeader("Access-Control-Allow-Headers", "*");
                        SaHolder.getResponse().setHeader("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS");
                        SaHolder.getResponse().setHeader("Vary", "Origin");
                    }
                    int status = 401;
                    int code = 40100;
                    String message = "未登录或登录已失效";
                    if (error instanceof NotRoleException || error instanceof NotPermissionException) {
                        status = 403;
                        code = 40300;
                        message = "无权访问该资源";
                    }
                    SaHolder.getResponse().setStatus(status);
                    return SaResult.error(message).setCode(code);
                });
    }
}
