package com.iiop.device.domain;

import com.iiop.device.domain.DeviceModels.Category;
import com.iiop.device.domain.DeviceModels.Metric;
import com.iiop.device.domain.DeviceModels.MetricData;
import com.iiop.device.domain.DeviceModels.Sop;
import java.util.List;
import java.util.Map;

public final class DeviceDtos {
    private DeviceDtos(){}
    public record CategoryTree(Category category,List<CategoryTree> children){}
    public record StatusRiskRequest(String status,String riskLevel){}
    public record AiContext(DeviceModels.Device device,List<Metric> metrics,List<MetricData> latestMetrics){}
    public record SopContext(Long deviceId,List<Sop> sops){}
    public record Overview(long deviceTotal,Map<String,Long> byStatus,Map<String,Long> byRisk){}
}
