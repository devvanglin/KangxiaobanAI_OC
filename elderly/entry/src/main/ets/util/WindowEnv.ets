import { UIContext, window } from '@kit.ArkUI';
import Logger from './Logger';

/**
 * 完全沉浸式窗口环境：与主工程 WindowUtil 已验证的链路一致——
 * 全屏布局 + 系统栏保持存在但背景全透明 + 内容色随底色，
 * 画布延伸到状态栏/导航条后面；安全区与键盘高度经 avoidAreaChange 实时更新。
 * 交互留白由页面按这些 vp 值自行处理。
 */
@ObservedV2
export class WindowEnv {
  private static instance?: WindowEnv;

  static get shared(): WindowEnv {
    if (!WindowEnv.instance) {
      WindowEnv.instance = new WindowEnv();
    }
    return WindowEnv.instance;
  }

  /** 顶部安全留白 = max(状态栏, 挖孔)，vp。 */
  @Trace statusBarHeight: number = 0;
  /** 底部导航指示条高度，vp。 */
  @Trace naviIndicatorHeight: number = 0;
  /** 键盘高度，vp；0 表示键盘收起。 */
  @Trace keyboardHeight: number = 0;

  private bound: boolean = false;
  private bindToken: number = 0;
  private systemBarHeight: number = 0;
  private cutoutHeight: number = 0;
  private readonly retryLimit: number = 20;
  private readonly retryDelayMs: number = 50;

  /** 在 onWindowStageCreate 的 loadContent 成功回调里调用。 */
  public bind(windowStage: window.WindowStage): void {
    const token: number = ++this.bindToken;
    this.tryBind(windowStage, token, 0);
  }

  /** 主窗口/UIContext 可能尚未就绪，按主工程同款重试模式等待。 */
  private tryBind(windowStage: window.WindowStage, token: number, attempt: number): void {
    try {
      const mainWindow: window.Window = windowStage.getMainWindowSync();
      const uiContext: UIContext = mainWindow.getUIContext();
      if (token !== this.bindToken || this.bound) { return; }
      this.bound = true;
      void this.applyImmersive(mainWindow);
      this.registerAvoidAreas(mainWindow, uiContext);
    } catch (err) {
      if (token === this.bindToken && attempt < this.retryLimit) {
        setTimeout((): void => {
          this.tryBind(windowStage, token, attempt + 1);
        }, this.retryDelayMs);
        return;
      }
      Logger.error('[WindowEnv]', `bind failed after retry: ${JSON.stringify(err)}`);
    }
  }

  /** 沉浸式链路（已验证组合）：全屏布局；系统栏保留但背景全透明；
   *  内容色取页面浅色底对应的深色，保证亮暗底都可读。 */
  private async applyImmersive(win: window.Window): Promise<void> {
    try {
      await win.setWindowLayoutFullScreen(true);
      await Promise.all([
        win.setSpecificSystemBarEnabled('status', true, false),
        win.setSpecificSystemBarEnabled('navigationIndicator', true, false),
        win.setWindowSystemBarProperties({
          statusBarColor: '#00000000',
          navigationBarColor: '#00000000',
          statusBarContentColor: '#1B2B4D',
          navigationBarContentColor: '#1B2B4D'
        })
      ]);
      Logger.info('[WindowEnv]', 'immersive mode applied');
    } catch (error) {
      Logger.error('[WindowEnv]', `applyImmersive failed: ${JSON.stringify(error)}`);
    }
  }

  private registerAvoidAreas(win: window.Window, uiContext: UIContext): void {
    const readInitial = (type: window.AvoidAreaType): void => {
      try {
        this.applyArea(type, win.getWindowAvoidArea(type), uiContext);
      } catch (_error) {
        // 窗口已释放等异常时序：安全区维持默认 0。
      }
    };
    readInitial(window.AvoidAreaType.TYPE_SYSTEM);
    readInitial(window.AvoidAreaType.TYPE_CUTOUT);
    readInitial(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
    readInitial(window.AvoidAreaType.TYPE_KEYBOARD);
    try {
      win.on('avoidAreaChange', (info: window.AvoidAreaOptions): void => {
        this.applyArea(info.type, info.area, uiContext);
      });
    } catch (_error) {
      // 监听失败仅影响旋转/键盘联动，初始值已就位。
    }
  }

  private applyArea(type: window.AvoidAreaType, area: window.AvoidArea, uiContext: UIContext): void {
    if (type === window.AvoidAreaType.TYPE_SYSTEM) {
      this.systemBarHeight = uiContext.px2vp(area?.topRect?.height ?? 0);
    } else if (type === window.AvoidAreaType.TYPE_CUTOUT) {
      this.cutoutHeight = uiContext.px2vp(area?.topRect?.height ?? 0);
    } else if (type === window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR) {
      this.naviIndicatorHeight = uiContext.px2vp(area?.bottomRect?.height ?? 0);
    } else if (type === window.AvoidAreaType.TYPE_KEYBOARD) {
      this.keyboardHeight = uiContext.px2vp(area?.bottomRect?.height ?? 0);
      return;
    } else {
      return;
    }
    this.statusBarHeight = Math.max(this.systemBarHeight, this.cutoutHeight);
  }
}
