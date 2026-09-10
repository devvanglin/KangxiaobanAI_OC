package service

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"mime/multipart"
	"net/http/httptest"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"testing"

	"kangxiaoban-service/internal/model"
)

func TestAdmissionPhotoViewDoesNotExposePrivatePersistenceFields(t *testing.T) {
	photo := model.AdmissionIntakePhoto{
		Base:         model.Base{ID: 17, TenantID: 42},
		IntakeID:     7,
		ElderID:      8,
		Kind:         "portrait",
		OriginalName: "身份证.jpg",
		StorageKey:   "tenant-42/admission/7/private.jpg",
		ContentType:  "image/jpeg",
		Size:         12345,
		SHA256:       "private-hash",
		UploadedBy:   99,
		UploadKey:    "form-portrait",
	}
	view := AdmissionPhotoViewFromModel(photo)
	payload, err := json.Marshal(view)
	if err != nil {
		t.Fatal(err)
	}
	encoded := string(payload)
	for _, privateField := range []string{"tenant_id", "intake_id", "elder_id", "storage_key", "original_name", "sha256", "uploaded_by", "upload_key"} {
		if strings.Contains(encoded, privateField) {
			t.Fatalf("public photo view exposed %q: %s", privateField, encoded)
		}
	}
	var got map[string]interface{}
	if err := json.Unmarshal(payload, &got); err != nil {
		t.Fatal(err)
	}
	if len(got) != 4 || got["id"] != float64(17) || got["kind"] != "portrait" ||
		got["content_type"] != "image/jpeg" || got["size"] != float64(12345) {
		t.Fatalf("unexpected public photo view: %s", encoded)
	}
}

func TestAdmissionPhotoConstraintErrorMapping(t *testing.T) {
	tests := []struct {
		name string
		err  error
		want bool
	}{
		{
			name: "sqlite unique constraint",
			err:  errors.New("constraint failed: UNIQUE constraint failed: admission_intake_photos.tenant_id, admission_intake_photos.uploaded_by, admission_intake_photos.upload_key, admission_intake_photos.kind"),
			want: true,
		},
		{
			name: "mysql duplicate index",
			err:  errors.New("Error 1062 (23000): Duplicate entry '1:form-1:portrait' for key 'uk_admission_photos_pending_slot'"),
			want: true,
		},
		{
			name: "other table unique constraint",
			err:  errors.New("UNIQUE constraint failed: users.email"),
			want: false,
		},
		{
			name: "other duplicate entry",
			err:  errors.New("Duplicate entry 'x' for key 'users.email'"),
			want: false,
		},
		{
			name: "nil",
			err:  nil,
			want: false,
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := isAdmissionPhotoConstraintError(tt.err); got != tt.want {
				t.Fatalf("isAdmissionPhotoConstraintError(%v) = %v, want %v", tt.err, got, tt.want)
			}
		})
	}
}

func TestAdmissionPhotoUploadValidatesAndReplacesOneSlot(t *testing.T) {
	_, db, doctorID, ctx := newAdmissionTestService(t)
	photos := NewAdmissionPhotoService(db, t.TempDir())
	actor := AdmissionActor{UserID: doctorID}

	firstData := validJPEGPhoto()
	firstHeader := multipartHeader(t, "../../身份证.jpg", firstData)
	first, err := photos.UploadPending(ctx, actor, "form-portrait", "portrait", firstHeader)
	if err != nil {
		t.Fatalf("first upload: %v", err)
	}
	if first.ID == 0 || first.IntakeID != 0 || first.Kind != "portrait" || first.Size != int64(len(firstData)) {
		t.Fatalf("unexpected first metadata: %+v", first)
	}
	firstPath := filepath.Join(photos.rootDir, filepath.FromSlash(first.StorageKey))
	if mode := fileMode(t, firstPath); runtime.GOOS != "windows" && mode.Perm() != 0o600 {
		t.Fatalf("stored photo mode = %o, want 600", mode.Perm())
	}
	if got, err := os.ReadFile(firstPath); err != nil || !bytes.Equal(got, firstData) {
		t.Fatalf("stored first photo mismatch: err=%v bytes=%d", err, len(got))
	}
	if _, err := photos.Content(ctx, actor, first.ID); !errors.Is(err, ErrAdmissionPhotoNotFound) {
		t.Fatalf("pending photo content error = %v, want not found", err)
	}

	secondData := validPNGPhoto()
	second, err := photos.UploadPending(ctx, actor, "form-portrait", "portrait", multipartHeader(t, "portrait.png", secondData))
	if err != nil {
		t.Fatalf("replacement upload: %v", err)
	}
	if second.ID == first.ID || second.StorageKey == first.StorageKey {
		t.Fatalf("replacement reused old identity: first=%+v second=%+v", first, second)
	}
	if _, err := os.Stat(firstPath); !errors.Is(err, os.ErrNotExist) {
		t.Fatalf("old replacement file still exists, stat error=%v", err)
	}
	var rows []model.AdmissionIntakePhoto
	if err := db.WithContext(ctx).Where("upload_key = ? AND uploaded_by = ?", "form-portrait", doctorID).Find(&rows).Error; err != nil {
		t.Fatal(err)
	}
	if len(rows) != 1 || rows[0].ID != second.ID || rows[0].ContentType != "image/png" {
		t.Fatalf("replacement rows = %+v, want one PNG row", rows)
	}
}

func TestAdmissionPhotoReplacementDoesNotDeleteOutsideStorageRoot(t *testing.T) {
	_, db, doctorID, ctx := newAdmissionTestService(t)
	root := t.TempDir()
	photos := NewAdmissionPhotoService(db, root)
	actor := AdmissionActor{UserID: doctorID}
	key := "form-legacy-path"
	first, err := photos.UploadPending(ctx, actor, key, "portrait",
		multipartHeader(t, "portrait.jpg", validJPEGPhoto()))
	if err != nil {
		t.Fatalf("initial upload: %v", err)
	}

	// Simulate a legacy/corrupted metadata row whose storage key escapes the
	// configured private root.  Replacement must still succeed, but it must
	// never remove the outside sentinel file.
	sentinel := filepath.Join(filepath.Dir(root), "admission-photo-outside-sentinel")
	sentinelData := []byte("must survive")
	if err := os.WriteFile(sentinel, sentinelData, 0600); err != nil {
		t.Fatalf("write outside sentinel: %v", err)
	}
	t.Cleanup(func() { _ = os.Remove(sentinel) })
	if err := db.WithContext(ctx).Model(&model.AdmissionIntakePhoto{}).
		Where("id = ?", first.ID).
		Update("storage_key", "../admission-photo-outside-sentinel").Error; err != nil {
		t.Fatalf("corrupt legacy storage key: %v", err)
	}

	if _, err := photos.UploadPending(ctx, actor, key, "portrait",
		multipartHeader(t, "replacement.jpg", validJPEGPhoto())); err != nil {
		t.Fatalf("replacement upload: %v", err)
	}
	got, err := os.ReadFile(sentinel)
	if err != nil {
		t.Fatalf("outside sentinel was removed: %v", err)
	}
	if !bytes.Equal(got, sentinelData) {
		t.Fatalf("outside sentinel changed: %q", got)
	}
}

func TestAdmissionPhotoDeletePendingIsIdempotentAndRemovesPrivateBytes(t *testing.T) {
	_, db, doctorID, ctx := newAdmissionTestService(t)
	root := t.TempDir()
	photos := NewAdmissionPhotoService(db, root)
	actor := AdmissionActor{UserID: doctorID}
	key := "form-delete-portrait"
	if _, err := photos.UploadPending(ctx, actor, key, "portrait", multipartHeader(t, "portrait.jpg", validJPEGPhoto())); err != nil {
		t.Fatalf("upload pending photo: %v", err)
	}
	var before model.AdmissionIntakePhoto
	if err := db.WithContext(ctx).Where("upload_key = ? AND uploaded_by = ? AND intake_id = 0", key, doctorID).First(&before).Error; err != nil {
		t.Fatalf("load pending photo: %v", err)
	}
	path := filepath.Join(root, filepath.FromSlash(before.StorageKey))
	if _, err := os.Stat(path); err != nil {
		t.Fatalf("pending file missing before delete: %v", err)
	}

	deleted, err := photos.DeletePending(ctx, actor, key, "portrait")
	if err != nil || !deleted {
		t.Fatalf("DeletePending = deleted:%v err:%v, want true/nil", deleted, err)
	}
	if _, err := os.Stat(path); !errors.Is(err, os.ErrNotExist) {
		t.Fatalf("private file still exists after delete: %v", err)
	}
	var activeCount int64
	if err := db.WithContext(ctx).Model(&model.AdmissionIntakePhoto{}).
		Where("upload_key = ? AND uploaded_by = ? AND intake_id = 0", key, doctorID).Count(&activeCount).Error; err != nil {
		t.Fatal(err)
	}
	if activeCount != 0 {
		t.Fatalf("active pending row count = %d, want 0", activeCount)
	}
	var allCount int64
	if err := db.WithContext(ctx).Unscoped().Model(&model.AdmissionIntakePhoto{}).
		Where("upload_key = ? AND uploaded_by = ?", key, doctorID).Count(&allCount).Error; err != nil {
		t.Fatal(err)
	}
	if allCount != 0 {
		t.Fatalf("hard-deleted pending row count = %d, want 0", allCount)
	}

	// Cleanup retries are safe and do not turn an already-completed operation
	// into a 404/error for the native form.
	deleted, err = photos.DeletePending(ctx, actor, key, "portrait")
	if err != nil || deleted {
		t.Fatalf("idempotent DeletePending = deleted:%v err:%v, want false/nil", deleted, err)
	}
}

func TestAdmissionPhotoDeletePendingIsTenantAndUploaderScoped(t *testing.T) {
	_, db, doctorID, ctx := newAdmissionTestService(t)
	photos := NewAdmissionPhotoService(db, t.TempDir())
	actor := AdmissionActor{UserID: doctorID}
	key := "form-scope-portrait"
	if _, err := photos.UploadPending(ctx, actor, key, "portrait", multipartHeader(t, "portrait.jpg", validJPEGPhoto())); err != nil {
		t.Fatalf("upload pending photo: %v", err)
	}
	var stored model.AdmissionIntakePhoto
	if err := db.WithContext(ctx).Where("upload_key = ?", key).First(&stored).Error; err != nil {
		t.Fatal(err)
	}
	path := filepath.Join(photos.rootDir, filepath.FromSlash(stored.StorageKey))

	// A different uploader in the same tenant cannot remove the row.
	deleted, err := photos.DeletePending(ctx, AdmissionActor{UserID: doctorID + 1000}, key, "portrait")
	if err != nil || deleted {
		t.Fatalf("foreign uploader delete = deleted:%v err:%v, want false/nil", deleted, err)
	}
	if _, err := os.Stat(path); err != nil {
		t.Fatalf("file changed after foreign uploader delete: %v", err)
	}

	// The same user ID in another tenant cannot remove the current tenant's
	// pending row.  The tenant scope is carried by the request context.
	tenantTwoCtx := context.WithValue(context.Background(), model.TenantContextKey, uint(2))
	deleted, err = photos.DeletePending(tenantTwoCtx, actor, key, "portrait")
	if err != nil || deleted {
		t.Fatalf("foreign tenant delete = deleted:%v err:%v, want false/nil", deleted, err)
	}
	if _, err := os.Stat(path); err != nil {
		t.Fatalf("file changed after foreign tenant delete: %v", err)
	}

	deleted, err = photos.DeletePending(ctx, actor, key, "portrait")
	if err != nil || !deleted {
		t.Fatalf("owner delete = deleted:%v err:%v, want true/nil", deleted, err)
	}
}

func TestAdmissionPhotoDeletePendingRejectsAttachedPhoto(t *testing.T) {
	svc, db, doctorID, ctx := newAdmissionTestService(t)
	photos := NewAdmissionPhotoService(db, t.TempDir())
	actor := AdmissionActor{UserID: doctorID}
	key := "form-attached-delete"
	if _, err := photos.UploadPending(ctx, actor, key, "portrait", multipartHeader(t, "portrait.jpg", validJPEGPhoto())); err != nil {
		t.Fatalf("upload pending photo: %v", err)
	}
	bed := freeIntakeBed(t, db, ctx)
	input := validIntakeInput(bed, "intake-attached-delete")
	input.PhotoUploadKeys = []string{key}
	result, err := svc.CreateIntake(ctx, actor, input)
	if err != nil {
		t.Fatalf("create intake: %v", err)
	}
	var attached model.AdmissionIntakePhoto
	if err := db.WithContext(ctx).Where("upload_key = ?", key).First(&attached).Error; err != nil {
		t.Fatal(err)
	}
	path := filepath.Join(photos.rootDir, filepath.FromSlash(attached.StorageKey))
	deleted, err := photos.DeletePending(ctx, actor, key, "portrait")
	if err != nil || deleted {
		t.Fatalf("attached delete = deleted:%v err:%v, want false/nil", deleted, err)
	}
	if _, err := os.Stat(path); err != nil {
		t.Fatalf("attached photo file was removed: %v", err)
	}
	var still model.AdmissionIntakePhoto
	if err := db.WithContext(ctx).Where("id = ? AND intake_id = ?", attached.ID, result.Intake.ID).First(&still).Error; err != nil {
		t.Fatalf("attached row disappeared: %v", err)
	}
}

func TestAdmissionPhotoUploadRejectsInvalidInput(t *testing.T) {
	_, db, doctorID, ctx := newAdmissionTestService(t)
	photos := NewAdmissionPhotoService(db, t.TempDir())
	actor := AdmissionActor{UserID: doctorID}
	tests := []struct {
		name string
		key  string
		kind string
		data []byte
	}{
		{name: "path traversal key", key: "../escape", kind: "portrait", data: validJPEGPhoto()},
		{name: "unknown kind", key: "form-unknown", kind: "passport", data: validJPEGPhoto()},
		{name: "invalid magic", key: "form-text", kind: "portrait", data: []byte("not an image")},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, err := photos.UploadPending(ctx, actor, tt.key, tt.kind, multipartHeader(t, "upload.bin", tt.data))
			if !errors.Is(err, ErrAdmissionPhotoInvalid) {
				t.Fatalf("error = %v, want ErrAdmissionPhotoInvalid", err)
			}
		})
	}
	tooLarge := bytes.Repeat([]byte{0x41}, int(maxAdmissionPhotoBytes)+1)
	if _, err := photos.UploadPending(ctx, actor, "form-large", "portrait", multipartHeader(t, "large.jpg", tooLarge)); !errors.Is(err, ErrAdmissionPhotoInvalid) {
		t.Fatalf("oversize error = %v, want ErrAdmissionPhotoInvalid", err)
	}
	var count int64
	if err := db.WithContext(ctx).Model(&model.AdmissionIntakePhoto{}).Count(&count).Error; err != nil {
		t.Fatal(err)
	}
	if count != 0 {
		t.Fatalf("invalid uploads created %d database rows", count)
	}
}

func TestAdmissionPhotoUploadAcceptsWebPContainer(t *testing.T) {
	_, db, doctorID, ctx := newAdmissionTestService(t)
	photos := NewAdmissionPhotoService(db, t.TempDir())
	photo, err := photos.UploadPending(ctx, AdmissionActor{UserID: doctorID}, "form-webp", "portrait",
		multipartHeader(t, "portrait.webp", validWebPPhoto()))
	if err != nil {
		t.Fatalf("WebP upload: %v", err)
	}
	if photo.ContentType != "image/webp" || photo.Size != int64(len(validWebPPhoto())) {
		t.Fatalf("WebP metadata = %+v", photo)
	}
	if ext := filepath.Ext(photo.StorageKey); ext != ".webp" {
		t.Fatalf("WebP storage extension = %q, want .webp", ext)
	}
}

func TestAdmissionPhotoAttachIsTenantAndUserScopedAndTransactional(t *testing.T) {
	svc, db, doctorID, ctx := newAdmissionTestService(t)
	photos := NewAdmissionPhotoService(db, t.TempDir())
	actor := AdmissionActor{UserID: doctorID}
	key := "form-attach"
	if _, err := photos.UploadPending(ctx, actor, key, "portrait", multipartHeader(t, "portrait.jpg", validJPEGPhoto())); err != nil {
		t.Fatal(err)
	}

	bed := freeIntakeBed(t, db, ctx)
	input := validIntakeInput(bed, "photo-intake")
	input.PhotoUploadKeys = []string{key}
	result, err := svc.CreateIntake(ctx, actor, input)
	if err != nil {
		t.Fatalf("create intake with photo: %v", err)
	}
	var linked model.AdmissionIntakePhoto
	if err := db.WithContext(ctx).Where("upload_key = ?", key).First(&linked).Error; err != nil {
		t.Fatal(err)
	}
	if linked.IntakeID != result.Intake.ID || linked.ElderID != result.Elder.ID {
		t.Fatalf("photo linkage = %+v, want intake=%d elder=%d", linked, result.Intake.ID, result.Elder.ID)
	}
	if content, err := photos.Content(ctx, actor, linked.ID); err != nil || content.Path == "" {
		t.Fatalf("linked photo content = %+v, err=%v", content, err)
	}
	if !strings.Contains(result.Elder.Image, "/admission-intake-photos/") {
		t.Fatalf("portrait URL was not recorded on elder: %q", result.Elder.Image)
	}
	// Reusing a client key after commit must not replace the immutable attached
	// portrait. It may create a new pending upload for a later form, but the
	// already-linked file and URL must remain intact.
	attachedPath := filepath.Join(photos.rootDir, filepath.FromSlash(linked.StorageKey))
	if _, err := photos.UploadPending(ctx, actor, key, "portrait", multipartHeader(t, "replacement.jpg", validJPEGPhoto())); !errors.Is(err, ErrAdmissionPhotoConflict) {
		t.Fatalf("post-attach upload error = %v, want ErrAdmissionPhotoConflict", err)
	}
	if _, err := os.Stat(attachedPath); err != nil {
		t.Fatalf("attached portrait file was removed after key reuse: %v", err)
	}
	if !strings.HasSuffix(result.Elder.Image, "/"+fmt.Sprint(linked.ID)+"/content") {
		t.Fatalf("elder portrait URL changed after key reuse: %q", result.Elder.Image)
	}

	// A missing or cross-user pending key must roll back the entire admission,
	// rather than leaving a resident/bed without its requested document.
	badBed := freeIntakeBed(t, db, ctx)
	badInput := validIntakeInput(badBed, "photo-rollback")
	badInput.PhotoUploadKeys = []string{"another-users-photo"}
	var before int64
	if err := db.WithContext(ctx).Model(&model.AdmissionIntake{}).Count(&before).Error; err != nil {
		t.Fatal(err)
	}
	if _, err := svc.CreateIntake(ctx, actor, badInput); !errors.Is(err, ErrAdmissionPhotoInvalid) {
		t.Fatalf("missing photo error = %v, want ErrAdmissionPhotoInvalid", err)
	}
	var after int64
	if err := db.WithContext(ctx).Model(&model.AdmissionIntake{}).Count(&after).Error; err != nil {
		t.Fatal(err)
	}
	if after != before {
		t.Fatalf("failed photo intake changed intake count from %d to %d", before, after)
	}
}

func TestAdmissionPhotoReadAndAttachAreTenantScoped(t *testing.T) {
	svc, db, doctorID, tenantOneCtx := newAdmissionTestService(t)
	photos := NewAdmissionPhotoService(db, t.TempDir())
	actor := AdmissionActor{UserID: doctorID}
	key := "form-tenant-photo"
	if _, err := photos.UploadPending(tenantOneCtx, actor, key, "portrait", multipartHeader(t, "portrait.jpg", validJPEGPhoto())); err != nil {
		t.Fatalf("upload pending photo: %v", err)
	}
	bed := freeIntakeBed(t, db, tenantOneCtx)
	input := validIntakeInput(bed, "tenant-photo-intake")
	input.PhotoUploadKeys = []string{key}
	created, err := svc.CreateIntake(tenantOneCtx, actor, input)
	if err != nil {
		t.Fatalf("create intake with photo: %v", err)
	}
	var linked model.AdmissionIntakePhoto
	if err := db.WithContext(tenantOneCtx).Where("intake_id = ?", created.Intake.ID).First(&linked).Error; err != nil {
		t.Fatalf("load linked photo: %v", err)
	}

	// A numeric intake/photo id is not a capability.  Every read and attached
	// upload lookup must still carry the tenant from the authenticated token.
	tenantTwoCtx := context.WithValue(context.Background(), model.TenantContextKey, uint(2))
	if _, err := photos.List(tenantTwoCtx, actor, created.Intake.ID); !errors.Is(err, ErrAdmissionNotFound) {
		t.Fatalf("cross-tenant photo list error = %v, want ErrAdmissionNotFound", err)
	}
	if _, err := photos.Content(tenantTwoCtx, actor, linked.ID); !errors.Is(err, ErrAdmissionPhotoNotFound) {
		t.Fatalf("cross-tenant photo content error = %v, want ErrAdmissionPhotoNotFound", err)
	}
	if _, err := photos.Upload(tenantTwoCtx, actor, created.Intake.ID, "id_front", "cross-tenant-upload", multipartHeader(t, "front.jpg", validJPEGPhoto())); !errors.Is(err, ErrAdmissionNotFound) {
		t.Fatalf("cross-tenant attached upload error = %v, want ErrAdmissionNotFound", err)
	}

	if listed, err := photos.List(tenantOneCtx, actor, created.Intake.ID); err != nil || len(listed) != 1 {
		t.Fatalf("tenant-one photo list = %d, err=%v; want one photo", len(listed), err)
	}
}

func TestAttachAdmissionPhotosRejectsAConcurrentAttachment(t *testing.T) {
	// Exercise the compare-and-set guard directly: once the pending row is no
	// longer pending, a stale attachment attempt must fail instead of allowing
	// an intake transaction to commit without its requested document.
	_, db, doctorID, ctx := newAdmissionTestService(t)
	photos := NewAdmissionPhotoService(db, t.TempDir())
	actor := AdmissionActor{UserID: doctorID}
	key := "form-stale-attachment"
	if _, err := photos.UploadPending(ctx, actor, key, "portrait", multipartHeader(t, "portrait.jpg", validJPEGPhoto())); err != nil {
		t.Fatalf("upload pending photo: %v", err)
	}
	var pending model.AdmissionIntakePhoto
	if err := db.WithContext(ctx).Where("upload_key = ? AND uploaded_by = ?", key, doctorID).First(&pending).Error; err != nil {
		t.Fatalf("load pending photo: %v", err)
	}
	// Simulate another transaction winning the attachment between the SELECT
	// and UPDATE in attachAdmissionPhotos.
	if err := db.WithContext(ctx).Model(&model.AdmissionIntakePhoto{}).
		Where("id = ?", pending.ID).Updates(map[string]interface{}{"intake_id": 9001, "elder_id": 9002}).Error; err != nil {
		t.Fatalf("simulate concurrent attachment: %v", err)
	}
	tx := db.WithContext(ctx).Begin()
	if tx.Error != nil {
		t.Fatal(tx.Error)
	}
	err := attachAdmissionPhotos(tx, actor, 9003, 9004, []string{key})
	_ = tx.Rollback()
	if !errors.Is(err, ErrAdmissionPhotoInvalid) {
		t.Fatalf("stale attachment error = %v, want ErrAdmissionPhotoInvalid", err)
	}
}

func multipartHeader(t *testing.T, filename string, data []byte) *multipart.FileHeader {
	t.Helper()
	var body bytes.Buffer
	writer := multipart.NewWriter(&body)
	part, err := writer.CreateFormFile("file", filename)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := part.Write(data); err != nil {
		t.Fatal(err)
	}
	contentType := writer.FormDataContentType()
	if err := writer.Close(); err != nil {
		t.Fatal(err)
	}
	req := httptest.NewRequest("POST", "/", &body)
	req.Header.Set("Content-Type", contentType)
	if err := req.ParseMultipartForm(8 << 20); err != nil {
		t.Fatal(err)
	}
	files := req.MultipartForm.File["file"]
	if len(files) != 1 {
		t.Fatalf("multipart files = %d, want 1", len(files))
	}
	return files[0]
}

func fileMode(t *testing.T, path string) os.FileMode {
	t.Helper()
	info, err := os.Stat(path)
	if err != nil {
		t.Fatal(err)
	}
	return info.Mode()
}

func validJPEGPhoto() []byte {
	return []byte{0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, 'J', 'F', 'I', 'F', 0xff, 0xd9}
}

func validPNGPhoto() []byte {
	return []byte{0x89, 'P', 'N', 'G', 0x0d, 0x0a, 0x1a, 0x0a, 0x00}
}

func validWebPPhoto() []byte {
	return []byte{'R', 'I', 'F', 'F', 0x04, 0x00, 0x00, 0x00, 'W', 'E', 'B', 'P'}
}
