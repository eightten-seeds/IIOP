export function statusText(value: string): string {
  if (value === 'PENDING') return '待处理'; if (value === 'IN_PROGRESS') return '巡检中'; if (value === 'COMPLETED') return '已完成';
  if (value === 'ASSIGNED') return '待开工'; if (value === 'PROCESSING') return '维修中 / 返修'; if (value === 'WAITING_ACCEPTANCE') return '待验收';
  if (value === 'NORMAL') return '正常'; if (value === 'ABNORMAL') return '异常'; if (value === 'SUCCEEDED') return '诊断完成'; if (value === 'FAILED') return '诊断未完成'; if (value === 'RUNNING') return '正在分析';
  if (value === 'LOW') return '低风险'; if (value === 'MEDIUM') return '中风险'; if (value === 'HIGH') return '高风险'; if (value === 'CRITICAL') return '严重风险';
  return value;
}

export function formatTime(value?: string): string { return value === undefined || value.length === 0 ? '—' : value.replace('T', ' ').substring(0, 16); }
