<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref } from 'vue';
import { useRouter } from 'vue-router';
import { ElMessage } from 'element-plus';
import { Check, Notification } from '@element-plus/icons-vue';
import { request } from '../api/request';
import { useAuthStore } from '../stores/auth';
import { displayValue } from '../utils/display';
import { notificationSocket, type NotificationMessage } from '../services/notificationSocket';

interface PageResult<T> {
  current: number;
  size: number;
  total: number;
  records: T[];
}

const auth = useAuthStore();
const router = useRouter();

const rows = ref<NotificationMessage[]>([]);
const total = ref(0);
const page = ref(1);
const pageSize = 15;
const loading = ref(false);
const errorMessage = ref('');
const markingAll = ref(false);
const markingId = ref('');

const hasUnread = computed(() => rows.value.some((r) => r.readStatus === 'UNREAD') || auth.unread > 0);

function formatDateTime(v: string | null | undefined) {
  if (!v) return '-';
  return v.replace('T', ' ').slice(0, 19);
}

function resolveBizPath(row: NotificationMessage): string | null {
  return notificationSocket.resolveBizRoute(row.bizType, row.bizId);
}

function handleBizNavigate(row: NotificationMessage) {
  const path = resolveBizPath(row);
  if (path) {
    if (row.readStatus === 'UNREAD') {
      void markAsRead(row, false);
    }
    void router.push(path);
  }
}

async function load() {
  loading.value = true;
  errorMessage.value = '';
  try {
    const data = await request.get<never, PageResult<NotificationMessage>>('/api/auth/notifications', {
      params: {
        pageNum: page.value,
        pageSize
      }
    });
    rows.value = data.records ?? [];
    total.value = data.total ?? 0;
    void auth.refreshUnread();
  } catch {
    errorMessage.value = '通知列表加载失败，请检查服务状态后重试。';
  } finally {
    loading.value = false;
  }
}

async function markAsRead(row: NotificationMessage, showMsg = true) {
  if (row.readStatus === 'READ') return;
  markingId.value = row.id;
  try {
    await request.put(`/api/auth/notifications/${row.id}/read`);
    row.readStatus = 'READ';
    row.readTime = new Date().toISOString();
    if (showMsg) ElMessage.success('已标记为已读');
    void auth.refreshUnread();
  } catch {
    // request.ts handles error prompt
  } finally {
    markingId.value = '';
  }
}

async function markAllAsRead() {
  markingAll.value = true;
  try {
    await request.put('/api/auth/notifications/read-all');
    ElMessage.success('全部未读通知已标记为已读');
    rows.value.forEach((r) => {
      r.readStatus = 'READ';
    });
    void auth.refreshUnread();
    await load();
  } catch {
    // request.ts handles error prompt
  } finally {
    markingAll.value = false;
  }
}

let unsubscribe: (() => void) | null = null;

onMounted(() => {
  void load();
  unsubscribe = notificationSocket.subscribe(() => {
    // When a live notification arrives, automatically refresh list
    void load();
  });
});

onUnmounted(() => {
  if (unsubscribe) {
    unsubscribe();
    unsubscribe = null;
  }
});
</script>

<template>
  <section class="notification-page">
    <div class="page-head">
      <div>
        <h1>通知中心</h1>
        <p>集中接收与查看指派工单、系统提醒等实时业务消息。</p>
      </div>
      <div class="head-actions">
        <el-button
          v-if="hasUnread"
          type="primary"
          :icon="Check"
          :loading="markingAll"
          @click="markAllAsRead"
        >
          全部标为已读
        </el-button>
        <el-button @click="load">刷新</el-button>
      </div>
    </div>

    <el-alert
      v-if="errorMessage"
      :title="errorMessage"
      type="error"
      show-icon
      :closable="false"
      class="mb-4"
    >
      <template #default>
        <el-button link type="primary" @click="load">重新加载</el-button>
      </template>
    </el-alert>

    <el-card v-else shadow="never" class="notification-card">
      <div v-loading="loading" class="notification-list">
        <template v-if="rows.length">
          <article
            v-for="item in rows"
            :key="item.id"
            class="notification-item"
            :class="{ 'is-unread': item.readStatus === 'UNREAD' }"
          >
            <div class="item-icon-box">
              <el-icon class="item-icon" :size="20"><Notification /></el-icon>
            </div>
            <div class="item-body">
              <header class="item-header">
                <div class="header-main">
                  <span v-if="item.readStatus === 'UNREAD'" class="unread-dot" title="未读通知" />
                  <h3 class="item-title">{{ item.title }}</h3>
                  <el-tag
                    v-if="item.notificationType"
                    size="small"
                    effect="plain"
                    class="type-tag"
                  >
                    {{ displayValue(item.notificationType) }}
                  </el-tag>
                </div>
                <time class="item-time">{{ formatDateTime(item.createdAt) }}</time>
              </header>

              <p class="item-content">{{ item.content }}</p>

              <footer class="item-footer">
                <div class="biz-info">
                  <template v-if="item.bizType && item.bizId">
                    <span class="biz-label">关联业务：</span>
                    <el-tag size="small" type="info">{{ displayValue(item.bizType) }}</el-tag>
                    <el-button
                      v-if="resolveBizPath(item)"
                      link
                      type="primary"
                      class="biz-link-btn"
                      @click="handleBizNavigate(item)"
                    >
                      查看对应业务详情 →
                    </el-button>
                    <span v-else class="biz-id-text">暂无可跳转业务</span>
                  </template>
                </div>

                <div class="item-actions">
                  <el-button
                    v-if="item.readStatus === 'UNREAD'"
                    link
                    type="primary"
                    size="small"
                    :loading="markingId === item.id"
                    @click="markAsRead(item)"
                  >
                    标为已读
                  </el-button>
                  <span v-else class="read-status-text">
                    已读 · {{ formatDateTime(item.readTime) }}
                  </span>
                </div>
              </footer>
            </div>
          </article>
        </template>
        <el-empty
          v-else
          description="暂无未读或历史通知"
          :image-size="120"
        />
      </div>

      <div v-if="total > pageSize" class="pagination-box">
        <el-pagination
          v-model:current-page="page"
          layout="prev, pager, next, total"
          :page-size="pageSize"
          :total="total"
          @current-change="load"
        />
      </div>
    </el-card>
  </section>
</template>

<style scoped>
.notification-page {
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.head-actions {
  display: flex;
  gap: 10px;
}

.notification-card {
  border-radius: 8px;
}

.notification-list {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.notification-item {
  display: flex;
  gap: 16px;
  padding: 16px 20px;
  border-radius: 8px;
  background: #fafbfc;
  border: 1px solid #eef2f6;
  transition: all 0.2s ease;
}

.notification-item:hover {
  background: #f4f8fd;
  border-color: #d0e2fa;
}

.notification-item.is-unread {
  background: #ffffff;
  border-color: #b9d8ff;
  box-shadow: 0 2px 8px rgba(23, 105, 170, 0.08);
}

.item-icon-box {
  flex-shrink: 0;
  width: 40px;
  height: 40px;
  border-radius: 50%;
  background: #eef4fc;
  color: #1769aa;
  display: flex;
  align-items: center;
  justify-content: center;
}

.notification-item.is-unread .item-icon-box {
  background: #1769aa;
  color: #ffffff;
}

.item-body {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.item-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}

.header-main {
  display: flex;
  align-items: center;
  gap: 10px;
  min-width: 0;
}

.unread-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background: #f56c6c;
  flex-shrink: 0;
}

.item-title {
  margin: 0;
  font-size: 15px;
  font-weight: 600;
  color: #1f2937;
}

.notification-item.is-unread .item-title {
  color: #0f172a;
  font-weight: 700;
}

.item-time {
  font-size: 12px;
  color: #94a3b8;
  white-space: nowrap;
}

.item-content {
  margin: 0;
  font-size: 13px;
  line-height: 1.6;
  color: #475569;
  word-break: break-word;
}

.notification-item.is-unread .item-content {
  color: #334155;
}

.item-footer {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  margin-top: 4px;
  font-size: 12px;
}

.biz-info {
  display: flex;
  align-items: center;
  gap: 8px;
}

.biz-label {
  color: #64748b;
}

.biz-link-btn {
  font-size: 12px;
  padding: 0;
}

.biz-id-text {
  color: #94a3b8;
}

.item-actions {
  display: flex;
  align-items: center;
  gap: 8px;
  white-space: nowrap;
}

.read-status-text {
  color: #94a3b8;
  font-size: 12px;
}

.pagination-box {
  display: flex;
  justify-content: flex-end;
  margin-top: 20px;
}
</style>
