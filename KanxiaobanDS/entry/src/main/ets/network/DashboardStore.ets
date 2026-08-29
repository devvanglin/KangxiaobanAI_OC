import DashboardApi from './DashboardApi';
import {
  CockpitSnapshot,
  CockpitSummary,
  LoginResponse,
  LoginUser,
  RoleInfo
} from '../model/DashboardModels';

function emptySummary(): CockpitSummary {
  return {
    residents: 0,
    occupied_beds: 0,
    total_beds: 0,
    free_beds: 0,
    staff_on_duty: 0,
    open_tasks: 0,
    open_alerts: 0,
    emergency_alerts: 0,
    devices_online: 0,
    devices_total: 0
  };
}

function emptySnapshot(): CockpitSnapshot {
  return {
    updated_at: '',
    policy: {
      occupancy_warning_percent: 0,
      device_online_warning_percent: 0,
      alert_cooldown_seconds: 0,
      device_offline_seconds: 0,
      alert_escalation_seconds: 0
    },
    summary: emptySummary(),
    wards: [],
    rooms: [],
    events: [],
    facilities: [],
    work_items: [],
    risks: []
  };
}

@ObservedV2
export class DashboardStore {
  private static shared: DashboardStore = new DashboardStore();
  private token: string = '';

  @Trace authenticated: boolean = false;
  @Trace loading: boolean = false;
  @Trace error: string = '';
  @Trace user: LoginUser | null = null;
  @Trace snapshot: CockpitSnapshot = emptySnapshot();

  public static getShared(): DashboardStore {
    return DashboardStore.shared;
  }

  public async login(username: string, password: string, tenantCode: string): Promise<boolean> {
    this.loading = true;
    this.error = '';
    try {
      const response = await DashboardApi.login(username.trim(), password, tenantCode);
      if (response.code !== 0 || !response.data || response.data.token.length === 0) {
        this.error = response.msg.length > 0 ? response.msg : '账号或密码错误';
        return false;
      }
      const login: LoginResponse = response.data;
      if (!this.canReadDashboard(login.user.roles)) {
        this.error = '该账号没有驾驶舱查看权限';
        return false;
      }
      this.token = login.token;
      this.user = login.user;
      this.authenticated = true;
      return await this.load();
    } catch (_error) {
      this.error = '无法连接服务器，请检查网络后重试';
      return false;
    } finally {
      this.loading = false;
    }
  }

  public async load(): Promise<boolean> {
    if (this.token.length === 0) {
      this.logout();
      return false;
    }
    this.loading = true;
    this.error = '';
    try {
      const response = await DashboardApi.cockpit(this.token);
      if (response.code === 401 || response.code === 403) {
        this.logout();
        this.error = response.code === 403 ? '该账号没有驾驶舱查看权限' : '登录已失效，请重新登录';
        return false;
      }
      if (response.code !== 0 || !response.data) {
        this.error = response.msg.length > 0 ? response.msg : '驾驶舱数据加载失败';
        return false;
      }
      this.snapshot = response.data;
      return true;
    } catch (_error) {
      this.error = '服务器暂时不可用，请稍后重试';
      return false;
    } finally {
      this.loading = false;
    }
  }

  public logout(): void {
    this.token = '';
    this.user = null;
    this.authenticated = false;
    this.snapshot = emptySnapshot();
  }

  public displayName(): string {
    return this.user?.real_name || this.user?.username || '当前用户';
  }

  private canReadDashboard(roles: RoleInfo[]): boolean {
    for (let index: number = 0; index < roles.length; index++) {
      if (roles[index].code === 'admin' || roles[index].code === 'doctor' || roles[index].code === 'caregiver') {
        return true;
      }
    }
    return false;
  }
}

export default DashboardStore;
