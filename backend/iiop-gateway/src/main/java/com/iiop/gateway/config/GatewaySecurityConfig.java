package com.iiop.gateway.config;

import cn.dev33.satoken.context.SaHolder;
import cn.dev33.satoken.reactor.filter.SaReactorFilter;
import cn.dev33.satoken.router.SaRouter;
import cn.dev33.satoken.stp.StpUtil;
import cn.dev33.satoken.util.SaResult;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class GatewaySecurityConfig {
    @Bean
    SaReactorFilter saReactorFilter() {
        return new SaReactorFilter()
                .addInclude("/api/**", "/ws/**")
                .setAuth(obj -> SaRouter.match("/api/**")
                        .notMatch("/api/auth/login", "/api/auth/captcha")
                        .notMatchMethod("OPTIONS")
                        .check(StpUtil::checkLogin))
                .setError(error -> {
                    SaHolder.getResponse().setStatus(401);
                    return SaResult.error("未登录或登录已失效").setCode(40100);
                });
    }
}
