package ie.ul.productservice;

import org.springframework.stereotype.Service;
import java.util.UUID;

@Service
public class ProductService {

    private final ProductRepository productRepository;

    public ProductService(ProductRepository productRepository) {
        this.productRepository = productRepository;
    }

    public Product createProduct(CreateProductRequest request) {
        Product product = new Product();
        product.setName(request.name());
        product.setPrice(request.price());
        product.setStock(request.stock());
        return productRepository.save(product);
    }

    public Product getProduct(UUID id) {
        return productRepository.findById(id)
                .orElseThrow(() -> new ProductNotFoundException(id));
    }

    public Product updateStock(UUID id, Integer newStock) {
        Product product = getProduct(id);
        product.setStock(newStock);
        return productRepository.save(product);
    }
}