export function statusText(value: string): string {
  if (value === 'PENDING') return '待处理'; if (value === 'IN_PROGRESS') return '巡检中'; if (value === 'COMPLETED') return '已完成';
  if (value === 'ASSIGNED') return '待开工'; if (value === 'PROCESSING') return '维修中'; if (value === 'WAITING_ACCEPTANCE') return '待验收';
  if (value === 'NORMAL') return '正常'; if (value === 'ABNORMAL') return '异常';
  if (value === 'SUCCESS') return '修复成功'; if (value === 'PARTIAL') return '部分修复'; if (value === 'FAILED') return '失败';
  if (value === 'PASSED') return '验收通过'; if (value === 'REJECTED') return '验收驳回';
  if (value === 'SUCCEEDED') return '诊断完成'; if (value === 'RUNNING') return '正在分析'; if (value === 'SKIPPED') return '已跳过';
  if (value === 'LOW') return '低风险'; if (value === 'MEDIUM') return '中风险'; if (value === 'HIGH') return '高风险'; if (value === 'CRITICAL') return '严重风险'; if (value === 'URGENT') return '紧急';
  return '未知状态';
}

export function formatTime(value?: string): string { return value === undefined || value.length === 0 ? '—' : value.replace('T', ' ').substring(0, 16); }
