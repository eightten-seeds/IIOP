package com.iiop.auth.controller;

import cn.dev33.satoken.annotation.SaCheckLogin;
import com.iiop.auth.domain.dto.*;
import com.iiop.auth.service.AuthService;
import com.iiop.common.api.Result;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.*;

@RestController @RequestMapping("/api/auth")
public class AuthController {
    private final AuthService service;
    public AuthController(AuthService service){this.service=service;}
    @PostMapping("/login") public Result<LoginResponse> login(@Valid @RequestBody LoginRequest request){return Result.success(service.login(request));}
    @SaCheckLogin @PostMapping("/logout") public Result<Void> logout(){service.logout();return Result.success();}
    @SaCheckLogin @GetMapping("/me") public Result<MeResponse> me(){return Result.success(service.me());}
}
