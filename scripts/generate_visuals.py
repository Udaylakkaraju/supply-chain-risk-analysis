"""
Generates the visual set used in README.md from the checked-in mart CSVs.

Run from the repo root:
    python scripts/generate_visuals.py

Outputs land in outputs/. Every number drawn here traces directly to
data/mart_*.csv - no numbers are computed independently in this script
beyond simple formatting/derived shares that are already in the marts.
"""

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch
import matplotlib.ticker as mticker
import pandas as pd
import numpy as np
import os

DATA = "data"
OUT = "outputs"
os.makedirs(OUT, exist_ok=True)

# ---------------------------------------------------------------- palette --
NAVY = "#152442"
NAVY_SOFT = "#2C4066"
TEAL = "#2B8C93"
AMBER = "#E68A2E"
RED = "#C0392B"
GREEN = "#4F9D69"
GRAY = "#8A93A6"
GRID = "#E7E9EE"
INK = "#1C2333"
PAPER = "#FFFFFF"

plt.rcParams.update({
    "font.family": "DejaVu Sans",
    "text.color": INK,
    "axes.edgecolor": "#C7CCD6",
    "axes.labelcolor": INK,
    "xtick.color": "#4B5468",
    "ytick.color": "#4B5468",
    "axes.grid": True,
    "grid.color": GRID,
    "grid.linewidth": 0.9,
    "figure.facecolor": PAPER,
    "axes.facecolor": PAPER,
    "savefig.facecolor": PAPER,
})

def style_ax(ax, hide_top_right=True):
    if hide_top_right:
        ax.spines["top"].set_visible(False)
        ax.spines["right"].set_visible(False)
    ax.spines["left"].set_color("#C7CCD6")
    ax.spines["bottom"].set_color("#C7CCD6")
    ax.set_axisbelow(True)

def money(x, pos=None):
    if abs(x) >= 1_000_000:
        return f"${x/1_000_000:.1f}M"
    if abs(x) >= 1_000:
        return f"${x/1_000:.0f}K"
    return f"${x:.0f}"

# =====================================================================
# 1. KPI hero banner
# =====================================================================
kpi = pd.read_csv(f"{DATA}/mart_executive_kpis.csv").iloc[0]
mkt = pd.read_csv(f"{DATA}/mart_market_efficiency.csv")
revenue = mkt["revenue_usd"].sum()

cards = [
    ("REVENUE ANALYZED", f"${revenue/1_000_000:.2f}M", "65,752 orders", NAVY),
    ("SLA BREACH RATE", f"{kpi['sla_breach_rate_pct']:.1f}%", "37,698 late orders", RED),
    ("PROFIT AT RISK", f"${kpi['profit_at_risk_usd']/1_000_000:.2f}M", "sitting on breached orders", AMBER),
    ("HIGH-VALUE PROFIT EXPOSED", f"${kpi['high_value_profit_at_risk_usd']/1_000_000:.2f}M", "top profit quartile", TEAL),
    ("BREACH CONCENTRATION", f"{kpi['top_5_priority_lane_breach_share_pct']:.0f}%", "held by 5 of 19 lanes", GREEN),
]

fig, ax = plt.subplots(figsize=(13.6, 2.5), dpi=200)
ax.set_xlim(0, len(cards))
ax.set_ylim(0, 1)
ax.axis("off")

card_w = 0.94
for i, (label, value, sub, color) in enumerate(cards):
    x0 = i + (1 - card_w) / 2
    box = FancyBboxPatch((x0, 0.06), card_w, 0.88,
                          boxstyle="round,pad=0,rounding_size=0.045",
                          linewidth=0, facecolor="#F7F8FA", zorder=1)
    ax.add_patch(box)
    accent = FancyBboxPatch((x0, 0.06), card_w, 0.06,
                             boxstyle="round,pad=0,rounding_size=0.03",
                             linewidth=0, facecolor=color, zorder=2)
    ax.add_patch(accent)
    cx = i + 0.5
    ax.text(cx, 0.68, value, ha="center", va="center", fontsize=22,
            fontweight="bold", color=NAVY, zorder=3)
    ax.text(cx, 0.40, label, ha="center", va="center", fontsize=9.3,
            fontweight="bold", color="#5B6479", zorder=3,
            fontfamily="DejaVu Sans")
    ax.text(cx, 0.24, sub, ha="center", va="center", fontsize=8.8,
            color="#8A93A6", zorder=3)

plt.subplots_adjust(left=0.005, right=0.995, top=0.98, bottom=0.02)
fig.savefig(f"{OUT}/kpi_hero_banner.png", dpi=200, bbox_inches="tight", pad_inches=0.12)
plt.close(fig)

# =====================================================================
# 2. Profit-quartile breach parity
# =====================================================================
pp = pd.read_csv(f"{DATA}/mart_profit_priority.csv")
pp = pp.sort_values("profit_quartile")

fig, ax = plt.subplots(figsize=(8.6, 5.0), dpi=200)
x = np.arange(len(pp))
bars = ax.bar(x, pp["sla_breach_rate_pct"], width=0.58, color=NAVY, zorder=3)

overall = kpi["sla_breach_rate_pct"]
ax.axhline(overall, color=RED, linestyle="--", linewidth=1.4, zorder=2)
ax.text(len(pp) - 0.32, 64.5, f"Overall avg: {overall:.1f}%",
        color=RED, fontsize=9.8, fontweight="bold", ha="right")

for xi, row in zip(x, pp.itertuples()):
    ax.text(xi, row.sla_breach_rate_pct + 2.0, f"{row.sla_breach_rate_pct:.1f}%",
            ha="center", fontsize=12.5, fontweight="bold", color=NAVY)

labels = [f"{tier.replace(' profit', '')}\n${profit/1_000_000:,.2f}M profit"
          for tier, profit in zip(pp["profit_tier"], pp["total_profit_usd"])]
ax.set_xticks(x)
ax.set_xticklabels(labels, fontsize=9.6)
ax.set_ylim(0, 68)
ax.set_ylabel("SLA breach rate (%)", fontsize=10.5)
ax.set_title("High-profit orders get no fulfillment advantage",
             fontsize=14.5, fontweight="bold", color=INK, pad=14, loc="left")
ax.text(0, 1.0, "Breach rate by profit quartile - top quartile ($4.09M profit) breaches almost as often as the bottom",
        transform=ax.transAxes, fontsize=9.6, color="#5B6479", va="bottom")
ax.yaxis.set_major_formatter(mticker.PercentFormatter(xmax=100, decimals=0))
style_ax(ax)
ax.grid(axis="x", visible=False)
plt.subplots_adjust(bottom=0.2)
fig.savefig(f"{OUT}/profit_quartile_breach.png", dpi=200, bbox_inches="tight")
plt.close(fig)

# =====================================================================
# 3. Shipping-mode promise gap
# =====================================================================
sm = pd.read_csv(f"{DATA}/mart_sla_promise_gap.csv")
sm = sm.sort_values("sla_breach_rate_pct", ascending=False).reset_index(drop=True)

fig, ax = plt.subplots(figsize=(9.4, 5.2), dpi=200)
x = np.arange(len(sm))
w = 0.34
ax.bar(x - w/2, sm["avg_promised_delivery_days"], width=w, color=TEAL,
       label="Promised days", zorder=3)
ax.bar(x + w/2, sm["avg_actual_delivery_days"], width=w, color=NAVY,
       label="Actual days", zorder=3)

for xi, row in zip(x, sm.itertuples()):
    color = RED if row.sla_breach_rate_pct >= 70 else ("#B9852F" if row.sla_breach_rate_pct >= 45 else GREEN)
    ax.text(xi, max(row.avg_promised_delivery_days, row.avg_actual_delivery_days) + 0.18,
            f"{row.sla_breach_rate_pct:.0f}% breach", ha="center", fontsize=10.5,
            fontweight="bold", color=color)

labels = [f"{mode}\n${risk/1_000_000:,.2f}M at risk"
          for mode, risk in zip(sm["shipping_mode"], sm["profit_at_risk_usd"])]
ax.set_xticks(x)
ax.set_xticklabels(labels, fontsize=9.6)
ax.set_ylabel("Delivery days", fontsize=10.5)
ax.set_ylim(0, 4.9)
ax.set_title("Second Class is the clearest fixable service-promise gap",
             fontsize=14.5, fontweight="bold", color=INK, pad=14, loc="left")
ax.text(0, 1.0, "Promised vs. actual delivery time by shipping mode, with breach rate and profit exposure",
        transform=ax.transAxes, fontsize=9.6, color="#5B6479", va="bottom")
ax.legend(loc="upper left", frameon=False, fontsize=10)
style_ax(ax)
ax.grid(axis="x", visible=False)
plt.subplots_adjust(bottom=0.2)
fig.savefig(f"{OUT}/shipping_mode_sla_gap.png", dpi=200, bbox_inches="tight")
plt.close(fig)

# =====================================================================
# 4. Lane priority scatter
# =====================================================================
ln = pd.read_csv(f"{DATA}/mart_lane_reliability.csv")

action_color = {
    "Protect": RED,
    "Stabilize": AMBER,
    "Monitor": TEAL,
    "Maintain": GREEN,
    "Review SLA Definition": GRAY,
}
ln["color"] = ln["recommended_action"].map(action_color)

max_orders = ln["orders"].max()
ln["bubble"] = 300 + (ln["orders"] / max_orders) * 2600

fig, ax = plt.subplots(figsize=(10.6, 6.6), dpi=200)

for action, sub in ln.groupby("recommended_action"):
    ax.scatter(sub["sla_breach_rate_pct"], sub["profit_at_risk_usd"],
               s=sub["bubble"], color=action_color[action], alpha=0.72,
               edgecolors="white", linewidths=1.3, zorder=3, label=action)

# hand-placed labels for the 5 variability-priority lanes (avoids overlap)
label_specs = {
    "Europe | Standard Class": (39.88, 465247.74, (150, 10), "left"),
    "Pacific Asia | Standard Class": (40.25, 354965.89, (160, -25), "left"),
    "Europe | Second Class": (79.97, 303644.63, (-150, 95), "right"),
    "LATAM | Second Class": (79.35, 277052.94, (-150, -60), "right"),
    "USCA | Second Class": (79.92, 143942.57, (-150, 15), "right"),
}
for lane, (bx, by, offset, ha) in label_specs.items():
    ax.annotate(
        lane, xy=(bx, by), xytext=offset, textcoords="offset points",
        ha=ha, fontsize=9.6, fontweight="bold", color=NAVY,
        arrowprops=dict(arrowstyle="-", color="#9AA2B1", lw=1.0,
                         shrinkA=6, shrinkB=8),
        bbox=dict(boxstyle="round,pad=0.28", fc="white", ec="#D6DAE3", lw=0.8),
        zorder=5,
    )

ax.set_xlim(33, 107)
ax.set_ylim(-15000, 510000)
ax.set_xlabel("SLA breach rate (%)", fontsize=10.5)
ax.set_ylabel("Profit at risk (USD)", fontsize=10.5)
ax.yaxis.set_major_formatter(mticker.FuncFormatter(money))
ax.set_title("A small set of lanes carries most of the risk",
             fontsize=14.5, fontweight="bold", color=INK, pad=14, loc="left")
ax.text(0, 1.0, "Every market x shipping-mode lane, sized by order volume - the 5 labeled lanes drive 41% of all breaches",
        transform=ax.transAxes, fontsize=9.6, color="#5B6479", va="bottom")
leg = ax.legend(title="Recommended action", loc="upper left", bbox_to_anchor=(1.015, 1.0),
                 frameon=False, fontsize=9.8, title_fontsize=10.5, borderaxespad=0)
style_ax(ax)
plt.subplots_adjust(bottom=0.1, right=0.8)
fig.savefig(f"{OUT}/lane_priority_scatter.png", dpi=200, bbox_inches="tight")
plt.close(fig)

# =====================================================================
# 5. Monthly trend
# =====================================================================
mt = pd.read_csv(f"{DATA}/mart_monthly_trends.csv")
mt["order_month"] = pd.to_datetime(mt["order_month"])

fig, ax1 = plt.subplots(figsize=(10.8, 5.4), dpi=200)
ax2 = ax1.twinx()

# de-emphasize the final 2 partial-period months
n = len(mt)
stable = mt.iloc[: n - 2]
tail = mt.iloc[n - 3:]

ax2.fill_between(stable["order_month"], 0, stable["profit_at_risk_usd"],
                  color=AMBER, alpha=0.18, zorder=1)
ax2.fill_between(tail["order_month"], 0, tail["profit_at_risk_usd"],
                  color=AMBER, alpha=0.08, zorder=1)
ax2.plot(stable["order_month"], stable["profit_at_risk_usd"], color=AMBER, linewidth=2.1, zorder=3)
ax2.plot(tail["order_month"], tail["profit_at_risk_usd"], color=AMBER, linewidth=2.1,
         linestyle=(0, (3, 2)), zorder=3)

ax1.plot(mt["order_month"], mt["sla_breach_rate_pct"], color=NAVY, linewidth=2.4, zorder=4)

ax1.set_ylabel("SLA breach rate (%)", fontsize=10.5, color=NAVY)
ax2.set_ylabel("Profit at risk (USD)", fontsize=10.5, color="#B9752A")
ax1.tick_params(axis="y", colors=NAVY)
ax2.tick_params(axis="y", colors="#B9752A")
ax2.yaxis.set_major_formatter(mticker.FuncFormatter(money))
ax1.set_ylim(40, 70)
ax2.grid(False)
ax1.set_title("Breach rate has stayed structurally high for three years",
              fontsize=14.5, fontweight="bold", color=INK, pad=14, loc="left")
ax1.text(0, 1.0, "Monthly SLA breach rate and profit-at-risk, Jan 2015 - Jan 2018 (final months are a partial period)",
         transform=ax1.transAxes, fontsize=9.6, color="#5B6479", va="bottom")
style_ax(ax1)
style_ax(ax2, hide_top_right=False)
ax2.spines["top"].set_visible(False)
fig.savefig(f"{OUT}/monthly_trend.png", dpi=200, bbox_inches="tight")
plt.close(fig)

print("Done: 5 visuals written to outputs/")
