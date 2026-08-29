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
  Paged,
  Room,
  Schedule,
  UserMessage
} from './Dto';
import { MessageApi } from './MessageApi';

/** 登录用户可见的业务数据。所有页面共享同一组服务器 ID。 */
@ObservedV2
export class BusinessStore {
  private static shared: BusinessStore = new BusinessStore();

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
  @Trace loading: boolean = false;
  /** 长者接口已经返回后，即可结束长者区域的首屏加载态。 */
  @Trace eldersLoaded: boolean = false;
  @Trace loaded: boolean = false;
  @Trace error: string = '';
  private eldersLoadTimer: number = 0;

  public static getShared(): BusinessStore {
    return BusinessStore.shared;
  }

  public async load(force: boolean = false): Promise<void> {
    if (this.loading || this.loaded && !force) {
      return;
    }
    this.loading = true;
    this.eldersLoaded = false;
    this.error = '';
    this.eldersLoadTimer = setTimeout((): void => {
      if (!this.eldersLoaded) {
        this.eldersLoaded = true;
        this.error = '长者数据请求超时';
      }
    }, 12000);
    try {
      const elderResp = await ApiClient.get<Paged<Elder>>('/elders?size=100');
      this.elders = elderResp.data?.list ?? [];
      this.eldersLoaded = true;
      clearTimeout(this.eldersLoadTimer);
      const roomResp = await ApiClient.get<Paged<Room>>('/rooms?size=100');
      this.rooms = roomResp.data?.list ?? [];
      const bedResp = await ApiClient.get<Paged<Bed>>('/beds?size=200');
      this.beds = bedResp.data?.list ?? [];
      const taskResp = await ApiClient.get<Paged<CareTask>>('/tasks?size=200');
      this.tasks = taskResp.data?.list ?? [];
      const deviceResp = await ApiClient.get<Paged<IotDevice>>('/iot/devices?size=200');
      this.devices = deviceResp.data?.list ?? [];
      const alertResp = await ApiClient.get<Paged<Alert>>('/alerts?size=200');
      this.alerts = alertResp.data?.list ?? [];
      const medicationResp = await ApiClient.get<Paged<MedicationRecord>>('/medications?size=200');
      this.medications = medicationResp.data?.list ?? [];
      const notificationResp = await ApiClient.get<Paged<NotificationRecord>>('/notifications?size=200');
      this.notifications = notificationResp.data?.list ?? [];
      const billResp = await ApiClient.get<Paged<Bill>>('/bills?size=100');
      this.bills = billResp.data?.list ?? [];
      const scheduleResp = await ApiClient.get<Paged<Schedule>>('/schedules?size=100');
      this.schedules = scheduleResp.data?.list ?? [];
      const diningResp = await ApiClient.get<Paged<DiningOrder>>('/dining?size=200');
      this.diningOrders = diningResp.data?.list ?? [];
      const assessmentResp = await ApiClient.get<Paged<Assessment>>('/assessments?size=200');
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
        const healthResp = await ApiClient.get<Paged<HealthRecord>>(`/elders/${elder.id}/health-records?size=100`);
        for (let recordIndex: number = 0; recordIndex < (healthResp.data?.list ?? []).length; recordIndex++) {
          health.push(healthResp.data.list[recordIndex]);
        }
      }
      this.healthRecords = health;
      this.loaded = true;
    } catch (_error) {
      this.error = '业务数据加载失败';
      this.eldersLoaded = true;
      clearTimeout(this.eldersLoadTimer);
    }
    this.loading = false;
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
    this.loaded = false;
    this.eldersLoaded = false;
    this.error = '';
  }
}
