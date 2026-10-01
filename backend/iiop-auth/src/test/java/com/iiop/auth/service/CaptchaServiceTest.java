package com.iiop.auth.service;

import com.iiop.auth.domain.dto.CaptchaResponse;
import com.iiop.common.api.ErrorCode;
import com.iiop.common.exception.BizException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;

import java.time.Duration;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class CaptchaServiceTest {

    @Mock
    private StringRedisTemplate redisTemplate;

    @Mock
    private ValueOperations<String, String> valueOperations;

    private CaptchaService captchaService;

    @BeforeEach
    void setUp() {
        captchaService = new CaptchaService(redisTemplate);
    }

    @Test
    @DisplayName("生成验证码：生成非空图片与ID，并向Redis存入120秒TTL")
    void generateCaptcha_success() {
        when(redisTemplate.opsForValue()).thenReturn(valueOperations);

        CaptchaResponse response = captchaService.generate();

        assertNotNull(response);
        assertNotNull(response.captchaId());
        assertFalse(response.captchaId().isBlank());
        assertNotNull(response.image());
        assertTrue(response.image().startsWith("data:image/png;base64,"));

        ArgumentCaptor<String> keyCaptor = ArgumentCaptor.forClass(String.class);
        ArgumentCaptor<String> codeCaptor = ArgumentCaptor.forClass(String.class);
        ArgumentCaptor<Duration> ttlCaptor = ArgumentCaptor.forClass(Duration.class);

        verify(valueOperations).set(keyCaptor.capture(), codeCaptor.capture(), ttlCaptor.capture());
        assertEquals("iiop:captcha:" + response.captchaId(), keyCaptor.getValue());
        assertEquals(4, codeCaptor.getValue().length());
        assertEquals(Duration.ofSeconds(120), ttlCaptor.getValue());
    }

    @Test
    @DisplayName("校验并消费：验证码正确且不区分大小写，校验通过并消费")
    void verifyAndConsume_validCode_success() {
        String captchaId = "test-captcha-id";
        String redisKey = "iiop:captcha:" + captchaId;
        when(redisTemplate.execute(any(), eq(List.of(redisKey)))).thenReturn("ABCD");

        assertDoesNotThrow(() -> captchaService.verifyAndConsume(captchaId, "abcd"));
        verify(redisTemplate).execute(any(), eq(List.of(redisKey)));
    }

    @Test
    @DisplayName("校验并消费：验证码不匹配抛出BAD_REQUEST异常")
    void verifyAndConsume_invalidCode_throwsBizException() {
        String captchaId = "test-captcha-id";
        String redisKey = "iiop:captcha:" + captchaId;
        when(redisTemplate.execute(any(), eq(List.of(redisKey)))).thenReturn("ABCD");

        BizException ex = assertThrows(BizException.class, () -> captchaService.verifyAndConsume(captchaId, "WXYZ"));
        assertEquals(ErrorCode.BAD_REQUEST, ex.getErrorCode());
        assertEquals("验证码错误或已失效，请重新获取", ex.getMessage());
    }

    @Test
    @DisplayName("校验并消费：验证码不存在或已过期失效")
    void verifyAndConsume_expiredOrNotFound_throwsBizException() {
        String captchaId = "expired-id";
        String redisKey = "iiop:captcha:" + captchaId;
        when(redisTemplate.execute(any(), eq(List.of(redisKey)))).thenReturn(null);

        BizException ex = assertThrows(BizException.class, () -> captchaService.verifyAndConsume(captchaId, "ABCD"));
        assertEquals(ErrorCode.BAD_REQUEST, ex.getErrorCode());
        assertEquals("验证码错误或已失效，请重新获取", ex.getMessage());
    }

    @Test
    @DisplayName("校验并消费：入参为空校验")
    void verifyAndConsume_blankParameters_throwsBizException() {
        BizException ex1 = assertThrows(BizException.class, () -> captchaService.verifyAndConsume(null, "1234"));
        assertEquals(ErrorCode.BAD_REQUEST, ex1.getErrorCode());
        assertEquals("验证码错误或已失效，请重新获取", ex1.getMessage());

        BizException ex2 = assertThrows(BizException.class, () -> captchaService.verifyAndConsume("id", "  "));
        assertEquals(ErrorCode.BAD_REQUEST, ex2.getErrorCode());
        assertEquals("验证码错误或已失效，请重新获取", ex2.getMessage());
    }
}
