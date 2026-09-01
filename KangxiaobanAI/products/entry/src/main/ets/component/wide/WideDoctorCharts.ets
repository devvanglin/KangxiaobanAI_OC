import { Elder, HealthRecord } from '../../network/Dto';

interface CareLevelSegment {
  label: string;
  value: number;
  color: string;
}

interface AgeRangeValue {
  label: string;
  male: number;
  female: number;
}

interface MoodSegment {
  label: string;
  value: number;
  color: string;
}

interface CanvasSize {
  width: number;
  height: number;
}

const CARE_LEVEL_COLORS: string[] = ['#0A59F7', '#36A3FF', '#FF9F43', '#8B5CF6'];
const MALE_COLOR: string = '#3678F6';
const FEMALE_COLOR: string = '#E9689A';
const CHART_MUTED_COLOR: string = '#8A919D';
const CHART_GRID_COLOR: string = '#E6E9EE';
const MOOD_COLORS: string[] = ['#36A3FF', '#FF9F43', '#E9689A'];

@ComponentV2
export struct WideDoctorCharts {
  @Param @Require elders: Elder[];
  @Param healthRecords: HealthRecord[] = [];
  @Param dataVersion: number = 0;
  @Param compactWidth: boolean = false;
  private pieContext: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));
  private ageContext: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));
  private moodContext: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));

  @Monitor('elders')
  onEldersChange(): void {
    setTimeout((): void => {
      this.drawCareLevelPie();
      this.drawAgeBars();
      this.drawMoodPie();
    }, 0);
  }

  @Monitor('dataVersion')
  onDataVersionChange(): void {
    setTimeout((): void => {
      this.drawCareLevelPie();
      this.drawAgeBars();
      this.drawMoodPie();
    }, 0);
  }

  private chartElders(): Elder[] {
    return this.elders;
  }

  private ageOf(elder: Elder): number {
    if (elder.birth_date === undefined || elder.birth_date.length < 4) {
      return -1;
    }
    const birth: Date = new Date(elder.birth_date);
    if (Number.isNaN(birth.getTime())) {
      return -1;
    }
    const now: Date = new Date();
    let age: number = now.getFullYear() - birth.getFullYear();
    const monthDelta: number = now.getMonth() - birth.getMonth();
    if (monthDelta < 0 || (monthDelta === 0 && now.getDate() < birth.getDate())) {
      age -= 1;
    }
    return age >= 0 ? age : -1;
  }

  private careLevelIndex(level: number): number {
    if (level <= 0) return 0;
    if (level === 1) return 1;
    if (level === 2) return 2;
    return 3;
  }

  private careLevelData(): CareLevelSegment[] {
    const values: CareLevelSegment[] = [
      { label: '特级护理', value: 0, color: CARE_LEVEL_COLORS[0] },
      { label: '一级护理', value: 0, color: CARE_LEVEL_COLORS[1] },
      { label: '二级护理', value: 0, color: CARE_LEVEL_COLORS[2] },
      { label: '三级护理', value: 0, color: CARE_LEVEL_COLORS[3] }
    ];
    const elders: Elder[] = this.chartElders();
    for (let index: number = 0; index < elders.length; index++) {
      values[this.careLevelIndex(elders[index].care_level)].value += 1;
    }
    return values;
  }

  private ageData(): AgeRangeValue[] {
    const values: AgeRangeValue[] = [
      { label: '60以下', male: 0, female: 0 },
      { label: '60-70岁', male: 0, female: 0 },
      { label: '70-80岁', male: 0, female: 0 },
      { label: '80-90岁', male: 0, female: 0 },
      { label: '90岁以上', male: 0, female: 0 }
    ];
    const elders: Elder[] = this.chartElders();
    for (let index: number = 0; index < elders.length; index++) {
      const age: number = this.ageOf(elders[index]);
      if (age < 0) continue;
      const bucket: number = age < 60 ? 0 : age < 70 ? 1 : age < 80 ? 2 : age < 90 ? 3 : 4;
      if (elders[index].gender === 'M' || elders[index].gender === 'male') {
        values[bucket].male += 1;
      } else {
        values[bucket].female += 1;
      }
    }
    return values;
  }

  private contextSize(context: CanvasRenderingContext2D): CanvasSize {
    return { width: context.width, height: context.height };
  }

  private drawCareLevelPie(): void {
    const context: CanvasRenderingContext2D = this.pieContext;
    const size = this.contextSize(context);
    if (size.width <= 0 || size.height <= 0) return;
    context.clearRect(0, 0, size.width, size.height);
    const values: CareLevelSegment[] = this.careLevelData();
    const total: number = values.reduce((sum: number, item: CareLevelSegment) => sum + item.value, 0);
    const radius: number = Math.min(size.width, size.height) * 0.36;
    const centerX: number = size.width * 0.5;
    const centerY: number = size.height * 0.5;
    if (total === 0) {
      context.beginPath();
      context.arc(centerX, centerY, radius, 0, Math.PI * 2);
      context.fillStyle = CHART_GRID_COLOR;
      context.fill();
      return;
    }
    let startAngle: number = -Math.PI / 2;
    for (let index: number = 0; index < values.length; index++) {
      if (values[index].value === 0) continue;
      const endAngle: number = startAngle + values[index].value / total * Math.PI * 2;
      context.beginPath();
      context.moveTo(centerX, centerY);
      context.arc(centerX, centerY, radius, startAngle, endAngle);
      context.closePath();
      context.fillStyle = values[index].color;
      context.fill();
      startAngle = endAngle;
    }
    context.beginPath();
    context.arc(centerX, centerY, radius * 0.56, 0, Math.PI * 2);
    context.fillStyle = '#FFFFFF';
    context.fill();
  }

  private drawAgeBars(): void {
    const context: CanvasRenderingContext2D = this.ageContext;
    const size = this.contextSize(context);
    if (size.width <= 0 || size.height <= 0) return;
    context.clearRect(0, 0, size.width, size.height);
    const values: AgeRangeValue[] = this.ageData();
    let maxValue: number = 0;
    for (let index: number = 0; index < values.length; index++) {
      maxValue = Math.max(maxValue, values[index].male + values[index].female);
    }
    maxValue = Math.max(maxValue, 1);
    const left: number = Math.max(56, size.width * 0.065);
    const right: number = Math.max(24, size.width * 0.03);
    const top: number = 24;
    // Reserve a little more canvas room for the enlarged age-range labels.
    // Canvas text is measured in pixels on the high-density device, so the
    // extra inset keeps the labels readable without colliding with the plot.
    const bottom: number = this.compactWidth ? 76 : 90;
    const plotWidth: number = Math.max(1, size.width - left - right);
    const plotHeight: number = Math.max(1, size.height - top - bottom);
    context.strokeStyle = CHART_GRID_COLOR;
    context.lineWidth = 1;
    // Canvas text uses its own pixel coordinate space, so keep the labels
    // visibly readable instead of relying on system Text scaling.
    const chartFontSize: number = this.compactWidth ?
      Math.max(16, Math.min(22, size.width / 45)) :
      Math.max(24, Math.min(34, size.width / 42));
    context.font = `${chartFontSize}px sans-serif`;
    context.fillStyle = CHART_MUTED_COLOR;
    context.textAlign = 'right';
    context.textBaseline = 'middle';
    for (let line: number = 0; line <= 4; line++) {
      const y: number = top + plotHeight * line / 4;
      context.beginPath();
      context.moveTo(left, y);
      context.lineTo(size.width - right, y);
      context.stroke();
      const label: number = Math.round(maxValue * (4 - line) / 4);
      context.fillText(label.toString(), left - 10, y);
    }
    const groupWidth: number = plotWidth / values.length;
    const barWidth: number = Math.max(8, Math.min(52, groupWidth * 0.32));
    const targetAgeLabelFontSize: number = this.compactWidth ?
      Math.max(23, Math.min(30, size.width / 34)) :
      Math.max(36, Math.min(48, size.width / 30));
    const ageLabelFontSize: number = Math.max(this.compactWidth ? 19 : 27,
      Math.min(targetAgeLabelFontSize, groupWidth / 4.8));
    context.textAlign = 'center';
    context.textBaseline = 'alphabetic';
    for (let index: number = 0; index < values.length; index++) {
      const centerX: number = left + groupWidth * (index + 0.5);
      const maleHeight: number = values[index].male / maxValue * plotHeight;
      const femaleHeight: number = values[index].female / maxValue * plotHeight;
      context.fillStyle = MALE_COLOR;
      context.fillRect(centerX - barWidth - 2, top + plotHeight - maleHeight, barWidth, maleHeight);
      context.fillStyle = FEMALE_COLOR;
      context.fillRect(centerX + 2, top + plotHeight - femaleHeight, barWidth, femaleHeight);
      context.fillStyle = CHART_MUTED_COLOR;
      context.font = `${ageLabelFontSize}px sans-serif`;
      context.fillText(values[index].label, centerX, size.height - Math.max(16, bottom * 0.35));
      context.font = `${chartFontSize}px sans-serif`;
      if (values[index].male > 0) {
        context.fillStyle = MALE_COLOR;
        context.fillText(values[index].male.toString(), centerX - barWidth * 0.5,
          top + plotHeight - maleHeight - 8);
      }
      if (values[index].female > 0) {
        context.fillStyle = FEMALE_COLOR;
        context.fillText(values[index].female.toString(), centerX + barWidth * 0.5,
          top + plotHeight - femaleHeight - 8);
      }
    }
  }

  private moodData(): MoodSegment[] {
    const values: MoodSegment[] = [
      { label: '平稳', value: 0, color: MOOD_COLORS[0] },
      { label: '需关注', value: 0, color: MOOD_COLORS[1] },
      { label: '暂无记录', value: 0, color: MOOD_COLORS[2] }
    ];
    for (let index: number = 0; index < this.chartElders().length; index++) {
      const elderId: number = this.chartElders()[index].id;
      const records: HealthRecord[] = this.healthRecords
        .filter((item: HealthRecord) => item.elder_id === elderId)
        .sort((left: HealthRecord, right: HealthRecord): number =>
          right.record_time.localeCompare(left.record_time));
      if (records.length === 0) {
        values[2].value += 1;
      } else if (records[0].is_abnormal || records[0].risk_level === 'high' || records[0].risk_level === 'danger') {
        values[1].value += 1;
      } else {
        values[0].value += 1;
      }
    }
    return values;
  }

  private drawMoodPie(): void {
    const context: CanvasRenderingContext2D = this.moodContext;
    const size = this.contextSize(context);
    if (size.width <= 0 || size.height <= 0) return;
    context.clearRect(0, 0, size.width, size.height);
    const values: MoodSegment[] = this.moodData();
    const total: number = values.reduce((sum: number, item: MoodSegment) => sum + item.value, 0);
    const radius: number = Math.min(size.width, size.height) * 0.36;
    const centerX: number = size.width * 0.5;
    const centerY: number = size.height * 0.5;
    if (total === 0) return;
    let startAngle: number = -Math.PI / 2;
    for (let index: number = 0; index < values.length; index++) {
      if (values[index].value === 0) continue;
      const endAngle: number = startAngle + values[index].value / total * Math.PI * 2;
      context.beginPath();
      context.moveTo(centerX, centerY);
      context.arc(centerX, centerY, radius, startAngle, endAngle);
      context.closePath();
      context.fillStyle = values[index].color;
      context.fill();
      startAngle = endAngle;
    }
    context.beginPath();
    context.arc(centerX, centerY, radius * 0.56, 0, Math.PI * 2);
    context.fillStyle = '#FFFFFF';
    context.fill();
  }

  private maleTotal(): number {
    return this.ageData().reduce((sum: number, item: AgeRangeValue) => sum + item.male, 0);
  }

  private femaleTotal(): number {
    return this.ageData().reduce((sum: number, item: AgeRangeValue) => sum + item.female, 0);
  }

  private genderLegend(): AgeRangeValue[] {
    return [
      { label: '男', male: this.maleTotal(), female: 0 },
      { label: '女', male: 0, female: this.femaleTotal() }
    ];
  }

  @Builder
  private chartLegendDot(color: string, label: string, value: number) {
    Row({ space: 6 }) {
      Row().width(8).height(8).borderRadius(4).backgroundColor(color)
      Text(`${label} ${value}`).fontSize(this.compactWidth ? 13 : 15)
        .fontColor($r('app.color.doctor_workspace_text_secondary'))
    }
  }

  @Builder
  private careLevelChart() {
    Column({ space: 8 }) {
      Row() {
        Text('老人护理等级分布').fontSize(this.compactWidth ? 17 : 20).fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.doctor_workspace_text_primary'))
        Blank()
        Text(`${this.chartElders().length} 位`).fontSize(this.compactWidth ? 13 : 15)
          .fontColor($r('app.color.doctor_workspace_text_tertiary'))
      }.width('100%')
      Row({ space: 16 }) {
        Canvas(this.pieContext)
          .width(this.compactWidth ? 150 : 172)
          .height(172)
          .onReady(() => this.drawCareLevelPie())
        Column({ space: 8 }) {
          ForEach(this.careLevelData(), (item: CareLevelSegment) => {
            this.chartLegendDot(item.color, item.label, item.value)
          }, (item: CareLevelSegment) => `${item.label}-${this.dataVersion}`)
        }.alignItems(HorizontalAlign.Start)
      }.width('100%').alignItems(VerticalAlign.Center)
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  private ageChart() {
    Column({ space: 8 }) {
      Row() {
        Text('老人年龄分布').fontSize(this.compactWidth ? 17 : 20).fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.doctor_workspace_text_primary'))
        Blank()
        Row({ space: 12 }) {
          ForEach(this.genderLegend(), (item: AgeRangeValue) => {
            this.chartLegendDot(item.label === '男' ? MALE_COLOR : FEMALE_COLOR, item.label,
              item.label === '男' ? item.male : item.female)
          }, (item: AgeRangeValue) => `${item.label}-${this.dataVersion}`)
        }
      }.width('100%')
      Canvas(this.ageContext)
        .width('100%')
        .layoutWeight(this.compactWidth ? 0 : 1)
        .height(this.compactWidth ? 184 : 'auto')
        .onAreaChange((_oldValue: Area, _newValue: Area) => this.drawAgeBars())
        .onReady(() => this.drawAgeBars())
    }.width('100%').height(this.compactWidth ? 220 : '100%').padding(18).borderRadius(16)
      .backgroundColor($r('app.color.doctor_workspace_surface'))
      .border({ width: 0.5, color: $r('app.color.doctor_workspace_border') })
      .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private moodChart() {
    Column({ space: 8 }) {
      Row() {
        Text('长者心情分布').fontSize(this.compactWidth ? 17 : 20).fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.doctor_workspace_text_primary'))
        Blank()
        Text(`${this.chartElders().length} 位`).fontSize(this.compactWidth ? 13 : 15)
          .fontColor($r('app.color.doctor_workspace_text_tertiary'))
      }.width('100%')
      Row({ space: 16 }) {
        Canvas(this.moodContext)
          .width(this.compactWidth ? 150 : 172)
          .height(172)
          .onReady(() => this.drawMoodPie())
        Column({ space: 8 }) {
          ForEach(this.moodData(), (item: MoodSegment) => {
            this.chartLegendDot(item.color, item.label, item.value)
          }, (item: MoodSegment) => `${item.label}-${this.dataVersion}`)
        }.alignItems(HorizontalAlign.Start)
      }.width('100%').alignItems(VerticalAlign.Center)
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  private careAndMoodCard() {
    Row({ space: 24 }) {
      Column() {
        this.careLevelChart()
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Column() {
        this.moodChart()
      }
      .layoutWeight(1)
      .padding({ left: this.compactWidth ? 0 : 24 })
      .border({ width: { left: this.compactWidth ? 0 : 0.5 }, color: { left: $r('app.color.doctor_workspace_border_soft') } })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height(this.compactWidth ? 300 : 250)
    .padding(18)
    .borderRadius(16)
    .backgroundColor($r('app.color.doctor_workspace_surface'))
    .border({ width: 0.5, color: $r('app.color.doctor_workspace_border') })
    .alignItems(VerticalAlign.Top)
  }

  build() {
    Column({ space: 18 }) {
      this.careAndMoodCard()
      Column() {
        this.ageChart()
      }
      .layoutWeight(this.compactWidth ? 0 : 1)
    }
    .width('100%')
    .height(this.compactWidth ? 'auto' : '100%')
    .alignItems(HorizontalAlign.Start)
  }
}
