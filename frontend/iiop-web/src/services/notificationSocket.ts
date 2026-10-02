import { ElNotification } from 'element-plus';
import router from '../router';
import { useAuthStore } from '../stores/auth';

export interface NotificationMessage {
  id: string;
  notificationType: string;
  title: string;
  content: string;
  bizType?: string | null;
  bizId?: string | null;
  readStatus: string;
  readTime?: string | null;
  createdAt: string;
}

type MessageListener = (msg: NotificationMessage) => void;
export type ConnectionState = 'connecting' | 'connected' | 'disconnected';
type StateListener = (state: ConnectionState) => void;

class NotificationSocketService {
  private socket: WebSocket | null = null;
  private reconnectTimer: number | null = null;
  private reconnectDelay = 1000;
  private intentionalClose = false;
  private listeners: Set<MessageListener> = new Set();
  private currentToken: string | null = null;
  private state: ConnectionState = 'disconnected';
  private stateListeners: Set<StateListener> = new Set();

  public subscribe(listener: MessageListener): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  public subscribeState(listener: StateListener): () => void {
    this.stateListeners.add(listener);
    listener(this.state);
    return () => this.stateListeners.delete(listener);
  }

  public connect(token: string) {
    if (!token) return;
    if (this.socket && this.socket.readyState === WebSocket.OPEN && this.currentToken === token) {
      return;
    }
    this.intentionalClose = false;
    this.currentToken = token;
    this.setState('connecting');

    if (this.socket) {
      try {
        this.socket.close();
      } catch {
        // ignore
      }
      this.socket = null;
    }

    if (this.reconnectTimer) {
      window.clearTimeout(this.reconnectTimer);
      this.reconnectTimer = null;
    }

    const wsUrl = this.buildWebSocketUrl(token);
    try {
      this.socket = new WebSocket(wsUrl);
    } catch {
      this.scheduleReconnect();
      return;
    }

    this.socket.onopen = () => {
      this.reconnectDelay = 1000;
      this.setState('connected');
    };

    this.socket.onmessage = (event) => {
      try {
        const data = JSON.parse(event.data) as NotificationMessage;
        this.handleMessage(data);
      } catch {
        // ignore non-json messages
      }
    };

    this.socket.onerror = () => {
      // silent to avoid exposing url with token
    };

    this.socket.onclose = () => {
      this.socket = null;
      this.setState('disconnected');
      if (!this.intentionalClose) {
        this.scheduleReconnect();
      }
    };
  }

  public close() {
    this.intentionalClose = true;
    this.currentToken = null;
    this.setState('disconnected');
    if (this.reconnectTimer) {
      window.clearTimeout(this.reconnectTimer);
      this.reconnectTimer = null;
    }
    if (this.socket) {
      try {
        this.socket.close();
      } catch {
        // ignore
      }
      this.socket = null;
    }
  }

  private scheduleReconnect() {
    if (this.intentionalClose || !this.currentToken) return;
    if (this.reconnectTimer) return;

    this.reconnectTimer = window.setTimeout(() => {
      this.reconnectTimer = null;
      if (!this.intentionalClose && this.currentToken) {
        this.connect(this.currentToken);
        this.reconnectDelay = Math.min(this.reconnectDelay * 2, 30000);
      }
    }, this.reconnectDelay);
  }

  private buildWebSocketUrl(token: string): string {
    const rawGateway = import.meta.env.VITE_GATEWAY_URL || 'http://127.0.0.1:8080';
    let baseWs: string;
    if (rawGateway.startsWith('http://')) {
      baseWs = rawGateway.replace('http://', 'ws://');
    } else if (rawGateway.startsWith('https://')) {
      baseWs = rawGateway.replace('https://', 'wss://');
    } else if (rawGateway.startsWith('ws://') || rawGateway.startsWith('wss://')) {
      baseWs = rawGateway;
    } else {
      const isHttps = window.location.protocol === 'https:';
      baseWs = `${isHttps ? 'wss://' : 'ws://'}${window.location.host}`;
    }
    const cleanBase = baseWs.replace(/\/+$/, '');
    return `${cleanBase}/ws/notifications?token=${encodeURIComponent(token)}`;
  }

  private handleMessage(msg: NotificationMessage) {
    const auth = useAuthStore();
    if (msg.readStatus !== 'EPHEMERAL') void auth.refreshUnread();

    this.listeners.forEach((fn) => {
      try {
        fn(msg);
      } catch {
        // ignore
      }
    });

    if (msg.notificationType === 'AI_WORKFLOW') return;
    const bizRoute = this.resolveBizRoute(msg.bizType, msg.bizId);
    ElNotification({
      title: msg.title || '系统通知',
      message: msg.content || '您收到一条新业务通知',
      type: 'info',
      duration: 6000,
      onClick: () => {
        if (bizRoute) {
          void router.push(bizRoute);
        } else {
          void router.push('/notifications');
        }
      }
    });
  }

  private setState(state: ConnectionState) {
    if (this.state === state) return;
    this.state = state;
    this.stateListeners.forEach((listener) => listener(state));
  }

  public resolveBizRoute(bizType?: string | null, bizId?: string | null): string | null {
    if (!bizType || !bizId) return null;
    switch (bizType) {
      case 'WORK_ORDER':
        return `/maintenance/work-orders/${bizId}`;
      case 'DEFECT':
        return `/maintenance/defects/${bizId}`;
      case 'INSPECTION_TASK':
        return `/inspection/tasks/${bizId}`;
      case 'INSPECTION_ABNORMAL':
        return `/inspection/abnormals/${bizId}`;
      case 'AI_DIAGNOSIS':
        return `/ai/diagnoses/${bizId}`;
      case 'DEVICE':
        return `/devices/${bizId}`;
      default:
        return null;
    }
  }
}

export const notificationSocket = new NotificationSocketService();
