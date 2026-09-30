package com.iiop.auth.domain.dto;
import java.util.List;
public record UserJobSummary(String id,String status,List<String> roleCodes) { }
