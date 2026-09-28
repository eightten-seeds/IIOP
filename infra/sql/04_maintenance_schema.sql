-- IIOP M1: iiop_maintenance 数据库表结构
USE iiop_maintenance;

CREATE TABLE IF NOT EXISTS mt_alarm (
    id BIGINT NOT NULL COMMENT '主键',
    alarm_code VARCHAR(64) NOT NULL COMMENT '告警编码',
    device_id BIGINT NOT NULL COMMENT '设备ID',
    metric_id BIGINT NULL COMMENT '指标ID',
    source_type VARCHAR(32) NOT NULL COMMENT 'SENSOR/INSPECTION/MANUAL',
    source_id BIGINT NULL COMMENT '来源业务ID',
    alarm_level VARCHAR(32) NOT NULL COMMENT 'INFO/WARNING/MAJOR/CRITICAL',
    alarm_title VARCHAR(128) NOT NULL COMMENT '告警标题',
    alarm_content VARCHAR(2000) NOT NULL COMMENT '告警内容',
    alarm_value DECIMAL(18,6) NULL COMMENT '告警值',
    threshold_value DECIMAL(18,6) NULL COMMENT '阈值',
    occur_time DATETIME NOT NULL COMMENT '发生时间',
    recover_time DATETIME NULL COMMENT '恢复时间',
    status VARCHAR(32) NOT NULL COMMENT 'ACTIVE/ACKNOWLEDGED/RECOVERED/CLOSED',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    PRIMARY KEY (id),
    UNIQUE KEY uk_mt_alarm_code (alarm_code),
    KEY idx_mt_alarm_device_time (device_id, occur_time),
    KEY idx_mt_alarm_level_status (alarm_level, status),
    KEY idx_mt_alarm_source (source_type, source_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='设备告警';

CREATE TABLE IF NOT EXISTS mt_defect (
    id BIGINT NOT NULL COMMENT '主键',
    defect_code VARCHAR(64) NOT NULL COMMENT '缺陷编码',
    device_id BIGINT NOT NULL COMMENT '设备ID',
    source_type VARCHAR(32) NOT NULL COMMENT 'INSPECTION_ABNORMAL/ALARM/MANUAL',
    source_id BIGINT NULL COMMENT '来源业务ID',
    title VARCHAR(128) NOT NULL COMMENT '标题',
    description VARCHAR(2000) NOT NULL COMMENT '描述',
    severity VARCHAR(32) NOT NULL COMMENT 'LOW/MEDIUM/HIGH/CRITICAL',
    reported_by BIGINT NULL COMMENT '上报人用户ID',
    reported_at DATETIME NOT NULL COMMENT '上报时间',
    status VARCHAR(32) NOT NULL COMMENT 'OPEN/CONFIRMED/PROCESSING/RESOLVED/CLOSED',
    ai_diagnosis_id BIGINT NULL COMMENT 'AI诊断ID',
    resolved_at DATETIME NULL COMMENT '解决时间',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    PRIMARY KEY (id),
    UNIQUE KEY uk_mt_defect_code (defect_code),
    UNIQUE KEY uk_mt_defect_source (source_type, source_id),
    KEY idx_mt_defect_device_status (device_id, status),
    KEY idx_mt_defect_severity_status (severity, status),
    KEY idx_mt_defect_source (source_type, source_id),
    KEY idx_mt_defect_ai (ai_diagnosis_id),
    KEY idx_mt_defect_reported_at (reported_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='缺陷';

CREATE TABLE IF NOT EXISTS mt_work_order (
    id BIGINT NOT NULL COMMENT '主键',
    work_order_code VARCHAR(64) NOT NULL COMMENT '工单编码',
    defect_id BIGINT NULL COMMENT '缺陷ID',
    device_id BIGINT NOT NULL COMMENT '设备ID',
    title VARCHAR(128) NOT NULL COMMENT '标题',
    description VARCHAR(2000) NOT NULL COMMENT '描述',
    work_order_type VARCHAR(32) NOT NULL COMMENT 'REPAIR/PREVENTIVE/EMERGENCY',
    priority VARCHAR(32) NOT NULL COMMENT 'LOW/MEDIUM/HIGH/URGENT',
    status VARCHAR(32) NOT NULL COMMENT 'DRAFT/PENDING/ASSIGNED/PROCESSING/WAITING_ACCEPTANCE/COMPLETED/CANCELLED',
    creator_user_id BIGINT NOT NULL COMMENT '创建人用户ID',
    assignee_user_id BIGINT NULL COMMENT '维修人用户ID',
    planned_start_time DATETIME NULL COMMENT '计划开始时间',
    planned_end_time DATETIME NULL COMMENT '计划结束时间',
    actual_start_time DATETIME NULL COMMENT '实际开始时间',
    actual_end_time DATETIME NULL COMMENT '实际结束时间',
    ai_diagnosis_id BIGINT NULL COMMENT 'AI诊断ID',
    close_result VARCHAR(1000) NULL COMMENT '关闭结果',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    PRIMARY KEY (id),
    UNIQUE KEY uk_mt_work_order_code (work_order_code),
    KEY idx_mt_work_order_defect (defect_id),
    KEY idx_mt_work_order_device_status (device_id, status),
    KEY idx_mt_work_order_assignee_status (assignee_user_id, status),
    KEY idx_mt_work_order_priority_status (priority, status),
    KEY idx_mt_work_order_ai (ai_diagnosis_id),
    KEY idx_mt_work_order_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='维修工单';

CREATE TABLE IF NOT EXISTS mt_work_order_log (
    id BIGINT NOT NULL COMMENT '主键',
    work_order_id BIGINT NOT NULL COMMENT '工单ID',
    action VARCHAR(64) NOT NULL COMMENT '操作',
    from_status VARCHAR(32) NULL COMMENT '原状态',
    to_status VARCHAR(32) NULL COMMENT '目标状态',
    operator_user_id BIGINT NOT NULL COMMENT '操作人用户ID',
    comment VARCHAR(1000) NULL COMMENT '操作说明',
    attachments JSON NULL COMMENT '附件列表',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    PRIMARY KEY (id),
    KEY idx_mt_work_order_log_order_time (work_order_id, created_at),
    KEY idx_mt_work_order_log_operator_time (operator_user_id, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='工单流转日志';

CREATE TABLE IF NOT EXISTS mt_maintenance_record (
    id BIGINT NOT NULL COMMENT '主键',
    work_order_id BIGINT NOT NULL COMMENT '工单ID',
    device_id BIGINT NOT NULL COMMENT '设备ID',
    fault_cause VARCHAR(2000) NULL COMMENT '故障原因',
    solution VARCHAR(3000) NOT NULL COMMENT '维修方案',
    parts_used JSON NULL COMMENT '使用配件',
    downtime_minutes INT NULL COMMENT '停机分钟数',
    maintenance_cost DECIMAL(12,2) NULL COMMENT '维修费用',
    result VARCHAR(32) NOT NULL COMMENT 'SUCCESS/PARTIAL/FAILED',
    repaired_by BIGINT NOT NULL COMMENT '维修人用户ID',
    repaired_at DATETIME NOT NULL COMMENT '维修时间',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    PRIMARY KEY (id),
    KEY idx_mt_maintenance_record_order (work_order_id),
    KEY idx_mt_maintenance_record_device_time (device_id, repaired_at),
    KEY idx_mt_maintenance_record_repaired_time (repaired_by, repaired_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='维修记录';

CREATE TABLE IF NOT EXISTS mt_acceptance (
    id BIGINT NOT NULL COMMENT '主键',
    work_order_id BIGINT NOT NULL COMMENT '工单ID',
    device_id BIGINT NOT NULL COMMENT '设备ID',
    acceptance_result VARCHAR(32) NOT NULL COMMENT 'PASSED/REJECTED',
    acceptance_content VARCHAR(2000) NULL COMMENT '验收内容',
    accepted_by BIGINT NOT NULL COMMENT '验收人用户ID',
    accepted_at DATETIME NOT NULL COMMENT '验收时间',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    PRIMARY KEY (id),
    KEY idx_mt_acceptance_order_time (work_order_id, accepted_at),
    KEY idx_mt_acceptance_device_time (device_id, accepted_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='维修验收';
