package com.iiop.auth.service;

import com.iiop.auth.domain.dto.CaptchaResponse;
import com.iiop.common.api.ErrorCode;
import com.iiop.common.exception.BizException;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.script.DefaultRedisScript;
import org.springframework.data.redis.core.script.RedisScript;
import org.springframework.stereotype.Service;

import javax.imageio.ImageIO;
import java.awt.*;
import java.awt.image.BufferedImage;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.security.SecureRandom;
import java.time.Duration;
import java.util.Base64;
import java.util.List;
import java.util.UUID;

@Service
public class CaptchaService {
    private static final String CAPTCHA_ERROR_MESSAGE = "验证码错误或已失效，请重新获取";
    private static final String CAPTCHA_KEY_PREFIX = "iiop:captcha:";
    private static final long CAPTCHA_TTL_SECONDS = 120;
    private static final char[] CODE_CHARS = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ".toCharArray();
    private static final int WIDTH = 120;
    private static final int HEIGHT = 40;
    private static final RedisScript<String> GET_AND_DEL_SCRIPT = new DefaultRedisScript<>(
            "local v = redis.call('get', KEYS[1]); if v then redis.call('del', KEYS[1]) end; return v",
            String.class
    );

    private final StringRedisTemplate redisTemplate;
    private final SecureRandom random = new SecureRandom();

    public CaptchaService(StringRedisTemplate redisTemplate) {
        this.redisTemplate = redisTemplate;
    }

    public CaptchaResponse generate() {
        String captchaId = UUID.randomUUID().toString().replace("-", "");
        StringBuilder sb = new StringBuilder(4);
        for (int i = 0; i < 4; i++) {
            sb.append(CODE_CHARS[random.nextInt(CODE_CHARS.length)]);
        }
        String code = sb.toString();

        redisTemplate.opsForValue().set(CAPTCHA_KEY_PREFIX + captchaId, code.toUpperCase(), Duration.ofSeconds(CAPTCHA_TTL_SECONDS));

        BufferedImage image = new BufferedImage(WIDTH, HEIGHT, BufferedImage.TYPE_INT_RGB);
        Graphics2D g = image.createGraphics();
        try {
            g.setColor(new Color(245, 247, 250));
            g.fillRect(0, 0, WIDTH, HEIGHT);

            // Draw noise lines
            for (int i = 0; i < 5; i++) {
                g.setColor(new Color(190 + random.nextInt(40), 190 + random.nextInt(40), 190 + random.nextInt(40)));
                int x1 = random.nextInt(WIDTH);
                int y1 = random.nextInt(HEIGHT);
                int x2 = random.nextInt(WIDTH);
                int y2 = random.nextInt(HEIGHT);
                g.drawLine(x1, y1, x2, y2);
            }

            // Draw characters
            g.setFont(new Font("Arial", Font.BOLD, 26));
            for (int i = 0; i < 4; i++) {
                g.setColor(new Color(30 + random.nextInt(80), 30 + random.nextInt(80), 50 + random.nextInt(100)));
                int x = 16 + i * 24;
                int y = 28 + random.nextInt(6) - 3;
                g.drawString(String.valueOf(code.charAt(i)), x, y);
            }

            // Draw noise dots
            for (int i = 0; i < 20; i++) {
                g.setColor(new Color(160 + random.nextInt(60), 160 + random.nextInt(60), 160 + random.nextInt(60)));
                int x = random.nextInt(WIDTH);
                int y = random.nextInt(HEIGHT);
                g.drawRect(x, y, 1, 1);
            }
        } finally {
            g.dispose();
        }

        ByteArrayOutputStream baos = new ByteArrayOutputStream();
        try {
            ImageIO.write(image, "png", baos);
        } catch (IOException e) {
            throw new BizException(ErrorCode.INTERNAL_ERROR, "生成验证码失败");
        }
        String base64 = "data:image/png;base64," + Base64.getEncoder().encodeToString(baos.toByteArray());
        return new CaptchaResponse(captchaId, base64);
    }

    public void verifyAndConsume(String captchaId, String code) {
        if (captchaId == null || captchaId.isBlank() || code == null || code.isBlank()) {
            throw new BizException(ErrorCode.BAD_REQUEST, CAPTCHA_ERROR_MESSAGE);
        }
        String redisKey = CAPTCHA_KEY_PREFIX + captchaId;
        String cachedCode;
        try {
            cachedCode = redisTemplate.execute(GET_AND_DEL_SCRIPT, List.of(redisKey));
        } catch (Exception ex) {
            cachedCode = redisTemplate.opsForValue().get(redisKey);
            redisTemplate.delete(redisKey);
        }
        if (cachedCode == null) {
            throw new BizException(ErrorCode.BAD_REQUEST, CAPTCHA_ERROR_MESSAGE);
        }
        if (!cachedCode.equalsIgnoreCase(code.trim())) {
            throw new BizException(ErrorCode.BAD_REQUEST, CAPTCHA_ERROR_MESSAGE);
        }
    }
}
