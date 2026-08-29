package database

import (
	"errors"
	"fmt"

	"gorm.io/gorm"

	"kangxiaoban-service/internal/model"
)

type admissionScreeningTemplateSeed struct {
	code, name, version, description string
	maxScore, sortOrder              int
	levelRules                       []model.AbilityLevelRule
	adjustmentRules                  []model.AdmissionAdjustmentRule
	scoringNotes                     []string
	questions                        []admissionScreeningQuestionSeed
}

type admissionScreeningQuestionSeed struct {
	code, groupCode, groupName, title, guidance string
	maxScore                                    int
	required                                    bool
	options                                     []admissionOptionSeed
}

func seedAdmissionScreeningTemplates(db *gorm.DB) error {
	for _, seed := range admissionScreeningTemplateSeeds() {
		var template model.AssessmentTemplate
		err := db.Where("code = ? AND version = ?", seed.code, seed.version).First(&template).Error
		attrs := model.AssessmentTemplate{
			Name: seed.name, Description: seed.description, Category: "admission_screening",
			MaxScore: seed.maxScore, Required: false, Enabled: true, SortOrder: seed.sortOrder,
			LevelRules: seed.levelRules, AdjustmentRules: seed.adjustmentRules, ScoringNotes: seed.scoringNotes,
		}
		if errors.Is(err, gorm.ErrRecordNotFound) {
			template = attrs
			template.Code = seed.code
			template.Version = seed.version
			if err := db.Create(&template).Error; err != nil {
				return err
			}
		} else if err != nil {
			return err
		} else {
			updates := map[string]interface{}{
				"name": attrs.Name, "description": attrs.Description, "category": attrs.Category,
				"max_score": attrs.MaxScore, "required": attrs.Required, "enabled": attrs.Enabled,
				"sort_order": attrs.SortOrder,
			}
			if len(template.LevelRules) == 0 && len(seed.levelRules) > 0 {
				updates["level_rules"] = seed.levelRules
			}
			if !hasExecutableAdjustmentRules(template.AdjustmentRules) && len(seed.adjustmentRules) > 0 {
				updates["adjustment_rules"] = seed.adjustmentRules
			}
			if len(template.ScoringNotes) == 0 && len(seed.scoringNotes) > 0 {
				updates["scoring_notes"] = seed.scoringNotes
			}
			if err := db.Model(&template).Updates(updates).Error; err != nil {
				return err
			}
		}

		for order, questionSeed := range seed.questions {
			var question model.AssessmentQuestion
			err := db.Where("template_id = ? AND code = ?", template.ID, questionSeed.code).First(&question).Error
			if errors.Is(err, gorm.ErrRecordNotFound) {
				question = model.AssessmentQuestion{TemplateID: template.ID, Code: questionSeed.code}
				if err := db.Create(&question).Error; err != nil {
					return err
				}
			} else if err != nil {
				return err
			}
			if err := db.Model(&question).Updates(map[string]interface{}{
				"group_code": questionSeed.groupCode, "group_name": questionSeed.groupName,
				"title": questionSeed.title, "guidance": questionSeed.guidance, "answer_type": "choice",
				"required": questionSeed.required, "max_score": questionSeed.maxScore, "sort_order": order + 1,
			}).Error; err != nil {
				return err
			}
			for optionOrder, optionSeed := range questionSeed.options {
				var option model.AssessmentOption
				err := db.Where("question_id = ? AND code = ?", question.ID, optionSeed.code).First(&option).Error
				if errors.Is(err, gorm.ErrRecordNotFound) {
					option = model.AssessmentOption{QuestionID: question.ID, Code: optionSeed.code}
					if err := db.Create(&option).Error; err != nil {
						return err
					}
				} else if err != nil {
					return err
				}
				if err := db.Model(&option).Updates(map[string]interface{}{
					"label": optionSeed.label, "score": optionSeed.score, "sort_order": optionOrder + 1,
				}).Error; err != nil {
					return err
				}
			}
		}
	}
	return nil
}

func admissionScreeningTemplateSeeds() []admissionScreeningTemplateSeed {
	return []admissionScreeningTemplateSeed{
		gad7ScreeningSeed(),
		gds15ScreeningSeed(),
		sleepScreeningSeed(),
		miniCogScreeningSeed(),
		mmseScreeningSeed(),
		mocaScreeningSeed(),
	}
}

func gad7ScreeningSeed() admissionScreeningTemplateSeed {
	questions := []string{
		"在最近两周里，您是否感觉紧张、焦虑或急切？",
		"在最近两周里，您是否不能够停止或控制担忧？",
		"在最近两周里，您是否对各种各样的事情担忧过多？",
		"在最近两周里，您是否很难放松下来？",
		"在最近两周里，您是否由于不安而无法静坐？",
		"在最近两周里，您是否变得容易烦恼或急躁？",
		"在最近两周里，您是否感到似乎将有可怕的事情发生而害怕？",
	}
	items := make([]admissionScreeningQuestionSeed, 0, len(questions))
	for i, title := range questions {
		items = append(items, admissionScreeningQuestionSeed{
			code: fmt.Sprintf("GAD7.%d", i+1), groupCode: "GAD7", groupName: "焦虑症状",
			title: title, guidance: "按最近两周出现频率作答", maxScore: 3, required: true,
			options: []admissionOptionSeed{{"none", "没有", 0}, {"several_days", "有几天", 1}, {"half_days", "一半天数", 2}, {"nearly_every_day", "几乎每天", 3}},
		})
	}
	return admissionScreeningTemplateSeed{
		code: "GAD7", name: "广泛性焦虑量表（GAD-7）", version: "PDF_APPENDIX_5", description: "PDF 附表5，评估最近两周焦虑症状频率。",
		maxScore: 21, sortOrder: 10, questions: items,
		scoringNotes: []string{"7题分别计0-3分，总分0-21分。", "附表未提供严重度或诊断阈值，本流程仅记录总分。"},
	}
}

func gds15ScreeningSeed() admissionScreeningTemplateSeed {
	questions := []struct {
		title      string
		yesIsScore bool
	}{
		{"您对生活基本上满意吗？", false},
		{"您是否放弃了许多活动和兴趣爱好？", true},
		{"您是否觉得生活空虚？", true},
		{"您是否常感到厌倦？", true},
		{"您是否大部分时间感觉精神好？", false},
		{"您是否害怕会有不幸的事落到你头上？", true},
		{"您是否大部分时间感到快乐？", false},
		{"您是否常感有无助的感觉？", true},
		{"您是否愿意呆在家里而不愿去做些新鲜事？", true},
		{"您是否觉得记忆力比大多数人差？", true},
		{"您是否认为现在活着很惬意？", false},
		{"您是否觉得像现在这样活着毫无意义？", true},
		{"您是否觉得您的处境没有帮助？", true},
		{"您是否觉得大多数人处境比你好？", true},
		{"您集中精力有困难吗？", true},
	}
	items := make([]admissionScreeningQuestionSeed, 0, len(questions))
	for i, item := range questions {
		yesScore, noScore := 0, 1
		if item.yesIsScore {
			yesScore, noScore = 1, 0
		}
		items = append(items, admissionScreeningQuestionSeed{
			code: fmt.Sprintf("GDS15.%d", i+1), groupCode: "GDS15", groupName: "抑郁症状",
			title: item.title, guidance: "选择最符合近一周感受的答案", maxScore: 1, required: true,
			options: yesNoOptions(yesScore, noScore),
		})
	}
	return admissionScreeningTemplateSeed{
		code: "GDS15", name: "老年抑郁量表（GDS-15）", version: "PDF_APPENDIX_6", description: "PDF 附表6，按近一周感受进行老年抑郁症状筛查。",
		maxScore: 15, sortOrder: 11, questions: items,
		scoringNotes: []string{"按附表阴影答案计1分，其余计0分，总分0-15分。", "附表未提供诊断阈值，本流程仅记录总分。"},
	}
}

func sleepScreeningSeed() admissionScreeningTemplateSeed {
	return admissionScreeningTemplateSeed{
		code: "SLEEP5", name: "睡眠问题筛查", version: "PDF_APPENDIX_7", description: "PDF 附表7，记录过去一个月的睡眠问题。",
		maxScore: 0, sortOrder: 12,
		levelRules:   screeningRules([]screeningRuleSeed{{"recorded", "已记录睡眠问题答案", 0, 0}}),
		scoringNotes: []string{"附表未设置计分或分级，本流程仅保存5项是/否答案。", "第1题可在 answer_text 中记录平均睡眠小时数。"},
		questions: []admissionScreeningQuestionSeed{
			{code: "SLEEP5.1", groupCode: "SLEEP", groupName: "睡眠问题", title: "在过去一个月您觉得您的睡眠足够吗？", guidance: "够回答“是”，不够回答“否”；可在备注中记录平均几个小时", maxScore: 0, required: true, options: yesNoOptions(0, 0)},
			{code: "SLEEP5.2", groupCode: "SLEEP", groupName: "睡眠问题", title: "您睡觉的时候容易醒吗？", guidance: "醒来之后超过20分钟睡不着", maxScore: 0, required: true, options: yesNoOptions(0, 0)},
			{code: "SLEEP5.3", groupCode: "SLEEP", groupName: "睡眠问题", title: "在过去一个月里您使用过安眠药来帮助您睡眠吗？", maxScore: 0, required: true, options: yesNoOptions(0, 0)},
			{code: "SLEEP5.4", groupCode: "SLEEP", groupName: "睡眠问题", title: "您是否经常上床之后睡不着？", guidance: "入睡困难超过30分钟", maxScore: 0, required: true, options: yesNoOptions(0, 0)},
			{code: "SLEEP5.5", groupCode: "SLEEP", groupName: "睡眠问题", title: "您是否有晚上睡了而白天仍然想打瞌睡？", maxScore: 0, required: true, options: yesNoOptions(0, 0)},
		},
	}
}

func miniCogScreeningSeed() admissionScreeningTemplateSeed {
	return admissionScreeningTemplateSeed{
		code: "MINI_COG", name: "简易智力状态评估量表（Mini-Cog）", version: "PDF_APPENDIX_8", description: "PDF 附表8，包含三个词语回忆和画钟测验。",
		maxScore: 5, sortOrder: 13,
		levelRules: screeningRules([]screeningRuleSeed{
			{"positive", "可能存在认知功能受损", 0, 2}, {"negative", "未见明显认知功能受损", 3, 5},
		}),
		scoringNotes: []string{"词语回忆0-3分；画钟完全正确2分，否则0分；总分0-5分。", "结果为筛查提示，不能替代临床诊断。"},
		questions: []admissionScreeningQuestionSeed{
			{code: "MINICOG.WORD_SET", groupCode: "MEMORY", groupName: "三个词语记忆", title: "本次使用的词语组", guidance: "从附表六组词语中选择一组", maxScore: 0, required: true, options: []admissionOptionSeed{
				{"group_1", "香蕉、朝阳、椅子", 0}, {"group_2", "领袖、季节、桌子", 0}, {"group_3", "村庄、厨房、婴儿", 0},
				{"group_4", "河流、国家、手指", 0}, {"group_5", "船长、花园、照片", 0}, {"group_6", "女儿、天堂、高山", 0},
			}},
			{code: "MINICOG.RECALL", groupCode: "MEMORY", groupName: "三个词语回忆", title: "不提示时回忆出的词语数", guidance: "回忆一个词语得1分", maxScore: 3, required: true, options: scoreOptions(3)},
			{code: "MINICOG.CLOCK", groupCode: "CLOCK", groupName: "画钟测验", title: "画钟测验", guidance: "数字齐全、顺序和位置大致正确，且指针指向11点10分时得2分；任一错误或拒绝测试计0分", maxScore: 2, required: true, options: []admissionOptionSeed{{"incorrect", "不正确或拒绝测试", 0}, {"correct", "完全正确", 2}}},
		},
	}
}

func mmseScreeningSeed() admissionScreeningTemplateSeed {
	return admissionScreeningTemplateSeed{
		code: "MMSE", name: "简明精神状态评估量表（MMSE）", version: "PDF_APPENDIX_9", description: "PDF 附表9，简明精神状态评估，总分30分。",
		maxScore: 30, sortOrder: 14,
		scoringNotes: []string{"各项目按附表正确项计分，总分0-30分。", "附表未提供教育分层诊断阈值，本流程仅记录总分。"},
		questions: []admissionScreeningQuestionSeed{
			scoredScreeningQuestion("MMSE.TIME", "ORIENTATION", "定向力", "时间定向", "年、季节、月份、日期、星期各1分", 5),
			scoredScreeningQuestion("MMSE.PLACE", "ORIENTATION", "定向力", "地点定向", "城市、区县、街道乡镇、楼层、具体地点各1分", 5),
			scoredScreeningQuestion("MMSE.REGISTER", "MEMORY", "记忆", "即刻记忆", "皮球、国旗、树木，第一遍每正确复述一个得1分", 3),
			scoredScreeningQuestion("MMSE.SERIAL7", "ATTENTION", "注意和计算", "100连续减7", "93、86、79、72、65，每个正确答案1分", 5),
			scoredScreeningQuestion("MMSE.RECALL", "MEMORY", "记忆", "延迟回忆", "回忆皮球、国旗、树木，每个1分", 3),
			scoredScreeningQuestion("MMSE.NAMING", "LANGUAGE", "语言", "命名", "手表和铅笔各1分", 2),
			scoredScreeningQuestion("MMSE.REPEAT", "LANGUAGE", "语言", "复述", "正确复述“大家齐心协力拉紧绳”得1分", 1),
			scoredScreeningQuestion("MMSE.COMMAND", "LANGUAGE", "语言", "三步指令", "右手拿纸、双手对折、放腿上，每步1分", 3),
			scoredScreeningQuestion("MMSE.READING", "LANGUAGE", "语言", "阅读并执行", "读懂“请您闭上眼睛”并照做得1分", 1),
			scoredScreeningQuestion("MMSE.WRITING", "LANGUAGE", "语言", "写完整句子", "由受试者自己写，有主语、谓语和一定内容得1分", 1),
			scoredScreeningQuestion("MMSE.COPY", "VISUAL", "视空间", "临摹交叉五边形", "两个五边形交叉形成四边形，角数正确得1分", 1),
		},
	}
}

func mocaScreeningSeed() admissionScreeningTemplateSeed {
	return admissionScreeningTemplateSeed{
		code: "MOCA_BEIJING", name: "蒙特利尔认知评估量表（MoCA）北京版", version: "PDF_APPENDIX_10", description: "PDF 附表10，MoCA北京版，总分30分。",
		maxScore: 30, sortOrder: 15,
		adjustmentRules: []model.AdmissionAdjustmentRule{{
			Code: "moca_education_bonus", Label: "受教育年限校正",
			Description: "受教育年限不超过12年时加1分，校正后最高不超过量表满分",
			Conditions:  []model.AdmissionRuleCondition{{Type: "education_years", Operator: "lte", Threshold: 12}},
			ScoreDelta:  1,
		}},
		levelRules: screeningRules([]screeningRuleSeed{
			{"positive", "认知功能受损筛查提示", 0, 25}, {"normal_range", "未见明显认知功能受损", 26, 30},
		}),
		scoringNotes: []string{"各项目原始总分0-30分。", "受教育年限不超过12年时加1分，校正后最高30分；完成量表必须提供 education_years。", "校正分低于26分为筛查提示，不能替代临床诊断。"},
		questions: []admissionScreeningQuestionSeed{
			scoredScreeningQuestion("MOCA.VIS_EXEC", "VISUAL", "视空间与执行功能", "视空间与执行功能", "交替连线1分、复制立方体1分、画钟轮廓/数字/指针各1分", 5),
			scoredScreeningQuestion("MOCA.NAMING", "NAMING", "命名", "动物命名", "狮子、犀牛、骆驼各1分", 3),
			{code: "MOCA.LEARNING", groupCode: "MEMORY", groupName: "记忆", title: "两次词语学习记录", guidance: "面孔、天鹅绒、教堂、菊花、红色；学习试验不计分，可在 answer_text 中记录", maxScore: 0, required: false, options: []admissionOptionSeed{{"recorded", "已记录", 0}}},
			scoredScreeningQuestion("MOCA.DIGITS", "ATTENTION", "注意", "数字广度", "顺背21854、倒背742，每项1分", 2),
			scoredScreeningQuestion("MOCA.VIGILANCE", "ATTENTION", "注意", "目标字母检测", "读到字母A时敲击；错误少于2个得1分", 1),
			scoredScreeningQuestion("MOCA.SERIAL7", "ATTENTION", "注意", "100连续减7", "4-5个正确3分，2-3个正确2分，1个正确1分，全部错误0分", 3),
			scoredScreeningQuestion("MOCA.REPEAT", "LANGUAGE", "语言", "句子复述", "正确复述“我只知道今天张亮是来帮过忙的人”和“狗在房间的时候，猫总是躲在沙发下面”，每句1分", 2),
			scoredScreeningQuestion("MOCA.FLUENCY", "LANGUAGE", "语言", "词语流畅性", "1分钟内尽可能多说出动物的名字，11个及以上得1分", 1),
			scoredScreeningQuestion("MOCA.ABSTRACT", "ABSTRACTION", "抽象", "词语相似性", "火车-自行车、手表-尺子各1分", 2),
			scoredScreeningQuestion("MOCA.RECALL", "MEMORY", "延迟回忆", "延迟回忆", "不提示回忆面孔、天鹅绒、教堂、菊花、红色，每词1分", 5),
			scoredScreeningQuestion("MOCA.ORIENTATION", "ORIENTATION", "定向", "定向", "日期、月份、年代、星期、地点、城市各1分", 6),
		},
	}
}

type screeningRuleSeed struct {
	code, label string
	minScore    int
	maxScore    int
}

func screeningRules(seeds []screeningRuleSeed) []model.AbilityLevelRule {
	rules := make([]model.AbilityLevelRule, 0, len(seeds))
	for i, seed := range seeds {
		rules = append(rules, model.AbilityLevelRule{
			Code: seed.code, Label: seed.label, MinScore: seed.minScore, MaxScore: seed.maxScore, SortOrder: i + 1,
		})
	}
	return rules
}

func scoredScreeningQuestion(code, groupCode, groupName, title, guidance string, maxScore int) admissionScreeningQuestionSeed {
	return admissionScreeningQuestionSeed{
		code: code, groupCode: groupCode, groupName: groupName, title: title, guidance: guidance,
		maxScore: maxScore, required: true, options: scoreOptions(maxScore),
	}
}

func scoreOptions(maxScore int) []admissionOptionSeed {
	options := make([]admissionOptionSeed, 0, maxScore+1)
	for score := 0; score <= maxScore; score++ {
		options = append(options, admissionOptionSeed{
			code: fmt.Sprintf("score_%d", score), label: fmt.Sprintf("%d分", score), score: score,
		})
	}
	return options
}

func yesNoOptions(yesScore, noScore int) []admissionOptionSeed {
	return []admissionOptionSeed{{"yes", "是", yesScore}, {"no", "否", noScore}}
}
