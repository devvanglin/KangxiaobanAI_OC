import { BasicDataSource } from '../model/BasicDataSource';
import { IconItemSource } from './IconItemSource';

export class MyDataSource extends BasicDataSource<IconItemSource> {
  private dataArray: IconItemSource[] = [];

  public totalCount(): number {
    return this.dataArray.length;
  }

  public getData(index: number): IconItemSource {
    return this.dataArray[index];
  }

  public pushData(data: IconItemSource): void {
    this.dataArray.push(data);
    this.notifyDataAdd(this.dataArray.length - 1);
  }

}