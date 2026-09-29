package com.iiop.device.config;

import cn.dev33.satoken.dao.SaTokenDao;
import cn.dev33.satoken.dao.SaTokenDaoForRedisTemplate;
import cn.dev33.satoken.interceptor.SaInterceptor;
import cn.dev33.satoken.session.SaSession;
import cn.dev33.satoken.stp.StpInterface;
import cn.dev33.satoken.stp.StpUtil;
import com.baomidou.mybatisplus.annotation.DbType;
import com.baomidou.mybatisplus.extension.plugins.MybatisPlusInterceptor;
import com.baomidou.mybatisplus.extension.plugins.inner.PaginationInnerInterceptor;
import java.util.List;
import java.util.concurrent.TimeUnit;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Primary;
import org.springframework.data.redis.connection.RedisConnectionFactory;
import org.springframework.web.servlet.config.annotation.InterceptorRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;
import org.springframework.boot.autoconfigure.jackson.Jackson2ObjectMapperBuilderCustomizer;
import com.fasterxml.jackson.databind.ser.std.ToStringSerializer;

@Configuration
public class DeviceConfig implements WebMvcConfigurer {
    @Override public void addInterceptors(InterceptorRegistry registry){registry.addInterceptor(new SaInterceptor()).addPathPatterns("/**");}
    @Bean MybatisPlusInterceptor pagination(){MybatisPlusInterceptor value=new MybatisPlusInterceptor();value.addInnerInterceptor(new PaginationInnerInterceptor(DbType.MYSQL));return value;}
    @Bean Jackson2ObjectMapperBuilderCustomizer longAsString(){return builder->builder.serializerByType(Long.class,ToStringSerializer.instance).serializerByType(Long.TYPE,ToStringSerializer.instance);}
    @Bean StpInterface permissions(){return new StpInterface(){
        @Override public List<String> getPermissionList(Object id,String type){return values(id,"iiop:permissions");}
        @Override public List<String> getRoleList(Object id,String type){return values(id,"iiop:roles");}
        private List<String> values(Object id,String key){SaSession session=StpUtil.getSessionByLoginId(id,false);Object value=session==null?null:session.get(key);return value instanceof List<?> list?list.stream().map(String::valueOf).toList():List.of();}
    };}
    @Bean @Primary SaTokenDao saTokenDao(RedisConnectionFactory factory){Redis5Dao dao=new Redis5Dao();dao.init(factory);return dao;}
    static class Redis5Dao extends SaTokenDaoForRedisTemplate {
        @Override public void setStringAndKeepTTL(String key,String value){String wrapped=wrapKey(key);Long timeout=stringRedisTemplate.getExpire(wrapped,TimeUnit.SECONDS);if(timeout==null||timeout==-2)return;if(timeout<0)stringRedisTemplate.opsForValue().set(wrapped,value);else stringRedisTemplate.opsForValue().set(wrapped,value,timeout,TimeUnit.SECONDS);}
    }
}
