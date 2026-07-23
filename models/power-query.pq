// ============================================================================
// Source transformation — synthetic_sales_data_400k
// ============================================================================
//
// PROBLEM THIS SOLVES
//
// The source CSV uses en-US number formatting (period as decimal separator).
// Loaded under a Spanish regional setting, Power Query interpreted the period
// as a thousands separator and typed the columns as Int64:
//
//     71951.51  →  7,195,151      (off by a factor of 100)
//     49.9      →  499            (off by a factor of 10)
//
// Because some values carry one decimal place and others two, dividing the
// result by 100 does NOT recover the original data — it produces a total
// 10.4% below the true figure. The columns must be re-parsed from source
// with an explicit locale.
//
// VALIDATION
//
// After this transformation, the identity
//     Sales_Amount = Quantity_Sold × Unit_Price × (1 − Discount)
// holds across all 400,000 rows, with a maximum deviation of 0.01 (rounding).
//
// ============================================================================

let
    Source = Csv.Document(
        File.Contents("...\synthetic_sales_data_400k.csv"),
        [Delimiter = ",", Columns = 14, Encoding = 1252, QuoteStyle = QuoteStyle.None]
    ),

    PromotedHeaders = Table.PromoteHeaders(Source, [PromoteAllScalars = true]),

    // Locale-independent columns: integers and text
    BaseTypes = Table.TransformColumnTypes(PromotedHeaders, {
        {"Product_ID",           Int64.Type},
        {"Sales_Rep",            type text},
        {"Region",               type text},
        {"Quantity_Sold",        Int64.Type},
        {"Product_Category",     type text},
        {"Customer_Type",        type text},
        {"Payment_Method",       type text},
        {"Sales_Channel",        type text},
        {"Region_and_Sales_Rep", type text}
    }),

    // Locale-dependent columns: parsed explicitly as en-US
    TypedEnUS = Table.TransformColumnTypes(BaseTypes, {
        {"Sale_Date",    type date},
        {"Sales_Amount", type number},
        {"Unit_Cost",    type number},
        {"Unit_Price",   type number},
        {"Discount",     type number}
    }, "en-US")

in
    TypedEnUS

// ============================================================================
// POST-LOAD CHECKS
// ============================================================================
//
//   Sales_Amount   min      49.85   max  361,098.04
//   Unit_Price     min      67.49   max    7,493.40
//   Discount       min       0.00   max        0.30
//   Errors         0% across all columns
//   Net revenue    28,514,051,718.71
//
// If Sales_Amount tops out in the tens of millions or Discount reaches 30
// instead of 0.30, the locale parameter has not been applied.
//
// ============================================================================
