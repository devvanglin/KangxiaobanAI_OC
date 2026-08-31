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
  private static shared: BusinessStore = new BusinessStore();
  private pendingForceReload: boolean = false;
  private retryTimerId: number = -1;
  private retryAttempt: number = 0;

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
  @Trace loaded: boolean = false;
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
    if (this.retryTimerId !== -1 || AuthStore.getToken().length === 0) return;
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

  public static getShared(): BusinessStore {
    return BusinessStore.shared;
  }

  public async load(force: boolean = false): Promise<void> {
    if (this.loading) {
      if (force) {
        this.pendingForceReload = true;
      }
      return;
    }
    if (this.loaded && !force) {
      return;
    }
    if (force) {
      this.cancelRetry();
    }
    this.loading = true;
    this.eldersLoaded = false;
    this.error = '';
    const failed: string[] = [];

    // Independent resources load concurrently. Each result is committed on
    // its own so one slow optional endpoint cannot erase a usable workbench.
    const elderPromise: Promise<LoadResult<Elder>> = this.fetchAll<Elder>('/elders');
    const policyPromise: Promise<LoadResult<OperationPolicy>> = this.fetchOne<OperationPolicy>('/dashboard/policy');
    const roomPromise: Promise<LoadResult<Room>> = this.fetchAll<Room>('/rooms');
    const bedPromise: Promise<LoadResult<Bed>> = this.fetchAll<Bed>('/beds');
    const taskPromise: Promise<LoadResult<CareTask>> = this.fetchAll<CareTask>('/tasks');
    const executionPromise: Promise<LoadResult<CareExecution>> = this.fetchAll<CareExecution>('/care-executions');
    const devicePromise: Promise<LoadResult<IotDevice>> = this.fetchAll<IotDevice>('/iot/devices');
    const alertPromise: Promise<LoadResult<Alert>> = this.fetchAll<Alert>('/alerts');
    const medicationPromise: Promise<LoadResult<MedicationRecord>> = this.fetchAll<MedicationRecord>('/medications');
    const notificationPromise: Promise<LoadResult<NotificationRecord>> = this.fetchAll<NotificationRecord>('/notifications');
    const billPromise: Promise<LoadResult<Bill>> = this.fetchAll<Bill>('/bills');
    const schedulePromise: Promise<LoadResult<Schedule>> = this.fetchAll<Schedule>('/schedules');
    const diningPromise: Promise<LoadResult<DiningOrder>> = this.fetchAll<DiningOrder>('/dining');
    const assessmentPromise: Promise<LoadResult<Assessment>> = this.fetchAll<Assessment>('/assessments');
    const elderResult: LoadResult<Elder> = await elderPromise;
    if (elderResult.ok) {
      this.elders = elderResult.value;
    } else {
      failed.push('老人档案');
    }
    // The resident summary can render as soon as this request completes.
    this.eldersLoaded = true;

    await Promise.all([policyPromise, roomPromise, bedPromise, taskPromise, executionPromise, devicePromise,
      alertPromise, medicationPromise, notificationPromise, billPromise, schedulePromise, diningPromise,
      assessmentPromise]);

    const policyResult: LoadResult<OperationPolicy> = await policyPromise;
    if (policyResult.ok && policyResult.value.length > 0) this.operationPolicy = policyResult.value[0];
    else failed.push('运营策略');
    const roomResult: LoadResult<Room> = await roomPromise;
    if (roomResult.ok) this.rooms = roomResult.value; else failed.push('房间');
    const bedResult: LoadResult<Bed> = await bedPromise;
    if (bedResult.ok) this.beds = bedResult.value; else failed.push('床位');
    const taskResult: LoadResult<CareTask> = await taskPromise;
    if (taskResult.ok) this.tasks = taskResult.value; else failed.push('护理任务');
    const executionResult: LoadResult<CareExecution> = await executionPromise;
    if (executionResult.ok) this.careExecutions = executionResult.value; else failed.push('护理执行记录');
    const deviceResult: LoadResult<IotDevice> = await devicePromise;
    if (deviceResult.ok) this.devices = deviceResult.value; else failed.push('设备');
    const alertResult: LoadResult<Alert> = await alertPromise;
    if (alertResult.ok) this.alerts = alertResult.value; else failed.push('告警');
    const medicationResult: LoadResult<MedicationRecord> = await medicationPromise;
    if (medicationResult.ok) this.medications = medicationResult.value; else failed.push('用药记录');
    const notificationResult: LoadResult<NotificationRecord> = await notificationPromise;
    if (notificationResult.ok) this.notifications = notificationResult.value; else failed.push('通知');
    const billResult: LoadResult<Bill> = await billPromise;
    if (billResult.ok) this.bills = billResult.value; else failed.push('账单');
    const scheduleResult: LoadResult<Schedule> = await schedulePromise;
    if (scheduleResult.ok) this.schedules = scheduleResult.value; else failed.push('排班');
    const diningResult: LoadResult<DiningOrder> = await diningPromise;
    if (diningResult.ok) this.diningOrders = diningResult.value; else failed.push('餐饮');
    const assessmentResult: LoadResult<Assessment> = await assessmentPromise;
    if (assessmentResult.ok) this.assessments = assessmentResult.value; else failed.push('评估记录');

    try {
      const contactResp = await MessageApi.contacts();
      if (contactResp.code !== 0 || contactResp.data === undefined || contactResp.data === null) {
        failed.push('消息联系人');
      } else {
        this.messageContacts = contactResp.data.list ?? [];
        const messagePromises: Promise<ApiResp<Paged<UserMessage>>>[] = this.messageContacts.map(
          (contact: MessageContact): Promise<ApiResp<Paged<UserMessage>>> => MessageApi.list(contact.id));
        const messageResponses: ApiResp<Paged<UserMessage>>[] = await Promise.all(messagePromises);
        const messages: UserMessage[] = [];
        for (let index: number = 0; index < messageResponses.length; index++) {
          const response: ApiResp<Paged<UserMessage>> = messageResponses[index];
          if (response.code !== 0 || response.data === undefined || response.data === null) continue;
          messages.push(...(response.data.list ?? []));
        }
        this.messages = messages;
      }
    } catch (_error) {
      failed.push('消息');
    }

    const healthPromises: Promise<LoadResult<HealthRecord>>[] = this.elders.map(
      (elder: Elder): Promise<LoadResult<HealthRecord>> => this.fetchAll<HealthRecord>(`/elders/${elder.id}/health-records`));
    const healthResults: LoadResult<HealthRecord>[] = await Promise.all(healthPromises);
    const health: HealthRecord[] = [];
    for (let index: number = 0; index < healthResults.length; index++) {
      if (healthResults[index].ok) health.push(...healthResults[index].value);
    }
    this.healthRecords = health;
    if (healthResults.some((result: LoadResult<HealthRecord>): boolean => !result.ok)) failed.push('健康记录');

    this.loaded = true;
    this.error = failed.length > 0 ? `部分数据加载失败：${failed.join('、')}` : '';
    if (failed.length > 0) {
      this.scheduleRetry();
    } else {
      this.cancelRetry();
    }
    this.loading = false;
    if (this.pendingForceReload) {
      this.pendingForceReload = false;
      await this.load(true);
    }
  }

  public clear(): void {
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
    this.loaded = false;
    this.eldersLoaded = false;
    this.error = '';
  }
}
