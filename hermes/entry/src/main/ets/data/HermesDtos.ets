export interface HermesLoginResponseDto {
  token: string;
  userId: number;
  profiles?: string[];
}

export interface HermesErrorResponseDto {
  error?: string;
  message?: string;
  detail?: string;
}

export interface HermesSessionSummaryDto {
  id: string;
  profile?: string | null;
  source: string;
  model: string;
  title: string | null;
  preview?: string;
  started_at: number;
  ended_at: number | null;
  last_active?: number;
  message_count: number;
  is_archived?: number | boolean;
}

export interface HermesSessionsResponseDto {
  sessions: HermesSessionSummaryDto[];
}

export interface HermesMessageDto {
  id: number;
  session_id: string;
  role: string;
  content: string;
  display_role?: string | null;
  display_content?: string | null;
  tool_name?: string | null;
  timestamp: number;
  reasoning?: string | null;
}

export interface HermesPaginatedMessagesDto {
  session: HermesSessionSummaryDto;
  messages: HermesMessageDto[];
  total: number;
  offset: number;
  limit: number;
  hasMore: boolean;
}

export interface HermesChatRunResponseDto {
  ok: boolean;
  status: string;
  session_id?: string;
  run_id?: string;
  output?: string;
  reasoning?: string;
  error?: string;
  event?: string;
}

export class HermesPasswordLoginRequestDto {
  public username: string;
  public password: string;

  public constructor(username: string, password: string) {
    this.username = username;
    this.password = password;
  }
}

export class HermesChatRunRequestDto {
  public input: string;
  public profile: string;
  public session_id?: string;
  public include_events: boolean = false;

  public constructor(input: string, profile: string, sessionId: string = '') {
    this.input = input;
    this.profile = profile;
    if (sessionId.length > 0) {
      this.session_id = sessionId;
    }
  }
}
