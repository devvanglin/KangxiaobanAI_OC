#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
跌倒雷达实时监控脚本

功能:订阅跌倒雷达的上报主题,实时打印所有数据,一旦跌倒(fallStatus=1)就醒目报警。

依赖:
    pip install paho-mqtt

用法:
    python monitor_fall.py
"""

import paho.mqtt.client as mqtt
import json
import time

BROKER = "192.168.100.110"      # MQTT 服务器
DEVICE = "E438192587C3"          # 设备 ID(改这里可换成别的设备)

FIELD_LABELS = {
    "online": "在线",
    "someoneExists": "有人",
    "motionStatus": "运动状态",
    "fallStatus": "跌倒报警",
    "residentStatus": "静止驻留",
    "movementSigns": "体动幅度",
    "humanDistance": "人体距离",
    "fallPosition": "跌倒位置",
    "heartBeat": "心跳包",
}


def on_message(client, userdata, msg):
    try:
        data = json.loads(msg.payload)
    except Exception:
        return
    params = data.get("params", {})
    ts = time.strftime("%H:%M:%S")
    for k, v in params.items():
        label = FIELD_LABELS.get(k, k)
        if k == "fallStatus" and str(v) == "1":
            print("\n" + "=" * 44)
            print("  >>>>> 跌倒报警触发!  fallStatus = 1  <<<<<")
            print("=" * 44 + "\n")
        else:
            print(f"[{ts}] {label} = {v}")


def main():
    topic = f"/Radar60FL/{DEVICE}/sys/property/post"
    client = mqtt.Client(client_id="fall_monitor")
    client.on_message = on_message
    client.connect(BROKER, 1883, 60)
    client.subscribe(topic)
    print(f"正在监控: {topic}")
    print("在雷达正下方 1.5 米内模拟跌倒,看到『跌倒报警触发』即预警成功\n")
    client.loop_forever()


if __name__ == "__main__":
    main()
