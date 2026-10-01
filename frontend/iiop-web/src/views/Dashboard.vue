<script setup lang="ts">
import { computed, nextTick, onMounted, onUnmounted, ref } from 'vue';
import { useRouter } from 'vue-router';
import * as echarts from 'echarts';
import {
  Cpu,
  DocumentChecked,
  Tools,
  Warning,
  DataAnalysis,
  User,
  View,
  Right,
  Refresh,
  Check
} from '@element-plus/icons-vue';
import { request } from '../api/request';
import { useAuthStore } from '../stores/auth';
import { displayValue } from '../utils/display';

interface DeviceOverview {
  deviceTotal: number;
  byStatus: Record<string, number>;
  byRiskLevel: Record<string, number>;
}

interface PageResult<T> {
  current: number;
  size: number;
  total: number;
  records: T[];
}

interface TaskItem {
  id: string;
  taskCode: string;
  planId: string;
  status: string;
  assignedUserId: string;
  createdAt: string;
}

interface WorkOrderItem {
  id: string;
  workOrderCode: string;
  title: string;
  status: string;
  priority: string;
  assigneeUserId: string;
  createdAt: string;
}

interface DefectItem {
  id: string;
  defectCode: string;
  title: string;
  status: string;
  severity: string;
  createdAt: string;
}

const auth = useAuthStore();
const router = useRouter();

const loading = ref(true);
const errorMessage = ref('');

// Overview from real API
const overview = ref<DeviceOverview>({
  deviceTotal: 0,
  byStatus: {},
  byRiskLevel: {}
});

// Operational metrics from real API
const taskMetrics = ref({ pending: 0, inProgress: 0, completed: 0 });
const defectMetrics = ref({ open: 0, confirmed: 0, processing: 0 });
const workOrderMetrics = ref({ pending: 0, assigned: 0, processing: 0, waitingAcceptance: 0 });
const aiMetrics = ref({ pending: 0, criticalHigh: 0 });

// Actionable todo lists
const pendingTasks = ref<TaskItem[]>([]);
const actionableWorkOrders = ref<WorkOrderItem[]>([]);
const openDefects = ref<DefectItem[]>([]);

// Chart DOM refs & instances
const chartStatusRef = ref<HTMLDivElement>();
const chartRiskRef = ref<HTMLDivElement>();
const chartOpsRef = ref<HTMLDivElement>();

let chartStatusInstance: echarts.ECharts | null = null;
let chartRiskInstance: echarts.ECharts | null = null;
let chartOpsInstance: echarts.ECharts | null = null;

const isSuperAdmin = computed(() => auth.roles.includes('SUPER_ADMIN'));
const isAdmin = computed(() => auth.roles.includes('ADMIN'));
const isInspector = computed(() => auth.roles.includes('INSPECTOR') && !isAdmin.value && !isSuperAdmin.value);
const isMaintainer = computed(() => auth.roles.includes('MAINTAINER') && !isAdmin.value && !isSuperAdmin.value);

async function loadData() {
  loading.value = true;
  errorMessage.value = '';

  const jobs: Promise<unknown>[] = [];

  // 1. Device overview stats (available to all 4 roles with dashboard:view)
  jobs.push(
    request.get<never, DeviceOverview>('/api/device/statistics/overview').then((res) => {
      overview.value = {
        deviceTotal: Number(res?.deviceTotal || 0),
        byStatus: res?.byStatus || {},
        byRiskLevel: res?.byRiskLevel || {}
      };
    })
  );

  // 2. Inspection tasks metrics (if user has inspection:view)
  if (auth.can('inspection:view')) {
    jobs.push(
      request.get<never, PageResult<TaskItem>>('/api/inspection/tasks', { params: { pageNum: 1, pageSize: 1, status: 'PENDING' } })
        .then((r) => { taskMetrics.value.pending = r.total || 0; }),
      request.get<never, PageResult<TaskItem>>('/api/inspection/tasks', { params: { pageNum: 1, pageSize: 1, status: 'IN_PROGRESS' } })
        .then((r) => { taskMetrics.value.inProgress = r.total || 0; }),
      request.get<never, PageResult<TaskItem>>('/api/inspection/tasks', { params: { pageNum: 1, pageSize: 1, status: 'COMPLETED' } })
        .then((r) => { taskMetrics.value.completed = r.total || 0; }),
      request.get<never, PageResult<TaskItem>>('/api/inspection/tasks', { params: { pageNum: 1, pageSize: 5, status: 'PENDING' } })
        .then((r) => { pendingTasks.value = r.records || []; })
    );
  }

  // 3. Maintenance defects & work orders (if user has maintenance:view)
  if (auth.can('maintenance:view')) {
    jobs.push(
      request.get<never, PageResult<DefectItem>>('/api/maintenance/defects', { params: { pageNum: 1, pageSize: 1, status: 'OPEN' } })
        .then((r) => { defectMetrics.value.open = r.total || 0; }),
      request.get<never, PageResult<DefectItem>>('/api/maintenance/defects', { params: { pageNum: 1, pageSize: 1, status: 'CONFIRMED' } })
        .then((r) => { defectMetrics.value.confirmed = r.total || 0; }),
      request.get<never, PageResult<DefectItem>>('/api/maintenance/defects', { params: { pageNum: 1, pageSize: 1, status: 'PROCESSING' } })
        .then((r) => { defectMetrics.value.processing = r.total || 0; }),
      request.get<never, PageResult<DefectItem>>('/api/maintenance/defects', { params: { pageNum: 1, pageSize: 5, status: 'OPEN' } })
        .then((r) => { openDefects.value = r.records || []; }),

      request.get<never, PageResult<WorkOrderItem>>('/api/maintenance/work-orders', { params: { pageNum: 1, pageSize: 1, status: 'PENDING' } })
        .then((r) => { workOrderMetrics.value.pending = r.total || 0; }),
      request.get<never, PageResult<WorkOrderItem>>('/api/maintenance/work-orders', { params: { pageNum: 1, pageSize: 1, status: 'ASSIGNED' } })
        .then((r) => { workOrderMetrics.value.assigned = r.total || 0; }),
      request.get<never, PageResult<WorkOrderItem>>('/api/maintenance/work-orders', { params: { pageNum: 1, pageSize: 1, status: 'PROCESSING' } })
        .then((r) => { workOrderMetrics.value.processing = r.total || 0; }),
      request.get<never, PageResult<WorkOrderItem>>('/api/maintenance/work-orders', { params: { pageNum: 1, pageSize: 1, status: 'WAITING_ACCEPTANCE' } })
        .then((r) => { workOrderMetrics.value.waitingAcceptance = r.total || 0; }),
      request.get<never, PageResult<WorkOrderItem>>('/api/maintenance/work-orders', {
        params: {
          pageNum: 1,
          pageSize: 5,
          status: isMaintainer.value ? 'ASSIGNED' : 'WAITING_ACCEPTANCE'
        }
      }).then((r) => { actionableWorkOrders.value = r.records || []; })
    );
  }

  // 4. AI diagnosis metrics (if user has ai:view)
  if (auth.can('ai:view')) {
    jobs.push(
      request.get<never, PageResult<any>>('/api/ai/diagnoses', { params: { pageNum: 1, pageSize: 1, confirmationStatus: 'PENDING' } })
        .then((r) => { aiMetrics.value.pending = r.total || 0; }),
      request.get<never, PageResult<any>>('/api/ai/diagnoses', { params: { pageNum: 1, pageSize: 1, riskLevel: 'CRITICAL' } })
        .then((r) => { aiMetrics.value.criticalHigh = (r.total || 0); })
    );
  }

  try {
    await Promise.allSettled(jobs);
    await nextTick();
    renderCharts();
  } catch {
    errorMessage.value = '仪表盘数据加载遇到异常，请检查网络或服务状态';
  } finally {
    loading.value = false;
  }
}

function renderCharts() {
  renderStatusChart();
  renderRiskChart();
  renderOpsChart();
}

function renderStatusChart() {
  if (!chartStatusRef.value) return;
  if (!chartStatusInstance) {
    chartStatusInstance = echarts.init(chartStatusRef.value);
  }

  const statusMap = overview.value.byStatus || {};
  const data = [
    { name: '在线 (ONLINE)', value: Number(statusMap.ONLINE || 0), itemStyle: { color: '#10b981' } },
    { name: '离线 (OFFLINE)', value: Number(statusMap.OFFLINE || 0), itemStyle: { color: '#94a3b8' } },
    { name: '故障 (FAULT)', value: Number(statusMap.FAULT || 0), itemStyle: { color: '#ef4444' } },
    { name: '维护中 (MAINTENANCE)', value: Number(statusMap.MAINTENANCE || 0), itemStyle: { color: '#f59e0b' } }
  ].filter((item) => item.value > 0);

  const hasData = data.length > 0;

  chartStatusInstance.setOption({
    title: {
      text: '设备运行状态',
      left: 'center',
      top: 10,
      textStyle: { fontSize: 14, fontWeight: 600, color: '#334155' }
    },
    tooltip: { trigger: 'item', formatter: '{b}: {c} 台 ({d}%)' },
    legend: { bottom: 10, left: 'center', itemWidth: 10, itemHeight: 10 },
    series: [
      {
        name: '设备状态',
        type: 'pie',
        radius: ['45%', '70%'],
        center: ['50%', '50%'],
        avoidLabelOverlap: false,
        itemStyle: { borderRadius: 6, borderColor: '#fff', borderWidth: 2 },
        label: { show: hasData, formatter: '{b}\n{c} 台' },
        data: hasData ? data : [{ name: '暂无数据', value: 0, itemStyle: { color: '#e2e8f0' } }]
      }
    ]
  });
}

function renderRiskChart() {
  if (!chartRiskRef.value) return;
  if (!chartRiskInstance) {
    chartRiskInstance = echarts.init(chartRiskRef.value);
  }

  const riskMap = overview.value.byRiskLevel || {};
  const categories = ['低风险', '中风险', '高风险', '严重风险'];
  const values = [
    Number(riskMap.LOW || 0),
    Number(riskMap.MEDIUM || 0),
    Number(riskMap.HIGH || 0),
    Number(riskMap.CRITICAL || 0)
  ];
  const colors = ['#22c55e', '#3b82f6', '#f97316', '#dc2626'];

  chartRiskInstance.setOption({
    title: {
      text: '设备安全风险分级',
      left: 'center',
      top: 10,
      textStyle: { fontSize: 14, fontWeight: 600, color: '#334155' }
    },
    tooltip: { trigger: 'axis', axisPointer: { type: 'shadow' } },
    grid: { left: '12%', right: '10%', bottom: '15%', top: '25%' },
    xAxis: {
      type: 'category',
      data: categories,
      axisLabel: { fontSize: 11, color: '#64748b' }
    },
    yAxis: {
      type: 'value',
      minInterval: 1,
      splitLine: { lineStyle: { stroke: '#f1f5f9' } }
    },
    series: [
      {
        name: '设备数',
        type: 'bar',
        barWidth: 26,
        data: values.map((val, idx) => ({
          value: val,
          itemStyle: { color: colors[idx], borderRadius: [4, 4, 0, 0] }
        })),
        label: { show: true, position: 'top', color: '#475569' }
      }
    ]
  });
}

function renderOpsChart() {
  if (!chartOpsRef.value) return;
  if (!chartOpsInstance) {
    chartOpsInstance = echarts.init(chartOpsRef.value);
  }

  let title = '业务待办与执行态势';
  let categories: string[] = [];
  let seriesData: { name: string; value: number; color: string }[] = [];

  if (isInspector.value) {
    title = '我的巡检任务执行状态';
    categories = ['待执行任务', '进行中任务', '已完成任务'];
    seriesData = [
      { name: '待执行', value: taskMetrics.value.pending, color: '#f59e0b' },
      { name: '进行中', value: taskMetrics.value.inProgress, color: '#3b82f6' },
      { name: '已完成', value: taskMetrics.value.completed, color: '#10b981' }
    ];
  } else if (isMaintainer.value) {
    title = '我的维修工单与缺陷态势';
    categories = ['待开始维修', '正在处理中', '待验收工单', '待确认缺陷'];
    seriesData = [
      { name: '待开始', value: workOrderMetrics.value.assigned, color: '#f59e0b' },
      { name: '维修中', value: workOrderMetrics.value.processing, color: '#3b82f6' },
      { name: '待验收', value: workOrderMetrics.value.waitingAcceptance, color: '#8b5cf6' },
      { name: '待确认缺陷', value: defectMetrics.value.open, color: '#ef4444' }
    ];
  } else {
    // Admin / Super Admin
    title = '平台巡检与维修协同负荷';
    categories = ['巡检待执行', '巡检进行中', '缺陷待确认', '工单待分派', '工单待验收'];
    seriesData = [
      { name: '巡检待执行', value: taskMetrics.value.pending, color: '#f59e0b' },
      { name: '巡检进行中', value: taskMetrics.value.inProgress, color: '#3b82f6' },
      { name: '缺陷待确认', value: defectMetrics.value.open, color: '#ef4444' },
      { name: '工单待分派', value: workOrderMetrics.value.pending, color: '#ec4899' },
      { name: '工单待验收', value: workOrderMetrics.value.waitingAcceptance, color: '#10b981' }
    ];
  }

  chartOpsInstance.setOption({
    title: {
      text: title,
      left: 'center',
      top: 10,
      textStyle: { fontSize: 14, fontWeight: 600, color: '#334155' }
    },
    tooltip: { trigger: 'axis', axisPointer: { type: 'shadow' } },
    grid: { left: '12%', right: '10%', bottom: '15%', top: '25%' },
    xAxis: {
      type: 'category',
      data: categories,
      axisLabel: { fontSize: 11, interval: 0, color: '#64748b' }
    },
    yAxis: {
      type: 'value',
      minInterval: 1,
      splitLine: { lineStyle: { stroke: '#f1f5f9' } }
    },
    series: [
      {
        name: '数量',
        type: 'bar',
        barWidth: 28,
        data: seriesData.map((item) => ({
          value: item.value,
          itemStyle: { color: item.color, borderRadius: [4, 4, 0, 0] }
        })),
        label: { show: true, position: 'top', color: '#475569' }
      }
    ]
  });
}

function handleResize() {
  chartStatusInstance?.resize();
  chartRiskInstance?.resize();
  chartOpsInstance?.resize();
}

onMounted(() => {
  void loadData();
  window.addEventListener('resize', handleResize);
});

onUnmounted(() => {
  window.removeEventListener('resize', handleResize);
  if (chartStatusInstance) {
    chartStatusInstance.dispose();
    chartStatusInstance = null;
  }
  if (chartRiskInstance) {
    chartRiskInstance.dispose();
    chartRiskInstance = null;
  }
  if (chartOpsInstance) {
    chartOpsInstance.dispose();
    chartOpsInstance = null;
  }
});
</script>

<template>
  <section class="dashboard-page">
    <!-- Page Header -->
    <div class="page-head">
      <div>
        <h1>工业设备智能巡检运维总览</h1>
        <p>基于实时感知与双端协同，掌握设备运行、巡检执行与缺陷修复全闭环。</p>
      </div>
      <div class="head-actions">
        <el-button :icon="View" @click="router.push('/devices/scene')">设备空间三维视图</el-button>
        <el-button :icon="Refresh" @click="loadData">刷新态势</el-button>
      </div>
    </div>

    <!-- Top KPI Cards -->
    <el-row :gutter="16" class="kpi-row" v-loading="loading">
      <el-col :xs="12" :sm="6" :lg="6">
        <el-card shadow="never" class="kpi-card" @click="router.push('/devices')">
          <div class="kpi-icon-box bg-blue">
            <el-icon :size="24"><Cpu /></el-icon>
          </div>
          <div class="kpi-info">
            <span class="kpi-label">设备总台数</span>
            <div class="kpi-value-row">
              <span class="kpi-value">{{ overview.deviceTotal }}</span>
              <span class="kpi-unit">台</span>
            </div>
            <span class="kpi-sub">
              在线 {{ overview.byStatus['ONLINE'] || 0 }} · 故障 {{ overview.byStatus['FAULT'] || 0 }}
            </span>
          </div>
        </el-card>
      </el-col>

      <el-col :xs="12" :sm="6" :lg="6">
        <el-card shadow="never" class="kpi-card" @click="router.push('/inspection/tasks')">
          <div class="kpi-icon-box bg-amber">
            <el-icon :size="24"><DocumentChecked /></el-icon>
          </div>
          <div class="kpi-info">
            <span class="kpi-label">{{ isInspector ? '我的待执行任务' : '待执行巡检' }}</span>
            <div class="kpi-value-row">
              <span class="kpi-value text-amber">{{ taskMetrics.pending }}</span>
              <span class="kpi-unit">项</span>
            </div>
            <span class="kpi-sub">
              进行中 {{ taskMetrics.inProgress }} · 已完成 {{ taskMetrics.completed }}
            </span>
          </div>
        </el-card>
      </el-col>

      <el-col :xs="12" :sm="6" :lg="6">
        <el-card shadow="never" class="kpi-card" @click="router.push('/maintenance/defects')">
          <div class="kpi-icon-box bg-red">
            <el-icon :size="24"><Warning /></el-icon>
          </div>
          <div class="kpi-info">
            <span class="kpi-label">待处理缺陷</span>
            <div class="kpi-value-row">
              <span class="kpi-value text-red">{{ defectMetrics.open }}</span>
              <span class="kpi-unit">起</span>
            </div>
            <span class="kpi-sub">
              已确认 {{ defectMetrics.confirmed }} · 修复中 {{ defectMetrics.processing }}
            </span>
          </div>
        </el-card>
      </el-col>

      <el-col :xs="12" :sm="6" :lg="6">
        <el-card shadow="never" class="kpi-card" @click="router.push('/maintenance/work-orders')">
          <div class="kpi-icon-box bg-purple">
            <el-icon :size="24"><Tools /></el-icon>
          </div>
          <div class="kpi-info">
            <span class="kpi-label">{{ isMaintainer ? '我的待处理工单' : '待验收工单' }}</span>
            <div class="kpi-value-row">
              <span class="kpi-value text-purple">
                {{ isMaintainer ? workOrderMetrics.assigned : workOrderMetrics.waitingAcceptance }}
              </span>
              <span class="kpi-unit">单</span>
            </div>
            <span class="kpi-sub">
              待分派 {{ workOrderMetrics.pending }} · 维修中 {{ workOrderMetrics.processing }}
            </span>
          </div>
        </el-card>
      </el-col>
    </el-row>

    <!-- 3 ECharts Visual Panels -->
    <el-row :gutter="16" class="charts-row" v-loading="loading">
      <el-col :xs="24" :md="8">
        <el-card shadow="never" class="chart-card">
          <div ref="chartStatusRef" class="chart-box" />
        </el-card>
      </el-col>

      <el-col :xs="24" :md="8">
        <el-card shadow="never" class="chart-card">
          <div ref="chartRiskRef" class="chart-box" />
        </el-card>
      </el-col>

      <el-col :xs="24" :md="8">
        <el-card shadow="never" class="chart-card">
          <div ref="chartOpsRef" class="chart-box" />
        </el-card>
      </el-col>
    </el-row>

    <!-- Role-based Actionable Work & Quick Navigation -->
    <el-row :gutter="16" class="action-row" v-loading="loading">
      <!-- Left Column: Actionable Todo List -->
      <el-col :xs="24" :lg="16">
        <el-card shadow="never" class="todo-card">
          <template #header>
            <div class="card-header-flex">
              <strong>
                {{ isInspector ? '现场巡检待办任务' : isMaintainer ? '现场维修工单待办' : '重点关注与待办事项' }}
              </strong>
              <el-button
                link
                type="primary"
                @click="
                  router.push(
                    isInspector
                      ? '/inspection/tasks'
                      : isMaintainer
                      ? '/maintenance/work-orders'
                      : '/maintenance/work-orders'
                  )
                "
              >
                查看全部 <el-icon><Right /></el-icon>
              </el-button>
            </div>
          </template>

          <!-- Inspector Todo: Pending Inspection Tasks -->
          <template v-if="isInspector">
            <el-table v-if="pendingTasks.length" :data="pendingTasks" size="small">
              <el-table-column prop="taskCode" label="任务编码" min-width="150" />
              <el-table-column label="任务状态" width="100">
                <template #default="s"><el-tag type="warning">{{ displayValue(s.row.status) }}</el-tag></template>
              </el-table-column>
              <el-table-column label="创建时间" min-width="150">
                <template #default="s">{{ s.row.createdAt?.replace('T', ' ').slice(0, 19) }}</template>
              </el-table-column>
              <el-table-column label="操作" width="100" fixed="right">
                <template #default="s">
                  <el-button link type="primary" @click="router.push(`/inspection/tasks/${s.row.id}`)">
                    去执行
                  </el-button>
                </template>
              </el-table-column>
            </el-table>
            <el-empty v-else description="暂无待执行巡检任务，设备运行良好" :image-size="70" />
          </template>

          <!-- Maintainer Todo: Assigned Work Orders -->
          <template v-else-if="isMaintainer">
            <el-table v-if="actionableWorkOrders.length" :data="actionableWorkOrders" size="small">
              <el-table-column prop="workOrderCode" label="工单编码" min-width="140" />
              <el-table-column prop="title" label="工单标题" min-width="160" />
              <el-table-column label="状态" width="100">
                <template #default="s"><el-tag type="warning">{{ displayValue(s.row.status) }}</el-tag></template>
              </el-table-column>
              <el-table-column label="优先级" width="90">
                <template #default="s">
                  <el-tag :type="s.row.priority === 'URGENT' ? 'danger' : 'info'" size="small">
                    {{ displayValue(s.row.priority) }}
                  </el-tag>
                </template>
              </el-table-column>
              <el-table-column label="操作" width="100" fixed="right">
                <template #default="s">
                  <el-button link type="primary" @click="router.push(`/maintenance/work-orders/${s.row.id}`)">
                    开始维修
                  </el-button>
                </template>
              </el-table-column>
            </el-table>
            <el-empty v-else description="暂无分派给本人的待维修工单" :image-size="70" />
          </template>

          <!-- Admin / Super Admin Todo: Waiting Acceptance Work Orders or Open Defects -->
          <template v-else>
            <div class="admin-todo-tabs">
              <div v-if="actionableWorkOrders.length" class="mb-3">
                <div class="subhead">待业务管理员验收工单 ({{ actionableWorkOrders.length }})</div>
                <el-table :data="actionableWorkOrders" size="small">
                  <el-table-column prop="workOrderCode" label="工单编号" min-width="140" />
                  <el-table-column prop="title" label="工单标题" min-width="160" />
                  <el-table-column label="状态" width="100">
                    <template #default="s"><el-tag type="success">{{ displayValue(s.row.status) }}</el-tag></template>
                  </el-table-column>
                  <el-table-column label="操作" width="100" fixed="right">
                    <template #default="s">
                      <el-button link type="primary" @click="router.push(`/maintenance/work-orders/${s.row.id}`)">
                        去验收
                      </el-button>
                    </template>
                  </el-table-column>
                </el-table>
              </div>

              <div v-if="openDefects.length">
                <div class="subhead">待确认设备缺陷 ({{ openDefects.length }})</div>
                <el-table :data="openDefects" size="small">
                  <el-table-column prop="defectCode" label="缺陷编码" min-width="140" />
                  <el-table-column prop="title" label="缺陷描述" min-width="160" />
                  <el-table-column label="严重度" width="90">
                    <template #default="s">
                      <el-tag :type="s.row.severity === 'CRITICAL' ? 'danger' : 'warning'" size="small">
                        {{ displayValue(s.row.severity) }}
                      </el-tag>
                    </template>
                  </el-table-column>
                  <el-table-column label="操作" width="100" fixed="right">
                    <template #default="s">
                      <el-button link type="primary" @click="router.push(`/maintenance/defects/${s.row.id}`)">
                        处理
                      </el-button>
                    </template>
                  </el-table-column>
                </el-table>
              </div>

              <el-empty
                v-if="!actionableWorkOrders.length && !openDefects.length"
                description="当前无待验收工单或待确认缺陷"
                :image-size="70"
              />
            </div>
          </template>
        </el-card>
      </el-col>

      <!-- Right Column: Quick Navigation & Governance -->
      <el-col :xs="24" :lg="8">
        <el-card shadow="never" class="quick-nav-card">
          <template #header><strong>快速业务通道</strong></template>

          <div class="quick-links-grid">
            <div class="quick-link-item" @click="router.push('/devices/scene')">
              <el-icon class="link-icon text-blue"><View /></el-icon>
              <div class="link-text">
                <span class="link-title">设备空间视图</span>
                <span class="link-desc">Three.js 三维场景</span>
              </div>
            </div>

            <div
              v-if="auth.can('inspection:view')"
              class="quick-link-item"
              @click="router.push('/inspection/tasks')"
            >
              <el-icon class="link-icon text-amber"><DocumentChecked /></el-icon>
              <div class="link-text">
                <span class="link-title">巡检执行</span>
                <span class="link-desc">任务与异常处置</span>
              </div>
            </div>

            <div
              v-if="auth.can('maintenance:view')"
              class="quick-link-item"
              @click="router.push('/maintenance/work-orders')"
            >
              <el-icon class="link-icon text-purple"><Tools /></el-icon>
              <div class="link-text">
                <span class="link-title">维修工单</span>
                <span class="link-desc">维修推进与验收</span>
              </div>
            </div>

            <div
              v-if="auth.can('ai:view')"
              class="quick-link-item"
              @click="router.push('/ai/diagnoses')"
            >
              <el-icon class="link-icon text-green"><DataAnalysis /></el-icon>
              <div class="link-text">
                <span class="link-title">AI 智能诊断</span>
                <span class="link-desc">DeepSeek 结构化排查</span>
              </div>
            </div>

            <div
              v-if="isSuperAdmin"
              class="quick-link-item"
              @click="router.push('/system/users')"
            >
              <el-icon class="link-icon text-slate"><User /></el-icon>
              <div class="link-text">
                <span class="link-title">用户治理</span>
                <span class="link-desc">平台账号与固定岗位</span>
              </div>
            </div>
          </div>
        </el-card>
      </el-col>
    </el-row>
  </section>
</template>

<style scoped>
.dashboard-page {
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.head-actions {
  display: flex;
  gap: 10px;
}

.kpi-row {
  margin-bottom: 0;
}

.kpi-card {
  border-radius: 8px;
  cursor: pointer;
  transition: all 0.2s ease;
}

.kpi-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.08);
}

.kpi-card :deep(.el-card__body) {
  display: flex;
  align-items: center;
  gap: 14px;
  padding: 16px;
}

.kpi-icon-box {
  width: 48px;
  height: 48px;
  border-radius: 8px;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.bg-blue { background: #e0f2fe; color: #0284c7; }
.bg-amber { background: #fef3c7; color: #d97706; }
.bg-red { background: #fee2e2; color: #dc2626; }
.bg-purple { background: #f3e8ff; color: #9333ea; }

.kpi-info {
  display: flex;
  flex-direction: column;
  min-width: 0;
}

.kpi-label {
  font-size: 12px;
  color: #64748b;
  font-weight: 500;
}

.kpi-value-row {
  display: flex;
  align-items: baseline;
  gap: 4px;
  margin: 2px 0;
}

.kpi-value {
  font-size: 24px;
  font-weight: 700;
  color: #1e293b;
  line-height: 1.2;
}

.text-amber { color: #d97706; }
.text-red { color: #dc2626; }
.text-purple { color: #9333ea; }

.kpi-unit {
  font-size: 12px;
  color: #94a3b8;
}

.kpi-sub {
  font-size: 11px;
  color: #94a3b8;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.charts-row {
  margin-bottom: 0;
}

.chart-card {
  border-radius: 8px;
}

.chart-box {
  width: 100%;
  height: 260px;
}

.action-row {
  margin-bottom: 0;
}

.todo-card,
.quick-nav-card {
  border-radius: 8px;
  height: 100%;
}

.card-header-flex {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.subhead {
  font-size: 13px;
  font-weight: 600;
  color: #475569;
  margin-bottom: 8px;
}

.quick-links-grid {
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.quick-link-item {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 10px 14px;
  border-radius: 6px;
  background: #f8fafc;
  border: 1px solid #e2e8f0;
  cursor: pointer;
  transition: all 0.15s ease;
}

.quick-link-item:hover {
  background: #f1f5f9;
  border-color: #cbd5e1;
}

.link-icon {
  font-size: 20px;
}

.text-blue { color: #0284c7; }
.text-green { color: #10b981; }
.text-slate { color: #475569; }

.link-text {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.link-title {
  font-size: 13px;
  font-weight: 600;
  color: #1e293b;
}

.link-desc {
  font-size: 11px;
  color: #64748b;
}
</style>
