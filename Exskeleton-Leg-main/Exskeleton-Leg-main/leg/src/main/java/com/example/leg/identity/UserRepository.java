package com.example.leg.identity;

import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;

public interface UserRepository extends JpaRepository<UserEntity, UUID> {
    @EntityGraph(attributePaths = "roles")
    Optional<UserEntity> findByEmailNormalized(String emailNormalized);

    @EntityGraph(attributePaths = "roles")
    Optional<UserEntity> findWithRolesById(UUID id);

    boolean existsByEmailNormalized(String emailNormalized);
}
