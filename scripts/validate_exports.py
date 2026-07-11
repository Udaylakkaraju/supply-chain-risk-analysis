"""Validate the checked-in supply-chain mart exports.

This is intentionally dependency-free so it can run locally or in CI before
the Excel and Power BI artifacts are refreshed.
"""

from __future__ import annotations

import argparse
import csv
import sys
from decimal import Decimal
from pathlib import Path


MONEY_TOLERANCE = Decimal("0.02")
LANE_SCOPE_ORDERS = 65518  # market × shipping-mode groups with at least 350 orders


def read_csv(data_dir: Path, name: str) -> list[dict[str, str]]:
    with (data_dir / name).open(newline="", encoding="utf-8-sig") as handle:
        return list(csv.DictReader(handle))


def dec(value: str) -> Decimal:
    return Decimal(value)


def total(rows: list[dict[str, str]], field: str) -> Decimal:
    return sum((dec(row[field]) for row in rows), Decimal("0"))


def check(label: str, condition: bool, detail: str) -> bool:
    status = "PASS" if condition else "FAIL"
    print(f"[{status}] {label}: {detail}")
    return condition


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--data-dir", type=Path, default=Path(__file__).parents[1] / "data")
    args = parser.parse_args()
    data_dir = args.data_dir.resolve()

    required = [
        "mart_executive_kpis.csv",
        "mart_profit_priority.csv",
        "mart_shipping_mode_performance.csv",
        "mart_lane_reliability.csv",
        "mart_customer_segments.csv",
        "mart_opportunity_scenarios.csv",
    ]
    missing = [name for name in required if not (data_dir / name).exists()]
    if missing:
        print(f"[FAIL] Required exports missing: {', '.join(missing)}")
        return 1

    executive = read_csv(data_dir, "mart_executive_kpis.csv")[0]
    quartiles = read_csv(data_dir, "mart_profit_priority.csv")
    shipping = read_csv(data_dir, "mart_shipping_mode_performance.csv")
    lanes = read_csv(data_dir, "mart_lane_reliability.csv")
    customers = read_csv(data_dir, "mart_customer_segments.csv")
    scenarios = read_csv(data_dir, "mart_opportunity_scenarios.csv")

    expected_orders = int(executive["total_orders"])
    expected_breaches = int(executive["sla_breached_orders"])
    expected_profit = dec(executive["total_profit_usd"])
    expected_exposure = dec(executive["profit_at_risk_usd"])

    results = [
        check("Order reconciliation", int(total(quartiles, "orders")) == expected_orders == int(total(shipping, "orders")),
              f"executive={expected_orders}; quartiles={int(total(quartiles, 'orders'))}; shipping={int(total(shipping, 'orders'))}"),
        check("Breach reconciliation", int(total(quartiles, "sla_breached_orders")) == expected_breaches == int(total(shipping, "sla_breached_orders")),
              f"executive={expected_breaches}; quartiles={int(total(quartiles, 'sla_breached_orders'))}; shipping={int(total(shipping, 'sla_breached_orders'))}"),
        check("Profit reconciliation", abs(total(quartiles, "total_profit_usd") - expected_profit) <= MONEY_TOLERANCE and abs(total(customers, "profit_usd") - expected_profit) <= MONEY_TOLERANCE,
              f"executive=${expected_profit:,.2f}"),
        check("Profit-exposure reconciliation", abs(total(quartiles, "profit_at_risk_usd") - expected_exposure) <= MONEY_TOLERANCE and abs(total(shipping, "profit_at_risk_usd") - expected_exposure) <= MONEY_TOLERANCE and abs(total(customers, "profit_at_risk_usd") - expected_exposure) <= MONEY_TOLERANCE,
              f"executive=${expected_exposure:,.2f}"),
        check("Lane scope", int(total(lanes, "orders")) == LANE_SCOPE_ORDERS and all(row["recommended_action"].strip() for row in lanes),
              f"lanes={len(lanes)}; scoped orders={int(total(lanes, 'orders'))}; excluded low-volume orders={expected_orders - LANE_SCOPE_ORDERS}"),
        check("Scenario caveats", len(scenarios) == 3 and all("Modeled" in row["caveat"] for row in scenarios),
              f"scenarios={len(scenarios)}; every scenario is labeled as modeled"),
        check("No negative profit exposure", all(dec(row["profit_at_risk_usd"]) >= 0 for row in quartiles + shipping + customers),
              "all grouped exposure values are non-negative"),
    ]

    passed = sum(results)
    print(f"\n{passed}/{len(results)} checks passed")
    return 0 if passed == len(results) else 1


if __name__ == "__main__":
    sys.exit(main())
