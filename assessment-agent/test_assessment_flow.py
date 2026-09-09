import unittest

from core.assessment import AssessmentSession


QUESTIONS = [
    {"id": "q1", "topic": "睡眠", "question": "最近睡得好吗？"},
    {"id": "q2", "topic": "饮食", "question": "最近吃得好吗？"},
]


class AssessmentSessionTests(unittest.TestCase):
    def test_opening_uses_name_and_gendered_address(self):
        male = AssessmentSession({"name": "张三", "gender": "M"}, "测试", QUESTIONS)
        female = AssessmentSession({"name": "李四", "gender": "F"}, "测试", QUESTIONS)
        self.assertTrue(male.opening_text().startswith("张三爷爷您好"))
        self.assertTrue(female.opening_text().startswith("李四奶奶您好"))

    def test_partial_answer_never_advances_without_record_answer(self):
        session = AssessmentSession({"name": "张三", "gender": "M"}, "测试", QUESTIONS)
        self.assertEqual(session.index, 0)
        self.assertEqual(session.current_question()["id"], "q1")
        self.assertEqual(session.record_answer("我睡得还可以，夜里"), "answered")
        self.assertEqual(session.index, 1)

    def test_resume_continues_at_first_unanswered_question(self):
        records = [
            {
                "id": "q1",
                "topic": "睡眠",
                "question": "最近睡得好吗？",
                "answer": "还可以",
                "skipped": False,
            }
        ]
        session = AssessmentSession(
            {"name": "张三", "gender": "M"}, "测试", QUESTIONS, records=records
        )
        self.assertEqual(session.index, 1)
        self.assertEqual(session.current_question()["id"], "q2")
        self.assertIn("继续上次的评估", session.opening_text())


if __name__ == "__main__":
    unittest.main()
