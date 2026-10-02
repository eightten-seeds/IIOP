package com.iiop.auth.controller;

import com.iiop.auth.domain.dto.UserSummary;
import com.iiop.auth.domain.dto.UserJobSummary;
import com.iiop.auth.domain.dto.NotificationCreateRequest;
import com.iiop.auth.domain.dto.NotificationView;
import com.iiop.auth.domain.dto.WebSocketEventRequest;
import com.iiop.auth.service.AdminService;
import com.iiop.auth.service.NotificationService;
import com.iiop.common.api.Result;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.*;

@RestController @RequestMapping("/internal/auth")
public class InternalAuthController {
    private final AdminService service; private final NotificationService notifications;
    public InternalAuthController(AdminService service,NotificationService notifications){this.service=service;this.notifications=notifications;}
    @GetMapping("/users/{id}/summary") public Result<UserSummary> summary(@PathVariable Long id){return Result.success(service.user(id));}
    @GetMapping("/users/{id}/job-summary") public Result<UserJobSummary> jobSummary(@PathVariable Long id){return Result.success(service.jobSummary(id));}
    @PostMapping("/notifications") public Result<NotificationView> notify(@Valid @RequestBody NotificationCreateRequest request){return Result.success(notifications.create(request));}
    @PostMapping("/websocket-events") public Result<Void> websocketEvent(@Valid @RequestBody WebSocketEventRequest request){notifications.pushEvent(request);return Result.success();}
}
