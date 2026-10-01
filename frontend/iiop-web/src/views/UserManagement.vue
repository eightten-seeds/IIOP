<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, reactive, ref } from 'vue';
import { onBeforeRouteLeave } from 'vue-router';
import { ElMessage, ElMessageBox } from 'element-plus';
import { request } from '../api/request';
import { useAuthStore } from '../stores/auth';
import { displayValue } from '../utils/display';

interface UserSummary {
  id: string;
  username: string;
  realName: string | null;
  status: 'ENABLED' | 'DISABLED' | 'LOCKED';
  phone?: string | null;
  email?: string | null;
  avatarUrl?: string | null;
}

interface RoleView {
  id: string;
  roleCode: 'SUPER_ADMIN' | 'ADMIN' | 'INSPECTOR' | 'MAINTAINER';
  roleName: string;
  description: string | null;
  status: string;
}

interface PageResult<T> {
  current: number;
  size: number;
  total: number;
  records: T[];
}

interface UserCreateForm {
  username: string;
  password: string;
  realName: string;
  phone: string;
  email: string;
  avatarUrl: string;
  status: UserSummary['status'];
}

interface UserEditForm {
  realName: string;
  phone: string;
  email: string;
  avatarUrl: string;
}

const auth = useAuthStore();
const rows = ref<UserSummary[]>([]);
const roles = ref<RoleView[]>([]);
const loading = ref(false);
const errorMessage = ref('');
const total = ref(0);
const page = ref(1);
const pageSize = 20;
const filters = reactive({ keyword: '', status: '', roleCode: '' });
const createVisible = ref(false);
const editVisible = ref(false);
const roleVisible = ref(false);
const saving = ref(false);
const editLoading = ref(false);
const statusSavingId = ref('');
const deletingId = ref('');
const roleLoading = ref(false);
const roleUser = ref<UserSummary | null>(null);
const selectedRoleIds = ref<string[]>([]);
const initialRoleIds = ref<string[]>([]);
const createForm = reactive<UserCreateForm>({ username: '', password: '', realName: '', phone: '', email: '', avatarUrl: '', status: 'ENABLED' });
const editForm = reactive<UserEditForm>({ realName: '', phone: '', email: '', avatarUrl: '' });
const editTouched = reactive<Record<keyof UserEditForm, boolean>>({ realName: false, phone: false, email: false, avatarUrl: false });
const editUser = ref<UserSummary | null>(null);

const resetVisible = ref(false);
const resetSaving = ref(false);
const resetUser = ref<UserSummary | null>(null);
const resetForm = reactive({ newPassword: '', confirmPassword: '' });

const canManageSuperAdmin = computed(() => auth.roles.includes('SUPER_ADMIN') && auth.can('system:role:permission'));

function resetCreateForm() {
  Object.assign(createForm, { username: '', password: '', realName: '', phone: '', email: '', avatarUrl: '', status: 'ENABLED' });
}

async function load() {
  loading.value = true;
  errorMessage.value = '';
  try {
    const data = await request.get<never, PageResult<UserSummary>>('/api/auth/users', {
      params: {
        pageNum: page.value,
        pageSize,
        keyword: filters.keyword || undefined,
        status: filters.status || undefined,
        roleCode: filters.roleCode || undefined
      }
    });
    rows.value = data.records ?? [];
    total.value = data.total ?? 0;
  } catch {
    errorMessage.value = '用户列表加载失败，请检查服务状态后重试。';
  } finally {
    loading.value = false;
  }
}

async function loadRoles() {
  roles.value = await request.get<never, RoleView[]>('/api/auth/roles');
}

function search() {
  page.value = 1;
  void load();
}

function openCreate() {
  resetCreateForm();
  createVisible.value = true;
}

async function createUser() {
  if (saving.value) return;
  if (!createForm.username.trim()) return void ElMessage.warning('请输入用户名');
  if (createForm.password.length < 8 || createForm.password.length > 72) return void ElMessage.warning('密码长度必须为 8~72 位');
  saving.value = true;
  try {
    await request.post('/api/auth/users', { ...createForm });
    ElMessage.success('用户创建成功');
    createVisible.value = false;
    await load();
  } finally {
    saving.value = false;
  }
}

async function openEdit(row: UserSummary) {
  editLoading.value = true;
  try {
    const detail = await request.get<never, UserSummary>(`/api/auth/users/${row.id}`);
    editUser.value = detail;
    Object.assign(editForm, {
      realName: detail.realName ?? '',
      phone: detail.phone ?? '',
      email: detail.email ?? '',
      avatarUrl: detail.avatarUrl ?? ''
    });
    Object.assign(editTouched, { realName: false, phone: false, email: false, avatarUrl: false });
    editVisible.value = true;
  } finally {
    editLoading.value = false;
  }
}

async function updateUser() {
  if (saving.value || !editUser.value) return;
  const payload: Partial<UserEditForm> = {};
  (Object.keys(editTouched) as Array<keyof UserEditForm>).forEach((field) => {
    if (editTouched[field]) payload[field] = editForm[field];
  });
  if (!Object.keys(payload).length) return void ElMessage.warning('请先修改需要更新的资料');
  saving.value = true;
  try {
    await request.put(`/api/auth/users/${editUser.value.id}`, payload);
    ElMessage.success('用户资料更新成功');
    editVisible.value = false;
    await load();
  } finally {
    saving.value = false;
  }
}

function markEditTouched(field: keyof UserEditForm) {
  editTouched[field] = true;
}

async function targetRoles(userId: string) {
  return request.get<never, RoleView[]>(`/api/auth/users/${userId}/roles`);
}

async function updateStatus(row: UserSummary, status: UserSummary['status']) {
  if (statusSavingId.value) return;
  statusSavingId.value = row.id;
  try {
    const assigned = await targetRoles(row.id);
    if (assigned.some((role) => role.roleCode === 'SUPER_ADMIN') && !canManageSuperAdmin.value) {
      ElMessage.warning('业务管理员不能修改超级管理员账号状态');
      return;
    }
    const fieldWarning = status === 'DISABLED' || status === 'LOCKED'
      ? '停用或锁定现场人员不会自动迁移其在途巡检任务或维修工单，请先确认在途工作已妥善处理。'
      : '确认启用该用户吗？';
    try {
      await ElMessageBox.confirm(fieldWarning, `${displayValue(status)}用户`, { type: 'warning', confirmButtonText: '确认', cancelButtonText: '取消' });
    } catch {
      return;
    }
    await request.put(`/api/auth/users/${row.id}/status`, { status });
    ElMessage.success(`用户已${displayValue(status)}`);
    await load();
  } finally {
    statusSavingId.value = '';
  }
}

async function openRoles(row: UserSummary) {
  roleLoading.value = true;
  roleUser.value = row;
  try {
    const [allRoles, assignedRoles] = await Promise.all([
      request.get<never, RoleView[]>('/api/auth/roles'),
      targetRoles(row.id)
    ]);
    roles.value = allRoles;
    selectedRoleIds.value = assignedRoles.map((role) => role.id);
    initialRoleIds.value = [...selectedRoleIds.value];
    roleVisible.value = true;
  } finally {
    roleLoading.value = false;
  }
}

function roleDisabled(role: RoleView) {
  if (role.roleCode !== 'SUPER_ADMIN') return false;
  if (!canManageSuperAdmin.value) return true;
  return roleUser.value?.id === auth.currentUser?.id;
}

function roleHelp(role: RoleView) {
  if (role.roleCode !== 'SUPER_ADMIN' || !roleDisabled(role)) return '';
  return roleUser.value?.id === auth.currentUser?.id ? '不能移除自己的超级管理员岗位' : '业务管理员不能授予或移除超级管理员岗位';
}

async function saveRoles() {
  if (saving.value || !roleUser.value) return;
  try {
    await ElMessageBox.confirm('确认提交完整岗位集合吗？', '确认角色变更', { type: 'warning', confirmButtonText: '确认', cancelButtonText: '取消' });
  } catch {
    return;
  }
  saving.value = true;
  try {
    await request.put(`/api/auth/users/${roleUser.value.id}/roles`, { ids: selectedRoleIds.value });
    ElMessage.success('角色分配成功');
    initialRoleIds.value = [...selectedRoleIds.value];
    roleVisible.value = false;
    await load();
  } finally {
    saving.value = false;
  }
}

async function deleteUser(row: UserSummary) {
  if (deletingId.value) return;
  try {
    await ElMessageBox.confirm(`确认删除用户“${row.username}”吗？此操作不可撤销。`, '删除用户', { type: 'error', confirmButtonText: '删除', cancelButtonText: '取消' });
  } catch {
    return;
  }
  deletingId.value = row.id;
  try {
    await request.delete(`/api/auth/users/${row.id}`);
    ElMessage.success('用户已删除');
    await load();
  } finally {
    deletingId.value = '';
  }
}

const resetCheckingId = ref('');

async function openResetPassword(row: UserSummary) {
  if (row.id === auth.currentUser?.id) {
    ElMessage.warning('不能在用户列表中重置自身密码，请使用右上角个人中心修改');
    return;
  }
  resetCheckingId.value = row.id;
  try {
    const assigned = await targetRoles(row.id);
    if (assigned.some((r) => r.roleCode === 'SUPER_ADMIN') && !canManageSuperAdmin.value) {
      ElMessage.warning('普通管理员不能重置超级管理员密码');
      return;
    }
  } catch {
    return;
  } finally {
    resetCheckingId.value = '';
  }

  resetUser.value = row;
  resetForm.newPassword = '';
  resetForm.confirmPassword = '';
  resetVisible.value = true;
}

async function submitResetPassword() {
  if (resetSaving.value || !resetUser.value) return;
  if (!resetForm.newPassword || resetForm.newPassword.length < 8 || resetForm.newPassword.length > 72) {
    ElMessage.warning('密码长度必须为 8~72 位');
    return;
  }
  if (resetForm.newPassword !== resetForm.confirmPassword) {
    ElMessage.warning('两次输入的新密码不一致');
    return;
  }
  resetSaving.value = true;
  try {
    await request.put(`/api/auth/users/${resetUser.value.id}/password`, {
      newPassword: resetForm.newPassword
    });
    ElMessage.success(`用户“${resetUser.value.username}”密码已重置，该账号已被强制下线`);
    resetVisible.value = false;
  } finally {
    resetSaving.value = false;
  }
}

function isCreateDirty() {
  return Boolean(
    createForm.username.trim() ||
    createForm.password ||
    createForm.realName.trim() ||
    createForm.phone.trim() ||
    createForm.email.trim() ||
    createForm.avatarUrl.trim() ||
    createForm.status !== 'ENABLED'
  );
}

function isEditDirty() {
  return Object.values(editTouched).some(Boolean);
}

function isRoleDirty() {
  if (selectedRoleIds.value.length !== initialRoleIds.value.length) return true;
  const set = new Set(initialRoleIds.value);
  return selectedRoleIds.value.some((id) => !set.has(id));
}

function isResetDirty() {
  return Boolean(resetForm.newPassword || resetForm.confirmPassword);
}

const isAnyDirty = computed(() =>
  (createVisible.value && isCreateDirty()) ||
  (editVisible.value && isEditDirty()) ||
  (roleVisible.value && isRoleDirty()) ||
  (resetVisible.value && isResetDirty())
);

async function beforeCloseCreate(done?: () => void) {
  if (saving.value) return;
  if (isCreateDirty()) {
    try {
      await ElMessageBox.confirm('当前有未保存的用户信息，确定放弃吗？', '提示', {
        type: 'warning',
        confirmButtonText: '放弃修改',
        cancelButtonText: '继续编辑'
      });
    } catch {
      return;
    }
  }
  if (done) done();
  else createVisible.value = false;
}

async function beforeCloseEdit(done?: () => void) {
  if (saving.value) return;
  if (isEditDirty()) {
    try {
      await ElMessageBox.confirm('当前有未保存的编辑内容，确定放弃吗？', '提示', {
        type: 'warning',
        confirmButtonText: '放弃修改',
        cancelButtonText: '继续编辑'
      });
    } catch {
      return;
    }
  }
  if (done) done();
  else editVisible.value = false;
}

async function beforeCloseRole(done?: () => void) {
  if (saving.value) return;
  if (isRoleDirty()) {
    try {
      await ElMessageBox.confirm('岗位选择尚未保存，确定放弃吗？', '提示', {
        type: 'warning',
        confirmButtonText: '放弃修改',
        cancelButtonText: '继续编辑'
      });
    } catch {
      return;
    }
  }
  if (done) done();
  else roleVisible.value = false;
}

async function beforeCloseReset(done?: () => void) {
  if (resetSaving.value) return;
  if (isResetDirty()) {
    try {
      await ElMessageBox.confirm('当前有未提交的新密码，确定放弃吗？', '提示', {
        type: 'warning',
        confirmButtonText: '放弃修改',
        cancelButtonText: '继续编辑'
      });
    } catch {
      return;
    }
  }
  if (done) done();
  else resetVisible.value = false;
}

function beforeUnload(e: BeforeUnloadEvent) {
  if (isAnyDirty.value) {
    e.preventDefault();
    e.returnValue = '';
  }
}

onBeforeRouteLeave(async () => {
  if (!isAnyDirty.value) return true;
  try {
    await ElMessageBox.confirm('当前有未保存的用户操作，确定离开吗？', '提示', {
      type: 'warning',
      confirmButtonText: '放弃修改',
      cancelButtonText: '继续留在页面'
    });
    return true;
  } catch {
    return false;
  }
});

onMounted(async () => {
  window.addEventListener('beforeunload', beforeUnload);
  try {
    await Promise.all([load(), loadRoles()]);
  } catch {
    // 用户列表自身负责 error/retry；角色筛选失败由公共错误提示说明。
  }
});

onBeforeUnmount(() => {
  window.removeEventListener('beforeunload', beforeUnload);
});
</script>

<template>
  <section class="system-page">
    <div class="page-head">
      <div><h1>用户管理</h1><p>管理账号基础资料、状态和固定岗位分配。</p></div>
      <el-button v-if="auth.can('system:user:create')" type="primary" @click="openCreate">创建用户</el-button>
    </div>

    <el-card class="filter-card" shadow="never">
      <el-form inline @submit.prevent="search">
        <el-form-item label="关键词"><el-input v-model="filters.keyword" clearable placeholder="用户名或姓名" @keyup.enter="search" /></el-form-item>
        <el-form-item label="状态">
          <el-select v-model="filters.status" clearable placeholder="全部状态">
            <el-option label="启用" value="ENABLED" /><el-option label="停用" value="DISABLED" /><el-option label="锁定" value="LOCKED" />
          </el-select>
        </el-form-item>
        <el-form-item label="岗位">
          <el-select v-model="filters.roleCode" clearable placeholder="全部岗位">
            <el-option v-for="role in roles" :key="role.id" :label="displayValue(role.roleCode)" :value="role.roleCode" />
          </el-select>
        </el-form-item>
        <el-form-item><el-button type="primary" @click="search">查询</el-button><el-button @click="Object.assign(filters,{keyword:'',status:'',roleCode:''});search()">重置</el-button></el-form-item>
      </el-form>
    </el-card>

    <el-card shadow="never">
      <el-alert v-if="errorMessage" :title="errorMessage" type="error" show-icon :closable="false">
        <template #default><el-button link type="primary" @click="load">重新加载</el-button></template>
      </el-alert>
      <el-table v-else v-loading="loading" :data="rows" row-key="id">
        <el-table-column prop="username" label="用户名" min-width="150" />
        <el-table-column prop="realName" label="姓名" min-width="140"><template #default="scope">{{ scope.row.realName || '-' }}</template></el-table-column>
        <el-table-column prop="status" label="状态" width="110"><template #default="scope"><el-tag :type="scope.row.status==='ENABLED'?'success':scope.row.status==='LOCKED'?'danger':'info'">{{ displayValue(scope.row.status) }}</el-tag></template></el-table-column>
        <el-table-column label="操作" min-width="440" fixed="right">
          <template #default="scope">
            <el-button v-if="auth.can('system:user:update')" link :loading="editLoading" @click="openEdit(scope.row)">编辑资料</el-button>
            <el-button v-if="auth.can('system:user:role')" link :loading="roleLoading" @click="openRoles(scope.row)">分配角色</el-button>
            <el-button
              v-if="auth.can('system:user:update')"
              link
              :loading="resetCheckingId === scope.row.id"
              :disabled="scope.row.id === auth.currentUser?.id"
              :title="scope.row.id === auth.currentUser?.id ? '不能在此重置自身密码，请使用右上角个人中心修改' : ''"
              @click="openResetPassword(scope.row)"
            >
              重置密码
            </el-button>
            <el-button v-if="auth.can('system:user:update')&&scope.row.status!=='ENABLED'" link :loading="statusSavingId===scope.row.id" @click="updateStatus(scope.row,'ENABLED')">启用</el-button>
            <el-button v-if="auth.can('system:user:update')&&scope.row.status!=='DISABLED'" link :loading="statusSavingId===scope.row.id" @click="updateStatus(scope.row,'DISABLED')">停用</el-button>
            <el-button v-if="auth.can('system:user:update')&&scope.row.status!=='LOCKED'" link :loading="statusSavingId===scope.row.id" @click="updateStatus(scope.row,'LOCKED')">锁定</el-button>
            <el-button v-if="auth.can('system:user:delete')" link type="danger" :loading="deletingId===scope.row.id" @click="deleteUser(scope.row)">删除</el-button>
          </template>
        </el-table-column>
      </el-table>
      <el-empty v-if="!loading&&!errorMessage&&!rows.length" description="暂无符合条件的用户" />
      <el-pagination v-if="!errorMessage&&total>pageSize" v-model:current-page="page" layout="prev, pager, next, total" :page-size="pageSize" :total="total" @current-change="load" />
    </el-card>

    <el-dialog v-model="createVisible" title="创建用户" width="600px" :close-on-click-modal="!saving" :before-close="beforeCloseCreate">
      <el-form label-width="100px">
        <el-form-item label="用户名" required><el-input v-model="createForm.username" autocomplete="off" /></el-form-item>
        <el-form-item label="密码" required><el-input v-model="createForm.password" type="password" show-password autocomplete="new-password" maxlength="72" placeholder="8~72 位" /></el-form-item>
        <el-form-item label="姓名"><el-input v-model="createForm.realName" /></el-form-item>
        <el-form-item label="手机号"><el-input v-model="createForm.phone" /></el-form-item>
        <el-form-item label="邮箱"><el-input v-model="createForm.email" /></el-form-item>
        <el-form-item label="头像地址"><el-input v-model="createForm.avatarUrl" /></el-form-item>
        <el-form-item label="状态"><el-select v-model="createForm.status"><el-option label="启用" value="ENABLED" /><el-option label="停用" value="DISABLED" /><el-option label="锁定" value="LOCKED" /></el-select></el-form-item>
      </el-form>
      <template #footer><el-button :disabled="saving" @click="beforeCloseCreate()">取消</el-button><el-button type="primary" :loading="saving" :disabled="saving" @click="createUser">保存</el-button></template>
    </el-dialog>

    <el-dialog v-model="editVisible" :title="`编辑用户：${editUser?.username||''}`" width="600px" :close-on-click-modal="!saving" :before-close="beforeCloseEdit">
      <el-alert title="后端当前不返回手机号、邮箱和头像；仅实际修改的字段会提交，未修改的空白字段保持原值。" type="info" :closable="false" show-icon />
      <el-form label-width="100px" class="dialog-form">
        <el-form-item label="姓名"><el-input v-model="editForm.realName" @input="markEditTouched('realName')" /></el-form-item>
        <el-form-item label="手机号"><el-input v-model="editForm.phone" placeholder="留空且不修改则保持原值" @input="markEditTouched('phone')" /></el-form-item>
        <el-form-item label="邮箱"><el-input v-model="editForm.email" placeholder="留空且不修改则保持原值" @input="markEditTouched('email')" /></el-form-item>
        <el-form-item label="头像地址"><el-input v-model="editForm.avatarUrl" placeholder="留空且不修改则保持原值" @input="markEditTouched('avatarUrl')" /></el-form-item>
      </el-form>
      <template #footer><el-button :disabled="saving" @click="beforeCloseEdit()">取消</el-button><el-button type="primary" :loading="saving" :disabled="saving" @click="updateUser">保存</el-button></template>
    </el-dialog>

    <el-dialog v-model="roleVisible" title="分配固定岗位" width="520px" :close-on-click-modal="!saving" :before-close="beforeCloseRole">
      <p>用户：{{ roleUser?.username }}</p>
      <el-checkbox-group v-model="selectedRoleIds" class="role-options">
        <el-tooltip v-for="role in roles" :key="role.id" :content="roleHelp(role)" :disabled="!roleHelp(role)" placement="right">
          <el-checkbox :value="role.id" :disabled="roleDisabled(role)">{{ displayValue(role.roleCode) }}（{{ role.roleCode }}）</el-checkbox>
        </el-tooltip>
      </el-checkbox-group>
      <el-alert title="保存时提交当前完整岗位集合；已有岗位已从服务端加载并回显。" type="info" :closable="false" show-icon />
      <template #footer><el-button :disabled="saving" @click="beforeCloseRole()">取消</el-button><el-button type="primary" :loading="saving" :disabled="saving" @click="saveRoles">保存角色</el-button></template>
    </el-dialog>

    <el-dialog v-model="resetVisible" title="重置用户密码" width="440px" :close-on-click-modal="!resetSaving" :before-close="beforeCloseReset">
      <el-alert
        title="重置密码后，目标用户的当前所有在线会话将被立即强制下线。"
        type="warning"
        :closable="false"
        show-icon
        style="margin-bottom: 18px"
      />
      <el-form label-width="90px">
        <el-form-item label="目标用户">
          <span>{{ resetUser?.realName ? `${resetUser.realName}（${resetUser.username}）` : resetUser?.username }}</span>
        </el-form-item>
        <el-form-item label="新密码" required>
          <el-input v-model="resetForm.newPassword" type="password" show-password maxlength="72" placeholder="8~72 位" />
        </el-form-item>
        <el-form-item label="确认密码" required>
          <el-input v-model="resetForm.confirmPassword" type="password" show-password maxlength="72" placeholder="请再次输入新密码" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button :disabled="resetSaving" @click="beforeCloseReset()">取消</el-button>
        <el-button type="primary" :loading="resetSaving" :disabled="resetSaving" @click="submitResetPassword">确认重置</el-button>
      </template>
    </el-dialog>
  </section>
</template>
