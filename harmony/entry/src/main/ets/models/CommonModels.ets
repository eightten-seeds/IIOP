export interface ApiEnvelope<T> { code: number; message?: string; msg?: string; data: T }
export interface PageResult<T> { current: number; size: number; total: number; records: T[] }
export interface CurrentUser { id: string; username: string; realName?: string; status: string }
export interface Identity { tokenValue?: string; user: CurrentUser; roles: string[]; permissions: string[] }
export interface Captcha { captchaId: string; image: string }
export interface Device { id: string; deviceCode: string; deviceName: string; installLocation?: string; workshop?: string; productionLine?: string; status: string; riskLevel: string }
export interface NotificationItem { id: string; title: string; content: string; bizType?: string; bizId?: string; readStatus: string; createdAt: string }
