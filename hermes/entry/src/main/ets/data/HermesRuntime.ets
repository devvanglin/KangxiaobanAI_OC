import { hilog } from '@kit.PerformanceAnalysisKit';
import { HermesChatModel } from '../model/HermesModels';
import {
  HermesAuthSession,
  HermesChatRunResult,
  HermesMessageListResult,
  HermesRepository,
  HermesSessionListResult
} from './HermesRepository';

const HERMES_RUNTIME_LOG_DOMAIN = 0x0000;
const HERMES_RUNTIME_LOG_TAG = 'HermesRuntime';

@ObservedV2
export class HermesRuntime {
  private repositoryValue: HermesRepository;
  @Trace private authSessionValue: HermesAuthSession | null = null;
  @Trace private revisionValue: number = 0;

  public constructor(repository: HermesRepository) {
    this.repositoryValue = repository;
  }

  public repository(): HermesRepository {
    return this.repositoryValue;
  }

  public authSession(): HermesAuthSession | null {
    return this.authSessionValue;
  }

  public activate(session: HermesAuthSession): void {
    this.authSessionValue = session;
    this.revisionValue++;
  }

  public clear(): void {
    this.authSessionValue = null;
    this.revisionValue++;
  }

  public revision(): number {
    return this.revisionValue;
  }

  public isActive(session: HermesAuthSession, revision: number): boolean {
    return this.authSessionValue === session && this.revisionValue === revision;
  }

  public async loadSessions(model: HermesChatModel): Promise<void> {
    const activeSession: HermesAuthSession | null = this.authSessionValue;
    if (activeSession === null) {
      return;
    }
    const activeRevision: number = this.revisionValue;
    model.beginRemoteSessionLoad();
    const result: HermesSessionListResult = await this.repositoryValue.fetchSessions(activeSession);
    if (!this.isActive(activeSession, activeRevision)) {
      return;
    }
    if (!result.ok) {
      model.failRemoteSessionLoad(result.message || '会话加载失败', result.errorKind === 'unauthorized');
      return;
    }
    model.applyRemoteSessions(result.sessions);
    if (result.sessions.length > 0) {
      await this.loadMessages(model, result.sessions[0].id);
    }
  }

  public selectSession(model: HermesChatModel, sessionId: string): void {
    if (this.authSessionValue === null) {
      model.activeSessionId = sessionId;
      return;
    }
    this.loadMessages(model, sessionId);
  }

  public async loadMessages(model: HermesChatModel, sessionId: string): Promise<void> {
    const activeSession: HermesAuthSession | null = this.authSessionValue;
    if (activeSession === null || sessionId.length === 0) {
      return;
    }
    const activeRevision: number = this.revisionValue;
    model.beginRemoteMessageLoad(sessionId);
    const result: HermesMessageListResult = await this.repositoryValue.fetchMessages(activeSession, sessionId, 0, 150);
    if (!this.isActive(activeSession, activeRevision) || model.activeSessionId !== sessionId) {
      return;
    }
    if (result.ok) {
      model.applyRemoteMessages(result.messages, result.total, result.hasMore);
      return;
    }
    model.failRemoteMessageLoad(result.message || '历史消息加载失败', result.errorKind === 'unauthorized');
    if (result.errorKind === 'unauthorized') {
      model.failRemoteSessionLoad('认证已过期，请重新登录', true);
    }
  }

  public async loadOlderMessages(model: HermesChatModel): Promise<number> {
    const activeSession: HermesAuthSession | null = this.authSessionValue;
    const sessionId: string = model.activeSessionId;
    if (activeSession === null || !model.beginOlderMessageLoad()) {
      return 0;
    }
    const activeRevision: number = this.revisionValue;
    const offset: number = model.loadedMessageCount;
    const result: HermesMessageListResult = await this.repositoryValue.fetchMessages(activeSession, sessionId,
      offset, 150);
    if (!this.isActive(activeSession, activeRevision) || model.activeSessionId !== sessionId) {
      model.loadingOlderMessages = false;
      return 0;
    }
    if (result.ok) {
      return model.prependRemoteMessages(result.messages, result.total, result.hasMore);
    }
    model.failOlderMessageLoad(result.message || '更早消息加载失败', result.errorKind === 'unauthorized');
    if (result.errorKind === 'unauthorized') {
      model.failRemoteSessionLoad('认证已过期，请重新登录', true);
    }
    return 0;
  }

  public async sendMessage(model: HermesChatModel, content: string, timeLabel: string): Promise<void> {
    const activeSession: HermesAuthSession | null = this.authSessionValue;
    if (activeSession === null) {
      model.sendLocalMessage(content, timeLabel);
      return;
    }
    const activeRevision: number = this.revisionValue;
    const requestId: string = model.beginRemoteMessage(content, timeLabel);
    if (requestId.length === 0) {
      return;
    }
    hilog.info(HERMES_RUNTIME_LOG_DOMAIN, HERMES_RUNTIME_LOG_TAG, 'sendMessage request started');
    const result: HermesChatRunResult = await this.repositoryValue.runOnce(activeSession, content,
      model.activeSessionId);
    hilog.info(HERMES_RUNTIME_LOG_DOMAIN, HERMES_RUNTIME_LOG_TAG, 'sendMessage result received, ok=%{public}s',
      result.ok.toString());
    if (!this.isActive(activeSession, activeRevision)) {
      hilog.warn(HERMES_RUNTIME_LOG_DOMAIN, HERMES_RUNTIME_LOG_TAG, 'sendMessage ignored stale result');
      model.resetSendingState();
      return;
    }
    if (result.ok) {
      if (model.activeSessionId.length === 0 && result.sessionId.length > 0) {
        model.activeSessionId = result.sessionId;
      }
      model.completeRemoteMessage(requestId, result.output, this.nowLabel());
      hilog.info(HERMES_RUNTIME_LOG_DOMAIN, HERMES_RUNTIME_LOG_TAG, 'sendMessage result applied');
      return;
    }
    const message: string = result.message || 'Hermes 运行失败';
    model.failRemoteMessage(requestId, `发送失败：${message}`, this.nowLabel());
    if (result.errorKind === 'unauthorized') {
      model.failRemoteSessionLoad('认证已过期，请重新登录', true);
    }
  }

  private nowLabel(): string {
    const date: Date = new Date();
    const hour: string = date.getHours().toString().padStart(2, '0');
    const minute: string = date.getMinutes().toString().padStart(2, '0');
    return `${hour}:${minute}`;
  }
}
