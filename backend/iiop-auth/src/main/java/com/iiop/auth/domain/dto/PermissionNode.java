package com.iiop.auth.domain.dto;

import java.util.ArrayList;
import java.util.List;

public record PermissionNode(PermissionView permission, List<PermissionNode> children) {
    public PermissionNode(PermissionView permission) { this(permission,new ArrayList<>()); }
}
