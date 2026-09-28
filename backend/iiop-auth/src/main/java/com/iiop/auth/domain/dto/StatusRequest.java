package com.iiop.auth.domain.dto;
import jakarta.validation.constraints.NotBlank;
public record StatusRequest(@NotBlank String status) { }
