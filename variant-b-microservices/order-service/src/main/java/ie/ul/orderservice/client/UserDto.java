package ie.ul.orderservice.client;

import java.time.Instant;
import java.util.UUID;

public record UserDto(
        UUID id,
        String name,
        String email,
        Instant createdAt
) {}