#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Variant B experimental runs
# ============================================================

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_BASE="$REPO_ROOT/results/variant-b"
USER_SEED="$REPO_ROOT/load-tests/seed-data/variant-b-user-seed.sql"
PRODUCT_SEED="$REPO_ROOT/load-tests/seed-data/variant-b-product-seed.sql"
ORDER_SEED="$REPO_ROOT/load-tests/seed-data/variant-b-order-seed.sql"
JMX_FILE="$REPO_ROOT/load-tests/variant-b-experiment.jmx"

CONCURRENCY_LEVELS=(10 50 100 200 500)
REPETITIONS=3
DURATION=600
RAMPUP=30
COOLDOWN=30

RUN_ID="$(date +%Y%m%d-%H%M%S)"
RUN_DIR="$RESULTS_BASE/$RUN_ID"
mkdir -p "$RUN_DIR"

echo "==========================================="
echo "Variant B experimental run"
echo "Run ID: $RUN_ID"
echo "Results: $RUN_DIR"
echo "==========================================="

# Verify all three services are responding
if ! curl -sf http://localhost:8081/actuator/health > /dev/null; then
    echo "ERROR: user-service is not responding on localhost:8081"
    exit 1
fi
if ! curl -sf http://localhost:8082/actuator/health > /dev/null; then
    echo "ERROR: product-service is not responding on localhost:8082"
    exit 1
fi
if ! curl -sf http://localhost:8083/actuator/health > /dev/null; then
    echo "ERROR: order-service is not responding on localhost:8083"
    exit 1
fi

# Verify Prometheus is responding
if ! curl -sf http://localhost:9090/-/ready > /dev/null; then
    echo "ERROR: Prometheus is not responding on localhost:9090"
    exit 1
fi

# Save experimental metadata
cat > "$RUN_DIR/metadata.txt" <<EOF
Run ID: $RUN_ID
Started: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
Variant: B (REST microservices)
Services: user-service (8081), product-service (8082), order-service (8083)
Concurrency levels: ${CONCURRENCY_LEVELS[*]}
Repetitions: $REPETITIONS
Duration per run: ${DURATION}s
Ramp-up: ${RAMPUP}s
Cooldown between runs: ${COOLDOWN}s
JMeter version: $(jmeter --version 2>&1 | grep -i "apache jmeter" | head -1)
Java version: $(java -version 2>&1 | head -1)
Mac: $(sw_vers -productName) $(sw_vers -productVersion)
Hardware: $(sysctl -n machdep.cpu.brand_string)
RAM: $(sysctl -n hw.memsize | awk '{print $1/1024/1024/1024 " GB"}')
EOF

cat "$RUN_DIR/metadata.txt"
echo "==========================================="

for THREADS in "${CONCURRENCY_LEVELS[@]}"; do
    for REP in $(seq 1 $REPETITIONS); do
        RUN_NAME="t${THREADS}-r${REP}"
        JTL_FILE="$RUN_DIR/${RUN_NAME}.jtl"
        LOG_FILE="$RUN_DIR/${RUN_NAME}.log"

        echo ""
        echo "-------------------------------------------"
        echo "[$(date +%H:%M:%S)] Starting run: $RUN_NAME"
        echo "  Threads: $THREADS, Repetition: $REP/$REPETITIONS"
        echo "-------------------------------------------"

        # Seed all three databases
        echo "  Seeding databases..."
        docker exec -i variant-b-postgres-user psql -U user_service -d user_service \
            < "$USER_SEED" > /dev/null
        docker exec -i variant-b-postgres-product psql -U product_service -d product_service \
            < "$PRODUCT_SEED" > /dev/null
        docker exec -i variant-b-postgres-order psql -U order_service -d order_service \
            < "$ORDER_SEED" > /dev/null

        sleep 5

        echo "  Running JMeter (${DURATION}s)..."
        jmeter -n -t "$JMX_FILE" \
            -Jthreads=$THREADS \
            -Jrampup=$RAMPUP \
            -Jduration=$DURATION \
            -l "$JTL_FILE" \
            -j "$LOG_FILE" \
            > /dev/null

        SAMPLES=$(wc -l < "$JTL_FILE")
        ERRORS=$(awk -F',' 'NR>1 && $8=="false"' "$JTL_FILE" | wc -l | tr -d ' ')
        echo "  Done. Samples: $((SAMPLES-1)), Errors: $ERRORS"

        if [ "$THREADS" != "500" ] || [ "$REP" != "$REPETITIONS" ]; then
            echo "  Cooldown ${COOLDOWN}s..."
            sleep $COOLDOWN
        fi
    done
done

echo ""
echo "==========================================="
echo "All runs complete at $(date)"
echo "Results in: $RUN_DIR"
echo "==========================================="