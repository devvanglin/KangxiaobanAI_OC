"""
评估问答引擎：医生建档后开始评估，大模型逐题问诊，结束后生成结构化总结报告。
- 题库来自 assessment_questions.json（医生可自行编辑增删）
- 每次只推进一题；支持 跳过 / 没听清重问 / 提前结束
- 报告由 LLM 依据问答记录生成，仅供关注建议，不构成诊断
"""

import json
import re
import time
import uuid
from pathlib import Path

BASE_DIR = Path(__file__).parent.parent
QUESTIONS_FILE = BASE_DIR / "assessment_questions.json"
REPORT_DIR = BASE_DIR / "outputs" / "assessments"

# run_assessment_turn 的哨兵入参：代表“本题为超时未回答，判定不配合”
NO_RESPONSE_SENTINEL = "__NO_RESPONSE__"

# 患者回答中的控制词
SKIP_WORDS = ("跳过", "不回答", "不想说", "下一个问题")
REPEAT_WORDS = ("没听清", "再说一遍", "再说一次", "什么意思", "没听懂", "重复一遍")
STOP_WORDS = ("结束评估", "停止评估", "直接出报告")

ASSESSOR_SYSTEM = (
    "你是一位亲切、专业的老年人健康评估员，正在为一位老人做问诊式综合评估。"
    "你的任务：先用一句话自然地回应老人刚才的回答（共情或简短确认，不超过20字），"
    "然后清楚、完整地说出下一个问题。如果老人没有回答（记录为未回答），请先温和地安慰一句"
    "（例如：没关系，我们慢慢来），再问下一个问题。只输出你要说出口的话，不要解释、不要编号、"
    "不要重复患者原话、不要提出题目之外的任何新问题。语气温和，像面对面聊天。"
)

REPORT_SYSTEM = (
    "你是一位资深的老年医学评估医生。请根据问诊问答记录，用简体中文生成一份 Markdown 格式的"
    "《老年人综合能力评估报告》。结构如下：\n"
    "# 老年人综合能力评估报告\n"
    "## 一、基本信息\n（姓名、年龄、性别、主诉备注、评估时间）\n"
    "## 二、逐项评估摘要\n（按睡眠、日常生活能力、记忆认知、情绪、跌倒风险、慢病用药、"
    "视听、二便、社会支持、饮食营养逐项一小段：患者原话要点 + 简短专业点评；"
    "注意如实区分『主动跳过』与『超时未回答（判定不配合）』，未作答的注明未作答）\n"
    "## 三、需要重点关注的风险\n（按高/中/低列点，如跌倒、情绪低落、认知下降、用药不规律等，"
    "没有风险的维度不要硬写）\n"
    "## 四、建议\n（给护理人员/医生的可执行建议，3-6条）\n"
    "## 五、声明\n本报告由 AI 根据问诊对话自动生成，属于评估参考信息，不构成医学诊断，"
    "最终结论请以医生面诊为准。\n"
    "要求：客观引用患者原话作为依据，不要虚构没有提到的信息。"
)


def load_questions():
    """返回 (title, questions, timeout_seconds)"""
    data = json.loads(QUESTIONS_FILE.read_text(encoding="utf-8"))
    title = data.get("title", "综合评估")
    timeout = int(data.get("no_answer_timeout", 15))
    return title, data["questions"], timeout


def _contains(text, words):
    return any(w in text for w in words)


class AssessmentSession:
    """一次评估会话的全部状态，由 api_server 持有。"""

    def __init__(
        self,
        profile: dict,
        title: str,
        questions: list,
        timeout: int = 15,
        records: list | None = None,
    ):
        self.profile = profile or {}
        self.title = title
        self.questions = questions
        self.timeout = timeout  # 每题无回答判定超时（秒）
        self.records = list(records or [])[: len(questions)]
        self.index = len(self.records)  # 当前题目下标
        self.done = self.index >= len(questions)
        self.created_at = time.strftime("%Y-%m-%d %H:%M:%S")
        # 文件名保持 ASCII，避免中文路径在各端下载时的编码问题；姓名保存在报告内容与索引里
        self.record_id = (
            f"assess_{time.strftime('%Y%m%d_%H%M%S')}_{uuid.uuid4().hex[:6]}"
        )

    @property
    def total(self) -> int:
        return len(self.questions)

    def current_question(self) -> dict | None:
        if self.index < self.total:
            return self.questions[self.index]
        return None

    def opening_text(self) -> str:
        """开场白 + 第一题（确定性模板，避免依赖一次额外的 LLM 往返）"""
        name = self.profile.get("name") or "您"
        address = self.profile.get("address")
        if not address:
            gender = str(self.profile.get("gender") or "").strip().lower()
            address = "奶奶" if gender in ("f", "女", "female") else "爷爷"
        current = self.current_question()
        if current is None:
            return (
                f"{name}{address}您好，之前的评估题目已经全部完成，我现在为您生成报告。"
            )
        resumed = self.index > 0
        return (
            f"{name}{address}您好，我是健康评估助手。"
            f"{'我们继续上次的评估，' if resumed else f'接下来我会问您 {self.total} 个关于日常生活和身体健康的问题，'}"
            f"大概几分钟，听不清可以说“再说一遍”，不方便回答可以说“跳过”，我们随时可以停下来。"
            f"现在{'继续' if resumed else '开始'}关于{current['topic']}的问题：{current['question']}"
        )

    def record_answer(self, text: str) -> str:
        """记录当前题的回答并推进。返回 'answered' | 'repeat' | 'summary'。"""
        if self.done:
            return "summary"
        text = (text or "").strip()
        if not text:
            return "repeat"

        if _contains(text, STOP_WORDS):
            self.done = True
            return "summary"

        q = self.current_question()
        if q is None:
            self.done = True
            return "summary"

        if _contains(text, REPEAT_WORDS):
            return "repeat"

        self.records.append(
            {
                "id": q["id"],
                "topic": q["topic"],
                "question": q["question"],
                "answer": text,
                "skipped": _contains(text, SKIP_WORDS),
            }
        )
        self.index += 1
        if self.index >= self.total:
            self.done = True
            return "summary"
        return "answered"

    def record_no_response(self) -> str:
        """超时未回答：当前题记为不配合并推进。返回 'answered' | 'summary'。"""
        q = self.current_question()
        if q is None:
            self.done = True
            return "summary"
        self.records.append(
            {
                "id": q["id"],
                "topic": q["topic"],
                "question": q["question"],
                "answer": "（超时未回答）",
                "skipped": True,
                "no_response": True,
            }
        )
        self.index += 1
        if self.index >= self.total:
            self.done = True
            return "summary"
        return "answered"

    def turn_messages(self) -> list:
        """让 LLM 生成『回应上一答 + 下一题』的对话消息。"""
        q = self.current_question()
        prev = self.records[-1] if self.records else None
        lines = [f"老人档案：{json.dumps(self.profile, ensure_ascii=False)}"]
        if prev:
            if prev.get("no_response"):
                status = "没有回答（超时）"
            elif prev["skipped"]:
                status = "选择跳过"
            else:
                status = "回答"
            lines.append(f"上一题（{prev['topic']}）：{prev['question']}")
            lines.append(f"老人{status}：{prev['answer']}")
        lines.append(
            f"下一个要问的题目（{q['topic']}），请原样完整说出：{q['question']}"
        )
        return [{"role": "user", "content": "\n".join(lines)}]

    def transcript_prompt(self) -> str:
        lines = [
            f"记录编号：{self.record_id}",
            f"评估时间：{self.created_at}",
            f"姓名：{self.profile.get('name', '未填写')}；年龄：{self.profile.get('age', '未填写')}；"
            f"性别：{self.profile.get('gender', '未填写')}；主诉备注：{self.profile.get('complaint') or '无'}",
            "",
            "问答记录：",
        ]
        for i, r in enumerate(self.records, 1):
            ans = "（跳过）" if r["skipped"] else r["answer"]
            lines.append(f"{i}. [{r['topic']}] 问：{r['question']}\n   答：{ans}")
        return "\n".join(lines)

    def save_report(self, report_md: str) -> str:
        """保存 Markdown 报告与结构化记录，返回可下载 URL 路径。"""
        REPORT_DIR.mkdir(parents=True, exist_ok=True)
        md_path = REPORT_DIR / f"{self.record_id}.md"
        md_path.write_text(report_md, encoding="utf-8")
        json_path = REPORT_DIR / f"{self.record_id}.json"
        json_path.write_text(
            json.dumps(
                {
                    "record_id": self.record_id,
                    "title": self.title,
                    "created_at": self.created_at,
                    "profile": self.profile,
                    "records": self.records,
                    "report_url": f"/outputs/assessments/{self.record_id}.md",
                },
                ensure_ascii=False,
                indent=2,
            ),
            encoding="utf-8",
        )
        index_path = REPORT_DIR / "index.json"
        try:
            items = (
                json.loads(index_path.read_text(encoding="utf-8"))
                if index_path.exists()
                else []
            )
        except Exception:
            items = []
        items.insert(
            0,
            {
                "record_id": self.record_id,
                "name": self.profile.get("name", ""),
                "age": self.profile.get("age", ""),
                "gender": self.profile.get("gender", ""),
                "created_at": self.created_at,
                "answered": len(self.records),
                "total": self.total,
                "report_url": f"/outputs/assessments/{self.record_id}.md",
            },
        )
        index_path.write_text(
            json.dumps(items, ensure_ascii=False, indent=2), encoding="utf-8"
        )
        return f"/outputs/assessments/{self.record_id}.md"
