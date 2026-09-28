package com.iiop.auth.config;

import org.junit.jupiter.api.Test;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import static org.junit.jupiter.api.Assertions.*;

class PasswordEncoderTest {
    @Test void storesOnlyBcryptHash() {
        String raw="Local-Test-Only-Password";
        BCryptPasswordEncoder encoder=new BCryptPasswordEncoder();
        String hash=encoder.encode(raw);
        assertNotEquals(raw,hash);
        assertTrue(hash.startsWith("$2"));
        assertTrue(encoder.matches(raw,hash));
    }
}
