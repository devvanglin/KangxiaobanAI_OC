//go:build windows

package system

import (
	"runtime"
	"strings"
	"syscall"
	"time"
	"unsafe"
)

var (
	kernel32                 = syscall.NewLazyDLL("kernel32.dll")
	procGetSystemTimes       = kernel32.NewProc("GetSystemTimes")
	procGlobalMemoryStatusEx = kernel32.NewProc("GlobalMemoryStatusEx")
	procGetDiskFreeSpaceExW  = kernel32.NewProc("GetDiskFreeSpaceExW")
)

type winFiletime struct{ LowDateTime, HighDateTime uint32 }
type memoryStatusEx struct {
	Length, MemoryLoad                                                                                   uint32
	TotalPhys, AvailPhys, TotalPageFile, AvailPageFile, TotalVirtual, AvailVirtual, AvailExtendedVirtual uint64
}

func collectCPU() CPUStat {
	read := func() (uint64, uint64, uint64, bool) {
		var idle, kernel, user winFiletime
		r, _, _ := procGetSystemTimes.Call(uintptr(unsafe.Pointer(&idle)), uintptr(unsafe.Pointer(&kernel)), uintptr(unsafe.Pointer(&user)))
		return filetimeValue(kernel), filetimeValue(user), filetimeValue(idle), r != 0
	}
	k1, u1, i1, ok := read()
	if !ok {
		return CPUStat{Cores: runtime.NumCPU(), Available: false}
	}
	time.Sleep(120 * time.Millisecond)
	k2, u2, i2, ok := read()
	if !ok {
		return CPUStat{Cores: runtime.NumCPU(), Available: false}
	}
	kernel, user, idle := k2-k1, u2-u1, i2-i1
	total := kernel + user
	if total <= 0 {
		return CPUStat{Cores: runtime.NumCPU(), Available: false}
	}
	return CPUStat{Cores: runtime.NumCPU(), Usage: percent(float64(total-idle), float64(total)), UserPercent: percent(float64(user), float64(total)), SystemPercent: percent(float64(kernel-idle), float64(total)), IdlePercent: percent(float64(idle), float64(total)), Available: true}
}

func filetimeValue(value winFiletime) uint64 {
	return uint64(value.HighDateTime)<<32 | uint64(value.LowDateTime)
}

func collectMemory() MemoryStat {
	status := memoryStatusEx{Length: uint32(unsafe.Sizeof(memoryStatusEx{}))}
	r, _, _ := procGlobalMemoryStatusEx.Call(uintptr(unsafe.Pointer(&status)))
	if r == 0 || status.TotalPhys == 0 {
		return fallbackMemory()
	}
	used := status.TotalPhys - status.AvailPhys
	process := processMemory()
	return MemoryStat{TotalBytes: status.TotalPhys, UsedBytes: used, FreeBytes: status.AvailPhys, UsedPercent: percent(float64(used), float64(status.TotalPhys)), ProcessBytes: process, ProcessPercent: percent(float64(process), float64(status.TotalPhys)), Available: true}
}

func collectDisks() []DiskStat {
	result := make([]DiskStat, 0, 2)
	for _, mount := range []string{"C:\\", "D:\\"} {
		path, err := syscall.UTF16PtrFromString(mount)
		if err != nil {
			continue
		}
		var free, total, available uint64
		r, _, _ := procGetDiskFreeSpaceExW.Call(uintptr(unsafe.Pointer(path)), uintptr(unsafe.Pointer(&available)), uintptr(unsafe.Pointer(&total)), uintptr(unsafe.Pointer(&free)))
		if r == 0 || total == 0 {
			continue
		}
		used := total - free
		result = append(result, DiskStat{Mount: strings.TrimSuffix(mount, "\\"), Filesystem: "Windows", TotalBytes: total, UsedBytes: used, FreeBytes: free, UsedPercent: percent(float64(used), float64(total))})
	}
	return result
}

func fallbackMemory() MemoryStat { return MemoryStat{ProcessBytes: processMemory(), Available: false} }
func processMemory() uint64 {
	var stats runtime.MemStats
	runtime.ReadMemStats(&stats)
	return stats.Alloc
}
