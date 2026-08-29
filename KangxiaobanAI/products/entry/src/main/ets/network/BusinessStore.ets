import ApiClient from './ApiClient';
import {
  Alert,
  Assessment,
  Bed,
  Bill,
  CareTask,
  Elder,
  DiningOrder,
  HealthRecord,
  IotDevice,
  MedicationRecord,
  MessageContact,
  NotificationRecord,
  OperationPolicy,
  Room,
  Schedule,
  UserMessage
} from './Dto';
import { MessageApi } from './MessageApi';

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

/** 登录用户可见的业务数据。所有页面共享同一组服务器 ID。 */
@ObservedV2
export class BusinessStore {
  private static shared: BusinessStore = new BusinessStore();
  private pendingForceReload: boolean = false;

  @Trace elders: Elder[] = [];
  @Trace rooms: Room[] = [];
  @Trace beds: Bed[] = [];
  @Trace tasks: CareTask[] = [];
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
    this.loading = true;
    this.eldersLoaded = false;
    this.error = '';
    try {
      const elderResp = await ApiClient.getAll<Elder>('/elders');
      this.elders = elderResp.data?.list ?? [];
      // 长者区域独立于后续业务接口，不能被整批同步过程长期阻塞。
      this.eldersLoaded = true;
      const policyResp = await ApiClient.get<OperationPolicy>('/dashboard/policy');
      if (policyResp.code !== 0) {
        throw new Error('运营策略加载失败');
      }
      this.operationPolicy = policyResp.data;
      const roomResp = await ApiClient.getAll<Room>('/rooms');
      this.rooms = roomResp.data?.list ?? [];
      const bedResp = await ApiClient.getAll<Bed>('/beds');
      this.beds = bedResp.data?.list ?? [];
      const taskResp = await ApiClient.getAll<CareTask>('/tasks');
      this.tasks = taskResp.data?.list ?? [];
      const deviceResp = await ApiClient.getAll<IotDevice>('/iot/devices');
      this.devices = deviceResp.data?.list ?? [];
      const alertResp = await ApiClient.getAll<Alert>('/alerts');
      this.alerts = alertResp.data?.list ?? [];
      const medicationResp = await ApiClient.getAll<MedicationRecord>('/medications');
      this.medications = medicationResp.data?.list ?? [];
      const notificationResp = await ApiClient.getAll<NotificationRecord>('/notifications');
      this.notifications = notificationResp.data?.list ?? [];
      const billResp = await ApiClient.getAll<Bill>('/bills');
      this.bills = billResp.data?.list ?? [];
      const scheduleResp = await ApiClient.getAll<Schedule>('/schedules');
      this.schedules = scheduleResp.data?.list ?? [];
      const diningResp = await ApiClient.getAll<DiningOrder>('/dining');
      this.diningOrders = diningResp.data?.list ?? [];
      const assessmentResp = await ApiClient.getAll<Assessment>('/assessments');
      this.assessments = assessmentResp.data?.list ?? [];
      const contactResp = await MessageApi.contacts();
      this.messageContacts = contactResp.data?.list ?? [];
      const messages: UserMessage[] = [];
      for (let contactIndex: number = 0; contactIndex < this.messageContacts.length; contactIndex++) {
        const contact: MessageContact = this.messageContacts[contactIndex];
        const messageResp = await MessageApi.list(contact.id);
        for (let messageIndex: number = 0; messageIndex < (messageResp.data?.list ?? []).length; messageIndex++) {
          messages.push(messageResp.data.list[messageIndex]);
        }
      }
      this.messages = messages;
      const health: HealthRecord[] = [];
      for (let index: number = 0; index < this.elders.length; index++) {
        const elder: Elder = this.elders[index];
        const healthResp = await ApiClient.getAll<HealthRecord>(`/elders/${elder.id}/health-records`);
        for (let recordIndex: number = 0; recordIndex < (healthResp.data?.list ?? []).length; recordIndex++) {
          health.push(healthResp.data.list[recordIndex]);
        }
      }
      this.healthRecords = health;
      this.loaded = true;
    } catch (_error) {
      this.error = '业务数据加载失败';
      this.eldersLoaded = true;
    }
    this.loading = false;
    if (this.pendingForceReload) {
      this.pendingForceReload = false;
      await this.load(true);
    }
  }

  public clear(): void {
    this.elders = [];
    this.rooms = [];
    this.beds = [];
    this.tasks = [];
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
