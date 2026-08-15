import { http } from '@kit.NetworkKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { normalizeHermesServerUrl } from '../common/HermesUrl';
import {
  HermesChatRunRequestDto,
  HermesChatRunResponseDto,
  HermesErrorResponseDto,
  HermesLoginResponseDto,
  HermesPaginatedMessagesDto,
  HermesPasswordLoginRequestDto,
  HermesSessionsResponseDto
} from './HermesDtos';
import { mapLoginResponse, mapMessages, mapSessionSummaries } from './HermesMappers';
import {
  HermesAuthSession,
  HermesChatRunResult,
  HermesLoginResult,
  HermesMessageListResult,
  HermesRepository,
  HermesRepositoryErrorKind,
  HermesSessionListResult
} from './HermesRepository';

const HERMES_LOG_DOMAIN = 0x0000;
const HERMES_LOG_TAG = 'HermesHttp';

class HermesHttpResult {
  public ok: boolean;
  public statusCode: number;
  public body: string;
  public errorKind: HermesRepositoryErrorKind;
  public message: string;

  public constructor(ok: boolean, statusCode: number = 0, body: string = '',
    errorKind: HermesRepositoryErrorKind = 'none', message: string = '') {
    this.ok = ok;
    this.statusCode = statusCode;
    this.body = body;
    this.errorKind = errorKind;
    this.message = message;
  }
}

function statusKind(statusCode: number): HermesRepositoryErrorKind {
  if (statusCode === 401) {
    return 'unauthorized';
  }
  if (statusCode === 403) {
    return 'forbidden';
  }
  return 'server';
}

function responseErrorMessage(body: string, fallback: string): string {
  if (body.trim().length === 0) {
    return fallback;
  }
  try {
    const parsed: HermesErrorResponseDto = JSON.parse(body) as HermesErrorResponseDto;
    return parsed.error?.trim() || parsed.message?.trim() || parsed.detail?.trim() || fallback;
  } catch (_error) {
    return fallback;
  }
}

async function requestJson(url: string, method: http.RequestMethod, body: string = '',
  token: string = '', profile: string = '', readTimeout: number = 60000): Promise<HermesHttpResult> {
  const request: http.HttpRequest = http.createHttp();
  const headers: Record<string, string> = { 'Content-Type': 'application/json' };
  if (token.length > 0) {
    headers['Authorization'] = `Bearer ${token}`;
  }
  if (profile.length > 0) {
    headers['X-Hermes-Profile'] = profile;
  }
  const options: http.HttpRequestOptions = {
    method: method,
    header: headers,
    expectDataType: http.HttpDataType.STRING,
    usingCache: false,
    connectTimeout: 15000,
    readTimeout: readTimeout
  };
  if (body.length > 0) {
    options.extraData = body;
  }
  try {
    const response: http.HttpResponse = await request.request(url, options);
    const responseBody: string = response.result.toString();
    const statusCode: number = Number(response.responseCode);
    if (statusCode >= 200 && statusCode < 300) {
      return new HermesHttpResult(true, statusCode, responseBody);
    }
    const fallback: string = `Hermes Studio 返回 HTTP ${statusCode}`;
    return new HermesHttpResult(false, statusCode, responseBody, statusKind(statusCode),
      responseErrorMessage(responseBody, fallback));
  } catch (_error) {
    return new HermesHttpResult(false, 0, '', 'network', '无法连接 Hermes Studio，请检查地址、网络和服务状态');
  } finally {
    request.destroy();
  }
}

export class HermesHttpRepository implements HermesRepository {
  public async login(serverUrl: string, userName: string, password: string,
    profile: string): Promise<HermesLoginResult> {
    const normalized = normalizeHermesServerUrl(serverUrl);
    if (normalized.status !== 'valid') {
      return new HermesLoginResult(false, null, 'validation', normalized.message);
    }
    const requestBody: HermesPasswordLoginRequestDto = new HermesPasswordLoginRequestDto(userName, password);
    const response: HermesHttpResult = await requestJson(`${normalized.normalizedUrl}/api/auth/login`,
      http.RequestMethod.POST, JSON.stringify(requestBody));
    if (!response.ok) {
      return new HermesLoginResult(false, null, response.errorKind, response.message);
    }
    try {
      const dto: HermesLoginResponseDto = JSON.parse(response.body) as HermesLoginResponseDto;
      return mapLoginResponse(normalized.normalizedUrl, profile, dto);
    } catch (_error) {
      return new HermesLoginResult(false, null, 'invalid-response', '登录响应不是有效 JSON');
    }
  }

  public async fetchSessions(session: HermesAuthSession): Promise<HermesSessionListResult> {
    const profileQuery: string = encodeURIComponent(session.profile);
    const response: HermesHttpResult = await requestJson(
      `${session.serverUrl}/api/hermes/sessions?profile=${profileQuery}`,
      http.RequestMethod.GET, '', session.token, session.profile);
    if (!response.ok) {
      return new HermesSessionListResult(false, [], response.errorKind, response.message);
    }
    try {
      const dto: HermesSessionsResponseDto = JSON.parse(response.body) as HermesSessionsResponseDto;
      if (!Array.isArray(dto.sessions)) {
        return new HermesSessionListResult(false, [], 'invalid-response', '会话响应缺少 sessions 数组');
      }
      return new HermesSessionListResult(true, mapSessionSummaries(dto.sessions));
    } catch (_error) {
      return new HermesSessionListResult(false, [], 'invalid-response', '会话响应不是有效 JSON');
    }
  }

  public async fetchMessages(session: HermesAuthSession, sessionId: string, offset: number = 0,
    limit: number = 150): Promise<HermesMessageListResult> {
    if (sessionId.trim().length === 0) {
      return new HermesMessageListResult(false, [], 0, false, 'validation', '会话 ID 不能为空');
    }
    const profileQuery: string = encodeURIComponent(session.profile);
    const safeOffset: number = Math.max(0, Math.floor(offset));
    const safeLimit: number = Math.max(1, Math.min(300, Math.floor(limit)));
    const response: HermesHttpResult = await requestJson(
      `${session.serverUrl}/api/hermes/sessions/conversations/${encodeURIComponent(sessionId)}` +
      `/messages/paginated?offset=${safeOffset}&limit=${safeLimit}&profile=${profileQuery}`,
      http.RequestMethod.GET, '', session.token, session.profile);
    if (!response.ok) {
      return new HermesMessageListResult(false, [], 0, false, response.errorKind, response.message);
    }
    try {
      const dto: HermesPaginatedMessagesDto = JSON.parse(response.body) as HermesPaginatedMessagesDto;
      if (!Array.isArray(dto.messages)) {
        return new HermesMessageListResult(false, [], 0, false, 'invalid-response', '消息响应缺少 messages 数组');
      }
      return new HermesMessageListResult(true, mapMessages(dto.messages), dto.total, dto.hasMore);
    } catch (_error) {
      return new HermesMessageListResult(false, [], 0, false, 'invalid-response', '消息响应不是有效 JSON');
    }
  }

  public async runOnce(session: HermesAuthSession, input: string,
    sessionId: string): Promise<HermesChatRunResult> {
    const requestBody: HermesChatRunRequestDto = new HermesChatRunRequestDto(input, session.profile, sessionId);
    hilog.info(HERMES_LOG_DOMAIN, HERMES_LOG_TAG, 'runOnce request started');
    const response: HermesHttpResult = await requestJson(`${session.serverUrl}/api/chat-run/runs`,
      http.RequestMethod.POST, JSON.stringify(requestBody), session.token, session.profile, 310000);
    hilog.info(HERMES_LOG_DOMAIN, HERMES_LOG_TAG, 'runOnce response received, ok=%{public}s, status=%{public}d',
      response.ok.toString(), response.statusCode);
    if (!response.ok) {
      const errorKind: HermesRepositoryErrorKind = response.statusCode === 409 ? 'requires-action' : response.errorKind;
      const message: string = response.statusCode === 409 ?
        '本次运行需要审批或补充信息，流式交互适配完成后才能继续' : response.message;
      return new HermesChatRunResult(false, sessionId, '', '', '', errorKind, message);
    }
    try {
      const dto: HermesChatRunResponseDto = JSON.parse(response.body) as HermesChatRunResponseDto;
      if (!dto.ok) {
        return new HermesChatRunResult(false, dto.session_id || sessionId, dto.run_id || '', '', dto.reasoning || '',
          'server', dto.error || 'Hermes 运行失败');
      }
      const output: string = dto.output?.trim() || '';
      if (output.length === 0) {
        return new HermesChatRunResult(false, dto.session_id || sessionId, dto.run_id || '', '', dto.reasoning || '',
          'invalid-response', 'Hermes 运行完成但没有返回可显示的内容');
      }
      return new HermesChatRunResult(true, dto.session_id || sessionId, dto.run_id || '', output,
        dto.reasoning || '');
    } catch (_error) {
      return new HermesChatRunResult(false, sessionId, '', '', '', 'invalid-response', '聊天响应不是有效 JSON');
    }
  }
}
