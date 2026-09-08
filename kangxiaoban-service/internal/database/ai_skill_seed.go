package database

import (
	"kangxiaoban-service/internal/model"

	"gorm.io/gorm"
)

// defaultAISkills is the starter capability set. Rows are created once by
// code; institutions may edit or disable them afterwards. Instructions are
// advisory fragments injected into the role system prompt by the agent.
var defaultAISkills = []model.AISkill{
	{
		RoleScope: "caregiver", Code: "fall-response", Name: "跌倒应急处置",
		Description: "跌倒/失稳事件的现场处置顺序与上报要点", Version: "1.0.0", Tags: "应急,跌倒,护理",
		SortOrder: 10, Enabled: true, IsBuiltin: true,
		Instructions: "遇到跌倒、失稳、坠床相关问题时：1) 先确认长者意识、呼吸与可见伤情，未排除脊柱损伤不要移动；2) 提醒立即通知值班医师并测量生命体征；3) 处置后按机构流程记录并复核防跌措施（床挡、地面、照明、呼叫器可达）。回答要给出可执行的顺序步骤，并说明仅为参考提示。",
	},
	{
		RoleScope: "caregiver", Code: "vital-observation", Name: "体征观察要点",
		Description: "体温血压心率血氧等异常读数的复核与上报建议", Version: "1.0.0", Tags: "健康,体征",
		SortOrder: 20, Enabled: true, IsBuiltin: true,
		Instructions: "涉及体征数据时：先说明读数本身和机构阈值的关系（可调用 get_elder_health 查询最近记录），单次异常建议复测确认；持续异常或出现危险区间读数时，提醒按流程上报医师。不做诊断结论，不推荐药物。",
	},
	{
		RoleScope: "doctor", Code: "admission-assessment", Name: "入住评估沟通要点",
		Description: "Appendix A/B/C 评估过程中的沟通与核对清单", Version: "1.0.0", Tags: "评估,入住",
		SortOrder: 10, Enabled: true, IsBuiltin: true,
		Instructions: "涉及入住评估时：提示按附录A（基本情况）、附录B（26项能力评估）、附录C（90分结果与等级）的顺序核对；信息提供者回答不确定时如实记录；评估结果为照护计划依据，最终等级以系统评分与医师确认为准。",
	},
	{
		RoleScope: "all", Code: "kb-first", Name: "制度问题先查知识库",
		Description: "涉及机构制度流程规范的问题优先检索知识库", Version: "1.0.0", Tags: "知识库,制度",
		SortOrder: 90, Enabled: true, IsBuiltin: true,
		Instructions: "当用户询问机构制度、流程、规范、应急预案类问题时，优先调用 search_knowledge_base 检索机构知识库并依据检索内容回答；检索不到时明确说明知识库暂无相关内容，不要编造制度条款。",
	},
}

// seedAISkills creates missing builtin skills by code. Existing rows are left
// untouched so institution edits survive restarts. Lookup must be by code
// only: struct conditions on FirstOrCreate put every field into the WHERE and
// would recreate edited rows (see the roles seed for the same trap).
func seedAISkills(db *gorm.DB) error {
	for i := range defaultAISkills {
		skill := defaultAISkills[i]
		var role model.AISkill
		if err := db.Where(model.AISkill{Code: skill.Code}).Attrs(model.AISkill{
			RoleScope: skill.RoleScope, Code: skill.Code, Name: skill.Name,
			Description: skill.Description, Version: skill.Version, Tags: skill.Tags,
			Instructions: skill.Instructions, SortOrder: skill.SortOrder, Enabled: skill.Enabled, IsBuiltin: true,
		}).FirstOrCreate(&role).Error; err != nil {
			return err
		}
	}
	return nil
}
