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

import image from "@ohos.multimedia.image";
import resourceManager from "@ohos.resourceManager";
import { BusinessError } from '@kit.BasicServicesKit';
import { Context } from '@kit.AbilityKit';
import { NodeController, FrameNode, RenderNode, DrawContext } from "@ohos.arkui.node";
import { UIContext } from "@ohos.arkui.UIContext";
import testNapi from 'libndkDrawing.so';

enum DrawType { NONE, PATH, TEXT, IMAGE };

// 定义一个RenderNode自绘制渲染节点MyRenderNode，以便使用Native的接口进行绘制
class MyRenderNode extends RenderNode {
  private drawType: DrawType = DrawType.NONE;
  private pMap: image.PixelMap | undefined = undefined;
  draw(context: DrawContext) {
    // 调用Native侧的nativeOnDraw接口进行绘制，将背景图 this.pMap 和图形绘制上下文 context 作为参数传入
    testNapi.nativeOnDraw(666, context, vp2px(this.size.width), vp2px(this.size.height), this.drawType, this.pMap);
  }
  // 设置绘制类型
  resetType(type: DrawType) {
    this.drawType = type;
  }
  // 设置背景图
  setPixelMap(p: PixelMap) {
    this.pMap = p;
  }
}

// 创建一个 MyRenderNode 对象
const newNode = new MyRenderNode();
// 定义 newNode 的大小和位置
newNode.frame = {
  x: 0,
  y: 0,
  width: 980,
  height: 1280
};

// 将MyRenderNode对象节点挂载到NodeContainer上
class MyNodeController extends NodeController {
  private rootNode: FrameNode | null = null;

  makeNode(uiContext: UIContext): FrameNode | null {
    this.rootNode = new FrameNode(uiContext);
    if (this.rootNode === null) {
      return null;
    }
    const renderNode = this.rootNode.getRenderNode();
    if (renderNode !== null) {
      renderNode.appendChild(newNode);
    }
    return this.rootNode;
  }
}

@Entry
@Component
struct Index {
  private myNodeController: MyNodeController = new MyNodeController();

  aboutToAppear(): void {
    const context: Context = getContext(this);
    const resourceMgr: resourceManager.ResourceManager = context.resourceManager;
    resourceMgr.getRawFileContent('drawImage.png').then((fileData: Uint8Array) => {
      console.info('success in getRawFileContent');
      const buffer = fileData.buffer.slice(0);
      const imageSource: image.ImageSource = image.createImageSource(buffer);
      imageSource.createPixelMap().then((pMap: image.PixelMap) => {
        // 自绘制渲染节点背景图
        newNode.setPixelMap(pMap);

      }).catch((err: BusinessError) => {
        console.error('fail to create PixelMap');
      }).catch((err: BusinessError) => {
        console.error('fail to getRawFileContent');
      })
    })
  }

  build() {
    Column() {
      Row() {
        // 将自绘制渲染节点挂载到 NodeContainer
        NodeContainer(this.myNodeController)
          .height('100%')
      }
      .width('100%')
      .height('80%')

      Row() {
        Button('Draw Image')
          .margin({ bottom: 50, right: 12 })
          .onClick(() => {
            newNode.resetType(DrawType.IMAGE);
            newNode.invalidate();
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .shadow(ShadowStyle.OUTER_DEFAULT_SM)
      .alignItems(VerticalAlign.Bottom)
      .layoutWeight(1)
    }
  }
}
