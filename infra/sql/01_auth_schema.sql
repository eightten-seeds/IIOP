-- IIOP M1: iiop_auth 数据库表结构
USE iiop_auth;

CREATE TABLE IF NOT EXISTS sys_user (
    id BIGINT NOT NULL COMMENT '主键',
    username VARCHAR(64) NOT NULL COMMENT '登录账号',
    password_hash VARCHAR(255) NOT NULL COMMENT '密码哈希，不允许明文密码',
    real_name VARCHAR(64) NULL COMMENT '展示姓名',
    phone VARCHAR(32) NULL COMMENT '手机号',
    email VARCHAR(128) NULL COMMENT '邮箱',
    avatar_url VARCHAR(512) NULL COMMENT '头像地址',
    status VARCHAR(32) NOT NULL DEFAULT 'ENABLED' COMMENT 'ENABLED/DISABLED/LOCKED',
    last_login_time DATETIME NULL COMMENT '最近登录时间',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    deleted TINYINT NOT NULL DEFAULT 0 COMMENT '0正常，1已删除',
    PRIMARY KEY (id),
    UNIQUE KEY uk_sys_user_username (username),
    KEY idx_sys_user_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='系统用户';

CREATE TABLE IF NOT EXISTS sys_role (
    id BIGINT NOT NULL COMMENT '主键',
    role_code VARCHAR(64) NOT NULL COMMENT '角色编码',
    role_name VARCHAR(64) NOT NULL COMMENT '角色名称',
    description VARCHAR(255) NULL COMMENT '角色描述',
    status VARCHAR(32) NOT NULL DEFAULT 'ENABLED' COMMENT '状态',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    deleted TINYINT NOT NULL DEFAULT 0 COMMENT '0正常，1已删除',
    PRIMARY KEY (id),
    UNIQUE KEY uk_sys_role_code (role_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='系统角色';

CREATE TABLE IF NOT EXISTS sys_permission (
    id BIGINT NOT NULL COMMENT '主键',
    parent_id BIGINT NULL COMMENT '父权限ID',
    permission_code VARCHAR(128) NOT NULL COMMENT '权限编码',
    permission_name VARCHAR(128) NOT NULL COMMENT '权限名称',
    permission_type VARCHAR(32) NOT NULL COMMENT 'MENU/BUTTON/API',
    route_path VARCHAR(255) NULL COMMENT 'PC路由',
    api_path VARCHAR(255) NULL COMMENT 'API路径',
    http_method VARCHAR(16) NULL COMMENT 'HTTP方法',
    sort_order INT NOT NULL COMMENT '排序',
    status VARCHAR(32) NOT NULL COMMENT 'ENABLED/DISABLED',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    deleted TINYINT NOT NULL DEFAULT 0 COMMENT '0正常，1已删除',
    PRIMARY KEY (id),
    UNIQUE KEY uk_sys_permission_code (permission_code),
    KEY idx_sys_permission_parent (parent_id),
    KEY idx_sys_permission_type (permission_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='系统权限';

CREATE TABLE IF NOT EXISTS sys_user_role (
    id BIGINT NOT NULL COMMENT '主键',
    user_id BIGINT NOT NULL COMMENT '用户ID',
    role_id BIGINT NOT NULL COMMENT '角色ID',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    PRIMARY KEY (id),
    UNIQUE KEY uk_sys_user_role (user_id, role_id),
    KEY idx_sys_user_role_role (role_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='用户角色关联';

CREATE TABLE IF NOT EXISTS sys_role_permission (
    id BIGINT NOT NULL COMMENT '主键',
    role_id BIGINT NOT NULL COMMENT '角色ID',
    permission_id BIGINT NOT NULL COMMENT '权限ID',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    PRIMARY KEY (id),
    UNIQUE KEY uk_sys_role_permission (role_id, permission_id),
    KEY idx_sys_role_permission_permission (permission_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='角色权限关联';

CREATE TABLE IF NOT EXISTS sys_notification (
    id BIGINT NOT NULL COMMENT '主键',
    recipient_user_id BIGINT NOT NULL COMMENT '接收人用户ID',
    notification_type VARCHAR(32) NOT NULL COMMENT 'ALARM/INSPECTION/WORK_ORDER/AI/SYSTEM',
    title VARCHAR(128) NOT NULL COMMENT '标题',
    content VARCHAR(1000) NOT NULL COMMENT '内容',
    biz_type VARCHAR(64) NULL COMMENT '关联业务类型',
    biz_id BIGINT NULL COMMENT '关联业务ID',
    read_status VARCHAR(16) NOT NULL COMMENT 'UNREAD/READ',
    read_time DATETIME NULL COMMENT '阅读时间',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    PRIMARY KEY (id),
    KEY idx_sys_notification_recipient (recipient_user_id, read_status, created_at),
    KEY idx_sys_notification_biz (biz_type, biz_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='用户通知';
