# -*- coding: utf-8 -*-
"""
Supply Chain Analysis -- Python Visualization Dashboard
========================================================
Generates three publication-ready PNG outputs covering the full analysis story:
  - output_exec_summary.png      : Thesis, KPI cards, heatmap, breach line, profit bar
  - output_chapter_deepdives.png : Ch1 prioritisation, Ch2 market, Ch3 variability
  - output_recommendations.png   : Impact scenarios + prioritised action table

Data source: All values are pulled from BigQuery marts (see sql/bigquery/02_build_powerbi_marts.sql).
             Numbers are hardcoded here for offline/portfolio rendering; to make this
             live, replace each data block with a BigQuery client query against the
             corresponding mart_ table.

Run from repo root:
    python scripts/supply_chain_dashboard.py

Outputs saved to: outputs/
"""

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.gridspec as gridspec
import numpy as np

RED      = "#C0392B"
ORANGE   = "#E67E22"
NEUTRAL  = "#7F8C8D"
DARK     = "#2C3E50"
LIGHT_BG = "#F7F9FC"
CARD_BG  = "#FFFFFF"
SUBTLE   = "#ECF0F1"

def spine_clean(ax):
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)

# ============================================================
# PAGE 1 -- EXECUTIVE SUMMARY
# ============================================================
fig1 = plt.figure(figsize=(18, 20), facecolor=LIGHT_BG)
fig1.suptitle(
    "Supply Chain Risk Analysis -- Executive Summary",
    fontsize=22, fontweight="bold", color=DARK, y=0.98
)

gs = gridspec.GridSpec(4, 3, figure=fig1, hspace=0.55, wspace=0.35,
                       top=0.93, bottom=0.04, left=0.06, right=0.97)

# Thesis box
ax_thesis = fig1.add_subplot(gs[0, :])
ax_thesis.set_facecolor("#2C3E50")
thesis = (
    '"The network is value-blind: high-profit orders receive no service advantage,\n'
    'the shipping promise breaks at the mode level, and SLA failures concentrate\n'
    'in a handful of lanes."'
)
ax_thesis.text(0.5, 0.5, thesis, ha="center", va="center", fontsize=14,
               fontstyle="italic", color="white", transform=ax_thesis.transAxes)
ax_thesis.set_xticks([]); ax_thesis.set_yticks([])
for sp in ax_thesis.spines.values(): sp.set_visible(False)

# KPI cards
kpis = [
    ("$2.77M",  "High-value profit at risk",     RED),
    ("57.3%",   "Overall SLA breach rate",        ORANGE),
    ("40.67%",  "Breach share in top 5 lanes",    RED),
]
for i, (val, label, color) in enumerate(kpis):
    ax = fig1.add_subplot(gs[1, i])
    ax.set_facecolor(CARD_BG)
    ax.text(0.5, 0.62, val, ha="center", va="center", fontsize=36,
            fontweight="bold", color=color, transform=ax.transAxes)
    ax.text(0.5, 0.22, label, ha="center", va="center", fontsize=11,
            color=NEUTRAL, transform=ax.transAxes)
    for sp in ax.spines.values():
        sp.set_linewidth(2); sp.set_color(color)
    ax.set_xticks([]); ax.set_yticks([])

# Heatmap: breach rate by market x mode
ax_heat = fig1.add_subplot(gs[2, :2])
markets = ["Africa", "USCA", "Pacific Asia", "LATAM", "Europe"]
modes   = ["Same Day", "Second Class", "Standard Class"]
breach_data = np.array([
    [28.57, 80.04, 39.82],
    [28.62, 79.55, 39.72],
    [28.76, 80.42, 39.85],
    [28.81, 78.94, 39.63],
    [28.90, 79.98, 39.91],
])
im = ax_heat.imshow(breach_data, cmap="RdYlGn_r", aspect="auto", vmin=25, vmax=85)
ax_heat.set_xticks(range(len(modes))); ax_heat.set_xticklabels(modes, fontsize=11)
ax_heat.set_yticks(range(len(markets))); ax_heat.set_yticklabels(markets, fontsize=11)
for r in range(len(markets)):
    for c in range(len(modes)):
        txt_color = "white" if breach_data[r,c] > 60 else DARK
        ax_heat.text(c, r, "{:.1f}%".format(breach_data[r,c]),
                     ha="center", va="center", fontsize=10,
                     color=txt_color, fontweight="bold")
ax_heat.set_title("SLA breach rate by market x shipping mode (First Class excluded)",
                  fontsize=12, fontweight="bold", color=DARK, pad=10)
plt.colorbar(im, ax=ax_heat, label="Breach rate %", shrink=0.8)

# Line: breach by profit quartile
ax_line = fig1.add_subplot(gs[2, 2])
quartiles   = ["Q1\n(Low)", "Q2", "Q3", "Q4\n(High)"]
breach_vals = [57.08, 57.20, 57.25, 57.59]
ax_line.plot(quartiles, breach_vals, marker="o", color=ORANGE,
             linewidth=2.5, markersize=8, markerfacecolor=RED)
for x, y in zip(quartiles, breach_vals):
    ax_line.annotate("{:.1f}%".format(y), (x, y), textcoords="offset points",
                     xytext=(0, 10), ha="center", fontsize=9, color=DARK)
ax_line.set_ylim(55, 60)
ax_line.set_ylabel("SLA breach rate (%)", fontsize=10)
ax_line.set_title("Breach rate nearly flat\nregardless of order value",
                  fontsize=11, fontweight="bold", color=DARK)
ax_line.set_facecolor(LIGHT_BG)
spine_clean(ax_line)

# Bar: profit at risk by market
ax_bar = fig1.add_subplot(gs[3, :])
markets_bar = ["Europe", "LATAM", "Pacific Asia", "USCA", "Africa"]
profit_risk = [685242, 658721, 501986, 330621, 147746]
bars = ax_bar.barh(markets_bar, profit_risk, color=RED, edgecolor="white", height=0.5)
for bar, val in zip(bars, profit_risk):
    ax_bar.text(val + 8000, bar.get_y() + bar.get_height()/2,
                "${:,.0f}".format(val), va="center", fontsize=10, color=DARK)
ax_bar.set_xlabel("Profit at risk ($)", fontsize=10)
ax_bar.set_title("Profit exposure concentrates in the largest markets",
                 fontsize=12, fontweight="bold", color=DARK, pad=10)
ax_bar.set_facecolor(LIGHT_BG)
spine_clean(ax_bar)
ax_bar.invert_yaxis()

fig1.savefig("/sessions/eloquent-nice-lovelace/mnt/Supply chain/output_exec_summary.png",
             dpi=150, bbox_inches="tight")
plt.close(fig1)
print("Page 1 done")


# ============================================================
# PAGE 2 -- CHAPTER DEEP DIVES
# ============================================================
fig2 = plt.figure(figsize=(18, 22), facecolor=LIGHT_BG)
fig2.suptitle("Supply Chain Risk Analysis -- Chapter Deep Dives",
              fontsize=22, fontweight="bold", color=DARK, y=0.99)

gs2 = gridspec.GridSpec(3, 2, figure=fig2, hspace=0.55, wspace=0.35,
                        top=0.95, bottom=0.04, left=0.07, right=0.97)

# Ch1a: avg delay by quartile
ax1a = fig2.add_subplot(gs2[0, 0])
delays = [0.56, 0.56, 0.57, 0.57]
bars1a = ax1a.bar(quartiles, delays, color=NEUTRAL, edgecolor="white", width=0.5)
bars1a[-1].set_color(RED)
ax1a.set_ylim(0.50, 0.60)
ax1a.set_ylabel("Avg delay (days)", fontsize=10)
ax1a.set_title("Ch1 -- Avg delay by profit quartile\n(nearly flat across all tiers)",
               fontsize=11, fontweight="bold", color=DARK)
for bar, val in zip(bars1a, delays):
    ax1a.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 0.001,
              "{}".format(val), ha="center", fontsize=10, color=DARK)
ax1a.set_facecolor(LIGHT_BG)
spine_clean(ax1a)

# Ch1b: profit at risk by tier
ax1b = fig2.add_subplot(gs2[0, 1])
tiers = ["Q1\n(Highest)", "Q2", "Q3", "Q4\n(Lowest)"]
risk  = [2770884, 812341, 534221, 198432]
clrs  = [RED, ORANGE, NEUTRAL, NEUTRAL]
bars1b = ax1b.bar(tiers, risk, color=clrs, edgecolor="white", width=0.5)
ax1b.set_ylabel("Profit at risk ($)", fontsize=10)
ax1b.set_title("Ch1 -- Profit at risk by tier\n($2.77M concentrated in Q1 breached orders)",
               fontsize=11, fontweight="bold", color=DARK)
for bar, val in zip(bars1b, risk):
    ax1b.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 15000,
              "${:.2f}M".format(val/1e6), ha="center", fontsize=10, color=DARK)
ax1b.set_facecolor(LIGHT_BG)
spine_clean(ax1b)

# Ch2a: volume vs profit share
ax2a = fig2.add_subplot(gs2[1, 0])
mkt_labels = ["Africa", "USCA", "Pacific\nAsia", "LATAM", "Europe"]
vol_pct  = [6.43, 14.29, 22.86, 28.58, 27.84]
prof_pct = [6.35, 14.23, 21.62, 28.32, 29.48]
x = np.arange(len(mkt_labels)); w = 0.35
ax2a.bar(x - w/2, vol_pct, w, label="Volume share", color=NEUTRAL, edgecolor="white")
ax2a.bar(x + w/2, prof_pct, w, label="Profit share", color=ORANGE, edgecolor="white")
for i, (v, p) in enumerate(zip(vol_pct, prof_pct)):
    if abs(v - p) > 0.5:
        sym = "^" if p > v else "v"
        clr = "#27AE60" if p > v else RED
        ax2a.text(x[i] + w/2, max(v,p) + 0.6, sym, ha="center", color=clr,
                  fontsize=12, fontweight="bold")
ax2a.set_xticks(x); ax2a.set_xticklabels(mkt_labels, fontsize=10)
ax2a.set_ylabel("Share (%)", fontsize=10)
ax2a.set_title("Ch2 -- Volume vs profit share\n(Europe over-converts; Pacific Asia under-converts)",
               fontsize=11, fontweight="bold", color=DARK)
ax2a.legend(fontsize=9)
ax2a.set_facecolor(LIGHT_BG)
spine_clean(ax2a)

# Ch2b: margin by market
ax2b = fig2.add_subplot(gs2[1, 1])
mkt_full = ["Africa", "USCA", "Pacific Asia", "LATAM", "Europe"]
margins  = [12.23, 12.39, 11.54, 12.16, 11.97]
clrs_m   = [NEUTRAL if m > 12 else RED for m in margins]
bars2b = ax2b.barh(mkt_full, margins, color=clrs_m, edgecolor="white", height=0.5)
avg_m = sum(margins)/len(margins)
ax2b.axvline(x=avg_m, color=DARK, linestyle="--", linewidth=1.5,
             label="Avg {:.1f}%".format(avg_m))
for bar, val in zip(bars2b, margins):
    ax2b.text(val + 0.05, bar.get_y() + bar.get_height()/2,
              "{}%".format(val), va="center", fontsize=10, color=DARK)
ax2b.set_xlabel("Profit margin (%)", fontsize=10)
ax2b.set_title("Ch2 -- Profit margin by market\n(Pacific Asia weakest at 11.54%)",
               fontsize=11, fontweight="bold", color=DARK)
ax2b.legend(fontsize=9)
ax2b.set_facecolor(LIGHT_BG)
spine_clean(ax2b)

# Ch3a: delay SD heatmap
ax3a = fig2.add_subplot(gs2[2, 0])
modes_ch3 = ["Same Day", "Second Class", "Standard Class"]
sd_data = np.array([
    [0.50, 1.41, 1.40],
    [0.50, 1.42, 1.41],
    [0.50, 1.39, 1.42],
    [0.50, 1.43, 1.42],
    [0.50, 1.42, 1.42],
])
im3 = ax3a.imshow(sd_data, cmap="OrRd", aspect="auto", vmin=0.4, vmax=1.5)
ax3a.set_xticks(range(3)); ax3a.set_xticklabels(modes_ch3, fontsize=10)
ax3a.set_yticks(range(5)); ax3a.set_yticklabels(markets, fontsize=10)
for r in range(5):
    for c in range(3):
        txt_c = "white" if sd_data[r,c] > 1.2 else DARK
        ax3a.text(c, r, "{:.2f}".format(sd_data[r,c]),
                  ha="center", va="center", fontsize=10,
                  color=txt_c, fontweight="bold")
ax3a.set_title("Ch3 -- Delay std dev by market x mode\n(Second Class & Standard Class most volatile)",
               fontsize=11, fontweight="bold", color=DARK)
plt.colorbar(im3, ax=ax3a, label="Delay SD (days)", shrink=0.8)

# Ch3b: Second Class breach by market
ax3b = fig2.add_subplot(gs2[2, 1])
sc_breach = [80.04, 79.55, 80.42, 78.94, 79.98]
sc_mkts   = ["Africa", "USCA", "Pacific\nAsia", "LATAM", "Europe"]
bars3b = ax3b.bar(sc_mkts, sc_breach, color=RED, edgecolor="white", width=0.5)
ax3b.axhline(y=57.3, color=NEUTRAL, linestyle="--", linewidth=1.5,
             label="Overall avg (57.3%)")
ax3b.set_ylim(50, 90)
ax3b.set_ylabel("Breach rate (%)", fontsize=10)
ax3b.set_title("Ch3 -- Second Class breach rate by market\n(~80% everywhere -- systemic, not geographic)",
               fontsize=11, fontweight="bold", color=DARK)
for bar, val in zip(bars3b, sc_breach):
    ax3b.text(bar.get_x() + bar.get_width()/2, val + 0.5,
              "{:.1f}%".format(val), ha="center", fontsize=10, color=DARK)
ax3b.legend(fontsize=9)
ax3b.set_facecolor(LIGHT_BG)
spine_clean(ax3b)

fig2.savefig("/sessions/eloquent-nice-lovelace/mnt/Supply chain/output_chapter_deepdives.png",
             dpi=150, bbox_inches="tight")
plt.close(fig2)
print("Page 2 done")


# ============================================================
# PAGE 3 -- RECOMMENDATIONS + IMPACT
# ============================================================
fig3 = plt.figure(figsize=(18, 14), facecolor=LIGHT_BG)
fig3.suptitle("Supply Chain Risk Analysis -- Recommendations & Impact",
              fontsize=22, fontweight="bold", color=DARK, y=0.99)

gs3 = gridspec.GridSpec(2, 1, figure=fig3, hspace=0.5,
                        top=0.93, bottom=0.06, left=0.06, right=0.97)

# Impact scenarios
ax_impact = fig3.add_subplot(gs3[0])
scenarios    = ["5% improvement", "10% improvement", "15% improvement", "25% improvement"]
profit_saved = [138600, 277200, 415800, 692700]
breach_red   = [2.01, 4.02, 6.03, 10.06]
x_sc = np.arange(len(scenarios))
ax_r = ax_impact.twinx()
b_imp = ax_impact.bar(x_sc - 0.15, profit_saved, 0.3, color=RED,
                      label="Profit protected ($)", edgecolor="white")
ax_r.plot(x_sc, breach_red, marker="D", color=ORANGE, linewidth=2.5,
          markersize=9, label="Breach concentration reduced (pp)")
ax_impact.set_xticks(x_sc); ax_impact.set_xticklabels(scenarios, fontsize=11)
ax_impact.set_ylabel("Profit protected ($)", fontsize=11, color=RED)
ax_r.set_ylabel("Breach share reduction (pp)", fontsize=11, color=ORANGE)
ax_impact.set_title("What a 5-25% SLA improvement unlocks",
                    fontsize=13, fontweight="bold", color=DARK, pad=12)
for bar, val in zip(b_imp, profit_saved):
    ax_impact.text(bar.get_x() + bar.get_width()/2, val + 5000,
                   "${:,.0f}".format(val), ha="center", fontsize=10, color=DARK)
for xi, yi in zip(x_sc, breach_red):
    ax_r.annotate("{:.1f}pp".format(yi), (xi, yi), textcoords="offset points",
                  xytext=(8, 5), fontsize=9, color=ORANGE)
h1, l1 = ax_impact.get_legend_handles_labels()
h2, l2 = ax_r.get_legend_handles_labels()
ax_impact.legend(h1+h2, l1+l2, fontsize=10, loc="upper left")
ax_impact.set_facecolor(LIGHT_BG)
spine_clean(ax_impact)

# Recommendations table
ax_rec = fig3.add_subplot(gs3[1])
ax_rec.axis("off")
col_labels = ["#", "Finding", "Recommendation", "Priority", "Metric to watch"]
rows = [
    ["1", "$2.77M profit at risk in Q1\nbreached orders",
     "Flag Q1-profit orders for SLA-protected routing;\nroute via Same Day or guaranteed Standard",
     "HIGH", "Q1 breach rate target <50%"],
    ["2", "Second Class ~80% breach\nacross all markets",
     "Audit Second Class SLA promise;\nredefine or renegotiate delivery window",
     "HIGH", "Second Class breach rate"],
    ["3", "Pacific Asia margin gap\n(-1.24pp vs volume share)",
     "Review Pacific Asia fulfillment cost structure;\nprioritize higher-margin product mix",
     "MEDIUM", "Margin delta vs volume share"],
    ["4", "40.67% of breaches in top 5 lanes",
     "Root cause top 5 lanes;\ntest dedicated carrier for worst lanes",
     "HIGH", "Top-5-lane breach concentration"],
    ["5", "Standard Class delay SD 1.42d",
     "Set internal lead-time buffers;\nuse predictive lateness flags",
     "MEDIUM", "P90 lateness vs SLA threshold"],
]
col_widths = [0.04, 0.22, 0.32, 0.10, 0.22]
table = ax_rec.table(cellText=rows, colLabels=col_labels,
                     cellLoc="left", loc="center", colWidths=col_widths)
table.auto_set_font_size(False)
table.set_fontsize(9.5)
table.scale(1, 3.2)
for (r, c), cell in table.get_celld().items():
    cell.set_edgecolor("#BDC3C7")
    if r == 0:
        cell.set_facecolor(DARK)
        cell.set_text_props(color="white", fontweight="bold")
    elif c == 3:
        prio = rows[r-1][3]
        cell.set_facecolor(RED if prio == "HIGH" else ORANGE)
        cell.set_text_props(color="white", fontweight="bold")
    else:
        cell.set_facecolor(CARD_BG if r % 2 == 0 else SUBTLE)
ax_rec.set_title("Prioritized Recommendations",
                 fontsize=13, fontweight="bold", color=DARK, pad=12)

fig3.savefig("/sessions/eloquent-nice-lovelace/mnt/Supply chain/output_recommendations.png",
             dpi=150, bbox_inches="tight")
plt.close(fig3)
print("Page 3 done")
print("All outputs saved.")
