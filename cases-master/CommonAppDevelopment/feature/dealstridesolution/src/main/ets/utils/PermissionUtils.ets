import { abilityAccessCtrl, common, PermissionRequestResult, Permissions } from "@kit.AbilityKit";

export enum PermissionResult {
  Agree, Disagree, Retry
}

export class PermissionUtils {
  // 请求读取图库媒体权限
  static async requestPermission(context: common.UIAbilityContext,
    permissions: Array<Permissions>): Promise<PermissionResult> {
    let atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
    let result: PermissionRequestResult =
      await atManager.requestPermissionsFromUser(context, permissions);
    if (result.authResults[0] === 0) {
      // 用户同意授权
      return PermissionResult.Agree;
    } else if (result.authResults[0] === -1) {
      if (result.dialogShownResults && result.dialogShownResults[0]) {
        // 用户首次拒绝授权
        return PermissionResult.Disagree;
      } else {
        // 用户拒绝授权后再次请求授权
        return PermissionResult.Retry;
      }
    } else {
      return PermissionResult.Retry;
    }
  }

  /**
   * 在Setting中获取授权
   * 首次申请授权时会弹出dialog，当用户拒绝后再次申请权限则不会弹出dialog，需要用户手动去设置中开启授权
   * @param context
   * @returns 授权结果
   */
  static async requestPermissionOnSetting(context: common.UIAbilityContext,
    permissions: Array<Permissions>): Promise<PermissionResult> {
    let atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
    let result: Array<abilityAccessCtrl.GrantStatus> =
      await atManager.requestPermissionOnSetting(context, permissions);
    return result[0] === 0 ? PermissionResult.Agree : PermissionResult.Disagree;
  }

  /**
   * 检查权限
   * @param context
   * @param permissions 需要检查的权限
   */
  static async checkPermission(context: common.UIAbilityContext, permissions: Array<Permissions>): Promise<boolean> {
    // 获取媒体权限
    let permissionResult: PermissionResult =
      await PermissionUtils.requestPermission(context, permissions)
    switch (permissionResult) {
      case PermissionResult.Agree:
        // 用户同意权限
        return true;
      case PermissionResult.Disagree:
        // 用户拒绝权限，不做操作
        return false;
      case PermissionResult.Retry:
        // 用户拒绝权限后重新申请权限
        let retryPermissionResult: PermissionResult =
          await PermissionUtils.requestPermissionOnSetting(context, permissions);
        // 如果用户同意权限，则显示媒体列表
        if (retryPermissionResult === PermissionResult.Agree) {
          return true;
        }
    }
    return false;
  }
}