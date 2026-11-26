package com.projectcp.api;

import com.nimbusds.jose.*;
import com.nimbusds.jose.crypto.RSASSASigner;
import com.nimbusds.jose.jwk.*;
import com.nimbusds.jose.jwk.gen.RSAKeyGenerator;
import com.nimbusds.jwt.*;
import com.sun.net.httpserver.HttpServer;
import java.net.*;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.*;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class GoogleIdentityTest {
    @Test void realRsaSignatureAudienceIssuerAndExpiryAreValidated() throws Exception {
        var key=new RSAKeyGenerator(2048).keyID("test-key").generate();
        var other=new RSAKeyGenerator(2048).keyID("test-key").generate();
        var server=HttpServer.create(new InetSocketAddress("127.0.0.1",0),0);
        byte[] jwks=new JWKSet(key.toPublicJWK()).toString().getBytes(StandardCharsets.UTF_8);
        server.createContext("/keys",x->{x.sendResponseHeaders(200,jwks.length);try(var output=x.getResponseBody()){output.write(jwks);}});server.start();
        try {
            var decoder=GoogleIdentity.decoder("correct-client","http://127.0.0.1:"+server.getAddress().getPort()+"/keys");
            assertEquals("google-sub",decoder.decode(token(key,"correct-client","https://accounts.google.com",300)).getSubject());
            assertThrows(Exception.class,()->decoder.decode(token(key,"wrong-client","https://accounts.google.com",300)));
            assertThrows(Exception.class,()->decoder.decode(token(key,"correct-client","https://attacker.invalid",300)));
            assertThrows(Exception.class,()->decoder.decode(token(key,"correct-client","https://accounts.google.com",-300)));
            assertThrows(Exception.class,()->decoder.decode(token(other,"correct-client","https://accounts.google.com",300)));
        } finally {server.stop(0);}
    }
    private String token(RSAKey key,String audience,String issuer,int expiry) throws Exception {
        var claims=new JWTClaimsSet.Builder().subject("google-sub").issuer(issuer).audience(audience)
                .issueTime(Date.from(Instant.now().minusSeconds(10))).expirationTime(Date.from(Instant.now().plusSeconds(expiry))).claim("nonce","nonce").build();
        var jwt=new SignedJWT(new JWSHeader.Builder(JWSAlgorithm.RS256).keyID("test-key").build(),claims);
        jwt.sign(new RSASSASigner(key));return jwt.serialize();
    }
}
