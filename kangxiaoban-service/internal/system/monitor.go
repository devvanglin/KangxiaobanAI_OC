package system

import (
	"net"
	"os"
	"runtime"
	"strconv"
	"sync"
	"time"
)

var processStartedAt = time.Now()

// DiskStat describes one visible filesystem mount.
type DiskStat struct {
	Mount       string  `json:"mount"`
	Filesystem  string  `json:"filesystem"`
	TotalBytes  uint64  `json:"total_bytes"`
	UsedBytes   uint64  `json:"used_bytes"`
	FreeBytes   uint64  `json:"free_bytes"`
	UsedPercent float64 `json:"used_percent"`
}

type CPUStat struct {
	Cores         int     `json:"cores"`
	Usage         float64 `json:"usage_percent"`
	UserPercent   float64 `json:"user_percent"`
	SystemPercent float64 `json:"system_percent"`
	IdlePercent   float64 `json:"idle_percent"`
	Available     bool    `json:"available"`
}

type MemoryStat struct {
	TotalBytes     uint64  `json:"total_bytes"`
	UsedBytes      uint64  `json:"used_bytes"`
	FreeBytes      uint64  `json:"free_bytes"`
	UsedPercent    float64 `json:"used_percent"`
	ProcessBytes   uint64  `json:"process_bytes"`
	ProcessPercent float64 `json:"process_percent"`
	Available      bool    `json:"available"`
}

type ServerInfo struct {
	Hostname      string `json:"hostname"`
	IP            string `json:"ip"`
	OS            string `json:"os"`
	Arch          string `json:"arch"`
	PID           int    `json:"pid"`
	GoVersion     string `json:"go_version"`
	StartedAt     string `json:"started_at"`
	UptimeSeconds int64  `json:"uptime_seconds"`
	UptimeText    string `json:"uptime_text"`
	Goroutines    int    `json:"goroutines"`
}

type Snapshot struct {
	CollectedAt string      `json:"collected_at"`
	CPU         CPUStat     `json:"cpu"`
	Memory      MemoryStat  `json:"memory"`
	Server      ServerInfo  `json:"server"`
	Disks       []DiskStat  `json:"disks"`
	Network     NetworkStat `json:"network"`
}

// NetworkInterfaceStat describes one non-loopback interface's counters and
// the receive/transmit rates calculated between monitor samples.
type NetworkInterfaceStat struct {
	Name            string  `json:"name"`
	ReceiveBytes    uint64  `json:"receive_bytes"`
	TransmitBytes   uint64  `json:"transmit_bytes"`
	ReceiveRateBps  float64 `json:"receive_rate_bps"`
	TransmitRateBps float64 `json:"transmit_rate_bps"`
}

type NetworkStat struct {
	Available       bool                   `json:"available"`
	Interface       string                 `json:"interface"`
	ReceiveBytes    uint64                 `json:"receive_bytes"`
	TransmitBytes   uint64                 `json:"transmit_bytes"`
	ReceiveRateBps  float64                `json:"receive_rate_bps"`
	TransmitRateBps float64                `json:"transmit_rate_bps"`
	Interfaces      []NetworkInterfaceStat `json:"interfaces"`
}

type networkCounter struct {
	receiveBytes  uint64
	transmitBytes uint64
}

var networkState = struct {
	sync.Mutex
	previous map[string]networkCounter
	at       time.Time
}{previous: map[string]networkCounter{}}

// Collect returns host and process metrics. Platform-specific files provide
// CPU, host memory, and disk collection while this file keeps the contract
// stable for both Linux deployment and Windows development builds.
func Collect() Snapshot {
	now := time.Now()
	hostname, _ := os.Hostname()
	info := ServerInfo{
		Hostname:      hostname,
		IP:            firstLocalIP(),
		OS:            runtime.GOOS,
		Arch:          runtime.GOARCH,
		PID:           os.Getpid(),
		GoVersion:     runtime.Version(),
		StartedAt:     processStartedAt.Format(time.RFC3339),
		UptimeSeconds: int64(now.Sub(processStartedAt).Seconds()),
		Goroutines:    runtime.NumGoroutine(),
	}
	info.UptimeText = formatUptime(info.UptimeSeconds)
	return Snapshot{CollectedAt: now.Format(time.RFC3339), CPU: collectCPU(), Memory: collectMemory(), Server: info, Disks: collectDisks(), Network: collectNetwork()}
}

func collectNetwork() NetworkStat {
	counters, ok := readNetworkCounters()
	if !ok || len(counters) == 0 {
		return NetworkStat{Available: false, Interface: "all", Interfaces: []NetworkInterfaceStat{}}
	}
	now := time.Now()
	networkState.Lock()
	defer networkState.Unlock()
	interval := now.Sub(networkState.at).Seconds()
	if interval <= 0 {
		interval = 0
	}
	items := make([]NetworkInterfaceStat, 0, len(counters))
	var receiveBytes, transmitBytes uint64
	var receiveRate, transmitRate float64
	for name, counter := range counters {
		previous, exists := networkState.previous[name]
		item := NetworkInterfaceStat{Name: name, ReceiveBytes: counter.receiveBytes, TransmitBytes: counter.transmitBytes}
		if exists && interval > 0 && counter.receiveBytes >= previous.receiveBytes && counter.transmitBytes >= previous.transmitBytes {
			item.ReceiveRateBps = float64(counter.receiveBytes-previous.receiveBytes) / interval
			item.TransmitRateBps = float64(counter.transmitBytes-previous.transmitBytes) / interval
		}
		receiveBytes += counter.receiveBytes
		transmitBytes += counter.transmitBytes
		receiveRate += item.ReceiveRateBps
		transmitRate += item.TransmitRateBps
		items = append(items, item)
	}
	networkState.previous = counters
	networkState.at = now
	return NetworkStat{Available: true, Interface: "all", ReceiveBytes: receiveBytes, TransmitBytes: transmitBytes,
		ReceiveRateBps: receiveRate, TransmitRateBps: transmitRate, Interfaces: items}
}

func firstLocalIP() string {
	interfaces, err := net.Interfaces()
	if err != nil {
		return ""
	}
	for _, item := range interfaces {
		if item.Flags&net.FlagUp == 0 || item.Flags&net.FlagLoopback != 0 {
			continue
		}
		addresses, err := item.Addrs()
		if err != nil {
			continue
		}
		for _, address := range addresses {
			if ipNet, ok := address.(*net.IPNet); ok && ipNet.IP.To4() != nil {
				return ipNet.IP.String()
			}
		}
	}
	return "127.0.0.1"
}

func formatUptime(seconds int64) string {
	if seconds < 0 {
		seconds = 0
	}
	days := seconds / 86400
	hours := (seconds % 86400) / 3600
	minutes := (seconds % 3600) / 60
	if days > 0 {
		return formatNumber(days) + "天" + formatNumber(hours) + "小时"
	}
	return formatNumber(hours) + "小时" + formatNumber(minutes) + "分钟"
}

func formatNumber(value int64) string {
	return strconv.FormatInt(value, 10)
}

func percent(value, total float64) float64 {
	if total <= 0 {
		return 0
	}
	return float64(int(value/total*1000+0.5)) / 10
}
