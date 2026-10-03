package com.iiop.device.service;

import com.iiop.common.api.ErrorCode;
import com.iiop.common.api.Result;
import com.iiop.common.exception.BizException;
import com.iiop.device.client.InspectionReferenceClient;
import com.iiop.device.client.MaintenanceReferenceClient;
import com.iiop.device.domain.DeviceModels.Device;
import com.iiop.device.mapper.CategoryMapper;
import com.iiop.device.mapper.DeviceMapper;
import com.iiop.device.mapper.MetricDataMapper;
import com.iiop.device.mapper.MetricMapper;
import com.iiop.device.mapper.SopMapper;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class DeviceServiceDeleteGuardTest {

    private final CategoryMapper categories = mock(CategoryMapper.class);
    private final DeviceMapper devices = mock(DeviceMapper.class);
    private final MetricMapper metrics = mock(MetricMapper.class);
    private final MetricDataMapper metricData = mock(MetricDataMapper.class);
    private final SopMapper sops = mock(SopMapper.class);
    private final InspectionReferenceClient inspection = mock(InspectionReferenceClient.class);
    private final MaintenanceReferenceClient maintenance = mock(MaintenanceReferenceClient.class);

    private DeviceService service() {
        return new DeviceService(categories, devices, metrics, metricData, sops, inspection, maintenance);
    }

    @Test
    void blocksDeleteWhenInspectionHasActiveReference() {
        Device device = new Device();
        device.setId(1L);
        when(devices.selectById(1L)).thenReturn(device);
        when(inspection.activeReferenceCount(1L)).thenReturn(Result.success(1L));
        when(maintenance.activeReferenceCount(1L)).thenReturn(Result.success(0L));

        BizException ex = assertThrows(BizException.class, () -> service().deleteDevice(1L));

        assertEquals(ErrorCode.CONFLICT, ex.getErrorCode());
        verify(devices, never()).deleteById(1L);
    }

    @Test
    void deletesWhenNoActiveReferenceExists() {
        Device device = new Device();
        device.setId(1L);
        when(devices.selectById(1L)).thenReturn(device);
        when(inspection.activeReferenceCount(1L)).thenReturn(Result.success(0L));
        when(maintenance.activeReferenceCount(1L)).thenReturn(Result.success(0L));

        service().deleteDevice(1L);

        verify(devices).deleteById(1L);
    }
}
