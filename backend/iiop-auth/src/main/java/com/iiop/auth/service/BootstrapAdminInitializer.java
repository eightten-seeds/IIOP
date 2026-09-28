package com.iiop.auth.service;

import com.baomidou.mybatisplus.core.toolkit.Wrappers;
import com.iiop.auth.domain.entity.SysRole;
import com.iiop.auth.domain.entity.SysUser;
import com.iiop.auth.domain.entity.SysUserRole;
import com.iiop.auth.mapper.SysRoleMapper;
import com.iiop.auth.mapper.SysUserMapper;
import com.iiop.auth.mapper.SysUserRoleMapper;
import java.time.LocalDateTime;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Profile;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

@Component @Profile("dev")
@ConditionalOnProperty(name="iiop.bootstrap-admin.enabled",havingValue="true")
public class BootstrapAdminInitializer implements ApplicationRunner {
    private final SysUserMapper users; private final SysRoleMapper roles; private final SysUserRoleMapper userRoles; private final PasswordEncoder encoder;
    @Value("${iiop.bootstrap-admin.username:}") private String username;
    @Value("${iiop.bootstrap-admin.password:}") private String password;
    public BootstrapAdminInitializer(SysUserMapper u,SysRoleMapper r,SysUserRoleMapper ur,PasswordEncoder e){users=u;roles=r;userRoles=ur;encoder=e;}
    @Override @Transactional public void run(ApplicationArguments args){
        if(username.isBlank()||password.length()<8) throw new IllegalStateException("Bootstrap Admin 环境变量缺失或密码长度不足");
        if(users.selectCount(Wrappers.<SysUser>lambdaQuery().eq(SysUser::getUsername,username))>0)return;
        SysRole role=roles.selectOne(Wrappers.<SysRole>lambdaQuery().eq(SysRole::getRoleCode,"SUPER_ADMIN"));
        if(role==null)throw new IllegalStateException("SUPER_ADMIN 角色不存在");
        SysUser user=new SysUser(); user.setUsername(username); user.setPasswordHash(encoder.encode(password)); user.setRealName("Bootstrap Admin"); user.setStatus("ENABLED"); user.setDeleted(0); users.insert(user);
        SysUserRole relation=new SysUserRole(); relation.setUserId(user.getId()); relation.setRoleId(role.getId()); relation.setCreatedAt(LocalDateTime.now()); userRoles.insert(relation);
    }
}
