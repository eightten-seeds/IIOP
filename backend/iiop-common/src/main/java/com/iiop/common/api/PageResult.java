package com.iiop.common.api;

import java.util.List;

public record PageResult<T>(long pageNum, long pageSize, long total, List<T> records) {
    public PageResult {
        records = records == null ? List.of() : List.copyOf(records);
    }
}
