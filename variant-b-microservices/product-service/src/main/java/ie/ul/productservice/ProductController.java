package ie.ul.productservice;

import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import java.util.UUID;

@RestController
@RequestMapping("/products")
public class ProductController {

    private final ProductService productService;

    public ProductController(ProductService productService) {
        this.productService = productService;
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public ProductResponse createProduct(@Valid @RequestBody CreateProductRequest request) {
        Product product = productService.createProduct(request);
        return ProductResponse.from(product);
    }

    @GetMapping("/{id}")
    public ProductResponse getProduct(@PathVariable UUID id) {
        Product product = productService.getProduct(id);
        return ProductResponse.from(product);
    }

    @PatchMapping("/{id}/stock")
    public ProductResponse updateStock(@PathVariable UUID id,
                                       @RequestBody UpdateStockRequest request) {
        Product updated = productService.updateStock(id, request.stock());
        return ProductResponse.from(updated);
    }

}