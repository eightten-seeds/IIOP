package com.iiop.auth.controller;

import cn.dev33.satoken.same.SaSameUtil;
import com.iiop.auth.domain.dto.UserSummary;
import com.iiop.auth.service.AdminService;
import com.iiop.common.api.Result;
import org.springframework.web.bind.annotation.*;

@RestController @RequestMapping("/internal/auth")
public class InternalAuthController {
    private final AdminService service; public InternalAuthController(AdminService service){this.service=service;}
    @GetMapping("/users/{id}/summary") public Result<UserSummary> summary(@PathVariable Long id){SaSameUtil.checkCurrentRequestToken();return Result.success(service.user(id));}
}
