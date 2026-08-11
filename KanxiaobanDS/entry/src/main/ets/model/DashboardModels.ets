export type DashboardSection = 'overview' | 'care' | 'safety' | 'facility';

export type DashboardTone = 'brand' | 'success' | 'warning' | 'danger';

export interface DashboardSectionItem {
  id: DashboardSection;
  label: string;
  description: string;
  symbol: Resource;
  badge: number;
}

export interface DashboardMetric {
  id: string;
  label: string;
  value: string;
  unit: string;
  trend: string;
  note: string;
  tone: DashboardTone;
  symbol: Resource;
}

export interface WardStatus {
  id: string;
  name: string;
  floor: string;
  residents: number;
  capacity: number;
  occupancy: number;
  staffOnDuty: number;
  openTasks: number;
  riskCount: number;
}

export interface TrendPoint {
  label: string;
  value: number;
  secondaryValue: number;
}

export interface RiskSummary {
  id: string;
  label: string;
  count: number;
  ratio: number;
  tone: DashboardTone;
}

export interface DashboardEvent {
  id: string;
  time: string;
  title: string;
  detail: string;
  location: string;
  level: '紧急' | '关注' | '完成';
  tone: DashboardTone;
}

export interface CareWorkItem {
  id: string;
  label: string;
  owner: string;
  completed: number;
  total: number;
  overdue: number;
}

export interface FacilityStatus {
  id: string;
  label: string;
  online: number;
  total: number;
  note: string;
  symbol: Resource;
}
