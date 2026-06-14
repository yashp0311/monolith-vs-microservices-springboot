package ie.ul.orderservice;

import ie.ul.orderservice.client.ProductClient;
import ie.ul.orderservice.client.ProductDto;
import ie.ul.orderservice.client.UserClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.UUID;

@Service
public class OrderService {

    private final OrderRepository orderRepository;
    private final UserClient userClient;
    private final ProductClient productClient;

    public OrderService(OrderRepository orderRepository,
                        UserClient userClient,
                        ProductClient productClient) {
        this.orderRepository = orderRepository;
        this.userClient = userClient;
        this.productClient = productClient;
    }

    @Transactional
    public Order createOrder(CreateOrderRequest request) {
        // Validate user exists via HTTP call to user-service
        userClient.getUser(request.userId());

        Order order = new Order();
        order.setUserId(request.userId());
        BigDecimal total = BigDecimal.ZERO;

        for (CreateOrderRequest.OrderItemRequest item : request.items()) {
            // Fetch product via HTTP call to product-service
            ProductDto product = productClient.getProduct(item.productId());

            if (product.stock() < item.quantity()) {
                throw new InsufficientStockException(product.id(),
                        item.quantity(), product.stock());
            }

            // Decrement stock via HTTP call to product-service
            int newStock = product.stock() - item.quantity();
            productClient.decrementStock(product.id(), newStock);

            // Build line item
            OrderItem orderItem = new OrderItem();
            orderItem.setOrder(order);
            orderItem.setProductId(product.id());
            orderItem.setQuantity(item.quantity());
            orderItem.setUnitPrice(product.price());
            order.getItems().add(orderItem);

            total = total.add(product.price().multiply(BigDecimal.valueOf(item.quantity())));
        }

        order.setTotalAmount(total);
        return orderRepository.save(order);
    }

    public Order getOrder(UUID id) {
        return orderRepository.findById(id)
                .orElseThrow(() -> new OrderNotFoundException(id));
    }
}