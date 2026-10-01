package com.iiop.maintenance.service;

import com.iiop.common.api.ErrorCode;
import com.iiop.common.exception.BizException;
import com.iiop.maintenance.domain.MaintenanceDtos.AcceptanceRequest;
import java.util.Set;

final class AcceptanceRules {
    private AcceptanceRules() { }

    static void validate(AcceptanceRequest request) {
        if (request == null || !Set.of("PASSED", "REJECTED").contains(request.acceptanceResult())) {
            throw new BizException(ErrorCode.BAD_REQUEST, "验收结果不正确");
        }
        if ("REJECTED".equals(request.acceptanceResult())
                && (request.comment() == null || request.comment().isBlank())) {
            throw new BizException(ErrorCode.BAD_REQUEST, "驳回原因必填");
        }
    }
}
