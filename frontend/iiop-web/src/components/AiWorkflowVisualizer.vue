<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { VueFlow, type NodeMouseEvent } from '@vue-flow/core';
import '@vue-flow/core/dist/style.css';
import '@vue-flow/core/dist/theme-default.css';
import type { WorkflowTrace } from '../types/maintenance';

const props = defineProps<{
  trace: WorkflowTrace[];
  summaries: Record<string, string[]>;
}>();

const catalog = [
  { code: 'LOAD_CONTEXT', name: '数据汇聚', icon: '汇', running: '正在汇聚设备与运维上下文' },
  { code: 'ANALYZE_WITH_DEEPSEEK', name: 'AI 智能研判', icon: 'AI', running: '正在进行 AI 智能研判' },
  { code: 'RISK_CHECK', name: '风险校验', icon: '险', running: '正在校验风险等级' },
  { code: 'GENERATE_ADVICE', name: '处置方案', icon: '策', running: '正在生成处置建议' },
  { code: 'PREPARE_WORK_ORDER_DRAFT', name: '工单草案', icon: '单', running: '正在准备维修工单草案' }
] as const;

const selectedCode = ref(catalog[0].code as string);
const byCode = computed(() => Object.fromEntries(props.trace.map((item) => [item.nodeCode, item])));
const statusText = (status: string) => ({ PENDING: '等待执行', RUNNING: '正在分析', SUCCEEDED: '已完成', FAILED: '执行失败', SKIPPED: '已跳过' }[status] ?? '等待执行');
const durationText = (value: number | null | undefined) => value == null ? '—' : value < 1000 ? `${value} ms` : `${(value / 1000).toFixed(1)} s`;
const friendlyError = (value: string | null | undefined) => {
  const raw = (value ?? '').trim();
  if (!raw) return '';
  if (/timeout|timed out|超时/i.test(raw)) return '该阶段等待超时，工作流已安全终止。';
  if (/connect|connection|refused|unavailable|503|网络/i.test(raw)) return '智能分析服务暂时不可用。';
  if (/exception|\bat\b|\.java:|org\.|com\.|stack|trace/i.test(raw)) return '该阶段执行异常，未产生可用业务结果。';
  return raw.length > 100 ? `${raw.slice(0, 100)}…` : raw;
};

const nodes = computed(() => catalog.map((step, index) => {
  const item = byCode.value[step.code];
  const status = item?.status ?? 'PENDING';
  return {
    id: step.code,
    type: 'diagnosis',
    position: { x: index * 226, y: 22 },
    data: {
      name: step.name,
      icon: step.icon,
      status,
      statusText: statusText(status),
      duration: durationText(item?.duration),
      summary: status === 'RUNNING' ? step.running : (item?.message || '等待前序步骤完成')
    },
    selectable: true,
    draggable: false
  };
}));

const edges = computed(() => catalog.slice(0, -1).map((step, index) => {
  const source = byCode.value[step.code]?.status ?? 'PENDING';
  const target = byCode.value[catalog[index + 1].code]?.status ?? 'PENDING';
  const active = source === 'SUCCEEDED' && ['RUNNING', 'SUCCEEDED', 'FAILED'].includes(target);
  return {
    id: `edge-${index}`,
    source: step.code,
    target: catalog[index + 1].code,
    animated: source === 'SUCCEEDED' && target === 'RUNNING',
    style: { stroke: active ? '#27c2d7' : '#526171', strokeWidth: active ? 2.5 : 1.5 }
  };
}));

const selected = computed(() => {
  const step = catalog.find((item) => item.code === selectedCode.value) ?? catalog[0];
  const item = byCode.value[step.code];
  return {
    ...step,
    status: item?.status ?? 'PENDING',
    statusText: statusText(item?.status ?? 'PENDING'),
    duration: durationText(item?.duration),
    message: item?.message || '该步骤尚未开始。',
    error: friendlyError(item?.errorMessage),
    highlights: props.summaries[step.code] ?? []
  };
});

function choose(event: NodeMouseEvent) {
  selectedCode.value = event.node.id;
}

watch(() => props.trace, () => {
  const current = catalog.find((step) => byCode.value[step.code]?.status === 'RUNNING')
    ?? catalog.find((step) => byCode.value[step.code]?.status === 'FAILED');
  if (current) selectedCode.value = current.code;
}, { immediate: true, deep: true });
</script>

<template>
  <section class="workflow-panel">
    <div class="section-heading">
      <div>
        <span class="eyebrow">AI WORKFLOW</span>
        <h2>智能诊断执行流</h2>
      </div>
      <span class="heading-tip">点击步骤查看业务摘要</span>
    </div>
    <div class="flow-shell">
      <VueFlow
        :nodes="nodes"
        :edges="edges"
        :nodes-draggable="false"
        :nodes-connectable="false"
        :elements-selectable="true"
        :zoom-on-scroll="false"
        :zoom-on-pinch="false"
        :pan-on-drag="false"
        :prevent-scrolling="false"
        :fit-view-on-init="true"
        :min-zoom="0.55"
        :max-zoom="1"
        class="diagnosis-flow"
        @node-click="choose"
      >
        <template #node-diagnosis="slotProps">
          <article class="flow-node" :class="[`is-${slotProps.data.status.toLowerCase()}`, { selected: selectedCode === slotProps.id }]">
            <div class="node-top">
              <span class="node-icon">{{ slotProps.data.icon }}</span>
              <span class="node-status">{{ slotProps.data.statusText }}</span>
            </div>
            <strong>{{ slotProps.data.name }}</strong>
            <p>{{ slotProps.data.summary }}</p>
            <span class="node-duration">耗时 {{ slotProps.data.duration }}</span>
          </article>
        </template>
      </VueFlow>
    </div>
    <div class="step-detail" :class="`is-${selected.status.toLowerCase()}`">
      <div>
        <span class="detail-status">{{ selected.statusText }}</span>
        <h3>{{ selected.name }}完成了什么</h3>
        <p>{{ selected.message }}</p>
      </div>
      <ul v-if="selected.highlights.length">
        <li v-for="item in selected.highlights" :key="item">{{ item }}</li>
      </ul>
      <p v-if="selected.error" class="step-error">{{ selected.error }}</p>
    </div>
  </section>
</template>

<style scoped>
.workflow-panel{padding:24px;border:1px solid #253849;border-radius:14px;background:linear-gradient(145deg,#111b24,#172531);box-shadow:0 14px 34px rgba(5,15,24,.12);color:#eef8fb}.section-heading{display:flex;align-items:flex-end;justify-content:space-between;margin-bottom:8px}.section-heading h2{margin:4px 0 0;font-size:21px}.eyebrow{color:#66d7e5;font-size:11px;font-weight:700;letter-spacing:.18em}.heading-tip{color:#90a5b4;font-size:12px}.flow-shell{height:235px;overflow:hidden}.diagnosis-flow{height:100%;background:transparent}.flow-node{width:192px;min-height:154px;padding:15px;border:1px solid #405363;border-radius:11px;background:#1b2a36;box-shadow:0 9px 22px rgba(0,0,0,.18);cursor:pointer;transition:.2s ease}.flow-node:hover,.flow-node.selected{transform:translateY(-2px);border-color:#65d3e1}.flow-node.is-running{border-color:#3dd2e5;box-shadow:0 0 0 1px rgba(61,210,229,.25),0 0 22px rgba(44,191,211,.18);animation:node-pulse 2.2s ease-in-out infinite}.flow-node.is-succeeded{border-color:#2d887f}.flow-node.is-failed{border-color:#d46666}.node-top{display:flex;align-items:center;justify-content:space-between;margin-bottom:13px}.node-icon{display:grid;width:34px;height:34px;place-items:center;border-radius:9px;background:#254352;color:#71dce8;font-size:12px;font-weight:800}.node-status{color:#9eb1bd;font-size:11px}.is-running .node-status{color:#65d9e7}.is-succeeded .node-status{color:#71d2a5}.is-failed .node-status{color:#f39191}.flow-node strong{display:block;font-size:15px}.flow-node p{height:34px;margin:8px 0 10px;overflow:hidden;color:#aebdc6;font-size:12px;line-height:1.45}.node-duration{color:#718796;font-size:11px}.step-detail{display:grid;grid-template-columns:minmax(260px,1fr) minmax(280px,1.15fr);gap:24px;padding:18px 20px;border:1px solid #324655;border-radius:10px;background:rgba(8,17,24,.38)}.step-detail h3{margin:5px 0;font-size:15px}.step-detail p{margin:0;color:#aebdc6;font-size:13px;line-height:1.6}.detail-status{color:#65d9e7;font-size:11px;font-weight:700}.step-detail ul{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:7px 18px;margin:0;padding-left:18px;color:#d8e6eb;font-size:13px}.step-error{grid-column:1/-1;color:#f39191!important}.vue-flow :deep(.vue-flow__node){width:auto}.vue-flow :deep(.vue-flow__edge-path){transition:stroke .2s}.vue-flow :deep(.vue-flow__edge.animated path){stroke-dasharray:6;animation-duration:1.5s}@keyframes node-pulse{50%{box-shadow:0 0 0 3px rgba(61,210,229,.12),0 0 26px rgba(44,191,211,.25)}}@media(max-width:900px){.step-detail{grid-template-columns:1fr}.step-detail ul{grid-template-columns:1fr}.flow-shell{overflow-x:auto}.diagnosis-flow{min-width:1120px}}
</style>
