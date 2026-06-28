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

#include "cmath"
#include "string"
#include "bits/alltypes.h"
#include "native_drawing/drawing_point.h"
#include "native_drawing/drawing_bitmap.h"
#include "native_drawing/drawing_color.h"
#include "native_drawing/drawing_color_filter.h"
#include "native_drawing/drawing_canvas.h"
#include "native_drawing/drawing_pen.h"
#include "native_drawing/drawing_pixel_map.h"
#include "native_drawing/drawing_brush.h"
#include "native_drawing/drawing_rect.h"
#include "native_drawing/drawing_font.h"
#include "native_drawing/drawing_path.h"
#include "native_drawing/drawing_register_font.h"
#include "native_drawing/drawing_filter.h"
#include "native_drawing/drawing_font_collection.h"
#include "native_drawing/drawing_text_blob.h"
#include "native_drawing/drawing_sampling_options.h"
#include "native_drawing/drawing_text_declaration.h"
#include "native_drawing/drawing_text_typography.h"
#include "native_drawing/drawing_types.h"
#include "native_drawing/drawing_typeface.h"
#include "multimedia/image_framework/image_mdk_common.h"
#include "multimedia/image_framework/image_mdk.h"
#include "multimedia/image_framework/image_pixel_map_mdk.h"
#include "napi/native_api.h"
#include "native_window/external_window.h"
#include "native_window/external_window.h"
#include "common/log_common.h"

enum DrawType { NONE, PATH, TEXT, IMAGE };
#define DRAW_MAX_NUM 1000

// 生成随机坐标
static int RangedRand(int range_min, int range_max) {
    int r = ((double)rand() / RAND_MAX) * (range_max - range_min) + range_min;
    return r;
}

// 空心圆圈与背景图融合场景绘制
static void NativeOnDrawPixelMap(OH_Drawing_Canvas *canvas, NativePixelMap *nativeMap) {
    // 画背景图
    OH_Drawing_CanvasSave(canvas);
    OH_Drawing_PixelMap *pixelMap = OH_Drawing_PixelMapGetFromNativePixelMap(nativeMap);
    // 创建采样选项对象
    OH_Drawing_SamplingOptions *sampling = OH_Drawing_SamplingOptionsCreate(FILTER_MODE_NEAREST, MIPMAP_MODE_NONE);
    // 获取背景图绘制区域
    OH_Drawing_Rect *src = OH_Drawing_RectCreate(0, 0, 360, 693);
    // 创建渲染区域
    OH_Drawing_Rect *dst = OH_Drawing_RectCreate(0, 0, 1300, 2500);
    // 创建画刷
    OH_Drawing_Brush *brush = OH_Drawing_BrushCreate();
    OH_Drawing_CanvasAttachBrush(canvas, brush);
    // 将背景图渲染到画布指定区域
    OH_Drawing_CanvasDrawPixelMapRect(canvas, pixelMap, src, dst, sampling);
    OH_Drawing_CanvasDetachBrush(canvas);

    // 调用分层接口
    OH_Drawing_CanvasSaveLayer(canvas, dst, brush);

    // 画蒙层
    OH_Drawing_Rect *rect2 = OH_Drawing_RectCreate(0, 0, 1300, 2500);
    OH_Drawing_Brush *brush2 = OH_Drawing_BrushCreate();
    // 设置画刷颜色
    OH_Drawing_BrushSetColor(brush2, OH_Drawing_ColorSetArgb(0x77, 0xCC, 0xCC, 0xCC));
    OH_Drawing_CanvasAttachBrush(canvas, brush2);
    OH_Drawing_CanvasDrawRect(canvas, rect2);
    OH_Drawing_CanvasDetachBrush(canvas);

    OH_Drawing_Point *pointArray[DRAW_MAX_NUM];
    int x = 0;
    int y = 0;
    for (int i = 0; i < DRAW_MAX_NUM; i++) {
        // 生成随机坐标
        x = RangedRand(0, 1300);
        y = RangedRand(0, 2500);
        pointArray[i] = OH_Drawing_PointCreate(x, y);
    }

    OH_Drawing_Point *point = OH_Drawing_PointCreate(800, 1750);
    OH_Drawing_Brush *brush3 = OH_Drawing_BrushCreate();
    // 设置圆圈的画刷和混合模式
    OH_Drawing_BrushSetBlendMode(brush3, BLEND_MODE_DST_OUT);
    OH_Drawing_CanvasAttachBrush(canvas, brush3);
    // 画圈
    for (int i = 0; i < DRAW_MAX_NUM; i++) {
        OH_Drawing_CanvasDrawCircle(canvas, pointArray[i], 15);
    }

    // 销毁对象
    OH_Drawing_CanvasDetachBrush(canvas);
    OH_Drawing_RectDestroy(rect2);
    OH_Drawing_BrushDestroy(brush2);
    OH_Drawing_BrushDestroy(brush3);
    OH_Drawing_PointDestroy(point);
    OH_Drawing_BrushDestroy(brush);
    OH_Drawing_CanvasRestore(canvas);
    OH_Drawing_SamplingOptionsDestroy(sampling);
    OH_Drawing_RectDestroy(src);
    OH_Drawing_RectDestroy(dst);
}

static napi_value OnDraw(napi_env env, napi_callback_info info) {
    size_t argc = 6;
    napi_value args[6] = {nullptr};

    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    int32_t id;
    napi_get_value_int32(env, args[0], &id);

    // 图形绘制上下文参数
    void *temp = nullptr;
    napi_unwrap(env, args[1], &temp);
    OH_Drawing_Canvas *canvas = reinterpret_cast<OH_Drawing_Canvas *>(temp);

    int32_t width;
    napi_get_value_int32(env, args[2], &width);

    int32_t height;
    napi_get_value_int32(env, args[3], &height);

    DRAWING_LOGI("OnDraw, width:%{public}d, helght:%{public}d", width, height);
    int32_t drawOption;
    napi_get_value_int32(env, args[4], &drawOption);
    // 背景图参数
    NativePixelMap *nativePixelMap = OH_PixelMap_InitNativePixelMap(env, args[5]);
    if (drawOption == IMAGE) {
        NativeOnDrawPixelMap(canvas, nativePixelMap);
    }
    return nullptr;
}

EXTERN_C_START
static napi_value Init(napi_env env, napi_value exports) {
    napi_property_descriptor desc[] = {
        {"nativeOnDraw", nullptr, OnDraw, nullptr, nullptr, nullptr, napi_default, nullptr}};
    napi_define_properties(env, exports, sizeof(desc) / sizeof(desc[0]), desc);
    return exports;
}
EXTERN_C_END

static napi_module demoModule = {
    .nm_version = 1,
    .nm_flags = 0,
    .nm_filename = nullptr,
    .nm_register_func = Init,
    .nm_modname = "ndkDrawing",
    .nm_priv = ((void *)0),
    .reserved = {0},
};

extern "C" __attribute__((constructor)) void RegisterEntryModule(void) { napi_module_register(&demoModule); }
