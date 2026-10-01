package com.iiop.maintenance.service;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

import com.iiop.common.api.ErrorCode;
import com.iiop.common.exception.BizException;
import com.iiop.maintenance.domain.MaintenanceDtos.AcceptanceRequest;
import org.junit.jupiter.api.Test;

class AcceptanceRulesTest {
    @Test
    void rejectedAcceptanceRequiresComment() {
        BizException error = assertThrows(BizException.class,
                () -> AcceptanceRules.validate(new AcceptanceRequest("REJECTED", "未达标", " ")));
        assertEquals(ErrorCode.BAD_REQUEST, error.getErrorCode());
        assertEquals("驳回原因必填", error.getMessage());
    }

    @Test
    void acceptsPassedAndReasonedRejectedResults() {
        assertDoesNotThrow(() -> AcceptanceRules.validate(new AcceptanceRequest("PASSED", "验收通过", null)));
        assertDoesNotThrow(() -> AcceptanceRules.validate(new AcceptanceRequest("REJECTED", "未达标", "振动仍超标")));
    }
}
