import type { RouteRecordNormalized } from 'vue-router';

export type MenuGroupKey = 'inspection' | 'maintenance' | 'system';

export interface BreadcrumbItem {
  title: string;
  path?: string;
}

export interface MenuItemMeta {
  label: string;
  group?: MenuGroupKey;
  order: number;
  icon?: string;
}

declare module 'vue-router' {
  interface RouteMeta {
    title?: string;
    permission?: string | null;
    roles?: string[];
    activeMenu?: string;
    breadcrumb?: BreadcrumbItem[];
    menu?: MenuItemMeta;
  }
}

export interface NavSingleItem {
  isGroup: false;
  path: string;
  label: string;
  order: number;
  icon?: string;
}

export interface NavSubMenuItem {
  isGroup: true;
  key: string;
  groupKey: MenuGroupKey;
  label: string;
  order: number;
  icon: string;
  children: Array<{
    path: string;
    label: string;
    order: number;
  }>;
}

export type NavItem = NavSingleItem | NavSubMenuItem;

export const MENU_GROUPS: Record<MenuGroupKey, { label: string; icon: string; order: number }> = {
  inspection: { label: '巡检管理', icon: 'DocumentChecked', order: 30 },
  maintenance: { label: '维修管理', icon: 'Tools', order: 40 },
  system: { label: '系统管理', icon: 'Management', order: 60 }
};

export function buildNavigation(
  routes: RouteRecordNormalized[],
  auth: { roles: string[]; can: (perm: string) => boolean }
): NavItem[] {
  const singleItems: NavSingleItem[] = [];
  const groupChildrenMap: Record<MenuGroupKey, Array<{ path: string; label: string; order: number }>> = {
    inspection: [],
    maintenance: [],
    system: []
  };

  for (const route of routes) {
    const meta = route.meta;
    if (!meta?.menu) continue;

    // Filter by role
    if (meta.roles && !meta.roles.some((role) => auth.roles.includes(role))) {
      continue;
    }
    // Filter by permission
    if (meta.permission && !auth.can(meta.permission)) {
      continue;
    }

    const { label, group, order, icon } = meta.menu;
    if (group && group in groupChildrenMap) {
      groupChildrenMap[group].push({ path: route.path, label, order });
    } else {
      singleItems.push({
        isGroup: false,
        path: route.path,
        label,
        order,
        icon
      });
    }
  }

  const result: NavItem[] = [...singleItems];

  for (const groupKey of Object.keys(MENU_GROUPS) as MenuGroupKey[]) {
    const groupDef = MENU_GROUPS[groupKey];
    const children = groupChildrenMap[groupKey];
    if (children.length > 0) {
      children.sort((a, b) => a.order - b.order);
      result.push({
        isGroup: true,
        key: `group-${groupKey}`,
        groupKey,
        label: groupDef.label,
        order: groupDef.order,
        icon: groupDef.icon,
        children
      });
    }
  }

  result.sort((a, b) => a.order - b.order);
  return result;
}

export function getActiveGroupKey(path: string, activeMenu?: string): string | null {
  const target = activeMenu || path;
  if (target.startsWith('/inspection')) return 'group-inspection';
  if (target.startsWith('/maintenance')) return 'group-maintenance';
  if (target.startsWith('/system')) return 'group-system';
  return null;
}
