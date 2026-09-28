package com.iiop.auth.support;

import com.iiop.common.constant.HeaderConstants;
import com.iiop.common.trace.TraceContext;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.util.UUID;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

@Component
public class RequestTraceFilter extends OncePerRequestFilter {
    @Override protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
            throws ServletException, IOException {
        String traceId = request.getHeader(HeaderConstants.REQUEST_ID);
        if (traceId == null || traceId.isBlank()) traceId = UUID.randomUUID().toString();
        TraceContext.setTraceId(traceId);
        response.setHeader(HeaderConstants.REQUEST_ID, traceId);
        response.setHeader(HeaderConstants.TRACE_ID, traceId);
        try { chain.doFilter(request, response); } finally { TraceContext.clear(); }
    }
}
