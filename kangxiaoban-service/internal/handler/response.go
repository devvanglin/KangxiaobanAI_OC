package handler

import "github.com/gin-gonic/gin"

// respond 统一返回 {code,msg,data}。
func respond(c *gin.Context, httpCode int, code int, msg string, data interface{}) {
	c.JSON(httpCode, gin.H{"code": code, "msg": msg, "data": data})
}

// OK 成功响应。
func OK(c *gin.Context, data interface{}) {
	respond(c, 200, 0, "ok", data)
}

// Fail 业务错误响应。
func Fail(c *gin.Context, httpCode int, code int, msg string) {
	respond(c, httpCode, code, msg, nil)
}