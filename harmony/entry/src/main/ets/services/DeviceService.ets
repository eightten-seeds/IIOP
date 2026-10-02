import { Device } from '../models/CommonModels';
import { ApiClient } from '../network/ApiClient';

export class DeviceService {
  static detail(id: string): Promise<Device> { return ApiClient.get<Device>('/api/device/devices/' + id); }
}
