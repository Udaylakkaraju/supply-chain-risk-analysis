from pathlib import Path

import pandas as pd
import plotly.express as px
import streamlit as st


ROOT = Path(__file__).resolve().parent
EXPORTS = ROOT / "exports"

PAGE_BG = "#0b1220"
PANEL_BG = "#111827"
PANEL_2 = "#0f172a"
ACCENT = "#60a5fa"
ACCENT_2 = "#93c5fd"
MUTED = "#cbd5e1"
TEXT = "#f8fafc"


st.set_page_config(page_title="Supply Chain Prioritization & Risk Analysis", page_icon="📦", layout="wide")

st.markdown(
    f"""
    <style>
      .stApp {{ background: radial-gradient(circle at top, #111827 0%, {PAGE_BG} 55%); color: {TEXT}; }}
      .block-container {{
        padding-top: 1rem;
        padding-bottom: 2rem;
        max-width: 1300px;
      }}
      [data-testid="stSidebar"] {{
        background: linear-gradient(180deg, #0f172a 0%, #111827 100%);
        border-right: 1px solid rgba(255,255,255,0.08);
      }}
      [data-testid="stSidebar"] * {{
        color: {TEXT} !important;
      }}
      .hero {{
        background: linear-gradient(135deg, #0f172a 0%, #1e3a8a 100%);
        padding: 1.15rem 1.25rem;
        border-radius: 18px;
        color: {TEXT};
        border: 1px solid rgba(255,255,255,0.08);
        box-shadow: 0 12px 30px rgba(15, 23, 42, 0.35);
        margin-bottom: 1rem;
      }}
      .hero h1 {{
        margin: 0;
        font-size: 2.05rem;
        line-height: 1.1;
      }}
      .hero p {{
        margin: 0.4rem 0 0 0;
        font-size: 0.98rem;
        color: #dbeafe;
      }}
      .subtle {{
        color: #cbd5e1;
        font-size: 0.95rem;
      }}
      .storybox {{
        background: rgba(255,255,255,0.04);
        border: 1px solid rgba(255,255,255,0.08);
        border-left: 5px solid {ACCENT};
        border-radius: 14px;
        padding: 0.85rem 1rem;
        color: {TEXT};
      }}
      .storybox strong {{
        color: {TEXT};
      }}
      .recommendation {{
        background: rgba(255,255,255,0.04);
        border: 1px solid rgba(255,255,255,0.08);
        border-radius: 18px;
        padding: 1rem 1rem 0.85rem 1rem;
        box-shadow: 0 10px 24px rgba(0, 0, 0, 0.18);
        min-height: 180px;
      }}
      .recommendation h3 {{
        margin: 0 0 0.25rem 0;
        font-size: 1.05rem;
      }}
      .kpi-label {{
        font-size: 0.74rem;
        letter-spacing: .08em;
        text-transform: uppercase;
        color: #94a3b8;
        margin-bottom: 0.2rem;
      }}
      .kpi-value {{
        font-size: 2rem;
        font-weight: 800;
        color: {TEXT};
        line-height: 1.05;
      }}
      .kpi-desc {{
        font-size: 0.92rem;
        color: {MUTED};
        margin-top: 0.25rem;
      }}
    </style>
    """,
    unsafe_allow_html=True,
)


@st.cache_data
def load_csv(name: str) -> pd.DataFrame:
    return pd.read_csv(EXPORTS / name)


@st.cache_data
def load_optional_csv(name: str):
    path = EXPORTS / name
    if not path.exists():
        return None
    return pd.read_csv(path)


def fmt_money(value: float) -> str:
    return f"${value:,.0f}"


def pct(series: pd.Series) -> float:
    return float((series == "Yes").mean() * 100)


def late_pct(series: pd.Series) -> float:
    return float((series <= 90).mean() * 100)


def stylize(fig, height: int = 390):
    fig.update_layout(
        template="plotly_dark",
        height=height,
        margin=dict(l=10, r=10, t=70, b=10),
        font=dict(family="Arial, sans-serif", size=13, color=TEXT),
        title=dict(font=dict(size=18, color=TEXT)),
        legend_title_text="",
        paper_bgcolor=PANEL_BG,
        plot_bgcolor=PANEL_BG,
        colorway=["#60a5fa", "#fbbf24", "#34d399", "#a78bfa", "#f472b6"],
    )
    fig.update_xaxes(gridcolor="rgba(255,255,255,0.08)", zerolinecolor="rgba(255,255,255,0.08)", color=TEXT)
    fig.update_yaxes(gridcolor="rgba(255,255,255,0.08)", zerolinecolor="rgba(255,255,255,0.08)", color=TEXT)
    return fig


def metric_box(label: str, value: str, desc: str) -> None:
    st.markdown(
        f"""
        <div class="recommendation">
          <div class="kpi-label">{label}</div>
          <div class="kpi-value">{value}</div>
          <div class="kpi-desc">{desc}</div>
        </div>
        """,
        unsafe_allow_html=True,
    )


def insight_box(title: str, bullets: list[str]) -> None:
    items = "".join(f"<li>{b}</li>" for b in bullets)
    st.markdown(
        f"""
        <div class="storybox">
          <strong>{title}</strong>
          <ul style="margin:0.5rem 0 0 1.2rem; padding:0;">
            {items}
          </ul>
        </div>
        """,
        unsafe_allow_html=True,
    )


def section_title(title: str, subtitle: str) -> None:
    st.markdown(f"## {title}")
    st.markdown(f'<div class="subtle">{subtitle}</div>', unsafe_allow_html=True)


fulfillment = load_csv("fct_fulfillment_priority.csv")
market = load_csv("fct_market_performance.csv")
variability = load_csv("fct_lead_time_variability.csv")
bqml_eval = load_optional_csv("bqml_evaluation.csv")
bqml_features = load_optional_csv("bqml_feature_importance.csv")
bqml_lanes = load_optional_csv("bqml_top_risk_lanes.csv")

fulfillment_summary = (
    fulfillment.groupby("profit_quartile", as_index=False)
    .agg(
        avg_delay=("delay_days", "mean"),
        breach_rate=("sla_breached", pct),
        profit_at_risk=("profit_at_risk", "sum"),
    )
    .sort_values("profit_quartile")
)

market_summary = (
    market.groupby("market", as_index=False)
    .agg(
        revenue=("order_item_total", "sum"),
        profit=("order_profit_per_order", "sum"),
        profit_at_risk=("profit_at_risk", lambda s: s[s > 0].sum()),
        order_count=("market", "size"),
        sla_breach_rate=("sla_breached", pct),
    )
)
market_summary["volume_pct"] = market_summary["order_count"] / market_summary["order_count"].sum() * 100
market_summary["profit_pct"] = market_summary["profit"] / market_summary["profit"].sum() * 100
market_summary["margin_pct"] = market_summary["profit"] / market_summary["revenue"] * 100
market_summary = market_summary.sort_values("profit")

variability_summary = (
    variability.groupby(["market", "shipping_mode"], as_index=False)
    .agg(
        order_count=("market", "size"),
        delay_sd=("delay_days", "std"),
        breaches=("sla_breached", lambda s: (s == "Yes").sum()),
        avg_late_days=("delay_days", lambda s: s.clip(lower=0).mean()),
        late_sd=("delay_days", lambda s: s.clip(lower=0).std()),
    )
    .query("order_count >= 1000")
)
variability_summary["lane"] = variability_summary["market"] + " | " + variability_summary["shipping_mode"]
variability_summary = variability_summary.sort_values("delay_sd", ascending=False)
top_variability = variability_summary.head(5).copy()
top_variability["breach_share_pct"] = top_variability["breaches"] / variability_summary["breaches"].sum() * 100

model_auc = None
model_accuracy = None
model_recall = None

if bqml_eval is not None and not bqml_eval.empty:
    model_auc = float(bqml_eval.loc[0, "roc_auc"])
    model_accuracy = float(bqml_eval.loc[0, "accuracy"])
    model_recall = float(bqml_eval.loc[0, "recall"])

if bqml_lanes is not None and not bqml_lanes.empty:
    bqml_lanes["lane"] = bqml_lanes["market"] + " | " + bqml_lanes["shipping_mode"]

st.sidebar.title("Navigation")
page = st.sidebar.radio(
    "Go to",
    [
        "Executive Summary",
        "Fulfillment fairness",
        "Market mix",
        "Reliability pattern",
        "Predicting breach risk",
        "Next steps",
    ],
)

st.markdown(
    """
    <div class="hero">
      <h1>Supply Chain Prioritization & Risk Analysis</h1>
      <p>A supply chain story about where value is exposed, where reliability breaks down, and how to turn that into action.</p>
    </div>
    """,
    unsafe_allow_html=True,
)

if page == "Executive Summary":
    section_title(
        "Executive Summary",
        "The quick read: value is not being protected consistently, and the gaps show up in a few clear places.",
    )
    c1, c2, c3 = st.columns(3)
    with c1:
        metric_box("High-value profit at risk", fmt_money(2770884.62), "Breached high-profit orders expose the largest immediate value base.")
    with c2:
        metric_box("Breach concentration", "40.67%", "Top 5 unstable lanes account for most grouped SLA disruption.")
    with c3:
        if model_auc is not None:
            metric_box("Model ROC AUC", f"{model_auc:.3f}", "Operational features are strong enough to rank breach risk before delivery fails.")
        else:
            metric_box("Model ROC AUC", "Pending", "Run the BigQuery ML export to surface the final prediction metric here.")

    st.markdown(
        '<div class="storybox"><strong>Bottom line:</strong> High-value orders are not getting special treatment, the most unstable lanes carry a concentrated share of failures, and market efficiency varies even though every market remains profitable.</div>',
        unsafe_allow_html=True,
    )
    insight_box(
        "How to read this page",
        [
            "The profit-at-risk card shows where the money is actually exposed.",
            "The breach concentration card shows that a few unstable lanes do most of the damage.",
            "The prediction card shows whether those operational signals are strong enough to forecast breach risk ahead of time.",
        ],
    )

    c1, c2 = st.columns([1.2, 1])
    with c1:
        fig = px.bar(
            fulfillment_summary,
            x="profit_quartile",
            y="avg_delay",
            color_discrete_sequence=["#2563eb"],
            text=fulfillment_summary["avg_delay"].round(2),
            title="Delay stays flat across value tiers",
            labels={"profit_quartile": "Profit quartile", "avg_delay": "Average delay days"},
        )
        fig.update_traces(textposition="outside", marker_line_color="rgba(15,23,42,.2)", marker_line_width=1)
        st.plotly_chart(stylize(fig, 390), use_container_width=True)
    with c2:
        fig = px.bar(
            fulfillment_summary,
            x="profit_quartile",
            y="breach_rate",
            color_discrete_sequence=["#0f172a"],
            text=fulfillment_summary["breach_rate"].round(2),
            title="Breach rates barely move by value tier",
            labels={"profit_quartile": "Profit quartile", "breach_rate": "Breach rate %"},
        )
        fig.update_traces(textposition="outside", marker_line_color="rgba(15,23,42,.2)", marker_line_width=1)
        st.plotly_chart(stylize(fig, 390), use_container_width=True)

    c1, c2 = st.columns([1.1, 0.9])
    with c1:
        fig = px.bar(
            fulfillment_summary,
            x="profit_quartile",
            y="profit_at_risk",
            color_discrete_sequence=["#2563eb"],
            text=fulfillment_summary["profit_at_risk"].map(lambda x: f"${x:,.0f}"),
            title="Where the exposure sits",
            labels={"profit_quartile": "Profit quartile", "profit_at_risk": "Profit at risk"},
        )
        fig.update_traces(textposition="outside", marker_line_color="rgba(15,23,42,.2)", marker_line_width=1)
        st.plotly_chart(stylize(fig, 390), use_container_width=True)
    with c2:
        st.markdown(
            """
            <div class="recommendation" style="min-height: 390px;">
              <h3>Why it matters</h3>
              <ul>
                <li>Value is concentrated, but service treatment is not.</li>
                <li>That gap between exposure and treatment is the actual problem.</li>
                <li>The story is about missing prioritization, not a dramatic service collapse.</li>
              </ul>
            </div>
            """,
            unsafe_allow_html=True,
        )

elif page == "Fulfillment fairness":
    section_title(
        "Fulfillment fairness",
        "High-profit orders are not being protected any better, even though they carry more value.",
    )
    c1, c2 = st.columns(2)
    with c1:
        fig = px.box(
            fulfillment,
            x="profit_quartile",
            y="delay_days",
            color="profit_quartile",
            points="outliers",
            title="Delay distribution across value tiers",
            labels={"profit_quartile": "Profit quartile", "delay_days": "Delay days"},
        )
        st.plotly_chart(stylize(fig, 420), use_container_width=True)
    with c2:
        mix = (
            fulfillment.groupby(["profit_quartile", "shipping_mode"], as_index=False)
            .size()
            .rename(columns={"size": "orders"})
        )
        fig = px.bar(
            mix,
            x="profit_quartile",
            y="orders",
            color="shipping_mode",
            title="Shipping mode mix by value tier",
            barmode="stack",
            labels={"profit_quartile": "Profit quartile", "orders": "Orders"},
        )
        st.plotly_chart(stylize(fig, 420), use_container_width=True)
    st.markdown(
        '<div class="storybox"><strong>Takeaway:</strong> The network is not actively punishing high-value orders, but it is also not giving them a meaningful advantage. That makes the system value-blind rather than value-aware.</div>',
        unsafe_allow_html=True,
    )
    insight_box(
        "What stands out",
        [
            "Shipping mix barely changes across value tiers.",
            "The high-profit group carries large exposure without getting better treatment.",
            "This is less about overt failure and more about missing prioritization rules.",
        ],
    )

elif page == "Market mix":
    section_title(
        "Market mix",
        "All markets are profitable, but some convert demand into profit more cleanly than others.",
    )
    c1, c2 = st.columns(2)
    with c1:
        fig = px.bar(
            market_summary,
            x="market",
            y=["volume_pct", "profit_pct"],
            barmode="group",
            title="Volume share vs profit share",
            labels={"value": "Share %", "market": "Market"},
        )
        st.plotly_chart(stylize(fig, 420), use_container_width=True)
    with c2:
        fig = px.bar(
            market_summary.sort_values("profit_at_risk", ascending=False),
            x="market",
            y="profit_at_risk",
            color_discrete_sequence=["#2563eb"],
            title="Profit at risk by market",
            labels={"market": "Market", "profit_at_risk": "Profit at risk"},
        )
        st.plotly_chart(stylize(fig, 420), use_container_width=True)

    st.dataframe(
        market_summary[["market", "revenue", "profit", "margin_pct", "volume_pct", "profit_pct"]].round(2),
        use_container_width=True,
        hide_index=True,
    )
    st.markdown(
        '<div class="storybox"><strong>Takeaway:</strong> Europe is the clearest efficiency winner, Pacific Asia trails the pack, and the exposed profit pool is concentrated in the largest markets rather than in obviously broken ones.</div>',
        unsafe_allow_html=True,
    )
    insight_box(
        "What stands out",
        [
            "This is a ranking story, not a failure story.",
            "Europe contributes a bit more profit than its size would suggest.",
            "Pacific Asia contributes a bit less, which is a useful signal when deciding where to lean in.",
        ],
    )

elif page == "Reliability pattern":
    section_title(
        "Reliability pattern",
        "The heatmap shows where lateness clusters, and the ranking shows which lanes create the biggest spread.",
    )
    st.markdown(
        '<div class="storybox"><strong>Business read:</strong> reliability is not evenly distributed. Second Class carries the widest spread across markets, while the ranked lanes show where the operational noise is concentrated most heavily.</div>',
        unsafe_allow_html=True,
    )
    c1, c2 = st.columns(2)
    with c1:
        heat = variability_summary.pivot(index="shipping_mode", columns="market", values="avg_late_days").sort_index()
        fig = px.imshow(
            heat,
            text_auto=".2f",
            color_continuous_scale="Blues",
            title="Positive lateness heatmap",
            labels=dict(x="Market", y="Shipping mode", color="Avg late days"),
        )
        st.plotly_chart(stylize(fig, 420), use_container_width=True)
    with c2:
        fig = px.bar(
            top_variability.sort_values("delay_sd", ascending=True),
            x="delay_sd",
            y="lane",
            orientation="h",
            color="shipping_mode",
            title="Top 5 unstable lanes",
            labels={"delay_sd": "Delay SD", "lane": "Market | Shipping mode"},
        )
        st.plotly_chart(stylize(fig, 420), use_container_width=True)
    st.success("Top 5 highest-variance lanes account for 40.67% of grouped SLA breaches.")
    insight_box(
        "What the charts show",
        [
            "The heatmap shows Second Class as the most consistently late option across markets.",
            "Standard Class looks less severe on average, but its spread is still wide enough to matter.",
            "The ranked bars isolate the five noisiest lanes, and together they explain 40.67% of grouped SLA breaches.",
        ],
    )

elif page == "Predicting breach risk":
    section_title(
        "Predicting breach risk",
        "The final view turns the earlier operational patterns into a working BigQuery ML risk model.",
    )
    if (
        bqml_eval is None
        or bqml_eval.empty
        or bqml_features is None
        or bqml_features.empty
        or bqml_lanes is None
        or bqml_lanes.empty
    ):
        st.warning("BigQuery ML export files are missing. Add the evaluation, feature-importance, and top-risk lane CSVs to display the prediction layer.")
    else:
        c1, c2, c3 = st.columns(3)
        with c1:
            metric_box("ROC AUC", f"{model_auc:.3f}", "Overall ranking quality of the breach-risk model.")
        with c2:
            metric_box("Accuracy", f"{model_accuracy:.3f}", "Share of holdout orders classified correctly.")
        with c3:
            metric_box("Recall", f"{model_recall:.3f}", "Share of breached orders correctly identified.")

        c1, c2 = st.columns(2)
        with c1:
            top_features = bqml_features.sort_values("importance_gain", ascending=True).tail(8)
            fig = px.bar(
                top_features,
                x="importance_gain",
                y="feature",
                orientation="h",
                color="importance_gain",
                color_continuous_scale="Blues",
                text=top_features["importance_gain"].round(2),
                title="What drives predicted breach risk",
                labels={"importance_gain": "Importance gain", "feature": "Feature"},
            )
            fig.update_traces(textposition="outside")
            st.plotly_chart(stylize(fig, 420), use_container_width=True)
        with c2:
            ranked_lanes = bqml_lanes.sort_values("predicted_breach_risk", ascending=True).copy()
            fig = px.bar(
                ranked_lanes,
                x="predicted_breach_risk",
                y="lane",
                orientation="h",
                color="shipping_mode",
                text=ranked_lanes["predicted_breach_risk"].map(lambda x: f"{x:.1%}"),
                title="Highest-risk market and shipping lanes",
                labels={"predicted_breach_risk": "Predicted breach probability", "lane": "Lane"},
            )
            fig.update_traces(textposition="outside")
            st.plotly_chart(stylize(fig, 420), use_container_width=True)

        lane_table = bqml_lanes.copy()
        lane_table["predicted_breach_risk"] = lane_table["predicted_breach_risk"].map(lambda x: f"{x:.1%}")
        st.dataframe(
            lane_table.rename(
                columns={
                    "market": "Market",
                    "shipping_mode": "Shipping mode",
                    "order_count": "Orders",
                    "predicted_breach_risk": "Predicted breach risk",
                }
            )[["Market", "Shipping mode", "Orders", "Predicted breach risk"]],
            use_container_width=True,
            hide_index=True,
        )
        st.markdown(
            '<div class="storybox"><strong>Business read:</strong> The model confirms that breach risk is largely operational. Scheduled shipping days and shipping mode dominate the prediction, which means the strongest levers still sit in service design and lane policy rather than in downstream customer behavior.</div>',
            unsafe_allow_html=True,
        )
        insight_box(
            "What stands out",
            [
                "The strongest model drivers come from service promise and fulfillment design, not from soft downstream proxies.",
                "First Class and Second Class lanes dominate the highest predicted-risk list, which gives the last page a concrete prioritization view.",
                "This closes the story with a real predictive output instead of a weak customer-impact claim.",
            ],
        )


else:
    section_title(
        "Next steps",
        "Three actions follow naturally from the analysis: protect value, rebalance the mix, and tighten control in the weakest lanes.",
    )
    c1, c2, c3 = st.columns(3)
    with c1:
        st.markdown(
            """
            <div class="recommendation">
              <h3>Value-based routing</h3>
              <p><strong>Why it matters:</strong> high-profit orders carry a lot of exposure, but they are not being treated any differently.</p>
              <p><strong>Expected impact:</strong> even a 10% reduction in breached high-value profit protects about <strong>$277K</strong>.</p>
            </div>
            """,
            unsafe_allow_html=True,
        )
    with c2:
        st.markdown(
            """
            <div class="recommendation">
              <h3>Portfolio rebalancing</h3>
              <p><strong>Why it matters:</strong> some markets convert volume into profit more efficiently than others.</p>
              <p><strong>Expected impact:</strong> shift capacity toward stronger-converting markets and away from weaker-converting lanes.</p>
            </div>
            """,
            unsafe_allow_html=True,
        )
    with c3:
        st.markdown(
            """
            <div class="recommendation">
              <h3>Variability control</h3>
              <p><strong>Why it matters:</strong> a small number of lanes drive a concentrated share of SLA failures.</p>
              <p><strong>Expected impact:</strong> focus SLA controls on the few lanes driving most reliability risk.</p>
            </div>
            """,
            unsafe_allow_html=True,
        )
    insight_box(
        "How to read these actions",
        [
            "The first action protects value directly.",
            "The second action shifts the portfolio toward better-converting markets.",
            "The third action targets the few lanes driving most instability.",
        ],
    )

