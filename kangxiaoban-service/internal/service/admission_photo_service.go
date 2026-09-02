package service

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"mime/multipart"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	"gorm.io/gorm"

	"kangxiaoban-service/internal/model"
)

const maxAdmissionPhotoBytes int64 = 5 << 20

var (
	ErrAdmissionPhotoNotFound   = errors.New("admission photo not found")
	ErrAdmissionPhotoInvalid    = errors.New("admission photo validation failed")
	ErrAdmissionPhotoConflict   = errors.New("admission photo already exists")
	errAdmissionPhotoDeleteNoop = errors.New("admission photo delete no-op")
)

var admissionPhotoKinds = map[string]struct{}{"portrait": {}, "id_front": {}, "id_back": {}}

// AdmissionPhotoService stores private intake images outside the public static
// directory. The generated key is tenant scoped and never derived from a
// client supplied filename.
type AdmissionPhotoService struct {
	db      *gorm.DB
	rootDir string
}

func NewAdmissionPhotoService(db *gorm.DB, rootDir string) *AdmissionPhotoService {
	if strings.TrimSpace(rootDir) == "" {
		rootDir = "uploads"
	}
	return &AdmissionPhotoService{db: db, rootDir: filepath.Clean(rootDir)}
}

type AdmissionPhotoContent struct {
	Photo model.AdmissionIntakePhoto
	Path  string
}

// AdmissionPhotoView is the deliberately small client-facing representation
// of an intake photo.  AdmissionIntakePhoto also contains tenant, intake,
// uploader and private storage fields; returning that model directly from an
// HTTP handler would make those implementation details part of the API (and
// could disclose information across otherwise unrelated screens).
type AdmissionPhotoView struct {
	ID          uint   `json:"id"`
	Kind        string `json:"kind"`
	ContentType string `json:"content_type"`
	Size        int64  `json:"size"`
}

// AdmissionPhotoViewFromModel maps persisted metadata to the public photo
// contract. Keep this mapping explicit so adding a field to the database model
// does not accidentally expose it to clients.
func AdmissionPhotoViewFromModel(photo model.AdmissionIntakePhoto) AdmissionPhotoView {
	return AdmissionPhotoView{
		ID:          photo.ID,
		Kind:        photo.Kind,
		ContentType: photo.ContentType,
		Size:        photo.Size,
	}
}

func AdmissionPhotoViewsFromModels(photos []model.AdmissionIntakePhoto) []AdmissionPhotoView {
	views := make([]AdmissionPhotoView, 0, len(photos))
	for _, photo := range photos {
		views = append(views, AdmissionPhotoViewFromModel(photo))
	}
	return views
}

func (s *AdmissionPhotoService) Upload(ctx context.Context, actor AdmissionActor, intakeID uint, kind, uploadKey string, header *multipart.FileHeader) (*model.AdmissionIntakePhoto, error) {
	if actor.UserID == 0 {
		return nil, ErrAdmissionForbidden
	}
	if _, ok := admissionPhotoKinds[kind]; !ok {
		return nil, fmt.Errorf("%w: kind must be portrait, id_front or id_back", ErrAdmissionPhotoInvalid)
	}
	if uploadKey == "" || len(uploadKey) > 128 || !validUploadKey(uploadKey) {
		return nil, fmt.Errorf("%w: upload key 无效", ErrAdmissionPhotoInvalid)
	}
	if header == nil || header.Size <= 0 || header.Size > maxAdmissionPhotoBytes {
		return nil, fmt.Errorf("%w: 文件大小须在 1-5MB 以内", ErrAdmissionPhotoInvalid)
	}
	file, err := header.Open()
	if err != nil {
		return nil, fmt.Errorf("%w: 无法读取上传文件", ErrAdmissionPhotoInvalid)
	}
	defer file.Close()

	// Stream to a private temporary file while sniffing the actual bytes. Do
	// not trust Content-Type or extension from the client.
	tmpDir := filepath.Join(s.rootDir, "tmp")
	if err := os.MkdirAll(tmpDir, 0750); err != nil {
		return nil, err
	}
	tmp, err := os.CreateTemp(tmpDir, "admission-photo-*")
	if err != nil {
		return nil, err
	}
	tmpPath := tmp.Name()
	defer os.Remove(tmpPath)
	defer tmp.Close()
	if err := tmp.Chmod(0600); err != nil {
		return nil, err
	}
	limited := io.LimitReader(file, maxAdmissionPhotoBytes+1)
	hash := sha256.New()
	tee := io.MultiWriter(tmp, hash)
	size, err := io.Copy(tee, limited)
	if err != nil {
		return nil, fmt.Errorf("%w: 读取文件失败", ErrAdmissionPhotoInvalid)
	}
	if size == 0 || size > maxAdmissionPhotoBytes {
		return nil, fmt.Errorf("%w: 文件大小须在 1-5MB 以内", ErrAdmissionPhotoInvalid)
	}
	if _, err := tmp.Seek(0, 0); err != nil {
		return nil, err
	}
	buf := make([]byte, 512)
	n, _ := tmp.Read(buf)
	contentType := detectAdmissionPhotoContentType(buf[:n])
	ext := map[string]string{"image/jpeg": ".jpg", "image/png": ".png", "image/webp": ".webp"}[contentType]
	if ext == "" {
		return nil, fmt.Errorf("%w: 仅支持 JPG、PNG 或 WebP 图片", ErrAdmissionPhotoInvalid)
	}
	if err := tmp.Sync(); err != nil {
		return nil, err
	}
	if err := tmp.Close(); err != nil {
		return nil, err
	}

	db := s.db.WithContext(ctx)
	var intake model.AdmissionIntake
	tenantID := tenantIDFromContext(ctx)
	if intakeID > 0 {
		// Keep the tenant predicate at the service boundary as well as in the
		// GORM callback.  This method is also called from migration/tests and a
		// future caller could accidentally use a DB session without the callback;
		// an intake id must never select another institution's record.
		if err := db.Where("tenant_id = ? AND id = ?", tenantID, intakeID).First(&intake).Error; err != nil {
			if errors.Is(err, gorm.ErrRecordNotFound) {
				return nil, ErrAdmissionNotFound
			}
			return nil, err
		}
		if intake.Status != "completed" {
			return nil, ErrAdmissionInvalidState
		}
		tenantID = intake.TenantID
	}
	var keyBytes [16]byte
	if _, err := rand.Read(keyBytes[:]); err != nil {
		return nil, err
	}
	var key string
	if intakeID == 0 {
		key = filepath.Join(fmt.Sprintf("tenant-%d", tenantID), "admission", "pending", uploadKey, hex.EncodeToString(keyBytes[:])+ext)
	} else {
		key = filepath.Join(fmt.Sprintf("tenant-%d", tenantID), "admission", fmt.Sprintf("%d", intake.ID), hex.EncodeToString(keyBytes[:])+ext)
	}
	dest := filepath.Join(s.rootDir, filepath.FromSlash(key))
	if err := os.MkdirAll(filepath.Dir(dest), 0750); err != nil {
		return nil, err
	}
	if err := os.Rename(tmpPath, dest); err != nil {
		return nil, err
	}
	photo := &model.AdmissionIntakePhoto{Base: model.Base{TenantID: tenantID}, IntakeID: intake.ID, ElderID: intake.ElderID,
		Kind: kind, OriginalName: safeOriginalName(header.Filename), StorageKey: filepath.ToSlash(key), ContentType: contentType,
		Size: size, SHA256: hex.EncodeToString(hash.Sum(nil)), UploadedBy: actor.UserID, UploadKey: uploadKey}
	var old model.AdmissionIntakePhoto
	if err := db.Transaction(func(tx *gorm.DB) error {
		// An already-attached document is part of the immutable intake record.
		// Check it first so a legacy/parallel pending row cannot bypass the key
		// reuse guard below.
		var attached model.AdmissionIntakePhoto
		if attachedErr := tx.Where("tenant_id = ? AND upload_key = ? AND kind = ? AND uploaded_by = ? AND intake_id <> 0", tenantID, uploadKey, kind, actor.UserID).First(&attached).Error; attachedErr == nil {
			return ErrAdmissionPhotoConflict
		} else if !errors.Is(attachedErr, gorm.ErrRecordNotFound) {
			return attachedErr
		}

		// Only a still-pending upload may be replaced. An already-attached
		// document can never be deleted by a replacement request.
		if err := tx.Where("tenant_id = ? AND upload_key = ? AND kind = ? AND uploaded_by = ? AND intake_id = 0", tenantID, uploadKey, kind, actor.UserID).First(&old).Error; err == nil {
			if err := tx.Delete(&old).Error; err != nil {
				return err
			}
		} else if !errors.Is(err, gorm.ErrRecordNotFound) {
			return err
		}
		if err := tx.Create(photo).Error; err != nil {
			// The pending-slot unique index is the cross-process race guard.
			// Convert its driver-specific error into the same safe conflict
			// returned by the explicit attached/pending checks above.
			if isAdmissionPhotoConstraintError(err) {
				return ErrAdmissionPhotoConflict
			}
			return err
		}
		return nil
	}); err != nil {
		_ = os.Remove(dest)
		return nil, err
	}
	if old.StorageKey != "" {
		// A pending row can predate the current service or have been repaired by
		// an operator.  Never join an untrusted persisted key directly to the
		// storage root: a legacy `../` value must not turn replacement cleanup
		// into an arbitrary file delete.  If the key is malformed, leave the
		// orphan for an explicit storage sweep instead of failing an already
		// committed replacement.
		if oldPath, pathErr := s.privateStoragePath(old.StorageKey); pathErr == nil {
			_ = os.Remove(oldPath)
		}
	}
	return photo, nil
}

// detectAdmissionPhotoContentType supplements net/http's content sniffer with
// the WebP container signature.  DetectContentType intentionally classifies
// many RIFF containers as application/octet-stream, while the picker and the
// native client explicitly support WebP.  The signature check is performed on
// the bytes already read from the private temporary file, so it does not trust
// a client-provided MIME type or filename.
func detectAdmissionPhotoContentType(data []byte) string {
	if len(data) >= 12 &&
		string(data[0:4]) == "RIFF" && string(data[8:12]) == "WEBP" {
		return "image/webp"
	}
	return http.DetectContentType(data)
}

func isAdmissionPhotoConstraintError(err error) bool {
	if err == nil {
		return false
	}
	message := strings.ToLower(err.Error())
	if strings.Contains(message, "uk_admission_photos_pending_slot") {
		return true
	}
	return strings.Contains(message, "admission_intake_photos") &&
		(strings.Contains(message, "unique constraint") || strings.Contains(message, "duplicate entry"))
}

func (s *AdmissionPhotoService) UploadPending(ctx context.Context, actor AdmissionActor, uploadKey, kind string, header *multipart.FileHeader) (*model.AdmissionIntakePhoto, error) {
	return s.Upload(ctx, actor, 0, kind, uploadKey, header)
}

// DeletePending removes one pending image owned by the authenticated uploader.
//
// Pending images are temporary client-side uploads (IntakeID == 0), so they do
// not belong to the historical admission record yet.  The operation is
// deliberately scoped by tenant, uploader, upload key and slot kind.  A
// missing row is treated as an idempotent no-op: a retry after a successful
// delete, or a cleanup racing a replacement upload, must not turn into an
// error or disclose whether another user has a row with the same key.
//
// The file is first moved to a private, same-directory quarantine name while
// the database transaction is in progress.  If the transaction rolls back,
// the file is restored; after commit the quarantine file is removed.  This
// avoids leaving a database row pointing at a deleted file when a DB failure
// occurs, while also ensuring that a successful cleanup removes the bytes and
// the metadata together.
func (s *AdmissionPhotoService) DeletePending(ctx context.Context, actor AdmissionActor, uploadKey, kind string) (bool, error) {
	if actor.UserID == 0 {
		return false, ErrAdmissionForbidden
	}
	if uploadKey == "" || len(uploadKey) > 128 || !validUploadKey(uploadKey) {
		return false, fmt.Errorf("%w: upload key 无效", ErrAdmissionPhotoInvalid)
	}
	if _, ok := admissionPhotoKinds[kind]; !ok {
		return false, fmt.Errorf("%w: kind must be portrait, id_front or id_back", ErrAdmissionPhotoInvalid)
	}

	tenantID := tenantIDFromContext(ctx)
	db := s.db.WithContext(ctx)
	var quarantinePath string
	var originalPath string
	var deleted bool

	err := db.Transaction(func(tx *gorm.DB) error {
		var photo model.AdmissionIntakePhoto
		query := tx.Where("tenant_id = ? AND uploaded_by = ? AND intake_id = 0 AND upload_key = ? AND kind = ?",
			tenantID, actor.UserID, uploadKey, kind)
		if err := query.First(&photo).Error; err != nil {
			if errors.Is(err, gorm.ErrRecordNotFound) {
				// Idempotent cleanup.  Do not distinguish a foreign tenant/user
				// row from an absent row.
				return nil
			}
			return err
		}

		path, err := s.privateStoragePath(photo.StorageKey)
		if err != nil {
			// A malformed legacy row must never make a client-controlled
			// cleanup request delete outside the configured private root.
			return err
		}
		originalPath = path
		quarantinePath, err = s.quarantineFile(path)
		if err != nil {
			return err
		}

		// Pending rows are ephemeral.  Hard-delete the metadata rather than
		// retaining identity-document hashes/names in a soft-delete tombstone.
		result := tx.Unscoped().Where("id = ? AND tenant_id = ? AND uploaded_by = ? AND intake_id = 0",
			photo.ID, tenantID, actor.UserID).Delete(&model.AdmissionIntakePhoto{})
		if result.Error != nil {
			return result.Error
		}
		if result.RowsAffected == 0 {
			// Another transaction removed or attached the row between the
			// read and delete.  Roll back so the quarantined file is restored.
			return errAdmissionPhotoDeleteNoop
		}
		deleted = true
		return nil
	})
	if err != nil {
		if quarantinePath != "" {
			if restoreErr := os.Rename(quarantinePath, originalPath); restoreErr != nil && !errors.Is(restoreErr, os.ErrNotExist) {
				return false, errors.Join(err, fmt.Errorf("restore admission photo after delete rollback: %w", restoreErr))
			}
		}
		if errors.Is(err, errAdmissionPhotoDeleteNoop) {
			return false, nil
		}
		return false, err
	}

	if quarantinePath == "" {
		return deleted, nil
	}
	if removeErr := os.Remove(quarantinePath); removeErr != nil && !errors.Is(removeErr, os.ErrNotExist) {
		// The DB row is already gone.  Return an error so callers can log or
		// retry cleanup; the uniquely named quarantine file cannot be served
		// by any API and can be removed by a later storage sweep.
		return deleted, fmt.Errorf("remove quarantined admission photo: %w", removeErr)
	}
	return deleted, nil
}

// DeletePendingPhoto is a compatibility-shaped convenience wrapper for
// callers that only need an error result.  DeletePending remains the canonical
// method because the boolean lets an HTTP handler report an idempotent no-op.
func (s *AdmissionPhotoService) DeletePendingPhoto(ctx context.Context, actor AdmissionActor, uploadKey, kind string) error {
	_, err := s.DeletePending(ctx, actor, uploadKey, kind)
	return err
}

// privateStoragePath resolves a persisted storage key under rootDir.  It is
// used on deletion as a second line of defence for rows created by an older
// server or a manual migration.
func (s *AdmissionPhotoService) privateStoragePath(storageKey string) (string, error) {
	if strings.TrimSpace(storageKey) == "" {
		return "", ErrAdmissionPhotoNotFound
	}
	storagePath := filepath.FromSlash(storageKey)
	if filepath.IsAbs(storagePath) {
		return "", ErrAdmissionPhotoNotFound
	}
	root, err := filepath.Abs(s.rootDir)
	if err != nil {
		return "", err
	}
	path := filepath.Join(s.rootDir, storagePath)
	abs, err := filepath.Abs(path)
	if err != nil {
		return "", err
	}
	rel, err := filepath.Rel(root, abs)
	if err != nil || rel == ".." || strings.HasPrefix(rel, ".."+string(os.PathSeparator)) || filepath.IsAbs(rel) {
		return "", ErrAdmissionPhotoNotFound
	}
	return abs, nil
}

// quarantineFile atomically moves an existing regular file aside.  Missing
// files are tolerated because metadata cleanup should still be possible after
// an operator has already removed an orphaned file.
func (s *AdmissionPhotoService) quarantineFile(path string) (string, error) {
	info, err := os.Stat(path)
	if err != nil {
		if errors.Is(err, os.ErrNotExist) {
			return "", nil
		}
		return "", err
	}
	if info.IsDir() {
		return "", fmt.Errorf("admission photo storage path is a directory")
	}
	// Keep the quarantine beside the original so Rename is atomic on the same
	// filesystem and does not copy identity-document bytes through a second
	// location.
	quarantine := fmt.Sprintf("%s.delete-%d-%x", path, time.Now().UnixNano(), info.Size())
	if err := os.Rename(path, quarantine); err != nil {
		if errors.Is(err, os.ErrNotExist) {
			return "", nil
		}
		return "", err
	}
	return quarantine, nil
}

func tenantIDFromContext(ctx context.Context) uint {
	if ctx != nil {
		if value, ok := ctx.Value(model.TenantContextKey).(uint); ok && value > 0 {
			return value
		}
	}
	return 1
}

func validUploadKey(value string) bool {
	for _, r := range value {
		if (r >= 'a' && r <= 'z') || (r >= 'A' && r <= 'Z') || (r >= '0' && r <= '9') || r == '-' || r == '_' {
			continue
		}
		return false
	}
	return true
}

func (s *AdmissionPhotoService) List(ctx context.Context, actor AdmissionActor, intakeID uint) ([]model.AdmissionIntakePhoto, error) {
	if actor.UserID == 0 {
		return nil, ErrAdmissionForbidden
	}
	var intake model.AdmissionIntake
	tenantID := tenantIDFromContext(ctx)
	if err := s.db.WithContext(ctx).Where("tenant_id = ? AND id = ?", tenantID, intakeID).First(&intake).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrAdmissionNotFound
		}
		return nil, err
	}
	var photos []model.AdmissionIntakePhoto
	if err := s.db.WithContext(ctx).
		Where("tenant_id = ? AND intake_id = ?", tenantID, intake.ID).
		Order("kind asc, id asc").Find(&photos).Error; err != nil {
		return nil, err
	}
	return photos, nil
}

func (s *AdmissionPhotoService) Content(ctx context.Context, actor AdmissionActor, photoID uint) (*AdmissionPhotoContent, error) {
	if actor.UserID == 0 {
		return nil, ErrAdmissionForbidden
	}
	var photo model.AdmissionIntakePhoto
	tenantID := tenantIDFromContext(ctx)
	if err := s.db.WithContext(ctx).Where("tenant_id = ? AND id = ?", tenantID, photoID).First(&photo).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrAdmissionPhotoNotFound
		}
		return nil, err
	}
	// Pending uploads are intentionally write-only. They may be replaced or
	// attached by their owner, but they must never become an image oracle via a
	// guessed numeric ID before an intake transaction commits.
	if photo.IntakeID == 0 {
		return nil, ErrAdmissionPhotoNotFound
	}
	path, err := s.privateStoragePath(photo.StorageKey)
	if err != nil {
		return nil, ErrAdmissionPhotoNotFound
	}
	return &AdmissionPhotoContent{Photo: photo, Path: path}, nil
}

func safeOriginalName(name string) string {
	name = filepath.Base(strings.TrimSpace(name))
	if name == "." || name == "" {
		return "upload"
	}
	if len(name) > 200 {
		name = name[:200]
	}
	return name
}
