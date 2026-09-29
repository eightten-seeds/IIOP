package com.iiop.device.service;

import com.baomidou.mybatisplus.core.metadata.IPage;
import com.baomidou.mybatisplus.core.toolkit.Wrappers;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.iiop.common.api.ErrorCode;
import com.iiop.common.api.PageResult;
import com.iiop.common.exception.BizException;
import com.iiop.device.domain.DeviceDtos.*;
import com.iiop.device.domain.DeviceModels.*;
import com.iiop.device.mapper.*;
import java.math.BigDecimal;
import java.util.*;
import java.util.stream.Collectors;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class DeviceService {
    private static final Set<String> DEVICE_STATUS=Set.of("ONLINE","OFFLINE","FAULT","MAINTENANCE","SCRAPPED");
    private static final Set<String> RISK=Set.of("LOW","MEDIUM","HIGH","CRITICAL");
    private final CategoryMapper categories; private final DeviceMapper devices; private final MetricMapper metrics; private final MetricDataMapper metricData; private final SopMapper sops;
    public DeviceService(CategoryMapper categories,DeviceMapper devices,MetricMapper metrics,MetricDataMapper metricData,SopMapper sops){this.categories=categories;this.devices=devices;this.metrics=metrics;this.metricData=metricData;this.sops=sops;}
    public List<Category> categories(){return categories.selectList(Wrappers.<Category>lambdaQuery().orderByAsc(Category::getSortOrder));}
    public List<CategoryTree> categoryTree(){List<Category> all=categories();return tree(null,all);}
    private List<CategoryTree> tree(Long parent,List<Category> all){return all.stream().filter(v->Objects.equals(v.getParentId(),parent)).map(v->new CategoryTree(v,tree(v.getId(),all))).toList();}
    @Transactional public Category saveCategory(Category value,Long id){if(value.getStatus()==null)value.setStatus("ENABLED");if(value.getSortOrder()==null)value.setSortOrder(0);if(id==null)categories.insert(value);else{requireCategory(id);value.setId(id);categories.updateById(value);}return categories.selectById(value.getId());}
    @Transactional public void deleteCategory(Long id){requireCategory(id);if(devices.selectCount(Wrappers.<Device>lambdaQuery().eq(Device::getCategoryId,id))>0)throw new BizException(ErrorCode.CONFLICT,"分类下存在设备");categories.deleteById(id);}
    public PageResult<Device> devicePage(long page,long size,String status,String risk){IPage<Device> p=devices.selectPage(new Page<>(page,Math.min(size,100)),Wrappers.<Device>lambdaQuery().eq(status!=null,Device::getStatus,status).eq(risk!=null,Device::getRiskLevel,risk).orderByDesc(Device::getCreatedAt));return new PageResult<>(p.getCurrent(),p.getSize(),p.getTotal(),p.getRecords());}
    public Device device(Long id){Device value=devices.selectById(id);if(value==null)throw new BizException(ErrorCode.NOT_FOUND,"设备不存在");return value;}
    @Transactional public Device saveDevice(Device value,Long id){requireCategory(value.getCategoryId());validDevice(value.getStatus(),value.getRiskLevel());if(id==null)devices.insert(value);else{device(id);value.setId(id);devices.updateById(value);}return device(value.getId());}
    @Transactional public void deleteDevice(Long id){device(id);devices.deleteById(id);}
    @Transactional public Device statusRisk(Long id,StatusRiskRequest request){Device value=device(id);validDevice(request.status(),request.riskLevel());value.setStatus(request.status());value.setRiskLevel(request.riskLevel());devices.updateById(value);return value;}
    public List<Metric> metrics(Long deviceId){device(deviceId);return metrics.selectList(Wrappers.<Metric>lambdaQuery().eq(Metric::getDeviceId,deviceId).orderByAsc(Metric::getMetricCode));}
    @Transactional public Metric saveMetric(Metric value,Long id){device(value.getDeviceId());if(!Set.of("NUMBER","BOOLEAN","TEXT").contains(value.getValueType()))throw new BizException(ErrorCode.BAD_REQUEST,"指标值类型不正确");if(value.getStatus()==null)value.setStatus("ENABLED");if(id==null)metrics.insert(value);else{requireMetric(id);value.setId(id);metrics.updateById(value);}return metrics.selectById(value.getId());}
    @Transactional public void deleteMetric(Long id){requireMetric(id);metrics.deleteById(id);}
 @Transactional public MetricData addData(Long metricId,MetricData value){Metric metric=requireMetric(metricId);if(value.getQuality()==null)value.setQuality("GOOD");if(!Set.of("GOOD","UNCERTAIN","BAD").contains(value.getQuality()))throw new BizException(ErrorCode.BAD_REQUEST,"数据质量值不正确");if("NUMBER".equals(metric.getValueType())){if(value.getNumericValue()==null||value.getTextValue()!=null||value.getBooleanValue()!=null)throw new BizException(ErrorCode.BAD_REQUEST,"NUMBER 指标只能填写 numericValue");}else if("TEXT".equals(metric.getValueType())){if(value.getTextValue()==null||value.getNumericValue()!=null||value.getBooleanValue()!=null)throw new BizException(ErrorCode.BAD_REQUEST,"TEXT 指标只能填写 textValue");}else if("BOOLEAN".equals(metric.getValueType())){if(value.getBooleanValue()==null||!Set.of(0,1).contains(value.getBooleanValue())||value.getNumericValue()!=null||value.getTextValue()!=null)throw new BizException(ErrorCode.BAD_REQUEST,"BOOLEAN 指标只能填写 0 或 1");}else throw new BizException(ErrorCode.BAD_REQUEST,"指标值类型不正确");value.setMetricId(metricId);value.setDeviceId(metric.getDeviceId());if(value.getCollectTime()==null)value.setCollectTime(java.time.LocalDateTime.now());metricData.insert(value);return value;}
    public List<MetricData> history(Long metricId,int limit){requireMetric(metricId);return metricData.selectList(Wrappers.<MetricData>lambdaQuery().eq(MetricData::getMetricId,metricId).orderByDesc(MetricData::getCollectTime).last("LIMIT "+Math.min(Math.max(limit,1),500)));}
    public List<MetricData> snapshot(Long deviceId){device(deviceId);Map<Long,MetricData> latest=new LinkedHashMap<>();for(MetricData d:metricData.selectList(Wrappers.<MetricData>lambdaQuery().eq(MetricData::getDeviceId,deviceId).orderByDesc(MetricData::getCollectTime))){latest.putIfAbsent(d.getMetricId(),d);}return List.copyOf(latest.values());}
    public Map<String,Object> trend(Long metricId,int limit){List<MetricData> points=history(metricId,limit).stream().sorted(Comparator.comparing(MetricData::getCollectTime)).toList();List<BigDecimal> nums=points.stream().map(MetricData::getNumericValue).filter(Objects::nonNull).toList();BigDecimal avg=nums.isEmpty()?null:nums.stream().reduce(BigDecimal.ZERO,BigDecimal::add).divide(BigDecimal.valueOf(nums.size()),6,java.math.RoundingMode.HALF_UP);return Map.of("points",points,"average",avg==null?"":avg);}
    public PageResult<Sop> sopPage(long page,long size){IPage<Sop> p=sops.selectPage(new Page<>(page,Math.min(size,100)),Wrappers.<Sop>lambdaQuery().orderByDesc(Sop::getCreatedAt));return new PageResult<>(p.getCurrent(),p.getSize(),p.getTotal(),p.getRecords());}
    @Transactional public Sop saveSop(Sop value,Long id){if(id==null)sops.insert(value);else{requireSop(id);value.setId(id);sops.updateById(value);}return sops.selectById(value.getId());}
    @Transactional public void deleteSop(Long id){requireSop(id);sops.deleteById(id);}
    public List<Sop> applicableSops(Long deviceId){Device d=device(deviceId);return sops.selectList(Wrappers.<Sop>lambdaQuery().eq(Sop::getStatus,"EFFECTIVE").and(q->q.eq(Sop::getDeviceId,deviceId).or().isNull(Sop::getDeviceId).eq(Sop::getCategoryId,d.getCategoryId())).orderByAsc(Sop::getSopCode));}
    public Overview overview(){List<Device> all=devices.selectList(null);return new Overview(all.size(),all.stream().collect(Collectors.groupingBy(Device::getStatus,Collectors.counting())),all.stream().collect(Collectors.groupingBy(Device::getRiskLevel,Collectors.counting())));}
    public AiContext aiContext(Long id){return new AiContext(device(id),metrics(id),snapshot(id));}
    public SopContext sopContext(Long id){return new SopContext(id,applicableSops(id));}
    private Category requireCategory(Long id){Category v=id==null?null:categories.selectById(id);if(v==null)throw new BizException(ErrorCode.NOT_FOUND,"设备分类不存在");return v;}
    private Metric requireMetric(Long id){Metric v=metrics.selectById(id);if(v==null)throw new BizException(ErrorCode.NOT_FOUND,"指标不存在");return v;}
    private Sop requireSop(Long id){Sop v=sops.selectById(id);if(v==null)throw new BizException(ErrorCode.NOT_FOUND,"SOP不存在");return v;}
    private void validDevice(String status,String risk){if(!DEVICE_STATUS.contains(status)||!RISK.contains(risk))throw new BizException(ErrorCode.BAD_REQUEST,"设备状态或风险等级不正确");}
}
