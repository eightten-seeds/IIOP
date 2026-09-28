-- IIOP M1: iiop_ai 数据库表结构
USE iiop_ai;

CREATE TABLE IF NOT EXISTS ai_diagnosis (
    id BIGINT NOT NULL COMMENT '主键',
    diagnosis_code VARCHAR(64) NOT NULL COMMENT '诊断编码',
    trigger_type VARCHAR(32) NOT NULL COMMENT 'INSPECTION_ABNORMAL/ALARM/MANUAL',
    trigger_id BIGINT NULL COMMENT '触发来源ID，MANUAL时为空',
    device_id BIGINT NOT NULL COMMENT '设备ID',
    abnormal_summary VARCHAR(2000) NOT NULL COMMENT '异常摘要',
    user_description VARCHAR(2000) NULL COMMENT '用户描述',
    risk_level VARCHAR(32) NULL COMMENT 'LOW/MEDIUM/HIGH/CRITICAL',
    possible_causes JSON NULL COMMENT '可能原因列表',
    investigation_steps JSON NULL COMMENT '排查步骤列表',
    maintenance_advice LONGTEXT NULL COMMENT '维修建议',
    safety_notice VARCHAR(2000) NULL COMMENT '安全提示',
    context_snapshot JSON NULL COMMENT '诊断上下文快照',
    model_name VARCHAR(128) NULL COMMENT '模型名称',
    prompt_version VARCHAR(64) NULL COMMENT 'Prompt版本',
    diagnosis_status VARCHAR(32) NOT NULL COMMENT 'PENDING/RUNNING/SUCCEEDED/FAILED',
    confirmation_status VARCHAR(32) NOT NULL COMMENT 'PENDING/CONFIRMED/REJECTED',
    confirmed_by BIGINT NULL COMMENT '确认人用户ID',
    confirmed_at DATETIME NULL COMMENT '确认时间',
    confirmation_comment VARCHAR(1000) NULL COMMENT '确认说明',
    error_message VARCHAR(2000) NULL COMMENT '错误信息',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    PRIMARY KEY (id),
    UNIQUE KEY uk_ai_diagnosis_code (diagnosis_code),
    UNIQUE KEY uk_ai_diagnosis_trigger (trigger_type, trigger_id),
    KEY idx_ai_diagnosis_device_time (device_id, created_at),
    KEY idx_ai_diagnosis_status (diagnosis_status),
    KEY idx_ai_diagnosis_confirmation (confirmation_status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='AI诊断';

CREATE TABLE IF NOT EXISTS ai_workflow_trace (
    id BIGINT NOT NULL COMMENT '主键',
    diagnosis_id BIGINT NOT NULL COMMENT '诊断ID',
    node_code VARCHAR(64) NOT NULL COMMENT '节点编码',
    node_name VARCHAR(128) NOT NULL COMMENT '节点名称',
    node_status VARCHAR(32) NOT NULL COMMENT 'PENDING/RUNNING/SUCCEEDED/FAILED/SKIPPED',
    input_summary VARCHAR(2000) NULL COMMENT '输入摘要',
    output_data JSON NULL COMMENT '节点输出',
    error_message VARCHAR(2000) NULL COMMENT '错误信息',
    started_at DATETIME NULL COMMENT '开始时间',
    finished_at DATETIME NULL COMMENT '结束时间',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    PRIMARY KEY (id),
    KEY idx_ai_workflow_trace_diagnosis_time (diagnosis_id, created_at),
    KEY idx_ai_workflow_trace_diagnosis_node (diagnosis_id, node_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='AI工作流轨迹';

-- LangGraph4j 第一版固定节点：
-- LOAD_CONTEXT -> ANALYZE_WITH_DEEPSEEK -> RISK_CHECK -> GENERATE_ADVICE -> PREPARE_WORK_ORDER_DRAFT
