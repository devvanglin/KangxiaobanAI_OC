export type DashboardTone = 'brand' | 'success' | 'warning' | 'danger';

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

export interface RiskSummary {
  id: string;
  label: string;
  count: number;
  ratio: number;
  tone: DashboardTone;
}

export interface DashboardEvent {
  id: number;
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
}

export interface RoomOperation {
  id: number;
  building: string;
  floor: number;
  room_number: string;
  resident_names: string[];
  occupied_beds: number;
  total_beds: number;
  care_level: number;
  owner: string;
  vital_status: string;
  devices_online: number;
  devices_total: number;
  open_tasks: number;
  alerts: number;
  last_round: string;
  next_task: string;
  status: string;
  tone: DashboardTone;
}

export interface CockpitSummary {
  residents: number;
  occupied_beds: number;
  total_beds: number;
  free_beds: number;
  staff_on_duty: number;
  open_tasks: number;
  open_alerts: number;
  emergency_alerts: number;
  devices_online: number;
  devices_total: number;
}

export interface OperationPolicy {
  occupancy_warning_percent: number;
  device_online_warning_percent: number;
  alert_cooldown_seconds: number;
  device_offline_seconds: number;
  alert_escalation_seconds: number;
}

export interface CockpitSnapshot {
  updated_at: string;
  policy: OperationPolicy;
  summary: CockpitSummary;
  wards: WardStatus[];
  rooms: RoomOperation[];
  events: DashboardEvent[];
  facilities: FacilityStatus[];
  work_items: CareWorkItem[];
  risks: RiskSummary[];
}

export interface RoleInfo {
  code: string;
  name: string;
}

export interface LoginUser {
  id: number;
  username: string;
  real_name: string;
  roles: RoleInfo[];
}

export interface LoginResponse {
  token: string;
  user: LoginUser;
}

export interface ApiResponse<T> {
  code: number;
  msg: string;
  data?: T;
}
