# IIOP 数据库实现规范

> Codex 在实现 SQL、Entity、Mapper 时以此文件为准。

## 1. 通用规则

- MySQL 8.x
- InnoDB
- utf8mb4
- BIGINT 主键
- 后续 MyBatis-Plus 使用 ASSIGN_ID
- 主数据表默认包含 created_at、updated_at
- 需要逻辑删除的表增加 deleted TINYINT DEFAULT 0
- 状态字段优先使用 VARCHAR 英文编码
- 不创建跨数据库物理外键
- 同库也不强制物理外键，靠索引和应用层约束
- 所有 code 类业务字段唯一
- 关键查询字段建立索引
- JSON 只用于图片、多值结果、AI 结构化输出等天然多值数据

## 2. iiop_auth

### sys_user
id, username(unique), password_hash, real_name, phone, email, avatar_url, status, last_login_time, created_at, updated_at, deleted

status: ENABLED / DISABLED / LOCKED

### sys_role
id, role_code(unique), role_name, description, status, created_at, updated_at, deleted

预置：SUPER_ADMIN / ADMIN / INSPECTOR / MAINTAINER

### sys_permission
id, parent_id, permission_code(unique), permission_name, permission_type, route_path, api_path, http_method, sort_order, status, created_at, updated_at, deleted

permission_type: MENU / BUTTON / API

### sys_user_role
id, user_id, role_id, created_at
唯一索引：(user_id, role_id)

### sys_role_permission
id, role_id, permission_id, created_at
唯一索引：(role_id, permission_id)

### sys_notification
id, recipient_user_id, notification_type, title, content, biz_type, biz_id, read_status, read_time, created_at

read_status: UNREAD / READ
notification_type: ALARM / INSPECTION / WORK_ORDER / AI / SYSTEM

索引：
- (recipient_user_id, read_status)
- created_at

## 3. iiop_device

### dev_category
id, parent_id, category_code(unique), category_name, description, sort_order, status, created_at, updated_at, deleted

### dev_device
id, device_code(unique), device_name, category_id, model, manufacturer, serial_number, workshop, production_line, install_location, responsible_user_id, status, risk_level, install_date, warranty_expire_date, model_url, position_x, position_y, position_z, last_inspection_time, next_inspection_time, remark, created_at, updated_at, deleted

status: ONLINE / OFFLINE / FAULT / MAINTENANCE / SCRAPPED
risk_level: LOW / MEDIUM / HIGH / CRITICAL

model_url 用于 Three.js glTF/glb。
position_x/y/z 用 DECIMAL。

索引：
- category_id
- status
- risk_level
- responsible_user_id

### dev_metric
id, device_id, metric_code, metric_name, unit, value_type, warning_low, warning_high, critical_low, critical_high, status, created_at, updated_at, deleted

value_type: NUMBER / BOOLEAN / TEXT
唯一索引：(device_id, metric_code)

### dev_metric_data
id, device_id, metric_id, metric_value DECIMAL(18,6), quality, collect_time, created_at

quality: GOOD / UNCERTAIN / BAD

索引：
- (device_id, collect_time)
- (metric_id, collect_time)

### dev_sop
id, sop_code(unique), title, category_id, device_id, sop_type, version, content, status, effective_date, created_at, updated_at, deleted

sop_type: INSPECTION / MAINTENANCE / SAFETY

## 4. iiop_inspection

### ins_template
id, template_code(unique), template_name, category_id, description, status, created_at, updated_at, deleted

### ins_template_item
id, template_id, item_code, item_name, item_type, unit, standard_value, lower_limit, upper_limit, required_flag, sort_order, inspection_method, abnormal_hint, created_at, updated_at, deleted

item_type: NUMBER / BOOLEAN / TEXT / PHOTO
唯一索引：(template_id, item_code)

### ins_plan
id, plan_code(unique), plan_name, device_id, template_id, schedule_type, cron_expression, start_date, end_date, assignee_user_id, status, last_generate_time, next_generate_time, created_at, updated_at, deleted

schedule_type: DAILY / WEEKLY / MONTHLY / CRON
status: ENABLED / DISABLED

### ins_task
id, task_code(unique), plan_id, device_id, template_id, assignee_user_id, task_status, result_status, scheduled_start_time, scheduled_end_time, actual_start_time, actual_end_time, completion_rate DECIMAL(5,2), remark, created_at, updated_at

task_status: PENDING / IN_PROGRESS / COMPLETED / CANCELLED / OVERDUE
result_status: UNKNOWN / NORMAL / ABNORMAL

索引：
- device_id
- assignee_user_id
- task_status
- scheduled_start_time

### ins_task_item
id, task_id, template_item_id, item_code, item_name, item_type, unit, standard_value, lower_limit, upper_limit, actual_value, result_status, remark, evidence_urls JSON, sort_order, checked_at, created_at, updated_at

必须保存模板快照字段。

result_status: PENDING / NORMAL / ABNORMAL

### ins_abnormal
id, abnormal_code(unique), task_id, task_item_id, device_id, abnormal_type, severity, title, description, evidence_urls JSON, reported_by, reported_at, status, created_at, updated_at

severity: LOW / MEDIUM / HIGH / CRITICAL
status: OPEN / PROCESSING / RESOLVED / CLOSED

索引：
- device_id
- severity
- status
- reported_at

## 5. iiop_maintenance

### mt_alarm
id, alarm_code(unique), device_id, metric_id, source_type, source_id, alarm_level, alarm_title, alarm_content, alarm_value, threshold_value, occur_time, recover_time, status, created_at, updated_at

source_type: SENSOR / INSPECTION / MANUAL
alarm_level: INFO / WARNING / MAJOR / CRITICAL
status: ACTIVE / ACKNOWLEDGED / RECOVERED / CLOSED

### mt_defect
id, defect_code(unique), device_id, source_type, source_id, title, description, severity, reported_by, reported_at, status, created_at, updated_at

source_type: INSPECTION_ABNORMAL / ALARM / MANUAL
severity: LOW / MEDIUM / HIGH / CRITICAL
status: OPEN / CONFIRMED / PROCESSING / RESOLVED / CLOSED

### mt_work_order
id, work_order_code(unique), defect_id, device_id, title, description, work_order_type, priority, status, creator_user_id, assignee_user_id, planned_start_time, planned_end_time, actual_start_time, actual_end_time, ai_diagnosis_id, close_result, created_at, updated_at

work_order_type: REPAIR / PREVENTIVE / EMERGENCY
priority: LOW / MEDIUM / HIGH / URGENT
status: DRAFT / PENDING / ASSIGNED / PROCESSING / WAITING_ACCEPTANCE / COMPLETED / CANCELLED

### mt_work_order_log
id, work_order_id, action, from_status, to_status, operator_user_id, comment, attachments JSON, created_at

### mt_maintenance_record
id, work_order_id, device_id, fault_cause, solution, parts_used JSON, downtime_minutes, maintenance_cost DECIMAL(12,2), result, repaired_by, repaired_at, created_at, updated_at

result: SUCCESS / PARTIAL / FAILED

### mt_acceptance
id, work_order_id, device_id, acceptance_result, acceptance_content, accepted_by, accepted_at, created_at

acceptance_result: PASSED / REJECTED

## 6. iiop_ai

### ai_session
id, session_code(unique), user_id, device_id, title, status, created_at, updated_at

status: ACTIVE / CLOSED

### ai_message
id, session_id, role, content, model_name, token_usage, created_at

role: SYSTEM / USER / ASSISTANT / TOOL

### ai_diagnosis
id, diagnosis_code(unique), trigger_type, trigger_id, device_id, abnormal_summary, risk_level, possible_causes JSON, investigation_steps JSON, maintenance_advice, safety_notice, model_name, prompt_version, status, human_confirmed, confirmed_by, confirmed_at, created_at, updated_at

trigger_type: INSPECTION_ABNORMAL / ALARM / MANUAL
risk_level: LOW / MEDIUM / HIGH / CRITICAL
status: PENDING / RUNNING / SUCCEEDED / FAILED / CONFIRMED
human_confirmed: 0 / 1

### ai_workflow_trace
id, diagnosis_id, node_code, node_name, node_status, input_summary, output_data JSON, error_message, started_at, finished_at, created_at

node_status: PENDING / RUNNING / SUCCEEDED / FAILED / SKIPPED

计划节点：
LOAD_DEVICE
LOAD_INSPECTION_HISTORY
LOAD_MAINTENANCE_HISTORY
LOAD_SOP
ANALYZE_WITH_DEEPSEEK
RISK_CHECK
GENERATE_ADVICE
CREATE_WORK_ORDER_DRAFT

## 7. 初始化数据

只初始化演示数据：
- 4 个角色
- 少量权限
- 设备分类：数控机床、工业机器人、空压机、输送设备、电机
- 5 到 10 台演示设备
- 少量监测指标
- 2 到 3 个巡检模板及模板项
- 少量 SOP

禁止写入真实用户密码、API Key、真实个人信息。
