import { HermesMessage, HermesSession } from '../model/HermesModels';
import { HermesLoginResponseDto, HermesMessageDto, HermesSessionSummaryDto } from './HermesDtos';
import { HermesAuthSession, HermesLoginResult } from './HermesRepository';

function relativeTimeLabel(timestampSeconds: number): string {
  if (!Number.isFinite(timestampSeconds) || timestampSeconds <= 0) {
    return '未知时间';
  }
  const elapsedSeconds: number = Math.max(0, Math.floor(Date.now() / 1000 - timestampSeconds));
  if (elapsedSeconds < 60) {
    return '刚刚';
  }
  if (elapsedSeconds < 3600) {
    return `${Math.floor(elapsedSeconds / 60)} 分钟前`;
  }
  if (elapsedSeconds < 86400) {
    return `${Math.floor(elapsedSeconds / 3600)} 小时前`;
  }
  return `${Math.floor(elapsedSeconds / 86400)} 天前`;
}

export function mapLoginResponse(serverUrl: string, profile: string,
  dto: HermesLoginResponseDto): HermesLoginResult {
  if (typeof dto.token !== 'string' || dto.token.trim().length === 0 ||
    typeof dto.userId !== 'number' || !Number.isFinite(dto.userId)) {
    return new HermesLoginResult(false, null, 'invalid-response', '登录响应缺少有效 token 或 userId');
  }
  const requestedProfile: string = profile.trim();
  let activeProfile: string = requestedProfile.length > 0 ? requestedProfile : 'default';
  if (dto.profiles !== undefined && dto.profiles.length > 0 && !dto.profiles.includes(activeProfile)) {
    activeProfile = dto.profiles[0];
  }
  return new HermesLoginResult(true,
    new HermesAuthSession(serverUrl, dto.token, dto.userId, activeProfile));
}

export function mapSessionSummary(dto: HermesSessionSummaryDto): HermesSession {
  const title: string = dto.title?.trim() || '未命名会话';
  const preview: string = dto.preview?.trim() || `${dto.message_count} 条消息`;
  const timestamp: number = dto.last_active ?? dto.ended_at ?? dto.started_at;
  return new HermesSession(dto.id, title, preview, relativeTimeLabel(timestamp), dto.model || 'unknown', false,
    dto.source || 'other', dto.profile?.trim() || 'default', dto.message_count,
    dto.is_archived === true || dto.is_archived === 1);
}

export function mapSessionSummaries(dtos: HermesSessionSummaryDto[]): HermesSession[] {
  return dtos
    .filter((dto: HermesSessionSummaryDto) => typeof dto.id === 'string' && dto.id.length > 0)
    .map((dto: HermesSessionSummaryDto) => mapSessionSummary(dto));
}

function messageTimeLabel(timestamp: number): string {
  if (!Number.isFinite(timestamp) || timestamp <= 0) {
    return '';
  }
  const milliseconds: number = timestamp > 100000000000 ? timestamp : timestamp * 1000;
  const date: Date = new Date(milliseconds);
  return `${date.getHours().toString().padStart(2, '0')}:${date.getMinutes().toString().padStart(2, '0')}`;
}

export function mapMessage(dto: HermesMessageDto): HermesMessage {
  const role: string = dto.display_role?.trim() || dto.role || 'system';
  let content: string = dto.display_content?.trim() || dto.content?.trim() || '';
  if (content.length === 0 && dto.tool_name?.trim()) {
    content = `工具：${dto.tool_name.trim()}`;
  }
  return new HermesMessage(`remote-${dto.id}`, role, content || '（空消息）', messageTimeLabel(dto.timestamp));
}

export function mapMessages(dtos: HermesMessageDto[]): HermesMessage[] {
  return dtos
    .filter((dto: HermesMessageDto) => Number.isFinite(dto.id))
    .map((dto: HermesMessageDto) => mapMessage(dto));
}
