-- IIOP: 修复固定演示 Seed 数据的编码乱码
-- 本文件按固定 ID 原地更新文本字段，不执行 DROP、TRUNCATE 或 DELETE，不破坏业务关联。
SET NAMES utf8mb4;

-- 1. iiop_auth: 角色与权限名称修复
USE iiop_auth;

UPDATE sys_role SET role_name = '超级管理员', description = '系统级管理角色' WHERE id = 1001;
UPDATE sys_role SET role_name = '业务管理员', description = '设备巡检运维业务管理角色' WHERE id = 1002;
UPDATE sys_role SET role_name = '巡检人员', description = '现场巡检角色' WHERE id = 1003;
UPDATE sys_role SET role_name = '维修人员', description = '维修工单角色' WHERE id = 1004;

UPDATE sys_permission SET permission_name = '查看驾驶舱' WHERE id = 2001;
UPDATE sys_permission SET permission_name = '查看设备' WHERE id = 2002;
UPDATE sys_permission SET permission_name = '创建设备' WHERE id = 2003;
UPDATE sys_permission SET permission_name = '更新设备' WHERE id = 2004;
UPDATE sys_permission SET permission_name = '删除设备' WHERE id = 2005;
UPDATE sys_permission SET permission_name = '查看巡检' WHERE id = 2006;
UPDATE sys_permission SET permission_name = '管理巡检模板' WHERE id = 2007;
UPDATE sys_permission SET permission_name = '管理巡检计划' WHERE id = 2008;
UPDATE sys_permission SET permission_name = '执行巡检' WHERE id = 2009;
UPDATE sys_permission SET permission_name = '处理巡检异常' WHERE id = 2010;
UPDATE sys_permission SET permission_name = '查看运维' WHERE id = 2011;
UPDATE sys_permission SET permission_name = '处理告警' WHERE id = 2012;
UPDATE sys_permission SET permission_name = '处理缺陷' WHERE id = 2013;
UPDATE sys_permission SET permission_name = '创建维修工单' WHERE id = 2014;
UPDATE sys_permission SET permission_name = '处理维修工单' WHERE id = 2015;
UPDATE sys_permission SET permission_name = '验收维修工单' WHERE id = 2016;
UPDATE sys_permission SET permission_name = '查看AI诊断' WHERE id = 2017;
UPDATE sys_permission SET permission_name = '发起AI诊断' WHERE id = 2018;
UPDATE sys_permission SET permission_name = '确认AI诊断' WHERE id = 2019;
UPDATE sys_permission SET permission_name = '查看用户' WHERE id = 2020;
UPDATE sys_permission SET permission_name = '创建用户' WHERE id = 2021;
UPDATE sys_permission SET permission_name = '更新用户' WHERE id = 2022;
UPDATE sys_permission SET permission_name = '删除用户' WHERE id = 2023;
UPDATE sys_permission SET permission_name = '管理用户角色' WHERE id = 2024;
UPDATE sys_permission SET permission_name = '查看角色' WHERE id = 2025;
UPDATE sys_permission SET permission_name = '创建角色' WHERE id = 2026;
UPDATE sys_permission SET permission_name = '更新角色' WHERE id = 2027;
UPDATE sys_permission SET permission_name = '删除角色' WHERE id = 2028;
UPDATE sys_permission SET permission_name = '管理角色权限' WHERE id = 2029;
UPDATE sys_permission SET permission_name = '查看权限' WHERE id = 2030;
UPDATE sys_permission SET permission_name = '创建权限' WHERE id = 2031;
UPDATE sys_permission SET permission_name = '更新权限' WHERE id = 2032;
UPDATE sys_permission SET permission_name = '删除权限' WHERE id = 2033;

UPDATE sys_user SET real_name = '测试超级管理员' WHERE username = 'test_super';
UPDATE sys_user SET real_name = '测试管理员' WHERE username = 'test_admin';
UPDATE sys_user SET real_name = '测试巡检员' WHERE username = 'test_inspector';
UPDATE sys_user SET real_name = '测试维修员' WHERE username = 'test_maintainer';

-- 2. iiop_device: 分类、设备、指标、SOP 修复
USE iiop_device;

UPDATE dev_category SET category_name = '数控机床', description = '虚构数控加工设备分类' WHERE id = 4001;
UPDATE dev_category SET category_name = '工业机器人', description = '虚构工业机器人分类' WHERE id = 4002;
UPDATE dev_category SET category_name = '空压机', description = '虚构空压设备分类' WHERE id = 4003;
UPDATE dev_category SET category_name = '输送设备', description = '虚构输送设备分类' WHERE id = 4004;
UPDATE dev_category SET category_name = '电机', description = '虚构电机设备分类' WHERE id = 4005;

UPDATE dev_device SET device_name = '一号数控加工中心', manufacturer = '虚构设备厂', workshop = '一车间', production_line = 'A线', install_location = 'A线-01', remark = '虚构演示设备' WHERE id = 4101;
UPDATE dev_device SET device_name = '二号数控加工中心', manufacturer = '虚构设备厂', workshop = '一车间', production_line = 'A线', install_location = 'A线-02', remark = '虚构演示设备' WHERE id = 4102;
UPDATE dev_device SET device_name = '搬运机器人一号', manufacturer = '虚构设备厂', workshop = '一车间', production_line = 'B线', install_location = 'B线-01', remark = '虚构演示设备' WHERE id = 4103;
UPDATE dev_device SET device_name = '主空压机一号', manufacturer = '虚构设备厂', workshop = '二车间', production_line = 'C线', install_location = 'C线-01', remark = '虚构演示设备' WHERE id = 4104;
UPDATE dev_device SET device_name = '装配线电机一号', manufacturer = '虚构设备厂', workshop = '二车间', production_line = 'C线', install_location = 'C线-02', remark = '虚构演示设备' WHERE id = 4105;

UPDATE dev_metric SET metric_name = '主轴温度', unit = '℃' WHERE id = 4201;
UPDATE dev_metric SET metric_name = '主轴振动', unit = 'mm/s' WHERE id = 4202;
UPDATE dev_metric SET metric_name = '主轴电流', unit = 'A' WHERE id = 4203;
UPDATE dev_metric SET metric_name = '排气压力', unit = 'MPa' WHERE id = 4204;
UPDATE dev_metric SET metric_name = '排气温度', unit = '℃' WHERE id = 4205;
UPDATE dev_metric SET metric_name = '电机温度', unit = '℃' WHERE id = 4206;

UPDATE dev_sop SET title = '数控设备日常巡检规范', content = '检查外观、主轴温度、振动和润滑状态。' WHERE id = 4301;
UPDATE dev_sop SET title = '工业设备维修安全规范', content = '维修前执行断电、挂牌和现场安全确认。' WHERE id = 4302;
UPDATE dev_sop SET title = '车间设备安全操作规范', content = '设备运行和维护期间遵守现场安全操作要求。' WHERE id = 4303;

-- 3. iiop_inspection: 模板与模板检查项修复
USE iiop_inspection;

UPDATE ins_template SET template_name = '数控机床日常巡检', description = '虚构数控机床日常检查模板' WHERE id = 5001;
UPDATE ins_template SET template_name = '空压机日常巡检', description = '虚构空压机日常检查模板' WHERE id = 5002;
UPDATE ins_template SET template_name = '电机安全巡检', description = '虚构电机安全检查模板' WHERE id = 5003;

UPDATE ins_template_item SET item_name = '主轴温度', unit = '℃', standard_value = '≤70', inspection_method = '读取设备温度指标', abnormal_hint = '温度超限' WHERE id = 5101;
UPDATE ins_template_item SET item_name = '主轴振动', unit = 'mm/s', standard_value = '≤4', inspection_method = '读取设备振动指标', abnormal_hint = '振动超限' WHERE id = 5102;
UPDATE ins_template_item SET item_name = '润滑状态', unit = NULL, standard_value = '正常', inspection_method = '目视检查并记录', abnormal_hint = '润滑异常' WHERE id = 5103;
UPDATE ins_template_item SET item_name = '排气压力', unit = 'MPa', standard_value = '0.50-0.85', inspection_method = '读取压力指标', abnormal_hint = '压力异常' WHERE id = 5104;
UPDATE ins_template_item SET item_name = '排气温度', unit = '℃', standard_value = '≤80', inspection_method = '读取温度指标', abnormal_hint = '温度超限' WHERE id = 5105;
UPDATE ins_template_item SET item_name = '电机温度', unit = '℃', standard_value = '≤75', inspection_method = '读取电机温度指标', abnormal_hint = '电机温度超限' WHERE id = 5106;
