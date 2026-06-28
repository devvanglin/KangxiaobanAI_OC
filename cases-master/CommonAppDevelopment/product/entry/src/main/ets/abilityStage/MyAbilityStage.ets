import AbilityStage from '@ohos.app.ability.AbilityStage';
import { preInit, InternalPlugin, setLogEnabled, init, onEventObject } from '@umeng/analytics';
import { ApmPlugin } from '@umeng/apm';
import { BusinessError, emitter } from '@kit.BasicServicesKit';
import { bundleManager } from '@kit.AbilityKit';


export default class MyAbilityStage extends AbilityStage {
  onCreate() {
    try {
      bundleManager.getBundleInfoForSelf(bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION).then((data) => {
        console.info('testTag', `getBundleInfoForSelf successfully. Data: ${JSON.stringify(data)}`);
        if (data?.appInfo?.appProvisionType === 'release') {
          // release版本调用友盟
          setLogEnabled(true); // 开发时，打开调试日志，可观察sdk是否集成成功
          preInit({
            context: this.context.getApplicationContext(),
            plugins: [new InternalPlugin(), new ApmPlugin()]
          });
          emitter.on('agreedPrivacyAgreement', () => {
            init(); // 在用户同意隐私政策后再调用此方法
            console.info('initUmengFromAbility');
            // 埋点：成功初始化
            onEventObject('initSuccess', {
              'initSuccess': 'Success'
            });
          });
          emitter.on('enterCase', (caseObj: emitter.EventData) => {
            // 埋点：进入案例
            onEventObject('enterCase', {
              'enterCase': caseObj?.data?.uri
            });
          });
          emitter.on('pluginClicked', () => {
            // 埋点：插件红点点击
            onEventObject('pluginClicked', {
              'pluginClicked': "开发插件按钮点击"
            });
          });
        } else if (data?.appInfo?.appProvisionType === 'debug') {
          // debug版本不调用友盟
          emitter.on('agreedPrivacyAgreement', () => {});
          emitter.on('enterCase', (_caseObj: ESObject) => {});
        }
      }).catch((err: BusinessError) => {
        console.error('testTag', `getBundleInfoForSelf failed. Cause: ${err.message}`);
      });
    } catch (err) {
      let message = (err as BusinessError).message;
      console.error('testTag', `getBundleInfoForSelf failed: ${message}`);
    }


  }
}