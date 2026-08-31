import { Elder } from '../../network/Dto';

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

interface CanvasSize {
  width: number;
  height: number;
}

const CARE_LEVEL_COLORS: string[] = ['#0A59F7', '#36A3FF', '#FF9F43', '#8B5CF6'];
const MALE_COLOR: string = '#3678F6';
const FEMALE_COLOR: string = '#E9689A';
const CHART_MUTED_COLOR: string = '#8A919D';
const CHART_GRID_COLOR: string = '#E6E9EE';

@ComponentV2
export struct WideDoctorCharts {
  @Param @Require elders: Elder[];
  @Param dataVersion: number = 0;
  @Param compactWidth: boolean = false;
  private pieContext: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));
  private ageContext: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));

  @Monitor('elders')
  onEldersChange(): void {
    setTimeout((): void => {
      this.drawCareLevelPie();
      this.drawAgeBars();
    }, 0);
  }

  @Monitor('dataVersion')
  onDataVersionChange(): void {
    setTimeout((): void => {
      this.drawCareLevelPie();
      this.drawAgeBars();
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
    const left: number = 34;
    const right: number = 12;
    const top: number = 10;
    const bottom: number = 30;
    const plotWidth: number = Math.max(1, size.width - left - right);
    const plotHeight: number = Math.max(1, size.height - top - bottom);
    context.strokeStyle = CHART_GRID_COLOR;
    context.lineWidth = 1;
    context.font = '10px sans-serif';
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
      context.fillText(label.toString(), left - 6, y);
    }
    const groupWidth: number = plotWidth / values.length;
    const barWidth: number = Math.min(18, groupWidth * 0.24);
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
      context.fillText(values[index].label, centerX, size.height - 8);
    }
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
      Text(`${label} ${value}`).fontSize(10).fontColor($r('app.color.doctor_workspace_text_secondary'))
    }
  }

  @Builder
  private careLevelChart() {
    Column({ space: 8 }) {
      Row() {
        Text('老人护理等级分布').fontSize(14).fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.doctor_workspace_text_primary'))
        Blank()
        Text(`${this.chartElders().length} 位`).fontSize(10)
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
        Text('老人年龄分布').fontSize(14).fontWeight(FontWeight.Medium)
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
        .height(184)
        .onReady(() => this.drawAgeBars())
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  build() {
    Column({ space: 18 }) {
      this.careLevelChart()
      Divider().strokeWidth(0.5).color($r('app.color.doctor_workspace_border_soft'))
      this.ageChart()
    }
    .width('100%')
    .padding(18)
    .borderRadius(16)
    .backgroundColor($r('app.color.doctor_workspace_surface'))
    .border({ width: 0.5, color: $r('app.color.doctor_workspace_border') })
    .alignItems(HorizontalAlign.Start)
  }
}
