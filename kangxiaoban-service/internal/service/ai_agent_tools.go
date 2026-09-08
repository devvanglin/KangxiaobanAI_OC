package service

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"
	"time"

	"kangxiaoban-service/internal/agent"
	"kangxiaoban-service/internal/model"
)

// Institutional read-only tools exposed to the agent. Every tool declares the
// permission it needs; tools whose permission the caller lacks are not
// registered at all, so the model can never see (nor ask for) data the user
// cannot read. All queries run through the tenant-scoped request context.
type agentToolSpec struct {
	requiredPermission string
	definition         *agent.ToolDefinition
}

// buildAgentTools assembles the tool list for one exchange. Work mode carries
// the institutional data tools; both modes keep the knowledge-base search tool
// so ordinary conversation can still consult institutional documents.
func (s *AIService) buildAgentTools(ctx context.Context, connection *model.AIConnection, permissions []string, mode agent.Mode) []*agent.ToolDefinition {
	has := func(code string) bool {
		for _, permission := range permissions {
			if permission == code {
				return true
			}
		}
		return false
	}
	specs := make([]agentToolSpec, 0, 8)
	if mode == agent.ModeWork {
		specs = append(specs,
			agentToolSpec{"elder:read", s.toolGetElders()},
			agentToolSpec{"elder:read", s.toolGetElderDetail()},
			agentToolSpec{"health:read", s.toolGetElderHealth()},
			agentToolSpec{"task:read", s.toolGetTodayTasks()},
			agentToolSpec{"alert:read", s.toolGetAlerts()},
			agentToolSpec{"dash:read", s.toolGetTodaySchedule()},
		)
	}
	specs = append(specs, agentToolSpec{"", s.toolSearchKnowledgeBase(ctx, connection)})

	tools := make([]*agent.ToolDefinition, 0, len(specs))
	for _, spec := range specs {
		if spec.requiredPermission == "" || has(spec.requiredPermission) {
			tools = append(tools, spec.definition)
		}
	}
	// Bridged MCP tools come last so native data tools keep prompt priority.
	tools = append(tools, s.mcpAgentTools(ctx)...)
	return tools
}

func jsonSchema(properties map[string]interface{}, required []string) json.RawMessage {
	schema := map[string]interface{}{"type": "object", "properties": properties}
	if len(required) > 0 {
		schema["required"] = required
	}
	encoded, _ := json.Marshal(schema)
	return encoded
}

func toolArgs(args string, dest interface{}) error {
	trimmed := strings.TrimSpace(args)
	if trimmed == "" {
		return nil
	}
	return json.Unmarshal([]byte(trimmed), dest)
}

func toolJSON(value interface{}) (string, error) {
	encoded, err := json.Marshal(value)
	if err != nil {
		return "", err
	}
	return string(encoded), nil
}

// caregiverCareLevelLabel renders the 1-5 care level in Chinese.
func caregiverCareLevelLabel(level int8) string {
	if level < 1 || level > 5 {
		return fmt.Sprintf("等级%d", level)
	}
	return [...]string{"", "一级", "二级", "三级", "四级", "五级"}[level] + "照护"
}

func elderAge(birthDate string) int {
	parsed, err := time.Parse("2006-01-02", strings.TrimSpace(birthDate))
	if err != nil {
		return 0
	}
	return time.Now().Year() - parsed.Year()
}

func (s *AIService) toolGetElders() *agent.ToolDefinition {
	type args struct {
		Keyword string `json:"keyword"`
		Limit   int    `json:"limit"`
	}
	return &agent.ToolDefinition{
		Name:        "get_elders",
		Description: "查询在院长者名单，可按姓名关键字过滤。返回 id、姓名、性别、年龄、照护等级与床位位置。",
		ParametersJSON: jsonSchema(map[string]interface{}{
			"keyword": map[string]interface{}{"type": "string", "description": "姓名关键字，可省略"},
			"limit":   map[string]interface{}{"type": "integer", "description": "返回数量上限，默认10，最大30"},
		}, nil),
		Handler: func(ctx context.Context, raw string) (string, error) {
			var input args
			if err := toolArgs(raw, &input); err != nil {
				return "", fmt.Errorf("参数格式错误")
			}
			limit := input.Limit
			if limit <= 0 {
				limit = 10
			}
			if limit > 30 {
				limit = 30
			}
			query := s.db.WithContext(ctx).Model(&model.Elder{}).Preload("Bed.Room").Where("status = ?", 2)
			if keyword := strings.TrimSpace(input.Keyword); keyword != "" {
				query = query.Where("name LIKE ?", "%"+keyword+"%")
			}
			var elders []model.Elder
			if err := query.Order("id ASC").Limit(limit).Find(&elders).Error; err != nil {
				return "", err
			}
			rows := make([]map[string]interface{}, 0, len(elders))
			for _, elder := range elders {
				row := map[string]interface{}{
					"id": elder.ID, "name": elder.Name, "gender": elderGenderLabel(elder.Gender),
					"age": elderAge(elder.BirthDate), "care_level": caregiverCareLevelLabel(elder.CareLevel),
				}
				if elder.Bed != nil {
					row["bed_no"] = elder.Bed.BedNo
					if elder.Bed.Room != nil {
						row["room"] = strings.TrimSpace(elder.Bed.Room.Building + " " + elder.Bed.Room.RoomNo)
					}
				}
				rows = append(rows, row)
			}
			return toolJSON(map[string]interface{}{"total_in_list": len(rows), "elders": rows})
		},
	}
}

func elderGenderLabel(gender string) string {
	switch strings.TrimSpace(gender) {
	case "M":
		return "男"
	case "F":
		return "女"
	}
	return gender
}

// elderNamesFor resolves elder display names for tool rows in one query.
func (s *AIService) elderNamesFor(ctx context.Context, tasks []model.CareTask) map[uint]string {
	ids := make([]uint, 0, len(tasks))
	for _, task := range tasks {
		if task.ElderID > 0 {
			ids = append(ids, task.ElderID)
		}
	}
	names := map[uint]string{}
	if len(ids) == 0 {
		return names
	}
	var elders []model.Elder
	if err := s.db.WithContext(ctx).Select("id, name").Where("id IN ?", ids).Find(&elders).Error; err != nil {
		return names
	}
	for _, elder := range elders {
		names[elder.ID] = elder.Name
	}
	return names
}

func (s *AIService) toolGetElderDetail() *agent.ToolDefinition {
	type args struct {
		ElderID uint `json:"elder_id"`
	}
	return &agent.ToolDefinition{
		Name:        "get_elder_detail",
		Description: "按 id 查询单个长者的详细档案：基本信息、过敏史、紧急联系人与最近体征。",
		ParametersJSON: jsonSchema(map[string]interface{}{
			"elder_id": map[string]interface{}{"type": "integer", "description": "长者id"},
		}, []string{"elder_id"}),
		Handler: func(ctx context.Context, raw string) (string, error) {
			var input args
			if err := toolArgs(raw, &input); err != nil || input.ElderID == 0 {
				return "", fmt.Errorf("elder_id 必填")
			}
			var elder model.Elder
			if err := s.db.WithContext(ctx).Preload("Bed.Room").First(&elder, input.ElderID).Error; err != nil {
				return "", fmt.Errorf("长者不存在")
			}
			var records []model.HealthRecord
			_ = s.db.WithContext(ctx).Where("elder_id = ?", elder.ID).
				Order("record_time DESC").Limit(3).Find(&records).Error
			contacts := make([]map[string]interface{}, 0, len(elder.EmergencyContacts))
			for _, contact := range elder.EmergencyContacts {
				contacts = append(contacts, map[string]interface{}{
					"name": contact.Name, "relation": contact.Relation, "phone": contact.Phone,
				})
			}
			latest := make([]map[string]interface{}, 0, len(records))
			for _, record := range records {
				latest = append(latest, healthRecordRow(record))
			}
			detail := map[string]interface{}{
				"id": elder.ID, "name": elder.Name, "gender": elderGenderLabel(elder.Gender),
				"age": elderAge(elder.BirthDate), "care_level": caregiverCareLevelLabel(elder.CareLevel),
				"allergies": elder.Allergies, "emergency_contacts": contacts,
				"remark": elder.Remark, "recent_health": latest,
			}
			if elder.Bed != nil {
				detail["bed_no"] = elder.Bed.BedNo
				if elder.Bed.Room != nil {
					detail["room"] = strings.TrimSpace(elder.Bed.Room.Building + " " + elder.Bed.Room.RoomNo)
				}
			}
			return toolJSON(detail)
		},
	}
}

func healthRecordRow(record model.HealthRecord) map[string]interface{} {
	row := map[string]interface{}{
		"record_time": record.RecordTime.Format("01-02 15:04"), "risk_level": record.RiskLevel,
	}
	if record.Temperature != nil {
		row["temperature"] = *record.Temperature
	}
	if record.Systolic != nil && record.Diastolic != nil {
		row["blood_pressure"] = fmt.Sprintf("%d/%d", *record.Systolic, *record.Diastolic)
	}
	if record.HeartRate != nil {
		row["heart_rate"] = *record.HeartRate
	}
	if record.Spo2 != nil {
		row["spo2"] = *record.Spo2
	}
	if record.RespiratoryRate != nil {
		row["respiratory_rate"] = *record.RespiratoryRate
	}
	if record.IsAbnormal && strings.TrimSpace(record.RiskSummary) != "" {
		row["risk_summary"] = record.RiskSummary
	}
	return row
}

func (s *AIService) toolGetElderHealth() *agent.ToolDefinition {
	type args struct {
		ElderID uint `json:"elder_id"`
		Limit   int  `json:"limit"`
	}
	return &agent.ToolDefinition{
		Name:        "get_elder_health",
		Description: "查询某位长者最近的体征记录（体温、血压、心率、血氧、呼吸等）与风险级别。",
		ParametersJSON: jsonSchema(map[string]interface{}{
			"elder_id": map[string]interface{}{"type": "integer", "description": "长者id"},
			"limit":    map[string]interface{}{"type": "integer", "description": "条数上限，默认8，最大24"},
		}, []string{"elder_id"}),
		Handler: func(ctx context.Context, raw string) (string, error) {
			var input args
			if err := toolArgs(raw, &input); err != nil || input.ElderID == 0 {
				return "", fmt.Errorf("elder_id 必填")
			}
			limit := input.Limit
			if limit <= 0 {
				limit = 8
			}
			if limit > 24 {
				limit = 24
			}
			var records []model.HealthRecord
			if err := s.db.WithContext(ctx).Where("elder_id = ?", input.ElderID).
				Order("record_time DESC").Limit(limit).Find(&records).Error; err != nil {
				return "", err
			}
			rows := make([]map[string]interface{}, 0, len(records))
			for _, record := range records {
				rows = append(rows, healthRecordRow(record))
			}
			return toolJSON(map[string]interface{}{"elder_id": input.ElderID, "records": rows})
		},
	}
}

func (s *AIService) toolGetTodayTasks() *agent.ToolDefinition {
	type args struct {
		Status string `json:"status"`
		Limit  int    `json:"limit"`
	}
	return &agent.ToolDefinition{
		Name:        "get_today_tasks",
		Description: "查询今天的护理任务清单，可按状态过滤（todo 待办 / doing 进行中 / done 已完成）。",
		ParametersJSON: jsonSchema(map[string]interface{}{
			"status": map[string]interface{}{"type": "string", "description": "todo/doing/done，可省略"},
			"limit":  map[string]interface{}{"type": "integer", "description": "条数上限，默认20，最大50"},
		}, nil),
		Handler: func(ctx context.Context, raw string) (string, error) {
			var input args
			if err := toolArgs(raw, &input); err != nil {
				return "", fmt.Errorf("参数格式错误")
			}
			limit := input.Limit
			if limit <= 0 {
				limit = 20
			}
			if limit > 50 {
				limit = 50
			}
			today := time.Now().Format("2006-01-02")
			start, _ := time.ParseInLocation("2006-01-02", today, time.Local)
			end := start.AddDate(0, 0, 1)
			// 不做 join：租户回调会附加裸的 tenant_id 条件，跨表会产生歧义列；
			// 长者姓名通过 elderNamesFor 二次查询补齐。
			query := s.db.WithContext(ctx).Model(&model.CareTask{}).
				Where("care_tasks.due_at >= ? AND care_tasks.due_at < ?", start, end)
			switch strings.TrimSpace(input.Status) {
			case "todo", "doing", "done":
				query = query.Where("care_tasks.status = ?", strings.TrimSpace(input.Status))
			}
			var tasks []model.CareTask
			if err := query.Select("care_tasks.*").
				Order("care_tasks.status ASC, care_tasks.priority ASC, care_tasks.due_at ASC").
				Limit(limit).Find(&tasks).Error; err != nil {
				return "", err
			}
			elderNames := s.elderNamesFor(ctx, tasks)
			rows := make([]map[string]interface{}, 0, len(tasks))
			for _, task := range tasks {
				row := map[string]interface{}{
					"id": task.ID, "title": task.Title, "kind": task.Kind, "status": task.Status,
					"priority": task.Priority, "assignee": task.Assignee,
				}
				if name := elderNames[task.ElderID]; name != "" {
					row["elder"] = name
				}
				if task.DueAt != nil {
					row["due_at"] = task.DueAt.Format("15:04")
				}
				rows = append(rows, row)
			}
			return toolJSON(map[string]interface{}{"date": today, "count": len(rows), "tasks": rows})
		},
	}
}

func (s *AIService) toolGetAlerts() *agent.ToolDefinition {
	type args struct {
		Status string `json:"status"`
		Limit  int    `json:"limit"`
	}
	return &agent.ToolDefinition{
		Name:        "get_alerts",
		Description: "查询最近的告警（跌倒、离床、体征异常等），可按状态过滤（new 未处理 / handled 已处置）。",
		ParametersJSON: jsonSchema(map[string]interface{}{
			"status": map[string]interface{}{"type": "string", "description": "new/handled/closed，默认不限"},
			"limit":  map[string]interface{}{"type": "integer", "description": "条数上限，默认10，最大30"},
		}, nil),
		Handler: func(ctx context.Context, raw string) (string, error) {
			var input args
			if err := toolArgs(raw, &input); err != nil {
				return "", fmt.Errorf("参数格式错误")
			}
			limit := input.Limit
			if limit <= 0 {
				limit = 10
			}
			if limit > 30 {
				limit = 30
			}
			query := s.db.WithContext(ctx).Model(&model.Alert{})
			if status := strings.TrimSpace(input.Status); status != "" {
				query = query.Where("alerts.status = ?", status)
			}
			var alerts []model.Alert
			if err := query.Order("create_time DESC").Limit(limit).Find(&alerts).Error; err != nil {
				return "", err
			}
			rows := make([]map[string]interface{}, 0, len(alerts))
			for _, alert := range alerts {
				rows = append(rows, map[string]interface{}{
					"id": alert.ID, "type": alert.Type, "level": alert.Level, "content": alert.Content,
					"status": alert.Status, "create_time": alert.CreateTime.Format("01-02 15:04"),
				})
			}
			return toolJSON(map[string]interface{}{"count": len(rows), "alerts": rows})
		},
	}
}

func (s *AIService) toolGetTodaySchedule() *agent.ToolDefinition {
	return &agent.ToolDefinition{
		Name:           "get_today_schedule",
		Description:    "查询今天的员工排班（班次与负责区域）。",
		ParametersJSON: jsonSchema(map[string]interface{}{}, nil),
		Handler: func(ctx context.Context, raw string) (string, error) {
			today := time.Now().Format("2006-01-02")
			var schedules []model.Schedule
			if err := s.db.WithContext(ctx).Where("work_date = ?", today).
				Order("shift ASC, id ASC").Limit(40).Find(&schedules).Error; err != nil {
				return "", err
			}
			rows := make([]map[string]interface{}, 0, len(schedules))
			for _, schedule := range schedules {
				rows = append(rows, map[string]interface{}{
					"staff": schedule.Staff, "shift": schedule.Shift, "room_scope": schedule.RoomScope,
				})
			}
			return toolJSON(map[string]interface{}{"date": today, "count": len(rows), "schedules": rows})
		},
	}
}

// toolSearchKnowledgeBase turns the tenant's Dify dataset into an agent tool
// so the model decides when to consult institutional documents. Retrieval
// failures surface as tool errors and never abort the exchange.
func (s *AIService) toolSearchKnowledgeBase(ctx context.Context, connection *model.AIConnection) *agent.ToolDefinition {
	type args struct {
		Query string `json:"query"`
	}
	return &agent.ToolDefinition{
		Name:        "search_knowledge_base",
		Description: "检索机构知识库（护理规范、制度、应急预案等）。涉及流程、制度、处置规范的问题先查这里。",
		ParametersJSON: jsonSchema(map[string]interface{}{
			"query": map[string]interface{}{"type": "string", "description": "检索问题"},
		}, []string{"query"}),
		Handler: func(toolCtx context.Context, raw string) (string, error) {
			var input args
			if err := toolArgs(raw, &input); err != nil || strings.TrimSpace(input.Query) == "" {
				return "", fmt.Errorf("query 必填")
			}
			fragments, err := s.ragRetrieve(toolCtx, connection, strings.TrimSpace(input.Query), 3)
			if err != nil {
				return "", fmt.Errorf("知识库暂时不可用")
			}
			if len(fragments) == 0 {
				return "知识库中没有找到相关内容。", nil
			}
			return strings.Join(fragments, "\n---\n"), nil
		},
	}
}
