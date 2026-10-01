import { createRouter, createWebHashHistory, type RouteRecordRaw } from 'vue-router';
import { useAuthStore } from '../stores/auth';
import Login from '../views/Login.vue';
import Layout from '../layouts/AdminLayout.vue';
import Dashboard from '../views/Dashboard.vue';
import NotificationList from '../views/NotificationList.vue';
import TaskDetail from '../views/TaskDetail.vue';
import TemplateDetail from '../views/TemplateDetail.vue';
import WorkOrderDetail from '../views/WorkOrderDetail.vue';
import AiDetail from '../views/AiDetail.vue';
import Forbidden from '../views/Forbidden.vue';
import NoRole from '../views/NoRole.vue';
import IdentityUnavailable from '../views/IdentityUnavailable.vue';
import NotFound from '../views/NotFound.vue';
import UserManagement from '../views/UserManagement.vue';
import RoleReadOnly from '../views/RoleReadOnly.vue';
import PermissionReadOnly from '../views/PermissionReadOnly.vue';
import DeviceList from '../views/DeviceList.vue';
import DeviceDetail from '../views/DeviceDetail.vue';
import DeviceScene from '../views/DeviceScene.vue';
import TemplateList from '../views/TemplateList.vue';
import PlanList from '../views/PlanList.vue';
import TaskList from '../views/TaskList.vue';
import AbnormalList from '../views/AbnormalList.vue';
import AbnormalDetail from '../views/AbnormalDetail.vue';
import DefectList from '../views/DefectList.vue';
import DefectDetail from '../views/DefectDetail.vue';
import WorkOrderList from '../views/WorkOrderList.vue';
import AiList from '../views/AiList.vue';
import '../utils/navigation';

const children: RouteRecordRaw[] = [
  // 1. 工作台
  {
    path: '/dashboard',
    component: Dashboard,
    meta: {
      title: '工作台',
      permission: 'dashboard:view',
      roles: ['SUPER_ADMIN', 'ADMIN', 'INSPECTOR', 'MAINTAINER'],
      breadcrumb: [{ title: '工作台' }],
      menu: { label: '工作台', order: 10, icon: 'Odometer' }
    }
  },
  // 2. 设备管理
  {
    path: '/devices',
    component: DeviceList,
    meta: {
      title: '设备管理',
      permission: 'device:view',
      roles: ['SUPER_ADMIN', 'ADMIN', 'INSPECTOR', 'MAINTAINER'],
      breadcrumb: [{ title: '设备管理' }],
      menu: { label: '设备管理', order: 20, icon: 'Cpu' }
    }
  },
  {
    path: '/devices/scene',
    component: DeviceScene,
    meta: {
      title: '设备空间视图',
      permission: 'device:view',
      roles: ['SUPER_ADMIN', 'ADMIN', 'INSPECTOR', 'MAINTAINER'],
      activeMenu: '/devices',
      breadcrumb: [{ title: '设备管理', path: '/devices' }, { title: '设备空间视图' }]
    }
  },
  {
    path: '/devices/:id',
    component: DeviceDetail,
    meta: {
      title: '设备详情',
      permission: 'device:view',
      roles: ['SUPER_ADMIN', 'ADMIN', 'INSPECTOR', 'MAINTAINER'],
      activeMenu: '/devices',
      breadcrumb: [{ title: '设备管理', path: '/devices' }, { title: '设备详情' }]
    }
  },
  // 3. 巡检管理
  {
    path: '/inspection/templates',
    component: TemplateList,
    meta: {
      title: '巡检模板',
      permission: 'inspection:view',
      roles: ['SUPER_ADMIN', 'ADMIN'],
      breadcrumb: [{ title: '巡检管理' }, { title: '巡检模板' }],
      menu: { label: '巡检模板', group: 'inspection', order: 31 }
    }
  },
  {
    path: '/inspection/templates/:id',
    component: TemplateDetail,
    meta: {
      title: '模板详情',
      permission: 'inspection:view',
      roles: ['SUPER_ADMIN', 'ADMIN'],
      activeMenu: '/inspection/templates',
      breadcrumb: [{ title: '巡检管理' }, { title: '巡检模板', path: '/inspection/templates' }, { title: '模板详情' }]
    }
  },
  {
    path: '/inspection/plans',
    component: PlanList,
    meta: {
      title: '巡检计划',
      permission: 'inspection:view',
      roles: ['SUPER_ADMIN', 'ADMIN'],
      breadcrumb: [{ title: '巡检管理' }, { title: '巡检计划' }],
      menu: { label: '巡检计划', group: 'inspection', order: 32 }
    }
  },
  {
    path: '/inspection/tasks',
    component: TaskList,
    meta: {
      title: '巡检任务',
      permission: 'inspection:view',
      roles: ['SUPER_ADMIN', 'ADMIN', 'INSPECTOR'],
      breadcrumb: [{ title: '巡检管理' }, { title: '巡检任务' }],
      menu: { label: '巡检任务', group: 'inspection', order: 33 }
    }
  },
  {
    path: '/inspection/tasks/:id',
    component: TaskDetail,
    meta: {
      title: '任务详情',
      permission: 'inspection:view',
      roles: ['SUPER_ADMIN', 'ADMIN', 'INSPECTOR'],
      activeMenu: '/inspection/tasks',
      breadcrumb: [{ title: '巡检管理' }, { title: '巡检任务', path: '/inspection/tasks' }, { title: '任务详情' }]
    }
  },
  {
    path: '/inspection/abnormals',
    component: AbnormalList,
    meta: {
      title: '巡检异常',
      permission: 'inspection:view',
      roles: ['SUPER_ADMIN', 'ADMIN', 'INSPECTOR'],
      breadcrumb: [{ title: '巡检管理' }, { title: '巡检异常' }],
      menu: { label: '巡检异常', group: 'inspection', order: 34 }
    }
  },
  {
    path: '/inspection/abnormals/:id',
    component: AbnormalDetail,
    meta: {
      title: '异常详情',
      permission: 'inspection:view',
      roles: ['SUPER_ADMIN', 'ADMIN', 'INSPECTOR'],
      activeMenu: '/inspection/abnormals',
      breadcrumb: [{ title: '巡检管理' }, { title: '巡检异常', path: '/inspection/abnormals' }, { title: '异常详情' }]
    }
  },
  // 4. 维修管理
  {
    path: '/maintenance/defects',
    component: DefectList,
    meta: {
      title: '缺陷管理',
      permission: 'maintenance:view',
      roles: ['SUPER_ADMIN', 'ADMIN', 'MAINTAINER'],
      breadcrumb: [{ title: '维修管理' }, { title: '缺陷管理' }],
      menu: { label: '缺陷管理', group: 'maintenance', order: 41 }
    }
  },
  {
    path: '/maintenance/defects/:id',
    component: DefectDetail,
    meta: {
      title: '缺陷详情',
      permission: 'maintenance:view',
      roles: ['SUPER_ADMIN', 'ADMIN', 'MAINTAINER'],
      activeMenu: '/maintenance/defects',
      breadcrumb: [{ title: '维修管理' }, { title: '缺陷管理', path: '/maintenance/defects' }, { title: '缺陷详情' }]
    }
  },
  {
    path: '/maintenance/work-orders',
    component: WorkOrderList,
    meta: {
      title: '维修工单',
      permission: 'maintenance:view',
      roles: ['SUPER_ADMIN', 'ADMIN', 'MAINTAINER'],
      breadcrumb: [{ title: '维修管理' }, { title: '维修工单' }],
      menu: { label: '维修工单', group: 'maintenance', order: 42 }
    }
  },
  {
    path: '/maintenance/work-orders/:id',
    component: WorkOrderDetail,
    meta: {
      title: '工单详情',
      permission: 'maintenance:view',
      roles: ['SUPER_ADMIN', 'ADMIN', 'MAINTAINER'],
      activeMenu: '/maintenance/work-orders',
      breadcrumb: [{ title: '维修管理' }, { title: '维修工单', path: '/maintenance/work-orders' }, { title: '工单详情' }]
    }
  },
  // 5. AI 诊断
  {
    path: '/ai/diagnoses',
    component: AiList,
    meta: {
      title: 'AI 诊断',
      permission: 'ai:view',
      roles: ['SUPER_ADMIN', 'ADMIN', 'INSPECTOR', 'MAINTAINER'],
      breadcrumb: [{ title: 'AI 诊断' }],
      menu: { label: 'AI 诊断', order: 50, icon: 'DataAnalysis' }
    }
  },
  {
    path: '/ai/diagnoses/:id',
    component: AiDetail,
    meta: {
      title: '诊断详情',
      permission: 'ai:view',
      roles: ['SUPER_ADMIN', 'ADMIN', 'INSPECTOR', 'MAINTAINER'],
      activeMenu: '/ai/diagnoses',
      breadcrumb: [{ title: 'AI 诊断', path: '/ai/diagnoses' }, { title: '诊断详情' }]
    }
  },
  // 6. 系统管理
  {
    path: '/system/users',
    component: UserManagement,
    meta: {
      title: '用户管理',
      permission: 'system:user:view',
      roles: ['SUPER_ADMIN', 'ADMIN'],
      breadcrumb: [{ title: '系统管理' }, { title: '用户管理' }],
      menu: { label: '用户管理', group: 'system', order: 61 }
    }
  },
  {
    path: '/system/roles',
    component: RoleReadOnly,
    meta: {
      title: '角色查看',
      permission: 'system:role:view',
      roles: ['SUPER_ADMIN', 'ADMIN'],
      breadcrumb: [{ title: '系统管理' }, { title: '角色查看' }],
      menu: { label: '角色查看', group: 'system', order: 62 }
    }
  },
  {
    path: '/system/permissions',
    component: PermissionReadOnly,
    meta: {
      title: '权限查看',
      permission: 'system:permission:view',
      roles: ['SUPER_ADMIN', 'ADMIN'],
      breadcrumb: [{ title: '系统管理' }, { title: '权限查看' }],
      menu: { label: '权限查看', group: 'system', order: 63 }
    }
  },
  // 7. 通知中心
  {
    path: '/notifications',
    component: NotificationList,
    meta: {
      title: '通知中心',
      permission: null,
      roles: ['SUPER_ADMIN', 'ADMIN', 'INSPECTOR', 'MAINTAINER'],
      breadcrumb: [{ title: '通知中心' }],
      menu: { label: '通知中心', order: 70, icon: 'Bell' }
    }
  },
  // 8. 404
  {
    path: '/404',
    component: NotFound,
    meta: {
      title: '页面不存在',
      breadcrumb: [{ title: '页面不存在' }]
    }
  },
  {
    path: '/:pathMatch(.*)*',
    component: NotFound,
    meta: {
      title: '页面不存在',
      breadcrumb: [{ title: '页面不存在' }]
    }
  }
];

const router = createRouter({
  history: createWebHashHistory(),
  routes: [
    { path: '/login', component: Login },
    { path: '/identity-unavailable', component: IdentityUnavailable, meta: { title: '无法验证登录状态' } },
    { path: '/no-role', component: NoRole, meta: { title: '尚未分配岗位' } },
    { path: '/403', component: Forbidden, meta: { title: '无权访问' } },
    { path: '/', component: Layout, children }
  ]
});

router.beforeEach(async (to) => {
  const auth = useAuthStore();
  if (to.path !== '/login' && !auth.token) return '/login';
  if (to.path === '/identity-unavailable') {
    if (!auth.token) return '/login';
    if (!auth.identityLoaded) return true;
    const redirect = typeof to.query.redirect === 'string' && to.query.redirect.startsWith('/')
      ? to.query.redirect
      : auth.defaultHome();
    return redirect === '/identity-unavailable' ? auth.defaultHome() : redirect;
  }
  if (auth.token && !auth.identityLoaded) {
    try {
      await auth.ensureIdentity();
    } catch (err: any) {
      const status = err?.response?.status;
      if (status === 401) {
        // Only a confirmed 401 proves that the persisted credential is invalid.
        auth.logoutLocal();
        return '/login';
      }
      // Keep the credential, but do not render a protected route until /me succeeds.
      return {
        path: '/identity-unavailable',
        query: {
          redirect: to.fullPath,
          reason: err?.response ? 'service' : 'network'
        }
      };
    }
  }
  if (to.path === '/login' && auth.token) return auth.defaultHome();
  if (auth.token && auth.identityLoaded && auth.roles.length === 0) {
    return to.path === '/no-role' ? true : '/no-role';
  }
  if (to.path === '/no-role') return auth.defaultHome();
  if (to.path === '/403') return true;
  if (to.path === '/404' || to.matched.some((r) => r.path === '/:pathMatch(.*)*')) return true;

  const permission = to.meta.permission as string | undefined | null;
  if (permission && !auth.can(permission)) return '/403';
  const roles = to.meta.roles as string[] | undefined;
  if (roles && !roles.some((role) => auth.roles.includes(role))) return '/403';
  return true;
});

export default router;
