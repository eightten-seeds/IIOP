const labels:Record<string,string>={
  SUPER_ADMIN:'超级管理员',ADMIN:'业务管理员',INSPECTOR:'巡检人员',MAINTAINER:'维修人员',
  ENABLED:'启用',DISABLED:'停用',LOCKED:'锁定',ONLINE:'在线',OFFLINE:'离线',FAULT:'故障',MAINTENANCE:'维修中',
  LOW:'低风险',MEDIUM:'中风险',HIGH:'高风险',CRITICAL:'严重风险',
  READ:'已读',UNREAD:'未读',PASS:'通过',REJECT:'驳回',PENDING:'待处理',PROCESSING:'处理中',COMPLETED:'已完成',
  WAITING_ACCEPTANCE:'待验收',ACCEPTED:'已验收',CREATED:'已创建',IN_PROGRESS:'进行中'
};
export const displayValue=(value:unknown)=>labels[String(value)]??String(value??'-');
