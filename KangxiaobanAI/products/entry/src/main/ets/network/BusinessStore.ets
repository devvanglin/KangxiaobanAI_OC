import ApiClient from './ApiClient';
import {
  ApiResp,
  Alert,
  Assessment,
  Bed,
  Bill,
  CareTask,
  CareExecution,
  Elder,
  DiningOrder,
  HealthRecord,
  IotDevice,
  MedicationRecord,
  MessageContact,
  NotificationRecord,
  OperationPolicy,
  Paged,
  Room,
  Schedule,
  UserMessage
} from './Dto';
import { MessageApi } from './MessageApi';
import AuthStore from './AuthStore';
import Logger from '../util/Logger';

function emptyOperationPolicy(): OperationPolicy {
  return {
    occupancy_warning_percent: 0,
    device_online_warning_percent: 0,
    alert_cooldown_seconds: 0,
    device_offline_seconds: 0,
    alert_escalation_seconds: 0,
    medication_time_periods: []
  };
}

interface LoadResult<T> {
  value: T[];
  ok: boolean;
}

/** 登录用户可见的业务数据。所有页面共享同一组服务器 ID。 */
@ObservedV2
export class BusinessStore {
  private static readonly MAX_AUTO_RETRY_ATTEMPTS: number = 5;
  private static readonly HEALTH_BATCH_SIZE: number = 4;
  private static shared: BusinessStore = new BusinessStore();
  private pendingForceReload: boolean = false;
  private retryTimerId: number = -1;
  private retryAttempt: number = 0;
  private refreshTimerId: number = -1;
  private loadGeneration: number = 0;
  private requestInFlight: boolean = false;
  /** 当前核心快照的完成信号；重复调用 load 时共享它而不是立即返回。 */
  private coreLoadPromise: Promise<void> | null = null;
  private coreLoadFailed: boolean = false;

  @Trace elders: Elder[] = [];
  @Trace rooms: Room[] = [];
  @Trace beds: Bed[] = [];
  @Trace tasks: CareTask[] = [];
  @Trace careExecutions: CareExecution[] = [];
  @Trace devices: IotDevice[] = [];
  @Trace alerts: Alert[] = [];
  @Trace medications: MedicationRecord[] = [];
  @Trace notifications: NotificationRecord[] = [];
  @Trace bills: Bill[] = [];
  @Trace schedules: Schedule[] = [];
  @Trace healthRecords: HealthRecord[] = [];
  @Trace messageContacts: MessageContact[] = [];
  @Trace messages: UserMessage[] = [];
  @Trace diningOrders: DiningOrder[] = [];
  @Trace assessments: Assessment[] = [];
  @Trace operationPolicy: OperationPolicy = emptyOperationPolicy();
  @Trace loading: boolean = false;
  /** 长者接口已经返回后，即可结束长者区域的首屏加载态。 */
  @Trace eldersLoaded: boolean = false;
  /** 首屏核心数据已完成；消息、健康等次要数据可能仍在后台补齐。 */
  @Trace loaded: boolean = false;
  /** 每次核心快照提交后递增，供已挂载的页面建立明确重绘边界。 */
  @Trace coreVersion: number = 0;
  @Trace refreshing: boolean = false;
  @Trace error: string = '';

  private async fetchAll<T>(path: string): Promise<LoadResult<T>> {
    try {
      const response = await ApiClient.getAll<T>(path);
      if (response.code !== 0 || response.data === undefined || response.data === null) {
        return { value: [], ok: false };
      }
      return { value: response.data.list ?? [], ok: true };
    } catch (_error) {
      return { value: [], ok: false };
    }
  }

  private isCurrent(generation: number): boolean {
    return generation === this.loadGeneration;
  }

  private async fetchOne<T>(path: string): Promise<LoadResult<T>> {
    try {
      const response = await ApiClient.get<T>(path);
      if (response.code !== 0 || response.data === undefined || response.data === null) {
        return { value: [], ok: false };
      }
      return { value: [response.data], ok: true };
    } catch (_error) {
      return { value: [], ok: false };
    }
  }

  private scheduleRetry(): void {
    if (this.retryTimerId !== -1 || AuthStore.getToken().length === 0 ||
      this.retryAttempt >= BusinessStore.MAX_AUTO_RETRY_ATTEMPTS) return;
    const delayMs: number = Math.min(30000, 5000 * Math.max(1, this.retryAttempt + 1));
    this.retryAttempt += 1;
    this.retryTimerId = setTimeout((): void => {
      this.retryTimerId = -1;
      if (AuthStore.getToken().length > 0) {
        this.load(true);
      }
    }, delayMs);
  }

  private cancelRetry(): void {
    if (this.retryTimerId !== -1) {
      clearTimeout(this.retryTimerId);
      this.retryTimerId = -1;
    }
    this.retryAttempt = 0;
  }

  private scheduleRefresh(delayMs: number = 800): void {
    if (this.refreshTimerId !== -1 || AuthStore.getToken().length === 0) {
      return;
    }
    this.refreshTimerId = setTimeout((): void => {
      this.refreshTimerId = -1;
      if (AuthStore.getToken().length > 0) {
        this.load(true);
      }
    }, delayMs);
  }

  public static getShared(): BusinessStore {
    return BusinessStore.shared;
  }

  /** 请求一次合并后的后台刷新，供 WebSocket 事件使用。 */
  public requestRefresh(): void {
    // Realtime events are hints. The current request already includes a
    // consistent snapshot. Keep at most one follow-up refresh when a burst
    // arrives while the current snapshot is in flight.
    if (this.requestInFlight) {
      this.pendingForceReload = true;
      return;
    }
    this.scheduleRefresh();
  }

  public load(force: boolean = false): Promise<void> {
    if (this.requestInFlight) {
      if (force) {
        this.pendingForceReload = true;
      }
      return this.coreLoadPromise ?? Promise.resolve();
    }
    if (this.loaded && !force) {
      return Promise.resolve();
    }
    if (force) {
      this.cancelRetry();
      if (this.refreshTimerId !== -1) {
        clearTimeout(this.refreshTimerId);
        this.refreshTimerId = -1;
      }
    }
    const generation: number = ++this.loadGeneration;
    const hadCoreData: boolean = this.loaded;
    this.requestInFlight = true;
    this.coreLoadFailed = false;
    // A refresh keeps the already rendered workbench visible. Only the first
    // load owns the blocking spinner; refreshes are reported independently.
    this.loading = !hadCoreData;
    this.refreshing = hadCoreData;
    if (!hadCoreData) {
      this.eldersLoaded = false;
    }
    this.error = '';
    const failed: string[] = [];

    const corePromise: Promise<void> = this.loadCore(generation, failed);
    this.coreLoadPromise = corePromise;
    // loadCore handles transport failures itself. Keep the shared promise
    // reference only while this core stage is active.
    void corePromise.then((): void => {
      if (this.coreLoadPromise === corePromise) {
        this.coreLoadPromise = null;
      }
    }, (): void => {
      if (this.coreLoadPromise === corePromise) {
        this.coreLoadPromise = null;
      }
    });
    return corePromise;
  }

  private async loadCore(generation: number, failed: string[]): Promise<void> {

    // Core resources start together. Each request has its own watchdog in
    // ApiClient, so a stalled device cannot hold this stage indefinitely.
    const elderPromise: Promise<LoadResult<Elder>> = this.fetchAll<Elder>('/elders');
    const roomPromise: Promise<LoadResult<Room>> = this.fetchAll<Room>('/rooms');
    const bedPromise: Promise<LoadResult<Bed>> = this.fetchAll<Bed>('/beds');
    const taskPromise: Promise<LoadResult<CareTask>> = this.fetchAll<CareTask>('/tasks');
    const alertPromise: Promise<LoadResult<Alert>> = this.fetchAll<Alert>('/alerts');
    const schedulePromise: Promise<LoadResult<Schedule>> = this.fetchAll<Schedule>('/schedules');
    const policyPromise: Promise<LoadResult<OperationPolicy>> = this.fetchOne<OperationPolicy>('/dashboard/policy');
    // The resident index has its own loading contract. Commit it as soon as
    // its request settles instead of making the resident surface wait for the
    // remaining core resources used by the management workbench.
    const elderReadyPromise: Promise<LoadResult<Elder>> = elderPromise.then(
      (result: LoadResult<Elder>): LoadResult<Elder> => {
        if (this.isCurrent(generation)) {
          if (result.ok) {
            this.elders = result.value;
          } else {
            failed.push('老人档案');
          }
          this.eldersLoaded = true;
        }
        return result;
      });

    try {
      const coreResults: LoadResult<Object>[] = await Promise.all([
        elderReadyPromise as Promise<LoadResult<Object>>,
        policyPromise as Promise<LoadResult<Object>>,
        roomPromise as Promise<LoadResult<Object>>,
        bedPromise as Promise<LoadResult<Object>>,
        taskPromise as Promise<LoadResult<Object>>,
        alertPromise as Promise<LoadResult<Object>>,
        schedulePromise as Promise<LoadResult<Object>>
      ]);
      if (!this.isCurrent(generation)) return;
      const policyResult: LoadResult<OperationPolicy> = coreResults[1] as LoadResult<OperationPolicy>;
      const roomResult: LoadResult<Room> = coreResults[2] as LoadResult<Room>;
      const bedResult: LoadResult<Bed> = coreResults[3] as LoadResult<Bed>;
      const taskResult: LoadResult<CareTask> = coreResults[4] as LoadResult<CareTask>;
      const alertResult: LoadResult<Alert> = coreResults[5] as LoadResult<Alert>;
      const scheduleResult: LoadResult<Schedule> = coreResults[6] as LoadResult<Schedule>;
      if (policyResult.ok && policyResult.value.length > 0) this.operationPolicy = policyResult.value[0];
      else failed.push('运营策略');
      if (roomResult.ok) this.rooms = roomResult.value; else failed.push('房间');
      if (bedResult.ok) this.beds = bedResult.value; else failed.push('床位');
      if (taskResult.ok) this.tasks = taskResult.value; else failed.push('护理任务');
      if (alertResult.ok) this.alerts = alertResult.value; else failed.push('告警');
      if (scheduleResult.ok) this.schedules = scheduleResult.value; else failed.push('排班');
      this.coreLoadFailed = failed.length > 0;

      // Core data is authoritative for the first screen. Do not make the
      // user wait for messages, health history, or optional modules.
      this.loaded = true;
      this.loading = false;
      this.coreVersion += 1;
      this.error = failed.length > 0 ? `部分核心数据加载失败：${failed.join('、')}` : '';
      Logger.info('[BusinessStore]', `core loaded elders=${this.elders.length} rooms=${this.rooms.length} beds=${this.beds.length} tasks=${this.tasks.length} alerts=${this.alerts.length}`);
      void this.loadSecondary(generation, failed);
    } catch (error) {
      if (!this.isCurrent(generation)) return;
      this.eldersLoaded = true;
      this.loaded = true;
      this.loading = false;
      this.coreVersion += 1;
      this.error = `核心数据加载失败：${error instanceof Error ? error.message : '网络请求失败'}`;
      this.coreLoadFailed = true;
      this.requestInFlight = false;
      this.refreshing = false;
      this.scheduleRetry();
    }
  }

  private async loadSecondary(generation: number, failed: string[]): Promise<void> {
    try {
      const executionPromise: Promise<LoadResult<CareExecution>> = this.fetchAll<CareExecution>('/care-executions');
      const devicePromise: Promise<LoadResult<IotDevice>> = this.fetchAll<IotDevice>('/iot/devices');
      const medicationPromise: Promise<LoadResult<MedicationRecord>> = this.fetchAll<MedicationRecord>('/medications');
      const notificationPromise: Promise<LoadResult<NotificationRecord>> = this.fetchAll<NotificationRecord>('/notifications');
      const billPromise: Promise<LoadResult<Bill>> = this.fetchAll<Bill>('/bills');
      const diningPromise: Promise<LoadResult<DiningOrder>> = this.fetchAll<DiningOrder>('/dining');
      const assessmentPromise: Promise<LoadResult<Assessment>> = this.fetchAll<Assessment>('/assessments');
      const secondaryResults: LoadResult<Object>[] = await Promise.all([
        executionPromise as Promise<LoadResult<Object>>,
        devicePromise as Promise<LoadResult<Object>>,
        medicationPromise as Promise<LoadResult<Object>>,
        notificationPromise as Promise<LoadResult<Object>>,
        billPromise as Promise<LoadResult<Object>>,
        diningPromise as Promise<LoadResult<Object>>,
        assessmentPromise as Promise<LoadResult<Object>>
      ]);
      if (!this.isCurrent(generation)) return;
      const executionResult: LoadResult<CareExecution> = secondaryResults[0] as LoadResult<CareExecution>;
      const deviceResult: LoadResult<IotDevice> = secondaryResults[1] as LoadResult<IotDevice>;
      const medicationResult: LoadResult<MedicationRecord> = secondaryResults[2] as LoadResult<MedicationRecord>;
      const notificationResult: LoadResult<NotificationRecord> = secondaryResults[3] as LoadResult<NotificationRecord>;
      const billResult: LoadResult<Bill> = secondaryResults[4] as LoadResult<Bill>;
      const diningResult: LoadResult<DiningOrder> = secondaryResults[5] as LoadResult<DiningOrder>;
      const assessmentResult: LoadResult<Assessment> = secondaryResults[6] as LoadResult<Assessment>;
      if (executionResult.ok) this.careExecutions = executionResult.value; else failed.push('护理执行记录');
      if (deviceResult.ok) this.devices = deviceResult.value; else failed.push('设备');
      if (medicationResult.ok) this.medications = medicationResult.value; else failed.push('用药记录');
      if (notificationResult.ok) this.notifications = notificationResult.value; else failed.push('通知');
      if (billResult.ok) this.bills = billResult.value; else failed.push('账单');
      if (diningResult.ok) this.diningOrders = diningResult.value; else failed.push('餐饮');
      if (assessmentResult.ok) this.assessments = assessmentResult.value; else failed.push('评估记录');

      await this.loadMessages(generation, failed);
      await this.loadHealthRecords(generation, failed);
    } catch (_error) {
      if (this.isCurrent(generation)) {
        failed.push('次要业务数据');
      }
    } finally {
      if (!this.isCurrent(generation)) return;
      this.requestInFlight = false;
      this.refreshing = false;
      this.error = failed.length > 0 ? `部分数据加载失败：${failed.join('、')}` : '';
      // Optional resources can be forbidden for a role or temporarily absent;
      // retry the full snapshot only when a core request actually failed.
      if (this.coreLoadFailed) {
        this.scheduleRetry();
      } else {
        this.cancelRetry();
      }
      if (this.pendingForceReload) {
        this.pendingForceReload = false;
        this.scheduleRefresh();
      }
    }
  }

  private async loadMessages(generation: number, failed: string[]): Promise<void> {
    try {
      const contactResp = await MessageApi.contacts();
      if (!this.isCurrent(generation)) return;
      if (contactResp.code !== 0 || contactResp.data === undefined || contactResp.data === null) {
        failed.push('消息联系人');
        return;
      }
      this.messageContacts = contactResp.data.list ?? [];
      const messageResponses: Array<ApiResp<Paged<UserMessage>> | undefined> = await Promise.all(
        this.messageContacts.map(async (contact: MessageContact): Promise<ApiResp<Paged<UserMessage>> | undefined> => {
          try {
            return await MessageApi.list(contact.id);
          } catch (_error) {
            return undefined;
          }
        })
      );
      if (!this.isCurrent(generation)) return;
      const messages: UserMessage[] = [];
      let failedMessage: boolean = false;
      for (let index: number = 0; index < messageResponses.length; index++) {
        const response: ApiResp<Paged<UserMessage>> | undefined = messageResponses[index];
        if (response === undefined || response.code !== 0 || response.data === undefined || response.data === null) {
          failedMessage = true;
          continue;
        }
        messages.push(...(response.data.list ?? []));
      }
      this.messages = messages;
      if (failedMessage) failed.push('消息');
    } catch (_error) {
      if (this.isCurrent(generation)) failed.push('消息');
    }
  }

  private async loadHealthRecords(generation: number, failed: string[]): Promise<void> {
    const health: HealthRecord[] = [];
    let hasFailure: boolean = false;
    const elders: Elder[] = this.elders.slice();
    for (let start: number = 0; start < elders.length; start += BusinessStore.HEALTH_BATCH_SIZE) {
      const batch: Elder[] = elders.slice(start, start + BusinessStore.HEALTH_BATCH_SIZE);
      const healthPromises: Promise<LoadResult<HealthRecord>>[] = batch.map(
        (elder: Elder): Promise<LoadResult<HealthRecord>> =>
          this.fetchAll<HealthRecord>(`/elders/${elder.id}/health-records`));
      const healthResults: LoadResult<HealthRecord>[] = await Promise.all(healthPromises);
      if (!this.isCurrent(generation)) return;
      for (let index: number = 0; index < healthResults.length; index++) {
        if (healthResults[index].ok) health.push(...healthResults[index].value);
        else hasFailure = true;
      }
    }
    if (!this.isCurrent(generation)) return;
    this.healthRecords = health;
    if (hasFailure) failed.push('健康记录');
  }

  public clear(): void {
    this.loadGeneration += 1;
    this.requestInFlight = false;
    this.coreLoadFailed = false;
    if (this.refreshTimerId !== -1) {
      clearTimeout(this.refreshTimerId);
      this.refreshTimerId = -1;
    }
    this.cancelRetry();
    this.elders = [];
    this.rooms = [];
    this.beds = [];
    this.tasks = [];
    this.careExecutions = [];
    this.devices = [];
    this.alerts = [];
    this.medications = [];
    this.notifications = [];
    this.bills = [];
    this.schedules = [];
    this.healthRecords = [];
    this.messageContacts = [];
    this.messages = [];
    this.diningOrders = [];
    this.assessments = [];
    this.operationPolicy = emptyOperationPolicy();
    this.pendingForceReload = false;
    this.coreLoadPromise = null;
    this.loading = false;
    this.refreshing = false;
    this.loaded = false;
    this.coreVersion = 0;
    this.eldersLoaded = false;
    this.error = '';
  }
}
