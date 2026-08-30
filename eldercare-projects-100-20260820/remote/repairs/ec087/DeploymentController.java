package com.sm;

import java.util.LinkedHashMap;
import java.util.Map;
import javax.servlet.http.HttpSession;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseBody;

/**
 * Deployment completion for the incomplete upstream snapshot.  The repository
 * contains the Thymeleaf/Layui screens but omitted every MVC controller.
 */
@Controller
public class DeploymentController {
    @Value("${DEPLOY_ADMIN_USER:deployadmin}")
    private String deployAdminUser;

    @Value("${DEPLOY_ADMIN_PASSWORD:}")
    private String deployAdminPassword;

    @GetMapping({"/", "/login"})
    public String loginPage() {
        return "login";
    }

    @PostMapping("/root/loginIn")
    @ResponseBody
    public Map<String, Object> login(
            @RequestParam String username,
            @RequestParam String password,
            HttpSession session) {
        Map<String, Object> result = new LinkedHashMap<>();
        if (deployAdminUser.equals(username)
                && !deployAdminPassword.isEmpty()
                && deployAdminPassword.equals(password)) {
            session.setAttribute("username", username);
            result.put("code", 1);
            result.put("msg", "登录成功");
        } else {
            result.put("code", -1);
            result.put("msg", "账号或密码错误");
        }
        return result;
    }

    @GetMapping("/indexA")
    public String adminIndex(HttpSession session) {
        return session.getAttribute("username") == null ? "redirect:/" : "index-admin";
    }
}
