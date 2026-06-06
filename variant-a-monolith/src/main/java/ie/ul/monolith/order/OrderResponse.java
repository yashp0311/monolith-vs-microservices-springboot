package ie.ul.monolith.order;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

public record OrderResponse(
        UUID id,
        UUID userId,
        List<OrderItemResponse> items,
        BigDecimal totalAmount,
        OrderStatus status,
        Instant createdAt
) {
    public record OrderItemResponse(
            UUID productId,
            Integer quantity,
            BigDecimal unitPrice
    ) {}

    public static OrderResponse from(Order order) {
        List<OrderItemResponse> items = order.getItems().stream()
                .map(i -> new OrderItemResponse(i.getProductId(), i.getQuantity(), i.getUnitPrice()))
                .toList();
        return new OrderResponse(
                order.getId(),
                order.getUserId(),
                items,
                order.getTotalAmount(),
                order.getStatus(),
                order.getCreatedAt()
        );
    }
}