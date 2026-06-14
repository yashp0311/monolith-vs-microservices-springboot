package ie.ul.orderservice.client;

import ie.ul.orderservice.ProductNotFoundException;
import org.springframework.http.HttpStatusCode;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

import java.util.UUID;

@Component
public class ProductClient {

    private final RestClient productServiceClient;

    public ProductClient(RestClient productServiceClient) {
        this.productServiceClient = productServiceClient;
    }

    public ProductDto getProduct(UUID id) {
        return productServiceClient.get()
                .uri("/products/{id}", id)
                .retrieve()
                .onStatus(HttpStatusCode::is4xxClientError, (request, response) -> {
                    if (response.getStatusCode().value() == 404) {
                        throw new ProductNotFoundException(id);
                    }
                })
                .body(ProductDto.class);
    }

    public void decrementStock(UUID id, int newStock) {
        productServiceClient.patch()
                .uri("/products/{id}/stock", id)
                .contentType(MediaType.APPLICATION_JSON)
                .body(new UpdateStockRequest(newStock))
                .retrieve()
                .toBodilessEntity();
    }
}