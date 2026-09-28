-- IIOP M1: 安全的虚构演示数据
-- 本文件不创建用户账号，不写入明文密码、API Key、Token、真实手机号或真实邮箱。

USE iiop_auth;

INSERT IGNORE INTO sys_role (id, role_code, role_name, description, status, deleted)
VALUES
    (1001, 'SUPER_ADMIN', '超级管理员', '系统级管理角色', 'ENABLED', 0),
    (1002, 'ADMIN', '业务管理员', '业务与系统管理角色', 'ENABLED', 0),
    (1003, 'INSPECTOR', '巡检人员', '现场巡检角色', 'ENABLED', 0),
    (1004, 'MAINTAINER', '维修人员', '维修工单角色', 'ENABLED', 0);

INSERT IGNORE INTO sys_permission
    (id, permission_code, permission_name, permission_type, sort_order, status, deleted)
VALUES
    (2001, 'dashboard:view', '查看驾驶舱', 'API', 1, 'ENABLED', 0),
    (2002, 'device:view', '查看设备', 'API', 2, 'ENABLED', 0),
    (2003, 'device:create', '创建设备', 'API', 3, 'ENABLED', 0),
    (2004, 'device:update', '更新设备', 'API', 4, 'ENABLED', 0),
    (2005, 'device:delete', '删除设备', 'API', 5, 'ENABLED', 0),
    (2006, 'inspection:view', '查看巡检', 'API', 6, 'ENABLED', 0),
    (2007, 'inspection:template:manage', '管理巡检模板', 'API', 7, 'ENABLED', 0),
    (2008, 'inspection:plan:manage', '管理巡检计划', 'API', 8, 'ENABLED', 0),
    (2009, 'inspection:execute', '执行巡检', 'API', 9, 'ENABLED', 0),
    (2010, 'inspection:abnormal:process', '处理巡检异常', 'API', 10, 'ENABLED', 0),
    (2011, 'maintenance:view', '查看运维', 'API', 11, 'ENABLED', 0),
    (2012, 'maintenance:alarm:process', '处理告警', 'API', 12, 'ENABLED', 0),
    (2013, 'maintenance:defect:process', '处理缺陷', 'API', 13, 'ENABLED', 0),
    (2014, 'maintenance:workorder:create', '创建维修工单', 'API', 14, 'ENABLED', 0),
    (2015, 'maintenance:workorder:process', '处理维修工单', 'API', 15, 'ENABLED', 0),
    (2016, 'maintenance:workorder:accept', '验收维修工单', 'API', 16, 'ENABLED', 0),
    (2017, 'ai:view', '查看AI诊断', 'API', 17, 'ENABLED', 0),
    (2018, 'ai:diagnosis', '发起AI诊断', 'API', 18, 'ENABLED', 0),
    (2019, 'ai:confirm', '确认AI诊断', 'API', 19, 'ENABLED', 0),
    (2020, 'system:user:view', '查看用户', 'API', 20, 'ENABLED', 0),
    (2021, 'system:user:create', '创建用户', 'API', 21, 'ENABLED', 0),
    (2022, 'system:user:update', '更新用户', 'API', 22, 'ENABLED', 0),
    (2023, 'system:user:delete', '删除用户', 'API', 23, 'ENABLED', 0),
    (2024, 'system:user:role', '管理用户角色', 'API', 24, 'ENABLED', 0),
    (2025, 'system:role:view', '查看角色', 'API', 25, 'ENABLED', 0),
    (2026, 'system:role:create', '创建角色', 'API', 26, 'ENABLED', 0),
    (2027, 'system:role:update', '更新角色', 'API', 27, 'ENABLED', 0),
    (2028, 'system:role:delete', '删除角色', 'API', 28, 'ENABLED', 0),
    (2029, 'system:role:permission', '管理角色权限', 'API', 29, 'ENABLED', 0),
    (2030, 'system:permission:view', '查看权限', 'API', 30, 'ENABLED', 0),
    (2031, 'system:permission:create', '创建权限', 'API', 31, 'ENABLED', 0),
    (2032, 'system:permission:update', '更新权限', 'API', 32, 'ENABLED', 0),
    (2033, 'system:permission:delete', '删除权限', 'API', 33, 'ENABLED', 0);

-- SUPER_ADMIN 与 ADMIN 按规范拥有全部固定权限；其他角色按规范授予最小业务权限。
INSERT IGNORE INTO sys_role_permission (id, role_id, permission_id)
SELECT 300000 + (r.id - 1001) * 100 + (p.id - 2000), r.id, p.id
FROM sys_role r CROSS JOIN sys_permission p
WHERE r.role_code IN ('SUPER_ADMIN', 'ADMIN');

INSERT IGNORE INTO sys_role_permission (id, role_id, permission_id)
SELECT 304000 + (p.id - 2000), 1003, p.id
FROM sys_permission p
WHERE p.permission_code IN (
    'dashboard:view', 'device:view', 'inspection:view', 'inspection:execute',
    'ai:view', 'ai:diagnosis'
);

INSERT IGNORE INTO sys_role_permission (id, role_id, permission_id)
SELECT 305000 + (p.id - 2000), 1004, p.id
FROM sys_permission p
WHERE p.permission_code IN (
    'device:view', 'maintenance:view', 'maintenance:alarm:process',
    'maintenance:defect:process', 'maintenance:workorder:create',
    'maintenance:workorder:process', 'maintenance:workorder:accept',
    'ai:view', 'ai:diagnosis', 'ai:confirm'
);

USE iiop_device;

INSERT IGNORE INTO dev_category (id, category_code, category_name, description, sort_order, status, deleted)
VALUES
    (4001, 'CNC', '数控机床', '虚构数控加工设备分类', 1, 'ENABLED', 0),
    (4002, 'ROBOT', '工业机器人', '虚构工业机器人分类', 2, 'ENABLED', 0),
    (4003, 'COMPRESSOR', '空压机', '虚构空压设备分类', 3, 'ENABLED', 0),
    (4004, 'CONVEYOR', '输送设备', '虚构输送设备分类', 4, 'ENABLED', 0),
    (4005, 'MOTOR', '电机', '虚构电机设备分类', 5, 'ENABLED', 0);

INSERT IGNORE INTO dev_device
    (id, device_code, device_name, category_id, model, manufacturer, serial_number,
     workshop, production_line, install_location, status, risk_level,
     install_date, warranty_expire_date, model_url, position_x, position_y, position_z, remark, deleted)
VALUES
    (4101, 'DEV202609280001', '一号数控加工中心', 4001, 'CNC-DEMO-01', '虚构设备厂', 'DEMO-CNC-001', '一车间', 'A线', 'A线-01', 'ONLINE', 'LOW', '2025-01-10', '2028-01-09', NULL, 10.000, 2.000, 1.000, '虚构演示设备', 0),
    (4102, 'DEV202609280002', '二号数控加工中心', 4001, 'CNC-DEMO-02', '虚构设备厂', 'DEMO-CNC-002', '一车间', 'A线', 'A线-02', 'OFFLINE', 'MEDIUM', '2025-02-10', '2028-02-09', NULL, 14.000, 2.000, 1.000, '虚构演示设备', 0),
    (4103, 'DEV202609280003', '搬运机器人一号', 4002, 'ROBOT-DEMO-01', '虚构设备厂', 'DEMO-ROB-001', '一车间', 'B线', 'B线-01', 'FAULT', 'HIGH', '2025-03-10', '2028-03-09', NULL, 22.000, 3.000, 2.000, '虚构演示设备', 0),
    (4104, 'DEV202609280004', '主空压机一号', 4003, 'COMP-DEMO-01', '虚构设备厂', 'DEMO-CMP-001', '二车间', 'C线', 'C线-01', 'MAINTENANCE', 'CRITICAL', '2025-04-10', '2028-04-09', NULL, 30.000, 4.000, 1.000, '虚构演示设备', 0),
    (4105, 'DEV202609280005', '装配线电机一号', 4005, 'MOTOR-DEMO-01', '虚构设备厂', 'DEMO-MOT-001', '二车间', 'C线', 'C线-02', 'ONLINE', 'MEDIUM', '2025-05-10', '2028-05-09', NULL, 36.000, 4.000, 1.000, '虚构演示设备', 0);

INSERT IGNORE INTO dev_metric
    (id, device_id, metric_code, metric_name, unit, value_type, warning_low, warning_high, critical_low, critical_high, status, deleted)
VALUES
    (4201, 4101, 'SPINDLE_TEMP', '主轴温度', '℃', 'NUMBER', NULL, 70.000000, NULL, 85.000000, 'ENABLED', 0),
    (4202, 4101, 'SPINDLE_VIBRATION', '主轴振动', 'mm/s', 'NUMBER', NULL, 4.000000, NULL, 7.000000, 'ENABLED', 0),
    (4203, 4101, 'SPINDLE_CURRENT', '主轴电流', 'A', 'NUMBER', NULL, 30.000000, NULL, 40.000000, 'ENABLED', 0),
    (4204, 4104, 'DISCHARGE_PRESSURE', '排气压力', 'MPa', 'NUMBER', 0.500000, 0.850000, 0.300000, 1.000000, 'ENABLED', 0),
    (4205, 4104, 'DISCHARGE_TEMP', '排气温度', '℃', 'NUMBER', NULL, 80.000000, NULL, 100.000000, 'ENABLED', 0),
    (4206, 4105, 'MOTOR_TEMP', '电机温度', '℃', 'NUMBER', NULL, 75.000000, NULL, 95.000000, 'ENABLED', 0);

INSERT IGNORE INTO dev_sop
    (id, sop_code, title, category_id, device_id, sop_type, version, content, status, effective_date, deleted)
VALUES
    (4301, 'SOP-INSPECTION-001', '数控设备日常巡检规范', 4001, NULL, 'INSPECTION', '1.0', '检查外观、主轴温度、振动和润滑状态。', 'EFFECTIVE', '2026-01-01', 0),
    (4302, 'SOP-MAINTENANCE-001', '工业设备维修安全规范', NULL, NULL, 'MAINTENANCE', '1.0', '维修前执行断电、挂牌和现场安全确认。', 'EFFECTIVE', '2026-01-01', 0),
    (4303, 'SOP-SAFETY-001', '车间设备安全操作规范', NULL, NULL, 'SAFETY', '1.0', '设备运行和维护期间遵守现场安全操作要求。', 'EFFECTIVE', '2026-01-01', 0);

USE iiop_inspection;

INSERT IGNORE INTO ins_template
    (id, template_code, template_name, category_id, version, description, status, deleted)
VALUES
    (5001, 'TPL-CNC-DAILY', '数控机床日常巡检', 4001, 1, '虚构数控机床日常检查模板', 'ENABLED', 0),
    (5002, 'TPL-COMP-DAILY', '空压机日常巡检', 4003, 1, '虚构空压机日常检查模板', 'ENABLED', 0),
    (5003, 'TPL-MOTOR-SAFETY', '电机安全巡检', 4005, 1, '虚构电机安全检查模板', 'ENABLED', 0);

INSERT IGNORE INTO ins_template_item
    (id, template_id, item_code, item_name, item_type, unit, standard_value, lower_limit, upper_limit, required_flag, sort_order, inspection_method, abnormal_hint, deleted)
VALUES
    (5101, 5001, 'TEMP', '主轴温度', 'NUMBER', '℃', '≤70', NULL, 70.000000, 1, 1, '读取设备温度指标', '温度超限', 0),
    (5102, 5001, 'VIBRATION', '主轴振动', 'NUMBER', 'mm/s', '≤4', NULL, 4.000000, 1, 2, '读取设备振动指标', '振动超限', 0),
    (5103, 5001, 'LUBRICATION', '润滑状态', 'TEXT', NULL, '正常', NULL, NULL, 1, 3, '目视检查并记录', '润滑异常', 0),
    (5104, 5002, 'PRESSURE', '排气压力', 'NUMBER', 'MPa', '0.50-0.85', 0.500000, 0.850000, 1, 1, '读取压力指标', '压力异常', 0),
    (5105, 5002, 'TEMP', '排气温度', 'NUMBER', '℃', '≤80', NULL, 80.000000, 1, 2, '读取温度指标', '温度超限', 0),
    (5106, 5003, 'MOTOR_TEMP', '电机温度', 'NUMBER', '℃', '≤75', NULL, 75.000000, 1, 1, '读取电机温度指标', '电机温度超限', 0);
