<script setup lang="ts">
import { computed, nextTick, onMounted, onUnmounted, ref } from 'vue';
import { useRouter } from 'vue-router';
import * as THREE from 'three';
import { OrbitControls } from 'three/examples/jsm/controls/OrbitControls.js';
import { ArrowLeft, Aim, Refresh, Search, View } from '@element-plus/icons-vue';
import { ElMessage } from 'element-plus';
import { request } from '../api/request';
import { useAuthStore } from '../stores/auth';
import type { CategoryTree, Device, DeviceStatus, PageResult, RiskLevel } from '../types/device';
import type { InspectionAbnormal } from '../types/inspection';
import type { WorkOrder } from '../types/maintenance';
import { categoryNameMap } from '../types/device';
import { displayValue } from '../utils/display';
import { buildDeviceVisual, buildIndustrialEnvironment, inferDeviceType, riskColor, statusColor, visualTypeLabel, type VisualDeviceType } from '../three/industrialScene';

const router = useRouter();
const auth = useAuthStore();
const loading = ref(true), errorMessage = ref(''), devices = ref<Device[]>([]), categories = ref<Record<string, string>>({});
const selectedDevice = ref<Device | null>(null), hoveredDevice = ref<Device | null>(null), searchKeyword = ref(''), searchFocused = ref(false);
const tooltipX = ref(0), tooltipY = ref(0), latestAbnormal = ref<InspectionAbnormal | null>(null), currentWorkOrder = ref<WorkOrder | null>(null), detailLoading = ref(false);
const canvasContainer = ref<HTMLDivElement>();

let scene: THREE.Scene | null = null, camera: THREE.PerspectiveCamera | null = null, renderer: THREE.WebGLRenderer | null = null, controls: OrbitControls | null = null;
let animationFrame: number | null = null, resizeListening = false, eventCanvas: HTMLCanvasElement | null = null, pointerStart: { x: number; y: number } | null = null;
let cameraMotion: { startedAt: number; fromPosition: THREE.Vector3; toPosition: THREE.Vector3; fromTarget: THREE.Vector3; toTarget: THREE.Vector3 } | null = null;
const groupByDeviceId = new Map<string, THREE.Group>(), visualPositionById = new Map<string, THREE.Vector3>(), raycastTargets: THREE.Object3D[] = [];
const raycaster = new THREE.Raycaster(), pointer = new THREE.Vector2(), worldOrigin = new THREE.Vector3();
let worldScale = 1;
const unlocatedZoneX = 39;

const hasCoordinates = (device: Device) => device.positionX !== null && device.positionY !== null && device.positionZ !== null
  && [device.positionX, device.positionY, device.positionZ].every((value) => Number.isFinite(Number(value)));
const locatedDevices = computed(() => devices.value.filter(hasCoordinates));
const unlocatedDevices = computed(() => devices.value.filter((device) => !hasCoordinates(device)));
const searchResults = computed(() => { const keyword = searchKeyword.value.trim().toLowerCase(); return keyword ? devices.value.filter((device) => `${device.deviceName} ${device.deviceCode}`.toLowerCase().includes(keyword)).slice(0, 8) : []; });
const showSearchResults = computed(() => searchFocused.value && searchKeyword.value.trim().length > 0);
const selectedType = computed<VisualDeviceType>(() => selectedDevice.value ? inferDeviceType(selectedDevice.value, categories.value[selectedDevice.value.categoryId]) : 'GENERIC');
const selectedLocated = computed(() => selectedDevice.value ? hasCoordinates(selectedDevice.value) : false);
const statusSummary = computed(() => { const values: Record<string, number> = { ONLINE: 0, FAULT: 0, MAINTENANCE: 0, OFFLINE: 0 }; devices.value.forEach((device) => { if (device.status in values) values[device.status] += 1; }); return values; });

function statusTagType(status: DeviceStatus) { return status === 'ONLINE' ? 'success' : status === 'FAULT' ? 'danger' : status === 'MAINTENANCE' ? 'warning' : 'info'; }
function riskTagType(risk: RiskLevel) { return risk === 'CRITICAL' ? 'danger' : risk === 'HIGH' ? 'warning' : risk === 'MEDIUM' ? 'primary' : 'success'; }

function prepareWorldTransform() {
  if (!locatedDevices.value.length) { worldOrigin.set(0, 0, 0); worldScale = 1; return; }
  const xs = locatedDevices.value.map((device) => Number(device.positionX)), ys = locatedDevices.value.map((device) => Number(device.positionY)), zs = locatedDevices.value.map((device) => Number(device.positionZ));
  const minX = Math.min(...xs), maxX = Math.max(...xs), minY = Math.min(...ys), maxY = Math.max(...ys), minZ = Math.min(...zs), maxZ = Math.max(...zs);
  worldOrigin.set((minX + maxX) / 2, minY, (minZ + maxZ) / 2);
  worldScale = Math.min(2.5, 40 / Math.max(maxX - minX, maxY - minY, maxZ - minZ, 1));
}

function positionedDevice(device: Device, unlocatedIndex: number) {
  if (hasCoordinates(device)) return new THREE.Vector3((Number(device.positionX) - worldOrigin.x) * worldScale - 10, (Number(device.positionY) - worldOrigin.y) * worldScale, (Number(device.positionZ) - worldOrigin.z) * worldScale);
  return new THREE.Vector3(unlocatedZoneX - 7 + (unlocatedIndex % 3) * 7, 0, -17 + Math.floor(unlocatedIndex / 3) * 8);
}

function disposeMaterial(material: THREE.Material) { Object.values(material as THREE.Material & Record<string, unknown>).forEach((value) => { if (value instanceof THREE.Texture) value.dispose(); }); material.dispose(); }
function disposeScene() {
  if (animationFrame !== null) cancelAnimationFrame(animationFrame); animationFrame = null; cameraMotion = null;
  if (resizeListening) window.removeEventListener('resize', resizeScene); resizeListening = false;
  if (eventCanvas) { eventCanvas.removeEventListener('pointerdown', onPointerDown); eventCanvas.removeEventListener('pointerup', onPointerUp); eventCanvas.removeEventListener('pointermove', onPointerMove); eventCanvas.removeEventListener('pointerleave', onPointerLeave); }
  eventCanvas = null; controls?.dispose(); controls = null;
  scene?.traverse((object) => { const item = object as THREE.Object3D & { geometry?: THREE.BufferGeometry; material?: THREE.Material | THREE.Material[] }; item.geometry?.dispose(); if (Array.isArray(item.material)) item.material.forEach(disposeMaterial); else if (item.material) disposeMaterial(item.material); });
  scene?.clear(); scene = null;
  if (renderer) { const canvas = renderer.domElement; renderer.renderLists.dispose(); renderer.dispose(); renderer.forceContextLoss(); canvas.remove(); }
  renderer = null; camera = null; groupByDeviceId.clear(); visualPositionById.clear(); raycastTargets.splice(0); hoveredDevice.value = null;
}

function configureLights(target: THREE.Scene) {
  target.add(new THREE.HemisphereLight(0xc9d8e4, 0x161b20, 1.45));
  const key = new THREE.DirectionalLight(0xfff5df, 2.25); key.position.set(28, 42, 20); key.castShadow = true; key.shadow.mapSize.set(2048, 2048); Object.assign(key.shadow.camera, { left: -58, right: 58, top: 42, bottom: -42 }); target.add(key);
  const fill = new THREE.DirectionalLight(0x8fb9d8, 0.72); fill.position.set(-30, 18, -24); target.add(fill);
}

function initializeScene() {
  if (!canvasContainer.value) return;
  disposeScene(); prepareWorldTransform();
  const width = Math.max(canvasContainer.value.clientWidth, 320), height = Math.max(canvasContainer.value.clientHeight, 520);
  scene = new THREE.Scene(); scene.background = new THREE.Color(0x151b20); scene.fog = new THREE.Fog(0x151b20, 65, 125); buildIndustrialEnvironment(scene, unlocatedZoneX); configureLights(scene);
  camera = new THREE.PerspectiveCamera(43, width / height, 0.1, 300); camera.position.set(10, 34, 58);
  renderer = new THREE.WebGLRenderer({ antialias: true, powerPreference: 'high-performance' }); renderer.setSize(width, height); renderer.setPixelRatio(Math.min(window.devicePixelRatio, 1.75)); renderer.outputColorSpace = THREE.SRGBColorSpace; renderer.toneMapping = THREE.ACESFilmicToneMapping; renderer.toneMappingExposure = 1.05; renderer.shadowMap.enabled = true; renderer.shadowMap.type = THREE.PCFShadowMap; renderer.domElement.dataset.iiopScene = 'industrial-device-space'; canvasContainer.value.replaceChildren(renderer.domElement);
  controls = new OrbitControls(camera, renderer.domElement); controls.enableDamping = true; controls.dampingFactor = 0.07; controls.screenSpacePanning = false; controls.minDistance = 7; controls.maxDistance = 92; controls.minPolarAngle = 0.2; controls.maxPolarAngle = Math.PI / 2 - 0.045; controls.target.set(3, 1.8, 0);
  let unlocatedIndex = 0;
  devices.value.forEach((device) => { if (!scene) return; const unlocated = !hasCoordinates(device), position = positionedDevice(device, unlocatedIndex); if (unlocated) unlocatedIndex += 1; const group = buildDeviceVisual(device, inferDeviceType(device, categories.value[device.categoryId]), position, unlocated); scene.add(group); groupByDeviceId.set(device.id, group); visualPositionById.set(device.id, position.clone()); group.traverse((child) => { if (child instanceof THREE.Mesh) raycastTargets.push(child); }); });
  eventCanvas = renderer.domElement; eventCanvas.addEventListener('pointerdown', onPointerDown); eventCanvas.addEventListener('pointerup', onPointerUp); eventCanvas.addEventListener('pointermove', onPointerMove); eventCanvas.addEventListener('pointerleave', onPointerLeave); window.addEventListener('resize', resizeScene); resizeListening = true;
  const renderFrame = (time: number) => { animationFrame = requestAnimationFrame(renderFrame); if (cameraMotion && camera && controls) { const progress = Math.min((time - cameraMotion.startedAt) / 720, 1), eased = 1 - Math.pow(1 - progress, 3); camera.position.lerpVectors(cameraMotion.fromPosition, cameraMotion.toPosition, eased); controls.target.lerpVectors(cameraMotion.fromTarget, cameraMotion.toTarget, eased); if (progress >= 1) cameraMotion = null; } controls?.update(); if (renderer && scene && camera) renderer.render(scene, camera); };
  animationFrame = requestAnimationFrame(renderFrame); updateOutlines();
}

function pointerDevice(event: PointerEvent) { if (!eventCanvas || !camera) return null; const rect = eventCanvas.getBoundingClientRect(); pointer.set(((event.clientX - rect.left) / rect.width) * 2 - 1, -((event.clientY - rect.top) / rect.height) * 2 + 1); raycaster.setFromCamera(pointer, camera); return (raycaster.intersectObjects(raycastTargets, false)[0]?.object.userData.device as Device | undefined) ?? null; }
function updateOutlines() { groupByDeviceId.forEach((group, id) => { const outline = group.children.find((child) => child.userData.outline) as THREE.LineSegments | undefined; if (!outline || !(outline.material instanceof THREE.LineBasicMaterial)) return; const selected = selectedDevice.value?.id === id, hovered = hoveredDevice.value?.id === id; outline.visible = selected || hovered; outline.material.color.set(selected ? 0x54b9ff : 0xffcc62); outline.material.opacity = selected ? 1 : 0.78; }); }
function onPointerDown(event: PointerEvent) { pointerStart = { x: event.clientX, y: event.clientY }; }
function onPointerUp(event: PointerEvent) { if (!pointerStart) return; const distance = Math.hypot(event.clientX - pointerStart.x, event.clientY - pointerStart.y); pointerStart = null; if (distance <= 5) { const device = pointerDevice(event); if (device) selectDevice(device, true); } }
function onPointerMove(event: PointerEvent) { if (!eventCanvas) return; const rect = eventCanvas.getBoundingClientRect(); tooltipX.value = event.clientX - rect.left + 14; tooltipY.value = event.clientY - rect.top + 14; const device = pointerDevice(event); if (hoveredDevice.value?.id !== device?.id) { hoveredDevice.value = device; updateOutlines(); } eventCanvas.style.cursor = device ? 'pointer' : 'grab'; }
function onPointerLeave() { hoveredDevice.value = null; updateOutlines(); }

function moveCameraTo(device: Device) { if (!camera || !controls) return; const target = visualPositionById.get(device.id); if (!target) return; const direction = camera.position.clone().sub(controls.target); direction.y = 0; if (direction.lengthSq() < 0.01) direction.set(1, 0, 1); direction.normalize(); const toTarget = target.clone().add(new THREE.Vector3(0, 1.7, 0)), toPosition = toTarget.clone().add(direction.multiplyScalar(12)).add(new THREE.Vector3(0, 6.5, 0)); cameraMotion = { startedAt: performance.now(), fromPosition: camera.position.clone(), toPosition, fromTarget: controls.target.clone(), toTarget }; }
async function loadBusinessSummary(device: Device) { detailLoading.value = true; latestAbnormal.value = null; currentWorkOrder.value = null; const selectedId = device.id, requests: Promise<unknown>[] = []; if (auth.can('inspection:view')) requests.push(request.get<never, PageResult<InspectionAbnormal>>('/api/inspection/abnormals', { params: { pageNum: 1, pageSize: 1, deviceId: device.id } }).then((page) => { if (selectedDevice.value?.id === selectedId) latestAbnormal.value = page.records?.[0] ?? null; })); if (auth.can('maintenance:view')) requests.push(request.get<never, PageResult<WorkOrder>>('/api/maintenance/work-orders', { params: { pageNum: 1, pageSize: 20, deviceId: device.id } }).then((page) => { if (selectedDevice.value?.id === selectedId) currentWorkOrder.value = (page.records ?? []).find((order) => order.status !== 'COMPLETED') ?? page.records?.[0] ?? null; })); await Promise.allSettled(requests); if (selectedDevice.value?.id === selectedId) detailLoading.value = false; }
function selectDevice(device: Device, focus = true, searched = false) { selectedDevice.value = device; updateOutlines(); if (focus) moveCameraTo(device); void loadBusinessSummary(device); if (searched && !hasCoordinates(device)) ElMessage.info('该设备尚未配置空间坐标，已定位到“未定位设备区”的视觉排列位置。'); }
function selectSearchResult(device: Device) { searchKeyword.value = `${device.deviceName} · ${device.deviceCode}`; searchFocused.value = false; selectDevice(device, true, true); }
function selectFirstSearchResult() { if (searchResults.value[0]) selectSearchResult(searchResults.value[0]); }
function closeSearchResults() { window.setTimeout(() => { searchFocused.value = false; }, 120); }
function resetView() { if (camera && controls) cameraMotion = { startedAt: performance.now(), fromPosition: camera.position.clone(), toPosition: new THREE.Vector3(10, 34, 58), fromTarget: controls.target.clone(), toTarget: new THREE.Vector3(3, 1.8, 0) }; }
function resizeScene() { if (!canvasContainer.value || !renderer || !camera) return; const width = Math.max(canvasContainer.value.clientWidth, 320), height = Math.max(canvasContainer.value.clientHeight, 520); camera.aspect = width / height; camera.updateProjectionMatrix(); renderer.setSize(width, height); }

async function loadData() {
  loading.value = true; errorMessage.value = '';
  try { const previousId = selectedDevice.value?.id; const [firstPage, categoryTree] = await Promise.all([request.get<never, PageResult<Device>>('/api/device/devices', { params: { pageNum: 1, pageSize: 100 } }), request.get<never, CategoryTree[]>('/api/device/categories/tree')]); const pageCount = Math.ceil((firstPage.total ?? 0) / 100), remaining = pageCount > 1 ? await Promise.all(Array.from({ length: pageCount - 1 }, (_, index) => request.get<never, PageResult<Device>>('/api/device/devices', { params: { pageNum: index + 2, pageSize: 100 } }))) : []; devices.value = [...(firstPage.records ?? []), ...remaining.flatMap((page) => page.records ?? [])]; selectedDevice.value = devices.value.find((device) => device.id === previousId) ?? null; if (!selectedDevice.value) { latestAbnormal.value = null; currentWorkOrder.value = null; } categories.value = categoryNameMap(categoryTree ?? []); loading.value = false; await nextTick(); initializeScene(); const initial = selectedDevice.value ?? devices.value.find((device) => device.status === 'FAULT') ?? devices.value[0]; if (initial) selectDevice(initial, false); }
  catch { disposeScene(); errorMessage.value = '设备空间数据加载失败，请检查服务状态后重试。'; loading.value = false; }
}

onMounted(() => { void loadData(); });
onUnmounted(disposeScene);
</script>

<template>
  <section class="device-scene-page">
    <div class="page-head scene-head"><div><el-button link class="back-link" @click="router.push('/devices')"><el-icon><ArrowLeft /></el-icon> 返回设备档案列表</el-button><h1>设备空间视图</h1><p>轻量半写实工业现场 · 真实坐标映射 · 状态与运维信息联动</p></div><div class="head-actions"><el-button :icon="Aim" @click="resetView">总览视角</el-button><el-button :icon="Refresh" :loading="loading" @click="loadData">刷新场景</el-button></div></div>
    <el-alert v-if="errorMessage" :title="errorMessage" type="error" show-icon :closable="false"><template #default><el-button link type="primary" @click="loadData">重新加载</el-button></template></el-alert>
    <div v-else class="scene-shell">
      <div class="scene-toolbar">
        <div class="scene-search" @focusin="searchFocused = true" @focusout="closeSearchResults"><el-input v-model="searchKeyword" :prefix-icon="Search" clearable placeholder="搜索设备名称或编码，回车定位" @input="searchFocused = true" @keydown.enter.prevent="selectFirstSearchResult" /><div v-if="showSearchResults" class="search-results"><button v-for="device in searchResults" :key="device.id" type="button" @mousedown.prevent="selectSearchResult(device)"><span><strong>{{ device.deviceName }}</strong><small>{{ device.deviceCode }}</small></span><em v-if="!hasCoordinates(device)">未定位</em><i :style="{ background: `#${statusColor(device.status).toString(16).padStart(6, '0')}` }" /></button><div v-if="!searchResults.length" class="search-empty">没有找到匹配的设备</div></div></div>
        <div class="scene-stat"><span>设备</span><strong>{{ devices.length }}</strong></div><div class="scene-stat"><span>已定位</span><strong>{{ locatedDevices.length }}</strong></div><div class="scene-stat warning"><span>未定位</span><strong>{{ unlocatedDevices.length }}</strong></div><div class="scene-stat danger"><span>故障</span><strong>{{ statusSummary.FAULT }}</strong></div>
      </div>
      <div class="scene-layout">
        <div class="canvas-wrapper"><div ref="canvasContainer" class="three-canvas-box" />
          <div v-if="loading" class="scene-state-overlay loading-state"><div class="loader-ring" /><strong>正在构建设备空间场景</strong><span>加载设备、坐标与工业环境...</span></div>
          <div v-else-if="!devices.length" class="scene-state-overlay empty-state"><el-empty description="暂无设备，完成设备建档后即可生成空间视图"><el-button type="primary" @click="router.push('/devices')">返回设备档案</el-button></el-empty></div>
          <div v-if="hoveredDevice" class="hover-card" :style="{ left: `${tooltipX}px`, top: `${tooltipY}px` }"><strong>{{ hoveredDevice.deviceName }}</strong><span>{{ hoveredDevice.deviceCode }}</span><div><b :style="{ background: `#${statusColor(hoveredDevice.status).toString(16).padStart(6, '0')}` }" />{{ displayValue(hoveredDevice.status) }} · {{ displayValue(hoveredDevice.riskLevel) }}</div></div>
          <div class="scene-legend"><div class="legend-row"><span><i class="online" />在线 {{ statusSummary.ONLINE }}</span><span><i class="fault" />故障 {{ statusSummary.FAULT }}</span><span><i class="maintenance" />维修中 {{ statusSummary.MAINTENANCE }}</span><span><i class="offline" />离线 {{ statusSummary.OFFLINE }}</span></div><small>左键旋转 · 右键平移 · 滚轮缩放 · 点击设备平滑聚焦</small></div>
        </div>
        <aside class="scene-sidebar">
          <div class="sidebar-title"><div><small>DEVICE INSIGHT</small><strong>设备业务详情</strong></div><el-tag v-if="selectedDevice" :type="statusTagType(selectedDevice.status)">{{ displayValue(selectedDevice.status) }}</el-tag></div>
          <template v-if="selectedDevice">
            <div class="selected-identity"><div class="type-icon">{{ visualTypeLabel[selectedType].slice(0, 1) }}</div><div><h2>{{ selectedDevice.deviceName }}</h2><p>{{ selectedDevice.deviceCode }} · {{ visualTypeLabel[selectedType] }}</p></div></div>
            <div class="status-strip" :style="{ '--status-color': `#${statusColor(selectedDevice.status).toString(16).padStart(6, '0')}` }"><span>运行状态</span><strong>{{ displayValue(selectedDevice.status) }}</strong><span>风险等级</span><el-tag :type="riskTagType(selectedDevice.riskLevel)" size="small">{{ displayValue(selectedDevice.riskLevel) }}</el-tag></div>
            <el-descriptions :column="1" border size="small" class="device-descriptions"><el-descriptions-item label="设备类型">{{ categories[selectedDevice.categoryId] || visualTypeLabel[selectedType] }}</el-descriptions-item><el-descriptions-item label="型号">{{ selectedDevice.model || '未配置' }}</el-descriptions-item><el-descriptions-item label="安装位置">{{ selectedDevice.installLocation || selectedDevice.workshop || '未配置' }}</el-descriptions-item><el-descriptions-item label="空间坐标"><span v-if="selectedLocated">X {{ selectedDevice.positionX }} · Y {{ selectedDevice.positionY }} · Z {{ selectedDevice.positionZ }}</span><span v-else class="unlocated-text">未配置（当前仅在未定位区视觉排列）</span></el-descriptions-item></el-descriptions>
            <div v-loading="detailLoading" class="business-summary"><div class="summary-block"><label>最近异常</label><template v-if="latestAbnormal"><strong>{{ latestAbnormal.title }}</strong><span>{{ displayValue(latestAbnormal.severity) }} · {{ displayValue(latestAbnormal.status) }}</span></template><span v-else>{{ auth.can('inspection:view') ? '暂无巡检异常' : '当前岗位无巡检数据权限' }}</span></div><div class="summary-block"><label>当前维修</label><template v-if="currentWorkOrder"><strong>{{ currentWorkOrder.title }}</strong><span>{{ currentWorkOrder.workOrderCode }} · {{ displayValue(currentWorkOrder.status) }}</span></template><span v-else>{{ auth.can('maintenance:view') ? '暂无维修工单' : '当前岗位无维修数据权限' }}</span></div></div>
            <div class="detail-actions"><el-button type="primary" :icon="View" @click="router.push(`/devices/${selectedDevice.id}`)">进入设备档案</el-button><el-button v-if="auth.can('maintenance:view')" @click="router.push({ path: '/maintenance/work-orders', query: { deviceId: selectedDevice.id } })">查看维修工单</el-button></div>
          </template><el-empty v-else description="点击设备查看业务详情" :image-size="78" />
          <el-tabs class="device-index" stretch><el-tab-pane :label="`已定位 ${locatedDevices.length}`"><button v-for="device in locatedDevices" :key="device.id" type="button" class="device-index-row" :class="{ active: selectedDevice?.id === device.id }" @click="selectDevice(device)"><i :style="{ background: `#${statusColor(device.status).toString(16).padStart(6, '0')}` }" /><span><strong>{{ device.deviceName }}</strong><small>{{ device.deviceCode }}</small></span></button><el-empty v-if="!locatedDevices.length" description="暂无已定位设备" :image-size="52" /></el-tab-pane><el-tab-pane :label="`未定位 ${unlocatedDevices.length}`"><div class="unlocated-note">以下设备仅在专用区域规则排列，不代表真实坐标。</div><button v-for="device in unlocatedDevices" :key="device.id" type="button" class="device-index-row" :class="{ active: selectedDevice?.id === device.id }" @click="selectDevice(device)"><i :style="{ background: `#${riskColor(device.riskLevel).toString(16).padStart(6, '0')}` }" /><span><strong>{{ device.deviceName }}</strong><small>{{ device.deviceCode }} · 空间坐标未配置</small></span></button><el-empty v-if="!unlocatedDevices.length" description="所有设备均已定位" :image-size="52" /></el-tab-pane></el-tabs>
        </aside>
      </div>
    </div>
  </section>
</template>

<style scoped>
.device-scene-page{display:flex;flex-direction:column;gap:14px;height:calc(100vh - 104px);min-height:650px}.scene-head{align-items:flex-end}.back-link{padding:0;margin-bottom:4px;font-size:13px}.scene-shell{display:flex;flex-direction:column;gap:10px;flex:1;min-height:0}.scene-toolbar{display:flex;align-items:stretch;gap:9px}.scene-search{position:relative;width:min(420px,38vw);z-index:20}.search-results{position:absolute;top:calc(100% + 6px);left:0;right:0;padding:6px;background:#fff;border:1px solid #dbe3e9;border-radius:8px;box-shadow:0 14px 34px rgba(24,39,52,.18)}.search-results button{width:100%;border:0;background:transparent;border-radius:6px;padding:8px 10px;display:flex;align-items:center;gap:10px;text-align:left;cursor:pointer}.search-results button:hover{background:#eef4f7}.search-results button span{display:flex;flex:1;flex-direction:column}.search-results small{color:#81909b}.search-results em{font-style:normal;font-size:11px;color:#9b6a18;background:#fff3d8;padding:2px 6px;border-radius:10px}.search-results i,.device-index-row>i{width:8px;height:8px;border-radius:50%;box-shadow:0 0 8px currentColor}.search-empty{padding:16px;text-align:center;color:#8997a2}.scene-stat{min-width:88px;padding:6px 13px;border:1px solid #dde5ea;border-radius:7px;background:#fff;display:flex;align-items:center;justify-content:space-between;gap:12px}.scene-stat span{font-size:12px;color:#788791}.scene-stat strong{font-size:19px;color:#24313b}.scene-stat.warning strong{color:#a56c12}.scene-stat.danger strong{color:#c73f4b}.scene-layout{display:grid;grid-template-columns:minmax(0,1fr) 370px;gap:12px;flex:1;min-height:0}.canvas-wrapper{position:relative;min-height:540px;overflow:hidden;border-radius:10px;border:1px solid #343f48;background:#151b20;box-shadow:inset 0 0 0 1px rgba(255,255,255,.025)}.three-canvas-box{width:100%;height:100%}.scene-state-overlay{position:absolute;inset:0;z-index:8;display:grid;place-content:center;justify-items:center;gap:10px;background:rgba(21,27,32,.9);color:#dce5eb}.loading-state span{font-size:12px;color:#7f929f}.loader-ring{width:42px;height:42px;border:3px solid #40505b;border-top-color:#69b9e7;border-radius:50%;animation:spin .8s linear infinite}@keyframes spin{to{transform:rotate(360deg)}}.hover-card{position:absolute;z-index:12;pointer-events:none;min-width:190px;padding:9px 11px;border:1px solid rgba(129,151,166,.45);border-radius:7px;background:rgba(18,25,31,.94);box-shadow:0 10px 25px rgba(0,0,0,.3);color:#e5edf2;display:flex;flex-direction:column}.hover-card>span{font-size:11px;color:#8295a2}.hover-card div{margin-top:6px;font-size:12px;color:#b9c6ce}.hover-card b{display:inline-block;width:7px;height:7px;border-radius:50%;margin-right:6px}.scene-legend{position:absolute;left:14px;bottom:14px;padding:9px 12px;border:1px solid rgba(128,148,161,.28);border-radius:7px;background:rgba(17,24,29,.82);backdrop-filter:blur(8px);color:#c9d4db;pointer-events:none}.legend-row{display:flex;gap:12px;font-size:11px}.legend-row span{display:flex;align-items:center;gap:5px}.legend-row i{width:7px;height:7px;border-radius:50%}.legend-row .online{background:#36c98f}.legend-row .fault{background:#ff4d5e}.legend-row .maintenance{background:#ffb020}.legend-row .offline{background:#7c8794}.scene-legend small{display:block;margin-top:5px;color:#71838f}.scene-sidebar{min-height:0;overflow:auto;border:1px solid #dce4e9;border-radius:10px;background:#fff;padding:15px;box-shadow:0 8px 24px rgba(36,49,59,.06)}.sidebar-title{display:flex;justify-content:space-between;align-items:center;padding-bottom:11px;border-bottom:1px solid #e8edf0}.sidebar-title>div{display:flex;flex-direction:column}.sidebar-title small{font-size:9px;letter-spacing:1.6px;color:#82939e}.selected-identity{display:flex;align-items:center;gap:11px;padding:14px 0}.type-icon{width:43px;height:43px;display:grid;place-content:center;border-radius:8px;background:#303d47;color:#d8e2e8;font-size:19px;font-weight:700}.selected-identity h2{margin:0;font-size:17px;color:#1e2a33}.selected-identity p{margin:3px 0 0;font-size:11px;color:#7c8c97}.status-strip{display:grid;grid-template-columns:auto 1fr auto auto;align-items:center;gap:8px;padding:8px 10px;margin-bottom:11px;border-left:3px solid var(--status-color);background:#f3f6f8;font-size:12px}.status-strip span{color:#7b8993}.status-strip strong{color:#293741}.device-descriptions :deep(.el-descriptions__label){width:82px}.unlocated-text{color:#a56c12}.business-summary{display:grid;grid-template-columns:1fr 1fr;gap:8px;margin-top:11px;min-height:74px}.summary-block{padding:9px;border:1px solid #e3e9ed;border-radius:6px;background:#fafcfd;display:flex;flex-direction:column;gap:2px;min-width:0}.summary-block label{font-size:10px;color:#85949e}.summary-block strong{font-size:12px;color:#293741;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.summary-block span{font-size:10px;color:#7b8a95}.detail-actions{display:flex;margin:11px 0}.device-index{margin-top:5px}.device-index :deep(.el-tabs__content){max-height:175px;overflow:auto}.device-index-row{display:flex;align-items:center;gap:9px;width:100%;border:1px solid transparent;background:transparent;padding:7px 8px;border-radius:6px;text-align:left;cursor:pointer}.device-index-row:hover{background:#f3f6f8}.device-index-row.active{border-color:#9cc9e3;background:#eaf4fa}.device-index-row span{display:flex;flex-direction:column;min-width:0}.device-index-row strong{font-size:12px;color:#2c3942;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.device-index-row small{font-size:10px;color:#83919b}.unlocated-note{padding:7px 8px;margin-bottom:5px;border-radius:5px;background:#fff5df;color:#95651b;font-size:10px}
@media(max-width:1200px){.device-scene-page{height:auto}.scene-layout{grid-template-columns:1fr}.canvas-wrapper{height:590px}.scene-sidebar{max-height:none}.scene-toolbar{flex-wrap:wrap}.scene-search{width:100%}}@media(max-width:700px){.canvas-wrapper{height:520px;min-height:520px}.scene-stat{flex:1}.legend-row{flex-wrap:wrap}.scene-legend{right:14px}.business-summary{grid-template-columns:1fr}}
</style>
