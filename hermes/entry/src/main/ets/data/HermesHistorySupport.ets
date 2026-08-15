import { HermesMessage, HermesSession } from '../model/HermesModels';

export class HermesSessionGroup {
  public source: string;
  public label: string;
  public sessions: HermesSession[];

  public constructor(source: string, label: string, sessions: HermesSession[]) {
    this.source = source;
    this.label = label;
    this.sessions = sessions;
  }
}

export class HermesOutlineItem {
  public id: string;
  public messageId: string;
  public label: string;
  public level: number;
  public question: boolean;

  public constructor(id: string, messageId: string, label: string, level: number, question: boolean) {
    this.id = id;
    this.messageId = messageId;
    this.label = label;
    this.level = level;
    this.question = question;
  }
}

export function historySourceLabel(source: string): string {
  if (source === 'api_server') {
    return 'Web UI / API Server';
  }
  if (source === 'cli') {
    return 'CLI';
  }
  if (source === 'coding_agent') {
    return 'Coding Agent';
  }
  if (source === 'global_agent') {
    return 'Global Agent';
  }
  if (source === 'cron') {
    return 'Cron';
  }
  return source.trim().length > 0 ? source : '其他';
}

function historySourceSortValue(source: string): number {
  if (source === 'api_server') {
    return -1;
  }
  if (source === 'cron') {
    return 999;
  }
  return 0;
}

export function filterHistorySessions(sessions: HermesSession[], query: string,
  source: string = 'all'): HermesSession[] {
  const normalizedQuery: string = query.trim().toLowerCase();
  return sessions.filter((session: HermesSession) => {
    if (source !== 'all' && session.source !== source) {
      return false;
    }
    if (normalizedQuery.length === 0) {
      return true;
    }
    const searchable: string = (`${session.title} ${session.preview} ${session.model} ${session.profile} ` +
      `${historySourceLabel(session.source)}`).toLowerCase();
    return searchable.includes(normalizedQuery);
  });
}

export function groupHistorySessions(sessions: HermesSession[]): HermesSessionGroup[] {
  const sources: string[] = [];
  sessions.forEach((session: HermesSession) => {
    if (!sources.includes(session.source)) {
      sources.push(session.source);
    }
  });
  sources.sort((left: string, right: string) => {
    const leftValue: number = historySourceSortValue(left);
    const rightValue: number = historySourceSortValue(right);
    if (leftValue !== rightValue) {
      return leftValue - rightValue;
    }
    return left.localeCompare(right);
  });
  return sources.map((source: string) => new HermesSessionGroup(source, historySourceLabel(source),
    sessions.filter((session: HermesSession) => session.source === source)));
}

function firstContentLine(content: string): string {
  const line: string = content.split('\n').find((value: string) => value.trim().length > 0)?.trim() || '用户问题';
  return line.length > 50 ? `${line.slice(0, 50)}…` : line;
}

export function buildHistoryOutline(messages: HermesMessage[]): HermesOutlineItem[] {
  const result: HermesOutlineItem[] = [];
  messages.forEach((message: HermesMessage) => {
    if (message.role === 'user') {
      result.push(new HermesOutlineItem(`question-${message.id}`, message.id, firstContentLine(message.content),
        0, true));
      return;
    }
    if (message.role !== 'assistant' && message.role !== 'moa') {
      return;
    }
    let headingIndex: number = 0;
    message.content.split('\n').forEach((line: string) => {
      const value: string = line.trim();
      let level: number = 0;
      let label: string = '';
      if (value.startsWith('### ')) {
        level = 3;
        label = value.slice(4).trim();
      } else if (value.startsWith('## ')) {
        level = 2;
        label = value.slice(3).trim();
      } else if (value.startsWith('# ')) {
        level = 1;
        label = value.slice(2).trim();
      }
      if (level > 0 && label.length > 0) {
        headingIndex++;
        result.push(new HermesOutlineItem(`heading-${message.id}-${headingIndex}`, message.id, label, level, false));
      }
    });
  });
  return result;
}
