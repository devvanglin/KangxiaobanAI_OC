package healthrisk

import (
	"errors"
	"fmt"
	"strconv"
	"strings"

	"kangxiaoban-service/internal/model"
)

var ErrThresholdMissing = errors.New("health threshold missing")

type metricValue struct {
	code  string
	value *float64
}

// Evaluate calculates one record's aggregate risk exclusively from persisted thresholds.
func Evaluate(record *model.HealthRecord, thresholds []model.HealthThreshold) (string, string, error) {
	byMetric := make(map[string]model.HealthThreshold, len(thresholds))
	for _, threshold := range thresholds {
		if _, exists := byMetric[threshold.Metric]; !exists {
			byMetric[threshold.Metric] = threshold
		}
	}

	metrics := []metricValue{
		{code: "temperature", value: record.Temperature},
		{code: "systolic", value: intAsFloat(record.Systolic)},
		{code: "diastolic", value: intAsFloat(record.Diastolic)},
		{code: "heart_rate", value: intAsFloat(record.HeartRate)},
		{code: "spo2", value: record.Spo2},
		{code: "respiratory_rate", value: intAsFloat(record.RespiratoryRate)},
		{code: "steps", value: intAsFloat(record.Steps)},
		{code: "sleep_hours", value: record.SleepHours},
	}

	level := "normal"
	summaries := make([]string, 0)
	for _, metric := range metrics {
		if metric.value == nil {
			continue
		}
		threshold, ok := byMetric[metric.code]
		if !ok {
			return "", "", fmt.Errorf("%w: %s", ErrThresholdMissing, metric.code)
		}
		if !threshold.Enabled {
			continue
		}
		metricLevel, summary := evaluateMetric(*metric.value, threshold)
		if severity(metricLevel) > severity(level) {
			level = metricLevel
		}
		if summary != "" {
			summaries = append(summaries, summary)
		}
	}
	return level, strings.Join(summaries, "；"), nil
}

// EvaluateMetric evaluates one metric against the same persisted rule set used for full health records.
func EvaluateMetric(metric string, value float64, thresholds []model.HealthThreshold) (string, string, error) {
	for _, threshold := range thresholds {
		if threshold.Metric != metric {
			continue
		}
		if !threshold.Enabled {
			return "normal", "", nil
		}
		level, summary := evaluateMetric(value, threshold)
		return level, summary, nil
	}
	return "", "", fmt.Errorf("%w: %s", ErrThresholdMissing, metric)
}

func evaluateMetric(value float64, threshold model.HealthThreshold) (string, string) {
	if threshold.CriticalMin != nil && value < *threshold.CriticalMin {
		return "danger", formatSummary(value, threshold, "低于危险下限", *threshold.CriticalMin)
	}
	if threshold.CriticalMax != nil && value > *threshold.CriticalMax {
		return "danger", formatSummary(value, threshold, "高于危险上限", *threshold.CriticalMax)
	}
	if threshold.WarningMin != nil && value < *threshold.WarningMin {
		return "warning", formatSummary(value, threshold, "低于关注下限", *threshold.WarningMin)
	}
	if threshold.WarningMax != nil && value > *threshold.WarningMax {
		return "warning", formatSummary(value, threshold, "高于关注上限", *threshold.WarningMax)
	}
	return "normal", ""
}

func formatSummary(value float64, threshold model.HealthThreshold, relation string, boundary float64) string {
	name := strings.TrimSpace(threshold.DisplayName)
	if name == "" {
		name = threshold.Metric
	}
	return fmt.Sprintf("%s %s%s %s %s%s", name, formatNumber(value), threshold.Unit, relation, formatNumber(boundary), threshold.Unit)
}

func formatNumber(value float64) string {
	return strconv.FormatFloat(value, 'f', -1, 64)
}

func intAsFloat(value *int) *float64 {
	if value == nil {
		return nil
	}
	converted := float64(*value)
	return &converted
}

func severity(level string) int {
	switch level {
	case "danger":
		return 2
	case "warning":
		return 1
	default:
		return 0
	}
}
