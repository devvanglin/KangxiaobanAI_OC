package agent

import "testing"

func TestStreamRouterUnicodeBeforeProtocolTagDoesNotPanic(t *testing.T) {
	router := newStreamRouter(nil)
	router.feed("请根据老人的情况先分析：İİİİİİİİİİİİ")
	router.feed("<think>需要查询</think>最终回答")
	router.flush()
	if router.reasoningThink.String() != "需要查询" {
		t.Fatalf("reasoning = %q", router.reasoningThink.String())
	}
	if router.answer.String() != "请根据老人的情况先分析：İİİİİİİİİİİİ最终回答" {
		t.Fatalf("answer = %q", router.answer.String())
	}
}
