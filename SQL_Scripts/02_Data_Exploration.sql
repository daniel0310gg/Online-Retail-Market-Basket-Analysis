/*============================================================================
   SCRIPT 02: DATA EXPLORATION 
   
   Purpose: Understand the data structure, patterns, and quality
   Note: Data was imported as VARCHAR, so we use TRY_CAST for conversions
============================================================================*/

USE OnlineRetailDB;
GO

PRINT '====================================================================';
PRINT 'STARTING DATA EXPLORATION';
PRINT '====================================================================';
GO

-- =============================================================================
-- PART A: DATASET OVERVIEW
-- =============================================================================

PRINT 'Part A: Dataset Overview';
GO

-- A1: Overall Statistics 
SELECT 
    'Overall Statistics' AS Metric_Category,
    COUNT(*) AS Total_Transactions,
    COUNT(DISTINCT InvoiceNo) AS Unique_Invoices,
    COUNT(DISTINCT StockCode) AS Unique_Products,
    COUNT(DISTINCT CASE WHEN CustomerID IS NOT NULL AND CustomerID <> '' THEN CustomerID END) AS Unique_Customers,
    COUNT(DISTINCT Country) AS Unique_Countries,
    MIN(TRY_CAST(InvoiceDate AS DATETIME)) AS First_Transaction_Date,
    MAX(TRY_CAST(InvoiceDate AS DATETIME)) AS Last_Transaction_Date,
    DATEDIFF(DAY, MIN(TRY_CAST(InvoiceDate AS DATETIME)), MAX(TRY_CAST(InvoiceDate AS DATETIME))) AS Days_Of_Data
FROM staging.OnlineRetail_Raw;
GO

-- A2: Transaction Volume Over Time
SELECT 
    YEAR(TRY_CAST(InvoiceDate AS DATETIME)) AS Year,
    MONTH(TRY_CAST(InvoiceDate AS DATETIME)) AS Month,
    DATENAME(MONTH, TRY_CAST(InvoiceDate AS DATETIME)) AS Month_Name,
    COUNT(*) AS Transaction_Count,
    COUNT(DISTINCT InvoiceNo) AS Order_Count,
    COUNT(DISTINCT CustomerID) AS Customer_Count,
    SUM(TRY_CAST(Quantity AS INT) * TRY_CAST(UnitPrice AS DECIMAL(10,3))) AS Total_Revenue_Sterling
FROM staging.OnlineRetail_Raw
WHERE TRY_CAST(Quantity AS INT) > 0 
  AND TRY_CAST(UnitPrice AS DECIMAL(10,3)) > 0
  AND TRY_CAST(InvoiceDate AS DATETIME) IS NOT NULL
GROUP BY YEAR(TRY_CAST(InvoiceDate AS DATETIME)), 
         MONTH(TRY_CAST(InvoiceDate AS DATETIME)), 
         DATENAME(MONTH, TRY_CAST(InvoiceDate AS DATETIME))
ORDER BY Year, Month;
GO

-- =============================================================================
-- PART B: DATA QUALITY ANALYSIS
-- =============================================================================

PRINT 'Part B: Data Quality Analysis';
GO

-- B1: Missing Values Analysis
SELECT 
    'Missing Values' AS Analysis_Type,
    COUNT(*) AS Total_Rows,
    SUM(CASE WHEN Description IS NULL OR Description = '' THEN 1 ELSE 0 END) AS Missing_Description,
    CAST(SUM(CASE WHEN Description IS NULL OR Description = '' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) AS Pct_Missing_Description,
    SUM(CASE WHEN CustomerID IS NULL OR CustomerID = '' THEN 1 ELSE 0 END) AS Missing_CustomerID,
    CAST(SUM(CASE WHEN CustomerID IS NULL OR CustomerID = '' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) AS Pct_Missing_CustomerID
FROM staging.OnlineRetail_Raw;
GO

-- B2: Cancellations and Returns
SELECT 
    'Cancellations & Returns' AS Analysis_Type,
    SUM(CASE WHEN LEFT(InvoiceNo, 1) = 'C' THEN 1 ELSE 0 END) AS Cancellation_Count,
    CAST(SUM(CASE WHEN LEFT(InvoiceNo, 1) = 'C' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) AS Pct_Cancellations,
    SUM(CASE WHEN TRY_CAST(Quantity AS INT) < 0 THEN 1 ELSE 0 END) AS Negative_Quantity_Count,
    CAST(SUM(CASE WHEN TRY_CAST(Quantity AS INT) < 0 THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) AS Pct_Returns
FROM staging.OnlineRetail_Raw;
GO

-- B3: Invalid Stock Codes (Test/System Records)
SELECT 
    StockCode,
    COUNT(*) AS Occurrence_Count,
    SUM(TRY_CAST(Quantity AS INT)) AS Total_Quantity,
    SUM(TRY_CAST(Quantity AS INT) * TRY_CAST(UnitPrice AS DECIMAL(10,3))) AS Total_Value
FROM staging.OnlineRetail_Raw
WHERE StockCode IN ('POST', 'D', 'M', 'BANK CHARGES', 'CRUK', 'DOT', 'PADS', 'C2')
   OR StockCode LIKE '%ADJUST%'
   OR StockCode LIKE '%TEST%'
GROUP BY StockCode
ORDER BY Occurrence_Count DESC;
GO

-- B4: Price Anomalies
SELECT 
    'Price Anomalies' AS Analysis_Type,
    MIN(TRY_CAST(UnitPrice AS DECIMAL(10,3))) AS Min_Price,
    MAX(TRY_CAST(UnitPrice AS DECIMAL(10,3))) AS Max_Price,
    AVG(TRY_CAST(UnitPrice AS DECIMAL(10,3))) AS Avg_Price,
    SUM(CASE WHEN TRY_CAST(UnitPrice AS DECIMAL(10,3)) = 0 THEN 1 ELSE 0 END) AS Zero_Price_Count,
    SUM(CASE WHEN TRY_CAST(UnitPrice AS DECIMAL(10,3)) < 0 THEN 1 ELSE 0 END) AS Negative_Price_Count
FROM staging.OnlineRetail_Raw;
GO

-- B5: Data Type Validation
SELECT 
    'Data Type Issues' AS Analysis_Type,
    SUM(CASE WHEN TRY_CAST(Quantity AS INT) IS NULL AND Quantity IS NOT NULL THEN 1 ELSE 0 END) AS Invalid_Quantity,
    SUM(CASE WHEN TRY_CAST(UnitPrice AS DECIMAL(10,3)) IS NULL AND UnitPrice IS NOT NULL THEN 1 ELSE 0 END) AS Invalid_Price,
    SUM(CASE WHEN TRY_CAST(InvoiceDate AS DATETIME) IS NULL AND InvoiceDate IS NOT NULL THEN 1 ELSE 0 END) AS Invalid_Date,
    SUM(CASE WHEN TRY_CAST(CustomerID AS INT) IS NULL AND CustomerID IS NOT NULL AND CustomerID <> '' THEN 1 ELSE 0 END) AS Invalid_CustomerID
FROM staging.OnlineRetail_Raw;
GO

PRINT '====================================================================';
PRINT 'DATA EXPLORATION COMPLETE!';
PRINT '====================================================================';
PRINT 'Key Findings to Note:';
PRINT '- Review data type conversion issues';
PRINT '- Identify data quality problems';
PRINT '- Note cancellations and returns';
PRINT '';
PRINT 'Next Step: Run Script 03 - Data Cleaning';
PRINT '- Script 03 will convert VARCHAR to proper types';
PRINT '- Script 03 will filter out invalid records';
PRINT '====================================================================';
GO