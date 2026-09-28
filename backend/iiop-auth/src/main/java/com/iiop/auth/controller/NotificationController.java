package com.iiop.auth.controller;

import cn.dev33.satoken.annotation.SaCheckLogin;
import cn.dev33.satoken.stp.StpUtil;
import com.iiop.auth.domain.dto.NotificationView;
import com.iiop.auth.service.NotificationService;
import com.iiop.common.api.PageResult;
import com.iiop.common.api.Result;
import java.util.Map;
import org.springframework.web.bind.annotation.*;

@SaCheckLogin @RestController @RequestMapping("/api/auth/notifications")
public class NotificationController {
    private final NotificationService service; public NotificationController(NotificationService service){this.service=service;}
    @GetMapping public Result<PageResult<NotificationView>> list(@RequestParam(defaultValue="1") long pageNum,@RequestParam(defaultValue="20") long pageSize){return Result.success(service.list(StpUtil.getLoginIdAsLong(),pageNum,pageSize));}
    @GetMapping("/unread-count") public Result<Map<String,Long>> unread(){return Result.success(Map.of("count",service.unread(StpUtil.getLoginIdAsLong())));}
    @PutMapping("/{id}/read") public Result<Void> read(@PathVariable Long id){service.read(StpUtil.getLoginIdAsLong(),id);return Result.success();}
    @PutMapping("/read-all") public Result<Void> readAll(){service.readAll(StpUtil.getLoginIdAsLong());return Result.success();}
}
