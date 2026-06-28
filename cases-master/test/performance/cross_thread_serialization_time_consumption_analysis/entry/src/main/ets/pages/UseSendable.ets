import { collections, taskpool } from '@kit.ArkTS';

/**
 * “跨线程序列化耗时点分析工具使用指导” - 正例：使用Sendable方式优化后
 */

@Entry
@Component
export struct UseSendable {
  @State message: string = 'Hello World';

  build() {
    NavDestination() {
      Row() {
        Text(this.message)
          .fontSize(30)
          .fontWeight(FontWeight.Bold)
          .onClick(() => {
            prepareBooksInfo();
            this.message = 'execute finished';
          })
      }
    }
    .height('100%')
    .width('100%')
  }
}

@Sendable
class SharedContentExInfo {
}

@Sendable
class SharedBook {
  recordId_: string = '';
  title_: string = '';
  content_: string = '';
  contentExInfo_: SharedContentExInfo | null = null;
  authorList_: collections.Array<string> | null = null;

  constructor() {
    // 初始化Book相关静态信息
    // ...
  }

  init(contentExInfo: SharedContentExInfo) {
    this.contentExInfo_ = contentExInfo;
  }

  // 省略其余成员方法
  // ...
}

@Sendable
class SharedBookDBInfo {
  dbName_: string = '';
  seq_: number = 0;
  tableName_: string = '';
  books_: collections.Array<SharedBook> | null = null;

  constructor(dbName: string, tableName: string) {
    this.dbName_ = dbName;
    this.tableName_ = tableName;
  }
}

@Concurrent
function doDBOperations(info: SharedBookDBInfo) {
  // 进行数据库相关操作
  // ...
}

function prepareBooksInfo() {
  let dbInfo = new SharedBookDBInfo('database1', 'books');
  let bookBean: SharedBook = new SharedBook();
  bookBean.init(new SharedContentExInfo());
  dbInfo.books_ = new collections.Array<SharedBook>(bookBean);
  for (let i = 0; i < 50000; i++) {
    let book = new SharedBook();
    book.authorList_ = new collections.Array<string>();
    // 组装书本信息
    // ...
    for (let j = 0; j < 5; j++) {
      book.authorList_?.push(`${i}${j}`);
    }
    dbInfo.books_?.push(book);
  }
  let res = taskpool.execute(doDBOperations, dbInfo);
}
