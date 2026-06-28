import {DrawContext } from "@ohos.arkui.node";
import image from "@ohos.multimedia.image";

export const nativeOnDraw: (id: number, context: DrawContext, width: number,height: number, type: number, imagePixel:image.PixelMap) => number;