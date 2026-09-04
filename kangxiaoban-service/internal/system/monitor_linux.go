//go:build linux

package system

import (
	"bufio"
	"os"
	"runtime"
	"strconv"
	"strings"
	"syscall"
	"time"
)

type cpuTicks struct{ user, system, idle, total uint64 }

func collectCPU() CPUStat {
	first, ok := readCPUTicks()
	if !ok {
		return CPUStat{Cores: 0, Available: false}
	}
	time.Sleep(120 * time.Millisecond)
	second, ok := readCPUTicks()
	if !ok || second.total <= first.total {
		return CPUStat{Cores: intValueCPU(), Available: false}
	}
	total := float64(second.total - first.total)
	idle := float64(second.idle - first.idle)
	user := float64(second.user - first.user)
	system := float64(second.system - first.system)
	return CPUStat{Cores: intValueCPU(), Usage: percent(total-idle, total), UserPercent: percent(user, total), SystemPercent: percent(system, total), IdlePercent: percent(idle, total), Available: true}
}

func intValueCPU() int { return runtime.NumCPU() }

func readCPUTicks() (cpuTicks, bool) {
	file, err := os.Open("/proc/stat")
	if err != nil {
		return cpuTicks{}, false
	}
	defer file.Close()
	scanner := bufio.NewScanner(file)
	if !scanner.Scan() {
		return cpuTicks{}, false
	}
	parts := strings.Fields(scanner.Text())
	if len(parts) < 5 || parts[0] != "cpu" {
		return cpuTicks{}, false
	}
	values := make([]uint64, 0, len(parts)-1)
	for _, part := range parts[1:] {
		value, err := strconv.ParseUint(part, 10, 64)
		if err != nil {
			return cpuTicks{}, false
		}
		values = append(values, value)
	}
	var idle uint64
	for _, value := range values {
		idle += value
	}
	if len(values) > 3 {
		idle = values[3] + values[4]
	}
	return cpuTicks{user: values[0] + values[1], system: values[2], idle: idle, total: sum(values)}, true
}

func sum(values []uint64) uint64 {
	var out uint64
	for _, value := range values {
		out += value
	}
	return out
}
func collectMemory() MemoryStat {
	file, err := os.Open("/proc/meminfo")
	if err != nil {
		return fallbackMemory()
	}
	defer file.Close()
	values := map[string]uint64{}
	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		parts := strings.Fields(scanner.Text())
		if len(parts) < 2 {
			continue
		}
		value, err := strconv.ParseUint(parts[1], 10, 64)
		if err == nil {
			values[strings.TrimSuffix(parts[0], ":")] = value * 1024
		}
	}
	total := values["MemTotal"]
	available := values["MemAvailable"]
	if available == 0 {
		available = values["MemFree"] + values["Buffers"] + values["Cached"]
	}
	used := uint64(0)
	if total > available {
		used = total - available
	}
	process := processMemory()
	return MemoryStat{TotalBytes: total, UsedBytes: used, FreeBytes: available, UsedPercent: percent(float64(used), float64(total)), ProcessBytes: process, ProcessPercent: percent(float64(process), float64(total)), Available: total > 0}
}

func collectDisks() []DiskStat {
	mounts := []string{"/", "/data", "/app"}
	result := make([]DiskStat, 0, len(mounts))
	seen := map[string]bool{}
	for _, mount := range mounts {
		if seen[mount] {
			continue
		}
		var stat syscall.Statfs_t
		if err := syscall.Statfs(mount, &stat); err != nil {
			continue
		}
		block := uint64(stat.Bsize)
		total := stat.Blocks * block
		free := stat.Bavail * block
		used := uint64(0)
		if total > free {
			used = total - free
		}
		result = append(result, DiskStat{Mount: mount, Filesystem: "filesystem", TotalBytes: total, UsedBytes: used, FreeBytes: free, UsedPercent: percent(float64(used), float64(total))})
		seen[mount] = true
	}
	return result
}

func fallbackMemory() MemoryStat {
	process := processMemory()
	return MemoryStat{ProcessBytes: process, Available: false}
}

func processMemory() uint64 {
	var stats runtime.MemStats
	runtime.ReadMemStats(&stats)
	return stats.Alloc
}

func readNetworkCounters() (map[string]networkCounter, bool) {
	file, err := os.Open("/proc/net/dev")
	if err != nil {
		return nil, false
	}
	defer file.Close()
	counters := map[string]networkCounter{}
	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		separator := strings.Index(line, ":")
		if separator <= 0 {
			continue
		}
		name := strings.TrimSpace(line[:separator])
		if name == "lo" || name == "" {
			continue
		}
		fields := strings.Fields(line[separator+1:])
		if len(fields) < 9 {
			continue
		}
		receive, receiveErr := strconv.ParseUint(fields[0], 10, 64)
		transmit, transmitErr := strconv.ParseUint(fields[8], 10, 64)
		if receiveErr != nil || transmitErr != nil {
			continue
		}
		counters[name] = networkCounter{receiveBytes: receive, transmitBytes: transmit}
	}
	return counters, len(counters) > 0
}
