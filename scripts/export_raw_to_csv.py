"""
Export Cleaned_DataCo_SupplyChain.xlsx to raw/cleaned_dataco_supplychain.csv
with snake_case headers for loading into BigQuery. Run from repo root:
  python scripts/export_raw_to_csv.py
"""
from __future__ import annotations

from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
XLSX = ROOT / "Cleaned_DataCo_SupplyChain.xlsx"
OUT = ROOT / "raw" / "cleaned_dataco_supplychain.csv"

# Explicit mapping: Excel column -> BigQuery-friendly snake_case (51 cols)
COLUMN_RENAME: dict[str, str] = {
    "Type": "payment_type",
    "Days for shipping (real)": "days_for_shipping_real",
    "Days for shipment (scheduled)": "days_for_shipment_scheduled",
    "Benefit per order": "benefit_per_order",
    "Sales per customer": "sales_per_customer",
    "Delivery Status": "delivery_status",
    "Late_delivery_risk": "late_delivery_risk",
    "Category Id": "category_id",
    "Category Name": "category_name",
    "Customer City": "customer_city",
    "Customer Country": "customer_country",
    "Customer Fname": "customer_fname",
    "Customer Id": "customer_id",
    "Customer Lname": "customer_lname",
    "Customer Segment": "customer_segment",
    "Customer State": "customer_state",
    "Customer Street": "customer_street",
    "Department Id": "department_id",
    "Department Name": "department_name",
    "Latitude": "latitude",
    "Longitude": "longitude",
    "Market": "market",
    "Order City": "order_city",
    "Order Country": "order_country",
    "Order Customer Id": "order_customer_id",
    "order date (DateOrders)": "order_date_text",
    "Order Id": "order_id",
    "Order Item Cardprod Id": "order_item_cardprod_id",
    "Order Item Discount": "order_item_discount",
    "Order Item Discount Rate": "order_item_discount_rate",
    "Order Item Id": "order_item_id",
    "Order Item Product Price": "order_item_product_price",
    "Order Item Profit Ratio": "order_item_profit_ratio",
    "Order Item Quantity": "order_item_quantity",
    "Order Item Total": "order_item_total",
    "Order Profit Per Order": "order_profit_per_order",
    "Order Region": "order_region",
    "Order State": "order_state",
    "Order Status": "order_status",
    "Product Card Id": "product_card_id",
    "Product Category Id": "product_category_id",
    "Product Name": "product_name",
    "Product Price": "product_price",
    "shipping date (DateOrders)": "shipping_date_text",
    "Shipping Mode": "shipping_mode",
    "Order Date": "order_date",
    "Shipping Date": "shipping_date",
    "delay_Days": "delay_days",
    "SLA_Breached": "sla_breached",
    "Profit at Risk": "profit_at_risk",
    "Order Month": "order_month",
}


def main() -> None:
    if not XLSX.is_file():
        raise SystemExit(f"Missing Excel file: {XLSX}")

    print(f"Reading {XLSX.name} ...")
    df = pd.read_excel(XLSX, engine="openpyxl")

    missing = set(COLUMN_RENAME.keys()) - set(df.columns)
    extra = set(df.columns) - set(COLUMN_RENAME.keys())
    if missing:
        raise SystemExit(f"Excel missing expected columns: {sorted(missing)}")
    if extra:
        raise SystemExit(f"Unexpected columns in Excel: {sorted(extra)}")

    df = df.rename(columns=COLUMN_RENAME)

    OUT.parent.mkdir(parents=True, exist_ok=True)
    # ISO-8601 dates; no index; UTF-8
    df.to_csv(OUT, index=False, encoding="utf-8", date_format="%Y-%m-%d %H:%M:%S")
    print(f"Wrote {len(df):,} rows x {len(df.columns)} cols -> {OUT}")
    print(f"File size: {OUT.stat().st_size / 1_048_576:.1f} MB")


if __name__ == "__main__":
    main()
