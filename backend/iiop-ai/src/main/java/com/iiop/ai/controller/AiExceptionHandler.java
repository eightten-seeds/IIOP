package com.iiop.ai.controller;

import cn.dev33.satoken.exception.NotLoginException;
import cn.dev33.satoken.exception.NotPermissionException;
import com.iiop.common.api.*;
import com.iiop.common.exception.BizException;
import org.slf4j.*;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.http.*;
import org.springframework.web.bind.annotation.*;

@RestControllerAdvice public class AiExceptionHandler {
 private static final Logger log=LoggerFactory.getLogger(AiExceptionHandler.class);
 @ExceptionHandler(BizException.class) ResponseEntity<Result<Void>> biz(BizException e){return ResponseEntity.status(status(e.getErrorCode())).body(Result.failure(e.getErrorCode(),e.getMessage()));}
 @ExceptionHandler(NotLoginException.class) ResponseEntity<Result<Void>> login(){return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(Result.failure(ErrorCode.UNAUTHORIZED,ErrorCode.UNAUTHORIZED.getMessage()));}
 @ExceptionHandler(NotPermissionException.class) ResponseEntity<Result<Void>> permission(){return ResponseEntity.status(HttpStatus.FORBIDDEN).body(Result.failure(ErrorCode.FORBIDDEN,ErrorCode.FORBIDDEN.getMessage()));}
 @ExceptionHandler(DuplicateKeyException.class) ResponseEntity<Result<Void>> duplicate(){return ResponseEntity.status(HttpStatus.CONFLICT).body(Result.failure(ErrorCode.CONFLICT,"诊断记录已存在"));}
 @ExceptionHandler(Exception.class) ResponseEntity<Result<Void>> other(Exception e){log.error("AI 服务未处理异常",e);return ResponseEntity.internalServerError().body(Result.failure(ErrorCode.INTERNAL_ERROR,ErrorCode.INTERNAL_ERROR.getMessage()));}
 private HttpStatus status(ErrorCode code){return switch(code){case UNAUTHORIZED->HttpStatus.UNAUTHORIZED;case FORBIDDEN->HttpStatus.FORBIDDEN;case NOT_FOUND->HttpStatus.NOT_FOUND;case CONFLICT->HttpStatus.CONFLICT;case SERVICE_UNAVAILABLE->HttpStatus.SERVICE_UNAVAILABLE;case TOO_MANY_REQUESTS->HttpStatus.TOO_MANY_REQUESTS;default->HttpStatus.BAD_REQUEST;};}
}
