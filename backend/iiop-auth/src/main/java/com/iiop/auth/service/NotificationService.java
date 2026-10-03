package com.iiop.auth.service;

import com.baomidou.mybatisplus.core.metadata.IPage;
import com.baomidou.mybatisplus.core.toolkit.Wrappers;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.iiop.auth.domain.entity.SysNotification;
import com.iiop.auth.domain.dto.NotificationView;
import com.iiop.auth.domain.dto.NotificationCreateRequest;
import com.iiop.auth.domain.dto.WebSocketEventRequest;
import com.iiop.auth.mapper.SysNotificationMapper;
import com.iiop.common.api.ErrorCode;
import com.iiop.common.api.PageResult;
import com.iiop.common.api.PaginationGuard;
import com.iiop.common.exception.BizException;
import java.time.LocalDateTime;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class NotificationService {
    private final SysNotificationMapper mapper;
    private final NotificationWebSocketHandler webSocketHandler;
    public NotificationService(SysNotificationMapper mapper,NotificationWebSocketHandler webSocketHandler){this.mapper=mapper;this.webSocketHandler=webSocketHandler;}
    public PageResult<NotificationView> list(Long userId,long pageNum,long pageSize){IPage<SysNotification> p=mapper.selectPage(new Page<>(pageNum,PaginationGuard.limit(pageNum,pageSize)),Wrappers.<SysNotification>lambdaQuery().eq(SysNotification::getRecipientUserId,userId).orderByDesc(SysNotification::getCreatedAt));return new PageResult<>(p.getCurrent(),p.getSize(),p.getTotal(),p.getRecords().stream().map(this::view).toList());}
    public long unread(Long userId){return mapper.selectCount(Wrappers.<SysNotification>lambdaQuery().eq(SysNotification::getRecipientUserId,userId).eq(SysNotification::getReadStatus,"UNREAD"));}
    @Transactional public void read(Long userId,Long id){SysNotification n=mapper.selectById(id);if(n==null||!userId.equals(n.getRecipientUserId()))throw new BizException(ErrorCode.NOT_FOUND,"通知不存在");n.setReadStatus("READ");n.setReadTime(LocalDateTime.now());mapper.updateById(n);}
    @Transactional public void readAll(Long userId){SysNotification n=new SysNotification();n.setReadStatus("READ");n.setReadTime(LocalDateTime.now());mapper.update(n,Wrappers.<SysNotification>lambdaUpdate().eq(SysNotification::getRecipientUserId,userId).eq(SysNotification::getReadStatus,"UNREAD"));}
    @Transactional public NotificationView create(NotificationCreateRequest request){
        SysNotification n=new SysNotification(); n.setRecipientUserId(request.recipientUserId()); n.setNotificationType(request.notificationType());
        n.setTitle(request.title()); n.setContent(request.content()); n.setBizType(request.bizType()); n.setBizId(request.bizId()); n.setReadStatus("UNREAD");
        mapper.insert(n); NotificationView view=view(n); webSocketHandler.push(request.recipientUserId(),view); return view;
    }
    public void pushEvent(WebSocketEventRequest request){
        NotificationView event=new NotificationView("event-"+System.nanoTime(),request.eventType(),request.title(),request.content(),request.bizType(),String.valueOf(request.bizId()),"EPHEMERAL",null,LocalDateTime.now());
        webSocketHandler.push(request.recipientUserId(),event);
    }
    private NotificationView view(SysNotification n){return new NotificationView(String.valueOf(n.getId()),n.getNotificationType(),n.getTitle(),n.getContent(),n.getBizType(),n.getBizId()==null?null:String.valueOf(n.getBizId()),n.getReadStatus(),n.getReadTime(),n.getCreatedAt());}
}
