package database

import (
	"context"
	"errors"

	"gorm.io/gorm"

	"kangxiaoban-service/internal/model"
)

const admissionTemplateCode = "GB_T_42195_2022_ADMISSION"

type admissionOptionSeed struct {
	code  string
	label string
	score int
}

type admissionQuestionSeed struct {
	code, groupCode, groupName, title, guidance string
	maxScore                                    int
	options                                     []admissionOptionSeed
}

type admissionDictionarySeed struct {
	category, code, label string
}

func seedAdmissionReferenceData(db *gorm.DB) error {
	var tenants []model.Tenant
	if err := db.Where("status = ?", 1).Order("id").Find(&tenants).Error; err != nil {
		return err
	}
	for _, tenant := range tenants {
		ctx := context.WithValue(context.Background(), model.TenantContextKey, tenant.ID)
		if err := seedAdmissionTenant(db.WithContext(ctx)); err != nil {
			return err
		}
	}
	return nil
}

func seedAdmissionTenant(db *gorm.DB) error {
	rules := defaultAbilityLevelRules()
	adjustments := defaultAdmissionAdjustmentRules()
	scoringNotes := []string{
		"26项能力题总分90分，所有分数均按服务端选项重新计算。",
		"昏迷直接评定为能力完全丧失（完全失能）。",
		"痴呆F00-F03或其他精神和行为障碍F04-F99，在初步等级上加重一级。",
		"近30天照护风险事件合计达到2次及以上，在初步等级上加重一级。",
	}

	var template model.AssessmentTemplate
	err := db.Where("code = ? AND version = ?", admissionTemplateCode, "2022").First(&template).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		template = model.AssessmentTemplate{
			Code: admissionTemplateCode, Name: "老年人能力评估 A/B/C 入住评估", Version: "2022",
			Description: "依据老年人能力评估基本信息表、26项能力评估表和能力评估报告建立的入住评估流程",
			Category:    "admission_ability", MaxScore: 90, Required: true, Enabled: true, SortOrder: 1,
			LevelRules: rules, AdjustmentRules: adjustments, ScoringNotes: scoringNotes,
		}
		if err := db.Create(&template).Error; err != nil {
			return err
		}
	} else if err != nil {
		return err
	} else {
		// Existing template metadata is institution-owned. Only backfill truly
		// missing rule/note payloads; never rewrite names, descriptions, or
		// enablement after an administrator has edited them.
		updates := map[string]interface{}{}
		if len(template.LevelRules) == 0 {
			updates["level_rules"] = rules
		}
		if !hasExecutableAdjustmentRules(template.AdjustmentRules) {
			updates["adjustment_rules"] = adjustments
		}
		if len(template.ScoringNotes) == 0 {
			updates["scoring_notes"] = scoringNotes
		}
		if len(updates) > 0 {
			if err := db.Model(&template).Updates(updates).Error; err != nil {
				return err
			}
		}
	}

	for order, seed := range admissionQuestionSeeds() {
		var question model.AssessmentQuestion
		err := db.Where("template_id = ? AND code = ?", template.ID, seed.code).First(&question).Error
		if errors.Is(err, gorm.ErrRecordNotFound) {
			question = model.AssessmentQuestion{
				TemplateID: template.ID, Code: seed.code, GroupCode: seed.groupCode, GroupName: seed.groupName,
				Title: seed.title, Guidance: seed.guidance, AnswerType: "choice", Required: true,
				MaxScore: seed.maxScore, SortOrder: order + 1,
			}
			if err := db.Create(&question).Error; err != nil {
				return err
			}
		} else if err != nil {
			return err
		}
		for optionOrder, optionSeed := range seed.options {
			var option model.AssessmentOption
			err := db.Where("question_id = ? AND code = ?", question.ID, optionSeed.code).First(&option).Error
			if errors.Is(err, gorm.ErrRecordNotFound) {
				option = model.AssessmentOption{
					QuestionID: question.ID, Code: optionSeed.code, Label: optionSeed.label,
					Score: optionSeed.score, SortOrder: optionOrder + 1,
				}
				if err := db.Create(&option).Error; err != nil {
					return err
				}
			} else if err != nil {
				return err
			}
		}
	}

	for order, seed := range admissionDictionarySeeds() {
		var item model.AdmissionDictionaryItem
		err := db.Where("template_id = ? AND category = ? AND code = ?", template.ID, seed.category, seed.code).First(&item).Error
		if errors.Is(err, gorm.ErrRecordNotFound) {
			item = model.AdmissionDictionaryItem{
				TemplateID: template.ID, Category: seed.category, Code: seed.code,
				Label: seed.label, SortOrder: order + 1, Enabled: true,
			}
			if err := db.Create(&item).Error; err != nil {
				return err
			}
		} else if err != nil {
			return err
		}
	}

	for order, planSeed := range admissionCarePlanSeeds(template.ID) {
		var plan model.AdmissionCarePlanTemplate
		err := db.Where("template_id = ? AND code = ?", template.ID, planSeed.Code).First(&plan).Error
		if errors.Is(err, gorm.ErrRecordNotFound) {
			planSeed.SortOrder = order + 1
			if err := db.Create(&planSeed).Error; err != nil {
				return err
			}
		} else if err != nil {
			return err
		}
	}
	return seedAdmissionScreeningTemplates(db)
}

func defaultAbilityLevelRules() []model.AbilityLevelRule {
	return []model.AbilityLevelRule{
		{Code: "intact", Label: "能力完好", MinScore: 90, MaxScore: 90, CareLevel: 1, SortOrder: 1},
		{Code: "mild", Label: "能力轻度受损（轻度失能）", MinScore: 66, MaxScore: 89, CareLevel: 2, SortOrder: 2},
		{Code: "moderate", Label: "能力中度受损（中度失能）", MinScore: 46, MaxScore: 65, CareLevel: 3, SortOrder: 3},
		{Code: "severe", Label: "能力重度受损（重度失能）", MinScore: 30, MaxScore: 45, CareLevel: 4, SortOrder: 4},
		{Code: "complete", Label: "能力完全丧失（完全失能）", MinScore: 0, MaxScore: 29, CareLevel: 5, SortOrder: 5},
	}
}

func defaultAdmissionAdjustmentRules() []model.AdmissionAdjustmentRule {
	return []model.AdmissionAdjustmentRule{
		{
			Code: "coma", Label: "昏迷",
			Description: "处于昏迷状态者直接评定为能力完全丧失（完全失能）",
			MatchMode:   "any", TargetLevel: "complete",
			Conditions: []model.AdmissionRuleCondition{
				{Type: "boolean_field", Field: "coma", MatchCodes: []string{"true"}},
				{Type: "answer_option", QuestionCode: "B3.9", MatchCodes: []string{"coma"}},
				{Type: "list_contains", Field: "health_issues", MatchCodes: []string{"coma", "coma_status:present"}},
			},
		},
		{
			Code: "dementia_or_mental_disorder", Label: "痴呆或精神行为障碍",
			Description: "确诊 F00-F03 或 F04-F99 时，在初步能力等级上加重一级",
			MatchMode:   "any", LevelDelta: 1,
			Conditions: []model.AdmissionRuleCondition{
				{Type: "boolean_field", Field: "dementia_or_mental_disorder", MatchCodes: []string{"true"}},
				{Type: "diagnosis_code", MatchCodes: []string{"F00-F03", "F04-F99"}},
			},
		},
		{
			Code: "risk_events_2_plus", Label: "近30天照护风险事件",
			Description: "近30天照护风险事件合计达到2次及以上时，在初步能力等级上加重一级",
			LevelDelta:  1,
			Conditions: []model.AdmissionRuleCondition{{
				Type: "risk_count", RiskCodes: []string{"fall", "wander", "choke", "suicide_self_harm", "other"},
				Operator: "gte", Threshold: 2,
			}},
		},
	}
}

func hasExecutableAdjustmentRules(rules []model.AdmissionAdjustmentRule) bool {
	for _, rule := range rules {
		if len(rule.Conditions) > 0 {
			return true
		}
	}
	return false
}

func standardAssistanceOptions() []admissionOptionSeed {
	return []admissionOptionSeed{
		{"score_4", "独立完成，不需要他人协助", 4},
		{"score_3", "在他人指导或提示下完成", 3},
		{"score_2", "需要他人协助，但以自身完成为主", 2},
		{"score_1", "主要依靠他人协助，自身能给予配合", 1},
		{"score_0", "完全依赖他人协助，且不能给予配合", 0},
	}
}

func cognitionOptions(normal, mild, moderate, severe, complete string) []admissionOptionSeed {
	return []admissionOptionSeed{
		{"score_4", normal, 4}, {"score_3", mild, 3}, {"score_2", moderate, 2},
		{"score_1", severe, 1}, {"score_0", complete, 0},
	}
}

func admissionQuestionSeeds() []admissionQuestionSeed {
	return []admissionQuestionSeed{
		{"B1.1", "B1", "自理能力", "进食", "使用适当器具将食物送入口中并咽下", 4, []admissionOptionSeed{
			{"score_4", "独立使用器具进食并咽下，没有呛咳", 4}, {"score_3", "在指导提示下完成或独立使用辅具，没有呛咳", 3},
			{"score_2", "需要少量接触式协助，偶尔（每月一次及以上）呛咳", 2}, {"score_1", "需要大量接触式协助，经常（每周一次及以上）呛咳", 1},
			{"score_0", "完全依赖他人协助进食，或吞咽困难，或留置营养管", 0},
		}},
		{"B1.2", "B1", "自理能力", "修饰", "洗脸、刷牙、梳头、刮脸、剪指（趾）甲等", 4, standardAssistanceOptions()},
		{"B1.3", "B1", "自理能力", "洗澡", "清洗和擦干身体", 4, standardAssistanceOptions()},
		{"B1.4", "B1", "自理能力", "穿/脱上衣", "穿/脱上身衣服、系扣、拉拉链等", 4, standardAssistanceOptions()},
		{"B1.5", "B1", "自理能力", "穿/脱裤子和鞋袜", "穿/脱裤子、鞋袜等", 4, standardAssistanceOptions()},
		{"B1.6", "B1", "自理能力", "小便控制", "控制和排出尿液的能力", 4, []admissionOptionSeed{
			{"score_4", "可自行控制排尿，排尿次数、排尿控制均正常", 4}, {"score_3", "白天可自行控制，夜间次数增多或控制较差，或自行使用尿布尿垫", 3},
			{"score_2", "白天大部分可控制，偶有尿失禁，或需少量协助使用辅助用物", 2}, {"score_1", "白天大部分不能控制，夜间尿失禁，或需大量协助使用辅助用物", 1},
			{"score_0", "小便失禁、完全不能控制，或留置导尿管", 0},
		}},
		{"B1.7", "B1", "自理能力", "大便控制", "控制和排出粪便的能力", 4, []admissionOptionSeed{
			{"score_4", "可正常自行控制大便排出", 4}, {"score_3", "有时（每周少于1次）便秘或失禁，或自行使用辅助用物", 3},
			{"score_2", "经常（每天少于1次、每周多于1次）便秘或失禁，或需少量协助", 2}, {"score_1", "大部分时间（每天至少1次）便秘或失禁，或需大量协助", 1},
			{"score_0", "严重便秘或完全大便失禁，依赖他人协助排便或清洁皮肤", 0},
		}},
		{"B1.8", "B1", "自理能力", "如厕", "上厕所排泄大小便，并完成解裤、清洁身体和穿裤", 4, standardAssistanceOptions()},
		{"B2.1", "B2", "基础运动能力", "床上体位转移", "卧床翻身及坐起躺下", 4, standardAssistanceOptions()},
		{"B2.2", "B2", "基础运动能力", "床椅转移", "从坐位到站位，再从站位到坐位的转换过程", 4, standardAssistanceOptions()},
		{"B2.3", "B2", "基础运动能力", "平地行走", "双脚交互在地面行动，包括他人辅助和使用辅助具", 4, []admissionOptionSeed{
			{"score_4", "独立平地步行约50米，不需协助，无摔倒风险", 4}, {"score_3", "能步行约50米，需监护指导或使用拐杖、助行器等", 3},
			{"score_2", "步行时需要他人少量扶持协助", 2}, {"score_1", "步行时需要他人大量扶持协助", 1}, {"score_0", "完全不能步行", 0},
		}},
		{"B2.4", "B2", "基础运动能力", "上下楼梯", "双脚交替连续上下10至15个台阶", 3, []admissionOptionSeed{
			{"score_3", "可独立上下楼梯，不需要协助", 3}, {"score_2", "在他人指导或提示下完成", 2},
			{"score_1", "需要他人协助，但以自身完成为主", 1}, {"score_0", "主要依靠或完全依赖他人协助", 0},
		}},
		{"B3.1", "B3", "精神状态", "时间定向", "知道并确认时间的能力", 4, cognitionOptions(
			"年、月清楚，日期或星期可相差一天", "年、月、日或星期不能全部分清", "仅知上半年、下半年或季节", "仅知上午、下午或昼夜", "无时间观念")},
		{"B3.2", "B3", "精神状态", "空间定向", "知道并确认空间的能力", 4, cognitionOptions(
			"能在日常生活范围内单独外出", "不能单独外出，但准确知道所在地地址", "不能单独外出，但知道较多所在地信息", "只知道少量居住地信息", "不能单独外出且无空间观念")},
		{"B3.3", "B3", "精神状态", "人物定向", "知道并确认人物的能力", 4, cognitionOptions(
			"认识长期共同生活的人，能称呼并知道关系", "认识大部分共同生活者，能称呼或知道关系", "认识部分亲人或照护者", "只认识自己或极少数亲人照护者", "不认识任何人，包括自己")},
		{"B3.4", "B3", "精神状态", "记忆", "短时、近期和远期记忆能力", 4, cognitionOptions(
			"保持与社会和年龄相适应的记忆能力，能完整回忆", "轻度记忆紊乱或即时回忆不能", "中度记忆紊乱或近期记忆不能", "重度记忆紊乱或远期记忆不能", "记忆完全紊乱或完全不能正确回忆")},
		{"B3.5", "B3", "精神状态", "理解能力", "理解语言和非语言信息，可借助平时使用的助听设备", 4, cognitionOptions(
			"能正常理解他人的话", "能理解，但需要增加时间", "理解有困难，需频繁重复或简化表达", "理解有严重困难，需要大量帮助", "完全不能理解他人的话")},
		{"B3.6", "B3", "精神状态", "表达能力", "通过口头或非口头方式表达自己想法的能力", 4, cognitionOptions(
			"能正常表达自己的想法", "能表达需要，但需要增加时间", "表达有困难，需频繁重复或简化", "表达有严重困难，需要大量帮助", "完全不能表达需要")},
		{"B3.7", "B3", "精神状态", "攻击行为", "近一个月身体或语言攻击行为", 1, []admissionOptionSeed{{"none", "未出现", 1}, {"present", "近一个月内出现过攻击行为", 0}}},
		{"B3.8", "B3", "精神状态", "抑郁症状", "近一个月情绪低落、兴趣或活力减退等负性情绪", 1, []admissionOptionSeed{{"none", "未出现", 1}, {"present", "近一个月内出现过负性情绪", 0}}},
		{"B3.9", "B3", "精神状态", "意识水平", "机体对自身和周围环境刺激做出应答的能力程度", 2, []admissionOptionSeed{
			{"clear", "神志清醒，对周围环境能做出正确反应", 2},
			{"drowsy_confused", "嗜睡或意识模糊，经呼唤推动可唤醒", 1},
			{"stupor", "昏睡，强烈刺激下短时清醒，刺激减弱后很快入睡", 0},
			{"coma", "昏迷，意识和随意运动丧失，对一般刺激无反应", 0},
		}},
		{"B4.1", "B4", "感知觉与社会参与", "视力", "在个体最好矫正视力下进行评估", 2, []admissionOptionSeed{
			{"normal", "视力正常", 2}, {"limited", "可见大字体或辨认物体，但看不清标准字体或大标题", 1}, {"blind", "只能看到光、颜色和形状，或完全失明", 0},
		}},
		{"B4.2", "B4", "感知觉与社会参与", "听力", "可借助平时使用的助听设备", 2, []admissionOptionSeed{
			{"normal", "听力正常", 2}, {"limited", "轻声或两米外听不清，正常交流需安静环境或大声", 1}, {"deaf", "大声慢速说话仅部分听见，或完全失聪", 0},
		}},
		{"B4.3", "B4", "感知觉与社会参与", "执行日常事务", "计划、安排并完成洗衣、小额购物、服药管理等", 4, standardAssistanceOptions()},
		{"B4.4", "B4", "感知觉与社会参与", "使用交通工具外出", "使用交通工具外出的能力", 3, []admissionOptionSeed{
			{"score_3", "能自己骑车或搭乘公共交通工具外出", 3}, {"score_2", "能自己搭乘出租车，但不会搭乘其他公共交通工具", 2},
			{"score_1", "有人协助或陪伴时可搭乘公共交通工具", 1}, {"score_0", "只能在协助下乘出租车或私家车，或完全不能独立外出", 0},
		}},
		{"B4.5", "B4", "感知觉与社会参与", "社会交往能力", "参与社会并适应社会环境、与人交往的能力", 4, cognitionOptions(
			"参与社会并能适应社会环境，待人接物恰当", "能适应单纯环境并主动接触他人", "脱离社会、仅被动接触，谈话有不适词句", "勉强与人接触，内容不清、表情不当", "不能与人交往")},
	}
}

func admissionDictionarySeeds() []admissionDictionarySeed {
	return []admissionDictionarySeed{
		{"assessment_reason", "first", "首次评估"}, {"assessment_reason", "routine", "常规评估"}, {"assessment_reason", "immediate", "即时评估"}, {"assessment_reason", "reassessment", "对评估结果有疑问进行复评"}, {"assessment_reason", "other", "其他"},
		{"gender", "M", "男"}, {"gender", "F", "女"},
		{"ethnicity", "han", "汉族"}, {"ethnicity", "minority", "少数民族"}, {"ethnicity", "other", "其他"},
		{"religion", "none", "无"}, {"religion", "yes", "有"},
		{"education", "illiterate", "文盲"}, {"education", "primary", "小学"}, {"education", "junior_high", "初中"}, {"education", "senior_secondary", "高中/技校/中专"}, {"education", "college_plus", "大学专科及以上"}, {"education", "unknown", "不详"},
		{"living_situation", "alone", "独居"}, {"living_situation", "spouse", "与配偶居住"}, {"living_situation", "children", "与子女居住"}, {"living_situation", "parents", "与父母居住"}, {"living_situation", "siblings", "与兄弟姐妹居住"}, {"living_situation", "other_relatives", "与其他亲属居住"}, {"living_situation", "non_relatives", "与非亲属关系的人居住"}, {"living_situation", "institution", "养老机构"},
		{"marital_status", "unmarried", "未婚"}, {"marital_status", "married", "已婚"}, {"marital_status", "widowed", "丧偶"}, {"marital_status", "divorced", "离婚"}, {"marital_status", "unspecified", "未说明"},
		{"medical_payment", "employee_insurance", "城镇职工基本医疗保险"}, {"medical_payment", "resident_insurance", "城乡居民基本医疗保险"}, {"medical_payment", "self_pay", "自费"}, {"medical_payment", "civil_servant_subsidy", "公务员补助"}, {"medical_payment", "enterprise_supplement", "企业补充保险"}, {"medical_payment", "public_medical", "公费医疗及医疗照顾对象"}, {"medical_payment", "medical_assistance", "医疗救助"}, {"medical_payment", "critical_illness_insurance", "大病保险"},
		{"income_source", "pension", "退休金/养老金"}, {"income_source", "children_support", "子女补贴"}, {"income_source", "relatives_support", "亲友资助"}, {"income_source", "national_subsidy", "国家普惠型补贴"}, {"income_source", "savings", "个人储蓄"}, {"income_source", "other_subsidy", "其他补贴"},
		{"risk_event", "fall", "跌倒"}, {"risk_event", "wander", "走失"}, {"risk_event", "choke", "噎食"}, {"risk_event", "suicide_self_harm", "自杀、自伤"}, {"risk_event", "other", "其他"},
		{"info_provider_relation", "self", "本人"}, {"info_provider_relation", "spouse", "配偶"}, {"info_provider_relation", "child", "子女"}, {"info_provider_relation", "other_relative", "其他亲属"}, {"info_provider_relation", "paid_caregiver", "雇佣照顾者"}, {"info_provider_relation", "community_staff", "村（居）民委员会工作人员"}, {"info_provider_relation", "other", "其他"},
		{"diagnosis", "I10-I15", "高血压病"}, {"diagnosis", "I25", "冠心病"}, {"diagnosis", "E10-E14", "糖尿病"}, {"diagnosis", "J12-J18", "肺炎"}, {"diagnosis", "J44", "慢性阻塞性肺疾病"}, {"diagnosis", "I60-I62", "脑出血"}, {"diagnosis", "I63", "脑梗塞"}, {"diagnosis", "UTI_30D", "尿路感染（30天内）"}, {"diagnosis", "G20-G22", "帕金森综合征"}, {"diagnosis", "N18-N19", "慢性肾衰竭"}, {"diagnosis", "K74", "肝硬化"}, {"diagnosis", "K20-K31", "消化性溃疡"}, {"diagnosis", "C00-D48", "肿瘤"}, {"diagnosis", "AMPUTATION_6M", "截肢（6个月内）"}, {"diagnosis", "M84", "骨折（3个月内）"}, {"diagnosis", "G40", "癫痫"}, {"diagnosis", "E01-E03", "甲状腺功能减退症"}, {"diagnosis", "H25-H26", "白内障"}, {"diagnosis", "H40-H42", "青光眼"}, {"diagnosis", "M80-M82", "骨质疏松症"}, {"diagnosis", "F00-F03", "痴呆"}, {"diagnosis", "F04-F99", "其他精神和行为障碍"}, {"diagnosis", "other", "其他"},
		{"health_category", "pressure_injury", "压疮"}, {"health_category", "joint_mobility", "关节活动度"}, {"health_category", "wound", "伤口"}, {"health_category", "special_care", "特殊护理"}, {"health_category", "pain", "疼痛"}, {"health_category", "tooth_loss", "牙齿缺损"}, {"health_category", "denture", "义齿"}, {"health_category", "dysphagia", "吞咽问题"}, {"health_category", "malnutrition", "营养不良"}, {"health_category", "airway_clearance", "气道清除能力"},
		{"pressure_injury", "none", "无"}, {"pressure_injury", "stage_1", "I期"}, {"pressure_injury", "stage_2", "II期"}, {"pressure_injury", "stage_3", "III期"}, {"pressure_injury", "stage_4", "IV期"}, {"pressure_injury", "unstageable", "不可分期"},
		{"joint_mobility", "normal", "无，不影响日常生活功能"}, {"joint_mobility", "limited", "是，影响日常生活功能"}, {"joint_mobility", "unknown", "无法判断"},
		{"wound", "none", "无"}, {"wound", "abrasion", "擦伤"}, {"wound", "burn", "烧烫伤"}, {"wound", "postoperative", "术后伤口"}, {"wound", "diabetic_foot", "糖尿病足溃疡"}, {"wound", "vascular_ulcer", "血管性溃疡"}, {"wound", "other", "其他伤口"},
		{"special_care", "none", "无"}, {"special_care", "gastric_tube", "胃管"}, {"special_care", "urinary_catheter", "尿管"}, {"special_care", "tracheotomy", "气管切开"}, {"special_care", "stoma", "胃/肠/膀胱造瘘"}, {"special_care", "noninvasive_ventilator", "无创呼吸机"}, {"special_care", "dialysis", "透析"}, {"special_care", "other", "其他"},
		{"pain", "none", "无疼痛"}, {"pain", "mild", "轻度疼痛"}, {"pain", "moderate", "中度疼痛（尚可忍受）"}, {"pain", "severe", "重度疼痛（无法忍受）"}, {"pain", "unknown", "不知道或无法判断"},
		{"tooth_loss", "none", "无缺损"}, {"tooth_loss", "tooth_defect", "牙体缺损"}, {"tooth_loss", "dentition_defect", "牙列缺损"}, {"tooth_loss", "upper_loss", "上颌牙缺失"}, {"tooth_loss", "lower_loss", "下颌牙缺失"}, {"tooth_loss", "full_loss", "全口牙缺失"},
		{"denture", "none", "无义齿"}, {"denture", "fixed", "固定义齿"}, {"denture", "removable_partial", "可摘局部义齿"}, {"denture", "removable_full_half", "可摘全/半口义齿"},
		{"dysphagia", "none", "无"}, {"dysphagia", "pain", "抱怨吞咽困难或吞咽疼痛"}, {"dysphagia", "cough", "进食或饮水时咳嗽、呛咳"}, {"dysphagia", "oral_residue", "用餐后口中有残余食物"}, {"dysphagia", "oral_leakage", "流质或固体食物从嘴角流失"}, {"dysphagia", "drooling", "流口水"},
		{"malnutrition", "none", "无"}, {"malnutrition", "present", "有"},
		{"airway_clearance", "normal", "无"}, {"airway_clearance", "ineffective", "有"},
		{"coma_status", "none", "无"}, {"coma_status", "present", "有"},
	}
}

func careService(code, title, kind, frequency, instructions, risk string) model.AdmissionCareService {
	return model.AdmissionCareService{Code: code, Title: title, Kind: kind, Frequency: frequency, Instructions: instructions, RiskLevel: risk}
}

func admissionCarePlanSeeds(templateID uint) []model.AdmissionCarePlanTemplate {
	return []model.AdmissionCarePlanTemplate{
		{TemplateID: templateID, Code: "care_intact", Name: "能力完好基础照护方案", TargetLevel: "intact", Target: "维持独立生活能力并促进社会参与", Enabled: true, BaseServices: []model.AdmissionCareService{
			careService("health_weekly", "基础健康观察", "health", "每周1次", "记录一般状态和基础体征，异常及时上报", "low"),
			careService("activity_daily", "社会活动支持", "activity", "每日", "鼓励自主选择并参与适宜活动", "low"),
			careService("medication_reminder", "用药提醒", "medication", "按医嘱", "核对医嘱并提供提醒，不替代医嘱", "low"),
		}},
		{TemplateID: templateID, Code: "care_mild", Name: "轻度失能照护方案", TargetLevel: "mild", Target: "以提示、监护和风险预防维持现有能力", Enabled: true, BaseServices: []model.AdmissionCareService{
			careService("adl_prompt", "日常生活提示", "daily_living", "每日3次", "进食、修饰、穿衣和如厕以提示监护为主", "medium"),
			careService("fall_round", "防跌倒巡视", "round", "每班2次", "检查助行器、地面、照明和呼叫器", "medium"),
			careService("health_daily", "生命体征观察", "health", "每日1次", "记录体温、血压、心率及异常情况", "medium"),
			careService("medication_manage", "用药管理", "medication", "按医嘱", "执行三查七对并记录服药情况", "medium"),
		}},
		{TemplateID: templateID, Code: "care_moderate", Name: "中度失能照护方案", TargetLevel: "moderate", Target: "提供部分协助，预防跌倒、误吸和失禁相关风险", Enabled: true, BaseServices: []model.AdmissionCareService{
			careService("adl_assist", "日常生活协助", "daily_living", "每日4次", "按评估结果协助进食、洗漱、穿衣和如厕", "medium"),
			careService("transfer_assist", "转移与步行协助", "mobility", "每次转移", "使用适宜辅具并由照护人员在旁协助", "high"),
			careService("continence_care", "排泄照护", "continence", "每4小时评估", "记录排泄并保持皮肤清洁干燥", "medium"),
			careService("nutrition_watch", "营养与吞咽观察", "nutrition", "每餐", "观察摄入量、咀嚼吞咽和呛咳情况", "high"),
			careService("health_twice_daily", "生命体征监测", "health", "每日2次", "记录基础体征并按阈值上报", "medium"),
		}},
		{TemplateID: templateID, Code: "care_severe", Name: "重度失能照护方案", TargetLevel: "severe", Target: "提供全面生活照护并重点预防压伤、误吸和坠床", Enabled: true, BaseServices: []model.AdmissionCareService{
			careService("full_adl", "全面生活照护", "daily_living", "按需及每班", "完成进食、清洁、穿衣、如厕等照护并记录", "high"),
			careService("turn_q2h", "翻身与体位管理", "pressure_injury", "每2小时", "按计划翻身，检查受压部位并留痕", "high"),
			careService("feeding_safety", "进食与吞咽安全", "nutrition", "每餐", "采取适宜体位和食物性状，观察误吸征象", "high"),
			careService("bed_fall_prevention", "坠床与跌倒预防", "safety", "持续及每班检查", "检查床栏、呼叫器、转移辅具和环境", "high"),
			careService("health_q8h", "生命体征监测", "health", "每8小时", "按计划监测并及时处置异常", "high"),
		}},
		{TemplateID: templateID, Code: "care_complete", Name: "完全失能重点照护方案", TargetLevel: "complete", Target: "实施24小时重点照护，维护生命安全和基本舒适", Enabled: true, BaseServices: []model.AdmissionCareService{
			careService("intensive_24h", "24小时重点照护", "intensive_care", "持续", "每班完整交接意识、呼吸、循环、皮肤和管路状态", "critical"),
			careService("turn_q2h_complete", "翻身与皮肤保护", "pressure_injury", "每2小时", "翻身减压并检查记录皮肤完整性", "critical"),
			careService("airway_aspiration", "气道与误吸预防", "airway", "每2小时及按需", "保持适宜体位，观察呼吸和误吸征象", "critical"),
			careService("tube_care", "管路与特殊护理", "special_care", "每班及按医嘱", "核对固定、通畅、引流和局部皮肤情况", "critical"),
			careService("health_q4h", "生命体征与意识监测", "health", "每4小时", "记录体征和意识变化，异常立即上报", "critical"),
		}},
	}
}
