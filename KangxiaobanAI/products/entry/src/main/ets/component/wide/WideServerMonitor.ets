import ApiClient from '../../network/ApiClient';
import {
  SystemCPUStat,
  SystemDiskStat,
  SystemMemoryStat,
  SystemMonitorSnapshot,
  SystemServerInfo
} from '../../network/Dto';

@ComponentV2
struct ServerMetricRow {
  @Param @Require label: string;
  @Param @Require value: string;
  @Param note: string = '';

  build() {
    Row({ space: 10 }) {
      Column({ space: 2 }) {
        Text(this.label).fontSize(12).fontColor($r('sys.color.font_primary'))
        if (this.note.length > 0) {
          Text(this.note).fontSize(10).fontColor($r('sys.color.font_secondary'))
        }
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Text(this.value).fontSize(11).fontColor($r('sys.color.font_primary'))
        .textAlign(TextAlign.End).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
    }.width('100%').height(36).padding({ left: 0, right: 0, top: 4, bottom: 4 })
      .border({ width: { bottom: 0.5 }, color: { bottom: $r('sys.color.comp_divider') } })
  }
}

function emptyMonitor(): SystemMonitorSnapshot {
  return {
    collected_at: '',
    cpu: { cores: 0, usage_percent: 0, user_percent: 0, system_percent: 0, idle_percent: 0, available: false },
    memory: {
      total_bytes: 0, used_bytes: 0, free_bytes: 0, used_percent: 0,
      process_bytes: 0, process_percent: 0, available: false
    },
    server: {
      hostname: '--', ip: '--', os: '--', arch: '--', pid: 0, go_version: '--',
      started_at: '', uptime_seconds: 0, uptime_text: '--', goroutines: 0
    },
    disks: []
  };
}

@ComponentV2
export struct WideServerMonitor {
  @Param statusBarHeight: number = 0;
  @Param naviIndicatorHeight: number = 0;
  @Param compactWidth: boolean = false;
  @Param embedded: boolean = false;
  @Param managementScroller: Scroller = new Scroller();
  @Local cpuCores: number = 0;
  @Local cpuUsage: number = 0;
  @Local cpuUser: number = 0;
  @Local cpuSystem: number = 0;
  @Local cpuIdle: number = 0;
  @Local cpuAvailable: boolean = false;
  @Local memoryTotal: number = 0;
  @Local memoryUsed: number = 0;
  @Local memoryFree: number = 0;
  @Local memoryUsage: number = 0;
  @Local memoryProcess: number = 0;
  @Local memoryProcessUsage: number = 0;
  @Local memoryAvailable: boolean = false;
  @Local serverHostname: string = '--';
  @Local serverIp: string = '--';
  @Local serverOs: string = '--';
  @Local serverArch: string = '--';
  @Local serverPid: number = 0;
  @Local serverGoVersion: string = '--';
  @Local serverStartedAt: string = '';
  @Local serverUptime: string = '--';
  @Local serverGoroutines: number = 0;
  @Local disks: SystemDiskStat[] = [];
  @Local loading: boolean = false;
  @Local error: string = '';
  @Local lastUpdated: string = '--';
  private refreshTimer: number = -1;

  aboutToAppear(): void {
    this.loadMonitor();
    this.refreshTimer = setInterval(() => this.loadMonitor(true), 10000);
  }

  aboutToDisappear(): void {
    if (this.refreshTimer !== -1) {
      clearInterval(this.refreshTimer);
      this.refreshTimer = -1;
    }
  }

  private async loadMonitor(silent: boolean = false): Promise<void> {
    if (this.loading) {
      return;
    }
    this.loading = true;
    if (!silent) {
      this.error = '';
    }
    try {
      const response = await ApiClient.get<SystemMonitorSnapshot>('/system/monitor');
      if (response.code !== 0 || response.data === undefined || response.data === null) {
        throw new Error(response.msg || '服务器监控加载失败');
      }
      this.cpuCores = response.data.cpu.cores;
      this.cpuUsage = response.data.cpu.usage_percent;
      this.cpuUser = response.data.cpu.user_percent;
      this.cpuSystem = response.data.cpu.system_percent;
      this.cpuIdle = response.data.cpu.idle_percent;
      this.cpuAvailable = response.data.cpu.available;
      this.memoryTotal = response.data.memory.total_bytes;
      this.memoryUsed = response.data.memory.used_bytes;
      this.memoryFree = response.data.memory.free_bytes;
      this.memoryUsage = response.data.memory.used_percent;
      this.memoryProcess = response.data.memory.process_bytes;
      this.memoryProcessUsage = response.data.memory.process_percent;
      this.memoryAvailable = response.data.memory.available;
      this.serverHostname = response.data.server.hostname;
      this.serverIp = response.data.server.ip;
      this.serverOs = response.data.server.os;
      this.serverArch = response.data.server.arch;
      this.serverPid = response.data.server.pid;
      this.serverGoVersion = response.data.server.go_version;
      this.serverStartedAt = response.data.server.started_at;
      this.serverUptime = response.data.server.uptime_text;
      this.serverGoroutines = response.data.server.goroutines;
      this.disks = response.data.disks ?? [];
      this.lastUpdated = this.formatTime(response.data.collected_at);
      this.error = '';
    } catch (_error) {
      if (!silent || this.serverHostname === '--') {
        this.error = '无法读取服务器监控，请确认后端已更新并运行';
      }
    }
    this.loading = false;
  }

  private formatTime(value: string): string {
    if (value.length < 16) {
      return '--';
    }
    return value.slice(11, 19);
  }

  private percent(value: number): string {
    return `${Math.max(0, Math.min(100, value)).toFixed(1)}%`;
  }

  private bytes(value: number): string {
    if (!value || value < 0) {
      return '--';
    }
    const units: string[] = ['B', 'KB', 'MB', 'GB', 'TB'];
    let amount: number = value;
    let index: number = 0;
    while (amount >= 1024 && index < units.length - 1) {
      amount /= 1024;
      index++;
    }
    return `${amount.toFixed(index === 0 ? 0 : 2)} ${units[index]}`;
  }

  private memoryState(memory: SystemMemoryStat): string {
    return memory.available ? this.percent(memory.used_percent) : '主机内存不可用';
  }

  private cpuState(cpu: SystemCPUStat): string {
    return cpu.available ? this.percent(cpu.usage_percent) : '主机 CPU 不可用';
  }

  private currentCpu(): SystemCPUStat {
    return { cores: this.cpuCores, usage_percent: this.cpuUsage, user_percent: this.cpuUser,
      system_percent: this.cpuSystem, idle_percent: this.cpuIdle, available: this.cpuAvailable };
  }

  private currentMemory(): SystemMemoryStat {
    return { total_bytes: this.memoryTotal, used_bytes: this.memoryUsed, free_bytes: this.memoryFree,
      used_percent: this.memoryUsage, process_bytes: this.memoryProcess,
      process_percent: this.memoryProcessUsage, available: this.memoryAvailable };
  }

  private currentServer(): SystemServerInfo {
    return { hostname: this.serverHostname, ip: this.serverIp, os: this.serverOs, arch: this.serverArch,
      pid: this.serverPid, go_version: this.serverGoVersion, started_at: this.serverStartedAt,
      uptime_seconds: 0, uptime_text: this.serverUptime, goroutines: this.serverGoroutines };
  }

  @Builder
  private sectionTitle(title: string) {
    Row() {
      Text(title).fontSize(12).fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_primary'))
    }.width('100%').height(40).padding({ left: 14, right: 14 })
      .alignItems(VerticalAlign.Center)
      .border({ width: { bottom: 0.5 }, color: { bottom: $r('sys.color.comp_divider') } })
  }

  @Builder
  private cpuCard() {
    Column() {
      this.sectionTitle('CPU')
      Column({ space: 8 }) {
        Text(this.cpuState(this.currentCpu())).fontSize(30).fontWeight(FontWeight.Bold)
          .fontColor(this.currentCpu().available ? $r('app.color.brand_blue') : $r('sys.color.font_tertiary'))
        Text(this.currentCpu().available ? `${this.currentCpu().cores} 个逻辑核心 · 用户 ${this.percent(this.currentCpu().user_percent)} · 系统 ${this.percent(this.currentCpu().system_percent)}` :
          '当前运行环境未提供主机 CPU 采样')
          .fontSize(10).fontColor($r('sys.color.font_secondary'))
      }.alignItems(HorizontalAlign.Start).width('100%')
      Progress({ value: this.currentCpu().available ? this.currentCpu().usage_percent : 0, total: 100, type: ProgressType.Linear })
        .width('100%').height(5).color($r('app.color.brand_blue'))
        .backgroundColor($r('sys.color.comp_background_secondary'))
      GridRow({ columns: 12, gutter: { x: 8, y: 0 } }) {
        GridCol({ span: 4 }) { MonitorDetailCell({ label: '用户使用率', value: this.currentCpu().available ? this.percent(this.currentCpu().user_percent) : '--' }) }
        GridCol({ span: 4 }) { MonitorDetailCell({ label: '系统使用率', value: this.currentCpu().available ? this.percent(this.currentCpu().system_percent) : '--' }) }
        GridCol({ span: 4 }) { MonitorDetailCell({ label: '空闲率', value: this.currentCpu().available ? this.percent(this.currentCpu().idle_percent) : '--' }) }
      }.width('100%')
    }.width('100%').padding({ left: 14, right: 14, bottom: 6 }).borderRadius(8)
      .backgroundColor($r('sys.color.comp_background_primary'))
      .border({ width: 0.5, color: $r('sys.color.comp_divider') })
  }

  @Builder
  private memoryCard() {
    Column() {
      this.sectionTitle('内存')
      Column({ space: 8 }) {
        Text(this.memoryState(this.currentMemory())).fontSize(30).fontWeight(FontWeight.Bold)
          .fontColor(this.currentMemory().available ? $r('app.color.brand_blue') : $r('sys.color.font_tertiary'))
        Text(this.currentMemory().available ? `已用 ${this.bytes(this.currentMemory().used_bytes)} · 剩余 ${this.bytes(this.currentMemory().free_bytes)}` :
          `Go 进程 ${this.bytes(this.currentMemory().process_bytes)}`)
          .fontSize(10).fontColor($r('sys.color.font_secondary'))
      }.alignItems(HorizontalAlign.Start).width('100%')
      Progress({ value: this.currentMemory().available ? this.currentMemory().used_percent : 0, total: 100, type: ProgressType.Linear })
        .width('100%').height(5).color($r('app.color.brand_blue'))
        .backgroundColor($r('sys.color.comp_background_secondary'))
      GridRow({ columns: 12, gutter: { x: 8, y: 0 } }) {
        GridCol({ span: 4 }) { MonitorDetailCell({ label: '总内存', value: this.bytes(this.currentMemory().total_bytes) }) }
        GridCol({ span: 4 }) { MonitorDetailCell({ label: '已用内存', value: this.bytes(this.currentMemory().used_bytes) }) }
        GridCol({ span: 4 }) { MonitorDetailCell({ label: 'Go 进程', value: this.bytes(this.currentMemory().process_bytes) }) }
      }.width('100%')
    }.width('100%').padding({ left: 14, right: 14, bottom: 6 }).borderRadius(8)
      .backgroundColor($r('sys.color.comp_background_primary'))
      .border({ width: 0.5, color: $r('sys.color.comp_divider') })
  }

  @Builder
  private serverInfoCard() {
    Column() {
      this.sectionTitle('服务器信息')
      GridRow({ columns: 12, gutter: { x: 8, y: 0 } }) {
        GridCol({ span: 4 }) { MonitorDetailCell({ label: '服务器名称', value: this.currentServer().hostname }) }
        GridCol({ span: 4 }) { MonitorDetailCell({ label: '服务器 IP', value: this.currentServer().ip }) }
        GridCol({ span: 4 }) { MonitorDetailCell({ label: '操作系统', value: `${this.currentServer().os} · ${this.currentServer().arch}` }) }
        GridCol({ span: 4 }) { MonitorDetailCell({ label: '进程 ID', value: this.currentServer().pid > 0 ? this.currentServer().pid.toString() : '--' }) }
        GridCol({ span: 4 }) { MonitorDetailCell({ label: '架构', value: this.currentServer().arch }) }
        GridCol({ span: 4 }) { MonitorDetailCell({ label: '主机名', value: this.currentServer().hostname }) }
      }.width('100%')
    }.width('100%').padding({ left: 14, right: 14, bottom: 6 }).borderRadius(8)
      .backgroundColor($r('sys.color.comp_background_primary'))
      .border({ width: 0.5, color: $r('sys.color.comp_divider') })
  }

  @Builder
  private runtimeCard() {
    Column() {
      this.sectionTitle('运行时信息')
      GridRow({ columns: 12, gutter: { x: 8, y: 0 } }) {
        GridCol({ span: 4 }) { MonitorDetailCell({ label: 'Go 版本', value: this.currentServer().go_version }) }
        GridCol({ span: 4 }) { MonitorDetailCell({ label: '启动时间', value: this.formatTime(this.currentServer().started_at) }) }
        GridCol({ span: 4 }) { MonitorDetailCell({ label: '运行时长', value: this.currentServer().uptime_text }) }
        GridCol({ span: 4 }) { MonitorDetailCell({ label: 'Goroutine 数', value: this.currentServer().goroutines.toString() }) }
        GridCol({ span: 4 }) { MonitorDetailCell({ label: '应用版本', value: '1.0.0' }) }
        GridCol({ span: 4 }) { MonitorDetailCell({ label: '部署模式', value: '生产环境' }) }
      }.width('100%')
    }.width('100%').padding({ left: 14, right: 14, bottom: 6 }).borderRadius(8)
      .backgroundColor($r('sys.color.comp_background_primary'))
      .border({ width: 0.5, color: $r('sys.color.comp_divider') })
  }

  @Builder
  private diskCard() {
    Column() {
      this.sectionTitle('磁盘状态')
      if (this.disks.length === 0) {
          Text('当前运行环境未提供磁盘统计').fontSize(11).fontColor($r('sys.color.font_secondary'))
          .width('100%').padding({ top: 10, bottom: 10 })
      } else {
        List() {
          ForEach(this.disks, (disk: SystemDiskStat) => {
            ListItem() {
              Column({ space: 7 }) {
                Row() {
                  Text(disk.mount).fontSize(13).fontWeight(FontWeight.Medium)
                    .fontColor($r('sys.color.font_primary'))
                  Blank()
                  Text(this.percent(disk.used_percent)).fontSize(13).fontWeight(FontWeight.Bold)
                    .fontColor($r('sys.color.font_primary'))
                }.width('100%')
                Row() {
                  Text(`可用 ${this.bytes(disk.free_bytes)} · ${disk.filesystem}`).fontSize(10)
                    .fontColor($r('sys.color.font_secondary')).layoutWeight(1)
                  Text(`${this.bytes(disk.used_bytes)} / ${this.bytes(disk.total_bytes)}`).fontSize(10)
                    .fontColor($r('sys.color.font_secondary'))
                }.width('100%')
                Progress({ value: disk.used_percent, total: 100, type: ProgressType.Linear })
                  .width('100%').height(5).color($r('app.color.brand_blue'))
                  .backgroundColor($r('sys.color.comp_background_secondary'))
              }.width('100%').padding({ top: 10, bottom: 10 })
                .border({ width: { bottom: 0.5 }, color: { bottom: $r('sys.color.comp_divider') } })
            }
          }, (disk: SystemDiskStat) => disk.mount)
        }.width('100%').height(Math.min(360, Math.max(78, this.disks.length * 78))).scrollBar(BarState.Off)
      }
    }.width('100%').padding({ left: 14, right: 14, bottom: 6 }).borderRadius(8)
      .backgroundColor($r('sys.color.comp_background_primary'))
      .border({ width: 0.5, color: $r('sys.color.comp_divider') })
  }

  @Builder
  private monitorContent() {
      Column({ space: 12 }) {
        Blank().height(0)
        if (this.error.length > 0) {
          Text(this.error).fontSize(11).fontColor($r('app.color.doctor_workspace_danger'))
            .width('100%').padding(12).borderRadius(10)
            .backgroundColor($r('app.color.doctor_workspace_accent_soft'))
        }
        GridRow({ columns: 12, gutter: { x: 12, y: 12 } }) {
          GridCol({ span: this.compactWidth ? 12 : 6 }) { this.cpuCard() }
          GridCol({ span: this.compactWidth ? 12 : 6 }) { this.memoryCard() }
          GridCol({ span: this.compactWidth ? 12 : 6 }) { this.serverInfoCard() }
          GridCol({ span: this.compactWidth ? 12 : 6 }) { this.runtimeCard() }
          GridCol({ span: 12 }) { this.diskCard() }
        }.width('100%')
      }
      .width('100%')
      .padding({ left: this.compactWidth ? 14 : 8, right: this.compactWidth ? 14 : 8,
        top: this.embedded ? 0 : 58, bottom: this.embedded ? 0 : 16 + this.naviIndicatorHeight })
      .alignItems(HorizontalAlign.Start)
  }

  build() {
    if (this.embedded) {
      this.monitorContent()
    } else {
      Scroll(this.managementScroller) {
        this.monitorContent()
      }.width('100%').height('100%').scrollBar(BarState.Off).edgeEffect(EdgeEffect.Spring)
    }
  }
}

@ComponentV2
struct MonitorDetailCell {
  @Param @Require label: string;
  @Param @Require value: string;

  build() {
    Column({ space: 5 }) {
      Text(this.label).fontSize(10).fontColor($r('sys.color.font_secondary'))
      Text(this.value).fontSize(11).fontWeight(FontWeight.Medium).fontColor($r('sys.color.font_primary'))
        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
    }.width('100%').height(48).padding({ top: 9, bottom: 7 })
      .alignItems(HorizontalAlign.Start)
      .border({ width: { bottom: 0.5 }, color: { bottom: $r('sys.color.comp_divider') } })
  }
}
