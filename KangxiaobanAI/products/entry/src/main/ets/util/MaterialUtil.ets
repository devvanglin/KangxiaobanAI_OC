/*
 * Copyright (c) 2026 Huawei Device Co., Ltd.
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

// [Start immersive_button]
// [Start immersive_menu]
// [Start immersive_dialog]
import { hdsMaterial } from '@kit.UIDesignKit';

export class MaterialUtil {
  public static isMaterialSupported(): boolean {
    return hdsMaterial.getSystemMaterialTypes().length > 0;
  }

  public static getSystemMaterialEffectOptions(): SystemMaterialEffectOptions {
    return {
      materialType: hdsMaterial.MaterialType.ADAPTIVE,
      materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE,
      color: undefined
    };
  }

  public static applyFallbackBackground(modifier: CommonModifier, options: FallbackOptions): CommonModifier {
    if (options.backgroundColor) {
      modifier.backgroundColor(options.backgroundColor);
    }
    if (options.backgroundBlurStyle) {
      modifier.backgroundBlurStyle(options.backgroundBlurStyle);
    }
    return modifier;
  }
}

// [StartExclude immersive_button]
interface MaterialOptions<T> extends ThisType<T> {
  systemMaterialEffect?: SystemMaterialEffectOptions;
}

interface SystemMaterialEffectOptions {
  materialType: hdsMaterial.MaterialType;
  materialLevel: hdsMaterial.MaterialLevel;
  color?: ResourceColor;
}
// [EndExclude immersive_button]
// [End immersive_dialog]
// [End immersive_menu]

interface FallbackOptions {
  backgroundColor?: ResourceColor;
  backgroundBlurStyle?: BlurStyle;
}

export enum CustomImmersiveStyle {
  ULTRA_THIN = 0,
  THIN = 1,
  REGULAR = 2,
  THICK = 3,
  ULTRA_THICK = 4
}
// [End immersive_button]