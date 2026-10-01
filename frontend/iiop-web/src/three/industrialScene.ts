import * as THREE from 'three';
import type { Device, DeviceStatus, RiskLevel } from '../types/device';

export type VisualDeviceType = 'CNC' | 'ROBOT' | 'MOTOR' | 'PUMP' | 'CABINET' | 'GENERIC';

const steel = 0x59636f;
const steelDark = 0x303944;
const steelLight = 0x8a949f;
const panelDark = 0x17202a;

export const visualTypeLabel: Record<VisualDeviceType, string> = {
  CNC: '数控机床',
  ROBOT: '工业机器人',
  MOTOR: '工业电机',
  PUMP: '工业泵',
  CABINET: '配电柜',
  GENERIC: '通用工业设备'
};

export function statusColor(status: DeviceStatus) {
  if (status === 'ONLINE') return 0x36c98f;
  if (status === 'FAULT') return 0xff4d5e;
  if (status === 'MAINTENANCE') return 0xffb020;
  if (status === 'OFFLINE') return 0x7c8794;
  return 0x505862;
}

export function riskColor(risk: RiskLevel) {
  if (risk === 'CRITICAL') return 0xff3347;
  if (risk === 'HIGH') return 0xff7a22;
  if (risk === 'MEDIUM') return 0x3f8cff;
  return 0x36c98f;
}

export function inferDeviceType(device: Device, categoryName = ''): VisualDeviceType {
  const source = `${device.deviceName} ${device.model ?? ''} ${categoryName}`.toLowerCase();
  if (/cnc|数控|机床|加工中心|车床|铣床/.test(source)) return 'CNC';
  if (/robot|机器人|机械臂|机械手/.test(source)) return 'ROBOT';
  if (/motor|电机|马达/.test(source)) return 'MOTOR';
  if (/pump|泵|水泵|离心/.test(source)) return 'PUMP';
  if (/cabinet|配电|电柜|控制柜|开关柜/.test(source)) return 'CABINET';
  return 'GENERIC';
}

function standardMaterial(color = steel, options: THREE.MeshStandardMaterialParameters = {}) {
  return new THREE.MeshStandardMaterial({ color, roughness: 0.62, metalness: 0.48, ...options });
}

function box(
  group: THREE.Group,
  size: [number, number, number],
  position: [number, number, number],
  color = steel,
  options: THREE.MeshStandardMaterialParameters = {}
) {
  const mesh = new THREE.Mesh(new THREE.BoxGeometry(...size), standardMaterial(color, options));
  mesh.position.set(...position);
  mesh.castShadow = true;
  mesh.receiveShadow = true;
  group.add(mesh);
  return mesh;
}

function cylinder(
  group: THREE.Group,
  radius: number,
  length: number,
  position: [number, number, number],
  color = steel,
  rotation: [number, number, number] = [0, 0, 0]
) {
  const mesh = new THREE.Mesh(new THREE.CylinderGeometry(radius, radius, length, 18), standardMaterial(color));
  mesh.position.set(...position);
  mesh.rotation.set(...rotation);
  mesh.castShadow = true;
  mesh.receiveShadow = true;
  group.add(mesh);
  return mesh;
}

function armSegment(group: THREE.Group, start: THREE.Vector3, end: THREE.Vector3, radius: number, color: number) {
  const direction = end.clone().sub(start);
  const mesh = new THREE.Mesh(new THREE.CylinderGeometry(radius, radius, direction.length(), 16), standardMaterial(color));
  mesh.position.copy(start).add(end).multiplyScalar(0.5);
  mesh.quaternion.setFromUnitVectors(new THREE.Vector3(0, 1, 0), direction.normalize());
  mesh.castShadow = true;
  group.add(mesh);
  return mesh;
}

function addCnc(group: THREE.Group) {
  box(group, [3.8, 2.8, 2.7], [0, 1.6, 0], steelDark);
  box(group, [2.25, 2.05, 0.12], [-0.42, 1.65, 1.41], steelLight);
  box(group, [1.3, 1.25, 0.08], [-0.62, 1.72, 1.49], 0x183141, { emissive: 0x0b2433, emissiveIntensity: 0.25 });
  box(group, [0.7, 1.75, 0.28], [1.42, 1.7, 1.48], 0x27323d);
  for (let index = 0; index < 4; index += 1) {
    cylinder(group, 0.075, 0.08, [1.42, 2.25 - index * 0.28, 1.66], index === 0 ? 0xd84848 : 0x6e7882, [Math.PI / 2, 0, 0]);
  }
  box(group, [3.95, 0.18, 2.85], [0, 0.16, 0], 0x252d35);
}

function addRobot(group: THREE.Group) {
  cylinder(group, 0.9, 0.35, [0, 0.25, 0], steelDark);
  cylinder(group, 0.58, 0.72, [0, 0.72, 0], 0xd68a22);
  const shoulder = new THREE.Vector3(0, 1.05, 0);
  const elbow = new THREE.Vector3(0.35, 2.45, 0.08);
  const wrist = new THREE.Vector3(1.38, 3.25, 0.15);
  armSegment(group, shoulder, elbow, 0.34, 0xc98322);
  armSegment(group, elbow, wrist, 0.27, 0xd99a35);
  [shoulder, elbow, wrist].forEach((point, index) => {
    const joint = new THREE.Mesh(new THREE.SphereGeometry(index === 1 ? 0.43 : 0.34, 18, 14), standardMaterial(index === 1 ? steelDark : 0xc98322));
    joint.position.copy(point);
    joint.castShadow = true;
    group.add(joint);
  });
  const claw = box(group, [0.18, 0.65, 0.18], [1.55, 3.42, 0.15], steelLight);
  claw.rotation.z = -0.5;
}

function addMotor(group: THREE.Group) {
  box(group, [3.5, 0.28, 2.1], [0, 0.2, 0], steelDark);
  cylinder(group, 1.05, 2.6, [0, 1.25, 0], 0x4f6875, [0, 0, Math.PI / 2]);
  cylinder(group, 0.48, 0.48, [1.5, 1.25, 0], steelLight, [0, 0, Math.PI / 2]);
  cylinder(group, 0.19, 0.75, [1.98, 1.25, 0], 0xb7bec4, [0, 0, Math.PI / 2]);
  for (let index = -4; index <= 4; index += 1) {
    box(group, [0.08, 2.28, 2.18], [index * 0.24, 1.25, 0], 0x405765);
  }
  box(group, [0.85, 0.6, 0.9], [-0.35, 2.3, 0], 0x394650);
}

function addPump(group: THREE.Group) {
  box(group, [3.6, 0.28, 2.3], [0, 0.2, 0], steelDark);
  cylinder(group, 1.0, 0.9, [-0.7, 1.25, 0], 0x526773, [Math.PI / 2, 0, 0]);
  cylinder(group, 0.42, 1.4, [0.88, 1.1, 0], 0x65727d, [0, 0, Math.PI / 2]);
  cylinder(group, 0.27, 1.7, [-0.7, 2.42, 0], 0x7b8791);
  cylinder(group, 0.27, 1.4, [-1.72, 1.25, 0], 0x7b8791, [0, 0, Math.PI / 2]);
  cylinder(group, 0.55, 0.25, [-0.7, 3.23, 0], steelLight);
}

function addCabinet(group: THREE.Group) {
  box(group, [2.8, 3.8, 1.7], [0, 2.0, 0], 0x424c57);
  box(group, [1.22, 3.45, 0.1], [-0.66, 2.0, 0.9], 0x5f6b76);
  box(group, [1.22, 3.45, 0.1], [0.66, 2.0, 0.9], 0x5f6b76);
  box(group, [0.08, 0.5, 0.08], [-0.18, 2.0, 0.98], 0xc5cbd0);
  for (let index = 0; index < 6; index += 1) box(group, [2.35, 0.06, 0.08], [0, 0.65 + index * 0.16, 0.98], 0x202832);
  box(group, [3.0, 0.16, 1.9], [0, 0.12, 0], steelDark);
}

function addGeneric(group: THREE.Group) {
  box(group, [3.4, 2.25, 2.4], [0, 1.25, 0], steel);
  box(group, [2.6, 1.05, 0.1], [0, 1.48, 1.25], panelDark, { emissive: 0x0b1924, emissiveIntensity: 0.18 });
  box(group, [3.65, 0.2, 2.65], [0, 0.14, 0], steelDark);
  for (const x of [-1.35, 1.35]) for (const z of [-0.88, 0.88]) cylinder(group, 0.11, 0.25, [x, 0.35, z], steelLight);
}

function addStateVisual(group: THREE.Group, device: Device) {
  const color = statusColor(device.status);
  const lightMaterial = new THREE.MeshStandardMaterial({
    color,
    emissive: color,
    emissiveIntensity: device.status === 'OFFLINE' || device.status === 'SCRAPPED' ? 0.18 : 1.2,
    roughness: 0.22,
    metalness: 0.18
  });
  const beacon = new THREE.Mesh(new THREE.CylinderGeometry(0.22, 0.22, 0.42, 16), lightMaterial);
  beacon.position.set(0, 4.25, 0);
  beacon.userData.statusSurface = true;
  group.add(beacon);

  const band = new THREE.Mesh(new THREE.BoxGeometry(3.8, 0.1, 2.75), lightMaterial.clone());
  band.position.y = 0.08;
  band.userData.statusSurface = true;
  group.add(band);

  if (device.riskLevel === 'HIGH' || device.riskLevel === 'CRITICAL') {
    const risk = riskColor(device.riskLevel);
    const marker = new THREE.Mesh(
      new THREE.ConeGeometry(0.34, 0.62, 3),
      new THREE.MeshStandardMaterial({ color: risk, emissive: risk, emissiveIntensity: 0.72 })
    );
    marker.position.set(1.55, 3.85, 0);
    marker.rotation.z = Math.PI;
    marker.userData.statusSurface = true;
    group.add(marker);
  }
}

function createNameplate(device: Device) {
  const canvas = document.createElement('canvas');
  canvas.width = 384;
  canvas.height = 96;
  const context = canvas.getContext('2d');
  if (context) {
    context.fillStyle = 'rgba(15, 22, 29, .92)';
    context.fillRect(0, 0, canvas.width, canvas.height);
    context.fillStyle = '#dce4ea';
    context.font = '600 25px "Microsoft YaHei", sans-serif';
    context.textAlign = 'center';
    context.fillText(device.deviceName.slice(0, 16), 192, 39);
    context.fillStyle = '#7f95a6';
    context.font = '18px "Microsoft YaHei", sans-serif';
    context.fillText(device.deviceCode, 192, 70);
  }
  const texture = new THREE.CanvasTexture(canvas);
  texture.colorSpace = THREE.SRGBColorSpace;
  const sprite = new THREE.Sprite(new THREE.SpriteMaterial({ map: texture, transparent: true, depthTest: false }));
  sprite.position.set(0, 5.05, 0);
  sprite.scale.set(4.8, 1.2, 1);
  return sprite;
}

export function buildDeviceVisual(device: Device, type: VisualDeviceType, position: THREE.Vector3, unlocated: boolean) {
  const group = new THREE.Group();
  group.name = `device_${device.id}`;
  group.position.copy(position);
  group.userData = { device, type, unlocated };

  if (type === 'CNC') addCnc(group);
  else if (type === 'ROBOT') addRobot(group);
  else if (type === 'MOTOR') addMotor(group);
  else if (type === 'PUMP') addPump(group);
  else if (type === 'CABINET') addCabinet(group);
  else addGeneric(group);

  addStateVisual(group, device);
  group.add(createNameplate(device));

  const outline = new THREE.LineSegments(
    new THREE.EdgesGeometry(new THREE.BoxGeometry(4.5, 5.2, 3.4)),
    new THREE.LineBasicMaterial({ color: 0x58b9ff, transparent: true, opacity: 0.95 })
  );
  outline.position.y = 2.55;
  outline.visible = false;
  outline.userData.outline = true;
  group.add(outline);

  if (device.status === 'OFFLINE' || device.status === 'SCRAPPED') {
    group.traverse((child) => {
      if (child instanceof THREE.Mesh && child.material instanceof THREE.MeshStandardMaterial && !child.userData.statusSurface) {
        child.material.color.multiplyScalar(0.62);
        child.material.roughness = 0.82;
      }
    });
  }

  group.traverse((child) => {
    if (child instanceof THREE.Mesh) child.userData.device = device;
  });
  return group;
}

function floorRect(scene: THREE.Scene, width: number, depth: number, x: number, z: number, color: number) {
  const mesh = new THREE.Mesh(new THREE.PlaneGeometry(width, depth), standardMaterial(color, { roughness: 0.9, metalness: 0.05 }));
  mesh.rotation.x = -Math.PI / 2;
  mesh.position.set(x, 0.012, z);
  mesh.receiveShadow = true;
  scene.add(mesh);
}

function zoneOutline(scene: THREE.Scene, width: number, depth: number, x: number, z: number, color: number) {
  const points = [
    new THREE.Vector3(x - width / 2, 0.035, z - depth / 2),
    new THREE.Vector3(x + width / 2, 0.035, z - depth / 2),
    new THREE.Vector3(x + width / 2, 0.035, z + depth / 2),
    new THREE.Vector3(x - width / 2, 0.035, z + depth / 2),
    new THREE.Vector3(x - width / 2, 0.035, z - depth / 2)
  ];
  scene.add(new THREE.Line(new THREE.BufferGeometry().setFromPoints(points), new THREE.LineBasicMaterial({ color })));
}

function labelSprite(text: string, accent: string) {
  const canvas = document.createElement('canvas');
  canvas.width = 512;
  canvas.height = 112;
  const context = canvas.getContext('2d');
  if (context) {
    context.fillStyle = 'rgba(24, 31, 38, .9)';
    context.fillRect(0, 0, 512, 112);
    context.fillStyle = accent;
    context.fillRect(0, 0, 10, 112);
    context.fillStyle = '#e5ebef';
    context.font = '600 34px "Microsoft YaHei", sans-serif';
    context.textAlign = 'center';
    context.fillText(text, 264, 70);
  }
  const texture = new THREE.CanvasTexture(canvas);
  texture.colorSpace = THREE.SRGBColorSpace;
  const sprite = new THREE.Sprite(new THREE.SpriteMaterial({ map: texture, transparent: true }));
  sprite.scale.set(10, 2.2, 1);
  return sprite;
}

function addBarrier(scene: THREE.Scene, startX: number, endX: number, z: number) {
  const material = standardMaterial(0xd49a2f, { metalness: 0.3, roughness: 0.55 });
  for (let x = startX; x <= endX; x += 4) {
    const post = new THREE.Mesh(new THREE.CylinderGeometry(0.09, 0.09, 1.35, 10), material.clone());
    post.position.set(x, 0.68, z);
    post.castShadow = true;
    scene.add(post);
  }
  for (const height of [0.55, 1.15]) {
    const rail = new THREE.Mesh(new THREE.CylinderGeometry(0.065, 0.065, endX - startX, 10), material.clone());
    rail.rotation.z = Math.PI / 2;
    rail.position.set((startX + endX) / 2, height, z);
    scene.add(rail);
  }
}

export function buildIndustrialEnvironment(scene: THREE.Scene, unlocatedZoneX: number) {
  floorRect(scene, 112, 74, 8, 0, 0x20272d);
  floorRect(scene, 68, 52, -10, 0, 0x293239);
  floorRect(scene, 26, 52, unlocatedZoneX, 0, 0x252b30);
  zoneOutline(scene, 68, 52, -10, 0, 0x52616d);
  zoneOutline(scene, 26, 52, unlocatedZoneX, 0, 0xd49a2f);

  const grid = new THREE.GridHelper(112, 56, 0x394650, 0x303940);
  grid.position.y = 0.025;
  scene.add(grid);

  for (const z of [-29, 29]) floorRect(scene, 112, 0.45, 8, z, 0xd0a230);
  for (let x = -45; x < 55; x += 5) floorRect(scene, 2.6, 0.65, x, -24, 0xc79b2d);
  for (const x of [-45, 15, 23, 55]) floorRect(scene, 0.28, 52, x, 0, 0xd0a230);

  addBarrier(scene, -42, 12, -21.5);
  addBarrier(scene, 25, 53, 21.5);

  for (const z of [-14, 0, 14]) {
    const cabinet = new THREE.Group();
    box(cabinet, [2.4, 3.5, 1.25], [0, 1.78, 0], 0x3b454e);
    box(cabinet, [1.95, 2.95, 0.08], [0, 1.78, 0.67], 0x59636c);
    cabinet.position.set(-50, 0, z);
    scene.add(cabinet);
  }

  const locatedLabel = labelSprite('已定位设备作业区', '#6f8797');
  locatedLabel.position.set(-10, 7, -27);
  scene.add(locatedLabel);
  const unlocatedLabel = labelSprite('未定位设备区 · 视觉排列', '#d49a2f');
  unlocatedLabel.position.set(unlocatedZoneX, 7, -27);
  scene.add(unlocatedLabel);
}
