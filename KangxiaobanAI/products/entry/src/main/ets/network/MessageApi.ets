import ApiClient from './ApiClient';
import { ApiResp, MessageContact, Paged, UserMessage } from './Dto';

interface MessageContactList {
  list: MessageContact[];
}

interface SendMessageRequest {
  receiver_id: number;
  elder_id?: number;
  content: string;
  type: string;
}

interface EmptyRequest {
}

/** 用户沟通网络接口。页面不得再自行维护跨用户聊天数据。 */
export class MessageApi {
  public static contacts(): Promise<ApiResp<MessageContactList>> {
    return ApiClient.get<MessageContactList>('/message-contacts');
  }

  public static list(peerId: number, elderId?: number): Promise<ApiResp<Paged<UserMessage>>> {
    let path: string = `/messages?peer_id=${peerId}&size=100`;
    if (elderId !== undefined) { path += `&elder_id=${elderId}`; }
    return ApiClient.get<Paged<UserMessage>>(path);
  }

  public static send(receiverId: number, content: string, elderId?: number, type: string = 'chat'):
    Promise<ApiResp<UserMessage>> {
    const request: SendMessageRequest = {
      receiver_id: receiverId,
      content: content,
      type: type
    };
    if (elderId !== undefined) {
      request.elder_id = elderId;
    }
    return ApiClient.post<UserMessage>('/messages', request);
  }

  public static markRead(messageId: number): Promise<ApiResp<Object>> {
    const request: EmptyRequest = {};
    return ApiClient.patch<Object>(`/messages/${messageId}/read`, request);
  }
}
