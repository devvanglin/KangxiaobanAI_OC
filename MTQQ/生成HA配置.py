# -*- coding: utf-8 -*-
"""
养老院雷达 -> Home Assistant 配置生成器

功能:读取「养老院房间映射表.csv」,批量生成 configuration.yaml 的 MQTT 片段,
      每台设备按"房间号"归组、按型号生成对应传感器集。

用法:
    python 生成HA配置.py

输出:
    configuration_rooms.yaml  (sensor / binary_sensor 配置片段)
    init_commands.txt          (每台设备的初始化参数设置命令清单)

改映射表后重跑本脚本即可,不要手改生成文件。
"""
import csv
import os

BASE = os.path.dirname(os.path.abspath(__file__))
CSV_PATH = os.path.join(BASE, "养老院房间映射表.csv")
YAML_PATH = os.path.join(BASE, "configuration_rooms.yaml")
INIT_PATH = os.path.join(BASE, "init_commands.txt")

# 各型号传感器定义: (中文名, 字段, 单位, state_class)
ABD1_SENSORS = [
    ("人体距离", "humanDistance", "cm", "measurement"),
    ("体动幅度", "movementSigns", None, "measurement"),
    ("呼吸数值", "breathValue", "次/分", "measurement"),
    ("心率", "heartRateValue", "次/分", "measurement"),
    ("睡眠状态", "sleepStatus", None, None),
    ("睡眠评分", "sleepScore", None, "measurement"),
    ("清醒时长", "awakeDuration", "分钟", "measurement"),
]
ABD1_BINARIES = [
    ("有人", "someoneExists", "occupancy"),
    ("已上床", "getIntoBed", None),
    ("在线", "online", "connectivity"),
]
AFD1_SENSORS = [
    ("跌倒位置X", "fallPosition.x", "cm", None),
]
AFD1_BINARIES = [
    ("跌倒报警", "fallStatus", "safety"),
    ("静止驻留", "residentStatus", None),
    ("有人", "someoneExists", "occupancy"),
]

TOPIC_PREFIX = {"R60ABD1": "/Radar60SP", "R60AFD1": "/Radar60FL"}
SCENE_NAME = {"1": "客厅", "2": "卧室", "3": "卫生间"}


def device_lines(identifiers, name, manufacturer, model, area):
    """生成 device 归组配置块"""
    return [
        '      device:',
        f'        identifiers: "{identifiers}"',
        f'        name: "{name}"',
        f'        manufacturer: "{manufacturer}"',
        f'        model: "{model}"',
        f'        suggested_area: "{area}"',
    ]


def main():
    rows = []
    with open(CSV_PATH, "r", encoding="utf-8-sig") as f:
        for r in csv.DictReader(f):
            r = {k.strip(): (v or "").strip() for k, v in r.items()}
            if r.get("设备ID"):
                rows.append(r)

    if not rows:
        print("[错误] 映射表为空,请先在 CSV 里登记设备。")
        return

    sensor_lines = []
    binary_lines = []
    init_notes = []

    for r in rows:
        model = r["雷达型号"].strip().upper()
        dev_id = r["设备ID"]
        room = r["房间号"]
        scene = r["场景模式"]
        height = r["安装高度cm"]
        angle = r["安装角度"]
        prefix = TOPIC_PREFIX.get(model)
        if not prefix:
            init_notes.append(f"[警告] 未知型号 {model},房间 {room},已跳过")
            continue

        state_topic = f'{prefix}/{dev_id}/sys/property/post'
        role = "睡眠" if model == "R60ABD1" else "跌倒"
        ident = f"{model.lower()}_{room}"
        dev_name = f"{room}房间{role}雷达"

        sensors = ABD1_SENSORS if model == "R60ABD1" else AFD1_SENSORS
        binaries = ABD1_BINARIES if model == "R60ABD1" else AFD1_BINARIES

        for cn, field, unit, sc in sensors:
            uid = f"{room}_{model.lower()}_{field.replace('.', '_')}"
            sensor_lines.append(f'    - name: "{room}_{cn}"')
            sensor_lines.append(f'      unique_id: "{uid}"')
            sensor_lines.append(f'      state_topic: "{state_topic}"')
            sensor_lines.append(f'      value_template: "{{{{ value_json.params.{field} }}}}"')
            if unit:
                sensor_lines.append(f'      unit_of_measurement: "{unit}"')
            if sc:
                sensor_lines.append(f'      state_class: {sc}')
            sensor_lines += device_lines(ident, dev_name, "MicRadar", model, room)

        for cn, field, dc in binaries:
            uid = f"{room}_{model.lower()}_{field.replace('.', '_')}"
            binary_lines.append(f'    - name: "{room}_{cn}"')
            binary_lines.append(f'      unique_id: "{uid}"')
            binary_lines.append(f'      state_topic: "{state_topic}"')
            binary_lines.append(f'      value_template: "{{{{ value_json.params.{field} }}}}"')
            binary_lines.append('      payload_on: "1"')
            binary_lines.append('      payload_off: "0"')
            if dc:
                binary_lines.append(f'      device_class: {dc}')
            binary_lines += device_lines(ident, dev_name, "MicRadar", model, room)

        # 初始化参数设置命令(设备端场景/安装参数,影响算法精度)
        scene_name = SCENE_NAME.get(scene, scene)
        init_notes.append(
            f'房间 {room} ({dev_id}) — 场景模式={scene}({scene_name}) 安装高度={height}cm 安装角度={angle}°'
        )

    # 生成 YAML
    yaml_body = ["# 自动生成,请勿手改。改 养老院房间映射表.csv 后重新运行 生成HA配置.py", "mqtt:"]
    if sensor_lines:
        yaml_body.append("  sensor:")
        yaml_body += sensor_lines
    if binary_lines:
        yaml_body.append("  binary_sensor:")
        yaml_body += binary_lines

    with open(YAML_PATH, "w", encoding="utf-8") as f:
        f.write("\n".join(yaml_body) + "\n")

    # 生成初始化命令清单
    init_body = [
        "养老院雷达初始化参数设置清单",
        "=" * 40,
        "以下每台设备需各发一条 set 命令,让算法匹配房间环境(降低误报)。",
        "在 HA 开发者工具 -> 服务 -> mqtt.publish 逐条发送。",
        "",
    ]
    for r in rows:
        model = r["雷达型号"].strip().upper()
        dev_id = r["设备ID"]
        room = r["房间号"]
        scene = r["场景模式"]
        height = r["安装高度cm"]
        angle = r["安装角度"]
        prefix = TOPIC_PREFIX.get(model, "")
        if not prefix:
            continue
        set_topic = f'{prefix}/{dev_id}/sys/property/set'
        init_body.append(f'--- {room} ({model}) ---')
        init_body.append(f'  topic:   {set_topic}')
        init_body.append(f'  payload: {{"version":"1.0","method":"set","params":{{"sceneMode":"{scene}","installHeight":"{height}","installAngle":{{"x":"{angle}","y":"{angle}","z":"{angle}"}}}}}}')
        init_body.append("")

    with open(INIT_PATH, "w", encoding="utf-8") as f:
        f.write("\n".join(init_body) + "\n")

    print(f"[完成] 共 {len(rows)} 台设备")
    print(f"  -> 配置片段: {YAML_PATH}")
    print(f"  -> 初始化命令: {INIT_PATH}")


if __name__ == "__main__":
    main()
