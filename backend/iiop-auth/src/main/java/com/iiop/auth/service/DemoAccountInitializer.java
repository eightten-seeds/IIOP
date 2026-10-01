package com.iiop.auth.service;

import com.baomidou.mybatisplus.core.toolkit.Wrappers;
import com.iiop.auth.domain.entity.SysRole;
import com.iiop.auth.domain.entity.SysUser;
import com.iiop.auth.domain.entity.SysUserRole;
import com.iiop.auth.mapper.SysRoleMapper;
import com.iiop.auth.mapper.SysUserMapper;
import com.iiop.auth.mapper.SysUserRoleMapper;
import java.time.LocalDateTime;
import java.util.List;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Profile;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

@Component
@Profile("dev")
@ConditionalOnProperty(name = "iiop.demo-accounts.enabled", havingValue = "true")
public class DemoAccountInitializer implements ApplicationRunner {
    private final SysUserMapper users;
    private final SysRoleMapper roles;
    private final SysUserRoleMapper userRoles;
    private final PasswordEncoder encoder;

    @Value("${iiop.demo-accounts.super-admin-password:}")
    private String superAdminPassword;
    @Value("${iiop.demo-accounts.admin-password:}")
    private String adminPassword;
    @Value("${iiop.demo-accounts.inspector-password:}")
    private String inspectorPassword;
    @Value("${iiop.demo-accounts.maintainer-password:}")
    private String maintainerPassword;

    public DemoAccountInitializer(SysUserMapper users, SysRoleMapper roles, SysUserRoleMapper userRoles,
            PasswordEncoder encoder) {
        this.users = users;
        this.roles = roles;
        this.userRoles = userRoles;
        this.encoder = encoder;
    }

    @Override
    @Transactional
    public void run(ApplicationArguments args) {
        createIfMissing("super_demo", "SUPER_ADMIN", superAdminPassword);
        createIfMissing("admin_demo", "ADMIN", adminPassword);
        createIfMissing("inspector_demo", "INSPECTOR", inspectorPassword);
        createIfMissing("maintainer_demo", "MAINTAINER", maintainerPassword);
    }

    private void createIfMissing(String username, String roleCode, String password) {
        if (users.selectCount(Wrappers.<SysUser>lambdaQuery().eq(SysUser::getUsername, username)) > 0) {
            return;
        }
        if (password == null || password.length() < 8 || password.length() > 72) {
            throw new IllegalStateException("Demo account password is missing or invalid for " + username);
        }
        SysRole role = roles.selectOne(Wrappers.<SysRole>lambdaQuery().eq(SysRole::getRoleCode, roleCode));
        if (role == null) {
            throw new IllegalStateException("Demo account role is missing: " + roleCode);
        }
        SysUser user = new SysUser();
        user.setUsername(username);
        user.setPasswordHash(encoder.encode(password));
        user.setRealName("Demo " + roleCode);
        user.setStatus("ENABLED");
        user.setDeleted(0);
        users.insert(user);

        SysUserRole relation = new SysUserRole();
        relation.setUserId(user.getId());
        relation.setRoleId(role.getId());
        relation.setCreatedAt(LocalDateTime.now());
        userRoles.insert(relation);
    }
}
