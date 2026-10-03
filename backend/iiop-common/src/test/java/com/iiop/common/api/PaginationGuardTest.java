package com.iiop.common.api;

import com.iiop.common.exception.BizException;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

class PaginationGuardTest {

    @Test
    void rejectsNonPositivePageOrSize() {
        BizException page = assertThrows(BizException.class, () -> PaginationGuard.limit(0, 20));
        BizException size = assertThrows(BizException.class, () -> PaginationGuard.limit(1, 0));

        assertEquals(ErrorCode.BAD_REQUEST, page.getErrorCode());
        assertEquals(ErrorCode.BAD_REQUEST, size.getErrorCode());
    }

    @Test
    void capsPageSizeAtOneHundred() {
        assertEquals(20, PaginationGuard.limit(1, 20));
        assertEquals(100, PaginationGuard.limit(1, 101));
    }
}
