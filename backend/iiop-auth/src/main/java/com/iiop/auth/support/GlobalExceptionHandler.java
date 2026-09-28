package com.iiop.auth.support;

import cn.dev33.satoken.exception.NotLoginException;
import cn.dev33.satoken.exception.NotPermissionException;
import cn.dev33.satoken.exception.SameTokenInvalidException;
import com.iiop.common.api.ErrorCode;
import com.iiop.common.api.Result;
import com.iiop.common.exception.BizException;
import jakarta.validation.ConstraintViolationException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

@RestControllerAdvice
public class GlobalExceptionHandler {
    private static final Logger log = LoggerFactory.getLogger(GlobalExceptionHandler.class);

    @ExceptionHandler(BizException.class)
    ResponseEntity<Result<Void>> biz(BizException ex) {
        return ResponseEntity.status(status(ex.getErrorCode())).body(Result.failure(ex.getErrorCode(), ex.getMessage()));
    }
    @ExceptionHandler({MethodArgumentNotValidException.class, ConstraintViolationException.class})
    ResponseEntity<Result<Void>> validation(Exception ex) {
        String message = ex instanceof MethodArgumentNotValidException manv && manv.getBindingResult().getFieldError()!=null
                ? manv.getBindingResult().getFieldError().getDefaultMessage() : "请求参数错误";
        return ResponseEntity.badRequest().body(Result.failure(ErrorCode.BAD_REQUEST, message));
    }
    @ExceptionHandler(NotLoginException.class)
    ResponseEntity<Result<Void>> notLogin(NotLoginException ex) {
        return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(Result.failure(ErrorCode.UNAUTHORIZED, ErrorCode.UNAUTHORIZED.getMessage()));
    }
    @ExceptionHandler(NotPermissionException.class)
    ResponseEntity<Result<Void>> forbidden(NotPermissionException ex) {
        return ResponseEntity.status(HttpStatus.FORBIDDEN).body(Result.failure(ErrorCode.FORBIDDEN, ErrorCode.FORBIDDEN.getMessage()));
    }
    @ExceptionHandler(SameTokenInvalidException.class)
    ResponseEntity<Result<Void>> invalidSameToken(SameTokenInvalidException ex) {
        return ResponseEntity.status(HttpStatus.FORBIDDEN).body(Result.failure(ErrorCode.FORBIDDEN, "非法的内部服务调用"));
    }
    @ExceptionHandler(Exception.class)
    ResponseEntity<Result<Void>> other(Exception ex) {
        log.error("未处理异常", ex);
        return ResponseEntity.internalServerError().body(Result.failure(ErrorCode.INTERNAL_ERROR, ErrorCode.INTERNAL_ERROR.getMessage()));
    }
    private HttpStatus status(ErrorCode code) {
        return switch(code) { case UNAUTHORIZED -> HttpStatus.UNAUTHORIZED; case FORBIDDEN -> HttpStatus.FORBIDDEN;
            case NOT_FOUND -> HttpStatus.NOT_FOUND; case CONFLICT -> HttpStatus.CONFLICT; default -> HttpStatus.BAD_REQUEST; };
    }
}
