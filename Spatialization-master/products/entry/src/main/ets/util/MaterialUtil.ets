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
import { uiMaterial } from '@kit.ArkUI';
import { deviceInfo } from '@kit.BasicServicesKit';
import { hdsMaterial } from '@kit.UIDesignKit';

export class MaterialUtil {
  // [StartExclude immersive_menu]
  // [StartExclude immersive_dialog]
  public static getMaterialModifier(options: ModifierOptions): CommonModifier {
    if (deviceInfo.apiAvailable('26.0.0') && hdsMaterial.getSystemMaterialTypes().length > 0) {
      const materialOptions: uiMaterial.ImmersiveOptions = {
        style: uiMaterial.ImmersiveStyle.ULTRA_THIN,
        interactive: true,
        lightEffect: { color: undefined }
      }
      if (options.materialColor) {
        materialOptions.materialColor = options.materialColor;
      }
      options.modifier.systemMaterial(new uiMaterial.ImmersiveMaterial(materialOptions));
    } else {
      if (options.backgroundColor) {
        options.modifier.backgroundColor(options.backgroundColor);
      }
      if (options.backgroundBlurStyle) {
        options.modifier.backgroundBlurStyle(options.backgroundBlurStyle);
      }
    }
    return options.modifier;
  }
  // [EndExclude immersive_dialog]
  // [EndExclude immersive_menu]

  // [StartExclude immersive_button]
  public static getMaterialOptions<T>(option: T): MaterialOptions<T> | T {
    if (deviceInfo.apiAvailable('26.0.0') && hdsMaterial.getSystemMaterialTypes().length > 0) {
      const materialOptions = option as MaterialOptions<T>;
      materialOptions.systemMaterial = new uiMaterial.ImmersiveMaterial({
        style: uiMaterial.ImmersiveStyle.THICK,
        interactive: true,
        lightEffect: { color: undefined }
      });
      return materialOptions;
    }
    return option;
  }
  // [EndExclude immersive_button]
}

// [StartExclude immersive_button]
interface MaterialOptions<T> extends ThisType<T> {
  systemMaterial?: SystemUiMaterial;
}
// [EndExclude immersive_button]
// [End immersive_dialog]
// [End immersive_menu]

interface ModifierOptions {
  modifier: CommonModifier;
  style: CustomImmersiveStyle;
  backgroundColor?: ResourceColor;
  materialColor?: ResourceColor;
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