package handler

import (
	"strconv"

	"github.com/gin-gonic/gin"
)

const (
	defaultPage = 1
	defaultSize = 10
	maxSize     = 200
)

// parsePage 从请求解析分页参数，返回页码与每页条数（受上限约束）。
func parsePage(c *gin.Context) (page, size int) {
	page = parseInt(c, "page", defaultPage)
	size = parseInt(c, "size", defaultSize)
	if page < 1 {
		page = 1
	}
	if size < 1 || size > maxSize {
		size = defaultSize
	}
	return
}

func parseInt(c *gin.Context, key string, def int) int {
	v := c.Query(key)
	if v == "" {
		return def
	}
	n, err := strconv.Atoi(v)
	if err != nil {
		return def
	}
	return n
}

func parseUint(c *gin.Context, key string) uint64 {
	v := c.Query(key)
	if v == "" {
		return 0
	}
	n, _ := strconv.ParseUint(v, 10, 64)
	return n
}
