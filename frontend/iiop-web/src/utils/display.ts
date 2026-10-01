const labels:Record<string,string>={
  SUPER_ADMIN:'超级管理员',ADMIN:'业务管理员',INSPECTOR:'巡检人员',MAINTAINER:'维修人员',
  ENABLED:'启用',DISABLED:'停用',LOCKED:'锁定',ONLINE:'在线',OFFLINE:'离线',FAULT:'故障',MAINTENANCE:'维护中',SCRAPPED:'已报废',
  LOW:'低风险',MEDIUM:'中风险',HIGH:'高风险',CRITICAL:'严重风险',
  READ:'已读',UNREAD:'未读',PASS:'通过',REJECT:'驳回',PENDING:'待处理',UNKNOWN:'待判定',OPEN:'待处理',CANCELLED:'已取消',PROCESSING:'处理中',COMPLETED:'已完成',CLOSED:'已关闭',RESOLVED:'已解决',
  WAITING_ACCEPTANCE:'待验收',ACCEPTED:'已验收',CREATED:'已创建',IN_PROGRESS:'进行中',SUCCEEDED:'成功',FAILED:'失败',CONFIRMED:'已确认',REJECTED:'已拒绝',
  MENU:'菜单',BUTTON:'按钮',API:'接口',NUMBER:'数值',BOOLEAN:'正常/异常',TEXT:'文本',PHOTO:'图片',DRAFT:'草稿',EFFECTIVE:'生效',
  DAILY:'每日',WEEKLY:'每周',MONTHLY:'每月',CRON:'CRON 表达式',NORMAL:'正常',ABNORMAL:'异常',
  INSPECTION:'巡检',INSPECTION_ABNORMAL:'巡检异常',SAFETY:'安全'
};
export const displayValue=(value:unknown)=>labels[String(value)]??String(value??'-');
