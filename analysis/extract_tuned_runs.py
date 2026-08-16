import sys
from pathlib import Path

import numpy as np
import pandas as pd

# ─── Configuration ──────────────────────────────────────────────────────────

REPO_ROOT = Path(__file__).resolve().parent.parent
RESULTS = REPO_ROOT / "results"

DATASETS = {
    "A_tuned": RESULTS / "variant-a-tuned-pool30" / "20260727-162451",
    "B_tuned": RESULTS / "variant-b-tuned-pool30" / "20260727-225811",
}

CONCURRENCY_LEVELS = [10, 50, 100, 200, 500]
REPETITIONS = [1, 2, 3]

# The effective measurement window used in the experimental protocol,
# after discarding the 60-second warmup. Throughput = samples / this value.
EFFECTIVE_WINDOW_SECONDS = 540

# ─── Load a JTL file ────────────────────────────────────────────────────────

def load_jtl(path: Path) -> pd.DataFrame:
    """Load a JMeter JTL CSV and return the successful-sample rows."""
    if not path.exists():
        raise FileNotFoundError(f"Missing JTL file: {path}")
    df = pd.read_csv(path, usecols=["elapsed", "success"])
    df = df[df["success"] == True]  # noqa: E712
    return df

# ─── Per-run stats ──────────────────────────────────────────────────────────

def run_stats(jtl_path: Path) -> dict:
    """Compute samples, mean, P95, throughput for one JTL file."""
    df = load_jtl(jtl_path)
    samples = len(df)
    mean = float(df["elapsed"].mean())
    p95 = float(df["elapsed"].quantile(0.95))
    throughput = samples / EFFECTIVE_WINDOW_SECONDS
    return {"samples": samples, "mean": mean, "p95": p95, "throughput": throughput}

# ─── Print the per-run table ────────────────────────────────────────────────

def print_per_run_table(label: str, session_dir: Path):
    print(f"\n{'=' * 78}")
    print(f" PER-RUN TABLE: {label}")
    print(f" Source: {session_dir.relative_to(REPO_ROOT)}")
    print("=" * 78)
    print(f"{'Conc':>5}  {'Rep':>3}  {'Samples':>10}  "
          f"{'Mean (ms)':>10}  {'P95 (ms)':>10}  {'Tput (req/s)':>13}")
    print("-" * 78)

    aggregated = {}
    for level in CONCURRENCY_LEVELS:
        rep_stats = []
        for rep in REPETITIONS:
            jtl = session_dir / f"t{level}-r{rep}.jtl"
            try:
                s = run_stats(jtl)
            except FileNotFoundError as e:
                print(f"  ERROR: {e}", file=sys.stderr)
                sys.exit(1)
            rep_stats.append(s)
            print(f"{level:>5}  {rep:>3}  {s['samples']:>10,}  "
                  f"{s['mean']:>10.1f}  {s['p95']:>10.0f}  {s['throughput']:>13.0f}")
        aggregated[level] = rep_stats
    return aggregated

# ─── Print the aggregated table ─────────────────────────────────────────────

def print_aggregated_table(label: str, aggregated: dict):
    print(f"\n{'=' * 78}")
    print(f" AGGREGATED TABLE: {label}")
    print("=" * 78)
    print(f"{'Conc':>5}  {'Mean (ms)':>10}  {'Std Dev (ms)':>13}  "
          f"{'Mean P95 (ms)':>14}  {'Mean Tput (req/s)':>18}")
    print("-" * 78)
    for level in CONCURRENCY_LEVELS:
        stats = aggregated[level]
        means = [s["mean"] for s in stats]
        p95s = [s["p95"] for s in stats]
        tputs = [s["throughput"] for s in stats]
        mean_of_means = np.mean(means)
        std_of_means = np.std(means, ddof=1)
        mean_of_p95s = np.mean(p95s)
        mean_of_tputs = np.mean(tputs)
        print(f"{level:>5}  {mean_of_means:>10.1f}  {std_of_means:>13.2f}  "
              f"{mean_of_p95s:>14.0f}  {mean_of_tputs:>18.0f}")

# ─── Main ───────────────────────────────────────────────────────────────────

def main():
    for label, session_dir in DATASETS.items():
        aggregated = print_per_run_table(label, session_dir)
        print_aggregated_table(label, aggregated)

if __name__ == "__main__":
    main()