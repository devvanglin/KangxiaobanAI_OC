//go:build !linux && !windows

package system

func readNetworkCounters() (map[string]networkCounter, bool) {
	return map[string]networkCounter{}, false
}
