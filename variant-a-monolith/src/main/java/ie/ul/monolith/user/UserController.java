package ie.ul.monolith.user;

import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@RestController
@RequestMapping("/users")
public class UserController {

    private final UserService userService;

    public UserController(UserService userService) {
        this.userService = userService;
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public UserResponse createUser(@Valid @RequestBody CreateUserRequest request) {
        User user = userService.createUser(request);
        return UserResponse.from(user);
    }

    @GetMapping("/{id}")
    public UserResponse getUser(@PathVariable UUID id) {
        User user = userService.getUser(id);
        return UserResponse.from(user);
    }
}