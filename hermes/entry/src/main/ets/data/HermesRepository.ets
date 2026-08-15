import { HermesMessage, HermesSession } from '../model/HermesModels';

export type HermesRepositoryErrorKind = 'none' | 'validation' | 'network' | 'unauthorized' | 'forbidden' |
  'server' | 'invalid-response' | 'requires-action';

export class HermesAuthSession {
  public serverUrl: string;
  public token: string;
  public userId: number;
  public profile: string;

  public constructor(serverUrl: string, token: string, userId: number, profile: string) {
    this.serverUrl = serverUrl;
    this.token = token;
    this.userId = userId;
    this.profile = profile;
  }
}

export class HermesLoginResult {
  public ok: boolean;
  public session: HermesAuthSession | null;
  public errorKind: HermesRepositoryErrorKind;
  public message: string;

  public constructor(ok: boolean, session: HermesAuthSession | null = null,
    errorKind: HermesRepositoryErrorKind = 'none', message: string = '') {
    this.ok = ok;
    this.session = session;
    this.errorKind = errorKind;
    this.message = message;
  }
}

export class HermesSessionListResult {
  public ok: boolean;
  public sessions: HermesSession[];
  public errorKind: HermesRepositoryErrorKind;
  public message: string;

  public constructor(ok: boolean, sessions: HermesSession[] = [],
    errorKind: HermesRepositoryErrorKind = 'none', message: string = '') {
    this.ok = ok;
    this.sessions = sessions;
    this.errorKind = errorKind;
    this.message = message;
  }
}

export class HermesMessageListResult {
  public ok: boolean;
  public messages: HermesMessage[];
  public total: number;
  public hasMore: boolean;
  public errorKind: HermesRepositoryErrorKind;
  public message: string;

  public constructor(ok: boolean, messages: HermesMessage[] = [], total: number = 0, hasMore: boolean = false,
    errorKind: HermesRepositoryErrorKind = 'none', message: string = '') {
    this.ok = ok;
    this.messages = messages;
    this.total = total;
    this.hasMore = hasMore;
    this.errorKind = errorKind;
    this.message = message;
  }
}

export class HermesChatRunResult {
  public ok: boolean;
  public sessionId: string;
  public runId: string;
  public output: string;
  public reasoning: string;
  public errorKind: HermesRepositoryErrorKind;
  public message: string;

  public constructor(ok: boolean, sessionId: string = '', runId: string = '', output: string = '',
    reasoning: string = '', errorKind: HermesRepositoryErrorKind = 'none', message: string = '') {
    this.ok = ok;
    this.sessionId = sessionId;
    this.runId = runId;
    this.output = output;
    this.reasoning = reasoning;
    this.errorKind = errorKind;
    this.message = message;
  }
}

export interface HermesRepository {
  login(serverUrl: string, userName: string, password: string, profile: string): Promise<HermesLoginResult>;
  fetchSessions(session: HermesAuthSession): Promise<HermesSessionListResult>;
  fetchMessages(session: HermesAuthSession, sessionId: string, offset: number,
    limit: number): Promise<HermesMessageListResult>;
  runOnce(session: HermesAuthSession, input: string, sessionId: string): Promise<HermesChatRunResult>;
}
