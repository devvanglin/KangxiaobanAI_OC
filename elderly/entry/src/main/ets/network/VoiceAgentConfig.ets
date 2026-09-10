/**
 * 老人端语音助手服务配置。
 *
 * 老人端是普通聊天 agent，直连 AsLive 全双工聊天端点（/ws，无需代理令牌）；
 * 医师端的语音评估仍由康小伴主工程经 Go 后端代理访问同一台 AsLive 主机的
 * 受保护 /assessment-ws。两端共用同一后端主机，但入口和会话互不影响。
 */
export class VoiceAgentConfig {
  /** AsLive 全双工聊天 WebSocket 端点。 */
  static readonly CHAT_WS_URL: string = 'ws://10.10.1.11:8000/ws';
}
