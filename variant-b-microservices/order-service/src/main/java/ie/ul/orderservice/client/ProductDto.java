package ie.ul.orderservice.client;

import java.math.BigDecimal;
import java.util.UUID;

public record ProductDto(
        UUID id,
        String name,
        BigDecimal price,
        Integer stock
) {}