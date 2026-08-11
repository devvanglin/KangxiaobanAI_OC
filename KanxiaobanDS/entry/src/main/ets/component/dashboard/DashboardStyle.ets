import { DashboardTone } from '../../model/DashboardModels';

export function dashboardToneColor(tone: DashboardTone): Resource {
  if (tone === 'success') {
    return $r('app.color.status_success');
  }
  if (tone === 'warning') {
    return $r('app.color.status_warning');
  }
  if (tone === 'danger') {
    return $r('app.color.status_danger');
  }
  return $r('app.color.brand_primary');
}

export function dashboardToneSoftColor(tone: DashboardTone): Resource {
  if (tone === 'success') {
    return $r('app.color.status_success_soft');
  }
  if (tone === 'warning') {
    return $r('app.color.status_warning_soft');
  }
  if (tone === 'danger') {
    return $r('app.color.status_danger_soft');
  }
  return $r('app.color.brand_soft');
}

export function dashboardProgressWidth(value: number): string {
  const safeValue: number = Math.max(0, Math.min(100, value));
  return `${safeValue}%`;
}
