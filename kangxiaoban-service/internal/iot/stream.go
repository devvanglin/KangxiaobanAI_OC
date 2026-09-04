package iot

// RTSP 摄像头预览转码：把每条摄像头的 RTSP 流用 ffmpeg 转成 HLS 分片，
// 由后端通过 /api/v1/iot/preview/:id/:file?token=... 供 HarmonyOS Video 播放。
// HarmonyOS AVPlayer 不支持 RTSP，仅支持 HTTP(S) 下的 HLS，因此必须有这一步转码。

import (
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/base64"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"time"

	"kangxiaoban-service/internal/config"
)

// StreamSession 一台摄像头的转码会话。
type StreamSession struct {
	id      uint
	dir     string
	cmd     *exec.Cmd
	cancel  context.CancelFunc
	done    chan struct{}
	mu      sync.Mutex
	lastHit time.Time
	live    bool   // false 表示进程已退出
	lastErr string // 捕获 ffmpeg stderr 用于诊断
}

// StreamManager 管理多条 RTSP 的 ffmpeg HLS 会话，并负责令牌签发与分片文件服务。
type StreamManager struct {
	cfg      config.StreamConfig
	secret   []byte
	mu       sync.Mutex
	sessions map[uint]*StreamSession
	startAt  map[uint]time.Time // 防崩溃后高频重启同一摄像头
	done     chan struct{}
}

// NewStreamManager 创建流管理器。secret 用于签发预览令牌（建议用 JWT 密钥）。
func NewStreamManager(cfg config.StreamConfig, secret string) *StreamManager {
	m := &StreamManager{
		cfg:      cfg,
		secret:   []byte(secret),
		sessions: make(map[uint]*StreamSession),
		startAt:  make(map[uint]time.Time),
		done:     make(chan struct{}),
	}
	if cfg.Enabled {
		go m.janitor()
	}
	return m
}

// Stop 停止所有会话并回收全部 ffmpeg 进程（进程退出时调用）。
func (m *StreamManager) Stop() {
	close(m.done)
	m.mu.Lock()
	defer m.mu.Unlock()
	for id, s := range m.sessions {
		m.kill(s)
		delete(m.sessions, id)
	}
}

// Enabled 报告转码服务是否启用。
func (m *StreamManager) Enabled() bool { return m.cfg.Enabled }

func (m *StreamManager) ffmpegBin() string {
	if strings.TrimSpace(m.cfg.FfmpegPath) != "" {
		return strings.TrimSpace(m.cfg.FfmpegPath)
	}
	return "ffmpeg"
}

// Preview 确保某个设备的转码会话存在并返回其可播放的 HLS 相对地址。
func (m *StreamManager) Preview(id uint, streamURL string) (string, error) {
	if !m.cfg.Enabled {
		return "", fmt.Errorf("转码服务未启用")
	}
	if _, err := exec.LookPath(m.ffmpegBin()); err != nil {
		return "", fmt.Errorf("未找到 ffmpeg，无法转码 RTSP（%v）", err)
	}
	if _, err := m.ensure(id, streamURL); err != nil {
		return "", err
	}
	// 等待首个分片就绪，避免客户端播放时仍处于初始化竞态。
	m.waitPlaylist(id, 8*time.Second)
	return m.hlsURL(id), nil
}

// waitPlaylist 短暂轮询等待 index.m3u8 生成；超时也返回（交由播放器续拉）。
func (m *StreamManager) waitPlaylist(id uint, timeout time.Duration) {
	dir := filepath.Join(m.cfg.Dir, strconv.FormatUint(uint64(id), 10))
	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
		info, err := os.Stat(filepath.Join(dir, "index.m3u8"))
		if err == nil && info.Size() > 0 {
			return
		}
		time.Sleep(250 * time.Millisecond)
	}
}

// StopSession 主动停止某台设备的转码会话。
func (m *StreamManager) StopSession(id uint) {
	m.mu.Lock()
	defer m.mu.Unlock()
	if s, ok := m.sessions[id]; ok {
		m.kill(s)
		delete(m.sessions, id)
	}
}

func (m *StreamManager) session(id uint) *StreamSession {
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.sessions[id]
}

func (m *StreamManager) hlsURL(id uint) string {
	return fmt.Sprintf("/api/v1/iot/preview/%d/%s/index.m3u8", id, m.signToken(id))
}

// ensure 启动（或复用）某设备的 ffmpeg 转码进程，并把分片写入本地目录。
// 输出目录固定为 <Dir>/<deviceID>，由配置的绝对根目录决定，避免依赖运行 cwd。
func (m *StreamManager) ensure(id uint, streamURL string) (*StreamSession, error) {
	m.mu.Lock()
	if s, ok := m.sessions[id]; ok {
		s.setLive(m.isAlive(s))
		if s.live {
			m.mu.Unlock()
			return s, nil
		}
	}

	// 同一设备 10 秒内崩溃多次则不再无限重启，避免空转。
	if last, ok := m.startAt[id]; ok && time.Since(last) < 10*time.Second {
		m.mu.Unlock()
		return nil, fmt.Errorf("摄像头流启动失败，请稍后重试")
	}

	dir := filepath.Join(m.cfg.Dir, strconv.FormatUint(uint64(id), 10))
	if err := os.MkdirAll(dir, 0o755); err != nil {
		m.mu.Unlock()
		return nil, fmt.Errorf("创建转码目录失败: %v", err)
	}
	if err := removeSegments(dir); err != nil {
		log.Printf("clean stream dir %s: %v", dir, err)
	}

	args := []string{
		"-hide_banner", "-loglevel", "error",
		"-rtsp_transport", "tcp",
		"-i", streamURL,
		"-an",
		"-c:v", "libx264",
		"-preset", "veryfast", "-tune", "zerolatency",
		"-pix_fmt", "yuv420p",
		"-g", "50", "-keyint_min", "50",
		"-sc_threshold", "0",
		"-b:v", "2000k", "-maxrate", "2500k", "-bufsize", "4000k",
		"-f", "hls",
		"-hls_time", "2",
		"-hls_list_size", "8",
		"-hls_flags", "independent_segments+delete_segments+omit_endlist",
		"-hls_segment_filename", filepath.Join(dir, "seg%05d.ts"),
		filepath.Join(dir, "index.m3u8"),
	}

	cctx, cancel := context.WithCancel(context.Background())
	cmd := exec.CommandContext(cctx, m.ffmpegBin(), args...)
	stderr, err := cmd.StderrPipe()
	if err != nil {
		cancel()
		m.mu.Unlock()
		return nil, fmt.Errorf("无法读取 ffmpeg 输出: %v", err)
	}
	if err := cmd.Start(); err != nil {
		cancel()
		m.mu.Unlock()
		return nil, fmt.Errorf("启动 ffmpeg 失败: %v", err)
	}

	s := &StreamSession{id: id, dir: dir, cmd: cmd, cancel: cancel, done: make(chan struct{}), lastHit: time.Now(), live: true}
	m.sessions[id] = s
	m.startAt[id] = time.Now()
	go m.collectStderr(s, stderr)
	go m.watch(id, s, cmd)
	m.mu.Unlock()
	return s, nil
}

func (m *StreamManager) watch(id uint, s *StreamSession, cmd *exec.Cmd) {
	err := cmd.Wait()
	s.setLive(false)
	close(s.done)
	if err != nil {
		log.Printf("stream ffmpeg exit, device=%d, dir=%s, err=%v, stderr=%s", id, s.dir, err, s.errSnapshot())
	}
}

// Serve 校验令牌后提供 HLS 分片文件（index.m3u8 或 seg00001.ts）。
func (m *StreamManager) Serve(id uint, file, token string, w http.ResponseWriter, r *http.Request) {
	if !m.verifyToken(id, token) {
		http.Error(w, "预览令牌无效或已过期", http.StatusUnauthorized)
		return
	}
	s := m.session(id)
	if s == nil || !s.isLive() {
		http.Error(w, "转码会话未就绪，请重新发起预览", http.StatusNotFound)
		return
	}
	base := filepath.Base(filepath.Clean("/" + file))
	if base == "" || base != file {
		http.Error(w, "非法文件", http.StatusBadRequest)
		return
	}
	full := filepath.Join(s.dir, base)
	rel, err := filepath.Rel(s.dir, full)
	if err != nil || strings.HasPrefix(rel, "..") {
		http.Error(w, "非法文件", http.StatusBadRequest)
		return
	}
	if _, err := os.Stat(full); err != nil {
		http.Error(w, "分片尚未生成", http.StatusNotFound)
		return
	}
	s.touch()
	if strings.HasSuffix(base, ".m3u8") {
		w.Header().Set("Content-Type", "application/vnd.apple.mpegurl")
	} else if strings.HasSuffix(base, ".ts") {
		w.Header().Set("Content-Type", "video/mp2t")
	}
	w.Header().Set("Cache-Control", "no-store")
	http.ServeFile(w, r, full)
}

func (m *StreamManager) isAlive(s *StreamSession) bool {
	return s.cmd != nil && s.cmd.Process != nil && s.cmd.ProcessState == nil
}

func (m *StreamManager) kill(s *StreamSession) {
	if s == nil {
		return
	}
	if s.cancel != nil {
		s.cancel()
	}
	if s.cmd != nil && s.cmd.Process != nil {
		_ = s.cmd.Process.Kill()
	}
	s.setLive(false)
}

// janitor 定期回收空闲或已退出的转码进程，避免残留 ffmpeg 与磁盘分片。
func (m *StreamManager) janitor() {
	ticker := time.NewTicker(30 * time.Second)
	defer ticker.Stop()
	for {
		select {
		case <-m.done:
			return
		case now := <-ticker.C:
			m.mu.Lock()
			for id, s := range m.sessions {
				s.setLive(m.isAlive(s))
				if !s.live || now.Sub(s.hitTime()) > m.cfg.IdleTTL {
					m.kill(s)
					delete(m.sessions, id)
					_ = os.RemoveAll(s.dir)
				}
			}
			m.mu.Unlock()
		}
	}
}

// ---- 会话辅助 ----

func (s *StreamSession) touch() {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.lastHit = time.Now()
}

func (s *StreamSession) hitTime() time.Time {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.lastHit
}

func (s *StreamSession) isLive() bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.live
}

func (s *StreamSession) setLive(v bool) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.live = v
}

func (s *StreamSession) errSnapshot() string {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.lastErr
}

// collectStderr 持续读取 ffmpeg stderr，保留最近一段以便出错时诊断。
func (m *StreamManager) collectStderr(s *StreamSession, r io.Reader) {
	const max = 4096
	buf := make([]byte, 0, max)
	chunk := make([]byte, 1024)
	for {
		n, err := r.Read(chunk)
		if n > 0 {
			buf = append(buf, chunk[:n]...)
			if len(buf) > max {
				buf = buf[len(buf)-max:]
			}
			s.appendErr(string(buf))
			buf = buf[:0]
		}
		if err != nil {
			return
		}
	}
}

func (s *StreamSession) appendErr(v string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.lastErr = v
}

// ---- 令牌：HMAC(secret, "<id>:<exp>")，过期时间在令牌里，设备 id 在路径里，防跨设备复用 ----

func (m *StreamManager) signToken(id uint) string {
	exp := time.Now().Add(m.cfg.TokenTTL).Unix()
	sig := base64.RawURLEncoding.EncodeToString(m.hmac(id, exp))
	return fmt.Sprintf("%d:%s", exp, sig)
}

func (m *StreamManager) verifyToken(id uint, token string) bool {
	sep := strings.IndexByte(token, ':')
	if sep <= 0 {
		return false
	}
	exp, err := strconv.ParseInt(token[:sep], 10, 64)
	if err != nil || exp < time.Now().Unix() {
		return false
	}
	want := base64.RawURLEncoding.EncodeToString(m.hmac(id, exp))
	return subtle.ConstantTimeCompare([]byte(token[sep+1:]), []byte(want)) == 1
}

func (m *StreamManager) hmac(id uint, exp int64) []byte {
	mac := hmac.New(sha256.New, m.secret)
	_, _ = fmt.Fprintf(mac, "%d:%d", id, exp)
	return mac.Sum(nil)
}

func removeSegments(dir string) error {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return err
	}
	for _, e := range entries {
		_ = os.RemoveAll(filepath.Join(dir, e.Name()))
	}
	return nil
}
