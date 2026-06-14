package ie.ul.orderservice.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.client.RestClient;

@Configuration
public class RestClientConfig {

    @Value("${services.user-service.url}")
    private String userServiceUrl;

    @Value("${services.product-service.url}")
    private String productServiceUrl;

    @Bean
    public RestClient userServiceClient() {
        return RestClient.builder()
                .baseUrl(userServiceUrl)
                .build();
    }

    @Bean
    public RestClient productServiceClient() {
        return RestClient.builder()
                .baseUrl(productServiceUrl)
                .build();
    }
}