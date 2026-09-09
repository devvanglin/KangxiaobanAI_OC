import os
from pathlib import Path

# 项目根目录
BASE_DIR = Path(__file__).parent.absolute()

# Only the authenticated Kangxiaoban backend may create assessment sessions.
# The value is injected by systemd and never shipped to clients or source.
ASSESSMENT_PROXY_TOKEN = os.getenv("ASSESSMENT_PROXY_TOKEN", "")

# LLM 配置
# 默认模型: "qwen3:4b"
LLM_MODEL_NAME = os.getenv("LLM_MODEL_NAME", "llama3.2:3b")

# ASR 配置
# 默认模型: "iic/SenseVoiceSmall"
ASR_MODEL_PATH = os.getenv("ASR_MODEL_PATH", "iic/SenseVoiceSmall")

# TTS 配置
# 模型文件通常位于 checkpoints/kokoro/
TTS_MODEL_DIR = BASE_DIR / "checkpoints" / "kokoro"
TTS_CONFIG = {
    "model": str(TTS_MODEL_DIR / "kokoro-v1.1-zh.onnx"),
    "voice": str(TTS_MODEL_DIR / "voices-v1.1-zh.bin"),
    "vocab": str(TTS_MODEL_DIR / "config-v1.1-zh.json"),
}

# VAD 配置
VAD_SILENCE_THRESHOLD_MS = int(os.getenv("VAD_SILENCE_THRESHOLD_MS", "350"))
# Elderly speakers pause more often inside one answer. Assessment turns use a
# longer end-of-utterance window so a brief thinking pause never advances the
# questionnaire. The timer starts only after the client confirms TTS playback
# has drained and ASR is actually listening.
ASSESSMENT_END_SILENCE_MS = int(os.getenv("ASSESSMENT_END_SILENCE_MS", "1200"))

# 其他配置
OUTPUT_DIR = BASE_DIR / "outputs"
STATIC_DIR = BASE_DIR / "static"

# 确保输出目录存在
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
