package com.projectcp.api;

import java.nio.charset.StandardCharsets;
import java.security.*;
import java.time.*;
import java.util.*;
import jakarta.servlet.http.*;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.*;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import tools.jackson.databind.json.JsonMapper;

@Service
class AccountService {
    record Account(UUID id, String username, String googleSub, long progressId) {}
    private final JdbcClient jdbc;
    private final JsonMapper json;
    private final BCryptPasswordEncoder passwords = new BCryptPasswordEncoder(12);
    private final String dummyPassword = passwords.encode("invalid-account-timing-padding");
    final boolean secure;
    final String origin;
    AccountService(JdbcClient jdbc, JsonMapper json, @Value("${cp.secure-cookies:false}") boolean secure,
                   @Value("${cp.web-origin:http://localhost:8080}") String origin) {
        this.jdbc=jdbc; this.json=json; this.secure=secure; this.origin=origin;
    }
    static String secret() { byte[] b=new byte[32];new SecureRandom().nextBytes(b);return Base64.getUrlEncoder().withoutPadding().encodeToString(b); }
    static String hash(String value) {
        try { return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(value.getBytes(StandardCharsets.UTF_8))); }
        catch(NoSuchAlgorithmException e) { throw new IllegalStateException(e); }
    }
    static ResponseStatusException fail(HttpStatus status,String message) { return new ResponseStatusException(status,message); }
    static String cookie(HttpServletRequest req,String name) {
        if(req.getCookies()!=null) for(var c:req.getCookies()) if(c.getName().equals(name)) return c.getValue();
        return null;
    }
    void setCookie(HttpServletResponse res,String name,String value,long seconds) {
        res.addHeader(HttpHeaders.SET_COOKIE,ResponseCookie.from(name,value).httpOnly(true).secure(secure)
                .sameSite("Lax").path("/").maxAge(seconds).build().toString());
        res.setHeader("Cache-Control","no-store");
    }
    void mutation(HttpServletRequest req) {
        if(!origin.equals(req.getHeader("Origin")) || !"1".equals(req.getHeader("X-CP-Request")))
            throw fail(HttpStatus.FORBIDDEN,"허용되지 않은 요청이에요.");
    }
    Optional<Account> current(HttpServletRequest req) {
        String token=cookie(req,"cp_session");if(token==null || token.length()>100)return Optional.empty();
        return jdbc.sql("SELECT a.id,a.username,a.google_sub,a.progress_id FROM public.cp_account a JOIN public.cp_login_session s ON s.account_id=a.id WHERE s.token_hash=:hash AND s.expires_at>CURRENT_TIMESTAMP")
                .param("hash",hash(token)).query((r,i)->new Account(r.getObject("id",UUID.class),r.getString("username"),r.getString("google_sub"),r.getLong("progress_id"))).optional();
    }
    Account required(HttpServletRequest req) { return current(req).orElseThrow(()->fail(HttpStatus.UNAUTHORIZED,"로그인이 필요해요.")); }
    String progressHash(HttpServletRequest req) {
        var account=current(req);if(account.isEmpty())return null;
        return jdbc.sql("SELECT token_hash FROM public.prototype_prototypesession WHERE id=:id").param("id",account.get().progressId()).query(String.class).single();
    }
    Map<String,Object> profile(Account a) { return Map.of("signed_in",true,"username",a.username()==null?"캠퍼":a.username(),"google_linked",a.googleSub()!=null); }
    private Account create(String username,String passwordHash,String recoveryHash,String googleSub) {
        long progress=jdbc.sql("INSERT INTO public.prototype_prototypesession(token_hash,state,version,updated_at) VALUES (:hash,CAST(:state AS jsonb),0,CURRENT_TIMESTAMP) RETURNING id")
                .param("hash",hash(secret())).param("state",json.writeValueAsString(PrototypeRules.initialState())).query(Long.class).single();
        UUID id=UUID.randomUUID();
        jdbc.sql("INSERT INTO public.cp_account(id,username,password_hash,recovery_hash,google_sub,progress_id) VALUES(:id,:username,:password,:recovery,:google,:progress)")
                .param("id",id).param("username",username).param("password",passwordHash).param("recovery",recoveryHash).param("google",googleSub).param("progress",progress).update();
        return new Account(id,username,googleSub,progress);
    }
    private void session(Account a,HttpServletResponse res) {
        jdbc.sql("DELETE FROM public.cp_login_session WHERE expires_at<CURRENT_TIMESTAMP").update();
        String token=secret();
        jdbc.sql("INSERT INTO public.cp_login_session(token_hash,account_id,expires_at) VALUES(:hash,:id,:expiry)")
                .param("hash",hash(token)).param("id",a.id()).param("expiry",OffsetDateTime.now(ZoneOffset.UTC).plusDays(7)).update();
        setCookie(res,"cp_session",token,7*86400);
    }
    private String username(String name) {
        String normalized=name.strip().toLowerCase(Locale.ROOT);
        if(!normalized.matches("[a-z0-9_]{3,24}")) throw fail(HttpStatus.BAD_REQUEST,"ID는 영문 소문자·숫자·밑줄 3~24자로 입력해 주세요.");
        return normalized;
    }
    private void password(String password) {
        if(password.length()<12 || password.getBytes(StandardCharsets.UTF_8).length>72)throw fail(HttpStatus.BAD_REQUEST,"비밀번호는 12자 이상, UTF-8 72바이트 이하로 입력해 주세요.");
    }
    @Transactional
    public Map<String,Object> register(String name,String password,HttpServletResponse res) {
        String user=username(name);password(password);String recovery=secret();
        var a=create(user,passwords.encode(password),hash(recovery),null);session(a,res);
        var result=new LinkedHashMap<>(profile(a));result.put("recovery_code",recovery);return result;
    }
    @Transactional
    public Map<String,Object> login(String name,String password,HttpServletResponse res) {
        String user=username(name);
        if(password.getBytes(StandardCharsets.UTF_8).length>72)throw fail(HttpStatus.UNAUTHORIZED,"ID 또는 비밀번호를 확인해 주세요.");
        var row=jdbc.sql("SELECT id,password_hash FROM public.cp_account WHERE username=:name").param("name",user).query((r,i)->Map.entry(r.getObject("id",UUID.class),r.getString("password_hash"))).optional();
        boolean valid=passwords.matches(password,row.map(Map.Entry::getValue).orElse(dummyPassword));
        if(row.isEmpty() || !valid)throw fail(HttpStatus.UNAUTHORIZED,"ID 또는 비밀번호를 확인해 주세요.");
        var a=byId(row.get().getKey());session(a,res);return profile(a);
    }
    private Account byId(UUID id) {
        return jdbc.sql("SELECT id,username,google_sub,progress_id FROM public.cp_account WHERE id=:id").param("id",id)
                .query((r,i)->new Account(id,r.getString("username"),r.getString("google_sub"),r.getLong("progress_id"))).single();
    }
    @Transactional
    public Map<String,Object> google(String sub,Account linking,HttpServletResponse res) {
        jdbc.sql("SELECT pg_advisory_xact_lock(hashtextextended(:sub,0))").param("sub",sub).query((r,i)->0).single();
        var existing=jdbc.sql("SELECT id FROM public.cp_account WHERE google_sub=:sub").param("sub",sub).query(UUID.class).optional();
        Account a;
        if(linking!=null) {
            var locked=jdbc.sql("SELECT google_sub FROM public.cp_account WHERE id=:id FOR UPDATE").param("id",linking.id()).query((r,i)->Optional.ofNullable(r.getString(1))).single();
            if(existing.isPresent() && !existing.get().equals(linking.id()) || locked.isPresent() && !locked.get().equals(sub))
                throw fail(HttpStatus.CONFLICT,"이미 다른 계정에 연결되어 있어요. 진행을 자동으로 합치지 않아요.");
            jdbc.sql("UPDATE public.cp_account SET google_sub=:sub WHERE id=:id").param("sub",sub).param("id",linking.id()).update();a=byId(linking.id());
        } else { a=existing.isPresent()?byId(existing.get()):create(null,null,null,sub); }
        session(a,res);return profile(a);
    }
    @Transactional
    public Map<String,Object> recover(String name,String code,String password,HttpServletResponse res) {
        String user=username(name);password(password);String replacement=secret();
        var ids=jdbc.sql("UPDATE public.cp_account SET password_hash=:password,recovery_hash=:next WHERE username=:user AND recovery_hash=:hash RETURNING id")
                .param("password",passwords.encode(password)).param("next",hash(replacement)).param("user",user).param("hash",hash(code)).query(UUID.class).list();
        if(ids.isEmpty())throw fail(HttpStatus.UNAUTHORIZED,"ID 또는 복구 코드를 확인해 주세요.");
        UUID id=ids.getFirst();jdbc.sql("DELETE FROM public.cp_login_session WHERE account_id=:id").param("id",id).update();var a=byId(id);session(a,res);
        var result=new LinkedHashMap<>(profile(a));result.put("recovery_code",replacement);return result;
    }
    void logout(HttpServletRequest req,HttpServletResponse res) {
        String token=cookie(req,"cp_session");if(token!=null)jdbc.sql("DELETE FROM public.cp_login_session WHERE token_hash=:hash").param("hash",hash(token)).update();
        setCookie(res,"cp_session","",0);
    }
}
