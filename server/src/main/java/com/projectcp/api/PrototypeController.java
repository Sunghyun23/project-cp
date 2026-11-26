package com.projectcp.api;

import java.nio.charset.StandardCharsets;
import java.security.*;
import java.util.*;
import org.springframework.dao.DataAccessException;
import org.springframework.http.*;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import tools.jackson.core.type.TypeReference;
import tools.jackson.databind.json.JsonMapper;

@RestController
public class PrototypeController {
    private final JdbcClient jdbc;
    private final JsonMapper json;
    private final AccountService accounts;
    private final jakarta.servlet.http.HttpServletRequest request;
    private final SecureRandom random = new SecureRandom();
    private static final TypeReference<Map<String, Object>> STATE_TYPE = new TypeReference<>() {};

    PrototypeController(JdbcClient jdbc, JsonMapper json, AccountService accounts, jakarta.servlet.http.HttpServletRequest request) {
        this.jdbc = jdbc; this.json = json; this.accounts=accounts; this.request=request;
    }
    private String requestHash(String auth) {
        if (auth==null) return accounts.progressHash(request);
        if (!auth.startsWith("Bearer ") || auth.length()>200) return null;
        return digest(auth.substring(7));
    }
    record Session(Map<String, Object> state, long version) {}
    private Map<String, Object> payload(Session session) { return Map.of("state", session.state(), "version", session.version()); }
    private static ResponseEntity<?> error(HttpStatus status, String message) { return ResponseEntity.status(status).body(Map.of("error", message)); }

    private String digest(String token) {
        try {
            return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(token.getBytes(StandardCharsets.UTF_8)));
        } catch (NoSuchAlgorithmException e) { throw new IllegalStateException(e); }
    }

    private Optional<Session> find(String auth, boolean lock) {
        String hash=requestHash(auth);
        if(hash==null)return Optional.empty();
        return jdbc.sql("SELECT state::text, version FROM public.prototype_prototypesession WHERE token_hash = :hash" + (lock ? " FOR UPDATE" : ""))
                .param("hash", requestHash(auth))
                .query((row, index) -> new Session(json.readValue(row.getString("state"), STATE_TYPE), row.getLong("version"))).optional();
    }

    @GetMapping("/api/v1/health/")
    ResponseEntity<?> health() {
        try { jdbc.sql("SELECT 1").query(Integer.class).single(); }
        catch (DataAccessException e) { return ResponseEntity.status(503).body(Map.of("status", "unavailable")); }
        return ResponseEntity.ok(Map.of("status", "ok", "database", "ok"));
    }

    @PostMapping("/api/v1/prototype/sessions/")
    ResponseEntity<?> createSession() {
        byte[] secret = new byte[32]; random.nextBytes(secret);
        String token = Base64.getUrlEncoder().withoutPadding().encodeToString(secret);
        var state = PrototypeRules.initialState();
        jdbc.sql("INSERT INTO public.prototype_prototypesession (token_hash, state, version, updated_at) VALUES (:hash, CAST(:state AS jsonb), 0, CURRENT_TIMESTAMP)")
                .param("hash", digest(token)).param("state", json.writeValueAsString(state)).update();
        return ResponseEntity.status(201).body(Map.of("token", token, "state", state, "version", 0));
    }

    @GetMapping("/api/v1/prototype/state/")
    ResponseEntity<?> state(@RequestHeader(value="Authorization", required=false) String auth) {
        return find(auth, false).<ResponseEntity<?>>map(s -> ResponseEntity.ok(payload(s)))
                .orElseGet(() -> error(HttpStatus.UNAUTHORIZED, "테스트 세션을 찾을 수 없어요."));
    }

    @PostMapping("/api/v1/prototype/actions/")
    @Transactional
    ResponseEntity<?> action(@RequestHeader(value="Authorization", required=false) String auth, @RequestBody Map<String, Object> body) {
        if(auth==null)accounts.mutation(request);
        var existing = find(auth, true);
        if (existing.isEmpty()) return error(HttpStatus.UNAUTHORIZED, "테스트 세션을 찾을 수 없어요.");
        var session = existing.get();
        Object version = body.get("version");
        if (!(version instanceof Integer || version instanceof Long) || ((Number) version).longValue() != session.version())
            return error(HttpStatus.CONFLICT, "다른 요청이 먼저 저장됐어요. 다시 불러와 주세요.");
        if (!(body.get("command") instanceof String command) || command.length() > 32
                || !(body.getOrDefault("choice", "") instanceof String choice) || choice.length() > 32)
            return error(HttpStatus.BAD_REQUEST, "행동 형식이 올바르지 않아요.");
        Map<String, Object> next;
        try { next = PrototypeRules.transition(session.state(), command, choice); }
        catch (IllegalArgumentException e) { return error(HttpStatus.BAD_REQUEST, e.getMessage()); }
        jdbc.sql("UPDATE public.prototype_prototypesession SET state=CAST(:state AS jsonb), version=:version, updated_at=CURRENT_TIMESTAMP WHERE token_hash=:hash")
                .param("state", json.writeValueAsString(next)).param("version", session.version() + 1).param("hash", requestHash(auth)).update();
        return ResponseEntity.ok(payload(new Session(next, session.version() + 1)));
    }
}
