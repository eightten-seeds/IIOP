package com.iiop.common.api;

import com.iiop.common.exception.BizException;

public final class PaginationGuard {

    private PaginationGuard() {
    }

    public static long limit(long page, long size) {
        if (page < 1 || size < 1) {
            throw new BizException(ErrorCode.BAD_REQUEST, "pageNum 和 pageSize 必须大于 0");
        }
        return Math.min(size, 100);
    }
}
