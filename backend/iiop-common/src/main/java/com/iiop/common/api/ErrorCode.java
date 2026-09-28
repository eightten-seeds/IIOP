package com.iiop.common.api;

public enum ErrorCode {
    BAD_REQUEST(40000, "请求参数错误"),
    UNAUTHORIZED(40100, "未登录或登录已失效"),
    FORBIDDEN(40300, "无权执行该操作"),
    NOT_FOUND(40400, "资源不存在"),
    CONFLICT(40900, "业务状态冲突"),
    TOO_MANY_REQUESTS(42900, "请求过于频繁"),
    INTERNAL_ERROR(50000, "系统内部错误"),
    SERVICE_UNAVAILABLE(50300, "服务暂不可用");

    private final int code;
    private final String message;

    ErrorCode(int code, String message) {
        this.code = code;
        this.message = message;
    }

    public int getCode() { return code; }
    public String getMessage() { return message; }
}
