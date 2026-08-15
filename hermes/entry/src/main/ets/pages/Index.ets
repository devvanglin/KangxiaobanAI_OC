import { HermesChatPage } from '../component/HermesChatPage';
import { HermesFeaturePage } from '../component/HermesFeaturePage';
import { HermesHistoryPage } from '../component/HermesHistoryPage';
import { HermesLoginPage } from '../component/HermesLoginPage';
import { HermesSidebar } from '../component/HermesSidebar';
import {
  hdsMaterial,
  HdsNavigation,
  HdsNavigationTitleBarOptions,
  HdsNavigationTitleMode,
  HdsSideBar,
  TitleSize
} from '@kit.UIDesignKit';
import { findNavItem, HERMES_SESSIONS } from '../data/HermesCatalog';
import { HermesHttpRepository } from '../data/HermesHttpRepository';
import {
  HermesLoginResult,
} from '../data/HermesRepository';
import { HermesRuntime } from '../data/HermesRuntime';
import { HermesAppModel, HermesChatModel, HermesNavItem } from '../model/HermesModels';

const HERMES_APP_MODEL: HermesAppModel = new HermesAppModel();
const HERMES_CHAT_MODEL: HermesChatModel = new HermesChatModel(HERMES_SESSIONS);
const HERMES_HISTORY_MODEL: HermesChatModel = new HermesChatModel(HERMES_SESSIONS);
const HERMES_RUNTIME: HermesRuntime = new HermesRuntime(new HermesHttpRepository());

@Entry
@ComponentV2
struct Index {
  @Local appModel: HermesAppModel = HERMES_APP_MODEL;
  @Local chatModel: HermesChatModel = HERMES_CHAT_MODEL;
  @Local historyModel: HermesChatModel = HERMES_HISTORY_MODEL;
  @Local runtime: HermesRuntime = HERMES_RUNTIME;
  @Local viewportWidth: number = 390;
  @Local viewportHeight: number = 844;
  private pathStack: NavPathStack = new NavPathStack();

  private lengthValue(value: Length): number {
    if (typeof value === 'number') {
      return value;
    }
    if (typeof value === 'string') {
      return parseFloat(value);
    }
    return 0;
  }

  private updateViewport(width: Length, height: Length): void {
    const nextWidth: number = this.lengthValue(width);
    const nextHeight: number = this.lengthValue(height);
    if (nextWidth > 0 && Math.abs(nextWidth - this.viewportWidth) > 0.5) {
      this.viewportWidth = nextWidth;
    }
    if (nextHeight > 0 && Math.abs(nextHeight - this.viewportHeight) > 0.5) {
      this.viewportHeight = nextHeight;
    }
  }

  private isWide(): boolean {
    return this.viewportWidth >= 720;
  }

  private usesSplitChat(): boolean {
    return this.viewportWidth >= 940;
  }

  private sidebarCollapsed(): boolean {
    return this.appModel.sidebarCollapsed || (this.viewportWidth >= 720 && this.viewportWidth < 940);
  }

  private currentItem(): HermesNavItem {
    return findNavItem(this.appModel.selectedFeature);
  }

  private navigationTitleBarOptions(): HdsNavigationTitleBarOptions {
    return {
      content: {
        title: {
          mainTitle: this.currentItem().title,
          subTitle: this.appModel.connectionMode === 'remote' ? this.appModel.activeProfile : '本地预览',
          mainTitleSize: TitleSize.TITLE_S,
          mainTitleAccessibilityText: this.currentItem().title,
          subTitleAccessibilityText: this.appModel.connectionMode === 'remote' ?
            `当前 Profile ${this.appModel.activeProfile}` : '当前为本地预览'
        },
        menu: {
          value: this.isWide() ? [] : [{
            content: {
              label: '打开主菜单',
              icon: $r('sys.symbol.line_3_horizontal'),
              action: (): void => {
                this.appModel.mobileMenuOpen = true;
              }
            }
          }],
          maxCount: this.isWide() ? 0 : 1
        }
      },
      style: {
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.IMMERSIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
        }
      }
    };
  }

  private selectFeature(key: string): void {
    this.appModel.selectedFeature = key;
    this.appModel.mobileMenuOpen = false;
  }

  private async login(serverUrl: string, userName: string, password: string, profile: string): Promise<string> {
    if (serverUrl.trim().length === 0) {
      this.runtime.clear();
      this.appModel.userName = userName;
      this.appModel.activeProfile = profile;
      this.appModel.connectionMode = 'preview';
      this.appModel.serverLabel = '本地预览';
      this.chatModel.usePreviewSessions(HERMES_SESSIONS);
      this.historyModel.usePreviewSessions(HERMES_SESSIONS);
      this.appModel.authenticated = true;
      return '';
    }
    const result: HermesLoginResult = await this.runtime.repository().login(serverUrl, userName, password, profile);
    if (!result.ok || result.session === null) {
      return result.message || '登录失败，请检查服务器地址和凭据';
    }
    this.runtime.activate(result.session);
    this.appModel.userName = userName;
    this.appModel.activeProfile = result.session.profile;
    this.appModel.connectionMode = 'remote';
    this.appModel.serverLabel = result.session.serverUrl;
    this.chatModel.beginRemoteSessionLoad();
    this.historyModel.beginRemoteSessionLoad();
    this.appModel.authenticated = true;
    this.runtime.loadSessions(this.chatModel);
    this.runtime.loadSessions(this.historyModel);
    return '';
  }

  private async loadRemoteSessions(): Promise<void> {
    await this.runtime.loadSessions(this.chatModel);
  }

  private selectSession(sessionId: string): void {
    this.runtime.selectSession(this.chatModel, sessionId);
  }

  private async loadRemoteMessages(sessionId: string): Promise<void> {
    await this.runtime.loadMessages(this.chatModel, sessionId);
  }

  private async sendMessage(model: HermesChatModel, content: string, timeLabel: string): Promise<void> {
    await this.runtime.sendMessage(model, content, timeLabel);
  }

  private async loadOlderMessages(model: HermesChatModel): Promise<number> {
    return await this.runtime.loadOlderMessages(model);
  }

  private async loadHistorySessions(): Promise<void> {
    await this.runtime.loadSessions(this.historyModel);
  }

  private async loadHistoryMessages(sessionId: string): Promise<void> {
    await this.runtime.loadMessages(this.historyModel, sessionId);
  }

  private selectHistorySession(sessionId: string): void {
    this.runtime.selectSession(this.historyModel, sessionId);
  }

  private logout(): void {
    this.runtime.clear();
    this.appModel.authenticated = false;
    this.appModel.mobileMenuOpen = false;
    this.appModel.connectionMode = 'preview';
    this.appModel.serverLabel = '本地预览';
    this.chatModel.resetSendingState();
    this.chatModel.usePreviewSessions(HERMES_SESSIONS);
    this.historyModel.resetSendingState();
    this.historyModel.usePreviewSessions(HERMES_SESSIONS);
  }

  @Builder
  private activeFeature() {
    if (this.appModel.selectedFeature === 'chat') {
      HermesChatPage({
        split: this.usesSplitChat(),
        model: this.chatModel,
        onSend: (model: HermesChatModel, content: string, timeLabel: string): Promise<void> =>
          this.sendMessage(model, content, timeLabel),
        onSelectSession: (sessionId: string) => this.selectSession(sessionId),
        onRetrySessions: () => this.loadRemoteSessions(),
        onRetryMessages: () => this.loadRemoteMessages(this.chatModel.activeSessionId),
        onLoadOlderMessages: (model: HermesChatModel): Promise<number> => this.loadOlderMessages(model),
        onSessionExpired: () => this.logout()
      })
    } else if (this.appModel.selectedFeature === 'history') {
      HermesHistoryPage({
        split: this.usesSplitChat(),
        outlinePane: this.viewportWidth >= 1240,
        model: this.historyModel,
        onSelectSession: (sessionId: string) => this.selectHistorySession(sessionId),
        onRetrySessions: () => this.loadHistorySessions(),
        onRetryMessages: () => this.loadHistoryMessages(this.historyModel.activeSessionId),
        onLoadOlderMessages: (model: HermesChatModel): Promise<number> => this.loadOlderMessages(model),
        onSessionExpired: () => this.logout(),
        onOpenChat: () => this.selectFeature('chat')
      })
    } else {
      HermesFeaturePage({ item: this.currentItem(), wide: this.isWide() })
    }
  }

  @Builder
  private sideBarPanel() {
    HermesSidebar({
      selectedKey: this.appModel.selectedFeature,
      collapsed: this.isWide() && this.sidebarCollapsed(),
      mobile: !this.isWide(),
      onSelect: (key: string) => this.selectFeature(key),
      onToggleCollapse: () => this.appModel.sidebarCollapsed = !this.appModel.sidebarCollapsed,
      onLogout: () => this.logout()
    })
  }

  @Builder
  private contentPanel() {
    Column() {
      this.activeFeature()
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.hermes_bg_primary'))
  }

  @Builder
  private authenticatedShell() {
    HdsNavigation(this.pathStack) {
      HdsSideBar({
        isShowSideBar: this.isWide() || this.appModel.mobileMenuOpen,
        $isShowSideBar: (isShown: boolean): void => {
          if (!this.isWide()) {
            this.appModel.mobileMenuOpen = isShown;
          }
        },
        minSideBarWidth: this.isWide() && this.sidebarCollapsed() ? 72 : 240,
        maxSideBarWidth: this.isWide() && this.sidebarCollapsed() ? 72 : 300,
        sideBarWidth: this.isWide() && this.sidebarCollapsed() ? 72 : (this.isWide() ? 240 : 300),
        minContentWidth: this.isWide() ? 480 : 280,
        contentAreaMask: !this.isWide(),
        sideBarColor: $r('app.color.hermes_bg_sidebar'),
        contentColor: $r('app.color.hermes_bg_primary'),
        autoHide: !this.isWide(),
        isSideBarBlur: false,
        sideBarPosition: SideBarPosition.Start,
        sideBarContainerType: this.isWide() ? SideBarContainerType.Embed : SideBarContainerType.Overlay,
        swipeEnabled: !this.isWide(),
        scaleContentEnabled: this.isWide(),
        sideBarPanelBuilder: () => {
          this.sideBarPanel()
        },
        contentPanelBuilder: () => {
          this.contentPanel()
        }
      })
      .padding({ top: 64 })
      .width('100%')
      .height('100%')
    }
    .mode(NavigationMode.Stack)
    .titleBar(this.navigationTitleBarOptions())
    .titleMode(HdsNavigationTitleMode.MINI)
    .hideBackButton(true)
    .backgroundColor($r('app.color.hermes_bg_primary'))
    .width('100%')
    .height('100%')
  }

  build() {
    Stack() {
      if (this.appModel.authenticated) {
        this.authenticatedShell()
      } else {
        HermesLoginPage({
          wide: this.isWide(),
          onLogin: (serverUrl: string, userName: string, password: string, profile: string): Promise<string> =>
            this.login(serverUrl, userName, password, profile)
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.hermes_bg_primary'))
    .onAreaChange((_oldValue: Area, newValue: Area) => {
      this.updateViewport(newValue.width, newValue.height);
    })
  }
}
