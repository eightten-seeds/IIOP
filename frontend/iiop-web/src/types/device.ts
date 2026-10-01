export type DeviceStatus = 'ONLINE' | 'OFFLINE' | 'FAULT' | 'MAINTENANCE' | 'SCRAPPED';
export type RiskLevel = 'LOW' | 'MEDIUM' | 'HIGH' | 'CRITICAL';

export interface Device {
  id: string;
  deviceCode: string;
  deviceName: string;
  categoryId: string;
  model: string | null;
  manufacturer: string | null;
  serialNumber: string | null;
  workshop: string | null;
  productionLine: string | null;
  installLocation: string | null;
  responsibleUserId: string | null;
  status: DeviceStatus;
  riskLevel: RiskLevel;
  installDate: string | null;
  warrantyExpireDate: string | null;
  modelUrl: string | null;
  positionX: number | null;
  positionY: number | null;
  positionZ: number | null;
  remark: string | null;
}

export type DeviceForm = Omit<Device, 'id'>;

export interface Category {
  id: string;
  parentId: string | null;
  categoryCode: string;
  categoryName: string;
  status: string;
}

export interface CategoryTree {
  category: Category;
  children: CategoryTree[];
}

export interface CategoryOption {
  value: string;
  label: string;
  disabled: boolean;
  children?: CategoryOption[];
}

export interface UserSummary {
  id: string;
  username: string;
  realName: string | null;
  status: string;
}

export interface Metric {
  id: string;
  metricCode: string;
  metricName: string;
  unit: string | null;
  valueType: string;
  warningLow: number | null;
  warningHigh: number | null;
  criticalLow: number | null;
  criticalHigh: number | null;
  status: string;
}

export interface Sop {
  id: string;
  sopCode: string;
  title: string;
  sopType: string;
  version: string;
  status: string;
  effectiveDate: string | null;
}

export interface PageResult<T> {
  current: number;
  size: number;
  total: number;
  records: T[];
}

export function emptyDeviceForm(): DeviceForm {
  return {
    deviceCode: '', deviceName: '', categoryId: '', model: '', manufacturer: '', serialNumber: '',
    workshop: '', productionLine: '', installLocation: '', responsibleUserId: null,
    status: 'OFFLINE', riskLevel: 'LOW', installDate: null, warrantyExpireDate: null,
    modelUrl: '', positionX: null, positionY: null, positionZ: null, remark: ''
  };
}

export function editableDeviceForm(device: Device): DeviceForm {
  return {
    deviceCode: device.deviceCode,
    deviceName: device.deviceName,
    categoryId: device.categoryId,
    model: device.model,
    manufacturer: device.manufacturer,
    serialNumber: device.serialNumber,
    workshop: device.workshop,
    productionLine: device.productionLine,
    installLocation: device.installLocation,
    responsibleUserId: device.responsibleUserId,
    status: device.status,
    riskLevel: device.riskLevel,
    installDate: device.installDate,
    warrantyExpireDate: device.warrantyExpireDate,
    modelUrl: device.modelUrl,
    positionX: device.positionX,
    positionY: device.positionY,
    positionZ: device.positionZ,
    remark: device.remark
  };
}

export function categoryOptions(nodes: CategoryTree[]): CategoryOption[] {
  return nodes.map((node) => ({
    value: node.category.id,
    label: `${node.category.categoryName}（${node.category.categoryCode}）`,
    disabled: node.category.status !== 'ENABLED',
    children: node.children?.length ? categoryOptions(node.children) : undefined
  }));
}

export function categoryNameMap(nodes: CategoryTree[], result: Record<string, string> = {}) {
  nodes.forEach((node) => {
    result[node.category.id] = node.category.categoryName;
    categoryNameMap(node.children ?? [], result);
  });
  return result;
}
