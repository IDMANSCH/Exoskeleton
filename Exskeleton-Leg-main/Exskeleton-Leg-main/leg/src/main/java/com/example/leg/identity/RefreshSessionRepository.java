package com.example.leg.identity;

import java.time.Instant;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import jakarta.persistence.LockModeType;

public interface RefreshSessionRepository extends JpaRepository<RefreshSessionEntity, UUID> {
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    Optional<RefreshSessionEntity> findByTokenHash(byte[] tokenHash);

    @Modifying
    @Query("update RefreshSessionEntity r set r.revokedAt = coalesce(r.revokedAt, :now) where r.familyId = :familyId")
    void revokeFamily(@Param("familyId") UUID familyId, @Param("now") Instant now);

    @Modifying
    @Query("update RefreshSessionEntity r set r.revokedAt = :now, r.lastUsedAt = :now where r.user.id = :userId and r.tokenHash = :tokenHash and r.revokedAt is null")
    int revokeActive(@Param("userId") UUID userId, @Param("tokenHash") byte[] tokenHash, @Param("now") Instant now);
}
