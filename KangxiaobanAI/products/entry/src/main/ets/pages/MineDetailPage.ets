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

import { AppStorageV2, SymbolGlyphModifier } from '@kit.ArkUI';
import { bundleManager, common, ConfigurationConstant } from '@kit.AbilityKit';
import type { BusinessError } from '@kit.BasicServicesKit';
import {
  HdsListItemCard,
  HdsNavDestination,
  HdsNavDestinationTitleMode,
  IconSize,
  PrefixIcon,
  ScrollEffectType,
  SuffixArrow,
  SuffixText,
  TitleBarStyleOptions,
  hdsMaterial
} from '@kit.UIDesignKit';
import Logger from '../util/Logger';
import { PreferenceManager } from '../util/PreferenceManager';
import { GlobalInfoModel } from '../model/GlobalInfoModel';
import { StorageKey } from '../common/CommonConstants';
import ApiClient from '../network/ApiClient';
import { ApiResp } from '../network/Dto';

export type MineDetailType = 'about' | 'general' | 'article';

export class AboutArticleSection {
  heading: string = '';
  paragraphs: string[] = [];
}

export class AboutArticle {
  id: string = '';
  title: string = '';
  updated: string = '';
  intro: string = '';
  sections: AboutArticleSection[] = [];
}

function buildAboutArticle(id: string): AboutArticle {
  const article: AboutArticle = new AboutArticle();
  article.id = id;
  article.updated = '2026-09-08';
  if (id === 'product_intro') {
    article.title = '产品介绍';
    article.intro = '康小伴 AI 是面向养老护理机构的一体化工作助手，把长者档案、护理任务、体征趋势、房间设备和沟通消息集中在一个工作台，并用 AI 帮助护理人员整理信息、起草沟通内容。';
    const s1: AboutArticleSection = new AboutArticleSection();
    s1.heading = '产品定位';
    s1.paragraphs = [
      '康小伴 AI 服务于机构内的护理工作场景，主要使用者是护理员、医师与管理员。产品提供的是工作辅助与信息整理能力，不构成医疗诊断，也不替代护理规范和紧急处置流程。'
    ];
    article.sections.push(s1);
    const s2: AboutArticleSection = new AboutArticleSection();
    s2.heading = '核心功能';
    s2.paragraphs = [
      '长者档案与健康概览：集中查看长者的基础信息、护理计划、体征趋势、用药记录与联系人。',
      '任务与交接：按班次查看今日护理任务、完成情况与重点关注事项，支持交接提醒。',
      '体征与设备：接入房间设备的在线状态与上报数据，呈现心率、呼吸、血压等趋势与测量记录。',
      '消息协作：机构内消息沟通与通知，重要状态变化及时触达对应人员。',
      '康小伴 AI 助手：以对话方式汇总当日重点照护事项、解读健康指标变化、协助安排护理优先级。'
    ];
    article.sections.push(s2);
    const s3: AboutArticleSection = new AboutArticleSection();
    s3.heading = '适用角色';
    s3.paragraphs = [
      '护理员端聚焦长者列表、任务执行与消息；医师与管理端在同一管理工作台上查看长者详情、床位、任务、告警与运营数据。不同角色可见范围由机构授权决定。'
    ];
    article.sections.push(s3);
  } else if (id === 'user_agreement') {
    article.title = '用户协议';
    article.intro = '使用康小伴 AI 前，请仔细阅读本协议。登录或使用本应用即表示您已理解并同意本协议的全部内容。本协议为产品内简要说明，正式协议文本以机构签署文件与正式发布版本为准。';
    const s1: AboutArticleSection = new AboutArticleSection();
    s1.heading = '账号与身份';
    s1.paragraphs = [
      '本应用的账号由所在机构创建和授权。您应使用本人账号登录，妥善保管账号密码，不得出借、共享或冒用他人身份。发现账号异常时应立即通知机构管理员。'
    ];
    article.sections.push(s1);
    const s2: AboutArticleSection = new AboutArticleSection();
    s2.heading = '数据录入与真实性';
    s2.paragraphs = [
      '您通过本应用录入的长者信息、护理记录、体征与设备数据应真实、准确、及时。因录入错误或延迟更新导致的业务影响，由录入责任方按机构制度处理。'
    ];
    article.sections.push(s2);
    const s3: AboutArticleSection = new AboutArticleSection();
    s3.heading = 'AI 输出的使用限制';
    s3.paragraphs = [
      'AI 生成内容仅用于信息整理与工作建议，可能存在遗漏或偏差。涉及健康、安全、用药和紧急事件的判断与处置，必须由具备资质的工作人员核验后按机构制度执行，不得将 AI 输出直接替代专业判断。'
    ];
    article.sections.push(s3);
    const s4: AboutArticleSection = new AboutArticleSection();
    s4.heading = '设备与网络';
    s4.paragraphs = [
      '本应用依赖机构网络与设备环境。网络中断或设备故障可能导致数据延迟同步，请在恢复后核对重要记录的状态。'
    ];
    article.sections.push(s4);
    const s5: AboutArticleSection = new AboutArticleSection();
    s5.heading = '知识产权与责任限制';
    s5.paragraphs = [
      '本应用的软件、界面与文档归权利人所有，未经许可不得复制、逆向或对外传播。在法律允许的最大范围内，开发方不对因不可抗力、机构网络环境或第三方服务导致的间接损失承担责任。'
    ];
    article.sections.push(s5);
    const s6: AboutArticleSection = new AboutArticleSection();
    s6.heading = '协议变更与终止';
    s6.paragraphs = [
      '产品功能与本协议可能随版本更新调整，重要变更将在应用内提示。账号被机构停用或您不再符合使用条件时，相关授权即终止。'
    ];
    article.sections.push(s6);
  } else if (id === 'privacy_policy') {
    article.title = '隐私政策';
    article.intro = '康小伴 AI 仅在提供养老护理工作功能所必需的范围内处理信息。本政策说明信息的收集、使用、存储与保护方式。正式隐私政策文本以机构签署文件与正式发布版本为准。';
    const s1: AboutArticleSection = new AboutArticleSection();
    s1.heading = '我们收集的信息';
    s1.paragraphs = [
      '账号信息：登录账号、姓名、角色与机构归属，用于身份识别与权限控制。',
      '业务数据：长者档案、护理记录、体征与设备数据、消息内容，用于实现对应工作功能。',
      '设备与运行信息：设备型号、系统版本与应用运行状态，用于保障稳定运行和问题排查。'
    ];
    article.sections.push(s1);
    const s2: AboutArticleSection = new AboutArticleSection();
    s2.heading = '信息的使用';
    s2.paragraphs = [
      '收集的信息仅用于提供和改进本应用的工作功能，包括身份认证、业务记录、消息触达与 AI 辅助整理。我们不会将业务数据用于广告或与工作功能无关的用途。'
    ];
    article.sections.push(s2);
    const s3: AboutArticleSection = new AboutArticleSection();
    s3.heading = '存储与保护';
    s3.paragraphs = [
      '业务数据按机构配置存储在机构指定的服务环境中，传输过程采用加密保护。健康、身份、联系方式和护理记录属于敏感信息，按最小必要原则访问，操作留有审计记录。'
    ];
    article.sections.push(s3);
    const s4: AboutArticleSection = new AboutArticleSection();
    s4.heading = '共享与披露';
    s4.paragraphs = [
      '除法律法规要求或机构明确授权外，我们不会向第三方共享、出售或对外披露业务数据。AI 处理所依赖的服务配置由机构管理员管理。'
    ];
    article.sections.push(s4);
    const s5: AboutArticleSection = new AboutArticleSection();
    s5.heading = '您的权利';
    s5.paragraphs = [
      '您可以在权限范围内查看、更正与自己工作相关的记录。对个人信息的查询、更正或删除请求，请通过机构管理员提交，我们将按机构制度与法律法规处理。'
    ];
    article.sections.push(s5);
    const s6: AboutArticleSection = new AboutArticleSection();
    s6.heading = '政策更新';
    s6.paragraphs = [
      '本政策可能随产品与法规变化更新，重要变更将在应用内提示后生效。'
    ];
    article.sections.push(s6);
  } else if (id === 'ai_data_usage') {
    article.title = 'AI 功能与数据使用说明';
    article.intro = '康小伴 AI 的对话与整理能力用于辅助护理工作。本说明帮助您了解哪些数据会参与 AI 处理、生成内容的边界以及使用时的注意事项。';
    const s1: AboutArticleSection = new AboutArticleSection();
    s1.heading = '功能范围';
    s1.paragraphs = [
      '当前 AI 能力包括：汇总当日重点照护事项、解读健康指标变化趋势、协助安排护理优先级、起草沟通内容。功能范围可能随版本更新扩展。'
    ];
    article.sections.push(s1);
    const s2: AboutArticleSection = new AboutArticleSection();
    s2.heading = '数据如何参与处理';
    s2.paragraphs = [
      '当您使用 AI 功能时，与请求相关的长者状态、体征记录和任务信息会作为上下文提交给已配置的 AI 服务进行处理。对话记录按租户与账号保存，用于延续会话和历史查询。'
    ];
    article.sections.push(s2);
    const s3: AboutArticleSection = new AboutArticleSection();
    s3.heading = '生成内容的边界';
    s3.paragraphs = [
      'AI 生成内容基于已有数据的整理与推断，可能存在遗漏、滞后或偏差。涉及用药调整、跌倒处置、紧急呼救等场景时，必须以现场评估和机构制度为准，由具备资质的工作人员核验后执行。'
    ];
    article.sections.push(s3);
    const s4: AboutArticleSection = new AboutArticleSection();
    s4.heading = '数据留存与删除';
    s4.paragraphs = [
      'AI 对话记录与业务数据一致，按机构的数据管理策略保存和删除。删除对话记录不会自动删除其引用的业务数据。'
    ];
    article.sections.push(s4);
  } else {
    article.title = '开源软件声明';
    article.intro = '本应用在开发过程中使用了开源软件组件。我们尊重开源社区的贡献，并按照各组件的开源许可证要求使用与发布。';
    const s1: AboutArticleSection = new AboutArticleSection();
    s1.heading = '使用范围';
    s1.paragraphs = [
      '本应用基于 HarmonyOS SDK 与相关开发框架构建，并使用了构建与开发过程中引入的第三方开源组件。各组件的著作权归其原作者与贡献者所有。'
    ];
    article.sections.push(s1);
    const s2: AboutArticleSection = new AboutArticleSection();
    s2.heading = '许可证遵循';
    s2.paragraphs = [
      '所有引入的开源组件均按其原始许可证（如 Apache License 2.0、MIT 等宽松许可证）使用。相应许可证文本与版权声明将随正式发布版本一并提供。'
    ];
    article.sections.push(s2);
    const s3: AboutArticleSection = new AboutArticleSection();
    s3.heading = '完整清单获取';
    s3.paragraphs = [
      '完整的开源组件、版本、版权信息与许可证清单将随正式发布版本的安装包与文档提供。如需提前获取，请通过机构管理员联系我们。'
    ];
    article.sections.push(s3);
  }
  return article;
}

const TAG: string = '[MineDetailPage]';

export type AppearanceMode = 'system' | 'light' | 'dark';
export type FontSizeMode = 'system' | 'small' | 'standard' | 'large' | 'xlarge';
export type AppLanguageMode = 'system' | 'zh-CN' | 'en-US';

const FONT_SCALE_SMALL: number = 0.85;
const FONT_SCALE_STANDARD: number = 1.0;
const FONT_SCALE_LARGE: number = 1.15;
const FONT_SCALE_XLARGE: number = 1.3;

interface ServerVersionData {
  version: string;
}

@ComponentV2
struct SettingsGroupCard {
  @BuilderParam @Require content: () => void;

  build() {
    Column({ space: 0 }) {
      this.content()
    }
    .width('100%')
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(16)
    .clip(true)
    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
  }
}

@ComponentV2
export struct MineDetailPage {
  @Param @Require pageType: MineDetailType;
  @Param articleId: string = '';
  @Param onOpenArticle: (id: string) => void = (id: string) => {
  };
  @Local globalInfoModel: GlobalInfoModel =
    AppStorageV2.connect(GlobalInfoModel, StorageKey.GLOBAL_INFO, () => new GlobalInfoModel()) ?? new GlobalInfoModel();
  @Local versionName: string = '1.0.0';
  @Local versionCode: number = 1000000;
  @Local serverVersion: string = '';
  @Local appearanceMode: AppearanceMode = 'system';
  @Local fontSizeMode: FontSizeMode = 'system';
  @Local appLanguageMode: AppLanguageMode = 'system';
  @Local isSelectionSheetOpen: boolean = false;
  @Local selectionSheetTitle: string = '';
  @Local selectionOptions: string[] = [];
  @Local selectionValues: string[] = [];
  @Local selectionSelectedValue: string = '';
  private currentArticle: AboutArticle = new AboutArticle();
  private selectionPickHandler: ((value: string) => void) | null = null;
  private scroller: Scroller = new Scroller();
  private preferenceManager: PreferenceManager = PreferenceManager.getInstance();

  aboutToAppear(): void {
    this.loadBundleInfo();
    this.loadServerVersion();
    if (this.pageType === 'article') {
      this.currentArticle = buildAboutArticle(this.articleId);
    }
    this.appearanceMode = this.readString(StorageKey.GENERAL_APPEARANCE, 'system') as AppearanceMode;
    this.fontSizeMode = this.readString(StorageKey.GENERAL_FONT_SIZE, 'system') as FontSizeMode;
    this.appLanguageMode = this.readString(StorageKey.GENERAL_APP_LANGUAGE, 'system') as AppLanguageMode;
  }

  private async loadBundleInfo(): Promise<void> {
    try {
      const info: bundleManager.BundleInfo = await bundleManager.getBundleInfoForSelf(
        bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION
      );
      this.versionName = info.versionName;
      this.versionCode = info.versionCode;
    } catch (err) {
      const error: BusinessError = err as BusinessError;
      Logger.error(TAG, `load bundle info failed: ${error.code}, ${error.message}`);
    }
  }

  /** 服务端版本号：来自 /api/v1/app-info，加载失败时回退到本地包版本。 */
  private async loadServerVersion(): Promise<void> {
    try {
      const response: ApiResp<ServerVersionData> = await ApiClient.get<ServerVersionData>('/app-info');
      const version: string = response.data?.version ?? '';
      if (response.code === 0 && version.length > 0) {
        this.serverVersion = version;
      }
    } catch (err) {
      Logger.warn(TAG, `load server version failed: ${err instanceof Error ? err.message : JSON.stringify(err)}`);
    }
  }

  private displayVersion(): string {
    return this.serverVersion.length > 0 ? this.serverVersion : this.versionName;
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message });
    } catch (err) {
      Logger.error(TAG, `show toast failed: ${JSON.stringify(err)}`);
    }
  }

  private pageTitle(): string {
    if (this.pageType === 'about') {
      return '关于我们';
    }
    if (this.pageType === 'article') {
      return this.currentArticle.title.length > 0 ? this.currentArticle.title : '详情';
    }
    return '通用设置';
  }

  private readString(key: string, fallback: string): string {
    return this.preferenceManager.getValue<string>(key, JSON.stringify(fallback)) ?? fallback;
  }

  private saveString(key: string, value: string): void {
    this.preferenceManager.setValue<string>(key, value);
  }

  private applicationContext(): common.ApplicationContext | undefined {
    try {
      return this.getUIContext().getHostContext()?.getApplicationContext();
    } catch (err) {
      Logger.error(TAG, `get application context failed: ${JSON.stringify(err)}`);
      return undefined;
    }
  }

  private applyAppearance(mode: AppearanceMode): void {
    const appContext: common.ApplicationContext | undefined = this.applicationContext();
    if (!appContext) {
      return;
    }
    try {
      if (mode === 'light') {
        appContext.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
      } else if (mode === 'dark') {
        appContext.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
      } else {
        appContext.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
      }
    } catch (err) {
      Logger.error(TAG, `apply appearance failed: ${JSON.stringify(err)}`);
    }
  }

  private applyFontSize(mode: FontSizeMode): void {
    const appContext: common.ApplicationContext | undefined = this.applicationContext();
    if (!appContext) {
      return;
    }
    try {
      if (mode === 'small') {
        appContext.setFontSizeScale(FONT_SCALE_SMALL);
      } else if (mode === 'standard') {
        appContext.setFontSizeScale(FONT_SCALE_STANDARD);
      } else if (mode === 'large') {
        appContext.setFontSizeScale(FONT_SCALE_LARGE);
      } else if (mode === 'xlarge') {
        appContext.setFontSizeScale(FONT_SCALE_XLARGE);
      } else {
        appContext.setFontSizeScale(FONT_SCALE_STANDARD);
      }
    } catch (err) {
      Logger.error(TAG, `apply font size failed: ${JSON.stringify(err)}`);
    }
  }

  private applyAppLanguage(mode: AppLanguageMode): void {
    const appContext: common.ApplicationContext | undefined = this.applicationContext();
    if (!appContext) {
      return;
    }
    try {
      appContext.setLanguage(mode === 'en-US' ? 'en-US' : (mode === 'zh-CN' ? 'zh-CN' : ''));
    } catch (err) {
      Logger.error(TAG, `apply app language failed: ${JSON.stringify(err)}`);
    }
  }

  private appearanceLabel(): string {
    if (this.appearanceMode === 'light') {
      return '浅色';
    }
    if (this.appearanceMode === 'dark') {
      return '深色';
    }
    return '跟随系统';
  }

  private fontSizeLabel(): string {
    if (this.fontSizeMode === 'small') {
      return '小';
    }
    if (this.fontSizeMode === 'standard') {
      return '标准';
    }
    if (this.fontSizeMode === 'large') {
      return '大';
    }
    if (this.fontSizeMode === 'xlarge') {
      return '特大';
    }
    return '跟随系统';
  }

  private appLanguageLabel(): string {
    if (this.appLanguageMode === 'en-US') {
      return 'English';
    }
    if (this.appLanguageMode === 'zh-CN') {
      return '简体中文';
    }
    return '跟随系统';
  }

  private openSelectionSheet(title: string, values: string[], labels: string[], selectedValue: string,
    onPick: (value: string) => void): void {
    this.selectionSheetTitle = title;
    this.selectionValues = values;
    this.selectionOptions = labels;
    this.selectionSelectedValue = selectedValue;
    this.selectionPickHandler = onPick;
    this.isSelectionSheetOpen = true;
  }

  private pickSelectionOption(index: number): void {
    this.isSelectionSheetOpen = false;
    const handler: ((value: string) => void) | null = this.selectionPickHandler;
    this.selectionPickHandler = null;
    if (index < 0 || index >= this.selectionValues.length || handler === null) {
      return;
    }
    handler(this.selectionValues[index]);
  }

  private chooseAppearance(value: string): void {
    this.appearanceMode = value as AppearanceMode;
    this.saveString(StorageKey.GENERAL_APPEARANCE, value);
    this.applyAppearance(this.appearanceMode);
  }

  private chooseFontSize(value: string): void {
    this.fontSizeMode = value as FontSizeMode;
    this.saveString(StorageKey.GENERAL_FONT_SIZE, value);
    this.applyFontSize(this.fontSizeMode);
  }

  private chooseAppLanguage(value: string): void {
    this.appLanguageMode = value as AppLanguageMode;
    this.saveString(StorageKey.GENERAL_APP_LANGUAGE, value);
    this.applyAppLanguage(this.appLanguageMode);
  }

  private resetGeneralSettings(): void {
    this.chooseAppearance('system');
    this.chooseFontSize('system');
    this.chooseAppLanguage('system');
    this.showToast('已恢复默认设置');
  }

  private confirmResetGeneralSettings(): void {
    try {
      this.getUIContext().showAlertDialog({
        title: '恢复默认设置',
        message: '将把外观模式、字体大小和应用语言恢复为跟随系统，不会删除账号、消息、护理记录或长者数据。',
        autoCancel: true,
        alignment: DialogAlignment.Center,
        buttonDirection: DialogButtonDirection.HORIZONTAL,
        buttons: [
          {
            value: '取消',
            action: () => {
            }
          },
          {
            value: '恢复',
            fontColor: $r('app.color.status_danger'),
            action: () => {
              this.resetGeneralSettings();
            }
          }
        ]
      });
    } catch (err) {
      Logger.error(TAG, `show reset dialog failed: ${JSON.stringify(err)}`);
    }
  }

  private titleBarStyle(): TitleBarStyleOptions {
    return {
      systemMaterialEffect: {
        materialType: hdsMaterial.MaterialType.IMMERSIVE,
        materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
      },
      scrollEffectOpts: {
        enableScrollEffect: true,
        scrollEffectType: ScrollEffectType.GRADIENT_BLUR
      }
    };
  }

  private openInfoSheet(title: string, content: string): void {
    this.onOpenArticle(content.length > 0 ? content : title);
  }
  @Builder
  private sectionTitle(title: string) {
    Text(title)
      .fontSize($r('sys.float.Body_S'))
      .fontWeight(FontWeight.Medium)
      .fontColor($r('sys.color.font_secondary'))
      .width('100%')
      .padding({ left: 4, bottom: 8 })
  }

  @Builder
  private divider(isLast: boolean) {
    if (!isLast) {
      Divider()
        .strokeWidth(0.5)
        .color($r('sys.color.comp_divider'))
        .margin({ left: 52 })
    }
  }

  @Builder
  private infoRow(icon: Resource, title: string, value: string, isLast: boolean) {
    Column({ space: 0 }) {
      HdsListItemCard({
        prefixItem: new PrefixIcon({
          iconSize: IconSize.SYSTEM_ICON,
          iconValue: {
            symbol: new SymbolGlyphModifier(icon)
              .fontColor([$r('sys.color.font_primary')])
          }
        }),
        textItem: {
          primaryText: { text: title }
        },
        suffixItem: new SuffixText({ text: value }),
        cardBorderRadius: 0,
        cardBackgroundColor: $r('sys.color.ohos_id_color_background_transparent'),
        cardHeight: 54,
        cardPrefixMargin: 0,
        cardSuffixMargin: 0,
        hoverBorderRadius: 0
      })
      this.divider(isLast)
    }
    .width('100%')
    .padding({ left: 16, right: 16 })
  }

  @Builder
  private linkRow(icon: Resource, title: string, isLast: boolean, action: () => void) {
    Column({ space: 0 }) {
      HdsListItemCard({
        prefixItem: new PrefixIcon({
          iconSize: IconSize.SYSTEM_ICON,
          iconValue: {
            symbol: new SymbolGlyphModifier(icon)
              .fontColor([$r('sys.color.font_primary')])
          }
        }),
        textItem: {
          primaryText: { text: title }
        },
        suffixItem: new SuffixArrow({ color: $r('sys.color.font_tertiary') }),
        cardBorderRadius: 0,
        cardBackgroundColor: $r('sys.color.ohos_id_color_background_transparent'),
        cardHeight: 54,
        cardPrefixMargin: 0,
        cardSuffixMargin: 0,
        hoverBorderRadius: 0
      })
      this.divider(isLast)
    }
    .width('100%')
    .padding({ left: 16, right: 16 })
    .focusable(true)
    .focusOnTouch(true)
    .onClick(action)
  }

  @Builder
  private aboutHero() {
    Column({ space: 8 }) {
      Text('康小伴 AI')
        .fontSize($r('sys.float.Title_L'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_primary'))
      Text('养老护理工作助手')
        .fontSize($r('sys.float.Body_M'))
        .fontColor($r('sys.color.font_secondary'))
      Text(`版本 ${this.displayVersion()}`)
        .fontSize($r('sys.float.Caption_M'))
        .fontColor($r('sys.color.font_tertiary'))
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private aboutContent() {
    this.aboutHero()

    Column({ space: 0 }) {
      this.sectionTitle('版本与产品')
      SettingsGroupCard({ content: () => {
        this.infoRow($r('sys.symbol.info_circle'), '版本信息', `${this.displayVersion()}（构建 ${this.versionCode}）`, false)
        this.linkRow($r('sys.symbol.AI_message'), '产品介绍', true, () => {
          this.openInfoSheet('产品介绍', 'product_intro');
        })
      } })
    }
    .width('100%')

    Column({ space: 0 }) {
      this.sectionTitle('隐私与法律')
      SettingsGroupCard({ content: () => {
        this.linkRow($r('sys.symbol.doc_text'), '用户协议', false, () => {
          this.openInfoSheet('用户协议', 'user_agreement');
        })
        this.linkRow($r('sys.symbol.shield_checkered'), '隐私政策', false, () => {
          this.openInfoSheet('隐私政策', 'privacy_policy');
        })
        this.linkRow($r('sys.symbol.AI_message'), 'AI 功能与数据使用说明', false, () => {
          this.openInfoSheet('AI 功能与数据使用说明', 'ai_data_usage');
        })
        this.linkRow($r('sys.symbol.doc_text'), '开源软件声明', true, () => {
          this.openInfoSheet('开源软件声明', 'oss_notice');
        })
      } })
    }
    .width('100%')
  }

  @Builder
  private articleContent() {
    Column({ space: 18 }) {
      Column({ space: 6 }) {
        Text(this.currentArticle.title)
          .fontSize($r('sys.float.Title_L'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_primary'))
          .textAlign(TextAlign.Center)
          .width('100%')
        Text(`更新日期 ${this.currentArticle.updated}`)
          .fontSize($r('sys.float.Caption_M'))
          .fontColor($r('sys.color.font_tertiary'))
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)

      if (this.currentArticle.intro.length > 0) {
        Text(this.currentArticle.intro)
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('sys.color.font_secondary'))
          .lineHeight(26)
          .width('100%')
          .padding({ left: 4, right: 4 })
      }

      ForEach(this.currentArticle.sections, (section: AboutArticleSection) => {
        Column({ space: 10 }) {
          Text(section.heading)
            .fontSize($r('sys.float.Subtitle_M'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
          ForEach(section.paragraphs, (paragraph: string) => {
            Text(paragraph)
              .fontSize($r('sys.float.Body_M'))
              .fontColor($r('sys.color.font_secondary'))
              .lineHeight(26)
              .width('100%')
          }, (paragraph: string, index: number) => `${section.heading}_${index}`)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding(18)
        .backgroundColor($r('sys.color.comp_background_primary'))
        .borderRadius(16)
        .border({ width: 0.5, color: $r('sys.color.comp_divider') })
      }, (section: AboutArticleSection) => `${this.currentArticle.id}_${section.heading}`)
    }
    .width('100%')
  }

  @Builder
  private selectionRow(icon: Resource, title: string, value: string, isLast: boolean, action: () => void) {
    Column({ space: 0 }) {
      HdsListItemCard({
        prefixItem: new PrefixIcon({
          iconSize: IconSize.SYSTEM_ICON,
          iconValue: {
            symbol: new SymbolGlyphModifier(icon)
              .fontColor([$r('sys.color.font_primary')])
          }
        }),
        textItem: {
          primaryText: { text: title }
        },
        suffixItem: new SuffixText({ text: value }),
        cardBorderRadius: 0,
        cardBackgroundColor: $r('sys.color.ohos_id_color_background_transparent'),
        cardHeight: 54,
        cardPrefixMargin: 0,
        cardSuffixMargin: 0,
        hoverBorderRadius: 0
      })
      this.divider(isLast)
    }
    .width('100%')
    .padding({ left: 16, right: 16 })
    .focusable(true)
    .focusOnTouch(true)
    .onClick(action)
  }

  @Builder
  private selectionSheetBuilder() {
    Column({ space: 0 }) {
      ForEach(this.selectionOptions, (label: string, index: number) => {
        Row({ space: 12 }) {
          Text(label)
            .fontSize($r('sys.float.Body_L'))
            .fontColor(index >= 0 && this.selectionValues[index] === this.selectionSelectedValue ?
              $r('app.color.brand_blue') : $r('sys.color.font_primary'))
            .layoutWeight(1)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          if (this.selectionValues[index] === this.selectionSelectedValue) {
            SymbolGlyph($r('sys.symbol.checkmark'))
              .fontSize(20)
              .fontColor([$r('app.color.brand_blue')])
          }
        }
        .width('100%')
        .height(52)
        .padding({ left: 20, right: 20 })
        .alignItems(VerticalAlign.Center)
        .onClick(() => {
          this.pickSelectionOption(index);
        })
      }, (label: string, index: number) => `${this.selectionSheetTitle}_${index}_${label}`)
    }
    .width('100%')
    .padding({ top: 8, bottom: 24 })
    .backgroundColor($r('sys.color.background_secondary'))
  }

  @Builder
  private generalContent() {
    Column({ space: 0 }) {
      this.sectionTitle('显示')
      SettingsGroupCard({ content: () => {
        this.selectionRow($r('sys.symbol.paintpalette'), '外观模式', this.appearanceLabel(), false, () => {
          this.openSelectionSheet('外观模式', ['system', 'light', 'dark'], ['跟随系统', '浅色', '深色'],
            this.appearanceMode, (value: string) => this.chooseAppearance(value));
        })
        this.selectionRow($r('sys.symbol.doc_text'), '字体大小', this.fontSizeLabel(), true, () => {
          this.openSelectionSheet('字体大小', ['system', 'small', 'standard', 'large', 'xlarge'],
            ['跟随系统', '小', '标准', '大', '特大'], this.fontSizeMode,
            (value: string) => this.chooseFontSize(value));
        })
      } })
    }
    .width('100%')

    Column({ space: 0 }) {
      this.sectionTitle('语言')
      SettingsGroupCard({ content: () => {
        this.selectionRow($r('sys.symbol.doc_text'), '应用语言', this.appLanguageLabel(), true, () => {
          this.openSelectionSheet('应用语言', ['system', 'zh-CN', 'en-US'], ['跟随系统', '简体中文', 'English'],
            this.appLanguageMode, (value: string) => this.chooseAppLanguage(value));
        })
      } })
    }
    .width('100%')

    Row() {
      SymbolGlyph($r('sys.symbol.arrow_clockwise'))
        .fontSize(20)
        .fontColor([$r('app.color.status_danger')])
      Text('恢复默认设置')
        .fontSize($r('sys.float.Body_L'))
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.status_danger'))
        .margin({ left: 12 })
      Blank()
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16 })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(16)
    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
    .focusable(true)
    .focusOnTouch(true)
    .onClick(() => {
      this.confirmResetGeneralSettings();
    })

    Text('设置保存在当前设备。外观模式、字体大小与应用语言设置立即生效。')
      .fontSize($r('sys.float.Caption_M'))
      .fontColor($r('sys.color.font_tertiary'))
      .width('100%')
      .padding({ left: 4, right: 4 })
  }

  build() {
    HdsNavDestination() {
      Scroll(this.scroller) {
        Row() {
          Column({ space: 18 }) {
            if (this.pageType === 'about') {
              this.aboutContent()
            } else if (this.pageType === 'article') {
              this.articleContent()
            } else {
              this.generalContent()
            }
          }
          .width('100%')
          .constraintSize({ maxWidth: 720 })
          .padding({
            left: 16,
            right: 16,
            top: this.globalInfoModel.statusBarHeight + 56,
            bottom: 40 + this.globalInfoModel.naviIndicatorHeight
          })
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .bindSheet(this.isSelectionSheetOpen, this.selectionSheetBuilder, {
          detents: [SheetSize.FIT_CONTENT],
          showClose: false,
          dragBar: false,
          title: { title: this.selectionSheetTitle },
          backgroundColor: $r('sys.color.background_secondary'),
          onDisappear: () => {
            this.isSelectionSheetOpen = false;
            this.selectionPickHandler = null;
          }
        })
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .hideBackButton(false)
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .titleBar({
      avoidLayoutSafeArea: true,
      content: {
        title: { mainTitle: this.pageTitle() }
      },
      style: this.titleBarStyle()
    })
    .bindToScrollable([this.scroller])
    .backgroundColor($r('sys.color.background_secondary'))
    .ignoreLayoutSafeArea(
      [LayoutSafeAreaType.SYSTEM],
      [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM]
    )
  }
}
