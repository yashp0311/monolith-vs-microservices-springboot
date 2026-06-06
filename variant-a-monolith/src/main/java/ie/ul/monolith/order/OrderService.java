package ie.ul.monolith.order;

import ie.ul.monolith.product.Product;
import ie.ul.monolith.product.ProductRepository;
import ie.ul.monolith.product.ProductNotFoundException;
import ie.ul.monolith.user.UserRepository;
import ie.ul.monolith.user.UserNotFoundException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.UUID;

@Service
public class OrderService {

    private final OrderRepository orderRepository;
    private final UserRepository userRepository;
    private final ProductRepository productRepository;

    public OrderService(OrderRepository orderRepository,
                        UserRepository userRepository,
                        ProductRepository productRepository) {
        this.orderRepository = orderRepository;
        this.userRepository = userRepository;
        this.productRepository = productRepository;
    }

    @Transactional
    public Order createOrder(CreateOrderRequest request) {
        // Validate user exists
        if (!userRepository.existsById(request.userId())) {
            throw new UserNotFoundException(request.userId());
        }

        Order order = new Order();
        order.setUserId(request.userId());
        BigDecimal total = BigDecimal.ZERO;

        // Process each item
        for (CreateOrderRequest.OrderItemRequest item : request.items()) {
            Product product = productRepository.findById(item.productId())
                    .orElseThrow(() -> new ProductNotFoundException(item.productId()));

            if (product.getStock() < item.quantity()) {
                throw new InsufficientStockException(product.getId(),
                        item.quantity(), product.getStock());
            }

            // Decrement stock
            product.setStock(product.getStock() - item.quantity());

            // Add line item
            OrderItem orderItem = new OrderItem();
            orderItem.setOrder(order);
            orderItem.setProductId(product.getId());
            orderItem.setQuantity(item.quantity());
            orderItem.setUnitPrice(product.getPrice());
            order.getItems().add(orderItem);

            // Accumulate total
            total = total.add(product.getPrice().multiply(BigDecimal.valueOf(item.quantity())));
        }

        order.setTotalAmount(total);
        return orderRepository.save(order);
    }

    public Order getOrder(UUID id) {
        return orderRepository.findById(id)
                .orElseThrow(() -> new OrderNotFoundException(id));
    }
}