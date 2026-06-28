/*
 * Copyright (c) 2024 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import { hiTraceMeter } from '@kit.PerformanceAnalysisKit'

/**
 * 玻璃蒙层效果
 */

@Preview
@Component
export default struct GlassCoverView {
  @Prop
  @Watch('onDraw')
  pointsToDraw: number[][] = [];
  private settings = new RenderingContextSettings(true);
  private renderContext = new CanvasRenderingContext2D(this.settings);
  private viewWidth: number = 0;
  private viewHeight: number = 0;

  build() {
    Stack() {
      Canvas(this.renderContext)
        .width('100%')
        .height('100%')
        .onAreaChange((_: Area, newValue: Area) => {
          this.handleAreaChange(newValue)
        })
    }
    .height('100%')
    .width('100%')
  }

  private handleAreaChange(area: Area) {
    this.viewWidth = parseInt(area.width.toString());
    this.viewHeight = parseInt(area.height.toString());
    this.onDraw();
  }

  private onDraw() {
    const canvas = this.renderContext;
    if (canvas === undefined) {
      return;
    }
    // 空心透明圆圈，速度非常慢
    hiTraceMeter.startTrace('chisj slow', 1);
    console.info('chisj debug: slow start');
    canvas.save();
    // 清空给定矩形内的指定像素
    canvas.clearRect(0, 0, this.viewWidth, this.viewHeight);
    canvas.fillStyle = '#77CCCCCC';
    canvas.fillRect(0, 0, this.viewWidth, this.viewHeight);
    canvas.globalCompositeOperation = 'destination-out';
    canvas.fillStyle = '#CCCCCC';
    this.pointsToDraw.forEach((xy: number[]) => {
      this.drawOneCell(canvas, xy[0] * this.viewWidth, xy[1] * this.viewHeight, 5);
    })
    canvas.restore();
    console.info('chisj debug: slow end');
    hiTraceMeter.finishTrace('chisj slow', 1);
  }

  private drawOneCell(canvas: CanvasRenderer, x: number, y: number, width: number) {
    canvas.beginPath();
    canvas.arc(x, y, width, 0, Math.PI * 2);
    canvas.closePath();
    canvas.fill();
  }
}