import { createRouter, createWebHashHistory, type RouteRecordRaw } from 'vue-router';
import { useAuthStore } from '../stores/auth';
import Login from '../views/Login.vue';
import Layout from '../layouts/AdminLayout.vue';
import Dashboard from '../views/Dashboard.vue';
import Resource from '../views/Resource.vue';
import Detail from '../views/Detail.vue';
import TaskDetail from '../views/TaskDetail.vue';
import TemplateDetail from '../views/TemplateDetail.vue';
import WorkOrderDetail from '../views/WorkOrderDetail.vue';
import AiDetail from '../views/AiDetail.vue';
import Forbidden from '../views/Forbidden.vue';
import NoRole from '../views/NoRole.vue';
import UserManagement from '../views/UserManagement.vue';
import RoleReadOnly from '../views/RoleReadOnly.vue';
import PermissionReadOnly from '../views/PermissionReadOnly.vue';

type ResourceRoute = [path: string, title: string, api: string, permission: string | null];

const resources: ResourceRoute[] = [
  ['devices', '设备', '/api/device/devices', 'device:view'],
  ['inspection/templates', '巡检模板', '/api/inspection/templates', 'inspection:view'],
  ['inspection/plans', '巡检计划', '/api/inspection/plans', 'inspection:view'],
  ['inspection/tasks', '巡检任务', '/api/inspection/tasks', 'inspection:view'],
  ['inspection/abnormals', '巡检异常', '/api/inspection/abnormals', 'inspection:view'],
  ['maintenance/defects', '维修缺陷', '/api/maintenance/defects', 'maintenance:view'],
  ['maintenance/work-orders', '维修工单', '/api/maintenance/work-orders', 'maintenance:view'],
  ['ai/diagnoses', 'AI诊断', '/api/ai/diagnoses', 'ai:view'],
  ['notifications', '通知中心', '/api/auth/notifications', null]
];

const children: RouteRecordRaw[] = [
  { path: '/dashboard', component: Dashboard, meta: { title: '工作台', permission: 'dashboard:view' } },
  { path: '/system/users', component: UserManagement, meta: { title: '用户管理', permission: 'system:user:view' } },
  { path: '/system/roles', component: RoleReadOnly, meta: { title: '角色查看', permission: 'system:role:view' } },
  { path: '/system/permissions', component: PermissionReadOnly, meta: { title: '权限查看', permission: 'system:permission:view' } }
];

resources.forEach(([path, title, api, permission]) => {
  children.push({ path: `/${path}`, component: Resource, props: { title, api, kind: path }, meta: { title, permission } });
  if (path === 'inspection/tasks') children.push({ path: `/${path}/:id`, component: TaskDetail, meta: { title, permission } });
  else if (path === 'inspection/templates') children.push({ path: `/${path}/:id`, component: TemplateDetail, meta: { title, permission } });
  else if (path === 'maintenance/work-orders') children.push({ path: `/${path}/:id`, component: WorkOrderDetail, meta: { title, permission } });
  else if (path === 'ai/diagnoses') children.push({ path: `/${path}/:id`, component: AiDetail, meta: { title, permission } });
  else if (!['notifications', 'inspection/plans'].includes(path)) children.push({ path: `/${path}/:id`, component: Detail, props: { title, api, kind: path }, meta: { title, permission } });
});

const router = createRouter({
  history: createWebHashHistory(),
  routes: [
    { path: '/login', component: Login },
    { path: '/no-role', component: NoRole, meta: { title: '尚未分配岗位' } },
    { path: '/403', component: Forbidden, meta: { title: '无权访问' } },
    { path: '/', component: Layout, children },
    { path: '/:pathMatch(.*)*', redirect: '/dashboard' }
  ]
});

router.beforeEach(async (to) => {
  const auth = useAuthStore();
  if (to.path !== '/login' && !auth.token) return '/login';
  if (auth.token) {
    try {
      await auth.ensureIdentity();
    } catch {
      auth.logoutLocal();
      return '/login';
    }
  }
  if (to.path === '/login' && auth.token) return auth.defaultHome();
  if (auth.token && auth.identityLoaded && auth.roles.length === 0) {
    return to.path === '/no-role' ? true : '/no-role';
  }
  if (to.path === '/no-role') return auth.defaultHome();
  if (to.path === '/403') return true;
  const permission = to.meta.permission as string | undefined;
  if (permission && !auth.can(permission)) return '/403';
  return true;
});

export default router;
