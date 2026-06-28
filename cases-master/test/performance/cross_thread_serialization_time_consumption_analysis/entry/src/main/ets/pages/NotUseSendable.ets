import { taskpool } from '@kit.ArkTS';

/**
 * “跨线程序列化耗时点分析工具使用指导” - 反例：未使用Sendable方式
 */

@Entry
@Component
export struct NotUseSendable {
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

class Book {
  recordId_: string = '';
  title_: string = '';
  content_: string = '';
  authorList_: Array<string> | null = null;

  constructor() {
    // 初始化Book相关静态信息
    // ...
  }

  // 省略其余成员方法
  // ...
}

class BookDBInfo {
  dbName_: string = '';
  seq_: number = 0;
  tableName_: string = '';
  books_: Array<Book> | null = null;

  constructor(dbName: string, tableName: string) {
    this.dbName_ = dbName;
    this.tableName_ = tableName;
  }
}

@Concurrent
function doDBOperations(info: BookDBInfo) {
  // 进行数据库相关操作
  // ...
}

function prepareBooksInfo() {
  let dbInfo = new BookDBInfo('database1', 'books');
  dbInfo.books_ = new Array<Book>();
  for (let i = 0; i < 50000; i++) {
    let book = new Book();
    book.authorList_ = new Array<string>();
    // 组装书本信息
    // ...
    for (let j = 0; j < 5; j++) {
      book.authorList_?.push(`${i}${j}`);
    }
    dbInfo.books_?.push(book);
  }
  let res = taskpool.execute(doDBOperations, dbInfo);
}