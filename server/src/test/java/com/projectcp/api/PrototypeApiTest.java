package com.projectcp.api;

import java.net.URI;
import java.net.http.*;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.*;
import java.util.concurrent.*;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.jdbc.core.simple.JdbcClient;
import tools.jackson.core.type.TypeReference;
import tools.jackson.databind.json.JsonMapper;

@SpringBootTest(webEnvironment=SpringBootTest.WebEnvironment.RANDOM_PORT)
class PrototypeApiTest {
    @LocalServerPort int port;
    @Autowired JsonMapper json;
    @Autowired JdbcClient jdbc;
    final HttpClient http = HttpClient.newHttpClient();
    static final TypeReference<Map<String, Object>> MAP = new TypeReference<>() {};
    record Reply(int status, Map<String, Object> data) {}

    Reply request(String method, String path, String token, String body) throws Exception {
        var builder = HttpRequest.newBuilder(URI.create("http://localhost:" + port + "/api/v1/" + path));
        if (token != null) builder.header("Authorization", "Bearer " + token);
        if (body != null) builder.header("Content-Type", "application/json");
        builder.method(method, body == null ? HttpRequest.BodyPublishers.noBody() : HttpRequest.BodyPublishers.ofString(body));
        var response = http.send(builder.build(), HttpResponse.BodyHandlers.ofString());
        return new Reply(response.statusCode(), json.readValue(response.body(), MAP));
    }

    class Player {
        String token;
        Map<String, Object> saved;
        Player() throws Exception {
            var created = request("POST", "prototype/sessions/", null, "{}");
            assertEquals(201, created.status());
            token = (String) created.data().get("token");
            saved = new LinkedHashMap<>(created.data()); saved.remove("token");
        }
        @SuppressWarnings("unchecked") Map<String, Object> state() { return (Map<String, Object>) saved.get("state"); }
        void act(String command) throws Exception { act(command, ""); }
        void act(String command, String choice) throws Exception {
            var reply = request("POST", "prototype/actions/", token,
                    json.writeValueAsString(Map.of("command", command, "choice", choice, "version", saved.get("version"))));
            assertEquals(200, reply.status(), reply.data().toString()); saved = reply.data();
        }
        void week(String meal, boolean improved) throws Exception {
            for (int i=0; i<5; i++) act("work");
            act("buy", meal);
            for (String gear : List.of("tent", "table", "chair")) act("pack", gear);
            act("gear", improved ? "improved" : "basic"); act("next");
            for (int i=0; i<3; i++) act("install");
            act("rest"); assertEquals("free", state().get("phase")); act("next");
            if (meal.equals("skewer")) for (String item : List.of("meat", "mushroom", "meat")) act("ingredient", item);
            for (int i=0; i<(improved ? 2 : 3); i++) act("cook");
            assertEquals("night", state().get("phase"));
            act("rest"); assertEquals("night", state().get("phase")); act("next"); act("breakfast");
            for (int i=0; i<3; i++) act("pack_up");
            assertEquals("settlement", state().get("phase")); act("next");
        }
    }

    @Test void bothMealsCompleteAndReload() throws Exception {
        var p = new Player(); p.week("ramen", false); p.week("skewer", true);
        var loaded = request("GET", "prototype/state/", p.token, null);
        assertEquals(200, loaded.status()); assertEquals(p.saved, loaded.data());
        assertEquals(3, p.state().get("week"));
        assertEquals(2, ((Map<?, ?>) p.state().get("recipes")).size());
    }

    @Test void repeatedThreeStarRecipeEarnsBonus() throws Exception {
        var p = new Player(); for (int i=0; i<4; i++) p.week("ramen", true);
        assertEquals(4, p.state().get("stars"));
    }

    @Test void invalidActionAndStaleVersionDoNotChangeProgress() throws Exception {
        var p = new Player();
        assertEquals(400, request("POST", "prototype/actions/", p.token, "{\"command\":\"cook\",\"version\":0}").status());
        assertEquals(p.saved, request("GET", "prototype/state/", p.token, null).data());
        p.act("work");
        assertEquals(409, request("POST", "prototype/actions/", p.token, "{\"command\":\"work\",\"version\":0}").status());
        assertEquals(p.saved, request("GET", "prototype/state/", p.token, null).data());
    }

    @Test void invalidTokenCannotReadOrChangeAnotherSession() throws Exception {
        var p = new Player();
        assertEquals(401, request("GET", "prototype/state/", "invalid", null).status());
        assertEquals(401, request("POST", "prototype/actions/", "invalid", "{\"command\":\"work\",\"version\":0}").status());
        assertEquals(401, request("GET", "prototype/state/", null, null).status());
        assertEquals(p.saved, request("GET", "prototype/state/", p.token, null).data());
    }

    @Test void concurrentRequestsApplyOnlyOnce() throws Exception {
        var p = new Player();
        try (var workers = Executors.newFixedThreadPool(2)) {
            var ready = new CountDownLatch(2); var start = new CountDownLatch(1);
            Callable<Integer> action = () -> {
                ready.countDown(); start.await();
                return request("POST", "prototype/actions/", p.token, "{\"command\":\"work\",\"version\":0}").status();
            };
            var a=workers.submit(action); var b=workers.submit(action);
            assertTrue(ready.await(5, TimeUnit.SECONDS)); start.countDown();
            assertEquals(Set.of(200, 409), Set.of(a.get(10, TimeUnit.SECONDS), b.get(10, TimeUnit.SECONDS)));
        }
        var loaded = request("GET", "prototype/state/", p.token, null).data();
        assertEquals(1, loaded.get("version"));
    }

    @Test void legacyDjangoRowAndTokenRemainUsable() throws Exception {
        String token = UUID.randomUUID().toString();
        String hash = HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(token.getBytes(StandardCharsets.UTF_8)));
        var legacy = PrototypeRules.initialState(); legacy.put("money", 317); legacy.put("week", 8);
        jdbc.sql("INSERT INTO public.prototype_prototypesession (token_hash,state,version,updated_at) VALUES (:hash,CAST(:state AS jsonb),7,CURRENT_TIMESTAMP)")
                .param("hash",hash).param("state",json.writeValueAsString(legacy)).update();
        assertEquals(Map.of("state",legacy,"version",7),request("GET","prototype/state/",token,null).data());
        var changed=request("POST","prototype/actions/",token,"{\"command\":\"work\",\"version\":7}");
        assertEquals(200,changed.status()); assertEquals(8,changed.data().get("version"));
    }

    @Test void malformedPayloadDoesNotCauseServerError() throws Exception {
        var p = new Player();
        for (String body : List.of("[]", "null", "{", "{\"version\":0,\"command\":[]}", "{\"version\":0,\"command\":\"work\",\"choice\":{}}"))
            assertEquals(400, request("POST", "prototype/actions/", p.token, body).status(), body);
        assertEquals(p.saved, request("GET", "prototype/state/", p.token, null).data());
    }

    @Test void prerequisitesAndHealth() throws Exception {
        var s=PrototypeRules.initialState(); s.put("phase","packing");
        assertThrows(IllegalArgumentException.class,()->PrototypeRules.transition(s,"next",""));
        s.put("phase","dinner");s.put("meal","skewer");
        assertThrows(IllegalArgumentException.class,()->PrototypeRules.transition(s,"cook",""));
        var health=request("GET","health/",null,null);
        assertEquals(200,health.status()); assertEquals("ok",health.data().get("database"));
    }
}
