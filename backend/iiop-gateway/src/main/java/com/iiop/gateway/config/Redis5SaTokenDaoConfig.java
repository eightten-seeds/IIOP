package com.iiop.gateway.config;

import cn.dev33.satoken.dao.SaTokenDao;
import cn.dev33.satoken.dao.SaTokenDaoForRedisTemplate;
import java.util.concurrent.TimeUnit;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Primary;
import org.springframework.data.redis.connection.RedisConnectionFactory;

@Configuration
public class Redis5SaTokenDaoConfig {
    @Bean @Primary
    SaTokenDao saTokenDao(RedisConnectionFactory factory) {
        Redis5CompatibleSaTokenDao dao = new Redis5CompatibleSaTokenDao();
        dao.init(factory);
        return dao;
    }

    static class Redis5CompatibleSaTokenDao extends SaTokenDaoForRedisTemplate {
        @Override public void setStringAndKeepTTL(String key,String value) {
            String wrapped=wrapKey(key);
            Long timeout=stringRedisTemplate.getExpire(wrapped,TimeUnit.SECONDS);
            if(timeout==null||timeout==-2)return;
            if(timeout<0)stringRedisTemplate.opsForValue().set(wrapped,value);
            else stringRedisTemplate.opsForValue().set(wrapped,value,timeout,TimeUnit.SECONDS);
        }
    }
}
