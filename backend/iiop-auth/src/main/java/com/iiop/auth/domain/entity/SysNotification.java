package com.iiop.auth.domain.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import java.time.LocalDateTime;

@TableName("sys_notification")
public class SysNotification {
    @TableId(type=IdType.ASSIGN_ID) private Long id; private Long recipientUserId; private String notificationType;
    private String title; private String content; private String bizType; private Long bizId; private String readStatus;
    private LocalDateTime readTime; private LocalDateTime createdAt;
    public Long getId(){return id;} public void setId(Long v){id=v;} public Long getRecipientUserId(){return recipientUserId;} public void setRecipientUserId(Long v){recipientUserId=v;}
    public String getNotificationType(){return notificationType;} public void setNotificationType(String v){notificationType=v;} public String getTitle(){return title;} public void setTitle(String v){title=v;}
    public String getContent(){return content;} public void setContent(String v){content=v;} public String getBizType(){return bizType;} public void setBizType(String v){bizType=v;}
    public Long getBizId(){return bizId;} public void setBizId(Long v){bizId=v;} public String getReadStatus(){return readStatus;} public void setReadStatus(String v){readStatus=v;}
    public LocalDateTime getReadTime(){return readTime;} public void setReadTime(LocalDateTime v){readTime=v;} public LocalDateTime getCreatedAt(){return createdAt;} public void setCreatedAt(LocalDateTime v){createdAt=v;}
}
