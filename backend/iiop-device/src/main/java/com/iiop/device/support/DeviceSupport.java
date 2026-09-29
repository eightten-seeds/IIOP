package com.iiop.device.support;

import cn.dev33.satoken.exception.NotLoginException;
import cn.dev33.satoken.exception.NotPermissionException;
import com.iiop.common.api.ErrorCode;
import com.iiop.common.api.Result;
import com.iiop.common.constant.HeaderConstants;
import com.iiop.common.exception.BizException;
import com.iiop.common.trace.TraceContext;
import jakarta.servlet.FilterChain;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Component;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.filter.OncePerRequestFilter;

public final class DeviceSupport {private DeviceSupport(){}
    @Component public static class TraceFilter extends OncePerRequestFilter {
        @Override protected void doFilterInternal(HttpServletRequest req,HttpServletResponse res,FilterChain chain)throws java.io.IOException,jakarta.servlet.ServletException{String id=req.getHeader(HeaderConstants.REQUEST_ID);if(id==null||id.isBlank())id=UUID.randomUUID().toString();TraceContext.setTraceId(id);res.setHeader(HeaderConstants.REQUEST_ID,id);res.setHeader(HeaderConstants.TRACE_ID,id);try{chain.doFilter(req,res);}finally{TraceContext.clear();}}
    }
    @RestControllerAdvice public static class Errors {
        private static final Logger log=LoggerFactory.getLogger(Errors.class);
        @ExceptionHandler(BizException.class) ResponseEntity<Result<Void>> biz(BizException e){return ResponseEntity.status(status(e.getErrorCode())).body(Result.failure(e.getErrorCode(),e.getMessage()));}
        @ExceptionHandler(NotLoginException.class) ResponseEntity<Result<Void>> login(){return ResponseEntity.status(401).body(Result.failure(ErrorCode.UNAUTHORIZED,ErrorCode.UNAUTHORIZED.getMessage()));}
        @ExceptionHandler(NotPermissionException.class) ResponseEntity<Result<Void>> permission(){return ResponseEntity.status(403).body(Result.failure(ErrorCode.FORBIDDEN,ErrorCode.FORBIDDEN.getMessage()));}
        @ExceptionHandler(DuplicateKeyException.class) ResponseEntity<Result<Void>> duplicate(){return ResponseEntity.status(409).body(Result.failure(ErrorCode.CONFLICT,"业务编码已存在"));}
        @ExceptionHandler(Exception.class) ResponseEntity<Result<Void>> other(Exception e){log.error("设备服务未处理异常",e);return ResponseEntity.internalServerError().body(Result.failure(ErrorCode.INTERNAL_ERROR,ErrorCode.INTERNAL_ERROR.getMessage()));}
        private HttpStatus status(ErrorCode c){return switch(c){case NOT_FOUND->HttpStatus.NOT_FOUND;case CONFLICT->HttpStatus.CONFLICT;case FORBIDDEN->HttpStatus.FORBIDDEN;case UNAUTHORIZED->HttpStatus.UNAUTHORIZED;default->HttpStatus.BAD_REQUEST;};}
    }
}
