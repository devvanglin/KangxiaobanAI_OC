const { getHvigorNode, hvigor } = require('@ohos/hvigor')
import { hapTasks } from '@ohos/hvigor-ohos-plugin';
import * as path from 'path';

const mModule = getHvigorNode(__filename);
const ohosPlugin = hapTasks(mModule);

let curTargetName = "phone_target_debug";
const config = hvigor.getExtraConfig();
const productName = config.get('product');
const mModuleName = mModule.getName();
const projectRootPath = process.cwd();
const fs = require('fs')

const entryName = '';

ohosPlugin.getNeedExecTargetServiceList().forEach(targetServices => {
  curTargetName = targetServices.getTargetData().getTargetName();
  // TODO: 知识点：根据product修改bundleName
  let bundleNamePath = path.resolve(projectRootPath, `AppScope/app.json5`);
  let bundleNameData = fs.readFileSync(bundleNamePath);
  let bundleNameJson = JSON.parse(bundleNameData);
  // 判断target中name是否是tablet。
  if (curTargetName.startsWith('tablet')) {
    bundleNameJson.app.bundleName = 'com.north.casestablet';
  } else if (curTargetName.endsWith('product')) {
    // 构建发布版本时，使用生产环境
    bundleNameJson.app.bundleName = 'com.north.cases';
  } else {
    bundleNameJson.app.bundleName = 'com.north.cases.debug';
  }
  let outData = JSON.stringify(bundleNameJson, null, 2);
  fs.writeFileSync(bundleNamePath, outData);

  // TODO: 知识点：根据target名字修改module.json5中的数据
  let modulePath = path.resolve(projectRootPath, `product/entry/src/main/module.json5`);
  let rawData = fs.readFileSync(modulePath);
  let moduleJson = JSON.parse(rawData);
  let abilities = moduleJson.module.abilities;
  // 判断target中name是否是tablet,修改使用的entryAbility文件路径。
  if (curTargetName.startsWith('tablet')) {
    findAndReplaceSrcEntry(abilities, './ets/tablet/entryability/EntryAbility.ets');
  } else {
    findAndReplaceSrcEntry(abilities, './ets/entryability/EntryAbility.ets');
  }
  let data = JSON.stringify(moduleJson, null, 2);
  fs.writeFileSync(modulePath, data);

  function findAndReplaceSrcEntry(abilities, value) {
    for (let item of abilities) {
      item.srcEntry = value;
      break;
    }
  }

  // 根据target名字修改main_pages中的数据
  let mainPagesPath = path.resolve(projectRootPath, `product/entry/src/main/resources/base/profile/main_pages.json`);
  let mainPagesData = fs.readFileSync(mainPagesPath);
  let mainPagesJson = JSON.parse(mainPagesData);
  if (curTargetName.startsWith('tablet')) {
    mainPagesJson.src = ["tablet/pages/EntryView"];
  } else {
    mainPagesJson.src = ["pages/EntryView", "pages/AdvertisingPage"];
  }
  let pagesData = JSON.stringify(mainPagesJson, null, 2);
  fs.writeFileSync(mainPagesPath, pagesData);
})

module.exports = {
  ohos: ohosPlugin
}

export default {
  system: hapTasks, /* Built-in plugin of Hvigor. It cannot be modified. */
  plugins: []         /* Custom plugin to extend the functionality of Hvigor. */
}

