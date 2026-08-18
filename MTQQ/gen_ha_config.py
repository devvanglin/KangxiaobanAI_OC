#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
从养老院设备台账 CSV 生成 Home Assistant 的 MQTT sensor 配置片段。

用法:
    python gen_ha_config.py device_list.csv > mqtt_sensors.yaml

台账 CSV 表头(必须完全一致):
    device_id,room,floor,bed,resident,product,scene_mode,install_height

产物:
    打印到标准输出的 YAML 片段,含 mqtt.sensor 和 mqtt.binary_sensor,
    每个实体带 device 归组块,可直接贴进 configuration.yaml 的 mqtt: 节点下。

说明:
    - R60ABD1 -> Topic 前缀 /Radar60SP/ (睡眠雷达)
    - R60AFD1 -> Topic 前缀 /Radar60FL/ (跌倒雷达)
    - topic 用具体 device_id 拼,实现多房间隔离
    - 实体名/设备名自动带房间号前缀,告警文案可定位房间
"""

import csv
import sys

# 产品 -> 协议前缀 + 字段集
PRODUCTS = {
    "R60ABD1": {
        "prefix": "/Radar60SP",
        "sensors": [
            ("humanDistance", "人体距离", "cm"),
            ("movementSigns", "体动幅度", None),
            ("breathValue", "呼吸数值", "次/分"),
            ("heartRateValue", "心率", "次/分"),
            ("sleepStatus", "睡眠状态", None),
            ("sleepScore", "睡眠评分", None),
            ("awakeDuration", "清醒时长", "分钟"),
        ],
        "binary": [
            ("someoneExists", "有人", "occupancy"),
            ("getIntoBed", "已上床", None),
            ("online", "在线", "connectivity"),
        ],
    },
    "R60AFD1": {
        "prefix": "/Radar60FL",
        "sensors": [],
        "binary": [
            ("fallStatus", "跌倒报警", "safety"),
            ("residentStatus", "静止驻留", None),
            ("someoneExists", "有人", "occupancy"),
        ],
    },
}

# 英文字段名 -> 拼音/英文实体 id 片段(HA 实体 id 用 ASCII 安全)
FIELD_ID = {
    "humanDistance": "distance",
    "movementSigns": "movement",
    "breathValue": "breath",
    "heartRateValue": "heart",
    "sleepStatus": "sleep_status",
    "sleepScore": "sleep_score",
    "awakeDuration": "awake",
    "someoneExists": "presence",
    "getIntoBed": "in_bed",
    "online": "online",
    "fallStatus": "fall",
    "residentStatus": "resident",
}

# 枚举/分类字段,不加 state_class: measurement(否则 HA 会当数值统计)
ENUM_FIELDS = {"sleepStatus", "movementSigns"}


def device_id_to_unique(device_id: str) -> str:
    """设备 ID 可能含非 ASCII 字符,转成 HA 可用的 unique_id 片段。"""
    out = []
    for ch in device_id:
        if ch.isalnum():
            out.append(ch)
        else:
            out.append("_")
    return "".join(out)


def gen_entity(entity_type, device_id, room, product, field, label_cn, unit, device_class):
    """生成单个实体的 YAML 文本块。"""
    prefix = PRODUCTS[product]["prefix"]
    dev_key = device_id_to_unique(device_id)
    field_key = FIELD_ID[field]
    room_tag = room.replace(" ", "_").replace("/", "_")

    unique_id = f"radar_{dev_key}_{field_key}"
    state_topic = f"{prefix}/{device_id}/sys/property/post"
    value_tpl = f"{{{{ value_json.params.{field} }}}}"
    entity_name = f"{room}_{label_cn}"

    lines = [f"    - name: \"{entity_name}\""]
    lines.append(f"      unique_id: \"{unique_id}\"")
    lines.append(f"      state_topic: \"{state_topic}\"")
    lines.append(f"      value_template: \"{value_tpl}\"")

    if entity_type == "sensor":
        if unit:
            lines.append(f"      unit_of_measurement: \"{unit}\"")
        if field not in ENUM_FIELDS:
            lines.append("      state_class: measurement")
    else:  # binary_sensor
        lines.append("      payload_on: \"1\"")
        lines.append("      payload_off: \"0\"")
        if device_class:
            lines.append(f"      device_class: {device_class}")

    # device 归组块
    lines.append("      device:")
    lines.append(f"        identifiers: \"{device_id}\"")
    lines.append(f"        name: \"{room}_{product}\"")
    lines.append("        manufacturer: \"MicRadar\"")
    lines.append(f"        model: \"{product}\"")

    return "\n".join(lines)


def main():
    if len(sys.argv) < 2:
        print("用法: python gen_ha_config.py device_list.csv > mqtt_sensors.yaml", file=sys.stderr)
        sys.exit(1)

    csv_path = sys.argv[1]
    rows = []
    try:
        with open(csv_path, encoding="utf-8-sig") as f:
            reader = csv.DictReader(f)
            for r in reader:
                rows.append(r)
    except FileNotFoundError:
        print(f"错误: 找不到文件 {csv_path}", file=sys.stderr)
        sys.exit(1)

    sensors = []
    binaries = []

    for r in rows:
        device_id = (r.get("device_id") or "").strip()
        room = (r.get("room") or "").strip()
        product = (r.get("product") or "").strip()

        if not device_id or not room or not product:
            print(f"警告: 跳过缺字段的行 {r}", file=sys.stderr)
            continue
        if product not in PRODUCTS:
            print(f"警告: 未知产品 {product},跳过设备 {device_id}", file=sys.stderr)
            continue

        cfg = PRODUCTS[product]
        for field, label_cn, unit in cfg["sensors"]:
            sensors.append(gen_entity("sensor", device_id, room, product, field, label_cn, unit, None))
        for field, label_cn, device_class in cfg["binary"]:
            binaries.append(gen_entity("binary_sensor", device_id, room, product, field, label_cn, None, device_class))

    print("mqtt:")
    if sensors:
        print("  sensor:")
        for s in sensors:
            print(s)
    if binaries:
        print("  binary_sensor:")
        for b in binaries:
            print(b)


if __name__ == "__main__":
    main()
