package com.projectcp.api;

import java.util.*;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.oauth2.core.*;
import org.springframework.security.oauth2.jwt.*;
import org.springframework.stereotype.Component;

@Component
class GoogleIdentity {
    final String clientId;
    private final JwtDecoder decoder;
    GoogleIdentity(@Value("${cp.google-client-id:}") String clientId) {
        this.clientId = clientId;
        this.decoder = decoder(clientId,"https://www.googleapis.com/oauth2/v3/certs");
    }
    static JwtDecoder decoder(String clientId,String uri) {
        var nimbus = NimbusJwtDecoder.withJwkSetUri(uri).build();
        nimbus.setJwtValidator(new DelegatingOAuth2TokenValidator<>(
            JwtValidators.createDefault(),
            jwt -> Set.of("accounts.google.com", "https://accounts.google.com").contains(jwt.getClaimAsString("iss"))
                    && jwt.getAudience().contains(clientId) && jwt.getExpiresAt() != null
                ? OAuth2TokenValidatorResult.success()
                : OAuth2TokenValidatorResult.failure(new OAuth2Error("invalid_token"))));
        return nimbus;
    }
    String verify(String credential, String nonce) {
        if (clientId.isBlank()) throw new IllegalStateException("Google 로그인 설정이 아직 준비되지 않았어요.");
        var jwt = decoder.decode(credential);
        if (nonce == null || !nonce.equals(jwt.getClaimAsString("nonce")) || jwt.getSubject() == null || jwt.getSubject().length() > 255)
            throw new JwtException("Invalid Google identity");
        return jwt.getSubject();
    }
}
