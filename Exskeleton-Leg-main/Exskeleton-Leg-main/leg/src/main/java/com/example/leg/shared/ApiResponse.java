package com.example.leg.shared;

import java.util.UUID;

public record ApiResponse<T>(T data, Meta meta) {
    public static <T> ApiResponse<T> of(T data) {
        return new ApiResponse<>(data, new Meta(UUID.randomUUID()));
    }

    public record Meta(UUID requestId) {
    }
}
