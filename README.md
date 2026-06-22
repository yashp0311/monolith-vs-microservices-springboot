# Monolithic vs Microservices in Java Spring Boot

MSc Software Engineering Dissertation Project, University of Limerick (2026).
Controlled performance comparison of monolithic and microservice architectures in Java Spring Boot under progressive concurrent load.

**Author:** Yash Madhukar Patil (25297651)
**Supervisor:** Dr. Andrew Le Gear

## Research Questions

- **RQ1:** How does a monolithic Spring Boot architecture compare to a microservice architecture in response time and throughput under varying concurrent load?
- **RQ2:** What is the impact of increasing concurrent load on CPU and memory utilisation in monolithic versus microservice Java applications?

## Repository structure

- variant-a-monolith/        # Variant A: monolithic Spring Boot app
- variant-b-microservices/   # Variant B: REST-based microservices
- user-service/
- product-service/
- order-service/
- load-tests/                # Apache JMeter test plans
- docker/                    # Docker Compose files for each variant
- results/                   # Raw experimental data (read-only after collection)
- analysis/                  # Python notebooks and scripts for analysis
- docs/                      # Design documents, contracts, dissertation drafts

## Status

Currently in design phase. Build of Variant C starts next.

## License

MIT
