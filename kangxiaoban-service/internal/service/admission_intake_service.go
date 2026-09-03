package service

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"math"
	"strconv"
	"strings"
	"sync"
	"time"
	"unicode/utf8"

	"gorm.io/gorm"

	"kangxiaoban-service/internal/model"
)

// AdmissionIntakeInput is the payload for the operational intake form. It is
// intentionally smaller than AdmissionDraftInput and does not contain
// assessment answers or client-provided scores.
type AdmissionIntakeInput struct {
	IdempotencyKey     string   `json:"idempotency_key"`
	ElderID            *uint    `json:"elder_id"`
	ResidentName       string   `json:"resident_name"`
	Gender             string   `json:"gender"`
	BirthDate          string   `json:"birth_date"`
	Age                int      `json:"age"`
	IDCard             string   `json:"id_card"`
	ContactPhone       string   `json:"contact_phone"`
	FamilyAddress      string   `json:"family_address"`
	FamilyName         string   `json:"family_name"`
	FamilyPhone        string   `json:"family_phone"`
	FamilyRelation     string   `json:"family_relation"`
	AdmissionStartDate string   `json:"admission_start_date"`
	AdmissionEndDate   string   `json:"admission_end_date"`
	FeeStartDate       string   `json:"fee_start_date"`
	FeeEndDate         string   `json:"fee_end_date"`
	RoomType           string   `json:"room_type"`
	CareLevel          string   `json:"care_level"`
	BedID              uint     `json:"bed_id"`
	Deposit            float64  `json:"deposit"`
	CareFee            float64  `json:"care_fee"`
	BedFee             float64  `json:"bed_fee"`
	OtherFee           float64  `json:"other_fee"`
	MedicalInsurance   float64  `json:"medical_insurance"`
	Subsidy            float64  `json:"subsidy"`
	Note               string   `json:"note"`
	PhotoUploadKeys    []string `json:"photo_upload_keys"`
}

// AdmissionIntakeResult is returned after the transaction commits. The
// status on Intake means the operational admission completed; it does not
// imply an AdmissionAssessment was performed.
type AdmissionIntakeResult struct {
	Intake     model.AdmissionIntake `json:"intake"`
	Elder      model.Elder           `json:"elder"`
	Bed        model.Bed             `json:"bed"`
	CarePlan   *model.CarePlan       `json:"care_plan,omitempty"`
	Bill       *model.Bill           `json:"bill,omitempty"`
	Idempotent bool                  `json:"idempotent"`
}

type normalizedIntakeInput struct {
	AdmissionIntakeInput
	GenderCode    string
	CareLevelNum  int8
	CareLevelCode string
	Start         time.Time
	RequestHash   string
}

// intakeFingerprintPayload contains normalized business inputs. The
// idempotency key is intentionally excluded: a retry with the same key can be
// compared with the original request, while equivalent display labels hash to
// the same canonical values.
type intakeFingerprintPayload struct {
	ElderID            uint     `json:"elder_id,omitempty"`
	ResidentName       string   `json:"resident_name"`
	Gender             string   `json:"gender"`
	BirthDate          string   `json:"birth_date"`
	Age                int      `json:"age"`
	IDCard             string   `json:"id_card"`
	ContactPhone       string   `json:"contact_phone"`
	FamilyAddress      string   `json:"family_address"`
	FamilyName         string   `json:"family_name"`
	FamilyPhone        string   `json:"family_phone"`
	FamilyRelation     string   `json:"family_relation"`
	AdmissionStartDate string   `json:"admission_start_date"`
	AdmissionEndDate   string   `json:"admission_end_date"`
	FeeStartDate       string   `json:"fee_start_date"`
	FeeEndDate         string   `json:"fee_end_date"`
	RoomType           string   `json:"room_type"`
	CareLevel          int8     `json:"care_level"`
	CareLevelCode      string   `json:"care_level_code"`
	BedID              uint     `json:"bed_id"`
	Deposit            float64  `json:"deposit"`
	CareFee            float64  `json:"care_fee"`
	BedFee             float64  `json:"bed_fee"`
	OtherFee           float64  `json:"other_fee"`
	MedicalInsurance   float64  `json:"medical_insurance"`
	Subsidy            float64  `json:"subsidy"`
	Note               string   `json:"note"`
	PhotoUploadKeys    []string `json:"photo_upload_keys,omitempty"`
}

// errAdmissionIntakeDuplicateKey is internal control flow used when the
// database's idempotency unique index tells a concurrent request that another
// request has already claimed the same key. It is converted to an idempotent
// response after the transaction has ended.
var errAdmissionIntakeDuplicateKey = errors.New("admission intake idempotency key already claimed")

// The database unique index is the cross-process safety net. This mutex keeps
// retries from the same service instance from doing duplicate downstream work
// before the final unique insert (which is especially useful with SQLite).
var admissionIntakeIdempotencyMu sync.Mutex

// GetIntake returns an operational intake in the caller's tenant.  The
// admission:read route already limits this operation to authenticated
// institution staff; unlike a draft assessment, a completed intake is a
// shared operational record and is therefore not restricted to its creator.
func (s *AdmissionService) GetIntake(ctx context.Context, actor AdmissionActor, id uint) (*AdmissionIntakeResult, error) {
	if actor.UserID == 0 {
		return nil, ErrAdmissionForbidden
	}
	if id == 0 {
		return nil, fmt.Errorf("%w: intake id is required", ErrAdmissionValidation)
	}
	return s.loadIntakeResult(s.db.WithContext(ctx), id)
}

// ListIntakes returns completed operational intake orders in the caller's
// tenant.  `mine` is useful for an operator's own audit view while the normal
// doctor/admin view can inspect all orders in that tenant.
func (s *AdmissionService) ListIntakes(ctx context.Context, actor AdmissionActor, status string, mine bool, page, size int) ([]model.AdmissionIntake, int64, error) {
	if actor.UserID == 0 {
		return nil, 0, ErrAdmissionForbidden
	}
	if status != "" && status != "completed" {
		return nil, 0, fmt.Errorf("%w: invalid status", ErrAdmissionValidation)
	}
	if page < 1 {
		page = 1
	}
	if size < 1 {
		size = 10
	}
	if size > 200 {
		size = 200
	}
	q := s.db.WithContext(ctx).Model(&model.AdmissionIntake{})
	if status == "" {
		q = q.Where("status = ?", "completed")
	} else {
		q = q.Where("status = ?", status)
	}
	if mine {
		q = q.Where("assessor_id = ?", actor.UserID)
	}
	var total int64
	if err := q.Count(&total).Error; err != nil {
		return nil, 0, err
	}
	items := make([]model.AdmissionIntake, 0)
	if err := q.Order("updated_at desc, id desc").Offset((page - 1) * size).Limit(size).Find(&items).Error; err != nil {
		return nil, 0, err
	}
	return items, total, nil
}

// CreateIntake atomically creates an admitted elder and all operational
// records needed by the basic intake form. It never creates an assessment or
// invents ability scores.
func (s *AdmissionService) CreateIntake(ctx context.Context, actor AdmissionActor, input AdmissionIntakeInput) (*AdmissionIntakeResult, error) {
	if actor.UserID == 0 {
		return nil, ErrAdmissionForbidden
	}
	normalized, err := normalizeAdmissionIntake(input)
	if err != nil {
		return nil, err
	}

	result := &AdmissionIntakeResult{}
	db := s.db.WithContext(ctx)
	if normalized.IdempotencyKey != "" {
		admissionIntakeIdempotencyMu.Lock()
		defer admissionIntakeIdempotencyMu.Unlock()
	}
	err = db.Transaction(func(tx *gorm.DB) error {
		now := time.Now()
		var claimed *model.AdmissionIntake
		// A repeated request with the same key returns the already committed
		// intake. The service mutex plus the database unique index protect
		// retries both in one process and across multiple server processes. A
		// provisional row claims a new key before downstream records are made;
		// it is committed only together with the completed intake.
		if normalized.IdempotencyKey != "" {
			var existing model.AdmissionIntake
			findErr := tx.Where("idempotency_key = ?", normalized.IdempotencyKey).First(&existing).Error
			if findErr == nil {
				if existing.RequestHash == "" || existing.RequestHash != normalized.RequestHash {
					return ErrAdmissionIdempotencyConflict
				}
				if existing.AssessorID != actor.UserID && !actor.IsAdmin {
					return ErrAdmissionForbidden
				}
				if existing.Status != "completed" {
					return ErrAdmissionInvalidState
				}
				loaded, loadErr := s.loadIntakeResult(tx, existing.ID)
				if loadErr != nil {
					return loadErr
				}
				loaded.Idempotent = true
				*result = *loaded
				return nil
			} else if !errors.Is(findErr, gorm.ErrRecordNotFound) {
				return findErr
			}
			claim := model.AdmissionIntake{
				IntakeNo: newIntakeNo(), IdempotencyKey: normalized.IdempotencyKey, RequestHash: normalized.RequestHash, AssessorID: actor.UserID,
				ResidentNameSnapshot: normalized.ResidentName, ResidentIDCardSnapshot: normalized.IDCard,
				ResidentGenderSnapshot: normalized.GenderCode, ResidentBirthDateSnapshot: normalized.BirthDate,
				ResidentAgeSnapshot: normalized.Age,
				CareLevel:           normalized.CareLevelNum, CareLevelCode: normalized.CareLevelCode,
				AdmissionStartDate: normalized.AdmissionStartDate, AdmissionEndDate: normalized.AdmissionEndDate,
				FeeStartDate: normalized.FeeStartDate, FeeEndDate: normalized.FeeEndDate, RoomType: normalized.RoomType,
				FamilyAddress: normalized.FamilyAddress, FamilyName: normalized.FamilyName, FamilyPhone: normalized.FamilyPhone,
				FamilyRelation: normalized.FamilyRelation, Deposit: normalized.Deposit, CareFee: normalized.CareFee,
				BedFee: normalized.BedFee, OtherFee: normalized.OtherFee, MedicalInsurance: normalized.MedicalInsurance,
				Subsidy: normalized.Subsidy, Note: normalized.Note, Status: "processing",
			}
			if createErr := tx.Create(&claim).Error; createErr != nil {
				if isAdmissionIntakeIdempotencyConstraintError(createErr) {
					return errAdmissionIntakeDuplicateKey
				}
				return createErr
			}
			claimed = &claim
		}

		elder, err := s.createIntakeElder(tx, normalized)
		if err != nil {
			return err
		}
		bed, err := occupyAdmissionBedForRoomType(tx, &normalized.BedID, elder.ID, normalized.RoomType)
		if err != nil {
			return err
		}
		// Claim the elder with the same compare-and-set guard used for beds.
		// The initial read in createIntakeElder is only a friendly validation;
		// two admission requests can otherwise both observe an unadmitted linked
		// elder and leave two beds occupied while the elder points at whichever
		// request updates last.  Keeping this update inside the transaction makes
		// the lifecycle transition atomic on MySQL as well as SQLite.
		updatedElder := tx.Model(&model.Elder{}).
			Where("id = ? AND status <> ? AND bed_id IS NULL", elder.ID, 2).
			Updates(map[string]interface{}{"status": 2, "bed_id": bed.ID})
		if updatedElder.Error != nil {
			return updatedElder.Error
		}
		if updatedElder.RowsAffected != 1 {
			return ErrAdmissionElderConflict
		}
		if err := updateAdmissionRoomStatus(tx, bed.RoomID); err != nil {
			return err
		}

		planTemplate, err := intakePlanTemplate(tx, normalized.CareLevelCode)
		if err != nil {
			return err
		}
		caregiver, err := firstAvailableCaregiver(tx)
		if err != nil {
			return err
		}
		var caregiverID *uint
		caregiverName := ""
		if caregiver != nil {
			caregiverID = &caregiver.ID
			caregiverName = strings.TrimSpace(caregiver.RealName)
			if caregiverName == "" {
				caregiverName = caregiver.Username
			}
		}
		carePlan, err := createCarePlanFromTemplate(tx, elder.ID, actor.UserID, caregiverID, caregiverName,
			planTemplate, nil, normalized.Start)
		if err != nil {
			return err
		}
		if err := createAdmissionTasksAt(tx, elder.ID, caregiverID, caregiverName, carePlan.Items, normalized.Start); err != nil {
			return err
		}
		if normalized.AdmissionEndDate != "" {
			carePlan.EndDate = normalized.AdmissionEndDate
			if err := tx.Model(&model.CarePlan{}).Where("id = ?", carePlan.ID).Update("end_date", normalized.AdmissionEndDate).Error; err != nil {
				return err
			}
		}

		bill, err := createIntakeBill(tx, elder.ID, normalized)
		if err != nil {
			return err
		}
		if normalized.Deposit > 0 {
			flow := model.FundFlow{ElderID: elder.ID, Direction: "in", RelatedMonth: feeMonth(normalized),
				Reason: "入住押金", Amount: normalized.Deposit}
			if err := tx.Create(&flow).Error; err != nil {
				return err
			}
		}

		notification := model.Notification{
			Role: "caregiver", Channel: "in_app", Type: "admission_intake_completed", Severity: "important",
			Title: "新长者已办理入住", Content: fmt.Sprintf("%s 已完成办理入住并分配床位，请执行照护计划。", normalized.ResidentName), SentAt: &now,
		}
		if err := tx.Create(&notification).Error; err != nil {
			return err
		}

		intake := model.AdmissionIntake{
			IntakeNo: newIntakeNo(), IdempotencyKey: normalized.IdempotencyKey, RequestHash: normalized.RequestHash, AssessorID: actor.UserID,
			ResidentNameSnapshot: normalized.ResidentName, ResidentIDCardSnapshot: normalized.IDCard,
			ResidentGenderSnapshot: normalized.GenderCode, ResidentBirthDateSnapshot: normalized.BirthDate,
			ResidentAgeSnapshot: normalized.Age,
			CareLevel:           normalized.CareLevelNum, CareLevelCode: normalized.CareLevelCode,
			ElderID: elder.ID, BedID: bed.ID, AdmissionStartDate: normalized.AdmissionStartDate,
			AdmissionEndDate: normalized.AdmissionEndDate, FeeStartDate: normalized.FeeStartDate,
			FeeEndDate: normalized.FeeEndDate, RoomType: normalized.RoomType, FamilyAddress: normalized.FamilyAddress,
			FamilyName: normalized.FamilyName, FamilyPhone: normalized.FamilyPhone, FamilyRelation: normalized.FamilyRelation,
			Deposit: normalized.Deposit, CareFee: normalized.CareFee, BedFee: normalized.BedFee, OtherFee: normalized.OtherFee,
			MedicalInsurance: normalized.MedicalInsurance, Subsidy: normalized.Subsidy, Note: normalized.Note,
			Status: "completed", CompletedAt: &now, CarePlanID: uintPointer(carePlan.ID),
		}
		if bill != nil {
			intake.BillID = uintPointer(bill.ID)
		}
		if claimed != nil {
			intake.ID = claimed.ID
			intake.IntakeNo = claimed.IntakeNo
			updated := tx.Model(&model.AdmissionIntake{}).
				Where("id = ? AND status = ?", claimed.ID, "processing").
				Updates(map[string]interface{}{
					"request_hash": intake.RequestHash, "assessor_id": intake.AssessorID, "elder_id": intake.ElderID, "bed_id": intake.BedID,
					"resident_name_snapshot": intake.ResidentNameSnapshot, "resident_id_card_snapshot": intake.ResidentIDCardSnapshot,
					"resident_gender_snapshot": intake.ResidentGenderSnapshot, "resident_birth_date_snapshot": intake.ResidentBirthDateSnapshot,
					"resident_age_snapshot": intake.ResidentAgeSnapshot,
					"care_level":            intake.CareLevel, "care_level_code": intake.CareLevelCode,
					"admission_start_date": intake.AdmissionStartDate, "admission_end_date": intake.AdmissionEndDate,
					"fee_start_date": intake.FeeStartDate, "fee_end_date": intake.FeeEndDate, "room_type": intake.RoomType,
					"family_address": intake.FamilyAddress, "family_name": intake.FamilyName, "family_phone": intake.FamilyPhone,
					"family_relation": intake.FamilyRelation, "deposit": intake.Deposit, "care_fee": intake.CareFee,
					"bed_fee": intake.BedFee, "other_fee": intake.OtherFee, "medical_insurance": intake.MedicalInsurance,
					"subsidy": intake.Subsidy, "note": intake.Note, "status": "completed", "completed_at": now,
					"care_plan_id": intake.CarePlanID, "bill_id": intake.BillID,
				})
			if updated.Error != nil {
				return updated.Error
			}
			if updated.RowsAffected != 1 {
				return ErrAdmissionInvalidState
			}
		} else if err := tx.Create(&intake).Error; err != nil {
			if normalized.IdempotencyKey != "" && isAdmissionIntakeIdempotencyConstraintError(err) {
				return errAdmissionIntakeDuplicateKey
			}
			return err
		}
		if err := attachAdmissionPhotos(tx, actor, intake.ID, intake.ElderID, normalized.PhotoUploadKeys); err != nil {
			return err
		}
		audit := model.AuditLog{UserID: actor.UserID, Action: "create", Module: "admission_intake", Method: "POST", Path: "/api/v1/admission-intakes"}
		if err := tx.Create(&audit).Error; err != nil {
			return err
		}
		loaded, err := s.loadIntakeResult(tx, intake.ID)
		if err != nil {
			return err
		}
		*result = *loaded
		return nil
	})
	if errors.Is(err, errAdmissionIntakeDuplicateKey) {
		// The winner must have committed before the unique insert reported a
		// conflict. Reload it using the request tenant scope and return the
		// same result without emitting a duplicate event.
		var existing model.AdmissionIntake
		findErr := db.Where("idempotency_key = ?", normalized.IdempotencyKey).First(&existing).Error
		if findErr != nil {
			return nil, findErr
		}
		if existing.AssessorID != actor.UserID && !actor.IsAdmin {
			return nil, ErrAdmissionForbidden
		}
		if existing.RequestHash == "" || existing.RequestHash != normalized.RequestHash {
			return nil, ErrAdmissionIdempotencyConflict
		}
		if existing.Status != "completed" {
			return nil, ErrAdmissionInvalidState
		}
		loaded, loadErr := s.loadIntakeResult(db, existing.ID)
		if loadErr != nil {
			return nil, loadErr
		}
		loaded.Idempotent = true
		return loaded, nil
	}
	if err != nil {
		return nil, err
	}
	if !result.Idempotent && s.events != nil {
		s.events.SendToRole(result.Intake.TenantID, "caregiver", "admission.intake.completed", map[string]interface{}{
			"intake_id": result.Intake.ID, "intake_no": result.Intake.IntakeNo,
			"elder_id": result.Intake.ElderID, "bed_id": result.Intake.BedID,
		})
	}
	return result, nil
}

func normalizeAdmissionIntake(input AdmissionIntakeInput) (normalizedIntakeInput, error) {
	input.IdempotencyKey = strings.TrimSpace(input.IdempotencyKey)
	input.ResidentName = strings.TrimSpace(input.ResidentName)
	input.Gender = strings.TrimSpace(input.Gender)
	input.BirthDate = strings.TrimSpace(input.BirthDate)
	input.IDCard = strings.TrimSpace(input.IDCard)
	input.ContactPhone = strings.TrimSpace(input.ContactPhone)
	input.FamilyAddress = strings.TrimSpace(input.FamilyAddress)
	input.FamilyName = strings.TrimSpace(input.FamilyName)
	input.FamilyPhone = strings.TrimSpace(input.FamilyPhone)
	input.FamilyRelation = strings.TrimSpace(input.FamilyRelation)
	input.AdmissionStartDate = strings.TrimSpace(input.AdmissionStartDate)
	input.AdmissionEndDate = strings.TrimSpace(input.AdmissionEndDate)
	input.FeeStartDate = strings.TrimSpace(input.FeeStartDate)
	input.FeeEndDate = strings.TrimSpace(input.FeeEndDate)
	input.RoomType = strings.TrimSpace(input.RoomType)
	input.CareLevel = strings.TrimSpace(input.CareLevel)
	input.Note = strings.TrimSpace(input.Note)
	if input.IdempotencyKey == "" {
		return normalizedIntakeInput{}, fmt.Errorf("%w: idempotency_key is required", ErrAdmissionValidation)
	}
	for field, value := range map[string]string{
		"resident_name": input.ResidentName, "gender": input.Gender, "birth_date": input.BirthDate,
		"id_card": input.IDCard, "admission_start_date": input.AdmissionStartDate,
	} {
		if value == "" {
			return normalizedIntakeInput{}, fmt.Errorf("%w: %s is required", ErrAdmissionValidation, field)
		}
	}
	if input.BedID == 0 {
		return normalizedIntakeInput{}, fmt.Errorf("%w: bed_id is required", ErrAdmissionValidation)
	}
	gender, err := normalizeIntakeGender(input.Gender)
	if err != nil {
		return normalizedIntakeInput{}, err
	}
	level, levelCode, err := normalizeIntakeCareLevel(input.CareLevel)
	if err != nil {
		return normalizedIntakeInput{}, err
	}
	roomType, err := normalizeIntakeRoomType(input.RoomType)
	if err != nil {
		return normalizedIntakeInput{}, err
	}
	input.RoomType = roomType
	start, err := parseIntakeDate(input.AdmissionStartDate, "admission_start_date")
	if err != nil {
		return normalizedIntakeInput{}, err
	}
	birthDate, err := parseIntakeDate(input.BirthDate, "birth_date")
	if err != nil {
		return normalizedIntakeInput{}, err
	}
	if birthDate.After(start) {
		return normalizedIntakeInput{}, fmt.Errorf("%w: birth_date must not be after admission_start_date", ErrAdmissionValidation)
	}
	var admissionEnd *time.Time
	if input.AdmissionEndDate != "" {
		parsedEnd, endErr := parseIntakeDate(input.AdmissionEndDate, "admission_end_date")
		if endErr != nil {
			return normalizedIntakeInput{}, endErr
		}
		if parsedEnd.Before(start) {
			return normalizedIntakeInput{}, fmt.Errorf("%w: admission_end_date must not precede admission_start_date", ErrAdmissionValidation)
		}
		admissionEnd = &parsedEnd
	}
	expectedAge := ageAtDate(birthDate, start)
	if input.Age != expectedAge {
		return normalizedIntakeInput{}, fmt.Errorf("%w: age does not match birth_date at admission_start_date", ErrAdmissionValidation)
	}
	feeStart := input.FeeStartDate
	if feeStart != "" {
		feeStartTime, parseErr := parseIntakeDate(feeStart, "fee_start_date")
		if parseErr != nil {
			return normalizedIntakeInput{}, parseErr
		}
		if feeStartTime.Before(start) {
			return normalizedIntakeInput{}, fmt.Errorf("%w: fee_start_date must not precede admission_start_date", ErrAdmissionValidation)
		}
		if admissionEnd != nil && feeStartTime.After(*admissionEnd) {
			return normalizedIntakeInput{}, fmt.Errorf("%w: fee_start_date must not follow admission_end_date", ErrAdmissionValidation)
		}
		if input.FeeEndDate != "" {
			feeEndTime, endErr := parseIntakeDate(input.FeeEndDate, "fee_end_date")
			if endErr != nil {
				return normalizedIntakeInput{}, endErr
			}
			if feeEndTime.Before(start) {
				return normalizedIntakeInput{}, fmt.Errorf("%w: fee_end_date must not precede admission_start_date", ErrAdmissionValidation)
			}
			if admissionEnd != nil && feeEndTime.After(*admissionEnd) {
				return normalizedIntakeInput{}, fmt.Errorf("%w: fee_end_date must not follow admission_end_date", ErrAdmissionValidation)
			}
			if feeEndTime.Before(feeStartTime) {
				return normalizedIntakeInput{}, fmt.Errorf("%w: fee_end_date must not precede fee_start_date", ErrAdmissionValidation)
			}
		}
	} else if input.FeeEndDate != "" {
		return normalizedIntakeInput{}, fmt.Errorf("%w: fee_start_date is required when fee_end_date is set", ErrAdmissionValidation)
	}
	limits := map[string]int{
		"idempotency_key": 128, "resident_name": 50, "id_card": 28,
		"contact_phone": 32, "family_address": 500, "family_name": 64,
		"family_phone": 32, "family_relation": 32, "note": 1000,
	}
	for field, limit := range limits {
		var value string
		switch field {
		case "idempotency_key":
			value = input.IdempotencyKey
		case "resident_name":
			value = input.ResidentName
		case "id_card":
			value = input.IDCard
		case "contact_phone":
			value = input.ContactPhone
		case "family_address":
			value = input.FamilyAddress
		case "family_name":
			value = input.FamilyName
		case "family_phone":
			value = input.FamilyPhone
		case "family_relation":
			value = input.FamilyRelation
		case "note":
			value = input.Note
		}
		if utf8.RuneCountInString(value) > limit {
			return normalizedIntakeInput{}, fmt.Errorf("%w: %s exceeds %d characters", ErrAdmissionValidation, field, limit)
		}
	}
	for field, value := range map[string]float64{
		"deposit": input.Deposit, "care_fee": input.CareFee, "bed_fee": input.BedFee,
		"other_fee": input.OtherFee, "medical_insurance": input.MedicalInsurance, "subsidy": input.Subsidy,
	} {
		if math.IsNaN(value) || math.IsInf(value, 0) || value < 0 || value > 100000000 {
			return normalizedIntakeInput{}, fmt.Errorf("%w: %s must be between 0 and 100000000", ErrAdmissionValidation, field)
		}
	}
	if input.Age < 1 || input.Age > 130 {
		return normalizedIntakeInput{}, fmt.Errorf("%w: age must be between 1 and 130", ErrAdmissionValidation)
	}
	normalized := normalizedIntakeInput{AdmissionIntakeInput: input, GenderCode: gender, CareLevelNum: level,
		CareLevelCode: levelCode, Start: start}
	normalized.RequestHash, err = hashAdmissionIntake(normalized)
	if err != nil {
		return normalizedIntakeInput{}, fmt.Errorf("%w: cannot fingerprint request", ErrAdmissionValidation)
	}
	return normalized, nil
}

func hashAdmissionIntake(input normalizedIntakeInput) (string, error) {
	var elderID uint
	if input.ElderID != nil {
		elderID = *input.ElderID
	}
	payload := intakeFingerprintPayload{
		ElderID: elderID, ResidentName: input.ResidentName, Gender: input.GenderCode,
		BirthDate: input.BirthDate, Age: input.Age, IDCard: input.IDCard,
		ContactPhone: input.ContactPhone, FamilyAddress: input.FamilyAddress,
		FamilyName: input.FamilyName, FamilyPhone: input.FamilyPhone, FamilyRelation: input.FamilyRelation,
		AdmissionStartDate: input.AdmissionStartDate, AdmissionEndDate: input.AdmissionEndDate,
		FeeStartDate: input.FeeStartDate, FeeEndDate: input.FeeEndDate, RoomType: input.RoomType,
		CareLevel: input.CareLevelNum, CareLevelCode: input.CareLevelCode, BedID: input.BedID,
		Deposit: input.Deposit, CareFee: input.CareFee, BedFee: input.BedFee, OtherFee: input.OtherFee,
		MedicalInsurance: input.MedicalInsurance, Subsidy: input.Subsidy, Note: input.Note,
		PhotoUploadKeys: input.PhotoUploadKeys,
	}
	encoded, err := json.Marshal(payload)
	if err != nil {
		return "", err
	}
	digest := sha256.Sum256(encoded)
	return hex.EncodeToString(digest[:]), nil
}

func normalizeIntakeRoomType(value string) (string, error) {
	switch strings.ToLower(strings.TrimSpace(value)) {
	case "":
		return "", nil
	case "normal", "普通", "标准", "普通房", "双人房", "单人房":
		return "normal", nil
	case "nursing", "care", "护理", "照护":
		return "nursing", nil
	case "special", "特护", "特级", "隔离":
		return "special", nil
	default:
		return "", fmt.Errorf("%w: room_type is invalid", ErrAdmissionValidation)
	}
}

// occupyAdmissionBedForRoomType adds the form's optional room-type guard to
// the shared atomic bed claim used by the complete assessment workflow.
func occupyAdmissionBedForRoomType(tx *gorm.DB, bedID *uint, elderID uint, roomType string) (*model.Bed, error) {
	if strings.TrimSpace(roomType) != "" {
		var bed model.Bed
		if bedID == nil || *bedID == 0 {
			return nil, fmt.Errorf("%w: target bed is required", ErrAdmissionValidation)
		}
		if err := tx.Preload("Room").First(&bed, *bedID).Error; err != nil {
			if errors.Is(err, gorm.ErrRecordNotFound) {
				return nil, fmt.Errorf("%w: bed not found", ErrAdmissionBedConflict)
			}
			return nil, err
		}
		if bed.Room == nil || strings.ToLower(strings.TrimSpace(bed.Room.Type)) != roomType {
			return nil, fmt.Errorf("%w: bed room type does not match requested room_type", ErrAdmissionBedConflict)
		}
	}
	return occupyAdmissionBed(tx, bedID, elderID)
}

func isAdmissionIntakeIdempotencyConstraintError(err error) bool {
	if err == nil {
		return false
	}
	message := strings.ToLower(err.Error())
	return strings.Contains(message, "uk_admission_intakes_tenant_idempotency_key") ||
		(strings.Contains(message, "unique constraint") && strings.Contains(message, "admission_intakes")) ||
		(strings.Contains(message, "duplicate entry") && strings.Contains(message, "idempotency"))
}

func normalizeIntakeGender(value string) (string, error) {
	switch strings.ToUpper(strings.TrimSpace(value)) {
	case "M", "MALE", "男":
		return "M", nil
	case "F", "FEMALE", "女":
		return "F", nil
	default:
		return "", fmt.Errorf("%w: gender must be M/F or 男/女", ErrAdmissionValidation)
	}
}

func normalizeIntakeCareLevel(value string) (int8, string, error) {
	switch strings.ToLower(strings.TrimSpace(value)) {
	case "1", "一级", "自理", "intact":
		return 1, "intact", nil
	case "2", "二级", "半护理", "mild":
		return 2, "mild", nil
	case "3", "三级", "全护理", "moderate":
		return 3, "moderate", nil
	case "4", "四级", "重度护理", "severe":
		return 4, "severe", nil
	case "5", "五级", "特级护理", "complete":
		return 5, "complete", nil
	default:
		return 0, "", fmt.Errorf("%w: care_level is invalid", ErrAdmissionValidation)
	}
}

func parseIntakeDate(value, field string) (time.Time, error) {
	parsed, err := time.Parse("2006-01-02", value)
	if err != nil {
		return time.Time{}, fmt.Errorf("%w: %s must be YYYY-MM-DD", ErrAdmissionValidation, field)
	}
	return parsed, nil
}

func ageAtDate(birthDate, referenceDate time.Time) int {
	age := referenceDate.Year() - birthDate.Year()
	if referenceDate.Month() < birthDate.Month() ||
		(referenceDate.Month() == birthDate.Month() && referenceDate.Day() < birthDate.Day()) {
		age--
	}
	return age
}

func (s *AdmissionService) createIntakeElder(tx *gorm.DB, input normalizedIntakeInput) (*model.Elder, error) {
	contactPhone := strings.TrimSpace(input.ContactPhone)
	if contactPhone == "" {
		contactPhone = strings.TrimSpace(input.FamilyPhone)
	}
	contacts := []model.ElderContact{}
	if input.FamilyName != "" || input.FamilyPhone != "" || input.FamilyRelation != "" {
		contacts = append(contacts, model.ElderContact{Name: input.FamilyName, Relation: input.FamilyRelation, Phone: input.FamilyPhone, IsEmergency: true})
	}
	remark := input.Note
	if input.FamilyAddress != "" {
		if remark != "" {
			remark += "；家庭住址：" + input.FamilyAddress
		} else {
			remark = "家庭住址：" + input.FamilyAddress
		}
	}
	if len([]rune(remark)) > 500 {
		remark = truncateRunes(remark, 500)
	}

	if input.ElderID != nil && *input.ElderID > 0 {
		var elder model.Elder
		if err := tx.First(&elder, *input.ElderID).Error; err != nil {
			if errors.Is(err, gorm.ErrRecordNotFound) {
				return nil, fmt.Errorf("%w: linked elder not found", ErrAdmissionValidation)
			}
			return nil, err
		}
		if elder.Status == 2 || elder.BedID != nil {
			return nil, ErrAdmissionElderConflict
		}
		if err := ensureAdmissionIdentityAvailable(tx, input.IDCard, elder.ID); err != nil {
			return nil, err
		}
		updates := model.Elder{Name: input.ResidentName, IDCard: input.IDCard, Gender: input.GenderCode,
			BirthDate: input.BirthDate, ContactPhone: contactPhone, CareLevel: input.CareLevelNum,
			EmergencyContacts: contacts, Remark: remark}
		if err := tx.Model(&elder).Select("Name", "IDCard", "Gender", "BirthDate", "ContactPhone", "CareLevel", "EmergencyContacts", "Remark").Updates(&updates).Error; err != nil {
			if isElderIdentityConstraintError(err) {
				return nil, ErrAdmissionElderConflict
			}
			return nil, err
		}
		return &elder, nil
	}
	if err := ensureAdmissionIdentityAvailable(tx, input.IDCard, 0); err != nil {
		return nil, err
	}
	elder := model.Elder{Name: input.ResidentName, IDCard: input.IDCard, Gender: input.GenderCode,
		BirthDate: input.BirthDate, ContactPhone: contactPhone, CareLevel: input.CareLevelNum,
		Status: 1, EmergencyContacts: contacts, Allergies: []string{}, Remark: remark}
	if err := tx.Create(&elder).Error; err != nil {
		if isElderIdentityConstraintError(err) {
			return nil, ErrAdmissionElderConflict
		}
		return nil, err
	}
	return &elder, nil
}

func intakePlanTemplate(tx *gorm.DB, levelCode string) (*model.AdmissionCarePlanTemplate, error) {
	// Basic intake uses the same currently enabled assessment template as the
	// complete A/B/C workflow.  Filtering only by target_level would allow a
	// stale or tenant-owned plan from another template version to be selected
	// when an institution keeps multiple enabled versions.
	var template model.AssessmentTemplate
	if err := tx.Select("id").
		Where("code = ? AND enabled = ?", currentAdmissionTemplateCode, true).
		Order("sort_order asc, id desc").First(&template).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, fmt.Errorf("%w: active template missing", ErrAdmissionValidation)
		}
		return nil, err
	}
	var plan model.AdmissionCarePlanTemplate
	if err := tx.Where("template_id = ? AND target_level = ? AND enabled = ?", template.ID, levelCode, true).
		Order("sort_order asc, id asc").First(&plan).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, fmt.Errorf("%w: care plan unavailable for level %s", ErrAdmissionValidation, levelCode)
		}
		return nil, err
	}
	return &plan, nil
}

func createIntakeBill(tx *gorm.DB, elderID uint, input normalizedIntakeInput) (*model.Bill, error) {
	if input.CareFee == 0 && input.BedFee == 0 && input.OtherFee == 0 && input.MedicalInsurance == 0 && input.Subsidy == 0 && input.FeeStartDate == "" {
		return nil, nil
	}
	amount := input.BedFee + input.CareFee + input.OtherFee - input.MedicalInsurance - input.Subsidy
	if amount < 0 {
		amount = 0
	}
	bill := &model.Bill{ElderID: elderID, BillMonth: feeMonth(input), BedFee: input.BedFee, NursingFee: input.CareFee,
		OtherFee: input.OtherFee, Amount: amount, Status: "unpaid"}
	if err := tx.Create(bill).Error; err != nil {
		return nil, err
	}
	return bill, nil
}

func feeMonth(input normalizedIntakeInput) string {
	date := input.FeeStartDate
	if date == "" {
		date = input.AdmissionStartDate
	}
	if len(date) >= 7 {
		return date[:7]
	}
	return time.Now().Format("2006-01")
}

func attachAdmissionPhotos(tx *gorm.DB, actor AdmissionActor, intakeID, elderID uint, keys []string) error {
	if len(keys) == 0 {
		return nil
	}
	if len(keys) > 3 {
		return fmt.Errorf("%w: 最多上传三张照片", ErrAdmissionPhotoInvalid)
	}
	seen := map[string]bool{}
	for _, key := range keys {
		if !validUploadKey(key) || len(key) == 0 || len(key) > 128 || seen[key] {
			return fmt.Errorf("%w: photo upload key 无效或重复", ErrAdmissionPhotoInvalid)
		}
		seen[key] = true
	}
	tenantID := tenantIDFromContext(tx.Statement.Context)
	var photos []model.AdmissionIntakePhoto
	if err := tx.Where("tenant_id = ? AND upload_key IN ? AND intake_id = 0 AND uploaded_by = ?", tenantID, keys, actor.UserID).Find(&photos).Error; err != nil {
		return err
	}
	if len(photos) != len(keys) {
		return fmt.Errorf("%w: 照片不存在、已绑定或无权使用", ErrAdmissionPhotoInvalid)
	}
	seenKinds := map[string]bool{}
	for _, photo := range photos {
		if _, ok := admissionPhotoKinds[photo.Kind]; !ok {
			return fmt.Errorf("%w: 照片类型无效", ErrAdmissionPhotoInvalid)
		}
		if seenKinds[photo.Kind] {
			return fmt.Errorf("%w: 同一类型照片只能上传一张", ErrAdmissionPhotoInvalid)
		}
		seenKinds[photo.Kind] = true
		updated := tx.Model(&model.AdmissionIntakePhoto{}).
			Where("tenant_id = ? AND id = ? AND intake_id = 0 AND uploaded_by = ?", tenantID, photo.ID, actor.UserID).
			Updates(map[string]interface{}{"intake_id": intakeID, "elder_id": elderID})
		if updated.Error != nil {
			return updated.Error
		}
		// The row may have been attached by a concurrent intake after the
		// initial SELECT.  Never let the admission commit while silently
		// dropping a requested document; the surrounding transaction will roll
		// back the elder/bed/plan changes and the caller can retry with a fresh
		// upload key.
		if updated.RowsAffected != 1 {
			return fmt.Errorf("%w: 照片不存在、已绑定或无权使用", ErrAdmissionPhotoInvalid)
		}
		if photo.Kind == "portrait" {
			updatedElder := tx.Model(&model.Elder{}).
				Where("tenant_id = ? AND id = ?", tenantID, elderID).
				Update("image", fmt.Sprintf("/api/v1/admission-intake-photos/%d/content", photo.ID))
			if updatedElder.Error != nil {
				return updatedElder.Error
			}
			if updatedElder.RowsAffected != 1 {
				return fmt.Errorf("%w: 关联长者不存在或无权更新", ErrAdmissionPhotoInvalid)
			}
		}
	}
	return nil
}

func (s *AdmissionService) loadIntakeResult(db *gorm.DB, id uint) (*AdmissionIntakeResult, error) {
	var intake model.AdmissionIntake
	if err := db.First(&intake, id).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrAdmissionNotFound
		}
		return nil, err
	}
	var elder model.Elder
	if err := db.Preload("Bed").First(&elder, intake.ElderID).Error; err != nil {
		return nil, err
	}
	var bed model.Bed
	if err := db.Preload("Room").First(&bed, intake.BedID).Error; err != nil {
		return nil, err
	}
	result := &AdmissionIntakeResult{Intake: intake, Elder: elder, Bed: bed}
	if intake.CarePlanID != nil {
		var plan model.CarePlan
		if err := db.Preload("Items").First(&plan, *intake.CarePlanID).Error; err != nil {
			return nil, err
		}
		result.CarePlan = &plan
	}
	if intake.BillID != nil {
		var bill model.Bill
		if err := db.First(&bill, *intake.BillID).Error; err != nil {
			return nil, err
		}
		result.Bill = &bill
	}
	return result, nil
}

func createAdmissionTasksAt(tx *gorm.DB, elderID uint, caregiverID *uint, caregiverName string, items []model.CarePlanItem, dueAt time.Time) error {
	tasks := make([]model.CareTask, 0, len(items))
	for i := range items {
		itemID := items[i].ID
		itemDue := dueAt
		if items[i].DueAt != nil {
			itemDue = *items[i].DueAt
		}
		remark := strings.TrimSpace(items[i].Instructions)
		if items[i].Frequency != "" {
			if remark != "" {
				remark = items[i].Frequency + "；" + remark
			} else {
				remark = items[i].Frequency
			}
		}
		tasks = append(tasks, model.CareTask{ElderID: elderID, PlanItemID: &itemID, Title: items[i].Title,
			Kind: items[i].Kind, Category: normalizeTaskCategory("", items[i].Kind), Priority: normalizeTaskPriority("", items[i].RiskLevel),
			AssigneeID: caregiverID, DueAt: &itemDue, Assignee: caregiverName, Status: "todo", Remark: truncateRunes(remark, 500)})
	}
	if len(tasks) == 0 {
		return nil
	}
	return tx.Create(&tasks).Error
}

func uintPointer(value uint) *uint { return &value }

func newIntakeNo() string {
	b := make([]byte, 4)
	if _, err := rand.Read(b); err == nil {
		return "INT-" + time.Now().Format("20060102") + "-" + strings.ToUpper(hex.EncodeToString(b))
	}
	return "INT-" + time.Now().Format("20060102") + "-" + strconv.FormatInt(time.Now().UnixNano(), 10)
}
