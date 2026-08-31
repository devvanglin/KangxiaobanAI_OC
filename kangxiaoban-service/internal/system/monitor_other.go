//go:build !linux && !windows

package system

import "runtime"

func collectCPU() CPUStat { return CPUStat{Cores: runtime.NumCPU(), Available: false} }

func collectMemory() MemoryStat { return fallbackMemory() }

func collectDisks() []DiskStat { return []DiskStat{} }

func fallbackMemory() MemoryStat {
	var stats runtime.MemStats
	runtime.ReadMemStats(&stats)
	return MemoryStat{ProcessBytes: stats.Alloc, Available: false}
}

func processMemory() uint64 {
	var stats runtime.MemStats
	runtime.ReadMemStats(&stats)
	return stats.Alloc
}
