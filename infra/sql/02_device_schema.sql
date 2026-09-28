-- IIOP M1: iiop_device 数据库表结构
USE iiop_device;

CREATE TABLE IF NOT EXISTS dev_category (
    id BIGINT NOT NULL COMMENT '主键',
    parent_id BIGINT NULL COMMENT '父分类ID',
    category_code VARCHAR(64) NOT NULL COMMENT '分类编码',
    category_name VARCHAR(128) NOT NULL COMMENT '分类名称',
    description VARCHAR(500) NULL COMMENT '描述',
    sort_order INT NOT NULL DEFAULT 0 COMMENT '排序',
    status VARCHAR(32) NOT NULL DEFAULT 'ENABLED' COMMENT '状态',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    deleted TINYINT NOT NULL DEFAULT 0 COMMENT '0正常，1已删除',
    PRIMARY KEY (id),
    UNIQUE KEY uk_dev_category_code (category_code),
    KEY idx_dev_category_parent (parent_id),
    KEY idx_dev_category_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='设备分类';

CREATE TABLE IF NOT EXISTS dev_device (
    id BIGINT NOT NULL COMMENT '主键',
    device_code VARCHAR(64) NOT NULL COMMENT '设备编码',
    device_name VARCHAR(128) NOT NULL COMMENT '设备名称',
    category_id BIGINT NOT NULL COMMENT '设备分类ID',
    model VARCHAR(128) NULL COMMENT '设备型号',
    manufacturer VARCHAR(128) NULL COMMENT '制造商',
    serial_number VARCHAR(128) NULL COMMENT '出厂序列号',
    workshop VARCHAR(128) NULL COMMENT '车间',
    production_line VARCHAR(128) NULL COMMENT '产线',
    install_location VARCHAR(255) NULL COMMENT '安装位置',
    responsible_user_id BIGINT NULL COMMENT '责任人用户ID',
    status VARCHAR(32) NOT NULL COMMENT 'ONLINE/OFFLINE/FAULT/MAINTENANCE/SCRAPPED',
    risk_level VARCHAR(32) NOT NULL COMMENT 'LOW/MEDIUM/HIGH/CRITICAL',
    install_date DATE NULL COMMENT '安装日期',
    warranty_expire_date DATE NULL COMMENT '质保截止日期',
    model_url VARCHAR(512) NULL COMMENT 'glTF/glb模型地址',
    position_x DECIMAL(12,3) NULL COMMENT '三维X坐标',
    position_y DECIMAL(12,3) NULL COMMENT '三维Y坐标',
    position_z DECIMAL(12,3) NULL COMMENT '三维Z坐标',
    remark VARCHAR(1000) NULL COMMENT '备注',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    deleted TINYINT NOT NULL DEFAULT 0 COMMENT '0正常，1已删除',
    PRIMARY KEY (id),
    UNIQUE KEY uk_dev_device_code (device_code),
    KEY idx_dev_device_category (category_id),
    KEY idx_dev_device_status (status),
    KEY idx_dev_device_risk (risk_level),
    KEY idx_dev_device_responsible (responsible_user_id),
    KEY idx_dev_device_workshop (workshop),
    KEY idx_dev_device_line (production_line)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='设备台账';

CREATE TABLE IF NOT EXISTS dev_metric (
    id BIGINT NOT NULL COMMENT '主键',
    device_id BIGINT NOT NULL COMMENT '设备ID',
    metric_code VARCHAR(64) NOT NULL COMMENT '指标编码',
    metric_name VARCHAR(128) NOT NULL COMMENT '指标名称',
    unit VARCHAR(32) NULL COMMENT '单位',
    value_type VARCHAR(32) NOT NULL COMMENT 'NUMBER/BOOLEAN/TEXT',
    warning_low DECIMAL(18,6) NULL COMMENT '预警下限',
    warning_high DECIMAL(18,6) NULL COMMENT '预警上限',
    critical_low DECIMAL(18,6) NULL COMMENT '严重下限',
    critical_high DECIMAL(18,6) NULL COMMENT '严重上限',
    status VARCHAR(32) NOT NULL DEFAULT 'ENABLED' COMMENT '状态',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    deleted TINYINT NOT NULL DEFAULT 0 COMMENT '0正常，1已删除',
    PRIMARY KEY (id),
    UNIQUE KEY uk_dev_metric_device_code (device_id, metric_code),
    KEY idx_dev_metric_device (device_id),
    KEY idx_dev_metric_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='设备监测指标定义';

CREATE TABLE IF NOT EXISTS dev_metric_data (
    id BIGINT NOT NULL COMMENT '主键',
    device_id BIGINT NOT NULL COMMENT '设备ID',
    metric_id BIGINT NOT NULL COMMENT '指标ID',
    numeric_value DECIMAL(18,6) NULL COMMENT '数值型值',
    text_value VARCHAR(255) NULL COMMENT '文本型值',
    boolean_value TINYINT NULL COMMENT '布尔型值',
    quality VARCHAR(32) NOT NULL DEFAULT 'GOOD' COMMENT 'GOOD/UNCERTAIN/BAD',
    collect_time DATETIME NOT NULL COMMENT '采集时间',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    PRIMARY KEY (id),
    KEY idx_dev_metric_data_device_time (device_id, collect_time),
    KEY idx_dev_metric_data_metric_time (metric_id, collect_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='设备监测数据';

CREATE TABLE IF NOT EXISTS dev_sop (
    id BIGINT NOT NULL COMMENT '主键',
    sop_code VARCHAR(64) NOT NULL COMMENT 'SOP编码',
    title VARCHAR(128) NOT NULL COMMENT '标题',
    category_id BIGINT NULL COMMENT '设备分类ID',
    device_id BIGINT NULL COMMENT '设备ID',
    sop_type VARCHAR(32) NOT NULL COMMENT 'INSPECTION/MAINTENANCE/SAFETY',
    version VARCHAR(32) NOT NULL COMMENT '版本',
    content LONGTEXT NOT NULL COMMENT 'SOP内容',
    status VARCHAR(32) NOT NULL COMMENT 'DRAFT/EFFECTIVE/DISABLED',
    effective_date DATE NULL COMMENT '生效日期',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    deleted TINYINT NOT NULL DEFAULT 0 COMMENT '0正常，1已删除',
    PRIMARY KEY (id),
    UNIQUE KEY uk_dev_sop_code (sop_code),
    KEY idx_dev_sop_category (category_id),
    KEY idx_dev_sop_device (device_id),
    KEY idx_dev_sop_type_status (sop_type, status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='标准作业程序';
