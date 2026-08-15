import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { normalizeHermesServerUrl } from '../main/ets/common/HermesUrl';
import { HermesLoginResponseDto, HermesMessageDto, HermesSessionSummaryDto } from '../main/ets/data/HermesDtos';
import {
  buildHistoryOutline,
  filterHistorySessions,
  groupHistorySessions
} from '../main/ets/data/HermesHistorySupport';
import { mapLoginResponse, mapMessage, mapSessionSummary } from '../main/ets/data/HermesMappers';
import { HermesChatModel, HermesMessage, HermesSession } from '../main/ets/model/HermesModels';

export default function localUnitTest() {
  describe('localUnitTest', () => {
    // Defines a test suite. Two parameters are supported: test suite name and test suite function.
    beforeAll(() => {
      // Presets an action, which is performed only once before all test cases of the test suite start.
      // This API supports only one parameter: preset action function.
    });
    beforeEach(() => {
      // Presets an action, which is performed before each unit test case starts.
      // The number of execution times is the same as the number of test cases defined by **it**.
      // This API supports only one parameter: preset action function.
    });
    afterEach(() => {
      // Presets a clear action, which is performed after each unit test case ends.
      // The number of execution times is the same as the number of test cases defined by **it**.
      // This API supports only one parameter: clear action function.
    });
    afterAll(() => {
      // Presets a clear action, which is performed after all test cases of the test suite end.
      // This API supports only one parameter: clear action function.
    });
    it('assertContain', 0, () => {
      // Defines a test case. This API supports three parameters: test case name, filter parameter, and test case function.
      let a = 'abc';
      let b = 'b';
      // Defines a variety of assertion methods, which are used to declare expected boolean conditions.
      expect(a).assertContain(b);
      expect(a).assertEqual(a);
    });
    it('normalizeHermesServerUrl', 0, () => {
      expect(normalizeHermesServerUrl('  https://hermes.example.com/// ').normalizedUrl)
        .assertEqual('https://hermes.example.com');
      expect(normalizeHermesServerUrl('hermes.example.com').status).assertEqual('invalid');
      expect(normalizeHermesServerUrl('  ').status).assertEqual('empty');
    });
    it('mapLoginResponse', 0, () => {
      const dto: HermesLoginResponseDto = {
        token: 'token-value',
        userId: 7,
        profiles: ['care', 'default']
      };
      const result = mapLoginResponse('https://hermes.example.com', 'missing', dto);
      expect(result.ok).assertTrue();
      expect(result.session?.profile).assertEqual('care');
      const invalid = mapLoginResponse('https://hermes.example.com', 'default', { token: '', userId: 7 });
      expect(invalid.ok).assertFalse();
      expect(invalid.errorKind).assertEqual('invalid-response');
    });
    it('mapSessionSummary', 0, () => {
      const dto: HermesSessionSummaryDto = {
        id: 'session-real-1',
        source: 'api_server',
        model: 'gpt-5',
        title: null,
        started_at: Math.floor(Date.now() / 1000),
        ended_at: null,
        message_count: 3
      };
      const session = mapSessionSummary(dto);
      expect(session.id).assertEqual('session-real-1');
      expect(session.title).assertEqual('未命名会话');
      expect(session.preview).assertEqual('3 条消息');
      expect(session.source).assertEqual('api_server');
      expect(session.profile).assertEqual('default');
      expect(session.messageCount).assertEqual(3);
    });
    it('mapMessage', 0, () => {
      const dto: HermesMessageDto = {
        id: 9,
        session_id: 'session-real-1',
        role: 'tool',
        content: '',
        tool_name: 'web_search',
        timestamp: 1755200000
      };
      const message = mapMessage(dto);
      expect(message.id).assertEqual('remote-9');
      expect(message.role).assertEqual('tool');
      expect(message.content).assertEqual('工具：web_search');
    });
    it('completeRemoteMessage', 0, () => {
      const model: HermesChatModel = new HermesChatModel();
      model.beginRemoteSessionLoad();
      const requestId: string = model.beginRemoteMessage('hello', '10:00');
      expect(model.sending).assertTrue();
      expect(model.messages[1].pending).assertTrue();
      model.completeRemoteMessage(requestId, 'world', '10:01');
      expect(model.messages[1].content).assertEqual('world');
      expect(model.messages[1].pending).assertFalse();
      expect(model.messages[1].failed).assertFalse();
      expect(model.sending).assertFalse();
    });
    it('prependRemoteMessages', 0, () => {
      const model: HermesChatModel = new HermesChatModel();
      model.beginRemoteSessionLoad();
      model.applyRemoteMessages([
        new HermesMessage('remote-3', 'assistant', 'third', '10:03'),
        new HermesMessage('remote-4', 'assistant', 'fourth', '10:04')
      ], 4, true);
      const added: number = model.prependRemoteMessages([
        new HermesMessage('remote-1', 'user', 'first', '10:01'),
        new HermesMessage('remote-2', 'assistant', 'second', '10:02'),
        new HermesMessage('remote-3', 'assistant', 'third duplicate', '10:03')
      ], 4, false);
      expect(added).assertEqual(2);
      expect(model.messages.length).assertEqual(4);
      expect(model.messages[0].id).assertEqual('remote-1');
      expect(model.messages[2].content).assertEqual('third');
      expect(model.loadedMessageCount).assertEqual(4);
      expect(model.hasMoreMessages).assertFalse();
    });
    it('groupAndFilterHistorySessions', 0, () => {
      const sessions: HermesSession[] = [
        new HermesSession('api', 'API session', 'server', '刚刚', 'gpt-5', false, 'api_server', 'default', 4),
        new HermesSession('cli', 'CLI migration', 'terminal', '昨天', 'claude', false, 'cli', 'lab', 8),
        new HermesSession('cron', 'Nightly task', 'scheduled', '周三', 'qwen', false, 'cron', 'default', 2)
      ];
      expect(filterHistorySessions(sessions, 'MIGRATION').length).assertEqual(1);
      expect(filterHistorySessions(sessions, 'api SESSION').length).assertEqual(1);
      expect(filterHistorySessions(sessions, '', 'cli')[0].id).assertEqual('cli');
      const groups = groupHistorySessions(sessions);
      expect(groups[0].source).assertEqual('api_server');
      expect(groups[groups.length - 1].source).assertEqual('cron');
    });
    it('buildHistoryOutline', 0, () => {
      const outline = buildHistoryOutline([
        new HermesMessage('q1', 'user', 'How do we port History?', '10:00'),
        new HermesMessage('a1', 'assistant', '# Plan\n## Phone\n## Tablet', '10:01')
      ]);
      expect(outline.length).assertEqual(4);
      expect(outline[0].question).assertTrue();
      expect(outline[1].level).assertEqual(1);
      expect(outline[3].label).assertEqual('Tablet');
    });
  });
}
