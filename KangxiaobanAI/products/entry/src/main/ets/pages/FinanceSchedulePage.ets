/*
 * Copyright (c) 2026 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 */

import ApiClient from '../network/ApiClient';
import AuthStore from '../network/AuthStore';
import { Paged, Bill, Elder, FundFlow, Schedule } from '../network/Dto';
import Logger from '../util/Logger';

const TAG: string = '[FinanceSchedulePage]';

/**
 * 费用 + 排班 看板页（M4 数据，经 network 层读取后端）。
 * 说明：此页面为代码实现，需在 DevEco 构建/真机验证；
 * 依赖后端运行，未登录/后端不可达时展示空态提示。
 */
@Entry
@ComponentV2
struct FinanceSchedulePage {
  @Local selectedTab: number = 0;
  @Local bills: Bill[] = [];
  @Local flows: FundFlow[] = [];
  @Local schedules: Schedule[] = [];
  @Local loading: boolean = false;
  @Local error: string = '';

  aboutToAppear(): void {
    this.loadAll();
  }

  private async loadAll(): Promise<void> {
    if (!AuthStore.getToken()) {
      this.error = '未登录，请先登录';
      return;
    }
    this.loading = true;
    try {
      this.schedules = await this.loadSchedules();
      this.bills = await this.loadBills();
      this.flows = await this.loadFlows();
    } catch {
      this.error = '数据加载失败，请确认后端已运行';
      Logger.error(TAG, 'load failed');
    }
    this.loading = false;
  }

  private async loadBills(): Promise<Bill[]> {
    const resp = await ApiClient.get<Paged<Bill>>('/bills?size=50');
    return resp.data.list ?? [];
  }

  private async loadFlows(): Promise<FundFlow[]> {
    const elderResp = await ApiClient.get<Paged<Elder>>('/elders?size=100');
    const flows: FundFlow[] = [];
    for (let index: number = 0; index < elderResp.data.list.length; index++) {
      const elder: Elder = elderResp.data.list[index];
      const resp = await ApiClient.get<Paged<FundFlow>>(`/elders/${elder.id}/flows?size=50`);
      for (let flowIndex: number = 0; flowIndex < resp.data.list.length; flowIndex++) {
        flows.push(resp.data.list[flowIndex]);
      }
    }
    return flows;
  }

  private async loadSchedules(): Promise<Schedule[]> {
    const resp = await ApiClient.get<Paged<Schedule>>('/schedules?size=50');
    return resp.data.list ?? [];
  }

  private static money(v: number): string {
    return '¥' + v.toFixed(2);
  }

  private tabItems: string[] = ['费用账单', '排班', '资金流水'];

  @Builder
  private tabBar() {
    Row() {
      ForEach(this.tabItems, (item: string, idx: number) => {
        Text(item)
          .fontSize(15)
          .fontWeight(this.selectedTab === idx ? FontWeight.Bold : FontWeight.Normal)
          .fontColor(this.selectedTab === idx ? $r('app.color.brand_blue') : $r('sys.color.font_secondary'))
          .padding({ left: 16, right: 16, top: 12, bottom: 12 })
          .onClick(() => {
            this.selectedTab = idx;
          })
      })
    }
    .width('100%')
    .justifyContent(FlexAlign.Start)
    .backgroundColor($r('sys.color.comp_background_secondary'))
  }

  @Builder
  private billList() {
    List() {
      ForEach(this.bills, (b: Bill) => {
        ListItem() {
          Row({ space: 10 }) {
            Column({ space: 2 }) {
              Text(b.bill_month)
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
              Text(`长者#${b.elder_id}`)
                .fontSize(12)
                .fontColor($r('sys.color.font_tertiary'))
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Column({ space: 2 }) {
              Text(FinanceSchedulePage.money(b.amount))
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.brand_blue'))
              Text(`已缴 ${b.paid} / ${b.status}`)
                .fontSize(12)
                .fontColor(b.status === 'paid' ? $r('sys.color.font_secondary') : $r('sys.color.font_tertiary'))
            }
          }
          .width('100%')
          .padding(14)
          .backgroundColor($r('sys.color.comp_background_secondary'))
          .borderRadius(12)
        }
      })
    }
    .width('100%')
    .layoutWeight(1)
  }

  @Builder
  private scheduleList() {
    List() {
      ForEach(this.schedules, (s: Schedule) => {
        ListItem() {
          Row({ space: 10 }) {
            Column({ space: 2 }) {
              Text(s.staff)
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
              Text(`${s.work_date} · ${s.shift}`)
                .fontSize(12)
                .fontColor($r('sys.color.font_tertiary'))
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Text(s.room_scope ?? '-')
              .fontSize(13)
              .fontColor($r('sys.color.font_secondary'))
          }
          .width('100%')
          .padding(14)
          .backgroundColor($r('sys.color.comp_background_secondary'))
          .borderRadius(12)
        }
      })
    }
    .width('100%')
    .layoutWeight(1)
  }

  @Builder
  private flowList() {
    List() {
      ForEach(this.flows, (f: FundFlow) => {
        ListItem() {
          Row({ space: 10 }) {
            Column({ space: 2 }) {
              Text(f.reason || f.direction)
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
              Text(`${f.related_month ?? ''} · 长者#${f.elder_id}`)
                .fontSize(12)
                .fontColor($r('sys.color.font_tertiary'))
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Text(`${f.direction === 'in' ? '+' : '-'} ${f.amount}`)
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor(f.direction === 'in' ? $r('app.color.status_danger') : $r('app.color.brand_blue'))
          }
          .width('100%')
          .padding(14)
          .backgroundColor($r('sys.color.comp_background_secondary'))
          .borderRadius(12)
        }
      })
    }
    .width('100%')
    .layoutWeight(1)
  }

  build() {
    Column() {
      // 顶部标题栏
      Row() {
        Text('费用与排班')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
        Blank()
        Text('刷新')
          .fontSize(14)
          .fontColor($r('app.color.brand_blue'))
          .onClick(() => {
            this.loadAll();
          })
      }
      .width('100%')
      .height(52)
      .padding({ left: 16, right: 16 })

      this.tabBar()

      if (this.loading) {
        Blank()
        LoadingProgress()
          .width(42)
          .height(42)
        Text('加载中…')
          .fontSize(14)
          .fontColor($r('sys.color.font_tertiary'))
        Blank()
      } else if (this.error && this.bills.length === 0) {
        Blank()
        Text(this.error)
          .fontSize(14)
          .fontColor($r('sys.color.font_tertiary'))
        Text('请确认后端已运行，且在登录页登录')
          .fontSize(12)
          .fontColor($r('sys.color.font_tertiary'))
        Blank()
      } else if (this.selectedTab === 0) {
        this.billList()
      } else if (this.selectedTab === 1) {
        this.scheduleList()
      } else {
        this.flowList()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_primary'))
  }
}
