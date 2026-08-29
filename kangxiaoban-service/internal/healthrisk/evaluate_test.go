package healthrisk

import (
	"errors"
	"strings"
	"testing"

	"kangxiaoban-service/internal/model"
)

func TestEvaluateUsesPersistedBoundaries(t *testing.T) {
	warningMin := 36.0
	warningMax := 37.3
	criticalMin := 35.0
	criticalMax := 39.0
	threshold := model.HealthThreshold{
		Metric: "temperature", DisplayName: "体温", Unit: "℃", Enabled: true,
		WarningMin: &warningMin, WarningMax: &warningMax, CriticalMin: &criticalMin, CriticalMax: &criticalMax,
	}

	value := 38.2
	level, summary, err := Evaluate(&model.HealthRecord{Temperature: &value}, []model.HealthThreshold{threshold})
	if err != nil {
		t.Fatal(err)
	}
	if level != "warning" || !strings.Contains(summary, "高于关注上限") {
		t.Fatalf("unexpected warning result: level=%q summary=%q", level, summary)
	}

	criticalMax = 38.0
	threshold.CriticalMax = &criticalMax
	level, summary, err = Evaluate(&model.HealthRecord{Temperature: &value}, []model.HealthThreshold{threshold})
	if err != nil {
		t.Fatal(err)
	}
	if level != "danger" || !strings.Contains(summary, "高于危险上限") {
		t.Fatalf("unexpected danger result: level=%q summary=%q", level, summary)
	}
}

func TestEvaluateRejectsMissingThresholdAndHonorsDisabledMetric(t *testing.T) {
	temperature := 38.2
	if _, _, err := Evaluate(&model.HealthRecord{Temperature: &temperature}, nil); !errors.Is(err, ErrThresholdMissing) {
		t.Fatalf("missing threshold error = %v, want ErrThresholdMissing", err)
	}

	level, summary, err := Evaluate(&model.HealthRecord{Temperature: &temperature}, []model.HealthThreshold{{
		Metric: "temperature", Enabled: false,
	}})
	if err != nil {
		t.Fatal(err)
	}
	if level != "normal" || summary != "" {
		t.Fatalf("disabled threshold should skip risk: level=%q summary=%q", level, summary)
	}
}
