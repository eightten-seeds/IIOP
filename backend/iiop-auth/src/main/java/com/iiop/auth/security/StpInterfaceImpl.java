package com.iiop.auth.security;

import cn.dev33.satoken.session.SaSession;
import cn.dev33.satoken.stp.StpInterface;
import cn.dev33.satoken.stp.StpUtil;
import com.iiop.auth.service.AuthService;
import java.util.List;
import org.springframework.stereotype.Component;

@Component
public class StpInterfaceImpl implements StpInterface {
    @Override public List<String> getPermissionList(Object loginId, String loginType) { return values(loginId, AuthService.SESSION_PERMISSIONS); }
    @Override public List<String> getRoleList(Object loginId, String loginType) { return values(loginId, AuthService.SESSION_ROLES); }
    private List<String> values(Object loginId,String key){
        SaSession session=StpUtil.getSessionByLoginId(loginId,false); if(session==null)return List.of();
        Object value=session.get(key); return value instanceof List<?> list?list.stream().map(String::valueOf).toList():List.of();
    }
}
