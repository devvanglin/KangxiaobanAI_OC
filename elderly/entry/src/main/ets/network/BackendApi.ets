import { http } from '@kit.NetworkKit';

/**
 * 机构后端访问配置：老人端以一个受配置的机构账号自动登录，
 * 只读拉取长者档案与护理安排。生产部署应换成专用的陪护终端账号。
 */
export class BackendConfig {
  static readonly BASE_URL: string = 'http://10.10.1.12';
  static readonly USERNAME: string = 'admin';
  static readonly PASSWORD: string = '123456';
}

export interface ElderContactInfo {
  name?: string;
  relation?: string;
  phone?: string;
  is_emergency?: boolean;
}

export interface ElderBedInfo {
  id?: number;
  bed_no?: string;
  status?: string;
  room_id?: number;
}

export interface ElderInfo {
  id: number;
  name: string;
  gender?: string;
  birth_date?: string;
  care_level?: number;
  status?: number;
  remark?: string;
  bed?: ElderBedInfo | null;
  allergies?: string[] | null;
  emergency_contacts?: ElderContactInfo[] | null;
}

export interface CareTaskInfo {
  id: number;
  title: string;
  kind?: string;
  priority?: string;
  due_at?: string | null;
  status?: string;
  assignee?: string;
  remark?: string;
}

export interface CarePlanItemInfo {
  id?: number;
  title: string;
  kind?: string;
  frequency?: string;
  due_at?: string | null;
  instructions?: string;
  active?: boolean;
}

export interface CarePlanInfo {
  id: number;
  name: string;
  status?: string;
  start_date?: string;
  items?: CarePlanItemInfo[] | null;
}

/** 摄像头悲伤表情触发的主动安抚会话（老人端领取后走语音安抚流程）。 */
export interface ComfortSessionInfo {
  id: number;
  elder_id: number;
  device_id?: string;
  status?: string;
  trigger?: string;
  expression?: string;
}

/** 后端统一响应外壳：{code, msg, data}。 */
interface ApiEnvelope {
  code: number;
  msg?: string;
  data?: object;
}

interface ElderListData {
  list?: ElderInfo[];
}

interface TaskListData {
  list?: CareTaskInfo[];
}

interface PlanListData {
  list?: CarePlanInfo[];
}

interface LoginData {
  token?: string;
}

class BackendApiImpl {
  private token: string = '';

  private async requestJson(method: string, path: string, extraData?: string): Promise<ApiEnvelope> {
    if (this.token.length === 0) {
      await this.login();
    }
    const first: ApiEnvelope = await this.rawJson(method, path, extraData, true);
    if (first.code === 401) {
      // 会话过期：重登一次再试
      this.token = '';
      await this.login();
      return this.rawJson(method, path, extraData, true);
    }
    return first;
  }

  private async rawJson(method: string, path: string, extraData?: string, withAuth: boolean = true): Promise<ApiEnvelope> {
    const client = http.createHttp();
    try {
      const header: Record<string, string> = { 'Content-Type': 'application/json' };
      if (withAuth && this.token.length > 0) {
        header['Authorization'] = `Bearer ${this.token}`;
      }
      const resp = await client.request(`${BackendConfig.BASE_URL}${path}`, {
        method: method as http.RequestMethod,
        header: header,
        extraData: extraData,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 8000,
        readTimeout: 15000
      });
      if (resp.responseCode === 401) {
        const unauthorized: ApiEnvelope = { code: 401, msg: 'unauthorized' };
        return unauthorized;
      }
      if (resp.responseCode !== 200) {
        throw new Error(`HTTP ${resp.responseCode}`);
      }
      return JSON.parse(resp.result as string) as ApiEnvelope;
    } finally {
      client.destroy();
    }
  }

  public async login(): Promise<void> {
    const body = JSON.stringify({
      username: BackendConfig.USERNAME,
      password: BackendConfig.PASSWORD
    });
    const env = await this.rawJson('POST', '/api/v1/auth/login', body, false);
    const loginData = env.data as LoginData;
    if (env.code !== 0 || !loginData || !loginData.token) {
      throw new Error('后端登录失败');
    }
    this.token = loginData.token;
  }

  /** 全部长者档案（列表接口已带床位信息）。 */
  public async fetchElders(): Promise<ElderInfo[]> {
    const env = await this.requestJson('GET', '/api/v1/elders?page=1&size=200');
    if (env.code !== 0) {
      throw new Error('查询长者失败');
    }
    const data = env.data as ElderListData;
    return data.list ?? [];
  }

  public async fetchElder(id: number): Promise<ElderInfo> {
    const env = await this.requestJson('GET', `/api/v1/elders/${id}`);
    if (env.code !== 0) {
      throw new Error('长者不存在');
    }
    return env.data as ElderInfo;
  }

  public async fetchTasks(elderId: number): Promise<CareTaskInfo[]> {
    const env = await this.requestJson('GET', `/api/v1/tasks?elder_id=${elderId}&page=1&size=50`);
    if (env.code !== 0) {
      throw new Error('查询护理任务失败');
    }
    const data = env.data as TaskListData;
    return data.list ?? [];
  }

  public async fetchCarePlans(elderId: number): Promise<CarePlanInfo[]> {
    const env = await this.requestJson('GET', `/api/v1/care-plans?elder_id=${elderId}&page=1&size=20`);
    if (env.code !== 0) {
      throw new Error('查询护理计划失败');
    }
    const data = env.data as PlanListData;
    return data.list ?? [];
  }

  /** 查询该长者最早一个待领取的安抚会话；没有则返回 null。 */
  public async fetchPendingComfort(elderId: number): Promise<ComfortSessionInfo | null> {
    const env = await this.requestJson('GET', `/api/v1/comfort/pending?elder_id=${elderId}`);
    if (env.code !== 0 || !env.data) {
      return null;
    }
    return env.data as ComfortSessionInfo;
  }

  /** 领取安抚会话：设备开始播放开场白。 */
  public async comfortStart(sessionId: number): Promise<void> {
    const env = await this.requestJson('POST', `/api/v1/comfort/sessions/${sessionId}/start`, '{}');
    if (env.code !== 0) {
      throw new Error(`领取安抚会话失败: ${env.msg ?? env.code}`);
    }
  }

  /** 老人有语音回应，上报第一句 ASR 文本。 */
  public async comfortRespond(sessionId: number, transcript: string): Promise<void> {
    const env = await this.requestJson('POST', `/api/v1/comfort/sessions/${sessionId}/respond`,
      JSON.stringify({ transcript: transcript }));
    if (env.code !== 0) {
      throw new Error(`上报回应失败: ${env.msg ?? env.code}`);
    }
  }

  /** 老人无回应：后端通知护工前往查看。 */
  public async comfortNoResponse(sessionId: number): Promise<void> {
    const env = await this.requestJson('POST', `/api/v1/comfort/sessions/${sessionId}/no-response`, '{}');
    if (env.code !== 0) {
      throw new Error(`上报无回应失败: ${env.msg ?? env.code}`);
    }
  }
}

export const BackendApi: BackendApiImpl = new BackendApiImpl();
