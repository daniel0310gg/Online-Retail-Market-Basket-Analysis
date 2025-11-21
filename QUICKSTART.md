# ⚡ Quick Start Guide

Get up and running with the Market Basket Analysis project in 30 minutes!

---

## 📋 Prerequisites Checklist

Before you begin, ensure you have:

- [ ] **MS SQL Server 2016+** installed (or SQL Server Express - FREE)
- [ ] **SSMS** (SQL Server Management Studio) installed
- [ ] **2GB+ free disk space**
- [ ] **Admin rights** to create databases
- [ ] **Downloaded** Online_Retail.xlsx from [UCI Repository](https://archive.ics.uci.edu/ml/machine-learning-databases/00352/Online%20Retail.xlsx)

---

## 🚀 Installation Steps

### Step 1: Clone the Repository

```bash
git clone https://github.com/daniel0310gg/Online-Retail-Market-Basket-Analysis.git
cd Online-Retail-Market-Basket-Analysis
```

### Step 2: Download the Dataset

**Option A: Direct Download**
```bash
# Windows PowerShell
Invoke-WebRequest -Uri "https://archive.ics.uci.edu/ml/machine-learning-databases/00352/Online%20Retail.xlsx" -OutFile "Online_Retail.xlsx"

# Linux/Mac
wget "https://archive.ics.uci.edu/ml/machine-learning-databases/00352/Online%20Retail.xlsx"
```

**Option B: Manual Download**
1. Visit: https://archive.ics.uci.edu/ml/datasets/online+retail
2. Click "Data Folder"
3. Download `Online Retail.xlsx`
4. Save to a known location (e.g., `C:\Data\Online_Retail.xlsx`)

### Step 3: Convert Excel to CSV (Optional but Recommended)

**Using Python:**
```python
import pandas as pd

# Read Excel file
df = pd.read_excel('Online_Retail.xlsx')

# Save as CSV
df.to_csv('online_retail.csv', index=False, encoding='utf-8')

print(f"Converted {len(df)} rows to CSV")
```

**Using Excel:**
1. Open `Online_Retail.xlsx` in Excel
2. File → Save As → CSV UTF-8 (Comma delimited) (*.csv)
3. Save as `online_retail.csv`

---

## 🗄️ Database Setup

### Step 4: Open SQL Server Management Studio (SSMS)

1. Launch SSMS
2. Connect to your SQL Server instance
3. Server name: `localhost` or `(local)` or your server name
4. Authentication: Windows Authentication (or SQL Server Authentication)

### Step 5: Run Database Setup Script

```sql
-- Open: SQL_Scripts/01_Database_Setup.sql
-- Execute the entire script (F5)
-- ⏱️ Takes ~30 seconds
```

**What it does:**
- Creates `OnlineRetailDB` database
- Creates `staging` and `prod` schemas
- Creates tables:
  - `staging.OnlineRetail_Raw`
  - `prod.Transactions`
  - `prod.Products`
  - `prod.Customers`
  - `prod.ProductPairs`
- Creates indexes for performance

### Step 6: Import Data

**Method 1: BULK INSERT (if you have CSV)**

1. Edit line in `01_Database_Setup.sql`:
   ```sql
   -- Change this path to where your CSV is located:
   FROM 'C:\Data\online_retail.csv'
   ```

2. Execute the BULK INSERT section

**Method 2: SSMS Import Wizard (RECOMMENDED for Excel)**

1. Right-click on `OnlineRetailDB` database
2. Tasks → Import Data
3. Data Source: **Microsoft Excel**
4. Browse to `Online_Retail.xlsx`
5. Destination: **SQL Server Native Client**
6. Database: `OnlineRetailDB`
7. Source: `Sheet1$`
8. Destination: `staging.OnlineRetail_Raw`
9. Click **Next** → **Finish**
10. Wait for import to complete (~2 minutes)

### Step 7: Verify Data Import

```sql
-- Run this query to verify data loaded correctly
SELECT 
    'Data Import Complete' AS Status,
    COUNT(*) AS TotalRows,
    COUNT(DISTINCT InvoiceNo) AS UniqueInvoices,
    COUNT(DISTINCT StockCode) AS UniqueProducts
FROM staging.OnlineRetail_Raw;

-- Expected result:
-- TotalRows: 541,909
-- UniqueInvoices: ~25,900
-- UniqueProducts: ~4,070
```

---

## 📊 Run Analysis Scripts

### Step 8: Execute Scripts in Order

Run each script in SSMS (Open → Execute with F5):

#### Script 02: Data Exploration (⏱️ 2 minutes)
```sql
-- Open: SQL_Scripts/02_Data_Exploration.sql
-- Execute (F5)
```
**Output:** Data quality report, missing values, anomalies

#### Script 03: Data Cleaning (⏱️ 3 minutes)
```sql
-- Open: SQL_Scripts/03_Data_Cleaning.sql
-- Execute (F5)
```
**Output:** 
- Cleaned data in `prod.Transactions`
- ~397,000 valid transactions
- Product and customer dimensions created

#### Script 04: Market Basket Analysis (⏱️ 10 minutes)
```sql
-- Open: SQL_Scripts/04_Market_Basket_Analysis.sql
-- Execute (F5)
```
**Output:**
- Association rules calculated
- Support, Confidence, Lift metrics
- `prod.ProductPairs` table populated

#### Script 05: Product Pairs Deep Dive (⏱️ 5 minutes)
```sql
-- Open: SQL_Scripts/05_Product_Pairs_Deep_Dive.sql
-- Execute (F5)
```
**Output:**
- Hub products identified
- Seasonal patterns
- Country-specific insights
- 3-item bundle recommendations

#### Script 06: Business Insights (⏱️ 2 minutes)
```sql
-- Open: SQL_Scripts/06_Business_Insights.sql
-- Execute (F5)
```
**Output:**
- Top 5 recommended bundles
- Cross-sell strategies
- Revenue impact analysis
- A/B testing recommendations

---

## 🎉 Verify Results

### Check Your Analysis Results

```sql
-- View top product associations
SELECT TOP 10
    ProductA_Desc AS Product_A,
    ProductB_Desc AS Product_B,
    Lift AS Association_Strength,
    CAST(Confidence_AtoB * 100 AS DECIMAL(5,1)) AS Cross_Sell_Rate_Pct,
    OrdersWithBoth AS Co_Occurrences
FROM prod.ProductPairs
ORDER BY Lift DESC;
```

**Expected Output:**
- Product pairs with Lift > 3
- Confidence values between 20-60%
- Co-occurrences >= 10 orders

### Sample Results
```
Product_A                    | Product_B                  | Lift | Cross_Sell | Co_Occur
-----------------------------|----------------------------|------|------------|----------
ALARM CLOCK BAKELIKE PINK    | ALARM CLOCK BAKELIKE RED   | 8.2  | 45.3%      | 156
PINK REGENCY TEACUP          | GREEN REGENCY TEACUP       | 7.8  | 41.2%      | 203
SET OF 3 CAKE TINS PANTRY    | SPACEBOY LUNCH BOX         | 6.5  | 38.7%      | 89
```

---

## 🎯 Next Steps

### 1. Explore the Analysis

```sql
-- Top products by revenue
SELECT TOP 20 
    StockCode,
    Description,
    TotalQuantitySold,
    CAST(TotalRevenue_USD AS DECIMAL(12,2)) AS Revenue_USD
FROM prod.Products
ORDER BY TotalRevenue_USD DESC;

-- Basket size distribution
SELECT 
    BasketSize,
    COUNT(*) AS OrderCount,
    CAST(AVG(OrderValue) AS DECIMAL(10,2)) AS Avg_Order_Value_USD
FROM (
    SELECT 
        InvoiceNo,
        COUNT(DISTINCT StockCode) AS BasketSize,
        SUM(LineTotal_USD) AS OrderValue
    FROM prod.vw_ValidTransactions
    GROUP BY InvoiceNo
) AS Baskets
GROUP BY BasketSize
ORDER BY BasketSize;
```

### 2. Generate Your Own Insights

Try answering these questions:
- Which products have the most associations?
- Do patterns vary by country?
- What are peak shopping hours?
- Which bundles have highest revenue potential?

### 3. Build Dashboards (Optional)

If you have Power BI:
1. Connect to `OnlineRetailDB`
2. Import tables:
   - `prod.vw_ValidTransactions`
   - `prod.ProductPairs`
   - `prod.Products`
   - `prod.Customers`
3. Follow guidance in `Power_BI/Setup_Guide.md` (coming soon)

---

## 🐛 Troubleshooting

### Issue: "Cannot bulk load because the file could not be opened"
**Solution:** 
- Check file path is correct
- Ensure SQL Server has read permissions
- Use SSMS Import Wizard instead

### Issue: "TRY_CAST returns NULL"
**Solution:**
- Data imported as VARCHAR (expected)
- Script 03 handles type conversions
- Continue with data cleaning script

### Issue: "Execution time too long"
**Solution:**
- Normal for large datasets
- Script 04 (Market Basket Analysis) takes 10-15 minutes
- Ensure adequate server resources
- Check index creation in Script 01

### Issue: "Not enough valid transactions"
**Solution:**
```sql
-- Check how many valid transactions you have
SELECT 
    COUNT(*) AS Total,
    SUM(CASE WHEN IsValid = 1 THEN 1 ELSE 0 END) AS Valid
FROM prod.Transactions;

-- Should see ~397,000 valid transactions
-- If much lower, check data import step
```

### Issue: "Missing CustomerID error"
**Solution:**
- Expected: ~25% of transactions lack CustomerID
- These are filtered but counted
- Product-level analysis still works
- Customer-level analysis uses remaining 75%

---

## 📚 Additional Resources

### Learning SQL for Analysis
- [W3Schools SQL Tutorial](https://www.w3schools.com/sql/)
- [Mode Analytics SQL Tutorial](https://mode.com/sql-tutorial/)
- [SQL Server Documentation](https://docs.microsoft.com/en-us/sql/sql-server/)

### Market Basket Analysis Theory
- **Book:** "Introduction to Data Mining" by Tan, Steinbach, Kumar
- **Paper:** "Mining Association Rules" by Agrawal & Srikant
- **Video:** [StatQuest: Association Rules](https://www.youtube.com/watch?v=WGlMlS_Yydk)

### SQL Server Management
- [SSMS Download](https://docs.microsoft.com/en-us/sql/ssms/download-sql-server-management-studio-ssms)
- [SQL Server Express](https://www.microsoft.com/en-us/sql-server/sql-server-downloads) (FREE)

---

## ✅ Success Checklist

By the end of this guide, you should have:

- [x] Database `OnlineRetailDB` created
- [x] Data imported (~542K rows)
- [x] Data cleaned (~397K valid transactions)
- [x] Association rules calculated
- [x] Product pairs analyzed
- [x] Business recommendations generated
- [x] Queries returning expected results

---

## 💬 Need Help?

- **Documentation:** See `/Documentation` folder
- **Issues:** Open a GitHub Issue
- **Questions:** Check the [README.md](../README.md)

---

## 🎊 Congratulations!

You've successfully completed the Market Basket Analysis setup!

**What you've accomplished:**
✅ Analyzed 540K+ transactions  
✅ Identified product associations  
✅ Calculated Lift, Support, Confidence  
✅ Generated actionable bundle recommendations  
✅ Created a professional portfolio project  

**Next:** Share your results, build dashboards, or extend the analysis!

---

*Happy Analyzing! 📊*