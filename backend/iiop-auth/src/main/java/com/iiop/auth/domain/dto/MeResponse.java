package com.iiop.auth.domain.dto;
import java.util.List;
public record MeResponse(UserSummary user, List<String> roles, List<String> permissions) { }
