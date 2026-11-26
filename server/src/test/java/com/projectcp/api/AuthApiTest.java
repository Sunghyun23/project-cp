package com.projectcp.api;

import java.net.*;
import java.net.http.*;
import java.util.*;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.jdbc.core.simple.JdbcClient;
import tools.jackson.core.type.TypeReference;
import tools.jackson.databind.json.JsonMapper;

@SpringBootTest(webEnvironment=SpringBootTest.WebEnvironment.RANDOM_PORT)
class AuthApiTest {
    @LocalServerPort int port;
    @Autowired JsonMapper json;
    @Autowired JdbcClient jdbc;
    @MockitoBean GoogleIdentity google;
    record Reply(int status,Map<String,Object> data) {}
    class Browser {
        final String ip=UUID.randomUUID().toString();
        final HttpClient http=HttpClient.newBuilder().cookieHandler(new CookieManager(null,CookiePolicy.ACCEPT_ALL)).build();
        Reply call(String method,String path,Map<String,Object> body,String origin) throws Exception {
            var b=HttpRequest.newBuilder(URI.create("http://localhost:"+port+"/api/v1/"+path)).header("Origin",origin).header("X-CP-Request","1").header("X-Forwarded-For",ip);
            if(body!=null)b.header("Content-Type","application/json");
            b.method(method,body==null?HttpRequest.BodyPublishers.noBody():HttpRequest.BodyPublishers.ofString(json.writeValueAsString(body)));
            var r=http.send(b.build(),HttpResponse.BodyHandlers.ofString());return new Reply(r.statusCode(),json.readValue(r.body(),new TypeReference<Map<String,Object>>(){}));
        }
        Reply get(String path)throws Exception{return call("GET",path,null,"http://localhost:8080");}
        Reply post(String path,Map<String,Object> body)throws Exception{return call("POST",path,body,"http://localhost:8080");}
        Reply register(String name)throws Exception{return post("auth/register/",Map.of("username",name,"password","long-test-password"));}
    }
    String user(){return "u"+UUID.randomUUID().toString().replace("-", "").substring(0,14);}
    @Test void guestProgressPersistsAcrossBrowsersAndLogout() throws Exception {
        var a=new Browser();String name=user();assertEquals(200,a.register(name).status());
        assertEquals(200,a.post("prototype/actions/",Map.of("command","work","version",0)).status());
        var b=new Browser();assertEquals(401,b.get("prototype/state/").status());
        assertEquals(200,b.post("auth/login/",Map.of("username",name,"password","long-test-password")).status());
        assertEquals(1,((Number)b.get("prototype/state/").data().get("version")).intValue());
        assertEquals(200,b.post("auth/logout/",Map.of()).status());assertEquals(401,b.get("prototype/state/").status());
    }
    @Test void googleLinkPreservesGuestAndRejectsOtherAccounts() throws Exception {
        when(google.verify(eq("valid-google"),any())).thenReturn("google-sub-"+user());
        var a=new Browser();String name=user();a.register(name);a.post("prototype/actions/",Map.of("command","work","version",0));
        assertEquals(200,a.post("auth/google/link/",Map.of("credential","valid-google")).status());
        assertEquals(1,((Number)a.get("prototype/state/").data().get("version")).intValue());
        var b=new Browser();b.register(user());assertEquals(409,b.post("auth/google/link/",Map.of("credential","valid-google")).status());
        assertEquals(0,((Number)b.get("prototype/state/").data().get("version")).intValue());
        var c=new Browser();assertEquals(200,c.post("auth/google/",Map.of("credential","valid-google")).status());
        assertEquals(1,((Number)c.get("prototype/state/").data().get("version")).intValue());
        var d=new Browser();assertEquals(200,d.post("auth/login/",Map.of("username",name,"password","long-test-password")).status());
        assertEquals(true,d.get("auth/me/").data().get("google_linked"));
        when(google.verify(eq("new-google"),any())).thenReturn("new-sub-"+user());
        var firstGoogle=new Browser();assertEquals(200,firstGoogle.post("auth/google/",Map.of("credential","new-google")).status());
        assertEquals(true,firstGoogle.get("auth/me/").data().get("google_linked"));
        assertEquals(0,((Number)firstGoogle.get("prototype/state/").data().get("version")).intValue());
    }
    @Test void recoveryIsOneUseAndRevokesExistingSessions() throws Exception {
        var a=new Browser();String name=user();String recovery=(String)a.register(name).data().get("recovery_code");
        var b=new Browser();assertEquals(200,b.post("auth/recover/",Map.of("username",name,"password","new-long-test-password","recovery_code",recovery)).status());
        assertEquals(401,a.get("auth/me/").status());
        assertEquals(401,a.post("auth/recover/",Map.of("username",name,"password","other-long-test-password","recovery_code",recovery)).status());
        assertEquals(401,a.post("auth/login/",Map.of("username",name,"password","long-test-password")).status());
        assertEquals(200,a.post("auth/login/",Map.of("username",name,"password","new-long-test-password")).status());
    }
    @Test void rejectsCrossOriginBadPasswordExpiredAndForgedIdentity() throws Exception {
        var a=new Browser();String name=user();a.register(name);
        assertEquals(403,a.call("POST","auth/logout/",Map.of(),"https://attacker.invalid").status());
        assertEquals(400,a.register("!invalid").status());
        assertEquals(409,a.register(name).status());
        var b=new Browser();assertEquals(401,b.post("auth/login/",Map.of("username",name,"password","wrong")).status());
        when(google.verify(eq("invalid"),any())).thenThrow(new org.springframework.security.oauth2.jwt.JwtException("forged"));
        assertEquals(401,b.post("auth/google/",Map.of("credential","invalid")).status());
        jdbc.sql("UPDATE public.cp_login_session SET expires_at=CURRENT_TIMESTAMP-INTERVAL '1 second' WHERE account_id=(SELECT id FROM public.cp_account WHERE username=:u)").param("u",name).update();
        assertEquals(401,a.get("auth/me/").status());
    }
}
