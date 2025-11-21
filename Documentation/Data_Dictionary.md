# 📚 Data Dictionary

## Online Retail Dataset - Field Definitions

| Variable Name | Type | Role | Description | Units | Missing Values |
|---------------|------|------|-------------|-------|----------------|
| **InvoiceNo** | Categorical | ID | A 6-digit integral number uniquely assigned to each transaction. If this code starts with letter 'c', it indicates a cancellation | - | No |
| **StockCode** | Categorical | ID | A 5-digit integral number uniquely assigned to each distinct product | - | No |
| **Description** | Categorical | Feature | Product name | - | Yes (~0.3%) |
| **Quantity** | Integer | Feature | The quantities of each product (item) per transaction | items | No |
| **InvoiceDate** | DateTime | Feature | The day and time when each transaction was generated | - | No |
| **UnitPrice** | Continuous | Feature | Product price per unit | Sterling (£) | No |
| **CustomerID** | Categorical | Feature | A 5-digit integral number uniquely assigned to each customer | - | Yes (~24.9%) |
| **Country** | Categorical | Feature | The name of the country where each customer resides | - | No |

---

## Calculated Fields (Production Schema)

### prod.Transactions Table

| Field Name | Type | Description | Formula/Logic |
|------------|------|-------------|---------------|
| **TransactionID** | INT | Auto-incrementing primary key | IDENTITY(1,1) |
| **UnitPrice_USD** | DECIMAL(10,3) | Price converted to US Dollars | UnitPrice_Sterling × 1.31 |
| **LineTotal_USD** | DECIMAL(12,2) | Total line item value | Quantity × UnitPrice_USD |
| **IsCancellation** | BIT | Is this invoice a cancellation? | 1 if InvoiceNo starts with 'C', else 0 |
| **IsReturn** | BIT | Is this a return (negative quantity)? | 1 if Quantity < 0, else 0 |
| **IsValid** | BIT | Is this a valid transaction? | See validation rules below |
| **Year** | INT | Transaction year | YEAR(InvoiceDate) |
| **Month** | INT | Transaction month (1-12) | MONTH(InvoiceDate) |
| **DayOfWeek** | VARCHAR(10) | Day name (Monday-Sunday) | DATENAME(WEEKDAY, InvoiceDate) |
| **Hour** | INT | Hour of day (0-23) | DATEPART(HOUR, InvoiceDate) |

### prod.ProductPairs Table (Market Basket Analysis Results)

| Field Name | Type | Description | Formula |
|------------|------|-------------|---------|
| **SupportA** | DECIMAL(10,6) | Support of Product A | Orders containing A / Total Orders |
| **SupportB** | DECIMAL(10,6) | Support of Product B | Orders containing B / Total Orders |
| **SupportAB** | DECIMAL(10,6) | Support of both A and B | Orders with both A & B / Total Orders |
| **Confidence_AtoB** | DECIMAL(10,6) | Confidence A→B | SupportAB / SupportA |
| **Confidence_BtoA** | DECIMAL(10,6) | Confidence B→A | SupportAB / SupportB |
| **Lift** | DECIMAL(10,4) | Association strength | SupportAB / (SupportA × SupportB) |
| **OrdersWithBoth** | INT | Number of orders containing both | COUNT(DISTINCT InvoiceNo) |

---

## Data Quality Rules

### Validation Criteria (IsValid = 1)
A transaction is considered valid if ALL of the following are true:
- ✅ InvoiceNo does NOT start with 'C' (not a cancellation)
- ✅ Quantity > 0 (not a return)
- ✅ UnitPrice > 0 (has a valid price)
- ✅ CustomerID is NOT NULL (has customer information)
- ✅ StockCode is NOT in the exclusion list (see below)

### Excluded StockCodes (Invalid Records)
The following stock codes are excluded as they represent system entries, not actual products:
- POST, D, M, C2 - Postage/Delivery charges
- BANK CHARGES - Banking fees
- CRUK, DOT, PADS - Special system codes
- Any code containing "ADJUST", "TEST", "SAMPLE"

---

## Data Cleaning Summary

| Category | Records | Percentage |
|----------|---------|------------|
| **Total Raw Records** | 541,909 | 100.0% |
| **Cancellations** | ~9,000 | ~1.7% |
| **Returns (Negative Qty)** | ~10,000 | ~1.8% |
| **Missing CustomerID** | ~135,000 | ~24.9% |
| **Invalid Prices** | ~1,500 | ~0.3% |
| **Test/System Records** | ~1,000 | ~0.2% |
| **Valid Transactions** | **~397,000** | **73.2%** |

---

## Business Metrics Definitions

### Market Basket Analysis Metrics

**Support(A,B)**
- Definition: The proportion of all orders that contain both Product A and Product B
- Range: 0 to 1 (or 0% to 100%)
- Interpretation: Higher support = more frequently purchased together
- Example: Support = 0.05 means 5% of all orders contain both items

**Confidence(A→B)**
- Definition: Among customers who bought Product A, what percentage also bought Product B?
- Range: 0 to 1 (or 0% to 100%)
- Interpretation: Measures the likelihood of cross-sell
- Example: Confidence = 0.60 means 60% of customers who bought A also bought B

**Lift(A,B)**
- Definition: How much more likely are A and B purchased together compared to if they were independent?
- Range: 0 to ∞ (practically 0 to ~20 for strong associations)
- Interpretation:
  - Lift > 1: Positive association (bought together more than expected)
  - Lift = 1: No association (independent purchases)
  - Lift < 1: Negative association (one discourages the other)
- Example: Lift = 3.5 means items are bought together 3.5x more often than by chance

### Key Business KPIs

**Average Order Value (AOV)**
```sql
SUM(LineTotal_USD) / COUNT(DISTINCT InvoiceNo)
```

**Basket Size**
```sql
COUNT(DISTINCT StockCode) per InvoiceNo
```

**Customer Lifetime Value (CLV)**
```sql
SUM(LineTotal_USD) per CustomerID
```

**Repeat Purchase Rate**
```sql
Customers with >1 order / Total Customers
```

---

## Exchange Rate

**Sterling to USD Conversion**
- Exchange Rate Used: **1 GBP = 1.31 USD**
- Period Covered: December 2010 - September 2011
- Note: This is the average exchange rate during the dataset period

---

## Date Range

**Dataset Coverage:**
- Start Date: December 1, 2010
- End Date: September 9, 2011
- Total Days: ~282 days
- Total Months: ~9 months

---

## Country Coverage

**Total Countries:** 38

**Top 10 Countries by Order Volume:**
1. United Kingdom (UK) - ~90% of orders
2. Germany
3. France
4. EIRE (Ireland)
5. Spain
6. Netherlands
7. Belgium
8. Switzerland
9. Portugal
10. Australia

---

## Product Categories

**Note:** This dataset does not include explicit product categories. Products are identified by:
- StockCode: Unique 5-digit product identifier
- Description: Free-text product name

**Sample Product Types:**
- Home decor items
- Gifts and novelties
- Party supplies
- Kitchen accessories
- Seasonal items
- Wholesale products

---

## Database Schema

```
OnlineRetailDB/
├── staging.OnlineRetail_Raw     -- Raw imported data (VARCHAR fields)
└── prod/
    ├── Transactions              -- Cleaned transaction fact table
    ├── Products                  -- Product dimension table
    ├── Customers                 -- Customer dimension table
    └── ProductPairs              -- Market basket analysis results
```

---

## Notes & Limitations

1. **Missing CustomerIDs**: ~25% of transactions lack customer identification
   - These are likely guest checkout or point-of-sale transactions
   - Excluded from customer-level analysis but included in product analysis

2. **Wholesale Customers**: Dataset includes both retail and wholesale transactions
   - Wholesale orders may have higher quantities
   - This affects average basket size calculations

3. **Currency**: Original prices are in British Pounds (GBP)
   - Converted to USD for analysis
   - Exchange rate is fixed for the entire period

4. **Time Zone**: All timestamps are in UTC/GMT
   - No adjustment for local time zones
   - Hour-of-day analysis assumes UK time

5. **Product Lifecycle**: Some products may be seasonal or discontinued
   - Not all products appear throughout the entire date range

---

*For detailed technical implementation, see SQL_Scripts/ directory*  
*For analysis methodology, see Documentation/Methodology.md*