import {
  HermesActivity,
  HermesFeatureSnapshot,
  HermesMetric,
  HermesNavItem,
  HermesSession
} from '../model/HermesModels';

export const HERMES_CATEGORIES: string[] = ['对话', '自动化', '资源', '洞察', '管理', '桌面工具'];

export const HERMES_NAV_ITEMS: HermesNavItem[] = [
  new HermesNavItem('chat', 'Agent 对话', '✦', '对话', '运行 Hermes Agent、管理会话并查看工具调用。'),
  new HermesNavItem('history', '历史记录', '◷', '对话', '搜索并查看 Web UI 与 Hermes 只读历史会话。'),
  new HermesNavItem('global-agent', '全局 Agent', '◎', '对话', '在全局运行模式中发起和恢复 Agent 会话。'),
  new HermesNavItem('connections', '连接与设备', '⌘', '对话', '管理应用连接、局域网 Peer 与设备能力。'),
  new HermesNavItem('group-chat', '群聊', '◉', '对话', '创建多 Agent 房间并通过提及编排协作。'),
  new HermesNavItem('jobs', '定时任务', '◴', '自动化', '创建、暂停、恢复和立即运行 Cron 任务。'),
  new HermesNavItem('kanban', 'Kanban', '▦', '自动化', '按 Profile 规划并跟踪 Agent 工作。'),
  new HermesNavItem('workflow', '可视化工作流', '◇', '自动化', '连接 Agent、条件、循环和审批节点。'),
  new HermesNavItem('channels', '平台渠道', '⌁', '自动化', '配置 Telegram、Discord、Slack、飞书等平台。'),
  new HermesNavItem('skills', '技能', '◆', '资源', '浏览、搜索、导入并管理 Hermes Skills。'),
  new HermesNavItem('plugins', '插件', '⬡', '资源', '管理插件能力与安装状态。'),
  new HermesNavItem('memory', '记忆', '◫', '资源', '查看用户笔记、持久记忆和 Profile 记忆。'),
  new HermesNavItem('files', '文件浏览器', '▱', '资源', '浏览、编辑、上传、下载与预览工作区文件。'),
  new HermesNavItem('mcp', 'MCP 管理器', '⌬', '资源', '管理托管 MCP Server、工具集和 Profile 注入。'),
  new HermesNavItem('models', '模型管理', '◈', '资源', '管理 Provider、模型、OAuth 与语音模型。'),
  new HermesNavItem('usage', '用量分析', '▥', '洞察', '查看 Token、费用、缓存命中和模型分布。'),
  new HermesNavItem('journey', '学习轨迹', '⌇', '洞察', '探索技能、记忆和学习关系。'),
  new HermesNavItem('skills-usage', '技能用量', '▤', '洞察', '按 Profile 查看技能调用与趋势。'),
  new HermesNavItem('logs', '日志', '≡', '洞察', '筛选 Agent、Server、Error 与 HTTP 日志。'),
  new HermesNavItem('performance', '性能', '⌁', '洞察', '查看运行时健康与管理员性能指标。'),
  new HermesNavItem('profiles', 'Profiles', '◍', '管理', '创建、克隆、导入、导出和分配 Profile。'),
  new HermesNavItem('settings', '设置', '⚙', '管理', '配置显示、Agent、记忆、隐私和账号。'),
  new HermesNavItem('theme', '主题', '◐', '管理', '切换明暗、水墨/漫画、字号与背景。'),
  new HermesNavItem('version-preview', '版本预览', '↺', '管理', '隔离测试新的 Hermes Studio 版本。'),
  new HermesNavItem('petdex', 'Petdex', '♧', '桌面工具', '浏览并管理 Hermes 桌面宠物。'),
  new HermesNavItem('terminal', '终端', '>_', '桌面工具', '通过 PTY 会话访问 Hermes 运行环境。'),
  new HermesNavItem('coding-agents', 'Coding Agents', '⌨', '桌面工具', '安装、配置和监控 Claude Code 与 Codex。'),
  new HermesNavItem('desktop-browser', 'Agent 浏览器', '◌', '桌面工具', '管理 Agent 可控浏览器标签和 Profile。')
];

export const HERMES_SESSIONS: HermesSession[] = [
  new HermesSession('session-1', 'HarmonyOS 移植计划', '正在梳理多端导航与原生组件边界…', '刚刚', 'gpt-5', true,
    'api_server', 'default', 18),
  new HermesSession('session-2', 'Hermes 工作流设计', '把审批节点放在模型执行和发布之间。', '18 分钟前',
    'claude-sonnet', false, 'cli', 'default', 26),
  new HermesSession('session-3', 'Provider 配置检查', 'OpenAI 兼容端点已经通过模型发现。', '昨天', 'gpt-5-mini',
    false, 'api_server', 'lab', 9),
  new HermesSession('session-4', '技能包整理', '已找到 12 个启用技能与 3 个待审批写入。', '周三', 'qwen3-coder',
    false, 'coding_agent', 'default', 34),
  new HermesSession('session-5', '群聊回顾', '三位 Agent 已完成文档、测试与代码复核。', '8 月 10 日', 'gpt-5',
    false, 'cron', 'default', 12)
];

export function findNavItem(key: string): HermesNavItem {
  const found: HermesNavItem | undefined = HERMES_NAV_ITEMS.find((item: HermesNavItem) => item.key === key);
  return found ?? HERMES_NAV_ITEMS[0];
}

export function featureSnapshot(key: string): HermesFeatureSnapshot {
  if (key === 'jobs') {
    return new HermesFeatureSnapshot(
      [new HermesMetric('任务', '8', '6 个启用'), new HermesMetric('成功率', '96%', '近 30 次运行'),
        new HermesMetric('下一次', '02:00', '每日记忆整理')],
      [new HermesActivity('每日记忆整理', '0 2 * * *', '运行中', '今天 02:00'),
        new HermesActivity('周报生成', '0 18 * * 5', '已启用', '周五 18:00'),
        new HermesActivity('Provider 健康检查', '*/30 * * * *', '正常', '12 分钟前')]
    );
  }
  if (key === 'kanban') {
    return new HermesFeatureSnapshot(
      [new HermesMetric('待处理', '7', '2 个高优先级'), new HermesMetric('进行中', '4', '3 个 Agent'),
        new HermesMetric('已完成', '19', '本周')],
      [new HermesActivity('移植聊天输入框', '适配键盘、附件和发送状态', '进行中', 'Agent Hermes'),
        new HermesActivity('建立工作流画布', '确认节点与连线交互', '待处理', 'Agent Codex'),
        new HermesActivity('多端视觉复核', 'phone / tablet / 2in1', '待处理', '未分配')]
    );
  }
  if (key === 'models') {
    return new HermesFeatureSnapshot(
      [new HermesMetric('Provider', '6', '5 个在线'), new HermesMetric('可见模型', '24', '按 Profile 授权'),
        new HermesMetric('默认模型', 'gpt-5', 'openai')],
      [new HermesActivity('OpenAI', '8 个模型可用', '已连接', '刚刚'),
        new HermesActivity('Nous Portal', '4 个模型可用', '已连接', '2 分钟前'),
        new HermesActivity('本地语音', 'STT 模型尚未下载', '需配置', '未运行')]
    );
  }
  if (key === 'usage' || key === 'performance' || key === 'skills-usage') {
    return new HermesFeatureSnapshot(
      [new HermesMetric('输入 Token', '1.28M', '过去 30 天'), new HermesMetric('输出 Token', '284K', '过去 30 天'),
        new HermesMetric('缓存命中', '42%', '节省 318K Token')],
      [new HermesActivity('gpt-5', '46% · 723K Token', '主要模型', '30 天'),
        new HermesActivity('claude-sonnet', '31% · 487K Token', '稳定', '30 天'),
        new HermesActivity('qwen3-coder', '23% · 354K Token', '代码任务', '30 天')]
    );
  }
  if (key === 'logs') {
    return new HermesFeatureSnapshot(
      [new HermesMetric('Server', '1,284', '今天'), new HermesMetric('Agent', '842', '今天'),
        new HermesMetric('Error', '3', '均已恢复')],
      [new HermesActivity('POST /api/hermes/chat', '200 · 482ms', 'INFO', '刚刚'),
        new HermesActivity('Socket /chat-run', 'session-1 connected', 'INFO', '1 分钟前'),
        new HermesActivity('Provider retry', 'upstream timeout; retry 1/3', 'WARN', '9 分钟前')]
    );
  }
  if (key === 'files') {
    return new HermesFeatureSnapshot(
      [new HermesMetric('文件', '148', '当前 Profile'), new HermesMetric('目录', '23', '工作空间'),
        new HermesMetric('已用空间', '326 MB', '本地预览')],
      [new HermesActivity('AGENTS.md', 'Markdown · 8.2 KB', '已修改', '刚刚'),
        new HermesActivity('workflow.yaml', 'YAML · 4.1 KB', '已同步', '11 分钟前'),
        new HermesActivity('report.pdf', 'PDF · 2.8 MB', '可预览', '昨天')]
    );
  }
  return new HermesFeatureSnapshot(
    [new HermesMetric('状态', '可用', '原生页面骨架'), new HermesMetric('Profile', 'default', '本地预览'),
      new HermesMetric('服务', '未连接', '等待后端适配')],
    [new HermesActivity('页面结构', '已映射上游信息架构', '原生骨架', '本批次'),
      new HermesActivity('交互状态', '加载、空态与错误态将逐功能补齐', '进行中', '下一批'),
      new HermesActivity('服务契约', 'HTTP / Socket.IO Repository 尚未接入', '待实现', '后续')]
  );
}
