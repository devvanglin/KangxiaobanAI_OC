import ApiClient from '../../network/ApiClient';
import { SystemDiskStat, SystemMonitorSnapshot, SystemNetworkStat, SystemServerInfo } from '../../network/Dto';

interface NetworkSample {
  receiveRateBps: number;
  transmitRateBps: number;
  time: string;
}

const NETWORK_HISTORY_LIMIT: number = 24;
const NETWORK_UPLOAD_COLOR: string = '#72B89B';
const NETWORK_DOWNLOAD_COLOR: string = '#E9BF72';
const NETWORK_GRID_COLOR: string = '#E5E8ED';
const NETWORK_MUTED_COLOR: string = '#8A919D';

@ComponentV2
struct MonitorStatusRing {
  @Param @Require value: number;
  @Param @Require label: string;
  @Param valueText: string = '--';
  @Param detail: string = '';
  @Param secondaryDetail: string = '';
  @Param available: boolean = true;
  @Param accentColor: string = '#2864F0';
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));

  @Monitor('value', 'available')
  onValueChange(): void {
    setTimeout((): void => this.draw(), 0);
  }

  private draw(): void {
    const width: number = this.context.width;
    const height: number = this.context.height;
    if (width <= 0 || height <= 0) {
      return;
    }
    this.context.clearRect(0, 0, width, height);
    const centerX: number = width / 2;
    const centerY: number = height / 2;
    const radius: number = Math.min(width, height) * 0.38;
    const strokeWidth: number = Math.max(8, Math.min(14, width * 0.075));
    this.context.lineWidth = strokeWidth;
    this.context.lineCap = 'round';
    this.context.beginPath();
    this.context.strokeStyle = '#EDF2FA';
    this.context.arc(centerX, centerY, radius, 0, Math.PI * 2);
    this.context.stroke();
    if (this.available) {
      const clamped: number = Math.max(0, Math.min(100, this.value));
      this.context.beginPath();
      this.context.strokeStyle = this.accentColor;
      this.context.arc(centerX, centerY, radius, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * clamped / 100);
      this.context.stroke();
    }
  }

  build() {
    Column({ space: 9 }) {
      Stack({ alignContent: Alignment.Center }) {
        Canvas(this.context)
          .width(144)
          .height(144)
          .onReady(() => this.draw())
          .onAreaChange(() => this.draw())
        Column({ space: 2 }) {
          Text(this.valueText).fontSize(26).fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
          Text(this.label).fontSize(14).fontColor($r('sys.color.font_secondary'))
        }.alignItems(HorizontalAlign.Center)
      }.width(144).height(144)
      Text(this.detail).fontSize(11).fontColor($r('sys.color.font_secondary'))
        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
      // Always reserve the secondary line so the card keeps its height when
      // monitoring data lands, otherwise the whole overview layout jumps.
      Text(this.secondaryDetail).fontSize(10).fontColor($r('sys.color.font_tertiary'))
        .maxLines(1).height(14)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }.width('100%').alignItems(HorizontalAlign.Center)
      .accessibilityText(`${this.label} ${this.valueText} ${this.detail} ${this.secondaryDetail}`)
  }
}

@ComponentV2
struct ServerMetricRow {
  @Param @Require label: string;
  @Param @Require value: string;
  @Param note: string = '';
  @Param showBottomDivider: boolean = true;

  build() {
    Row({ space: 10 }) {
      Column({ space: 2 }) {
        Text(this.label).fontSize(13).fontColor($r('sys.color.font_primary'))
        if (this.note.length > 0) {
          Text(this.note).fontSize(11).fontColor($r('sys.color.font_secondary'))
        }
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Text(this.value).fontSize(12).fontColor($r('sys.color.font_primary'))
        .textAlign(TextAlign.End).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
    }.width('100%').height(38).padding({ left: 0, right: 0, top: 4, bottom: 4 })
      .border({
        width: { bottom: this.showBottomDivider ? 0.5 : 0 },
        color: { bottom: $r('sys.color.comp_divider') }
      })
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
    disks: [],
    network: {
      available: false,
      interface: 'all',
      receive_bytes: 0,
      transmit_bytes: 0,
      receive_rate_bps: 0,
      transmit_rate_bps: 0,
      interfaces: []
    }
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
  @Local serverAppVersion: string = '--';
  @Local serverDeployMode: string = '';
  @Local disks: SystemDiskStat[] = [];
  @Local networkAvailable: boolean = false;
  @Local networkInterface: string = 'all';
  @Local networkReceiveBytes: number = 0;
  @Local networkTransmitBytes: number = 0;
  @Local networkReceiveRateBps: number = 0;
  @Local networkTransmitRateBps: number = 0;
  @Local networkSamples: NetworkSample[] = [];
  @Local networkSampleVersion: number = 0;
  @Local loading: boolean = false;
  @Local error: string = '';
  @Local lastUpdated: string = '--';
  @Local infoCardMinHeight: number = 0;
  private networkContext: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));
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
      this.serverAppVersion = response.data.server.app_version ?? '--';
      this.serverDeployMode = response.data.server.deploy_mode ?? '';
      this.disks = response.data.disks ?? [];
      this.applyNetwork(response.data.network);
      this.lastUpdated = this.formatTime(response.data.collected_at);
      this.error = '';
    } catch (_error) {
      if (!silent || this.serverHostname === '--') {
        this.error = '无法读取服务器监控，请确认后端已更新并运行';
      }
    }
    this.loading = false;
  }

  private applyNetwork(network?: SystemNetworkStat): void {
    if (network === undefined) {
      this.networkAvailable = false;
      return;
    }
    this.networkAvailable = network.available;
    this.networkInterface = network.interface || 'all';
    this.networkReceiveBytes = network.receive_bytes;
    this.networkTransmitBytes = network.transmit_bytes;
    this.networkReceiveRateBps = network.receive_rate_bps;
    this.networkTransmitRateBps = network.transmit_rate_bps;
    if (!network.available) {
      return;
    }
    const samples: NetworkSample[] = this.networkSamples.slice();
    samples.push({
      receiveRateBps: network.receive_rate_bps,
      transmitRateBps: network.transmit_rate_bps,
      time: this.formatTime(new Date().toISOString())
    });
    this.networkSamples = samples.slice(Math.max(0, samples.length - NETWORK_HISTORY_LIMIT));
    this.networkSampleVersion += 1;
  }

  /** 部署模式展示名：production=生产环境，dev=开发环境，其余原样显示。 */
  private deployModeLabel(): string {
    const mode: string = this.serverDeployMode;
    if (mode === 'production' || mode === 'prod') { return '生产环境'; }
    if (mode === 'dev' || mode === 'development') { return '开发环境'; }
    return mode.length > 0 ? mode : '--';
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

  private rate(value: number): string {
    if (!Number.isFinite(value) || value < 0) {
      return '--';
    }
    if (value >= 1024 * 1024) {
      return `${(value / 1024 / 1024).toFixed(2)} MB/s`;
    }
    if (value >= 1024) {
      return `${(value / 1024).toFixed(2)} KB/s`;
    }
    return `${value.toFixed(0)} B/s`;
  }

  @Monitor('networkSampleVersion')
  onNetworkSampleChange(): void {
    setTimeout((): void => this.drawNetworkChart(), 0);
  }

  private diskUsage(): number {
    return this.disks.length > 0 ? Math.max(0, Math.min(100, this.disks[0].used_percent)) : 0;
  }

  private diskUsageText(): string {
    return this.disks.length > 0 ? this.percent(this.diskUsage()) : '--';
  }

  private drawNetworkChart(): void {
    const width: number = this.networkContext.width;
    const height: number = this.networkContext.height;
    if (width <= 0 || height <= 0) {
      return;
    }
    this.networkContext.clearRect(0, 0, width, height);
    if (!this.networkAvailable) {
      this.networkContext.fillStyle = NETWORK_MUTED_COLOR;
      this.networkContext.font = '16px sans-serif';
      this.networkContext.textAlign = 'center';
      this.networkContext.textBaseline = 'middle';
      this.networkContext.fillText('暂无网络采样', width / 2, height / 2);
      return;
    }
    // 进入页面先铺一条当前速率的基线，采样积累后过渡为真实曲线。
    const collected: NetworkSample[] = this.networkSamples;
    const seedTime: string = this.lastUpdated !== '--' ? this.lastUpdated : this.formatTime(new Date().toISOString());
    const samples: NetworkSample[] = collected.length === 0 ?
      [{ receiveRateBps: 0, transmitRateBps: 0, time: seedTime },
       { receiveRateBps: 0, transmitRateBps: 0, time: seedTime }] :
      collected.length === 1 ? [collected[0], collected[0]] : collected;
    const left: number = 46;
    const right: number = 18;
    const top: number = 18;
    const bottom: number = 30;
    const plotWidth: number = Math.max(1, width - left - right);
    const plotHeight: number = Math.max(1, height - top - bottom);
    let maxRate: number = 0;
    samples.forEach((sample: NetworkSample): void => {
      maxRate = Math.max(maxRate, sample.receiveRateBps, sample.transmitRateBps);
    });
    maxRate = Math.max(1024, maxRate);
    this.networkContext.strokeStyle = NETWORK_GRID_COLOR;
    this.networkContext.lineWidth = 1;
    this.networkContext.fillStyle = NETWORK_MUTED_COLOR;
      this.networkContext.font = '14px sans-serif';
    this.networkContext.textAlign = 'right';
    this.networkContext.textBaseline = 'middle';
    for (let line: number = 0; line <= 3; line++) {
      const y: number = top + plotHeight * line / 3;
      this.networkContext.beginPath();
      this.networkContext.moveTo(left, y);
      this.networkContext.lineTo(width - right, y);
      this.networkContext.stroke();
      this.networkContext.fillText(this.rate(maxRate * (3 - line) / 3), left - 8, y);
    }
    const pointX = (index: number): number => samples.length === 1 ? left + plotWidth / 2 :
      left + plotWidth * index / (samples.length - 1);
    const pointY = (value: number): number => top + plotHeight - plotHeight * value / maxRate;
    const drawSeries = (receive: boolean, fillColor: string, lineColor: string): void => {
      this.networkContext.beginPath();
      this.networkContext.moveTo(pointX(0), top + plotHeight);
      samples.forEach((sample: NetworkSample, index: number): void => {
        this.networkContext.lineTo(pointX(index), pointY(receive ? sample.receiveRateBps : sample.transmitRateBps));
      });
      this.networkContext.lineTo(pointX(samples.length - 1), top + plotHeight);
      this.networkContext.closePath();
      this.networkContext.fillStyle = fillColor;
      this.networkContext.globalAlpha = 0.28;
      this.networkContext.fill();
      this.networkContext.globalAlpha = 1;
      this.networkContext.beginPath();
      samples.forEach((sample: NetworkSample, index: number): void => {
        const y: number = pointY(receive ? sample.receiveRateBps : sample.transmitRateBps);
        if (index === 0) this.networkContext.moveTo(pointX(index), y);
        else this.networkContext.lineTo(pointX(index), y);
      });
      this.networkContext.strokeStyle = lineColor;
      this.networkContext.lineWidth = 2;
      this.networkContext.stroke();
    };
    drawSeries(false, '#B9DEC9', NETWORK_UPLOAD_COLOR);
    drawSeries(true, '#F8E7B8', NETWORK_DOWNLOAD_COLOR);
    this.networkContext.fillStyle = NETWORK_MUTED_COLOR;
    this.networkContext.font = '12px sans-serif';
    this.networkContext.textAlign = 'center';
    this.networkContext.textBaseline = 'alphabetic';
    if (samples.length > 0) {
      this.networkContext.fillText(samples[0].time, left, height - 8);
      this.networkContext.fillText(samples[samples.length - 1].time, width - right, height - 8);
    }
  }

  private currentServer(): SystemServerInfo {
    return { hostname: this.serverHostname, ip: this.serverIp, os: this.serverOs, arch: this.serverArch,
      pid: this.serverPid, go_version: this.serverGoVersion,
      app_version: this.serverAppVersion, deploy_mode: this.serverDeployMode, started_at: this.serverStartedAt,
      uptime_seconds: 0, uptime_text: this.serverUptime, goroutines: this.serverGoroutines };
  }

  @Builder
  private sectionTitle(title: string) {
    Row() {
      Text(title).fontSize(14).fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_primary'))
    }.width('100%').height(40).padding({ left: 14, right: 14 })
      .alignItems(VerticalAlign.Center)
      .border({ width: { bottom: 0.5 }, color: { bottom: $r('sys.color.comp_divider') } })
  }

  @Builder
  private statusPanel() {
    Column() {
      this.sectionTitle('状态')
      GridRow({ columns: 12, gutter: { x: 8, y: 0 } }) {
        GridCol({ span: this.compactWidth ? 12 : 4 }) {
          MonitorStatusRing({
            value: this.cpuAvailable ? this.cpuUsage : 0,
            valueText: this.cpuAvailable ? this.percent(this.cpuUsage) : '--',
            label: 'CPU',
            detail: this.cpuAvailable ? `${this.cpuCores} 个逻辑核心` : '主机 CPU 不可用',
            secondaryDetail: this.cpuAvailable ?
              `用户 ${this.percent(this.cpuUser)} · 系统 ${this.percent(this.cpuSystem)} · 空闲 ${this.percent(this.cpuIdle)}` : '',
            available: this.cpuAvailable
          })
        }
        GridCol({ span: this.compactWidth ? 12 : 4 }) {
          MonitorStatusRing({
            value: this.memoryAvailable ? this.memoryUsage : 0,
            valueText: this.memoryAvailable ? this.percent(this.memoryUsage) : '--',
            label: '内存',
            detail: this.memoryAvailable ? `${this.bytes(this.memoryUsed)} / ${this.bytes(this.memoryTotal)}` : '主机内存不可用',
            secondaryDetail: this.memoryAvailable ?
              `剩余 ${this.bytes(this.memoryFree)} · Go 进程 ${this.bytes(this.memoryProcess)}` : '',
            available: this.memoryAvailable
          })
        }
        GridCol({ span: this.compactWidth ? 12 : 4 }) {
          MonitorStatusRing({
            value: this.disks.length > 0 ? this.diskUsage() : 0,
            valueText: this.disks.length > 0 ? this.diskUsageText() : '--',
            label: this.disks.length > 0 ? this.disks[0].mount : '磁盘',
            detail: this.disks.length > 0 ? `${this.bytes(this.disks[0].used_bytes)} / ${this.bytes(this.disks[0].total_bytes)}` : '磁盘数据不可用',
            secondaryDetail: this.disks.length > 0 ?
              `可用 ${this.bytes(this.disks[0].free_bytes)} · ${this.disks[0].filesystem}` : '',
            available: this.disks.length > 0
          })
        }
      }.width('100%').padding({ top: 16, bottom: 16 })
    }.width('100%').borderRadius(8)
      .backgroundColor($r('sys.color.comp_background_primary'))
      .border({ width: 0.5, color: $r('sys.color.comp_divider') })
      .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private systemInfoPanel() {
    Column() {
      this.sectionTitle('系统信息')
      Column({ space: 8 }) {
        Column() {
          Text('服务器信息').fontSize(13).fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary')).width('100%').height(30)
          ServerMetricRow({ label: '服务器名称', value: this.currentServer().hostname })
          ServerMetricRow({ label: '服务器 IP', value: this.currentServer().ip })
          ServerMetricRow({ label: '操作系统', value: `${this.currentServer().os} · ${this.currentServer().arch}` })
          ServerMetricRow({ label: '进程 ID', value: this.currentServer().pid > 0 ? this.currentServer().pid.toString() : '--' })
          ServerMetricRow({ label: '架构', value: this.currentServer().arch })
          ServerMetricRow({ label: '主机名', value: this.currentServer().hostname, showBottomDivider: false })
        }.width('100%').alignItems(HorizontalAlign.Start)
        Column() {
          Text('运行时信息').fontSize(13).fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary')).width('100%').height(30)
          ServerMetricRow({ label: 'Go 版本', value: this.currentServer().go_version })
          ServerMetricRow({ label: '启动时间', value: this.formatTime(this.currentServer().started_at) })
          ServerMetricRow({ label: '运行时长', value: this.currentServer().uptime_text })
          ServerMetricRow({ label: 'Goroutine 数', value: this.currentServer().goroutines.toString() })
          ServerMetricRow({ label: '应用版本', value: this.serverAppVersion })
          ServerMetricRow({ label: '部署模式', value: this.deployModeLabel(), showBottomDivider: false })
        }.width('100%').alignItems(HorizontalAlign.Start)
      }.width('100%').padding({ left: 12, right: 12, bottom: 6 })
    }.width('100%').borderRadius(8)
      .backgroundColor($r('sys.color.comp_background_primary'))
      .border({ width: 0.5, color: $r('sys.color.comp_divider') })
      .alignItems(HorizontalAlign.Start)
      .constraintSize({ minHeight: this.compactWidth ? 0 : this.infoCardMinHeight })
  }

  @Builder
  private networkLegend(color: string, label: string, value: string) {
    Row({ space: 6 }) {
      Row().width(8).height(8).borderRadius(4).backgroundColor(color)
      Text(`${label} ${value}`).fontSize(12).fontColor($r('sys.color.font_secondary'))
    }
  }

  @Builder
  private networkCard() {
    Column() {
      Row() {
      Text('网络监控').fontSize(14).fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_primary'))
        Blank()
        Text(this.networkAvailable ? (this.networkInterface === 'all' ? '全部网卡' : this.networkInterface) :
          '网络数据不可用').fontSize(11)
          .fontColor(this.networkAvailable ? $r('sys.color.font_secondary') : $r('sys.color.font_tertiary'))
      }.width('100%').height(42).padding({ left: 14, right: 14 })
        .border({ width: { bottom: 0.5 }, color: { bottom: $r('sys.color.comp_divider') } })
      Row({ space: 10 }) {
        this.networkLegend(NETWORK_UPLOAD_COLOR, '上行', this.rate(this.networkTransmitRateBps))
        this.networkLegend(NETWORK_DOWNLOAD_COLOR, '下行', this.rate(this.networkReceiveRateBps))
        Text(`总发送 ${this.networkAvailable ? this.bytes(this.networkTransmitBytes) : '--'}`).fontSize(11)
          .fontColor($r('sys.color.font_secondary'))
        Text(`总接收 ${this.networkAvailable ? this.bytes(this.networkReceiveBytes) : '--'}`).fontSize(11)
          .fontColor($r('sys.color.font_secondary'))
      }.width('100%').padding({ left: 14, right: 14, top: 12, bottom: 4 })
        .alignItems(VerticalAlign.Center)
      Canvas(this.networkContext)
        .width('100%').height(250)
        .padding({ left: 14, right: 14, bottom: 4 })
        .onAreaChange(() => this.drawNetworkChart())
        .onReady(() => this.drawNetworkChart())
    }.width('100%').borderRadius(8)
      .backgroundColor($r('sys.color.comp_background_primary'))
      .border({ width: 0.5, color: $r('sys.color.comp_divider') })
      .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private monitorContent() {
      Column({ space: 10 }) {
        if (this.error.length > 0) {
          Text(this.error).fontSize(12).fontColor($r('app.color.doctor_workspace_danger'))
            .width('100%').padding(12).borderRadius(10)
            .backgroundColor($r('app.color.doctor_workspace_accent_soft'))
        }
        GridRow({ columns: 12, gutter: { x: 12, y: 10 } }) {
          GridCol({ span: this.compactWidth ? 12 : 7 }) {
            Column({ space: 10 }) {
              this.statusPanel()
              this.networkCard()
            }.width('100%')
              .onAreaChange((_oldArea: Area, newArea: Area) => {
                this.infoCardMinHeight = Number(newArea.height);
              })
          }
          GridCol({ span: this.compactWidth ? 12 : 5 }) {
            this.systemInfoPanel()
          }
        }.width('100%')
      }
      .width('100%')
      // The management overview already owns the shared horizontal inset.
      // Avoid adding a second inset when this monitor is embedded beside the
      // operation-log card so both cards share the same left and right edges.
      .padding({ left: this.embedded ? 0 : (this.compactWidth ? 14 : 8),
        right: this.embedded ? 0 : (this.compactWidth ? 14 : 8),
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
