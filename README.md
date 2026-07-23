# Retail Margin Intelligence

**A Power BI analysis of 400,000 retail transactions that found 26% of sales were being made below cost — and quantified the policy fix worth $560M in recovered margin.**

**[▶ Explore the live interactive dashboard](https://app.powerbi.com/view?r=eyJrIjoiNzQyMGQxYmEtNDQ1Yi00NjJhLWE2NmQtZDIxZDY5YWFkN2U5IiwidCI6IjBlMGNiMDYwLTA5YWQtNDlmNS1hMDA1LTY4YjliNDlhYTFmNiIsImMiOjR9)**

![Dashboard](docs/dashboard-overview.jpg)

---

## The short version

A retail catalogue with $28.5bn in revenue looked healthy: stable month over month, no seasonal collapse, no underperforming region. Only 9.5% of that revenue survived as gross margin.

The cause was not volume, mix, or sales performance. It was that the discount policy had never been reconciled with the pricing policy. Catalogue markup ranges from 1.1× to 1.5× — a gross margin of 9.1% to 33.3%. Discounts run up to 30%. With those two ranges, selling below cost is not an operational accident; it is arithmetically guaranteed.

**104,539 transactions (26.1%) were sold below cost, destroying $529M in margin.**

---

## Key findings

### Margin degrades monotonically with discount depth

| Discount band | Transactions | Revenue | Margin | Margin % | Below cost |
|---|---:|---:|---:|---:|---:|
| 0% | 6,747 | $570M | +$131M | 23.0% | 0 |
| 1–5% | 66,624 | $5,448M | +$1,130M | 20.7% | 0 |
| 6–10% | 66,927 | $5,149M | +$843M | 16.4% | 375 (0.6%) |
| 11–15% | 66,221 | $4,835M | +$562M | 11.6% | 8,148 (12.3%) |
| 16–20% | 66,573 | $4,560M | +$281M | 6.2% | 20,009 (30.1%) |
| 21–25% | 66,871 | $4,309M | +$7M | 0.2% | 33,250 (49.7%) |
| **26–30%** | **60,037** | **$3,644M** | **−$237M** | **−6.5%** | **42,757 (71.2%)** |

The 21–25% band is the exact break-even point. Above 25%, every incremental sale destroys margin. In the deepest band, 7 out of 10 transactions lose money.

### The value cascade

```
Gross revenue                      $33,542M
  − Discounts granted    (15.0%)   −$5,028M
= Net revenue                      $28,514M
  − Cost of goods                 −$25,797M
= Gross margin          ( 9.5%)     $2,717M
```

A 15% average discount consumes two thirds of a 22.5% average markup.

### Policy simulation

| Discount cap | Margin | Gain vs. current | Below-cost sales |
|---|---:|---:|---:|
| 30% (current) | $2,717M | — | 104,539 |
| 20% | $3,278M | **+$560M (+20.6%)** | 76,081 |
| 15% | $3,976M | +$1,259M (+46.3%) | 45,633 |
| 10% | $4,953M | +$2,236M (+82.3%) | 7,590 |
| 5% | $6,209M | +$3,492M (+128.5%) | 0 |

**The nuance that matters:** even a 10% cap leaves 7,590 sales below cost — the minimum-markup products whose 9.1% margin cannot absorb a 10% discount. The recommendation is therefore not a single cap but a rule:

> **Maximum discount = product margin % − 5 percentage points**

### The problem is structural, not local

Filtering by any dimension leaves the story unchanged:

| Filter | Margin % | Below-cost % |
|---|---:|---:|
| No filter | 9.53% | 26.13% |
| Category: Clothing | 9.53% | 26.22% |
| Region: East | 9.51% | 26.29% |
| Channel: Online | 9.53% | 26.09% |
| Customer: New | 9.53% | 26.23% |

No region, rep, category, or channel is the culprit. This is a pricing-policy failure that runs through the entire business, which is why the fix has to be a business rule rather than a commercial intervention.

---

## What I deliberately did *not* build

Before modelling anything, I tested whether region, sales rep, product category, channel, customer type, and seasonality carried any signal. They did not — dispersion across categories is under 1.2%, and all monthly variation is explained by the number of days in each month. `Product_ID` is a random integer that appears across all four categories with ~800 distinct prices, so no product dimension is possible.

A "sales by region" dashboard would have looked polished and said nothing. The absence of those pages is a finding, not an omission.

---

## Technical notes

### A locale bug that invalidated every figure

The source CSV uses period decimal separators (en-US). Loaded under a Spanish regional setting, Power Query read the period as a thousands separator and typed the columns as integers: `71951.51` became `7,195,151`.

Fixed by re-parsing the numeric columns with an explicit locale:

```m
#"Typed en-US" = Table.TransformColumnTypes(#"Base types", {
    {"Sale_Date",    type date},
    {"Sales_Amount", type number},
    {"Unit_Cost",    type number},
    {"Unit_Price",   type number},
    {"Discount",     type number}
}, "en-US")
```

Verified by confirming that `Sales_Amount = Quantity × Unit_Price × (1 − Discount)` holds across all 400,000 rows, with a maximum deviation of 0.01 from rounding.

Dividing by 100 would have been the tempting shortcut. It would also have been wrong by 10.4%, because some source values carry a single decimal place.

### Model architecture

Star schema, five tables:

| Table | Type | Purpose |
|---|---|---|
| `Sales` | Fact | 400,000 transactions + 2 calculated columns (discount band, margin status) |
| `Calendar` | Dimension | 731 days, marked as date table, 1→* to Sales |
| `MEASURES` | Container | 33 measures in 7 display folders |
| `Margin Cascade` | Disconnected | 3 steps driving the waterfall visual |
| `Discount Parameter` | Disconnected | 31 values (0–30%) driving the simulator |

### DAX patterns worth noting

**Disconnected-table simulator with `MAX()` instead of the native What-If parameter**, so the range slicer works correctly — the effective cap is always the upper bound of the selection:

```dax
Selected Discount Cap = MAX('Discount Parameter'[Max Discount])

Simulated Revenue =
VAR _cap = [Selected Discount Cap]
RETURN
IF(
    _cap >= 0.30,
    [Net Revenue],
    SUMX('Sales', ROUND('Sales'[Quantity_Sold] * 'Sales'[Unit_Price] * (1 - MIN('Sales'[Discount], _cap)), 2))
)
```

The `IF` short-circuit at 30% guarantees the simulation returns the exact actual figure at the unfiltered position, so the delta reads a clean zero rather than a rounding artefact.

**Blank suppression so empty categories still render.** `COUNTROWS(FILTER(...))` returns BLANK when nothing matches, which silently drops the 0% and 1–5% bands from the chart:

```dax
Below-Cost Transactions =
IF(
    NOT ISBLANK([Transactions]),
    COALESCE(COUNTROWS(FILTER('Sales', 'Sales'[Sales_Amount] < 'Sales'[Quantity_Sold] * 'Sales'[Unit_Cost])), 0)
)
```

**Dynamic titles with explicit locale**, so number formatting stays consistent regardless of the model culture:

```dax
Title Bands =
"Margin by discount band — "
    & FORMAT([Below-Cost Transactions], "#,0", "en-US")
    & " below-cost sales destroy "
    & FORMAT([Margin Recoverable]/1e6, "#,0", "en-US") & " M"
```

---

## Repository contents

```
├── README.md
├── docs/
│   └── dashboard-overview.jpg   # single-page consolidated dashboard
├── models/
│   ├── measures.md              # full DAX reference, 33 measures
│   └── power-query.pq            # source transformation
├── theme/
│   └── retail-margin-intelligence.json
└── Retail Data & Analysis.pbix
```

## Running it

1. Open the `.pbix` in Power BI Desktop (June 2024 or later).
2. The dataset is embedded; no refresh is required to explore.
3. To reload from source, point the Power Query source step at your own copy of the CSV.

---

## Methodology and limitations

**The dataset is synthetic and publicly available** (400,000 rows). It is used here to demonstrate the full workflow — source correction, modelling, analysis, and visual narrative — not to describe a real business.

**The simulator assumes constant volume.** The dataset contains no demand elasticity, so capping discounts is modelled as raising realised price without losing sales. The figures are a theoretical ceiling useful for sizing the opportunity and prioritising, not a revenue forecast. This is stated on the dashboard itself.

---

## Contact

**Piero Manuel Mejía Berrios** — Business Intelligence & Data Analytics 

[LinkedIn](https://www.linkedin.com/in/pieromejia19) · [Upwork](https://www.upwork.com/freelancers/~018ac605e4eec7ba2d)
