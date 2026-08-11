import {
  CareWorkItem,
  DashboardEvent,
  DashboardMetric,
  DashboardSectionItem,
  FacilityStatus,
  RiskSummary,
  TrendPoint,
  WardStatus
} from '../model/DashboardModels';

export const DASHBOARD_SECTIONS: DashboardSectionItem[] = [
  {
    id: 'overview',
    label: '全院态势',
    description: '床位、人力、任务与风险总览',
    symbol: $r('sys.symbol.square_grid_2x2'),
    badge: 0
  },
  {
    id: 'care',
    label: '照护运营',
    description: '班次执行与服务质量',
    symbol: $r('sys.symbol.person_2_fill'),
    badge: 3
  },
  {
    id: 'safety',
    label: '安全预警',
    description: '风险、告警与处置闭环',
    symbol: $r('sys.symbol.checkmark_shield_fill'),
    badge: 8
  },
  {
    id: 'facility',
    label: '设备空间',
    description: '设备在线与楼层运行',
    symbol: $r('sys.symbol.building_fill'),
    badge: 2
  }
];

export const OVERVIEW_METRICS: DashboardMetric[] = [
  {
    id: 'residents',
    label: '在院长者',
    value: '356',
    unit: '人',
    trend: '较昨日 +2',
    note: '其中重点关注 21 人',
    tone: 'brand',
    symbol: $r('sys.symbol.person_2_fill')
  },
  {
    id: 'occupancy',
    label: '床位使用率',
    value: '92.4',
    unit: '%',
    trend: '可用床位 29 张',
    note: '东区二层接近满载',
    tone: 'warning',
    symbol: $r('sys.symbol.building_fill')
  },
  {
    id: 'staff',
    label: '当前在岗',
    value: '87',
    unit: '人',
    trend: '到岗率 96.7%',
    note: '夜班缺口 2 人待协调',
    tone: 'success',
    symbol: $r('sys.symbol.person_crop_circle_fill')
  },
  {
    id: 'alerts',
    label: '未闭环预警',
    value: '8',
    unit: '项',
    trend: '紧急 2 · 关注 6',
    note: '最早一项已持续 18 分钟',
    tone: 'danger',
    symbol: $r('sys.symbol.exclamationmark_triangle_fill')
  }
];

export const CARE_METRICS: DashboardMetric[] = [
  {
    id: 'care-completion',
    label: '今日任务完成率',
    value: '88.6',
    unit: '%',
    trend: '已完成 1,042 项',
    note: '仍有 37 项临近超时',
    tone: 'success',
    symbol: $r('sys.symbol.checkmark_circle_fill')
  },
  {
    id: 'medication',
    label: '用药复核',
    value: '98.2',
    unit: '%',
    trend: '待复核 6 项',
    note: '高风险药品双人复核',
    tone: 'brand',
    symbol: $r('sys.symbol.cross_vial')
  },
  {
    id: 'rounds',
    label: '巡房覆盖',
    value: '94.7',
    unit: '%',
    trend: '已覆盖 337 人',
    note: '西区三层尚有 9 人',
    tone: 'warning',
    symbol: $r('sys.symbol.calendar_badge_clock')
  },
  {
    id: 'handoff',
    label: '交接完整率',
    value: '96.1',
    unit: '%',
    trend: '缺项 4 条',
    note: '需补充责任人与复查点',
    tone: 'warning',
    symbol: $r('sys.symbol.doc_text')
  }
];

export const SAFETY_METRICS: DashboardMetric[] = [
  {
    id: 'open-risks',
    label: '当前风险事件',
    value: '8',
    unit: '项',
    trend: '较上一班次 -3',
    note: '2 项需要院级协同',
    tone: 'danger',
    symbol: $r('sys.symbol.exclamationmark_triangle_fill')
  },
  {
    id: 'response',
    label: '平均响应时间',
    value: '4.8',
    unit: '分钟',
    trend: '目标 ≤ 5 分钟',
    note: '紧急事件优先分派',
    tone: 'success',
    symbol: $r('sys.symbol.calendar_badge_clock')
  },
  {
    id: 'high-risk',
    label: '高风险长者',
    value: '21',
    unit: '人',
    trend: '跌倒风险 12 人',
    note: '今日已完成复评 17 人',
    tone: 'warning',
    symbol: $r('sys.symbol.waveform_path_ecg_square')
  },
  {
    id: 'closed-loop',
    label: '24h 闭环率',
    value: '93.5',
    unit: '%',
    trend: '已闭环 29 项',
    note: '2 项等待设备班组确认',
    tone: 'brand',
    symbol: $r('sys.symbol.checkmark_shield_fill')
  }
];

export const FACILITY_METRICS: DashboardMetric[] = [
  {
    id: 'online-devices',
    label: '设备在线率',
    value: '97.8',
    unit: '%',
    trend: '在线 1,243 台',
    note: '离线设备 28 台',
    tone: 'success',
    symbol: $r('sys.symbol.waveform_path_ecg_square')
  },
  {
    id: 'room-environment',
    label: '环境达标率',
    value: '95.6',
    unit: '%',
    trend: '异常房间 7 间',
    note: '主要为湿度偏高',
    tone: 'warning',
    symbol: $r('sys.symbol.building_fill')
  },
  {
    id: 'maintenance',
    label: '待维保工单',
    value: '14',
    unit: '单',
    trend: '紧急 2 单',
    note: '今日已完成 31 单',
    tone: 'danger',
    symbol: $r('sys.symbol.hammer_fill')
  },
  {
    id: 'energy',
    label: '今日能耗指数',
    value: '81',
    unit: '分',
    trend: '较昨日下降 3.4%',
    note: '处于合理运行区间',
    tone: 'brand',
    symbol: $r('sys.symbol.waveform_path_ecg_magnifyingglass')
  }
];

export const WARD_STATUSES: WardStatus[] = [
  { id: 'east-2', name: '东区二层', floor: '失能照护区', residents: 94, capacity: 96, occupancy: 97.9, staffOnDuty: 19, openTasks: 17, riskCount: 4 },
  { id: 'east-3', name: '东区三层', floor: '认知症照护区', residents: 78, capacity: 84, occupancy: 92.9, staffOnDuty: 21, openTasks: 13, riskCount: 2 },
  { id: 'west-2', name: '西区二层', floor: '自理生活区', residents: 91, capacity: 104, occupancy: 87.5, staffOnDuty: 17, openTasks: 9, riskCount: 1 },
  { id: 'west-3', name: '西区三层', floor: '医养协同区', residents: 93, capacity: 100, occupancy: 93.0, staffOnDuty: 24, openTasks: 21, riskCount: 1 }
];

export const CARE_TREND: TrendPoint[] = [
  { label: '周一', value: 82, secondaryValue: 91 },
  { label: '周二', value: 86, secondaryValue: 93 },
  { label: '周三', value: 89, secondaryValue: 94 },
  { label: '周四', value: 84, secondaryValue: 92 },
  { label: '周五', value: 91, secondaryValue: 96 },
  { label: '周六', value: 87, secondaryValue: 95 },
  { label: '今日', value: 89, secondaryValue: 96 }
];

export const RISK_SUMMARIES: RiskSummary[] = [
  { id: 'fall', label: '跌倒风险', count: 3, ratio: 38, tone: 'danger' },
  { id: 'medication-risk', label: '用药复核', count: 2, ratio: 25, tone: 'warning' },
  { id: 'device-risk', label: '设备离线', count: 2, ratio: 25, tone: 'warning' },
  { id: 'environment-risk', label: '环境异常', count: 1, ratio: 12, tone: 'brand' }
];

export const LIVE_EVENTS: DashboardEvent[] = [
  { id: 'event-1', time: '10:24', title: '离床未归预警', detail: '已通知责任护理员，正在现场确认', location: '东区二层 · 218 房', level: '紧急', tone: 'danger' },
  { id: 'event-2', time: '10:18', title: '呼叫器连续触发', detail: '班组长已接单，响应计时 4 分钟', location: '东区三层 · 公共活动区', level: '关注', tone: 'warning' },
  { id: 'event-3', time: '10:05', title: '房间湿度偏高', detail: '已生成环境工单并转设备班组', location: '西区三层 · 305 房', level: '关注', tone: 'warning' },
  { id: 'event-4', time: '09:56', title: '晨间用药复核完成', detail: '高风险药品已完成双人核验', location: '全院药事', level: '完成', tone: 'success' }
];

export const CARE_WORK_ITEMS: CareWorkItem[] = [
  { id: 'medication-work', label: '用药照护', owner: '护理组', completed: 326, total: 332, overdue: 0 },
  { id: 'meal-work', label: '膳食与饮水', owner: '生活照护组', completed: 278, total: 305, overdue: 3 },
  { id: 'round-work', label: '巡房与生命体征', owner: '医护协同组', completed: 337, total: 356, overdue: 5 },
  { id: 'clean-work', label: '清洁与环境', owner: '后勤组', completed: 101, total: 118, overdue: 2 }
];

export const FACILITY_STATUSES: FacilityStatus[] = [
  { id: 'monitor', label: '生命体征监测', online: 318, total: 326, note: '8 台离线待排查', symbol: $r('sys.symbol.waveform_path_ecg_square') },
  { id: 'call', label: '床旁呼叫设备', online: 392, total: 396, note: '4 台维护中', symbol: $r('sys.symbol.bell_fill') },
  { id: 'access', label: '门禁与定位', online: 214, total: 218, note: '2 个网关信号较弱', symbol: $r('sys.symbol.lock') },
  { id: 'environment', label: '环境传感设备', online: 319, total: 331, note: '12 台数据延迟', symbol: $r('sys.symbol.building_fill') }
];
