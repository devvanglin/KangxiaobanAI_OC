package service

import (
	"regexp"
	"strconv"
	"strings"

	"kangxiaoban-service/internal/model"
)

// admissionRuleContext is the normalized input exposed to the data-driven
// rule interpreter. It deliberately contains no template-specific codes.
type admissionRuleContext struct {
	Answers        []model.AdmissionAssessmentAnswer
	BooleanFields  map[string]bool
	Lists          map[string][]string
	Diagnoses      []string
	RiskEvents     []model.AdmissionRiskEvent
	EducationYears *int
}

type admissionRuleOutcome struct {
	LevelTargets []string
	LevelDelta   int
	ScoreDelta   int
	Reasons      []string
}

var admissionCodeRangePattern = regexp.MustCompile(`^([A-Z]+)([0-9]+)-([A-Z]*)([0-9]+)$`)
var admissionCodeValuePattern = regexp.MustCompile(`^([A-Z]+)([0-9]+)$`)

func evaluateAdmissionAdjustmentRules(rules []model.AdmissionAdjustmentRule, context admissionRuleContext) admissionRuleOutcome {
	outcome := admissionRuleOutcome{}
	for _, rule := range rules {
		if !admissionRuleMatches(rule, context) {
			continue
		}
		if rule.TargetLevel != "" {
			outcome.LevelTargets = append(outcome.LevelTargets, rule.TargetLevel)
		}
		if rule.LevelDelta > outcome.LevelDelta {
			// Multiple independent triggers may match, but the strongest
			// configured worsening is applied only once.
			outcome.LevelDelta = rule.LevelDelta
		}
		outcome.ScoreDelta += rule.ScoreDelta
		reason := strings.TrimSpace(rule.Description)
		if reason == "" {
			reason = strings.TrimSpace(rule.Label)
		}
		if reason != "" {
			outcome.Reasons = append(outcome.Reasons, reason)
		}
	}
	return outcome
}

func admissionRuleMatches(rule model.AdmissionAdjustmentRule, context admissionRuleContext) bool {
	if len(rule.Conditions) == 0 {
		return false
	}
	if strings.EqualFold(strings.TrimSpace(rule.MatchMode), "all") {
		for _, condition := range rule.Conditions {
			if !admissionConditionMatches(condition, context) {
				return false
			}
		}
		return true
	}
	for _, condition := range rule.Conditions {
		if admissionConditionMatches(condition, context) {
			return true
		}
	}
	return false
}

func admissionConditionMatches(condition model.AdmissionRuleCondition, context admissionRuleContext) bool {
	typeName := strings.ToLower(strings.TrimSpace(condition.Type))
	switch typeName {
	case "answer", "answer_option", "answer_match":
		for _, answer := range context.Answers {
			if condition.QuestionCode != "" && !strings.EqualFold(answer.QuestionCode, condition.QuestionCode) {
				continue
			}
			if anyAdmissionCodeMatches(answer.OptionCode, condition.MatchCodes) {
				return true
			}
		}
		return false
	case "boolean", "boolean_field":
		value, ok := context.BooleanFields[condition.Field]
		if !ok || !value {
			return false
		}
		if len(condition.MatchCodes) == 0 {
			return true
		}
		return anyAdmissionCodeMatches("true", condition.MatchCodes)
	case "diagnosis", "diagnosis_code":
		for _, diagnosis := range context.Diagnoses {
			if anyAdmissionCodeMatches(diagnosis, condition.MatchCodes) {
				return true
			}
		}
		return false
	case "list", "list_contains":
		values, ok := context.Lists[condition.Field]
		if !ok {
			return false
		}
		for _, value := range values {
			if anyAdmissionCodeMatches(value, condition.MatchCodes) {
				return true
			}
		}
		return false
	case "risk", "risk_count":
		count := 0
		for _, event := range context.RiskEvents {
			if len(condition.RiskCodes) == 0 || anyAdmissionCodeMatches(event.Code, condition.RiskCodes) {
				count += event.Count
			}
		}
		return admissionCompareThreshold(count, condition.Threshold, condition.Operator)
	case "education", "education_years":
		if context.EducationYears == nil {
			return false
		}
		return admissionCompareThreshold(*context.EducationYears, condition.Threshold, condition.Operator)
	default:
		return false
	}
}

func admissionCompareThreshold(value, threshold int, operator string) bool {
	switch strings.ToLower(strings.TrimSpace(operator)) {
	case "gt", ">":
		return value > threshold
	case "gte", ">=":
		return value >= threshold
	case "lt", "<":
		return value < threshold
	case "lte", "<=":
		return value <= threshold
	case "eq", "=", "==", "":
		return value == threshold
	case "neq", "!=":
		return value != threshold
	default:
		return false
	}
}

func anyAdmissionCodeMatches(value string, patterns []string) bool {
	for _, pattern := range patterns {
		if admissionCodeMatches(value, pattern) {
			return true
		}
	}
	return false
}

func admissionCodeMatches(value, pattern string) bool {
	value = strings.ToUpper(strings.TrimSpace(value))
	pattern = strings.ToUpper(strings.TrimSpace(pattern))
	if value == "" || pattern == "" {
		return false
	}
	if value == pattern {
		return true
	}
	if strings.HasSuffix(pattern, "*") {
		return strings.HasPrefix(value, strings.TrimSuffix(pattern, "*"))
	}
	if matches, ok := admissionCodeRange(value, pattern); ok {
		return matches
	}
	return value == pattern
}

func admissionCodeRange(value, pattern string) (bool, bool) {
	parts := admissionCodeRangePattern.FindStringSubmatch(pattern)
	if len(parts) != 5 {
		return false, false
	}
	valueParts := admissionCodeValuePattern.FindStringSubmatch(value)
	if len(valueParts) != 3 {
		return false, true
	}
	start, startErr := strconv.Atoi(parts[2])
	end, endErr := strconv.Atoi(parts[4])
	current, currentErr := strconv.Atoi(valueParts[2])
	if startErr != nil || endErr != nil || currentErr != nil {
		return false, true
	}
	startPrefix := parts[1]
	endPrefix := parts[3]
	if endPrefix == "" {
		endPrefix = startPrefix
	}
	// A malformed/reversed range is treated as a non-match rather than an
	// accidental wildcard. Prefixes are compared lexicographically, which is
	// sufficient for the ICD ranges used by the admission dictionaries (and
	// supports ranges such as C00-D48).
	if startPrefix > endPrefix || (startPrefix == endPrefix && start > end) {
		return false, true
	}
	if valueParts[1] < startPrefix || valueParts[1] > endPrefix {
		return false, true
	}
	if startPrefix == endPrefix {
		return current >= start && current <= end, true
	}
	if valueParts[1] == startPrefix {
		return current >= start, true
	}
	if valueParts[1] == endPrefix {
		return current <= end, true
	}
	return true, true
}

// adjustmentRulesRequireEducationYears reports whether an incomplete
// education predicate could still change a rule outcome. A rule with
// match_mode=all needs education only after every other predicate matches; a
// match_mode=any needs it only when no other predicate has matched.
func adjustmentRulesRequireEducationYears(rules []model.AdmissionAdjustmentRule, context admissionRuleContext) bool {
	if context.EducationYears != nil {
		return false
	}
	for _, rule := range rules {
		hasEducation := false
		otherMatched := false
		otherCount := 0
		for _, condition := range rule.Conditions {
			typeName := strings.ToLower(strings.TrimSpace(condition.Type))
			if typeName == "education" || typeName == "education_years" {
				hasEducation = true
				continue
			}
			otherCount++
			if admissionConditionMatches(condition, context) {
				otherMatched = true
			}
		}
		if !hasEducation {
			continue
		}
		if strings.EqualFold(strings.TrimSpace(rule.MatchMode), "all") {
			if otherMatched || otherCount == 0 {
				// For all-mode, all non-education predicates must match. If
				// there are multiple non-education predicates, check them all.
				allOtherMatched := true
				for _, condition := range rule.Conditions {
					typeName := strings.ToLower(strings.TrimSpace(condition.Type))
					if typeName != "education" && typeName != "education_years" && !admissionConditionMatches(condition, context) {
						allOtherMatched = false
						break
					}
				}
				if allOtherMatched {
					return true
				}
			}
			continue
		}
		// any-mode (and the historical default) is undecided only when no
		// non-education condition already makes the rule true.
		if !otherMatched {
			return true
		}
	}
	return false
}

func allowedAdmissionRiskCodes(rules []model.AdmissionAdjustmentRule) (map[string]bool, bool) {
	allowed := map[string]bool{}
	found := false
	for _, rule := range rules {
		for _, condition := range rule.Conditions {
			typeName := strings.ToLower(strings.TrimSpace(condition.Type))
			if typeName != "risk" && typeName != "risk_count" {
				continue
			}
			found = true
			if len(condition.RiskCodes) == 0 {
				// An empty list intentionally means that every risk code is
				// accepted; the rule still controls whether it changes a level.
				return nil, true
			}
			for _, code := range condition.RiskCodes {
				code = strings.ToUpper(strings.TrimSpace(code))
				if code != "" {
					allowed[code] = true
				}
			}
		}
	}
	return allowed, found
}
