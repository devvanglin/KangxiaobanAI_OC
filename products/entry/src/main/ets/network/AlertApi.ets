import ApiClient from './ApiClient';
import { AlertAction, ApiResp, Paged } from './Dto';

interface AlertActionRequest {
  action: string;
  note: string;
}

interface EmptyBody {
}

/** 告警处置时间线与状态变更接口（医师/管理员共用 alert:handle 权限边界）。 */
export class AlertApi {
  public static async listActions(alertId: number): Promise<AlertAction[]> {
    const response: ApiResp<Paged<AlertAction>> =
      await ApiClient.getAll<AlertAction>(`/alerts/${alertId}/actions`);
    if (response.code !== 0 || response.data === undefined || response.data === null) {
      return [];
    }
    return response.data.list ?? [];
  }

  /** 处理告警：closeIt=false 置为 handled，true 置为 closed。服务端同时写一条时间线。 */
  public static async handleAlert(alertId: number, closeIt: boolean): Promise<void> {
    const body: EmptyBody = {};
    await ApiClient.patch<Object>(`/alerts/${alertId}/handle${closeIt ? '?close=1' : ''}`, body);
  }

  /** 追加处置时间线（acknowledge/assign/note/escalate/resolve/close）。 */
  public static async addAction(alertId: number, action: string, note: string): Promise<void> {
    const request: AlertActionRequest = { action: action, note: note };
    await ApiClient.post<Object>(`/alerts/${alertId}/actions`, request);
  }
}
