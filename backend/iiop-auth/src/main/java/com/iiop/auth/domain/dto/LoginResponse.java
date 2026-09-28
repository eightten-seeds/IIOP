package com.iiop.auth.domain.dto;
import java.util.List;
public record LoginResponse(String tokenName, String tokenValue, UserSummary user, List<String> roles, List<String> permissions) { }
