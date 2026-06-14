package ie.ul.orderservice.client;

import ie.ul.orderservice.UserNotFoundException;
import org.springframework.http.HttpStatusCode;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

import java.util.UUID;

@Component
public class UserClient {

    private final RestClient userServiceClient;

    public UserClient(RestClient userServiceClient) {
        this.userServiceClient = userServiceClient;
    }

    public UserDto getUser(UUID id) {
        return userServiceClient.get()
                .uri("/users/{id}", id)
                .retrieve()
                .onStatus(HttpStatusCode::is4xxClientError, (request, response) -> {
                    if (response.getStatusCode().value() == 404) {
                        throw new UserNotFoundException(id);
                    }
                })
                .body(UserDto.class);
    }
}