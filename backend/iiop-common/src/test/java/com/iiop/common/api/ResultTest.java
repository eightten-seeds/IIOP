package com.iiop.common.api;

import com.iiop.common.trace.TraceContext;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;

class ResultTest {
    @AfterEach void clear() { TraceContext.clear(); }

    @Test void shouldCarryTraceId() {
        TraceContext.setTraceId("trace-test");
        Result<String> result = Result.success("ok");
        assertEquals(0, result.code());
        assertEquals("trace-test", result.traceId());
    }
}
