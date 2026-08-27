/** 后端统一响应结构 {code,msg,data}。 */
export interface ApiResp<T> {
  code: number;
  msg: string;
  data: T;
}

export interface RoleInfo {
  code: string;
  name: string;
}

export interface LoginUser {
  id: number;
  username: string;
  real_name: string;
  phone: string;
  status: number;
  roles: RoleInfo[];
}

export interface LoginResp {
  token: string;
  user: LoginUser;
}

export interface Paged<T> {
  list: T[];
  page: number;
  size: number;
  total: number;
}

export interface Elder {
  id: number;
  name: string;
  gender: string;
  birth_date?: string;
  contact_phone?: string;
  care_level: number;
  status: number;
  bed_id?: number;
  emergency_contacts?: ElderContact[];
  remark?: string;
}

export interface ElderContact {
  name: string;
  relation: string;
  phone: string;
  is_emergency: boolean;
}

export interface HealthRecord {
  id: number;
  elder_id: number;
  temperature?: number;
  systolic?: number;
  diastolic?: number;
  heart_rate?: number;
  spo2?: number;
  source: string;
  record_time: string;
  is_abnormal: boolean;
}

export interface Alert {
  id: number;
  elder_id?: number;
  device_id: string;
  type: string;
  level: string;
  content: string;
  status: string;
  create_time: string;
}

export interface Bill {
  id: number;
  elder_id: number;
  bill_month: string;
  bed_fee: number;
  nursing_fee: number;
  meal_fee: number;
  other_fee: number;
  amount: number;
  paid: number;
  status: string;
}