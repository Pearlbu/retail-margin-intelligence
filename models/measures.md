# DAX measure reference

33 measures, organised in 7 display folders inside the `MEASURES` container table.
Fact table referenced as `'Sales'` (`synthetic_sales_data_400k`).

---

## 01 Sales

### Net Revenue
```dax
SUM('Sales'[Sales_Amount])
```
Revenue after discounts. Base measure of the model. **$28,514,051,718.71**

### Gross Revenue
```dax
SUMX('Sales', 'Sales'[Quantity_Sold] * 'Sales'[Unit_Price])
```
Revenue before discounts. **$33,541,730,655.93**

### Transactions
```dax
COUNTROWS('Sales')
```
**400,000**

### Units Sold
```dax
SUM('Sales'[Quantity_Sold])
```
**10,192,507**

### Average Order Value
```dax
DIVIDE([Net Revenue], [Transactions])
```
**$71,285.13**

---

## 02 Profitability

### Cost of Goods
```dax
SUMX('Sales', 'Sales'[Quantity_Sold] * 'Sales'[Unit_Cost])
```
**$25,796,903,608.76**

### Gross Margin
```dax
[Net Revenue] - [Cost of Goods]
```
**$2,717,148,109.95**

### Margin %
```dax
DIVIDE([Gross Margin], [Net Revenue])
```
**9.5%**

### Discount Given
```dax
[Gross Revenue] - [Net Revenue]
```
Money surrendered in discounts. **$5,027,678,937.22**

### Avg Discount %
```dax
AVERAGE('Sales'[Discount])
```
**15.0%**

---

## 03 Alerts

### Below-Cost Transactions
```dax
IF(
    NOT ISBLANK([Transactions]),
    COALESCE(
        COUNTROWS(
            FILTER('Sales', 'Sales'[Sales_Amount] < 'Sales'[Quantity_Sold] * 'Sales'[Unit_Cost])
        ),
        0
    )
)
```
Returns 0 rather than BLANK so bands with no below-cost sales still render on the chart. **104,539**

### Below-Cost %
```dax
DIVIDE([Below-Cost Transactions], [Transactions])
```
**26.1%**

### Margin Destroyed
```dax
IF(
    NOT ISBLANK([Transactions]),
    COALESCE(
        SUMX(
            FILTER('Sales', 'Sales'[Sales_Amount] < 'Sales'[Quantity_Sold] * 'Sales'[Unit_Cost]),
            'Sales'[Sales_Amount] - 'Sales'[Quantity_Sold] * 'Sales'[Unit_Cost]
        ),
        0
    )
)
```
**−$528,810,996.29**

### Margin Recoverable
```dax
-[Margin Destroyed]
```
Theoretical ceiling, assuming below-cost sales are eliminated without losing profitable ones. **+$528,810,996.29**

---

## 04 Time Intelligence

### Revenue YTD
```dax
TOTALYTD([Net Revenue], 'Calendar'[Date])
```

### Margin YTD
```dax
TOTALYTD([Gross Margin], 'Calendar'[Date])
```

### MoM Growth %
```dax
VAR _prev = CALCULATE([Net Revenue], DATEADD('Calendar'[Date], -1, MONTH))
RETURN IF(NOT ISBLANK(_prev), DIVIDE([Net Revenue] - _prev, _prev))
```

### Revenue 3M Moving Avg
```dax
VAR _window = DATESINPERIOD('Calendar'[Date], MAX('Calendar'[Date]), -3, MONTH)
RETURN
DIVIDE(
    CALCULATE([Net Revenue], _window),
    CALCULATE(DISTINCTCOUNT('Calendar'[YearMonthIndex]), _window)
)
```
Divides by the actual month count in the window rather than assuming 3, so the first two months of the series stay correct.

---

## 05 Visual Support

### Cascade Value
```dax
SWITCH(
    SELECTEDVALUE('Margin Cascade'[Step]),
    "Gross Revenue", [Gross Revenue],
    "Discounts",     -[Discount Given],
    "Cost of Goods", -[Cost of Goods]
)
```
Drives the waterfall via a disconnected table. Power BI appends the Total bar, which resolves to Gross Margin.

### Margin Colour
```dax
IF([Gross Margin] < 0, "#EF4444", "#10B981")
```

### Delta Colour
```dax
IF([Simulated Margin Delta] < 0, "#EF4444", "#10B981")
```

### Cap Marker
```dax
MAX('Discount Parameter'[Max Discount])
```
Plain decimal format (no percent) for use as an X-axis constant line.

---

## 06 Simulator

### Selected Discount Cap
```dax
MAX('Discount Parameter'[Max Discount])
```
Uses `MAX` rather than `SELECTEDVALUE` so a range-style slicer works: the effective cap is the upper bound of the selection.

### Simulated Revenue
```dax
VAR _cap = [Selected Discount Cap]
RETURN
IF(
    _cap >= 0.30,
    [Net Revenue],
    SUMX('Sales',
        ROUND('Sales'[Quantity_Sold] * 'Sales'[Unit_Price] * (1 - MIN('Sales'[Discount], _cap)), 2)
    )
)
```
Row-level `ROUND` mirrors the source data. The short-circuit at 30% returns the exact actual figure so the delta reads zero at the unfiltered position.

### Simulated Margin
```dax
[Simulated Revenue] - [Cost of Goods]
```

### Simulated Margin Delta
```dax
[Simulated Margin] - [Gross Margin]
```

### Simulated Margin %
```dax
DIVIDE([Simulated Margin], [Simulated Revenue])
```

### Simulated Below-Cost Trans
```dax
VAR _cap = [Selected Discount Cap]
RETURN
IF(
    NOT ISBLANK([Transactions]),
    COALESCE(
        COUNTROWS(
            FILTER('Sales',
                'Sales'[Unit_Price] * (1 - MIN('Sales'[Discount], _cap)) < 'Sales'[Unit_Cost]
            )
        ),
        0
    )
)
```

---

## 07 Titles

Text measures bound to visual titles through conditional formatting (fx → Field value). All use an explicit `en-US` locale so number formatting is independent of the model culture.

### Title Cascade
```dax
"Value cascade: from " & FORMAT([Gross Revenue]/1e9, "#,0.0", "en-US")
    & " bn gross to " & FORMAT([Gross Margin]/1e9, "#,0.0", "en-US")
    & " bn margin (" & FORMAT([Margin %], "0.0%", "en-US") & ")"
```

### Title Bands
```dax
"Margin by discount band — " & FORMAT([Below-Cost Transactions], "#,0", "en-US")
    & " below-cost sales destroy " & FORMAT([Margin Recoverable]/1e6, "#,0", "en-US") & " M"
```

### Title Simulator
```dax
"Simulated policy: discount cap at " & FORMAT([Selected Discount Cap], "0%", "en-US")
    & " → margin " & FORMAT([Simulated Margin %], "0.0%", "en-US")
    & " (" & FORMAT(DIVIDE([Simulated Margin Delta], [Gross Margin]), "+0.0%;-0.0%", "en-US")
    & " vs. current)"
```

### Title Trend
```dax
"Monthly revenue and 3-month moving average — total "
    & FORMAT([Net Revenue]/1e9, "#,0.0", "en-US") & " bn (stable, ±5%)"
```

### Title Curve
```dax
"Policy curve: margin by discount cap — a " & FORMAT([Selected Discount Cap], "0%", "en-US")
    & " cap yields " & FORMAT([Simulated Margin]/1e9, "#,0.0", "en-US") & " bn"
```

---

## Calculated columns

### Sales[Discount Band]
```dax
SWITCH(TRUE(),
    'Sales'[Discount] = 0,     "0%",
    'Sales'[Discount] <= 0.05, "01-05%",
    'Sales'[Discount] <= 0.10, "06-10%",
    'Sales'[Discount] <= 0.15, "11-15%",
    'Sales'[Discount] <= 0.20, "16-20%",
    'Sales'[Discount] <= 0.25, "21-25%",
    "26-30%"
)
```
Sorted by a hidden `Discount Band Order` column (0–6).

### Sales[Margin Status]
```dax
IF(
    'Sales'[Sales_Amount] < 'Sales'[Quantity_Sold] * 'Sales'[Unit_Cost],
    "Below cost",
    "Profitable"
)
```
295,461 profitable / 104,539 below cost.

---

## Calculated tables

### Calendar
```dax
ADDCOLUMNS(
    CALENDAR(DATE(2023,1,1), DATE(2024,12,31)),
    "Year",           YEAR([Date]),
    "MonthNo",        MONTH([Date]),
    "Month",          FORMAT([Date], "MMM", "en-US"),
    "YearMonth",      FORMAT([Date], "YYYY-MM"),
    "YearMonthIndex", YEAR([Date]) * 12 + MONTH([Date]),
    "QuarterNo",      QUARTER([Date]),
    "Quarter",        "Q" & QUARTER([Date]),
    "YearQuarter",    YEAR([Date]) & "-Q" & QUARTER([Date]),
    "WeekdayNo",      WEEKDAY([Date], 2),
    "Weekday",        FORMAT([Date], "ddd", "en-US")
)
```
731 rows. Marked as the model's date table.

### Margin Cascade
```dax
SELECTCOLUMNS(
    {(1, "Gross Revenue"), (2, "Discounts"), (3, "Cost of Goods")},
    "Order", [Value1],
    "Step",  [Value2]
)
```

### Discount Parameter
```dax
SELECTCOLUMNS(GENERATESERIES(0, 30, 1), "Max Discount", [Value] / 100)
```
Built from integers divided by 100 rather than `GENERATESERIES(0, 0.30, 0.01)`, which produces floating-point drift and breaks exact-value matching.
