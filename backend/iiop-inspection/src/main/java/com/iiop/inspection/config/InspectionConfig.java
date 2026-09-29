package com.iiop.inspection.config;

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
import org.springframework.boot.autoconfigure.jackson.Jackson2ObjectMapperBuilderCustomizer;import com.fasterxml.jackson.databind.ser.std.ToStringSerializer;

@Configuration public class InspectionConfig implements WebMvcConfigurer {
    @Override public void addInterceptors(InterceptorRegistry r){r.addInterceptor(new SaInterceptor()).addPathPatterns("/**");}
    @Bean MybatisPlusInterceptor pagination(){MybatisPlusInterceptor v=new MybatisPlusInterceptor();v.addInnerInterceptor(new PaginationInnerInterceptor(DbType.MYSQL));return v;}
    @Bean Jackson2ObjectMapperBuilderCustomizer longAsString(){return b->b.serializerByType(Long.class,ToStringSerializer.instance).serializerByType(Long.TYPE,ToStringSerializer.instance);}
    @Bean StpInterface permissions(){return new StpInterface(){public List<String> getPermissionList(Object id,String t){return values(id,"iiop:permissions");}public List<String> getRoleList(Object id,String t){return values(id,"iiop:roles");}private List<String> values(Object id,String key){SaSession s=StpUtil.getSessionByLoginId(id,false);Object v=s==null?null:s.get(key);return v instanceof List<?> l?l.stream().map(String::valueOf).toList():List.of();}};}
    @Bean @Primary SaTokenDao saTokenDao(RedisConnectionFactory f){Redis5Dao d=new Redis5Dao();d.init(f);return d;}
    static class Redis5Dao extends SaTokenDaoForRedisTemplate{@Override public void setStringAndKeepTTL(String k,String v){String w=wrapKey(k);Long t=stringRedisTemplate.getExpire(w,TimeUnit.SECONDS);if(t==null||t==-2)return;if(t<0)stringRedisTemplate.opsForValue().set(w,v);else stringRedisTemplate.opsForValue().set(w,v,t,TimeUnit.SECONDS);}}
}
