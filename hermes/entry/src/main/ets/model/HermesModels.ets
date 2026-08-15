export class HermesNavItem {
  public key: string;
  public title: string;
  public icon: string;
  public category: string;
  public description: string;

  public constructor(key: string, title: string, icon: string, category: string, description: string) {
    this.key = key;
    this.title = title;
    this.icon = icon;
    this.category = category;
    this.description = description;
  }
}

export class HermesSession {
  public id: string;
  public title: string;
  public preview: string;
  public updatedAt: string;
  public model: string;
  public active: boolean;
  public source: string;
  public profile: string;
  public messageCount: number;
  public archived: boolean;

  public constructor(id: string, title: string, preview: string, updatedAt: string, model: string,
    active: boolean = false, source: string = 'api_server', profile: string = 'default', messageCount: number = 0,
    archived: boolean = false) {
    this.id = id;
    this.title = title;
    this.preview = preview;
    this.updatedAt = updatedAt;
    this.model = model;
    this.active = active;
    this.source = source;
    this.profile = profile;
    this.messageCount = messageCount;
    this.archived = archived;
  }
}

@ObservedV2
export class HermesMessage {
  @Trace public id: string;
  @Trace public role: string;
  @Trace public content: string;
  @Trace public time: string;
  @Trace public pending: boolean;
  @Trace public failed: boolean;

  public constructor(id: string, role: string, content: string, time: string, pending: boolean = false,
    failed: boolean = false) {
    this.id = id;
    this.role = role;
    this.content = content;
    this.time = time;
    this.pending = pending;
    this.failed = failed;
  }
}

export type HermesSessionLoadState = 'preview' | 'loading' | 'content' | 'empty' | 'error' | 'unauthorized';
export type HermesMessageLoadState = 'preview' | 'loading' | 'content' | 'empty' | 'error' | 'unauthorized';

function createPreviewMessages(): HermesMessage[] {
  return [
    new HermesMessage('message-1', 'assistant',
      '你好，我是 Hermes。这个鸿蒙端正在按照 Hermes Studio 的信息架构和 Pure Ink 视觉逐步原生移植。', '02:58'),
    new HermesMessage('message-2', 'user', '先告诉我当前移植到哪一步了。', '02:59'),
    new HermesMessage('message-3', 'assistant',
      '已完成上游源码盘点、API 26 工程基线构建、持久化进度文件，以及 phone / tablet / 2in1 共用的原生应用骨架。当前聊天为本地交互预览，尚未连接 Koa 与 Socket.IO 服务。', '02:59')
  ];
}

@ObservedV2
export class HermesChatModel {
  @Trace public showSessions: boolean = false;
  @Trace public activeSessionId: string = 'session-1';
  @Trace public inputText: string = '';
  @Trace public sending: boolean = false;
  @Trace public remoteMode: boolean = false;
  @Trace public sessionLoadState: HermesSessionLoadState = 'preview';
  @Trace public sessionErrorText: string = '';
  @Trace public sessions: HermesSession[] = [];
  @Trace public messageLoadState: HermesMessageLoadState = 'preview';
  @Trace public messageErrorText: string = '';
  @Trace public messages: HermesMessage[] = createPreviewMessages();
  @Trace public messageTotal: number = 0;
  @Trace public loadedMessageCount: number = 0;
  @Trace public hasMoreMessages: boolean = false;
  @Trace public loadingOlderMessages: boolean = false;
  @Trace public olderMessageErrorText: string = '';

  public constructor(previewSessions: HermesSession[] = []) {
    this.usePreviewSessions(previewSessions);
  }

  public usePreviewSessions(sessions: HermesSession[]): void {
    this.remoteMode = false;
    this.sessionLoadState = 'preview';
    this.sessionErrorText = '';
    this.sessions = [...sessions];
    this.activeSessionId = this.sessions.length > 0 ? this.sessions[0].id : '';
    this.messageLoadState = 'preview';
    this.messageErrorText = '';
    this.messages = createPreviewMessages();
    this.messageTotal = this.messages.length;
    this.loadedMessageCount = this.messages.length;
    this.hasMoreMessages = false;
    this.loadingOlderMessages = false;
    this.olderMessageErrorText = '';
  }

  public beginRemoteSessionLoad(): void {
    this.remoteMode = true;
    this.sessionLoadState = 'loading';
    this.sessionErrorText = '';
    this.sessions = [];
    this.activeSessionId = '';
    this.messageLoadState = 'loading';
    this.messageErrorText = '';
    this.messages = [];
    this.messageTotal = 0;
    this.loadedMessageCount = 0;
    this.hasMoreMessages = false;
    this.loadingOlderMessages = false;
    this.olderMessageErrorText = '';
  }

  public applyRemoteSessions(sessions: HermesSession[]): void {
    this.remoteMode = true;
    this.sessions = [...sessions];
    this.sessionLoadState = sessions.length > 0 ? 'content' : 'empty';
    this.sessionErrorText = '';
    this.activeSessionId = sessions.length > 0 ? sessions[0].id : '';
    if (sessions.length === 0) {
      this.messageLoadState = 'empty';
      this.messages = [];
      this.messageTotal = 0;
      this.loadedMessageCount = 0;
      this.hasMoreMessages = false;
    }
  }

  public failRemoteSessionLoad(message: string, unauthorized: boolean = false): void {
    this.remoteMode = true;
    this.sessions = [];
    this.activeSessionId = '';
    this.sessionLoadState = unauthorized ? 'unauthorized' : 'error';
    this.sessionErrorText = message;
    this.messageLoadState = unauthorized ? 'unauthorized' : 'error';
    this.messageErrorText = message;
    this.messages = [];
    this.messageTotal = 0;
    this.loadedMessageCount = 0;
    this.hasMoreMessages = false;
    this.loadingOlderMessages = false;
    this.olderMessageErrorText = '';
  }

  public beginRemoteMessageLoad(sessionId: string): void {
    this.remoteMode = true;
    this.activeSessionId = sessionId;
    this.messageLoadState = 'loading';
    this.messageErrorText = '';
    this.messages = [];
    this.messageTotal = 0;
    this.loadedMessageCount = 0;
    this.hasMoreMessages = false;
    this.loadingOlderMessages = false;
    this.olderMessageErrorText = '';
  }

  public applyRemoteMessages(messages: HermesMessage[], total: number, hasMore: boolean): void {
    this.messages = [...messages];
    this.messageLoadState = messages.length > 0 ? 'content' : 'empty';
    this.messageErrorText = '';
    this.messageTotal = Math.max(total, messages.length);
    this.loadedMessageCount = messages.length;
    this.hasMoreMessages = hasMore;
    this.loadingOlderMessages = false;
    this.olderMessageErrorText = '';
  }

  public failRemoteMessageLoad(message: string, unauthorized: boolean = false): void {
    this.messages = [];
    this.messageLoadState = unauthorized ? 'unauthorized' : 'error';
    this.messageErrorText = message;
    this.messageTotal = 0;
    this.loadedMessageCount = 0;
    this.hasMoreMessages = false;
    this.loadingOlderMessages = false;
    this.olderMessageErrorText = '';
  }

  public beginOlderMessageLoad(): boolean {
    if (!this.remoteMode || this.loadingOlderMessages || !this.hasMoreMessages || this.activeSessionId.length === 0) {
      return false;
    }
    this.loadingOlderMessages = true;
    this.olderMessageErrorText = '';
    return true;
  }

  public prependRemoteMessages(messages: HermesMessage[], total: number, hasMore: boolean): number {
    const existingIds: Set<string> = new Set(this.messages.map((message: HermesMessage) => message.id));
    const olderMessages: HermesMessage[] = messages.filter((message: HermesMessage) => !existingIds.has(message.id));
    this.messages = [...olderMessages, ...this.messages];
    this.messageTotal = Math.max(total, this.messages.length);
    this.loadedMessageCount = Math.min(this.messageTotal, this.loadedMessageCount + messages.length);
    this.hasMoreMessages = hasMore && messages.length > 0;
    this.loadingOlderMessages = false;
    this.olderMessageErrorText = '';
    return olderMessages.length;
  }

  public failOlderMessageLoad(message: string, unauthorized: boolean = false): void {
    this.loadingOlderMessages = false;
    this.olderMessageErrorText = message;
    if (unauthorized) {
      this.messageLoadState = 'unauthorized';
      this.messageErrorText = message;
      this.hasMoreMessages = false;
    }
  }

  public sendLocalMessage(content: string, timeLabel: string): boolean {
    const normalizedContent: string = content.trim();
    if (normalizedContent.length === 0 || this.sending) {
      return false;
    }
    const requestId: string = Date.now().toString();
    this.messages = [...this.messages,
      new HermesMessage(`user-${requestId}`, 'user', normalizedContent, timeLabel),
      new HermesMessage(`local-reply-${requestId}`, 'assistant',
        '这是本地原生预览回复。真实版本会通过 Repository 接入 Hermes Studio 的认证、HTTP API 与 Socket.IO `/chat-run`，并保持工具轨迹、附件、历史会话和取消状态真实。',
        timeLabel)
    ];
    this.inputText = '';
    this.messageLoadState = 'content';
    return true;
  }

  public beginRemoteMessage(content: string, timeLabel: string): string {
    const normalizedContent: string = content.trim();
    if (normalizedContent.length === 0 || this.sending) {
      return '';
    }
    const requestId: string = Date.now().toString();
    this.sending = true;
    this.messages = [...this.messages,
      new HermesMessage(`user-${requestId}`, 'user', normalizedContent, timeLabel),
      new HermesMessage(`remote-reply-${requestId}`, 'assistant', 'Hermes 正在处理…', timeLabel, true)
    ];
    this.inputText = '';
    this.messageLoadState = 'content';
    return requestId;
  }

  public completeRemoteMessage(requestId: string, output: string, timeLabel: string): void {
    const targetId: string = `remote-reply-${requestId}`;
    const target: HermesMessage | undefined = this.messages.find((message: HermesMessage) => message.id === targetId);
    if (target !== undefined) {
      target.role = 'assistant';
      target.content = output;
      target.time = timeLabel;
      target.pending = false;
      target.failed = false;
    }
    this.sending = false;
  }

  public failRemoteMessage(requestId: string, messageText: string, timeLabel: string): void {
    const targetId: string = `remote-reply-${requestId}`;
    const target: HermesMessage | undefined = this.messages.find((message: HermesMessage) => message.id === targetId);
    if (target !== undefined) {
      target.role = 'assistant';
      target.content = messageText;
      target.time = timeLabel;
      target.pending = false;
      target.failed = true;
    }
    this.sending = false;
  }

  public resetSendingState(): void {
    this.sending = false;
  }
}

export class HermesMetric {
  public label: string;
  public value: string;
  public detail: string;

  public constructor(label: string, value: string, detail: string) {
    this.label = label;
    this.value = value;
    this.detail = detail;
  }
}

export class HermesActivity {
  public title: string;
  public detail: string;
  public status: string;
  public time: string;

  public constructor(title: string, detail: string, status: string, time: string) {
    this.title = title;
    this.detail = detail;
    this.status = status;
    this.time = time;
  }
}

export class HermesFeatureSnapshot {
  public metrics: HermesMetric[];
  public activities: HermesActivity[];

  public constructor(metrics: HermesMetric[], activities: HermesActivity[]) {
    this.metrics = metrics;
    this.activities = activities;
  }
}

@ObservedV2
export class HermesAppModel {
  @Trace public authenticated: boolean = false;
  @Trace public selectedFeature: string = 'chat';
  @Trace public mobileMenuOpen: boolean = false;
  @Trace public sidebarCollapsed: boolean = false;
  @Trace public userName: string = 'admin';
  @Trace public activeProfile: string = 'default';
  @Trace public activeModel: string = 'openai/gpt-5';
  @Trace public connectionMode: string = 'preview';
  @Trace public serverLabel: string = '本地预览';
}
