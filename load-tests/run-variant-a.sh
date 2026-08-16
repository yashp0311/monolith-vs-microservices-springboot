#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Variant A experimental runs
# Concurrency levels: 10, 50, 100, 200, 500
# Repetitions per level: 3
# Duration per run: 10 minutes (600s)
# Total: 15 runs, ~150 minutes plus seed/wait overhead
# ============================================================

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_BASE="$REPO_ROOT/results/variant-a-tuned-pool30"
SEED_FILE="$REPO_ROOT/load-tests/seed-data/variant-a-seed.sql"
JMX_FILE="$REPO_ROOT/load-tests/variant-a-experiment.jmx"

CONCURRENCY_LEVELS=(10 50 100 200 500)
REPETITIONS=3
DURATION=600
RAMPUP=30
COOLDOWN=30  # seconds to wait between runs

# Create timestamped run directory
RUN_ID="$(date +%Y%m%d-%H%M%S)"
RUN_DIR="$RESULTS_BASE/$RUN_ID"
mkdir -p "$RUN_DIR"

echo "==========================================="
echo "Variant A experimental run"
echo "Run ID: $RUN_ID"
echo "Results: $RUN_DIR"
echo "==========================================="

# Verify monolith is responding
if ! curl -sf http://localhost:8080/actuator/health > /dev/null; then
    echo "ERROR: Monolith is not responding on localhost:8080"
    echo "Start the app in IntelliJ before running this script"
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
Variant: A (monolith) - TUNED with HikariCP pool=30 (default was 10)
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

# Run the experiments
for THREADS in "${CONCURRENCY_LEVELS[@]}"; do
    for REP in $(seq 1 $REPETITIONS); do
        RUN_NAME="t${THREADS}-r${REP}"
        JTL_FILE="$RUN_DIR/${RUN_NAME}.jtl"
        LOG_FILE="$RUN_DIR/${RUN_NAME}.log"

        echo ""
        echo "[$(date +%H:%M:%S)] Starting run: $RUN_NAME"
        echo "  Threads: $THREADS, Repetition: $REP/$REPETITIONS"

        # Seed the database
        echo "  Seeding database..."
        docker exec -i monolith-postgres psql -U monolith -d monolith \
            < "$SEED_FILE" > /dev/null

        # Brief pause to let things settle
        sleep 5

        # Run JMeter headless
        echo "  Running JMeter (${DURATION}s)..."
        jmeter -n -t "$JMX_FILE" \
            -Jthreads=$THREADS \
            -Jrampup=$RAMPUP \
            -Jduration=$DURATION \
            -l "$JTL_FILE" \
            -j "$LOG_FILE" \
            > /dev/null

        # Save Prometheus snapshot via API
        # Captures the time window of this run for later analysis
        END_TIME=$(date +%s)
        START_TIME=$((END_TIME - DURATION - RAMPUP - 30))

        # Quick summary
        SAMPLES=$(wc -l < "$JTL_FILE")
        ERRORS=$(awk -F',' 'NR>1 && $8=="false"' "$JTL_FILE" | wc -l | tr -d ' ')
        echo "  Done. Samples: $((SAMPLES-1)), Errors: $ERRORS"

        # Cooldown between runs
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