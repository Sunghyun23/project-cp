package com.projectcp.api;

import java.util.*;
import jakarta.servlet.http.*;
import org.springframework.http.*;
import org.springframework.security.oauth2.jwt.JwtException;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/auth")
class AuthController {
    private final AccountService accounts;
    private final GoogleIdentity google;
    private final Map<String,long[]> attempts=new HashMap<>();
    AuthController(AccountService accounts,GoogleIdentity google) {this.accounts=accounts;this.google=google;}
    private synchronized void guard(HttpServletRequest req) {
        accounts.mutation(req);
        long now=System.currentTimeMillis();attempts.entrySet().removeIf(e->now-e.getValue()[0]>60000);
        String ip=Optional.ofNullable(req.getHeader("X-Forwarded-For")).orElse(req.getRemoteAddr());
        if(ip.length()>200)throw AccountService.fail(HttpStatus.TOO_MANY_REQUESTS,"잠시 후 다시 시도해 주세요.");
        if(!attempts.containsKey(ip)&&attempts.size()>=4096)throw AccountService.fail(HttpStatus.TOO_MANY_REQUESTS,"잠시 후 다시 시도해 주세요.");
        long[] counter=attempts.computeIfAbsent(ip,k->new long[]{now,0});
        if(++counter[1]>30)throw AccountService.fail(HttpStatus.TOO_MANY_REQUESTS,"요청이 많아요. 1분 뒤 다시 시도해 주세요.");
    }
    private String field(Map<String,Object> body,String key,int max) {
        if(!(body.get(key) instanceof String value)||value.length()>max)throw AccountService.fail(HttpStatus.BAD_REQUEST,"입력 내용을 확인해 주세요.");
        return (String)body.get(key);
    }
    @GetMapping("/config/")
    Map<String,Object> config(HttpServletResponse res) {
        String nonce=AccountService.secret();accounts.setCookie(res,"cp_google_nonce",nonce,300);
        return Map.of("google_client_id",google.clientId,"nonce",nonce);
    }
    @GetMapping("/me/")
    Map<String,Object> me(HttpServletRequest req,HttpServletResponse res) {
        res.setHeader("Cache-Control","no-store");return accounts.profile(accounts.required(req));
    }
    @PostMapping("/register/")
    Map<String,Object> register(@RequestBody Map<String,Object> body,HttpServletRequest req,HttpServletResponse res) {
        guard(req);return accounts.register(field(body,"username",24),field(body,"password",72),res);
    }
    @PostMapping("/login/")
    Map<String,Object> login(@RequestBody Map<String,Object> body,HttpServletRequest req,HttpServletResponse res) {
        guard(req);return accounts.login(field(body,"username",24),field(body,"password",72),res);
    }
    @PostMapping("/recover/")
    Map<String,Object> recover(@RequestBody Map<String,Object> body,HttpServletRequest req,HttpServletResponse res) {
        guard(req);return accounts.recover(field(body,"username",24),field(body,"recovery_code",100),field(body,"password",72),res);
    }
    @PostMapping({"/google/","/google/link/"})
    Map<String,Object> google(@RequestBody Map<String,Object> body,HttpServletRequest req,HttpServletResponse res) {
        guard(req);
        var linking=req.getRequestURI().endsWith("/link/")?accounts.required(req):null;
        String sub;
        try {sub=google.verify(field(body,"credential",10000),AccountService.cookie(req,"cp_google_nonce"));}
        catch(JwtException e){throw AccountService.fail(HttpStatus.UNAUTHORIZED,"Google 인증을 확인하지 못했어요. 새로 로그인해 주세요.");}
        catch(IllegalStateException e){throw AccountService.fail(HttpStatus.SERVICE_UNAVAILABLE,"Google 로그인 설정을 준비 중이에요.");}
        accounts.setCookie(res,"cp_google_nonce","",0);return accounts.google(sub,linking,res);
    }
    @PostMapping("/logout/")
    Map<String,Object> logout(HttpServletRequest req,HttpServletResponse res) {
        guard(req);accounts.logout(req,res);return Map.of("signed_in",false);
    }
}
