//go:build windows

package system

// Windows host counters are intentionally unavailable until a stable native
// interface-table implementation is added. The API reports available=false
// instead of inventing network values.
func readNetworkCounters() (map[string]networkCounter, bool) {
	return map[string]networkCounter{}, false
}
