<script setup lang="ts">
import { computed, nextTick, onMounted, onUnmounted, ref } from 'vue';
import { useRouter } from 'vue-router';
import * as THREE from 'three';
import { OrbitControls } from 'three/examples/jsm/controls/OrbitControls.js';
import { ArrowLeft, Refresh, View, Warning } from '@element-plus/icons-vue';
import { request } from '../api/request';
import type { Device, DeviceStatus, PageResult, RiskLevel } from '../types/device';
import { displayValue } from '../utils/display';

const router = useRouter();

const loading = ref(true);
const errorMessage = ref('');
const devices = ref<Device[]>([]);
const selectedDevice = ref<Device | null>(null);

const canvasContainer = ref<HTMLDivElement>();

let scene: THREE.Scene | null = null;
let camera: THREE.PerspectiveCamera | null = null;
let renderer: THREE.WebGLRenderer | null = null;
let controls: OrbitControls | null = null;
let animId: number | null = null;
let pointerDownHandler: ((event: PointerEvent) => void) | null = null;
let pointerEventTarget: HTMLCanvasElement | null = null;
let resizeListenerActive = false;
const meshMap = new Map<string, THREE.Group>();
let highlightedGroup: THREE.Group | null = null;
const sceneOrigin = new THREE.Vector3();
let uniformSceneScale = 1;

const devicesWithCoords = computed(() => {
  return devices.value.filter(
    (d) => d.positionX !== null && d.positionY !== null && d.positionZ !== null
  );
});

const devicesWithoutCoords = computed(() => {
  return devices.value.filter(
    (d) => d.positionX === null || d.positionY === null || d.positionZ === null
  );
});

function getStatusColor(status: DeviceStatus): number {
  switch (status) {
    case 'ONLINE':
      return 0x10b981; // emerald green
    case 'FAULT':
      return 0xef4444; // crimson red
    case 'MAINTENANCE':
      return 0xf59e0b; // amber yellow
    case 'OFFLINE':
      return 0x94a3b8; // slate gray
    case 'SCRAPPED':
      return 0x475569;
    default:
      return 0x64748b;
  }
}

function getRiskColor(risk: RiskLevel): number {
  switch (risk) {
    case 'CRITICAL':
      return 0xdc2626;
    case 'HIGH':
      return 0xf97316;
    case 'MEDIUM':
      return 0x3b82f6;
    case 'LOW':
      return 0x22c55e;
    default:
      return 0x94a3b8;
  }
}

function statusTagType(status: DeviceStatus) {
  return status === 'ONLINE' ? 'success' : status === 'FAULT' ? 'danger' : status === 'MAINTENANCE' ? 'warning' : 'info';
}

function riskTagType(risk: RiskLevel) {
  return risk === 'CRITICAL' ? 'danger' : risk === 'HIGH' ? 'warning' : risk === 'MEDIUM' ? 'primary' : 'success';
}

function createLabelTexture(text: string, subText: string, color: string): THREE.CanvasTexture {
  const canvas = document.createElement('canvas');
  canvas.width = 256;
  canvas.height = 80;
  const ctx = canvas.getContext('2d');
  if (ctx) {
    ctx.fillStyle = 'rgba(15, 23, 42, 0.85)';
    ctx.roundRect(0, 0, 256, 80, 8);
    ctx.fill();
    ctx.strokeStyle = color;
    ctx.lineWidth = 3;
    ctx.roundRect(0, 0, 256, 80, 8);
    ctx.stroke();

    ctx.fillStyle = '#ffffff';
    ctx.font = 'bold 20px "Microsoft YaHei", sans-serif';
    ctx.textAlign = 'center';
    ctx.fillText(text, 128, 34);

    ctx.fillStyle = '#94a3b8';
    ctx.font = '14px "Microsoft YaHei", sans-serif';
    ctx.fillText(subText, 128, 62);
  }
  const texture = new THREE.CanvasTexture(canvas);
  texture.minFilter = THREE.LinearFilter;
  return texture;
}

function buildDeviceMesh(dev: Device): THREE.Group {
  const group = new THREE.Group();
  group.name = `device_${dev.id}`;
  group.userData = { device: dev };

  const colorHex = getStatusColor(dev.status);
  const riskHex = getRiskColor(dev.riskLevel);

  // 1. Device base body
  const bodyGeo = new THREE.BoxGeometry(3, 2.2, 2.2);
  const bodyMat = new THREE.MeshStandardMaterial({
    color: colorHex,
    roughness: 0.35,
    metalness: 0.4
  });
  const bodyMesh = new THREE.Mesh(bodyGeo, bodyMat);
  bodyMesh.position.y = 1.1;
  bodyMesh.castShadow = true;
  bodyMesh.receiveShadow = true;
  bodyMesh.userData = { device: dev };
  group.add(bodyMesh);

  // 2. Base plate
  const baseGeo = new THREE.BoxGeometry(3.4, 0.2, 2.6);
  const baseMat = new THREE.MeshStandardMaterial({ color: 0x1e293b, roughness: 0.7 });
  const baseMesh = new THREE.Mesh(baseGeo, baseMat);
  baseMesh.position.y = 0.1;
  baseMesh.userData = { device: dev };
  group.add(baseMesh);

  // 3. Top Risk Indicator Beacon
  const beaconGeo = new THREE.CylinderGeometry(0.35, 0.35, 0.4, 16);
  const beaconMat = new THREE.MeshStandardMaterial({
    color: riskHex,
    emissive: riskHex,
    emissiveIntensity: 0.7,
    roughness: 0.2
  });
  const beaconMesh = new THREE.Mesh(beaconGeo, beaconMat);
  beaconMesh.position.y = 2.4;
  beaconMesh.userData = { device: dev };
  group.add(beaconMesh);

  // 4. Floating 2D Label Sprite
  const labelTex = createLabelTexture(
    dev.deviceName.length > 8 ? dev.deviceName.slice(0, 8) + '...' : dev.deviceName,
    dev.deviceCode,
    dev.status === 'FAULT' ? '#ef4444' : dev.status === 'ONLINE' ? '#10b981' : '#3b82f6'
  );
  const spriteMat = new THREE.SpriteMaterial({ map: labelTex, depthTest: false });
  const sprite = new THREE.Sprite(spriteMat);
  sprite.position.set(0, 3.6, 0);
  sprite.scale.set(4, 1.25, 1);
  group.add(sprite);

  // Preserve the DB coordinate semantics: one origin translation and one
  // uniform scale are applied to all three axes for scene visualization.
  const posX = (Number(dev.positionX) - sceneOrigin.x) * uniformSceneScale;
  const posY = (Number(dev.positionY) - sceneOrigin.y) * uniformSceneScale;
  const posZ = (Number(dev.positionZ) - sceneOrigin.z) * uniformSceneScale;
  group.position.set(posX, posY, posZ);

  return group;
}

function prepareSceneTransform() {
  if (!devicesWithCoords.value.length) {
    sceneOrigin.set(0, 0, 0);
    uniformSceneScale = 1;
    return;
  }

  const xs = devicesWithCoords.value.map((d) => Number(d.positionX));
  const ys = devicesWithCoords.value.map((d) => Number(d.positionY));
  const zs = devicesWithCoords.value.map((d) => Number(d.positionZ));
  const minX = Math.min(...xs);
  const maxX = Math.max(...xs);
  const minY = Math.min(...ys);
  const maxY = Math.max(...ys);
  const minZ = Math.min(...zs);
  const maxZ = Math.max(...zs);
  sceneOrigin.set((minX + maxX) / 2, minY, (minZ + maxZ) / 2);
  const maxSpan = Math.max(maxX - minX, maxY - minY, maxZ - minZ, 1);
  uniformSceneScale = Math.min(3, 50 / maxSpan);
}

function disposeMaterial(material: THREE.Material) {
  const texture = (material as THREE.Material & { map?: THREE.Texture | null }).map;
  texture?.dispose();
  material.dispose();
}

function disposeScene() {
  if (animId !== null) {
    cancelAnimationFrame(animId);
    animId = null;
  }
  if (resizeListenerActive) {
    window.removeEventListener('resize', handleResize);
    resizeListenerActive = false;
  }
  if (pointerEventTarget && pointerDownHandler) {
    pointerEventTarget.removeEventListener('pointerdown', pointerDownHandler);
  }
  pointerEventTarget = null;
  pointerDownHandler = null;
  controls?.dispose();
  controls = null;

  scene?.traverse((child) => {
    const disposable = child as THREE.Object3D & {
      geometry?: THREE.BufferGeometry;
      material?: THREE.Material | THREE.Material[];
    };
    disposable.geometry?.dispose();
    if (Array.isArray(disposable.material)) {
      disposable.material.forEach(disposeMaterial);
    } else if (disposable.material) {
      disposeMaterial(disposable.material);
    }
  });
  scene?.clear();
  scene = null;

  if (renderer) {
    const canvas = renderer.domElement;
    renderer.dispose();
    canvas.parentNode?.removeChild(canvas);
  }
  renderer = null;
  camera = null;
  meshMap.clear();
  highlightedGroup = null;
}

function initScene() {
  if (!canvasContainer.value) return;

  disposeScene();
  prepareSceneTransform();

  const width = canvasContainer.value.clientWidth;
  const height = canvasContainer.value.clientHeight || 580;

  // Scene
  scene = new THREE.Scene();
  scene.background = new THREE.Color(0x0c1524);

  // Camera
  camera = new THREE.PerspectiveCamera(45, width / height, 0.1, 1000);
  camera.position.set(0, 24, 40);

  // Renderer
  renderer = new THREE.WebGLRenderer({ antialias: true });
  renderer.setSize(width, height);
  renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
  renderer.shadowMap.enabled = true;
  canvasContainer.value.innerHTML = '';
  canvasContainer.value.appendChild(renderer.domElement);

  // OrbitControls
  controls = new OrbitControls(camera, renderer.domElement);
  controls.enableDamping = true;
  controls.dampingFactor = 0.05;
  controls.maxPolarAngle = Math.PI / 2 - 0.05;
  controls.minDistance = 8;
  controls.maxDistance = 150;
  controls.target.set(0, 2, 0);

  // Lights
  const ambientLight = new THREE.AmbientLight(0xffffff, 0.85);
  scene.add(ambientLight);

  const dirLight1 = new THREE.DirectionalLight(0xffffff, 1.4);
  dirLight1.position.set(25, 45, 25);
  dirLight1.castShadow = true;
  scene.add(dirLight1);

  const dirLight2 = new THREE.DirectionalLight(0x60a5fa, 0.6);
  dirLight2.position.set(-25, 20, -25);
  scene.add(dirLight2);

  // Floor Grid
  const gridHelper = new THREE.GridHelper(80, 40, 0x38bdf8, 0x1e3a5f);
  gridHelper.position.y = 0;
  scene.add(gridHelper);

  // Ground Plane
  const planeGeo = new THREE.PlaneGeometry(80, 80);
  const planeMat = new THREE.MeshStandardMaterial({
    color: 0x09111e,
    roughness: 0.9,
    metalness: 0.1
  });
  const plane = new THREE.Mesh(planeGeo, planeMat);
  plane.rotation.x = -Math.PI / 2;
  plane.position.y = -0.01;
  plane.receiveShadow = true;
  scene.add(plane);

  // Add Device Meshes
  meshMap.clear();
  devicesWithCoords.value.forEach((dev) => {
    if (!scene) return;
    const meshGroup = buildDeviceMesh(dev);
    scene.add(meshGroup);
    meshMap.set(dev.id, meshGroup);
  });

  // Setup Raycaster
  setupRaycaster();
  window.addEventListener('resize', handleResize);
  resizeListenerActive = true;

  // Animation Loop
  const animate = () => {
    animId = requestAnimationFrame(animate);
    if (controls) controls.update();
    if (renderer && scene && camera) {
      renderer.render(scene, camera);
    }
  };
  animate();
}

const raycaster = new THREE.Raycaster();
const mouse = new THREE.Vector2();

function setupRaycaster() {
  if (!renderer) return;

  const dom = renderer.domElement;

  pointerEventTarget = dom;
  pointerDownHandler = (event: PointerEvent) => {
    if (!camera || !scene) return;
    const rect = dom.getBoundingClientRect();
    mouse.x = ((event.clientX - rect.left) / rect.width) * 2 - 1;
    mouse.y = -((event.clientY - rect.top) / rect.height) * 2 + 1;

    raycaster.setFromCamera(mouse, camera);

    const interactiveMeshes: THREE.Object3D[] = [];
    meshMap.forEach((group) => {
      group.traverse((child) => {
        if (child instanceof THREE.Mesh) {
          interactiveMeshes.push(child);
        }
      });
    });

    const intersects = raycaster.intersectObjects(interactiveMeshes, false);
    if (intersects.length > 0) {
      const hit = intersects[0].object;
      const dev = hit.userData?.device as Device | undefined;
      if (dev) {
        selectDevice(dev);
      }
    }
  };

  dom.addEventListener('pointerdown', pointerDownHandler);
}

function highlightMesh(group: THREE.Group | null) {
  if (highlightedGroup) {
    highlightedGroup.traverse((child) => {
      if (child instanceof THREE.Mesh && child.material instanceof THREE.MeshStandardMaterial) {
        child.material.emissiveIntensity = child.userData?.isBeacon ? 0.7 : 0;
      }
    });
  }
  highlightedGroup = group;
  if (highlightedGroup) {
    highlightedGroup.traverse((child) => {
      if (child instanceof THREE.Mesh && child.material instanceof THREE.MeshStandardMaterial) {
        if (!child.userData?.isBeacon) {
          child.material.emissive = new THREE.Color(0x38bdf8);
          child.material.emissiveIntensity = 0.45;
        }
      }
    });
  }
}

function selectDevice(dev: Device) {
  selectedDevice.value = dev;
  const group = meshMap.get(dev.id) || null;
  highlightMesh(group);

  if (group && camera && controls) {
    const targetPos = group.position.clone();
    controls.target.copy(targetPos);
  }
}

function handleResize() {
  if (!canvasContainer.value || !renderer || !camera) return;
  const width = canvasContainer.value.clientWidth;
  const height = canvasContainer.value.clientHeight || 580;
  camera.aspect = width / height;
  camera.updateProjectionMatrix();
  renderer.setSize(width, height);
}

async function loadData() {
  loading.value = true;
  errorMessage.value = '';
  try {
    const firstPage = await request.get<never, PageResult<Device>>('/api/device/devices', {
      params: {
        pageNum: 1,
        pageSize: 100
      }
    });
    const pageCount = Math.ceil((firstPage.total ?? 0) / 100);
    const remainingPages = pageCount > 1
      ? await Promise.all(
          Array.from({ length: pageCount - 1 }, (_, index) =>
            request.get<never, PageResult<Device>>('/api/device/devices', {
              params: { pageNum: index + 2, pageSize: 100 }
            })
          )
        )
      : [];
    devices.value = [
      ...(firstPage.records ?? []),
      ...remainingPages.flatMap((page) => page.records ?? [])
    ];
    await nextTick();
    initScene();
    if (devicesWithCoords.value.length > 0) {
      selectDevice(devicesWithCoords.value[0]);
    }
  } catch {
    errorMessage.value = '设备数据加载失败，请检查服务状态后重试。';
  } finally {
    loading.value = false;
  }
}

onMounted(() => {
  void loadData();
});

onUnmounted(() => {
  disposeScene();
});
</script>

<template>
  <section class="device-scene-page">
    <div class="page-head">
      <div>
        <el-button link class="back-link" @click="router.push('/devices')">
          <el-icon><ArrowLeft /></el-icon> 返回设备档案列表
        </el-button>
        <h1>设备空间视图</h1>
        <p>基于 Three.js 呈现车间真实设备三维布局、运行状态与风险感知。</p>
      </div>
      <div class="head-actions">
        <el-button :icon="Refresh" @click="loadData">刷新场景</el-button>
      </div>
    </div>

    <el-alert
      v-if="errorMessage"
      :title="errorMessage"
      type="error"
      show-icon
      :closable="false"
    >
      <template #default>
        <el-button link type="primary" @click="loadData">重新加载</el-button>
      </template>
    </el-alert>

    <div v-else class="scene-container">
      <!-- 3D Canvas Area -->
      <div class="canvas-wrapper">
        <div ref="canvasContainer" class="three-canvas-box" />

        <div class="scene-overlay-legend">
          <div class="legend-title">状态标识</div>
          <div class="legend-items">
            <span class="legend-item"><i class="dot online" />在线 (ONLINE)</span>
            <span class="legend-item"><i class="dot fault" />故障 (FAULT)</span>
            <span class="legend-item"><i class="dot maintenance" />维护中 (MAINTENANCE)</span>
            <span class="legend-item"><i class="dot offline" />离线 (OFFLINE)</span>
          </div>
          <div class="legend-hint">鼠标左键拖拽旋转 · 右键平移 · 滚轮缩放 · 点击设备查看详情</div>
        </div>
      </div>

      <!-- Right Side Device Panel -->
      <aside class="scene-sidebar">
        <!-- Selected Device Detail Card -->
        <el-card shadow="never" class="detail-card">
          <template #header>
            <div class="card-header-flex">
              <strong>选中设备详情</strong>
              <el-tag v-if="selectedDevice" :type="statusTagType(selectedDevice.status)" size="small">
                {{ displayValue(selectedDevice.status) }}
              </el-tag>
            </div>
          </template>

          <template v-if="selectedDevice">
            <el-descriptions :column="1" border size="small">
              <el-descriptions-item label="设备名称">
                <strong>{{ selectedDevice.deviceName }}</strong>
              </el-descriptions-item>
              <el-descriptions-item label="设备编码">
                {{ selectedDevice.deviceCode }}
              </el-descriptions-item>
              <el-descriptions-item label="风险等级">
                <el-tag :type="riskTagType(selectedDevice.riskLevel)" size="small">
                  {{ displayValue(selectedDevice.riskLevel) }}
                </el-tag>
              </el-descriptions-item>
              <el-descriptions-item label="安装位置">
                {{ selectedDevice.installLocation || '未标明' }}
              </el-descriptions-item>
              <el-descriptions-item label="空间三维坐标">
                <span v-if="selectedDevice.positionX !== null">
                  X: {{ selectedDevice.positionX }}, Y: {{ selectedDevice.positionY }}, Z: {{ selectedDevice.positionZ }}
                </span>
                <span v-else class="text-muted">未配置坐标</span>
              </el-descriptions-item>
              <el-descriptions-item label="型号">
                {{ selectedDevice.model || '-' }}
              </el-descriptions-item>
            </el-descriptions>

            <div class="detail-actions">
              <el-button
                type="primary"
                :icon="View"
                class="w-full"
                @click="router.push(`/devices/${selectedDevice.id}`)"
              >
                进入该设备详情档案
              </el-button>
            </div>
          </template>
          <el-empty v-else description="点击 3D 场景或列表选择设备" :image-size="70" />
        </el-card>

        <!-- Coordinate Lists -->
        <el-tabs type="border-card" class="device-tabs">
          <el-tab-pane :label="`三维设备 (${devicesWithCoords.length})`">
            <div class="device-scroll-list">
              <div
                v-for="item in devicesWithCoords"
                :key="item.id"
                class="device-row"
                :class="{ active: selectedDevice?.id === item.id }"
                @click="selectDevice(item)"
              >
                <div class="row-main">
                  <span class="row-name">{{ item.deviceName }}</span>
                  <span class="row-code">{{ item.deviceCode }}</span>
                </div>
                <div class="row-tags">
                  <el-tag :type="statusTagType(item.status)" size="small">
                    {{ displayValue(item.status) }}
                  </el-tag>
                </div>
              </div>
            </div>
          </el-tab-pane>

          <el-tab-pane :label="`未配置坐标 (${devicesWithoutCoords.length})`">
            <div class="device-scroll-list">
              <div
                v-for="item in devicesWithoutCoords"
                :key="item.id"
                class="device-row unconfigured"
                @click="selectDevice(item)"
              >
                <div class="row-main">
                  <span class="row-name">{{ item.deviceName }}</span>
                  <span class="row-code">{{ item.deviceCode }}</span>
                </div>
                <el-button link size="small" type="primary" @click.stop="router.push('/devices')">
                  去配置
                </el-button>
              </div>
              <el-empty
                v-if="!devicesWithoutCoords.length"
                description="所有设备均已配置坐标"
                :image-size="60"
              />
            </div>
          </el-tab-pane>
        </el-tabs>
      </aside>
    </div>
  </section>
</template>

<style scoped>
.device-scene-page {
  display: flex;
  flex-direction: column;
  gap: 16px;
  height: calc(100vh - 105px);
}

.back-link {
  font-size: 13px;
  padding: 0;
  margin-bottom: 4px;
}

.scene-container {
  display: grid;
  grid-template-columns: 1fr 360px;
  gap: 16px;
  flex: 1;
  min-height: 0;
}

.canvas-wrapper {
  position: relative;
  background: #0c1524;
  border-radius: 8px;
  overflow: hidden;
  border: 1px solid #1e3a5f;
  display: flex;
  flex-direction: column;
}

.three-canvas-box {
  width: 100%;
  height: 100%;
  flex: 1;
  outline: none;
}

.scene-overlay-legend {
  position: absolute;
  bottom: 14px;
  left: 14px;
  background: rgba(12, 21, 36, 0.85);
  backdrop-filter: blur(6px);
  padding: 10px 14px;
  border-radius: 6px;
  border: 1px solid rgba(56, 189, 248, 0.25);
  color: #e2e8f0;
  font-size: 12px;
  pointer-events: none;
}

.legend-title {
  font-weight: 600;
  color: #38bdf8;
  margin-bottom: 6px;
}

.legend-items {
  display: flex;
  gap: 12px;
  margin-bottom: 6px;
}

.legend-item {
  display: flex;
  align-items: center;
  gap: 5px;
}

.dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  display: inline-block;
}

.dot.online { background: #10b981; }
.dot.fault { background: #ef4444; }
.dot.maintenance { background: #f59e0b; }
.dot.offline { background: #94a3b8; }

.legend-hint {
  color: #64748b;
  font-size: 11px;
}

.scene-sidebar {
  display: flex;
  flex-direction: column;
  gap: 14px;
  min-height: 0;
}

.card-header-flex {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.detail-card {
  border-radius: 8px;
}

.detail-actions {
  margin-top: 14px;
}

.w-full {
  width: 100%;
}

.device-tabs {
  flex: 1;
  display: flex;
  flex-direction: column;
  border-radius: 8px;
  overflow: hidden;
  min-height: 0;
}

.device-tabs :deep(.el-tabs__content) {
  flex: 1;
  overflow-y: auto;
  padding: 8px;
}

.device-scroll-list {
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.device-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 8px 12px;
  border-radius: 6px;
  background: #f8fafc;
  border: 1px solid #e2e8f0;
  cursor: pointer;
  transition: all 0.15s ease;
}

.device-row:hover {
  background: #f1f5f9;
  border-color: #cbd5e1;
}

.device-row.active {
  background: #eff6ff;
  border-color: #3b82f6;
  box-shadow: 0 0 0 1px #3b82f6;
}

.row-main {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.row-name {
  font-size: 13px;
  font-weight: 600;
  color: #1e293b;
}

.row-code {
  font-size: 11px;
  color: #64748b;
}

.text-muted {
  color: #94a3b8;
}

@media (max-width: 1200px) {
  .scene-container {
    grid-template-columns: 1fr;
    grid-template-rows: 460px 1fr;
    overflow-y: auto;
  }
}
</style>
