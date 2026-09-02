import {
  HdsListItemCard,
  HdsNavDestination,
  HdsNavDestinationTitleMode,
  ScrollEffectType,
  SuffixText,
  TitleBarStyleOptions,
  hdsMaterial
} from '@kit.UIDesignKit';
import { LengthMetrics } from '@kit.ArkUI';
import { BusinessError } from '@ohos.base';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { fileIo as fs, fileUri } from '@kit.CoreFileKit';
import { Bed } from '../../network/Dto';
import { BusinessStore } from '../../network/BusinessStore';
import AdmissionRepository, { AdmissionFailureKind, AdmissionResult } from '../../network/AdmissionRepository';
import { AdmissionIntakePayload, AdmissionIntakeResult, AdmissionPhoto } from '../../network/AdmissionApi';

interface AdmissionPhotoBinary {
  data: ArrayBuffer;
  contentType: string;
}

interface AdmissionCachedPhoto {
  uri: string;
  path: string;
}

interface AdmissionPendingPhotoCleanup {
  label: string;
  uploadKey: string;
  kind: string;
}

interface AdmissionDetachedSubmissionCleanup {
  token: number;
  pendingPhotos: AdmissionPendingPhotoCleanup[];
  cacheFiles: AdmissionCachedPhoto[];
  pendingCleanupAllowed: boolean;
}

interface AdmissionSubmissionPhotoSnapshot {
  label: string;
  kind: string;
  uri: string;
  path: string;
  revision: number;
  uploadKey: string;
  photoId: number;
  cleanupPromise: Promise<void>;
}

interface AdmissionSubmissionPhotoContext {
  token: number;
  photos: AdmissionSubmissionPhotoSnapshot[];
  uploadKeys: string[];
  // Once createIntake is sent, a network timeout leaves the server outcome
  // unknown. Keep pending identity photos in that case instead of racing a
  // compensating DELETE against a transaction that may still be committing.
  pendingCleanupAllowed: boolean;
}

@ComponentV2
struct AdmissionGroupCard {
  @Param @Require title: string;
  @BuilderParam @Require content: () => void;

  build() {
    Column({ space: 0 }) {
      HdsListItemCard({
        textItem: {
          primaryText: { text: this.title },
        },
        cardBorderRadius: 0,
        cardBackgroundColor: $r('sys.color.ohos_id_color_background_transparent'),
        cardHeight: 58,
        hoverBorderRadius: 0
      })
      Divider().strokeWidth(0.5).color($r('sys.color.comp_divider')).margin({ left: 16, right: 16 });
      Column({ space: 18 }) {
      this.content()
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 18, bottom: 22 })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(16)
    .clip(true)
    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
  }
}

/** 医师端办理入住页面：沉浸式详情页表单，提交到服务端完成入住办理。 */
@ComponentV2
export struct WideDoctorAdmissionForm {
  @Param compactWidth: boolean = false;
  @Param statusBarHeight: number = 0;
  @Param naviIndicatorHeight: number = 0;
  @Event onClose: () => void = () => {};

  @Local name: string = '';
  @Local gender: string = '';
  @Local idCard: string = '';
  @Local birthDate: string = '';
  @Local age: string = '';
  @Local phone: string = '';
  @Local familyAddress: string = '';
  @Local familyName: string = '';
  @Local familyPhone: string = '';
  @Local familyRelation: string = '';
  @Local admissionDate: string = '';
  @Local admissionEndDate: string = '';
  @Local feeStartDate: string = '';
  @Local feeEndDate: string = '';
  @Local careLevel: string = '';
  @Local bedName: string = '';
  @Local deposit: string = '';
  @Local careFee: string = '';
  @Local bedFee: string = '';
  @Local otherFee: string = '';
  @Local medicalInsurance: string = '';
  @Local subsidy: string = '';
  @Local note: string = '';
  @Local submitted: boolean = false;
  @Local activeField: string = '';
  @Local freeBeds: Bed[] = [];
  @Local bedsLoading: boolean = false;
  @Local bedsError: string = '';
  @Local bedId: number = 0;
  @Local submitting: boolean = false;
  @Local submitError: string = '';
  @Local submitErrorKind: AdmissionFailureKind = 'none';
  @Local intakeResult: AdmissionIntakeResult | null = null;
  @Local idempotencyKey: string = '';
  // PhotoViewPicker returns a temporary, permission-scoped URI. The picker
  // result is copied into the app cache immediately; these fields therefore
  // always contain a stable `file://` URI that remains readable while the form
  // is being edited or submitted.
  @Local portraitPhotoUri: string = '';
  @Local idCardFrontPhotoUri: string = '';
  @Local idCardBackPhotoUri: string = '';
  @Local photoPicking: string = '';
  @Local portraitPhotoId: number = 0;
  @Local idCardFrontPhotoId: number = 0;
  @Local idCardBackPhotoId: number = 0;
  @Local portraitUploadState: string = 'idle';
  @Local idCardFrontUploadState: string = 'idle';
  @Local idCardBackUploadState: string = 'idle';

  private scroller: Scroller = new Scroller();
  // Keep the key that belongs to each selected slot instead of deriving it
  // solely from the currently rendered form idempotency key.  A destination
  // can be reused after a system-driven detach while an older transaction is
  // still settling; in that case cleanup and retry must continue to address
  // the old pending row, not a newly generated form key.
  private portraitPhotoUploadKey: string = '';
  private idCardFrontPhotoUploadKey: string = '';
  private idCardBackPhotoUploadKey: string = '';
  // Each slot has a monotonically increasing revision.  An upload/picker
  // captures the revision before it suspends; a late response is allowed to
  // update the UI only when the slot still contains the same selection.
  // This keeps an old request from writing its id into a newly selected photo.
  private portraitPhotoRevision: number = 0;
  private idCardFrontPhotoRevision: number = 0;
  private idCardBackPhotoRevision: number = 0;
  private submissionSequence: number = 0;
  private activeSubmissionToken: number = 0;
  // Submission progress and view lifetime are separate concerns. A submit
  // request may outlive the navigation destination (for example when the
  // system back gesture removes the page), but late responses must not try to
  // repaint a detached/reused component instance.
  private uiLifecycleSequence: number = 0;
  private submissionUiLifecycle: number = 0;
  private componentAttached: boolean = false;
  private photoPickerSequence: number = 0;
  private bedsLoadSequence: number = 0;
  // Upload and cleanup operations are serialized per slot.  A picker result
  // can replace a photo while an older request is still settling; waiting for
  // the old operation before deleting/uploading the next one prevents a late
  // DELETE from removing the replacement row.
  private portraitPhotoUploadPromise: Promise<void> = Promise.resolve();
  private idCardFrontPhotoUploadPromise: Promise<void> = Promise.resolve();
  private idCardBackPhotoUploadPromise: Promise<void> = Promise.resolve();
  private portraitPhotoCleanupPromise: Promise<void> = Promise.resolve();
  private idCardFrontPhotoCleanupPromise: Promise<void> = Promise.resolve();
  private idCardBackPhotoCleanupPromise: Promise<void> = Promise.resolve();
  // Only paths created by this form are retained here.  This makes cleanup
  // safe: a raw provider URI or a server URL can never be passed to unlink.
  private photoCacheFiles: AdmissionCachedPhoto[] = [];
  // A system-driven destination removal can happen while the multipart upload
  // or the intake transaction is still in flight.  Keep a token-scoped
  // snapshot so the eventual finally block can clean only the old form's
  // pending rows/cache files, even if this component instance is reused for a
  // new admission form before the old request settles.
  private detachedSubmissionCleanups: AdmissionDetachedSubmissionCleanup[] = [];
  // Upload keys belong to the transaction, not to the currently rendered
  // form. Keep them separately so a detached submit can still bind its photos
  // when the component is no longer allowed to mutate visual state.
  private submissionPhotoContexts: AdmissionSubmissionPhotoContext[] = [];
  private readonly photoCachePrefix: string = 'admission-photo-';
  private readonly careLevelOptions: string[] = ['自理', '半护理', '全护理', '重度护理', '特级护理'];

  private titleBarStyle(): TitleBarStyleOptions {
    return {
      systemMaterialEffect: {
        materialType: hdsMaterial.MaterialType.IMMERSIVE,
        materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
      },
      scrollEffectOpts: {
        enableScrollEffect: true,
        scrollEffectType: ScrollEffectType.GRADIENT_BLUR
      }
    };
  }

  @Styles
  private keyboardFocusStyle() {
    .focusable(true)
    .focusOnTouch(true)
    .hoverEffect(HoverEffect.None)
    .focusBox({
      margin: LengthMetrics.vp(2),
      strokeWidth: LengthMetrics.vp(2)
    })
  }

  private horizontalPadding(): number {
    return this.compactWidth ? 16 : 24;
  }

  /**
   * Keep the form readable without forcing a tablet window into a 720vp
   * column.  The admission surface is already inside a scroll container, so
   * the parent can shrink this value naturally on smaller windows while
   * medium windows get enough width for their single-column controls.
   */
  private formMaxWidth(): number {
    return this.compactWidth ? 1040 : 1320;
  }

  private controlHeight(): number {
    return this.compactWidth ? 46 : 48;
  }

  private requiredReady(): boolean {
    return this.name.trim().length > 0 && this.gender.length > 0 &&
      this.idCard.trim().length > 0 && this.birthDate.trim().length > 0 && this.age.trim().length > 0 &&
      this.admissionDate.trim().length > 0 && this.careLevel.length > 0 && this.bedId > 0;
  }

  private newIdempotencyKey(): string {
    return `intake-${Date.now()}-${Math.floor(Math.random() * 1000000)}`;
  }

  private validDate(value: string): boolean {
    const normalized: string = value.trim();
    if (!/^\d{4}-\d{2}-\d{2}$/.test(normalized)) {
      return false;
    }
    const parsed: Date = new Date(`${normalized}T12:00:00`);
    return !Number.isNaN(parsed.getTime()) &&
      `${parsed.getFullYear()}-${(parsed.getMonth() + 1).toString().padStart(2, '0')}-${parsed.getDate().toString().padStart(2, '0')}` === normalized;
  }

  private amountValue(value: string, label: string): number | null {
    const normalized: string = value.trim();
    if (normalized.length === 0) {
      return 0;
    }
    const amount: number = Number(normalized);
    if (!Number.isFinite(amount) || amount < 0) {
      this.showToast(`${label}请输入有效的非负金额`);
      return null;
    }
    return amount;
  }

  private bedLabel(bed: Bed): string {
    const roomText: string = bed.room === undefined ? '' : `${bed.room.floor}F-${bed.room.room_no} · `;
    return `${roomText}${bed.bed_no}床`;
  }

  private selectedBedRoomType(): string {
    for (const bed of this.freeBeds) {
      if (bed.id === this.bedId && bed.room !== undefined) {
        return bed.room.type;
      }
    }
    return '';
  }

  private async loadFreeBeds(): Promise<void> {
    const loadToken: number = this.bedsLoadSequence + 1;
    this.bedsLoadSequence = loadToken;
    this.bedsLoading = true;
    this.bedsError = '';
    const result = await AdmissionRepository.freeBeds();
    if (this.bedsLoadSequence !== loadToken) {
      return;
    }
    this.bedsLoading = false;
    if (!result.ok || result.data === undefined) {
      this.bedsError = result.message.length > 0 ? result.message : '空床位加载失败';
      return;
    }
    this.freeBeds = result.data.list ?? [];
    if (this.bedId > 0 && !this.freeBeds.some((item: Bed) => item.id === this.bedId)) {
      this.bedId = 0;
      this.bedName = '';
    }
  }

  /** Resolve the cache directory without retaining a UIContext beyond the call. */
  private photoCacheDir(): string {
    try {
      const hostContext = this.getUIContext().getHostContext();
      if (hostContext === undefined) {
        return '';
      }
      return hostContext.getApplicationContext().cacheDir;
    } catch (_error) {
      return '';
    }
  }

  /** Resolve a cache URI to its exact sandbox path; never strip URI schemes. */
  private localPhotoPath(uri: string): string {
    const cached: AdmissionCachedPhoto | undefined = this.photoCacheFiles.find(
      (item: AdmissionCachedPhoto): boolean => item.uri === uri);
    return cached === undefined ? uri : cached.path;
  }

  private photoCacheUri(path: string): string {
    return fileUri.getUriFromPath(path);
  }

  private photoCacheExtension(sourceUri: string): string {
    const withoutQuery: string = sourceUri.split('?')[0].toLowerCase();
    const dot: number = withoutQuery.lastIndexOf('.');
    if (dot >= 0) {
      const extension: string = withoutQuery.substring(dot);
      if (extension === '.jpg' || extension === '.jpeg') {
        return '.jpg';
      }
      if (extension === '.png' || extension === '.webp') {
        return extension;
      }
    }
    return '.img';
  }

  private rememberPhotoCacheFile(file: AdmissionCachedPhoto): void {
    if (!this.photoCacheFiles.some((item: AdmissionCachedPhoto): boolean => item.uri === file.uri)) {
      this.photoCacheFiles.push(file);
    }
  }

  private removePhotoCacheUri(uri: string): void {
    const index: number = this.photoCacheFiles.findIndex((item: AdmissionCachedPhoto): boolean => item.uri === uri);
    if (index < 0) {
      return;
    }
    const file: AdmissionCachedPhoto = this.photoCacheFiles[index];
    // A detached submit may still be reading this private copy. Do not let a
    // new visual lifecycle unlink bytes owned by that transaction.
    if (this.photoCachePathReserved(file.path)) {
      return;
    }
    this.photoCacheFiles.splice(index, 1);
    try {
      fs.unlinkSync(file.path);
    } catch (_error) {
      // The cache directory may already have been evicted by the system.
    }
  }

  private clearPhotoCache(): void {
    const cached: AdmissionCachedPhoto[] = this.photoCacheFiles.slice();
    const retained: AdmissionCachedPhoto[] = [];
    for (const file of cached) {
      if (this.photoCachePathReserved(file.path)) {
        retained.push(file);
        continue;
      }
      try {
        fs.unlinkSync(file.path);
      } catch (_error) {
        // Ignore an already-evicted cache file.
      }
    }
    this.photoCacheFiles = retained;
  }

  private photoCachePathReserved(path: string): boolean {
    if (path.length === 0) {
      return false;
    }
    for (const context of this.submissionPhotoContexts) {
      if (context.photos.some((photo: AdmissionSubmissionPhotoSnapshot): boolean => photo.path === path)) {
        return true;
      }
    }
    for (const detached of this.detachedSubmissionCleanups) {
      if (detached.cacheFiles.some((file: AdmissionCachedPhoto): boolean => file.path === path)) {
        return true;
      }
    }
    return false;
  }

  private captureDetachedSubmissionCleanup(token: number): void {
    if (token <= 0 || this.detachedSubmissionCleanups.some(
      (item: AdmissionDetachedSubmissionCleanup): boolean => item.token === token)) {
      return;
    }
    const context: AdmissionSubmissionPhotoContext | undefined = this.submissionPhotoContexts.find(
      (item: AdmissionSubmissionPhotoContext): boolean => item.token === token);
    if (context === undefined) {
      return;
    }
    const pendingPhotos: AdmissionPendingPhotoCleanup[] = [];
    for (const photo of context.photos) {
      if (photo.uri.length > 0 && photo.uploadKey.length > 0) {
        pendingPhotos.push({ label: photo.label, uploadKey: photo.uploadKey, kind: photo.kind });
      }
    }
    const cacheFiles: AdmissionCachedPhoto[] = this.photoCacheFiles.filter(
      (file: AdmissionCachedPhoto): boolean => context.photos.some(
        (photo: AdmissionSubmissionPhotoSnapshot): boolean => photo.path.length > 0 && photo.path === file.path));
    this.detachedSubmissionCleanups.push({
      token: token,
      pendingPhotos: pendingPhotos,
      cacheFiles: cacheFiles,
      pendingCleanupAllowed: context.pendingCleanupAllowed
    });
  }

  /**
   * Complete cleanup for a submission whose UI destination has disappeared.
   * This is called only after confirmForm has awaited the active upload/create
   * request, so unlinking the local copies cannot interrupt a file read.  The
   * server endpoint removes pending rows only; if the intake transaction
   * succeeded, its rows are already attached and therefore cannot be deleted.
   */
  private finishDetachedSubmissionCleanup(snapshot: AdmissionDetachedSubmissionCleanup): void {
    for (const file of snapshot.cacheFiles) {
      try {
        fs.unlinkSync(file.path);
      } catch (_error) {
        // Ignore a cache file already evicted by the system.
      }
      const index: number = this.photoCacheFiles.findIndex((item: AdmissionCachedPhoto): boolean =>
        item.uri === file.uri && item.path === file.path);
      if (index >= 0) {
        this.photoCacheFiles.splice(index, 1);
      }
    }
    const context: AdmissionSubmissionPhotoContext | undefined = this.submissionContext(snapshot.token);
    const cleanupAllowed: boolean = context === undefined ? snapshot.pendingCleanupAllowed : context.pendingCleanupAllowed;
    if (cleanupAllowed) {
      for (const pending of snapshot.pendingPhotos) {
        // Cleanup is best effort after a page teardown. The endpoint is scoped
        // to the authenticated owner and is idempotent for an already-absent
        // or already-attached row; a failure must not create an unhandled
        // rejection. If createIntake was attempted and the result was
        // unknown, the context deliberately skips this DELETE (see above).
        void AdmissionRepository.deletePendingPhoto(pending.uploadKey, pending.kind)
          .then((): void => {}, (): void => {});
      }
    }
    const snapshotIndex: number = this.detachedSubmissionCleanups.findIndex(
      (item: AdmissionDetachedSubmissionCleanup): boolean => item.token === snapshot.token);
    if (snapshotIndex >= 0) {
      this.detachedSubmissionCleanups.splice(snapshotIndex, 1);
    }
  }

  /** Release only cache files owned by one completed submission context. */
  private releaseSubmissionPhotoCache(token: number): void {
    const context: AdmissionSubmissionPhotoContext | undefined = this.submissionContext(token);
    if (context === undefined) {
      return;
    }
    for (const photo of context.photos) {
      if (photo.path.length === 0) {
        continue;
      }
      const referencedByOtherSubmission: boolean = this.submissionPhotoContexts.some(
        (other: AdmissionSubmissionPhotoContext): boolean => other.token !== token && other.photos.some(
          (item: AdmissionSubmissionPhotoSnapshot): boolean => item.path === photo.path));
      const referencedByDetachedCleanup: boolean = this.detachedSubmissionCleanups.some(
        (detached: AdmissionDetachedSubmissionCleanup): boolean => detached.token !== token && detached.cacheFiles.some(
          (item: AdmissionCachedPhoto): boolean => item.path === photo.path));
      const referencedByCurrentDraft: boolean = !this.submitted &&
        ['一寸照片', '身份证人像面', '身份证国徽面'].some(
          (label: string): boolean => this.photoUri(label) === photo.uri);
      if (referencedByOtherSubmission || referencedByDetachedCleanup || referencedByCurrentDraft) {
        continue;
      }
      const index: number = this.photoCacheFiles.findIndex((item: AdmissionCachedPhoto): boolean =>
        item.uri === photo.uri && item.path === photo.path);
      if (index >= 0) {
        this.photoCacheFiles.splice(index, 1);
      }
      try {
        fs.unlinkSync(photo.path);
      } catch (_error) {
        // Ignore a cache file already evicted by the system.
      }
    }
  }

  /**
   * Copy a picker result while its temporary grant is valid. PhotoViewPicker's
   * `photoUris` are provider URIs, not durable file paths. The Picker contract
   * grants a short-lived read permission for the returned URI, so open it
   * directly before that grant expires and copy the bytes into the application
   * cache. This avoids requesting the restricted READ_IMAGEVIDEO permission;
   * the component only stores the resulting sandbox URI, so a later submission
   * does not depend on the picker grant still being alive.
   */
  private async copyPhotoToCache(sourceUri: string): Promise<AdmissionCachedPhoto | null> {
    let sourceFile: fs.File | undefined;
    let destinationPath: string = '';
    try {
      const cacheDir: string = this.photoCacheDir();
      if (cacheDir.length === 0 || sourceUri.length === 0) {
        this.showToast('无法保存照片，请重新选择');
        return null;
      }

      // PhotoViewPicker grants temporary read access to this URI.  Opening it
      // directly is the privacy-preserving Picker path and does not require
      // the restricted READ_IMAGEVIDEO permission.
      sourceFile = fs.openSync(sourceUri, fs.OpenMode.READ_ONLY);
      const sourceSize: number = Number(fs.statSync(sourceFile.fd).size);
      if (!Number.isFinite(sourceSize) || sourceSize <= 0 || sourceSize > 5 * 1024 * 1024) {
        this.showToast('照片大小须在 5MB 以内');
        return null;
      }

      const uniqueName: string = `${this.photoCachePrefix}${Date.now()}-${this.photoPickerSequence}-` +
        `${Math.floor(Math.random() * 1000000)}${this.photoCacheExtension(sourceUri)}`;
      destinationPath = `${cacheDir}/${uniqueName}`;
      // Keep the potentially slow provider-to-sandbox transfer off the UI
      // thread.  The destination is an app-private path and copyFile replaces
      // an existing path atomically from the caller's point of view.
      await fs.copyFile(sourceFile.fd, destinationPath);

      const copiedSize: number = Number((await fs.stat(destinationPath)).size);
      if (!Number.isFinite(copiedSize) || copiedSize !== sourceSize) {
        throw new Error('照片复制不完整');
      }
      const stableUri: string = this.photoCacheUri(destinationPath);
      // Reuse the strict magic-number validation used by the upload path.
      // Validate by the concrete sandbox path before registering the URI
      // mapping; this keeps the check independent of URI parsing behavior.
      if (this.readPhoto(destinationPath) === null) {
        fs.unlinkSync(destinationPath);
        return null;
      }
      const cached: AdmissionCachedPhoto = { uri: stableUri, path: destinationPath };
      this.rememberPhotoCacheFile(cached);
      return cached;
    } catch (_error) {
      if (destinationPath.length > 0) {
        try {
          fs.unlinkSync(destinationPath);
        } catch (_cleanupError) {
          // Ignore cleanup failure after a rejected copy.
        }
      }
      this.showToast('无法读取照片，请重新选择');
      return null;
    } finally {
      if (sourceFile !== undefined) {
        try {
          fs.closeSync(sourceFile);
        } catch (_error) {
          // Ignore a close failure after the provider FD is no longer needed.
        }
      }
    }
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message });
    } catch (_error) {
      // 页面退出后不阻断表单状态。
    }
  }

  private intakePayload(): AdmissionIntakePayload | null {
    if (!this.validDate(this.birthDate) || !this.validDate(this.admissionDate)) {
      this.showToast('出生日期和入住开始日期需使用 YYYY-MM-DD 格式');
      return null;
    }
    if (this.admissionEndDate.trim().length > 0 && !this.validDate(this.admissionEndDate)) {
      this.showToast('入住结束日期需使用 YYYY-MM-DD 格式');
      return null;
    }
    if (this.feeStartDate.trim().length > 0 && !this.validDate(this.feeStartDate)) {
      this.showToast('费用开始日期需使用 YYYY-MM-DD 格式');
      return null;
    }
    if (this.feeEndDate.trim().length > 0 && !this.validDate(this.feeEndDate)) {
      this.showToast('费用结束日期需使用 YYYY-MM-DD 格式');
      return null;
    }
    const deposit: number | null = this.amountValue(this.deposit, '押金');
    const careFee: number | null = this.amountValue(this.careFee, '护理费用');
    const bedFee: number | null = this.amountValue(this.bedFee, '床位费用');
    const otherFee: number | null = this.amountValue(this.otherFee, '其他费用');
    const medicalInsurance: number | null = this.amountValue(this.medicalInsurance, '医保支付');
    const subsidy: number | null = this.amountValue(this.subsidy, '政府补贴');
    if (deposit === null || careFee === null || bedFee === null || otherFee === null ||
      medicalInsurance === null || subsidy === null) {
      return null;
    }
    return {
      idempotency_key: this.idempotencyKey,
      resident_name: this.name.trim(),
      gender: this.gender,
      birth_date: this.birthDate.trim(),
      age: Number(this.age.trim()),
      id_card: this.idCard.trim(),
      contact_phone: this.phone.trim(),
      family_address: this.familyAddress.trim(),
      family_name: this.familyName.trim(),
      family_phone: this.familyPhone.trim(),
      family_relation: this.familyRelation,
      admission_start_date: this.admissionDate.trim(),
      admission_end_date: this.admissionEndDate.trim(),
      fee_start_date: this.feeStartDate.trim(),
      fee_end_date: this.feeEndDate.trim(),
      // The room type is derived from the server-provided bed instead of a
      // second free-text selector, so the request cannot disagree with the
      // actual room that owns the selected bed.
      room_type: this.selectedBedRoomType(),
      care_level: this.careLevel,
      bed_id: this.bedId,
      deposit: deposit,
      care_fee: careFee,
      bed_fee: bedFee,
      other_fee: otherFee,
      medical_insurance: medicalInsurance,
      subsidy: subsidy,
      note: this.note.trim(),
      photo_upload_keys: this.photoUploadKeys()
    };
  }

  private photoIds(): number[] {
    const ids: number[] = [];
    if (this.portraitPhotoId > 0) {
      ids.push(this.portraitPhotoId);
    }
    if (this.idCardFrontPhotoId > 0) {
      ids.push(this.idCardFrontPhotoId);
    }
    if (this.idCardBackPhotoId > 0) {
      ids.push(this.idCardBackPhotoId);
    }
    return ids;
  }

  /**
   * Give each document slot its own pending-upload key. Reusing one key for
   * all three slots would make a removed photo look active when the form is
   * finally submitted, because the server quite correctly finds every
   * pending photo belonging to that key. Slot-scoped keys keep replacement
   * and removal independent while the form idempotency key still groups the
   * request on the client.
   */
  private photoUploadKey(label: string): string {
    if (label === '一寸照片' && this.portraitPhotoUploadKey.length > 0) {
      return this.portraitPhotoUploadKey;
    }
    if (label === '身份证人像面' && this.idCardFrontPhotoUploadKey.length > 0) {
      return this.idCardFrontPhotoUploadKey;
    }
    if (label === '身份证国徽面' && this.idCardBackPhotoUploadKey.length > 0) {
      return this.idCardBackPhotoUploadKey;
    }
    let suffix: string = 'portrait';
    if (label === '身份证人像面') {
      suffix = 'id-front';
    } else if (label === '身份证国徽面') {
      suffix = 'id-back';
    }
    return this.idempotencyKey.length > 0 ? `${this.idempotencyKey}-${suffix}` : '';
  }

  private photoUploadKeys(): string[] {
    const keys: string[] = [];
    if (this.portraitPhotoId > 0) {
      keys.push(this.photoUploadKey('一寸照片'));
    }
    if (this.idCardFrontPhotoId > 0) {
      keys.push(this.photoUploadKey('身份证人像面'));
    }
    if (this.idCardBackPhotoId > 0) {
      keys.push(this.photoUploadKey('身份证国徽面'));
    }
    return keys;
  }

  private photoId(label: string): number {
    if (label === '一寸照片') {
      return this.portraitPhotoId;
    }
    if (label === '身份证人像面') {
      return this.idCardFrontPhotoId;
    }
    return this.idCardBackPhotoId;
  }

  private photoRevision(label: string): number {
    if (label === '一寸照片') {
      return this.portraitPhotoRevision;
    }
    if (label === '身份证人像面') {
      return this.idCardFrontPhotoRevision;
    }
    return this.idCardBackPhotoRevision;
  }

  private bumpPhotoRevision(label: string): number {
    if (label === '一寸照片') {
      this.portraitPhotoRevision += 1;
      return this.portraitPhotoRevision;
    }
    if (label === '身份证人像面') {
      this.idCardFrontPhotoRevision += 1;
      return this.idCardFrontPhotoRevision;
    }
    this.idCardBackPhotoRevision += 1;
    return this.idCardBackPhotoRevision;
  }

  private photoSelectionIsCurrent(label: string, revision: number, uri: string, uploadKey: string): boolean {
    return this.photoRevision(label) === revision && this.photoUri(label) === uri &&
      this.photoUploadKey(label) === uploadKey;
  }

  private submissionPhotoSnapshot(label: string): AdmissionSubmissionPhotoSnapshot | null {
    const uri: string = this.photoUri(label);
    const photoId: number = this.photoId(label);
    if (uri.length === 0 && photoId <= 0) {
      return null;
    }
    const cached: AdmissionCachedPhoto | undefined = this.photoCacheFiles.find(
      (item: AdmissionCachedPhoto): boolean => item.uri === uri);
    return {
      label: label,
      kind: this.photoKind(label),
      uri: uri,
      path: cached === undefined ? '' : cached.path,
      revision: this.photoRevision(label),
      uploadKey: this.photoUploadKey(label),
      photoId: photoId,
      cleanupPromise: this.photoCleanupPromise(label)
    };
  }

  private submissionPhotoSnapshots(): AdmissionSubmissionPhotoSnapshot[] {
    const snapshots: AdmissionSubmissionPhotoSnapshot[] = [];
    for (const label of ['一寸照片', '身份证人像面', '身份证国徽面']) {
      const snapshot: AdmissionSubmissionPhotoSnapshot | null = this.submissionPhotoSnapshot(label);
      if (snapshot !== null) {
        snapshots.push(snapshot);
      }
    }
    return snapshots;
  }

  private submissionContext(token: number): AdmissionSubmissionPhotoContext | undefined {
    return this.submissionPhotoContexts.find(
      (item: AdmissionSubmissionPhotoContext): boolean => item.token === token);
  }

  private snapshotMatchesCurrent(snapshot: AdmissionSubmissionPhotoSnapshot): boolean {
    return this.photoSelectionIsCurrent(snapshot.label, snapshot.revision, snapshot.uri, snapshot.uploadKey);
  }

  private setSubmissionCleanupAllowed(token: number, allowed: boolean): void {
    const context: AdmissionSubmissionPhotoContext | undefined = this.submissionContext(token);
    if (context !== undefined) {
      context.pendingCleanupAllowed = allowed;
    }
  }

  private beginSubmission(): number {
    this.submissionSequence += 1;
    this.activeSubmissionToken = this.submissionSequence;
    this.submissionUiLifecycle = this.uiLifecycleSequence;
    const photos: AdmissionSubmissionPhotoSnapshot[] = this.submissionPhotoSnapshots();
    const uploadKeys: string[] = [];
    for (const photo of photos) {
      if (photo.photoId > 0 && photo.uploadKey.length > 0) {
        uploadKeys.push(photo.uploadKey);
      }
    }
    this.submissionPhotoContexts.push({
      token: this.activeSubmissionToken,
      photos: photos,
      uploadKeys: uploadKeys,
      pendingCleanupAllowed: true
    });
    return this.activeSubmissionToken;
  }

  /**
   * True only while the transaction is current *and* this destination is
   * still the attached view that started it. Keep this separate from
   * submissionIsCurrent(): the latter intentionally remains true while the
   * network transaction settles after the page has been popped.
   */
  private submissionUiIsCurrent(token: number): boolean {
    return this.submissionIsCurrent(token) && this.componentAttached &&
      this.submissionUiLifecycle === this.uiLifecycleSequence;
  }

  private submissionIsCurrent(token: number): boolean {
    // A component can be detached and, in edge cases, reused before an older
    // request settles. Presence in the transaction context is the durable
    // liveness check; activeSubmissionToken is only the UI's latest-submit
    // pointer and must not cancel an older server write.
    return token > 0 && this.submissionContext(token) !== undefined;
  }

  private recordSubmissionPhotoKey(token: number, uploadKey: string): void {
    if (token <= 0 || uploadKey.length === 0) {
      return;
    }
    const context: AdmissionSubmissionPhotoContext | undefined = this.submissionPhotoContexts.find(
      (item: AdmissionSubmissionPhotoContext): boolean => item.token === token);
    if (context !== undefined && !context.uploadKeys.includes(uploadKey)) {
      context.uploadKeys.push(uploadKey);
    }
  }

  private submissionPhotoKeys(token: number): string[] {
    const context: AdmissionSubmissionPhotoContext | undefined = this.submissionPhotoContexts.find(
      (item: AdmissionSubmissionPhotoContext): boolean => item.token === token);
    return context === undefined ? [] : context.uploadKeys.slice();
  }

  private discardSubmissionPhotoContext(token: number): void {
    const index: number = this.submissionPhotoContexts.findIndex(
      (item: AdmissionSubmissionPhotoContext): boolean => item.token === token);
    if (index >= 0) {
      this.submissionPhotoContexts.splice(index, 1);
    }
  }

  private isDetachedSubmission(token: number): boolean {
    return this.detachedSubmissionCleanups.some(
      (item: AdmissionDetachedSubmissionCleanup): boolean => item.token === token);
  }

  private invalidateSubmission(): void {
    this.submissionSequence += 1;
    // A previous transaction may still be finishing after its destination was
    // removed. Keep that context alive; only cancel a transaction owned by the
    // currently attached form.
    if (this.activeSubmissionToken > 0 && !this.isDetachedSubmission(this.activeSubmissionToken)) {
      this.discardSubmissionPhotoContext(this.activeSubmissionToken);
    }
    this.activeSubmissionToken = 0;
  }

  private invalidateUiOperations(resetTransient: boolean = false): void {
    this.uiLifecycleSequence += 1;
    this.photoPickerSequence += 1;
    this.bedsLoadSequence += 1;
    if (resetTransient) {
      this.photoPicking = '';
      this.submitting = false;
      if (this.portraitUploadState === 'uploading') {
        this.portraitUploadState = 'idle';
      }
      if (this.idCardFrontUploadState === 'uploading') {
        this.idCardFrontUploadState = 'idle';
      }
      if (this.idCardBackUploadState === 'uploading') {
        this.idCardBackUploadState = 'idle';
      }
    }
  }

  private invalidateAsyncOperations(resetTransient: boolean = false): void {
    this.invalidateUiOperations(resetTransient);
    this.invalidateSubmission();
  }

  private setPhotoId(label: string, id: number): void {
    if (label === '一寸照片') {
      this.portraitPhotoId = id;
    } else if (label === '身份证人像面') {
      this.idCardFrontPhotoId = id;
    } else {
      this.idCardBackPhotoId = id;
    }
  }

  private photoKind(label: string): string {
    if (label === '一寸照片') {
      return 'portrait';
    }
    if (label === '身份证人像面') {
      return 'id_front';
    }
    return 'id_back';
  }

  private photoUploadPromise(label: string): Promise<void> {
    if (label === '一寸照片') {
      return this.portraitPhotoUploadPromise;
    }
    if (label === '身份证人像面') {
      return this.idCardFrontPhotoUploadPromise;
    }
    return this.idCardBackPhotoUploadPromise;
  }

  private setPhotoUploadPromise(label: string, promise: Promise<void>): void {
    if (label === '一寸照片') {
      this.portraitPhotoUploadPromise = promise;
    } else if (label === '身份证人像面') {
      this.idCardFrontPhotoUploadPromise = promise;
    } else {
      this.idCardBackPhotoUploadPromise = promise;
    }
  }

  private photoCleanupPromise(label: string): Promise<void> {
    if (label === '一寸照片') {
      return this.portraitPhotoCleanupPromise;
    }
    if (label === '身份证人像面') {
      return this.idCardFrontPhotoCleanupPromise;
    }
    return this.idCardBackPhotoCleanupPromise;
  }

  private setPhotoCleanupPromise(label: string, promise: Promise<void>): void {
    if (label === '一寸照片') {
      this.portraitPhotoCleanupPromise = promise;
    } else if (label === '身份证人像面') {
      this.idCardFrontPhotoCleanupPromise = promise;
    } else {
      this.idCardBackPhotoCleanupPromise = promise;
    }
  }

  /**
   * Remove a server-side pending row after the current upload operation has
   * settled.  The endpoint is idempotent, so cleanup can safely be retried by
   * a later lifecycle callback.  Errors are intentionally swallowed here:
   * local editing must remain responsive even when the network is offline.
   */
  private queuePendingPhotoCleanup(label: string, uploadKey: string): void {
    if (uploadKey.length === 0 || this.submitted) {
      return;
    }
    const previousCleanup: Promise<void> = this.photoCleanupPromise(label);
    const currentUpload: Promise<void> = this.photoUploadPromise(label);
    const cleanup: Promise<void> = previousCleanup
      .then((): Promise<void> => currentUpload)
      .then(async (): Promise<void> => {
        const result = await AdmissionRepository.deletePendingPhoto(uploadKey, this.photoKind(label));
        // A 404/absent row is a successful idempotent cleanup.  Other errors
        // are left for the next explicit lifecycle cleanup attempt.
        if (!result.ok && result.code !== 404) {
          return;
        }
      })
      .catch((): void => {
        // Do not surface a background cleanup failure as a form submission
        // failure.  The pending endpoint is safe to call again.
      });
    this.setPhotoCleanupPromise(label, cleanup);
  }

  private cleanupCurrentPendingPhotos(): void {
    // A disappearing form can coincide with an in-flight submit.  The submit
    // path owns the pending rows until its transaction settles; issuing a
    // cleanup DELETE here could race the upload/create request and remove a
    // photo that the server is about to attach.  The submit failure path and
    // the next explicit lifecycle cleanup will handle any remaining rows.
    if (this.submitted || this.submitting || this.idempotencyKey.length === 0) {
      return;
    }
    const labels: string[] = ['一寸照片', '身份证人像面', '身份证国徽面'];
    for (const label of labels) {
      const hasSelection: boolean = this.photoUri(label).length > 0 || this.photoId(label) > 0 ||
        this.photoUploadState(label) !== 'idle';
      if (hasSelection) {
        this.queuePendingPhotoCleanup(label, this.photoUploadKey(label));
      }
    }
  }

  private photoUploadState(label: string): string {
    if (label === '一寸照片') {
      return this.portraitUploadState;
    }
    if (label === '身份证人像面') {
      return this.idCardFrontUploadState;
    }
    return this.idCardBackUploadState;
  }

  private setPhotoUploadState(label: string, state: string): void {
    if (label === '一寸照片') {
      this.portraitUploadState = state;
    } else if (label === '身份证人像面') {
      this.idCardFrontUploadState = state;
    } else {
      this.idCardBackUploadState = state;
    }
  }

  private readPhoto(uri: string): AdmissionPhotoBinary | null {
    let file: fs.File | undefined;
    try {
      // Image accepts a `file://` URI, while fileIo is most reliable with the
      // corresponding sandbox path.  Picker/provider URIs are only used by
      // copyPhotoToCache and never reach this method after selection.
      file = fs.openSync(this.localPhotoPath(uri), fs.OpenMode.READ_ONLY);
      const size: number = Number(fs.statSync(file.fd).size);
      if (!Number.isFinite(size) || size <= 0 || size > 5 * 1024 * 1024) {
        this.showToast('照片大小须在 5MB 以内');
        return null;
      }
      const data: ArrayBuffer = new ArrayBuffer(size);
      const bytes: Uint8Array = new Uint8Array(data);
      // A single readSync call is allowed to return fewer bytes than the
      // requested buffer length. Read through the file pointer in bounded
      // chunks and copy each
      // chunk into its own destination offset; passing the full destination
      // buffer on every call would overwrite bytes already read.
      const chunkSize: number = Math.min(256 * 1024, size);
      const chunk: ArrayBuffer = new ArrayBuffer(chunkSize);
      let bytesRead: number = 0;
      while (bytesRead < size) {
        const requestLength: number = Math.min(chunkSize, size - bytesRead);
        const readCount: number = fs.readSync(file.fd, chunk, { length: requestLength });
        if (!Number.isFinite(readCount) || readCount <= 0 || readCount > requestLength) {
          throw new Error('照片读取不完整');
        }
        bytes.set(new Uint8Array(chunk, 0, readCount), bytesRead);
        bytesRead += readCount;
      }
      let contentType: string = '';
      if (bytes.length >= 3 && bytes[0] === 0xFF && bytes[1] === 0xD8 && bytes[2] === 0xFF) {
        contentType = 'image/jpeg';
      } else if (bytes.length >= 8 && bytes[0] === 0x89 && bytes[1] === 0x50 && bytes[2] === 0x4E &&
        bytes[3] === 0x47 && bytes[4] === 0x0D && bytes[5] === 0x0A && bytes[6] === 0x1A && bytes[7] === 0x0A) {
        contentType = 'image/png';
      } else if (bytes.length >= 12 && bytes[0] === 0x52 && bytes[1] === 0x49 && bytes[2] === 0x46 &&
        bytes[3] === 0x46 && bytes[8] === 0x57 && bytes[9] === 0x45 && bytes[10] === 0x42 && bytes[11] === 0x50) {
        contentType = 'image/webp';
      }
      if (contentType.length === 0) {
        this.showToast('仅支持 JPG、PNG 或 WebP 图片');
        return null;
      }
      return { data: data, contentType: contentType };
    } catch (_error) {
      this.showToast('无法读取照片，请重新选择');
      return null;
    } finally {
      if (file !== undefined) {
        try {
          fs.closeSync(file);
        } catch (_error) {
          // Ignore a close failure after the read has completed.
        }
      }
    }
  }

  private async performPhotoUpload(snapshot: AdmissionSubmissionPhotoSnapshot,
    submissionToken: number): Promise<boolean> {
    const label: string = snapshot.label;
    if (this.submissionUiIsCurrent(submissionToken)) {
      this.setPhotoUploadState(label, 'uploading');
    }
    const binary: AdmissionPhotoBinary | null = this.readPhoto(
      snapshot.path.length > 0 ? snapshot.path : snapshot.uri);
    if (binary === null) {
      this.setSubmissionCleanupAllowed(submissionToken, true);
      if (this.submissionUiIsCurrent(submissionToken) && this.snapshotMatchesCurrent(snapshot)) {
        this.setPhotoUploadState(label, 'failed');
      }
      return false;
    }
    let result: AdmissionResult<AdmissionPhoto>;
    try {
      result = await AdmissionRepository.uploadPhoto(snapshot.kind, snapshot.uploadKey, binary.contentType, binary.data);
    } catch (_error) {
      // A lost upload response leaves the pending row's existence unknown;
      // do not race a cleanup DELETE against a request that may have arrived.
      this.setSubmissionCleanupAllowed(submissionToken, false);
      if (this.submissionUiIsCurrent(submissionToken) && this.snapshotMatchesCurrent(snapshot)) {
        this.setPhotoUploadState(label, 'failed');
        this.showToast(`${label}上传失败，可点击重试`);
      }
      return false;
    }
    // The picker/replacement and the network request are independent async
    // operations.  Never let a response from an obsolete selection mutate the
    // current slot, even if a future caller bypasses the disabled controls.
    if (!this.submissionIsCurrent(submissionToken)) {
      return false;
    }
    if (!result.ok || result.data === undefined || result.data.id <= 0) {
      this.setSubmissionCleanupAllowed(submissionToken, result.code !== -1);
      if (this.submissionUiIsCurrent(submissionToken) && this.snapshotMatchesCurrent(snapshot)) {
        this.setPhotoUploadState(label, 'failed');
        this.showToast(`${label}上传失败，可点击重试`);
      }
      return false;
    }
    // The key is the transaction's durable binding; retain it even when the
    // destination has disappeared and visual state must no longer be touched.
    this.recordSubmissionPhotoKey(submissionToken, snapshot.uploadKey);
    if (this.submissionUiIsCurrent(submissionToken) && this.snapshotMatchesCurrent(snapshot)) {
      this.setPhotoId(label, result.data.id);
      this.setPhotoUploadState(label, 'uploaded');
    }
    return true;
  }

  private async uploadPhotoFor(label: string, submissionToken: number): Promise<boolean> {
    const context: AdmissionSubmissionPhotoContext | undefined = this.submissionContext(submissionToken);
    if (context === undefined) {
      return false;
    }
    const snapshot: AdmissionSubmissionPhotoSnapshot | undefined = context.photos.find(
      (item: AdmissionSubmissionPhotoSnapshot): boolean => item.label === label);
    if (snapshot === undefined) {
      return true;
    }
    if (snapshot.photoId > 0) {
      this.recordSubmissionPhotoKey(submissionToken, snapshot.uploadKey);
      return true;
    }
    // If this slot replaced an earlier uploaded selection, wait until its
    // idempotent server cleanup has completed before reusing the same key.
    await snapshot.cleanupPromise;
    if (!this.submissionIsCurrent(submissionToken)) {
      return false;
    }
    const operation: Promise<boolean> = this.performPhotoUpload(snapshot, submissionToken);
    // Keep the operation alive for lifecycle cleanup, but never create an
    // unhandled rejection if a future implementation throws unexpectedly.
    this.setPhotoUploadPromise(label, operation.then((): void => {}, (): void => {}));
    return await operation;
  }

  private async uploadSelectedPhotos(submissionToken: number): Promise<boolean> {
    if (!(await this.uploadPhotoFor('一寸照片', submissionToken))) {
      if (this.submissionUiIsCurrent(submissionToken)) {
        this.submitError = '一寸照片上传失败，请重试';
      }
      return false;
    }
    if (!(await this.uploadPhotoFor('身份证人像面', submissionToken))) {
      if (this.submissionUiIsCurrent(submissionToken)) {
        this.submitError = '身份证人像面上传失败，请重试';
      }
      return false;
    }
    if (!(await this.uploadPhotoFor('身份证国徽面', submissionToken))) {
      if (this.submissionUiIsCurrent(submissionToken)) {
        this.submitError = '身份证国徽面上传失败，请重试';
      }
      return false;
    }
    return true;
  }

  private async confirmForm(): Promise<void> {
    if (!this.requiredReady()) {
      this.showToast('请填写必填项并选择真实空床位');
      return;
    }
    if (this.submitting) {
      return;
    }
    const payload: AdmissionIntakePayload | null = this.intakePayload();
    if (payload === null) {
      return;
    }
    if (this.photoPicking.length > 0) {
      this.showToast('正在选择照片，请先完成选择后再提交');
      return;
    }
    const submissionToken: number = this.beginSubmission();
    this.submitting = true;
    this.submitError = '';
    this.submitErrorKind = 'none';
    let submissionSucceeded: boolean = false;
    try {
      if (!(await this.uploadSelectedPhotos(submissionToken))) {
        if (this.submissionUiIsCurrent(submissionToken)) {
          this.submitErrorKind = 'network';
        }
        return;
      }
      if (!this.submissionIsCurrent(submissionToken)) {
        return;
      }
      // Read the keys from this submission's context. The form may have
      // detached while the uploads were settling, in which case its visual
      // photo ids are deliberately not updated.
      payload.photo_upload_keys = this.submissionPhotoKeys(submissionToken);
      // From this point the server may have accepted the request even if the
      // client later loses the response. Do not issue compensating DELETEs
      // until a definitive response is received.
      this.setSubmissionCleanupAllowed(submissionToken, false);
      const result = await AdmissionRepository.createIntake(payload);
      if (!this.submissionIsCurrent(submissionToken)) {
        return;
      }
      this.setSubmissionCleanupAllowed(submissionToken, result.code !== -1);
      if (!result.ok || result.data === undefined || result.data.intake === undefined ||
        result.data.intake.status !== 'completed') {
        if (this.submissionUiIsCurrent(submissionToken)) {
          this.submitError = result.message.length > 0 ? result.message : '入住办理未完成，请稍后重试';
          this.submitErrorKind = result.kind;
        }
        return;
      }
      if (this.submissionUiIsCurrent(submissionToken)) {
        this.intakeResult = result.data;
        this.submitted = true;
      }
      // The server now owns the validated copies; cache release is performed
      // in finally after the submission context is retired, so its own
      // reservation cannot prevent the targeted unlink.
      submissionSucceeded = true;
      // Refresh the shared operational snapshot after the server transaction
      // commits so resident, bed, task, and billing surfaces see the new record.
      void BusinessStore.getShared().load(true);
    } catch (_error) {
      if (this.submissionUiIsCurrent(submissionToken)) {
        this.submitError = '入住办理请求失败，请稍后重试';
        this.submitErrorKind = 'network';
      }
    } finally {
      if (this.submissionUiIsCurrent(submissionToken)) {
        this.submitting = false;
      }
      // Retire only this transaction's active pointer. A detached older
      // request must never clear the pointer for a newer form submission.
      if (this.activeSubmissionToken === submissionToken) {
        this.activeSubmissionToken = 0;
      }
      // aboutToDisappear invalidates the UI token to prevent late state
      // updates, but the request itself still settles in the background.  Do
      // not leave its private cache files or pending server rows behind.
      const detachedCleanup: AdmissionDetachedSubmissionCleanup | undefined = this.detachedSubmissionCleanups.find(
        (item: AdmissionDetachedSubmissionCleanup): boolean => item.token === submissionToken);
      if (detachedCleanup !== undefined) {
        this.finishDetachedSubmissionCleanup(detachedCleanup);
      }
      if (submissionSucceeded && detachedCleanup === undefined) {
        this.releaseSubmissionPhotoCache(submissionToken);
      }
      this.discardSubmissionPhotoContext(submissionToken);
    }
  }

  private resultPrimaryText(): string {
    return this.intakeResult === null ? this.name :
      `${this.intakeResult.elder.name} · ${this.intakeResult.intake.intake_no}`;
  }

  private resultSecondaryText(): string {
    return `${this.careLevel} · ${this.bedName} · ${this.admissionDate}`;
  }

  private resetForm(): void {
    if (this.submitting || this.photoPicking.length > 0) {
      this.showToast('当前操作进行中，暂时不能重新填写');
      return;
    }
    this.cleanupCurrentPendingPhotos();
    this.invalidateAsyncOperations();
    this.clearPhotoCache();
    this.name = '';
    this.gender = '';
    this.idCard = '';
    this.birthDate = '';
    this.age = '';
    this.phone = '';
    this.familyAddress = '';
    this.familyName = '';
    this.familyPhone = '';
    this.familyRelation = '';
    this.admissionDate = '';
    this.admissionEndDate = '';
    this.feeStartDate = '';
    this.feeEndDate = '';
    this.careLevel = '';
    this.bedName = '';
    this.bedId = 0;
    this.deposit = '';
    this.careFee = '';
    this.bedFee = '';
    this.otherFee = '';
    this.medicalInsurance = '';
    this.subsidy = '';
    this.note = '';
    this.submitted = false;
    this.submitting = false;
    this.submitError = '';
    this.submitErrorKind = 'none';
    this.intakeResult = null;
    this.idempotencyKey = this.newIdempotencyKey();
    this.activeField = '';
    this.portraitPhotoUri = '';
    this.idCardFrontPhotoUri = '';
    this.idCardBackPhotoUri = '';
    this.portraitPhotoUploadKey = '';
    this.idCardFrontPhotoUploadKey = '';
    this.idCardBackPhotoUploadKey = '';
    this.photoPicking = '';
    this.portraitPhotoId = 0;
    this.idCardFrontPhotoId = 0;
    this.idCardBackPhotoId = 0;
    this.bumpPhotoRevision('一寸照片');
    this.bumpPhotoRevision('身份证人像面');
    this.bumpPhotoRevision('身份证国徽面');
    this.portraitUploadState = 'idle';
    this.idCardFrontUploadState = 'idle';
    this.idCardBackUploadState = 'idle';
    // The old idempotency key is no longer relevant to the new form.  The
    // queued cleanup promises retain their own captured key and continue in
    // the background, while the next selection starts without waiting for
    // an unrelated old form's network request.
    this.portraitPhotoUploadPromise = Promise.resolve();
    this.idCardFrontPhotoUploadPromise = Promise.resolve();
    this.idCardBackPhotoUploadPromise = Promise.resolve();
    this.portraitPhotoCleanupPromise = Promise.resolve();
    this.idCardFrontPhotoCleanupPromise = Promise.resolve();
    this.idCardBackPhotoCleanupPromise = Promise.resolve();
  }

  private photoUri(label: string): string {
    if (label === '一寸照片') {
      return this.portraitPhotoUri;
    }
    if (label === '身份证人像面') {
      return this.idCardFrontPhotoUri;
    }
    return this.idCardBackPhotoUri;
  }

  private setPhotoUri(label: string, uri: string): void {
    if (this.submitting) {
      return;
    }
    const previousUri: string = this.photoUri(label);
    const previousPhotoId: number = this.photoId(label);
    const previousUploadKey: string = this.photoUploadKey(label);
    if (previousUri.length > 0 || previousPhotoId > 0) {
      this.queuePendingPhotoCleanup(label, previousUploadKey);
    }
    if (previousUri.length > 0 && previousUri !== uri) {
      this.removePhotoCacheUri(previousUri);
    }
    if (label === '一寸照片') {
      this.portraitPhotoUri = uri;
      this.portraitPhotoId = 0;
      this.portraitPhotoUploadKey = uri.length > 0 ? this.photoUploadKeyForCurrentForm('一寸照片') : '';
      this.bumpPhotoRevision(label);
      this.portraitUploadState = 'idle';
    } else if (label === '身份证人像面') {
      this.idCardFrontPhotoUri = uri;
      this.idCardFrontPhotoId = 0;
      this.idCardFrontPhotoUploadKey = uri.length > 0 ? this.photoUploadKeyForCurrentForm('身份证人像面') : '';
      this.bumpPhotoRevision(label);
      this.idCardFrontUploadState = 'idle';
    } else {
      this.idCardBackPhotoUri = uri;
      this.idCardBackPhotoId = 0;
      this.idCardBackPhotoUploadKey = uri.length > 0 ? this.photoUploadKeyForCurrentForm('身份证国徽面') : '';
      this.bumpPhotoRevision(label);
      this.idCardBackUploadState = 'idle';
    }
  }

  private photoUploadKeyForCurrentForm(label: string): string {
    let suffix: string = 'portrait';
    if (label === '身份证人像面') {
      suffix = 'id-front';
    } else if (label === '身份证国徽面') {
      suffix = 'id-back';
    }
    return this.idempotencyKey.length > 0 ? `${this.idempotencyKey}-${suffix}` : '';
  }

  private async pickPhoto(label: string): Promise<void> {
    if (this.submitting || this.photoPicking.length > 0) {
      return;
    }
    const pickerToken: number = this.photoPickerSequence + 1;
    this.photoPickerSequence = pickerToken;
    this.photoPicking = label;
    try {
      const options = new photoAccessHelper.PhotoSelectOptions();
      options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      options.maxSelectNumber = 1;
      const picker = new photoAccessHelper.PhotoViewPicker();
      const result: photoAccessHelper.PhotoSelectResult = await picker.select(options);
      const sourceUri: string = result.photoUris.length > 0 ? result.photoUris[0] : '';
      if (sourceUri.length > 0 && this.photoPickerSequence === pickerToken && !this.submitting) {
        const cachedPhoto: AdmissionCachedPhoto | null = await this.copyPhotoToCache(sourceUri);
        if (cachedPhoto !== null && this.photoPickerSequence === pickerToken && !this.submitting) {
          this.setPhotoUri(label, cachedPhoto.uri);
          this.showToast(`${label}已选择`);
        } else if (cachedPhoto !== null) {
          // The form was closed/replaced while the copy was in flight.
          this.removePhotoCacheUri(cachedPhoto.uri);
        }
      }
    } catch (error) {
      const pickerError: BusinessError = error as BusinessError;
      // Cancellation is a normal user action.  The picker has used different
      // cancellation codes across API levels, so only surface errors whose
      // message clearly indicates a launch/permission failure.
      const message: string = pickerError?.message === undefined ? '' : pickerError.message.toLowerCase();
      if (message.includes('permission') || message.includes('failed') || message.includes('invalid') ||
        message.includes('权限') || message.includes('失败')) {
        this.showToast('无法打开相册，请稍后重试');
      }
    } finally {
      if (this.photoPickerSequence === pickerToken) {
        this.photoPicking = '';
      }
    }
  }

  private removePhoto(label: string): void {
    if (this.submitting || this.photoPicking.length > 0) {
      return;
    }
    this.setPhotoUri(label, '');
    this.showToast(`${label}已移除`);
  }

  private photoControlsLocked(label: string): boolean {
    return this.submitting || this.photoPicking.length > 0 || this.photoUploadState(label) === 'uploading';
  }

  private photoStatusText(label: string): string {
    const state: string = this.photoUploadState(label);
    if (state === 'uploaded') {
      return '已上传到服务器';
    }
    if (state === 'uploading') {
      return '正在上传…';
    }
    if (state === 'failed') {
      return '上传失败，点击“确认办理入住”重试';
    }
    return '';
  }

  private photoStatusColor(label: string): ResourceColor {
    const state: string = this.photoUploadState(label);
    if (state === 'uploaded') {
      return $r('app.color.doctor_workspace_success');
    }
    if (state === 'failed') {
      return $r('app.color.doctor_workspace_danger');
    }
    return $r('sys.color.font_secondary');
  }

  private closeForm(): void {
    if (this.submitting) {
      this.showToast('正在提交，请稍候');
      return;
    }
    if (this.photoPicking.length > 0) {
      this.showToast('正在选择照片，请先完成选择');
      return;
    }
    this.cleanupCurrentPendingPhotos();
    this.invalidateAsyncOperations();
    this.clearPhotoCache();
    this.onClose();
  }

  aboutToAppear(): void {
    this.componentAttached = true;
    // A new view instance/lifecycle invalidates picker and bed-load responses,
    // but must not cancel an already-started admission transaction that may
    // still be completing after a previous destination was popped.
    this.invalidateUiOperations(true);
    this.portraitPhotoUploadPromise = Promise.resolve();
    this.idCardFrontPhotoUploadPromise = Promise.resolve();
    this.idCardBackPhotoUploadPromise = Promise.resolve();
    this.portraitPhotoCleanupPromise = Promise.resolve();
    this.idCardFrontPhotoCleanupPromise = Promise.resolve();
    this.idCardBackPhotoCleanupPromise = Promise.resolve();
    this.idempotencyKey = this.newIdempotencyKey();
    void this.loadFreeBeds();
  }

  aboutToDisappear(): void {
    // The repository request cannot be cancelled at this layer.  Invalidate
    // its token before the destination is removed so a late response cannot
    // mutate a recycled form instance.  A submit owns the local cache until
    // its upload/create transaction settles; deleting those files here would
    // make a system-driven page teardown race the bytes currently being read.
    const submitInFlight: boolean = this.submitting;
    if (submitInFlight && this.activeSubmissionToken > 0) {
      this.captureDetachedSubmissionCleanup(this.activeSubmissionToken);
    } else {
      this.cleanupCurrentPendingPhotos();
    }
    this.componentAttached = false;
    // Do not invalidate the submission token here. Upload/createIntake must
    // continue to completion so the server transaction is not abandoned just
    // because its destination was removed. Only picker/bed-load/UI responses
    // are stale after this lifecycle boundary.
    this.invalidateUiOperations(false);
    if (!submitInFlight) {
      this.clearPhotoCache();
    }
  }

  /**
   * All admission fields use the same label-above-control rhythm.  This is
   * deliberately a local form pattern instead of a second navigation shell:
   * it keeps long labels and large-font settings from stealing width from the
   * actual input control.
   */
  @Builder
  private stackedTextField(label: string, placeholder: string, value: string,
    onChange: (value: string) => void, required: boolean = false, numeric: boolean = false) {
    Column({ space: 8 }) {
      Text(required ? `${label} *` : label)
        .width('100%')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
        .textAlign(TextAlign.Start)
      TextInput({ text: value, placeholder: placeholder })
        .width('100%')
        .height(this.controlHeight())
        .fontSize(16)
        .fontColor($r('sys.color.font_primary'))
        .backgroundColor($r('sys.color.comp_background_secondary'))
        .borderRadius(10)
        .border({ width: this.activeField === label ? 1.5 : 0.5,
          color: this.activeField === label ? $r('app.color.brand_blue') : $r('sys.color.comp_divider') })
        .type(numeric ? InputType.Number : InputType.Normal)
        .onFocus(() => this.activeField = label)
        .onChange((next: string) => {
          onChange(next);
          this.activeField = label;
        })
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  private stackedTextAreaField(label: string, placeholder: string, value: string,
    onChange: (value: string) => void) {
    Column({ space: 8 }) {
      Text(label)
        .width('100%')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
        .textAlign(TextAlign.Start)
      TextArea({ text: value, placeholder: placeholder })
        .width('100%')
        .height(this.compactWidth ? 112 : 104)
        .fontSize(16)
        .fontColor($r('sys.color.font_primary'))
        .backgroundColor($r('sys.color.comp_background_secondary'))
        .borderRadius(10)
        .border({ width: 0.5, color: $r('sys.color.comp_divider') })
        .onChange((next: string) => onChange(next))
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  private stackedChoiceField(label: string, options: string[], selected: string,
    onSelect: (value: string) => void, required: boolean = false, optionWidth: number = 88) {
    Column({ space: 8 }) {
      Text(required ? `${label} *` : label)
        .width('100%')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
        .textAlign(TextAlign.Start)
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(options, (option: string) => {
          Button({ type: ButtonType.Capsule, stateEffect: true }) {
            Text(option).fontSize(15)
              .textAlign(TextAlign.Center)
              .fontColor(selected === option ? Color.White : $r('sys.color.font_secondary'))
          }
          .width(optionWidth)
          .padding(0)
          .height(40)
          .margin({ right: optionWidth <= 72 ? 6 : 8, bottom: 8 })
          .backgroundColor(selected === option ? $r('app.color.brand_blue') :
            $r('sys.color.comp_background_secondary'))
          .border({ width: selected === option ? 0 : 0.5, color: $r('sys.color.comp_divider') })
          .accessibilityText(`${label}${option}`)
          .accessibilitySelected(selected === option)
          .onClick(() => onSelect(option))
        }, (option: string) => `${label}-${option}`)
      }.width('100%')
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  private stackedDateRangeField(label: string, startPlaceholder: string, endPlaceholder: string,
    startValue: string, endValue: string, onStartChange: (value: string) => void,
    onEndChange: (value: string) => void, required: boolean = false) {
    Column({ space: 8 }) {
      Text(required ? `${label} *` : label)
        .width('100%')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
        .textAlign(TextAlign.Start)
      Row({ space: 8 }) {
        TextInput({ text: startValue, placeholder: startPlaceholder })
          .layoutWeight(1)
          .height(this.controlHeight())
          .fontSize(15)
          .backgroundColor($r('sys.color.comp_background_secondary'))
          .borderRadius(10)
          .border({ width: 0.5, color: $r('sys.color.comp_divider') })
          .onChange((next: string) => onStartChange(next))
        Text('至').fontSize(14).fontColor($r('sys.color.font_secondary'))
        TextInput({ text: endValue, placeholder: endPlaceholder })
          .layoutWeight(1)
          .height(this.controlHeight())
          .fontSize(15)
          .backgroundColor($r('sys.color.comp_background_secondary'))
          .borderRadius(10)
          .border({ width: 0.5, color: $r('sys.color.comp_divider') })
          .onChange((next: string) => onEndChange(next))
      }.width('100%').alignItems(VerticalAlign.Center)
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  private adjustAmount(current: string, delta: number, onChange: (value: string) => void): void {
    let amount: number = Number(current);
    if (isNaN(amount)) {
      amount = 0;
    }
    onChange(`${Math.max(0, amount + delta)}`);
  }

  @Builder
  private amountField(label: string, placeholder: string, value: string,
    onChange: (value: string) => void) {
    Column({ space: 8 }) {
      Text(label)
        .width('100%')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
        .textAlign(TextAlign.Start)
      Row({ space: 0 }) {
        Button({ type: ButtonType.Normal, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.minus')).fontSize(18)
            .fontColor([$r('sys.color.font_secondary')])
        }
          .width(44)
          .height(this.controlHeight())
          .padding(0)
          .backgroundColor($r('sys.color.comp_background_secondary'))
          .borderRadius({ topLeft: 10, bottomLeft: 10 })
          .accessibilityText(`减少${label}`)
          .onClick(() => this.adjustAmount(value, -100, onChange))
        TextInput({ text: value, placeholder: placeholder })
          .layoutWeight(1)
          .height(this.controlHeight())
          .fontSize(16)
          .type(InputType.Number)
          .textAlign(TextAlign.Center)
          .backgroundColor($r('sys.color.comp_background_secondary'))
          .borderRadius(0)
          .border({ width: { top: 0.5, bottom: 0.5 }, color: $r('sys.color.comp_divider') })
          .onChange((next: string) => onChange(next))
        Button({ type: ButtonType.Normal, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.plus')).fontSize(18)
            .fontColor([$r('sys.color.font_secondary')])
        }
          .width(44)
          .height(this.controlHeight())
          .padding(0)
          .backgroundColor($r('sys.color.comp_background_secondary'))
          .borderRadius({ topRight: 10, bottomRight: 10 })
          .accessibilityText(`增加${label}`)
          .onClick(() => this.adjustAmount(value, 100, onChange))
      }
      .width('100%')
      .borderRadius(10)
      .clip(true)
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  /** 只允许选择服务端返回的空床位，避免提交无法占用的自由文本。 */
  @Builder
  private bedField() {
    Column({ space: 8 }) {
      Text('入住床位 *')
        .width('100%')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
        .textAlign(TextAlign.Start)
        if (this.bedsLoading) {
          Row({ space: 8 }) {
            LoadingProgress().width(20).height(20)
            Text('正在加载空闲床位…').fontSize(14).fontColor($r('sys.color.font_tertiary'))
          }.width('100%').height(42).alignItems(VerticalAlign.Center)
        } else if (this.bedsError.length > 0) {
          Row({ space: 8 }) {
            Text(this.bedsError).fontSize(13).fontColor($r('app.color.doctor_workspace_danger')).layoutWeight(1)
            Button('重试', { type: ButtonType.Normal, stateEffect: true })
              .height(34).padding({ left: 12, right: 12 }).borderRadius(17)
              .backgroundColor($r('sys.color.comp_background_secondary'))
              .onClick(() => this.loadFreeBeds())
          }.width('100%').alignItems(VerticalAlign.Center)
        } else if (this.freeBeds.length === 0) {
          Text('暂无空闲床位，请先在床位管理中释放床位')
            .fontSize(14).fontColor($r('sys.color.font_tertiary')).height(42)
            .textAlign(TextAlign.Start)
        } else {
          Scroll() {
            Flex({ wrap: FlexWrap.Wrap }) {
              ForEach(this.freeBeds, (bed: Bed) => {
                Button({ type: ButtonType.Normal, stateEffect: true }) {
                  Text(this.bedLabel(bed)).fontSize(14)
                    .fontColor(this.bedId === bed.id ? Color.White : $r('sys.color.font_secondary'))
                }
                .height(42).padding({ left: 14, right: 14 }).margin({ right: 8, bottom: 8 })
                .borderRadius(10)
                .backgroundColor(this.bedId === bed.id ? $r('app.color.brand_blue') :
                  $r('sys.color.comp_background_secondary'))
                .border({ width: this.bedId === bed.id ? 0 : 0.5, color: $r('sys.color.comp_divider') })
                .accessibilityText(`选择床位${this.bedLabel(bed)}`)
                .accessibilitySelected(this.bedId === bed.id)
                .onClick(() => {
                  this.bedId = bed.id;
                  this.bedName = this.bedLabel(bed);
                })
              }, (bed: Bed) => `free-bed-${bed.id}`)
            }.width('100%')
          }
          .width('100%')
          .constraintSize({ maxHeight: this.compactWidth ? 184 : 156 })
          .scrollable(ScrollDirection.Vertical)
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
        }
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  private uploadField(label: string, description: string) {
    Column({ space: 8 }) {
      Text(label)
        .width('100%')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
        .textAlign(TextAlign.Start)
      Stack({ alignContent: Alignment.Center }) {
        if (this.photoPicking === label) {
          Row({ space: 8 }) {
            LoadingProgress().width(22).height(22)
            Text('正在打开相册…').fontSize(14).fontColor($r('sys.color.font_secondary'))
          }
        } else if (this.photoUri(label).length > 0) {
          // Keep the preview as a focusable button.  The delete control is a
          // sibling in the Stack rather than a child of this button, so the
          // two actions do not share an interactive/accessibility node.
          Button({ type: ButtonType.Normal, stateEffect: true }) {
            Image(this.photoUri(label))
              .width('100%')
              .height('100%')
              .objectFit(ImageFit.Contain)
          }
          .width('100%')
          .height('100%')
          .padding(0)
          .borderRadius(10)
          .backgroundColor(Color.Transparent)
          .enabled(!this.photoControlsLocked(label))
          .opacity(this.submitting ? 0.72 : 1)
          .keyboardFocusStyle()
          .accessibilityText(`${label}预览，点击可更换`)
          .accessibilityRole(AccessibilityRoleType.BUTTON)
          .onClick(() => {
            if (!this.photoControlsLocked(label)) {
              void this.pickPhoto(label);
            }
          })
          /* The delete button is intentionally larger than its glyph so the
           * destructive target remains easy to hit without enlarging the icon. */
          Button({ type: ButtonType.Circle, stateEffect: true }) {
            SymbolGlyph($r('sys.symbol.xmark')).fontSize(18)
              .fontColor([$r('sys.color.font_on_primary')])
          }
          .width(44).height(44)
          .padding(0)
          .position({ top: 6, right: 6 })
          .backgroundColor('#99000000')
          .enabled(!this.photoControlsLocked(label))
          .opacity(this.photoControlsLocked(label) ? 0.55 : 1)
          .accessibilityText(`移除${label}`)
          .accessibilityRole(AccessibilityRoleType.BUTTON)
          .keyboardFocusStyle()
          .onClick(() => this.removePhoto(label))
          Text('已选择 · 点击图片可更换')
            .fontSize(12)
            .fontColor(Color.White)
            .backgroundColor('#99000000')
            .padding({ left: 8, right: 8, top: 4, bottom: 4 })
            .borderRadius(6)
            .hitTestBehavior(HitTestMode.None)
            .position({ bottom: 8, left: 8 })
        } else {
          Button({ type: ButtonType.Normal, stateEffect: true }) {
            Row({ space: 10 }) {
              SymbolGlyph($r('sys.symbol.camera_fill')).fontSize(22)
                .fontColor([$r('app.color.brand_blue')])
              Column({ space: 2 }) {
                Text('点击选择照片').fontSize(15).fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.brand_blue'))
                Text(description).fontSize(12).fontColor($r('sys.color.font_tertiary'))
              }.alignItems(HorizontalAlign.Start)
            }
          }
          .width('100%')
          .height('100%')
          .padding({ left: 16, right: 16 })
          .borderRadius(10)
          .backgroundColor(Color.Transparent)
          .enabled(!this.photoControlsLocked(label))
          .keyboardFocusStyle()
          .accessibilityText(`${label}，点击选择照片`)
          .accessibilityRole(AccessibilityRoleType.BUTTON)
          .onClick(() => {
            if (!this.photoControlsLocked(label)) {
              void this.pickPhoto(label);
            }
          })
        }
      }
      .width('100%')
      // Reserve the same image well for empty, loading, and selected states so
      // the three columns do not jump when one slot receives a photo.
      .height(132)
      .backgroundColor($r('sys.color.comp_background_secondary'))
      .borderRadius(10)
      .border({ width: 0.5, color: $r('sys.color.comp_divider') })
      .clip(true)
      Text(this.photoStatusText(label))
        .height(18)
        .fontSize(12)
        .fontColor(this.photoStatusColor(label))
        .width('100%')
        .textAlign(TextAlign.Start)
        .opacity(this.photoStatusText(label).length > 0 ? 1 : 0)
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  /** A wide field with the label above the control, avoiding compressed labels. */
  @Builder
  private familyStackedTextField(label: string, placeholder: string, value: string,
    onChange: (value: string) => void, numeric: boolean = false) {
    Column({ space: 8 }) {
      Text(label)
        .width('100%')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
        .textAlign(TextAlign.Start)
      TextInput({ text: value, placeholder: placeholder })
        .width('100%')
        .height(this.controlHeight())
        .fontSize(16)
        .fontColor($r('sys.color.font_primary'))
        .backgroundColor($r('sys.color.comp_background_secondary'))
        .borderRadius(10)
        .border({ width: 0.5, color: $r('sys.color.comp_divider') })
        .type(numeric ? InputType.Number : InputType.Normal)
        .onFocus(() => this.activeField = label)
        .onChange((next: string) => {
          onChange(next);
          this.activeField = label;
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /** Relationship choices share the same grid cell and remain one line wide. */
  @Builder
  private familyStackedRelationField() {
    Column({ space: 8 }) {
      Text('与长者关系')
        .width('100%')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
        .textAlign(TextAlign.Start)
      Row({ space: 6 }) {
        ForEach(['子女', '配偶', '亲属', '其他'], (option: string) => {
          Button({ type: ButtonType.Capsule, stateEffect: true }) {
            Text(option)
              .fontSize(14)
              .textAlign(TextAlign.Center)
              .fontColor(this.familyRelation === option ? Color.White : $r('sys.color.font_secondary'))
          }
          // Share the available cell width so the relationship choices align
          // with the adjacent full-width fields instead of leaving a large
          // unexplained trailing gap on wide windows.
          .layoutWeight(1)
          .constraintSize({ minWidth: this.compactWidth ? 56 : 60 })
          .height(40)
          .padding(0)
          .backgroundColor(this.familyRelation === option ? $r('app.color.brand_blue') :
            $r('sys.color.comp_background_secondary'))
          .border({ width: this.familyRelation === option ? 0 : 0.5,
            color: $r('sys.color.comp_divider') })
          .accessibilityText(`与长者关系${option}`)
          .accessibilitySelected(this.familyRelation === option)
          .onClick(() => this.familyRelation = option)
        }, (option: string) => `family-relation-${option}`)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private familyActions() {
    Row({ space: 8 }) {
      Button({ type: ButtonType.Normal, stateEffect: true }) {
        Row({ space: 6 }) {
          SymbolGlyph($r('sys.symbol.plus')).fontSize(16)
            .fontColor([$r('app.color.brand_blue')])
          Text('添加家属').fontSize(13).fontColor($r('app.color.brand_blue'))
        }
      }
      .height(38)
      .padding({ left: 10, right: 10 })
      .borderRadius(19)
      .backgroundColor($r('sys.color.comp_background_secondary'))
      .accessibilityText('添加家属')
      .onClick(() => this.showToast('家属信息可继续添加'))
      Button({ type: ButtonType.Normal, stateEffect: true }) {
        SymbolGlyph($r('sys.symbol.minus')).fontSize(16)
          .fontColor([$r('sys.color.font_secondary')])
      }
      .width(38)
      .height(38)
      .padding(0)
      .borderRadius(19)
      .backgroundColor($r('sys.color.comp_background_secondary'))
      .accessibilityText('删除家属')
      .onClick(() => this.showToast('当前至少保留一位联系人'))
    }
    .width(144)
    .justifyContent(FlexAlign.End)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private familyGroupCard() {
    Column({ space: 0 }) {
      Row() {
        Text('家属信息')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
        Blank().layoutWeight(1)
        this.familyActions()
      }
      .width('100%')
      .height(58)
      .padding({ left: 20, right: 20 })
      .alignItems(VerticalAlign.Center)
      Divider()
        .strokeWidth(0.5)
        .color($r('sys.color.comp_divider'))
        .margin({ left: 16, right: 16 })
      Column({ space: 0 }) {
        this.familyFields()
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 18, bottom: 20 })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(16)
    .clip(true)
    .border({ width: 0.5, color: $r('sys.color.comp_divider') })
  }

  @Builder
  private formContent() {
    Column({ space: 20 }) {
      AdmissionGroupCard({ title: '基本信息',
        content: (): void => { this.identityFields(); } });
      this.familyGroupCard();
      AdmissionGroupCard({ title: '入住配置',
        content: (): void => { this.arrangementFields(); } });
    }.width('100%')
  }

  @Builder
  private identityFields() {
    GridRow({ columns: 12, gutter: { x: 14, y: 14 } }) {
      GridCol({ span: this.compactWidth ? 12 : 6 }) {
        this.stackedTextField('姓名', '请输入长者姓名', this.name, (value: string) => this.name = value, true)
      }
      GridCol({ span: this.compactWidth ? 12 : 6 }) {
        this.stackedTextField('身份证号', '请输入身份证号', this.idCard,
          (value: string) => this.idCard = value, true)
      }
      GridCol({ span: this.compactWidth ? 12 : 6 }) {
        this.stackedTextField('出生日期', '请选择出生日期', this.birthDate,
          (value: string) => this.birthDate = value, true)
      }
      GridCol({ span: this.compactWidth ? 12 : 6 }) {
        this.stackedTextField('年龄', '请输入年龄', this.age,
          (value: string) => this.age = value, true, true)
      }
      GridCol({ span: this.compactWidth ? 12 : 6 }) {
        this.stackedChoiceField('性别', ['男', '女'], this.gender, (value: string) => this.gender = value, true)
      }
      GridCol({ span: this.compactWidth ? 12 : 6 }) {
        this.stackedTextField('联系方式', '请输入手机号或其他联系方式', this.phone,
          (value: string) => this.phone = value, false, true)
      }
      GridCol({ span: 12 }) {
        this.stackedTextAreaField('家庭住址', '请输入家庭住址', this.familyAddress,
          (value: string) => this.familyAddress = value)
      }
      GridCol({ span: this.compactWidth ? 12 : 4 }) {
        this.uploadField('一寸照片', '支持 JPG、PNG、WebP，5MB以内')
      }
      GridCol({ span: this.compactWidth ? 12 : 4 }) {
        this.uploadField('身份证人像面', '支持 JPG、PNG、WebP，5MB以内')
      }
      GridCol({ span: this.compactWidth ? 12 : 4 }) {
        this.uploadField('身份证国徽面', '支持 JPG、PNG、WebP，5MB以内')
      }
    }.width('100%')
  }

  @Builder
  private familyFields() {
    if (this.compactWidth) {
      Column({ space: 12 }) {
        this.stackedTextField('家属姓名', '请输入主要联系人姓名', this.familyName,
          (value: string) => this.familyName = value)
        this.stackedTextField('家属联系方式', '请输入手机号或其他联系方式', this.familyPhone,
          (value: string) => this.familyPhone = value, false, true)
        this.stackedChoiceField('与长者关系', ['子女', '配偶', '亲属', '其他'], this.familyRelation,
          (value: string) => this.familyRelation = value, false, 72)
      }.width('100%')
    } else {
      GridRow({ columns: 12, gutter: { x: 18, y: 14 } }) {
        GridCol({ span: 4 }) {
          this.familyStackedTextField('家属姓名', '请输入主要联系人姓名', this.familyName,
            (value: string) => this.familyName = value)
        }
        GridCol({ span: 4 }) {
          this.familyStackedTextField('家属联系方式', '请输入手机号或其他联系方式', this.familyPhone,
            (value: string) => this.familyPhone = value, true)
        }
        GridCol({ span: 4 }) {
          this.familyStackedRelationField()
        }
      }.width('100%')
    }
  }

  @Builder
  private arrangementFields() {
    GridRow({ columns: 12, gutter: { x: 14, y: 14 } }) {
      GridCol({ span: this.compactWidth ? 12 : 6 }) {
        this.stackedDateRangeField('入住期限', '开始日期', '结束日期', this.admissionDate, this.admissionEndDate,
          (value: string) => this.admissionDate = value,
          (value: string) => this.admissionEndDate = value, true)
      }
      GridCol({ span: this.compactWidth ? 12 : 6 }) {
        this.stackedDateRangeField('费用期限', '开始日期', '结束日期', this.feeStartDate, this.feeEndDate,
          (value: string) => this.feeStartDate = value,
          (value: string) => this.feeEndDate = value)
      }
      GridCol({ span: this.compactWidth ? 12 : 6 }) {
        this.stackedChoiceField('护理等级', this.careLevelOptions, this.careLevel,
          (value: string) => this.careLevel = value, true)
      }
      // On wide windows the level and bed selectors form one balanced row;
      // keeping the bed selector full-width here left an avoidable empty band
      // beside the care-level choices. Narrow windows retain the stacked flow
      // so the controls stay touchable and readable.
      GridCol({ span: this.compactWidth ? 12 : 6 }) {
        this.bedField()
      }
      GridCol({ span: this.compactWidth ? 6 : 4 }) {
        this.amountField('押金', '请输入金额', this.deposit, (value: string) => this.deposit = value)
      }
      GridCol({ span: this.compactWidth ? 6 : 4 }) {
        this.amountField('护理费用', '请输入金额', this.careFee, (value: string) => this.careFee = value)
      }
      GridCol({ span: this.compactWidth ? 6 : 4 }) {
        this.amountField('床位费用', '请输入金额', this.bedFee, (value: string) => this.bedFee = value)
      }
      GridCol({ span: this.compactWidth ? 6 : 4 }) {
        this.amountField('其他费用', '请输入金额', this.otherFee, (value: string) => this.otherFee = value)
      }
      GridCol({ span: this.compactWidth ? 6 : 4 }) {
        this.amountField('医保支付', '请输入金额', this.medicalInsurance,
          (value: string) => this.medicalInsurance = value)
      }
      GridCol({ span: this.compactWidth ? 6 : 4 }) {
        this.amountField('政府补贴', '请输入金额', this.subsidy, (value: string) => this.subsidy = value)
      }
      GridCol({ span: 12 }) {
        this.stackedTextAreaField('入住备注', '记录接待安排、饮食偏好或其他需要关注的事项', this.note,
          (value: string) => this.note = value)
      }
    }.width('100%')
  }

  @Builder
  private resultView() {
    Column({ space: 14 }) {
      SymbolGlyph($r('sys.symbol.checkmark_circle_fill')).fontSize(52)
        .fontColor([$r('app.color.brand_blue')])
      Text('入住办理已完成').fontSize(22).fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_primary'))
      Text('服务端已完成老人档案、床位和护理计划同步。')
        .fontSize(13).fontColor($r('sys.color.font_secondary')).textAlign(TextAlign.Center)
      AdmissionGroupCard({ title: '填写完成', content: () => {
        HdsListItemCard({
          textItem: {
            primaryText: { text: this.resultPrimaryText() },
            secondaryText: { text: this.resultSecondaryText() }
          },
          suffixItem: new SuffixText({ text: '已完成' }),
          cardBorderRadius: 0,
          cardBackgroundColor: $r('sys.color.ohos_id_color_background_transparent'),
          cardHeight: 68,
          cardPrefixMargin: 16,
          cardSuffixMargin: 16,
          hoverBorderRadius: 0
        })
      } }).width(this.compactWidth ? '100%' : 520)
      Row({ space: 10 }) {
        Button('重新填写').height(44).borderRadius(12).fontSize(14)
          .backgroundColor($r('sys.color.comp_background_secondary'))
          .onClick(() => this.resetForm())
        Button('返回工作台').height(44).borderRadius(12).fontSize(14)
          .fontColor(Color.White).backgroundColor($r('app.color.brand_blue'))
          .onClick(() => this.closeForm())
      }
    }.width('100%').height('100%').justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
  }

  @Builder
  private footer() {
    Column({ space: 8 }) {
      Row({ space: 10 }) {
        Button('取消').height(44).borderRadius(12).fontSize(14)
          .backgroundColor($r('sys.color.comp_background_secondary'))
          .opacity(this.submitting || this.photoPicking.length > 0 ? 0.45 : 1)
          .enabled(!this.submitting && this.photoPicking.length === 0)
          .onClick(() => this.closeForm())
        Button(this.submitting ? '提交中…' : '确认办理入住').height(44).borderRadius(12).fontSize(14)
          .fontColor(Color.White).backgroundColor($r('app.color.brand_blue'))
          .opacity(this.requiredReady() && !this.submitting ? 1 : 0.45)
          .enabled(this.requiredReady() && !this.submitting)
          .onClick(() => this.confirmForm())
      }
      .width('100%')
      .justifyContent(FlexAlign.End)
      if (this.submitError.length > 0) {
        Text(this.submitError)
          .width('100%')
          .fontSize(12)
          .fontColor($r('app.color.doctor_workspace_danger'))
          .textAlign(TextAlign.End)
          .maxLines(2)
      }
    }
    .width('100%')
    .padding({ top: 12, bottom: 12 + this.naviIndicatorHeight })
  }

  build() {
    HdsNavDestination() {
      if (this.submitted) {
        Column() {
          this.resultView()
        }
        .width('100%')
        .height('100%')
        .padding({ left: this.horizontalPadding(), right: this.horizontalPadding(),
          top: 24 + this.statusBarHeight, bottom: 24 + this.naviIndicatorHeight })
      } else {
        Column() {
          Scroll(this.scroller) {
            Row() {
              Column({ space: 18 }) {
                this.formContent()
                this.footer()
              }
              .width('100%')
              // Keep the form close to the available canvas while retaining a
              // readable line length. The medium-window cap is intentionally
              // wider than the old 720vp value so tablet layouts do not leave
              // an unexplained empty band at either side.
              .constraintSize({ maxWidth: this.formMaxWidth() })
              .padding({ left: this.horizontalPadding(), right: this.horizontalPadding(),
                top: this.statusBarHeight + 56, bottom: 20 + this.naviIndicatorHeight })
              .alignItems(HorizontalAlign.Center)
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
          }
          .layoutWeight(1)
          .width('100%')
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
        }
        .width('100%')
        .height('100%')
      }
    }
    // Keep the native back affordance visible during normal editing, but hide
    // it while a write is in flight so the admission destination cannot be
    // popped around the guarded cancel action.
    .hideBackButton(this.submitting)
    .onBackPressed((): boolean => {
      this.closeForm();
      return true;
    })
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .titleBar({
      avoidLayoutSafeArea: true,
      content: {
        title: { mainTitle: '办理入住' }
      },
      style: this.titleBarStyle()
    })
    .bindToScrollable([this.scroller])
    .backgroundColor($r('sys.color.background_secondary'))
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
  }
}
