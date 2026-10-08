package com.example.leg.identity;

import java.util.Collection;
import java.util.List;
import java.util.UUID;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;

public record AuthenticatedUser(UUID id, List<String> roles) implements UserDetails {
    @Override
    public Collection<? extends GrantedAuthority> getAuthorities() {
        return roles.stream().map(role -> (GrantedAuthority) () -> "ROLE_" + role.toUpperCase()).toList();
    }

    @Override
    public String getPassword() {
        return "";
    }

    @Override
    public String getUsername() {
        return id.toString();
    }
}
