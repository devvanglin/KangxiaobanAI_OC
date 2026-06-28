# 自动生成代码插件

### 介绍

本示例将介绍如何通过ts抽象语法树，根据自定义装饰器，自动生成代码。

### 实现原理

在编译期通过扫描并解析ets文件中的自定义装饰器来生成方法并调用

### 实现思路

**插件初始化**

1. 创建ts工程，并添加hvigor依赖，可以使用hvigor中配置的解析和打包方法

   ```shell
   npm init
   npm install --save-dev @types/node hvigor @ohos/hvigor-ohos-plugin
   npm install typescript handlebars
   ```

2. 初始化ts配置

   ```shell
   ./node_modules/.bin/tsc --init
   ```

3. 修改package.json文件

   ```json
   {
   "name": "autobuilddecoration",
   "version": "1.0.0",
   "description": "",
   "main": "lib/index.js",
   "scripts": {
     "test": "echo \"Error: no test specified\" && exit 1",
     "dev": "tsc && node lib/index.js",
     "build": "tsc"
   },
   ...
   ```

4. 修改tsconfig.json，指定编译相关的选项

   ```json5
   {
     "compilerOptions": {
       "target": "es2021",                                  /* Set the JavaScript language version for emitted JavaScript and include compatible library 
       "module": "commonjs",                                /* Specify what module code is generated. */
       "esModuleInterop": true,                             /* Emit additional JavaScript to ease support for importing CommonJS modules. This enables 'allowSyntheticDefaultImports' for type compatibility. */
       "forceConsistentCasingInFileNames": true,            /* Ensure that casing is correct in imports. */
       "skipLibCheck": true,                                 /* Skip type checking all .d.ts files. */
       "sourceMap": true,
       "outDir": "./lib"
     },
     "include": [".eslintrc.js","src/**/*"],
     "exclude": ["node_modules","lib/**/*"]
   }
   ```

5. 创建插件文件src/index.ts，用于编写插件代码

6. 插件代码编写完成后，运行/node_modules/.bin/tsc.cmd，在hvigor/hvigor-config.json5中配置插件后即可使用。

**具体实现**

1. 提供配置方法，调用时传入配置参数

   ```typescript
   export function etsDecorationPlugin(pluginConfig: PluginConfig): HvigorPlugin {
     pluginConfig.annotation = 'CallbackObserver';
     pluginConfig.builderTpl = 'methodBuilder.tpl'
     return {
       pluginId: PLUGIN_ID,
       apply(node: HvigorNode) {
         console.log(`Exec ${PLUGIN_ID}...${__dirname}`);
         console.log(`node:${node.getNodeName},nodePath:${node.getNodePath()}`);
         pluginConfig.moduleName = node.getNodeName();
         pluginConfig.modulePath = node.getNodePath();
         pluginExec(pluginConfig);
       }
     }
   }
   ```

2. 根据配置的文件路径，扫描文件，并创建解析类，开始解析文件

   ```typescript
   ...
   config.scanFiles.forEach((file) => { 
     // 文件绝对路径
     let sourcePath = `${config.modulePath}/${file}`;
     if (!sourcePath.endsWith('.ets')) {
       sourcePath = sourcePath + '.ets';
     }
     const analyzer = new EtsAnalyzer(config, sourcePath);
     // 开始解析文件
     analyzer.start();
   ...
   ```

3. 将文件解析为抽象语法树

   ```typescript
   start() {
     // 读取文件
     const sourceCode = readFileSync(this.sourcePath, "utf-8");
     // 解析文件，生成节点树信息
     const sourceFile = ts.createSourceFile(this.sourcePath, sourceCode, ts.ScriptTarget.ES2021, false);
     // 遍历节点信息
     ts.forEachChild(sourceFile, (node: ts.Node) => {
       // 解析节点
       console.log(JSON.stringify(node));
       this.resolveNode(node);
     });
   }
   ```

4. 解析抽象语法树中的各类节点

   ```typescript
   resolveNode(node: ts.Node) {
     switch (node.kind) {
       // 未知的声明节点
       case ts.SyntaxKind.MissingDeclaration:
         this.resolveMissDeclaration(node);
         break;
       // 装饰器节点
       case ts.SyntaxKind.Decorator:
         this.resolveDecoration(node);
         break;
       // 获取节点的位置
       case ts.SyntaxKind.ExpressionStatement:
         this.resolveExpressionStatement(node);
         break;
       // 解析装饰器装饰的自定义组件
       case ts.SyntaxKind.Block:
         this.resolveBlock(node);
         break;
     }
   }
   ```

5. 解析装饰器节点，获取配置的方法名和组件ID，并记录装饰器位置，用于获取配置装饰器的struct的位置

   ```typescript
   // 被装饰器装饰的struct位置
   positionOfStruct: number = -1;
   // 解析装饰器
   resolveDecoration(node: ts.Node) {
     // 转换为装饰器节点类型
     let decorator = node as ts.Decorator;
     // 判断表达式是否是函数调用
     if (decorator.expression.kind === ts.SyntaxKind.CallExpression) {
       const callExpression = decorator.expression as ts.CallExpression;
       // 表达式类型是否是标识符
       if (callExpression.expression.kind === ts.SyntaxKind.Identifier) {
         const identifier = callExpression.expression as ts.Identifier;
         // 标识符是否是自定义的装饰器
         if (identifier.text === this.pluginConfig.annotation) {
           this.routerAnnotationExisted = true;
           // 记录装饰器装饰的struct的位置
           if (this.currentMissDeclarationNode !== undefined) {
             this.positionOfStruct = this.currentMissDeclarationNode.end;
             this.currentMissDeclarationNode = undefined;
           }
           const arg = callExpression.arguments[0];
           // 调用方法的第一个参数是否是表达式
           if (arg.kind === ts.SyntaxKind.ObjectLiteralExpression) {
             const properties = (arg as ts.ObjectLiteralExpression).properties;
             // 遍历装饰器中的所有参数
             let decoratorInfo: DecorationInfo = new DecorationInfo();
             properties.forEach((propertie) => {
               if (propertie.kind === ts.SyntaxKind.PropertyAssignment) {
                 if ((propertie.name as ts.StringLiteral).text !== 'bindId') {
                   // 如果参数名不是“bindId”，则放入需要创建的方法列表中
                   let methodInfo: MethodInfo = new MethodInfo();
                   methodInfo.name = (propertie.name as ts.StringLiteral).text;
                   methodInfo.value = (propertie.initializer as ts.StringLiteral).text;
                   decoratorInfo.methods.push(methodInfo);
                   this.methodArray.push((propertie.initializer as ts.StringLiteral).text);
                 } else {
                   // 如果参数名是“buildId”，则设置到对应的变量中
                   decoratorInfo.bindId = (propertie.initializer as ts.StringLiteral).text;
                 }
               }
             })
             this.decorationInfos.push(decoratorInfo);
           }
         }
       }
     }
   }
   ```

6. 获取固定节点的位置

   ```typescript
   // 被装饰器装饰的自定义组件@Component的位置
   positionOfComponent: number = -1;
   // 被装饰器装饰的自定义组件的位置（从“{”开始）
   positionOfBlock: number = -1;
   // 被装饰器装饰的自定义组件的结束位置（到“}”结束）
   positionOfBlockEnd: number = -1;
   // 获取固定节点的位置
   resolveExpressionStatement(node: ts.Node) {
     if (node.pos === this.positionOfStruct) {
       this.positionOfComponent = node.end;
     }
     if (node.pos === this.positionOfComponent) {
       this.positionOfBlock = node.end;
     }
     if(node.pos===this.positionOfAboutToAppear){
       this.positionOfAboutToAppearEnd=node.end;
     }
   }
   ```

7. 解析自定义组件结构体，查找是否已包含需要创建的方法，并查找是否已包含aboutToAppear方法

   ```typescript
   // 被装饰器装饰的自定义组件中aboutToAppear方法的位置（从“{”开始）
   positionOfAboutToAppear: number = -1;
   // 被装饰器装饰的自定义组件中aboutToAppear方法的结束位置（到“}”结束）
   positionOfAboutToAppearEnd: number = -1;
   // 解析装饰器装饰的自定义组件（从“{”到“}”）
   resolveBlock(node: ts.Node) {
     if (node.pos === this.positionOfBlock) {
       let method: ts.MethodDeclaration = undefined;
       const block = node as ts.Block;
       const statements = block.statements;
       // 自定义组件中已经存在的方法列表
       const methodNameArray: string[] = [];
       statements.forEach((statement: ts.Statement) => {
         if (statement.kind === ts.SyntaxKind.ExpressionStatement) {
           const expression = (statement as ts.ExpressionStatement).expression;
           if (expression.kind === ts.SyntaxKind.CallExpression) {
             const callExpression = expression as ts.CallExpression;
             if (callExpression.expression.kind === ts.SyntaxKind.Identifier) {
               const identifier = callExpression.expression as Identifier;
               methodNameArray.push(identifier.escapedText.toString());
               // 查找是否已经存在aboutToAppear方法
               if (identifier.escapedText === 'aboutToAppear') {
                 this.aboutToAppearExist = true;
                 this.positionOfAboutToAppear = statement.pos;
               }
             }
           }
         }
       })
       // 过滤已经存在的装饰器中的方法
       const temp = this.methodArray.filter((value: string, index: number) => {
         return !methodNameArray.includes(value);
       })
       this.methodArray = temp;
       // 记录自定义组件的结束位置
       this.positionOfBlockEnd = node.end;
     }
   }
   ```

8. 根据解析结果，创建装饰器中配置的方法，并在aboutToAppear方法中添加调用，然后写入原文件中

   ```typescript
   // 如果解析的文件中存在装饰器，则将结果保存到列表中
   if (analyzer.routerAnnotationExisted) {
     // 如果有需要创建的方法
     if (analyzer.methodArray.length > 0) {
       // 读取整个文件
       let fileContent = readFileSync(sourcePath, { encoding: "utf8" });
       // 添加了装饰器的自定义组件的结构体位置
       let firstHalfText = fileContent.slice(0, analyzer.positionOfBlockEnd - 1);
       // 文件中的剩余部分
       let secondHalfText = fileContent.slice(analyzer.positionOfBlockEnd - 1, fileContent.length)
       // 装饰器中如果设置了bindId，则添加listener变量，并在aboutToAppear中调用监听方法
       // aboutToAppear方法是否已存在 
       if (analyzer.aboutToAppearExist) {
         // 如果已经存在aboutToAppear，则根据aboutToAppear方法的位置拆分结构体，并将需要生成的代码添加到对应的位置
         let beforeAboutToAppear = firstHalfText.slice(0, analyzer.positionOfAboutToAppear);
         let inAboutToAppear =
           firstHalfText.slice(analyzer.positionOfAboutToAppear, analyzer.positionOfAboutToAppearEnd-2);
         let afterAboutToAppear = firstHalfText.slice(analyzer.positionOfAboutToAppearEnd-2, firstHalfText.length);
         // 遍历所有装饰器，根据装饰器中配置的方法名，添加listener初始化和调用代码
         analyzer.decorationInfos.forEach((decorationInfo: DecorationInfo) => {
           if (decorationInfo.bindId !== '' && !firstHalfText.includes(`${decorationInfo.bindId}Listener`)) {
             beforeAboutToAppear = beforeAboutToAppear +
               `\n  ${decorationInfo.bindId}Listener: inspector.ComponentObserver = inspector.createComponentObserver('${decorationInfo.bindId}')`;
             decorationInfo.methods.forEach((methodInfo: MethodInfo) => {
               if (methodInfo.name === 'onDraw') {
                 inAboutToAppear =
                   inAboutToAppear + `\nthis.${decorationInfo.bindId}Listener.on('draw',this.${methodInfo.value});\n`
               }
               if (methodInfo.name === 'onLayout') {
                 inAboutToAppear =
                   inAboutToAppear + `this.${decorationInfo.bindId}Listener.on('layout',this.${methodInfo.value});\n`
               }
             });
             
           }
         })
         firstHalfText = beforeAboutToAppear + inAboutToAppear + afterAboutToAppear;
       } else {
         // 如果不存在aboutToAppear方法，则创建aboutToAppear方法，并添加调用代码
         analyzer.decorationInfos.forEach((decorationInfo: DecorationInfo) => {
           if (decorationInfo.bindId !== ''&& !firstHalfText.includes(`${decorationInfo.bindId}Listener`)) {
             firstHalfText = firstHalfText +
               `  ${decorationInfo.bindId}Listener: inspector.ComponentObserver = inspector.createComponentObserver('${decorationInfo.bindId}');\n  aboutToAppear(): void {\n`;
               
             decorationInfo.methods.forEach((methodInfo: MethodInfo) => {
               if (methodInfo.name === 'onDraw') {
                 firstHalfText =
                 firstHalfText + `    this.${decorationInfo.bindId}Listener.on('draw',this.${methodInfo.value});\n`
               }
               if (methodInfo.name === 'onLayout') {
                 firstHalfText =
                 firstHalfText + `    this.${decorationInfo.bindId}Listener.on('layout',this.${methodInfo.value});\n`
               }
             });
           
             firstHalfText = firstHalfText + '\n  }\n';
           }
         })
         firstHalfText = firstHalfText + '\n';
       }
       // 根据模板创建装饰器中配置的方法
       const builderPath = path.resolve(__dirname, `../${config.builderTpl}`);
       const tpl = readFileSync(builderPath, { encoding: "utf8" });
       const template = Handlebars.compile(tpl);
       analyzer.methodArray.forEach((name: string) => {
         const output = template({
           functionName: name
         });
         firstHalfText = firstHalfText + "\n" + output;
       })
       fileContent = firstHalfText + '\n' + secondHalfText;
       // 将生成的代码写入文件中
       writeFileSync(sourcePath, fileContent, { encoding: "utf8" })
     }
   }
   ```