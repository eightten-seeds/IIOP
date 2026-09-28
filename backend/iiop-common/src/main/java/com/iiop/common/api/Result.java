package com.iiop.common.api;

import com.iiop.common.trace.TraceContext;

public record Result<T>(int code, String message, T data, String traceId) {
    public static <T> Result<T> success(T data) {
        return new Result<>(0, "success", data, TraceContext.currentTraceId());
    }

    public static Result<Void> success() {
        return success(null);
    }

    public static Result<Void> failure(ErrorCode errorCode, String message) {
        return new Result<>(errorCode.getCode(), message, null, TraceContext.currentTraceId());
    }
}
