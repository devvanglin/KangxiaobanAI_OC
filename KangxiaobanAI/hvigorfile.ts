import { appTasks } from '@ohos/hvigor-ohos-plugin';

// Windows 下 OpenJDK 的 app_packing_tool 可能因 CompressedOops 地址布局无法申请连续内存。
// 只给 Hvigor 及其子进程注入参数，避免设置全局 JAVA_TOOL_OPTIONS 影响 DevEco Studio。
if (process.platform === 'win32') {
  const memoryOption: string = '-XX:HeapBaseMinAddress=34g';
  const currentOptions: string = process.env.JAVA_TOOL_OPTIONS ?? '';
  if (!currentOptions.includes('HeapBaseMinAddress')) {
    process.env.JAVA_TOOL_OPTIONS = `${currentOptions} ${memoryOption}`.trim();
  }
}

export default {
  system: appTasks, /* Built-in plugin of Hvigor. It cannot be modified. */
  plugins: []       /* Custom plugin to extend the functionality of Hvigor. */
}
