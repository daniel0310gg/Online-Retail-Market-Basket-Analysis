/*============================================================================
   SCRIPT 03: DATA CLEANING & TRANSFORMATION (FIXED FOR VARCHAR IMPORT)
   
   Purpose: Clean raw data and populate production tables
   Author: Data Analytics Team
   
   Cleaning Steps:
   1. Convert VARCHAR to proper data types
   2. Remove cancellations (InvoiceNo starting with 'C')
   3. Remove returns (Quantity < 0)
   4. Remove invalid stock codes (POST, D, M, etc.)
   5. Remove records with missing CustomerID
   6. Remove zero/negative prices
   7. Convert prices to USD (1 GBP = 1.31 USD as of dataset period)
   8. Calculate derived fields
============================================================================*/

USE OnlineRetailDB;
GO

PRINT '====================================================================';
PRINT 'STARTING DATA CLEANING PROCESS';
PRINT '====================================================================';
GO

-- =============================================================================
-- PART A: DATA QUALITY REPORT (BEFORE CLEANING)
-- =============================================================================

PRINT 'Part A: Pre-Cleaning Data Quality Report';
GO

DECLARE @TotalRows INT;
SELECT @TotalRows = COUNT(*) FROM staging.OnlineRetail_Raw;

SELECT 
    'Before Cleaning' AS Status,
    @TotalRows AS Total_Rows,
    SUM(CASE WHEN LEFT(InvoiceNo, 1) = 'C' THEN 1 ELSE 0 END) AS Cancellations,
    SUM(CASE WHEN TRY_CAST(Quantity AS INT) < 0 THEN 1 ELSE 0 END) AS Returns,
    SUM(CASE WHEN TRY_CAST(Quantity AS INT) = 0 THEN 1 ELSE 0 END) AS Zero_Quantity,
    SUM(CASE WHEN TRY_CAST(UnitPrice AS DECIMAL(10,3)) <= 0 THEN 1 ELSE 0 END) AS Invalid_Price,
    SUM(CASE WHEN CustomerID IS NULL OR CustomerID = '' THEN 1 ELSE 0 END) AS Missing_Customer,
    SUM(CASE WHEN Description IS NULL OR Description = '' THEN 1 ELSE 0 END) AS Missing_Description,
    SUM(CASE WHEN StockCode IN ('POST', 'D', 'M', 'BANK CHARGES', 'DOT', 'CRUK', 'PADS', 'C2') THEN 1 ELSE 0 END) AS Invalid_StockCodes,
    SUM(CASE WHEN TRY_CAST(InvoiceDate AS DATETIME) IS NULL THEN 1 ELSE 0 END) AS Invalid_Dates
FROM staging.OnlineRetail_Raw;
GO

-- =============================================================================
-- PART B: CLEAN AND LOAD TRANSACTIONS TABLE
-- =============================================================================

PRINT 'Part B: Loading Clean Transactions...';
GO

-- Clear existing data
TRUNCATE TABLE prod.Transactions;
GO

-- Sterling to USD exchange rate (average rate during 2010-2011)
DECLARE @ExchangeRate DECIMAL(10,4) = 1.31;

-- Insert cleaned data with proper type conversions
INSERT INTO prod.Transactions (
    InvoiceNo,
    StockCode,
    Description,
    Quantity,
    InvoiceDate,
    UnitPrice_Sterling,
    UnitPrice_USD,
    LineTotal_USD,
    CustomerID,
    Country,
    IsCancellation,
    IsReturn,
    IsValid,
    Year,
    Month,
    DayOfWeek,
    Hour
)
SELECT 
    InvoiceNo,
    StockCode,
    UPPER(LTRIM(RTRIM(Description))) AS Description,
    TRY_CAST(Quantity AS INT) AS Quantity,
    TRY_CAST(InvoiceDate AS DATETIME) AS InvoiceDate,
    TRY_CAST(UnitPrice AS DECIMAL(10,3)) AS UnitPrice_Sterling,
    ROUND(TRY_CAST(UnitPrice AS DECIMAL(10,3)) * @ExchangeRate, 3) AS UnitPrice_USD,
    ROUND(TRY_CAST(Quantity AS INT) * TRY_CAST(UnitPrice AS DECIMAL(10,3)) * @ExchangeRate, 2) AS LineTotal_USD,
    TRY_CAST(CustomerID AS INT) AS CustomerID,
    Country,
    CASE WHEN LEFT(InvoiceNo, 1) = 'C' THEN 1 ELSE 0 END AS IsCancellation,
    CASE WHEN TRY_CAST(Quantity AS INT) < 0 THEN 1 ELSE 0 END AS IsReturn,
    -- IsValid flag: Valid if NOT (cancellation OR return OR invalid data)
    CASE 
        WHEN LEFT(InvoiceNo, 1) = 'C' THEN 0
        WHEN TRY_CAST(Quantity AS INT) IS NULL THEN 0
        WHEN TRY_CAST(Quantity AS INT) <= 0 THEN 0
        WHEN TRY_CAST(UnitPrice AS DECIMAL(10,3)) IS NULL THEN 0
        WHEN TRY_CAST(UnitPrice AS DECIMAL(10,3)) <= 0 THEN 0
        WHEN TRY_CAST(InvoiceDate AS DATETIME) IS NULL THEN 0
        WHEN CustomerID IS NULL OR CustomerID = '' THEN 0
        WHEN TRY_CAST(CustomerID AS INT) IS NULL THEN 0
        WHEN StockCode IN ('POST', 'D', 'M', 'BANK CHARGES', 'DOT', 'CRUK', 'PADS', 'C2', 'AMAZONFEE') THEN 0
        WHEN StockCode LIKE '%ADJUST%' THEN 0
        WHEN StockCode LIKE '%TEST%' THEN 0
        WHEN StockCode LIKE '%SAMPLE%' THEN 0
        ELSE 1
    END AS IsValid,
    YEAR(TRY_CAST(InvoiceDate AS DATETIME)) AS Year,
    MONTH(TRY_CAST(InvoiceDate AS DATETIME)) AS Month,
    DATENAME(WEEKDAY, TRY_CAST(InvoiceDate AS DATETIME)) AS DayOfWeek,
    DATEPART(HOUR, TRY_CAST(InvoiceDate AS DATETIME)) AS Hour
FROM staging.OnlineRetail_Raw
WHERE TRY_CAST(InvoiceDate AS DATETIME) IS NOT NULL;  -- Only import rows with valid dates

GO

-- Report on data cleaning results
DECLARE @LoadedRows INT, @ValidRows INT;
SELECT @LoadedRows = COUNT(*), @ValidRows = SUM(CASE WHEN IsValid = 1 THEN 1 ELSE 0 END)
FROM prod.Transactions;

PRINT 'Transactions Loaded: ' + CAST(@LoadedRows AS VARCHAR(20));
PRINT 'Valid Transactions: ' + CAST(@ValidRows AS VARCHAR(20));
PRINT 'Cleaning Rate: ' + CAST(CAST(@ValidRows * 100.0 / @LoadedRows AS DECIMAL(5,2)) AS VARCHAR(10)) + '%';
GO

-- =============================================================================
-- PART C: BUILD PRODUCTS DIMENSION
-- =============================================================================

PRINT 'Part C: Building Products Dimension...';
GO

-- Clear existing data
TRUNCATE TABLE prod.Products;
GO

-- Insert product data (only from valid transactions)
INSERT INTO prod.Products (
    StockCode,
    Description,
    FirstSeenDate,
    LastSeenDate,
    TotalQuantitySold,
    TotalRevenue_USD
)
SELECT 
    StockCode,
    MAX(Description) AS Description,
    MIN(InvoiceDate) AS FirstSeenDate,
    MAX(InvoiceDate) AS LastSeenDate,
    SUM(Quantity) AS TotalQuantitySold,
    SUM(LineTotal_USD) AS TotalRevenue_USD
FROM prod.Transactions
WHERE IsValid = 1
GROUP BY StockCode;

GO

PRINT 'Products Dimension Built: ' + CAST(@@ROWCOUNT AS VARCHAR(20)) + ' products';
GO

-- =============================================================================
-- PART D: BUILD CUSTOMERS DIMENSION
-- =============================================================================

PRINT 'Part D: Building Customers Dimension...';
GO

-- Clear existing data
TRUNCATE TABLE prod.Customers;
GO

-- Insert customer data (only from valid transactions)
INSERT INTO prod.Customers (
    CustomerID,
    Country,
    FirstPurchaseDate,
    LastPurchaseDate,
    TotalOrders,
    TotalRevenue_USD
)
SELECT 
    CustomerID,
    MAX(Country) AS Country,
    MIN(InvoiceDate) AS FirstPurchaseDate,
    MAX(InvoiceDate) AS LastPurchaseDate,
    COUNT(DISTINCT InvoiceNo) AS TotalOrders,
    SUM(LineTotal_USD) AS TotalRevenue_USD
FROM prod.Transactions
WHERE IsValid = 1
GROUP BY CustomerID;

GO

PRINT 'Customers Dimension Built: ' + CAST(@@ROWCOUNT AS VARCHAR(20)) + ' customers';
GO

-- =============================================================================
-- PART E: DATA QUALITY REPORT (AFTER CLEANING)
-- =============================================================================

PRINT 'Part E: Post-Cleaning Data Quality Report';
GO

SELECT 
    'After Cleaning' AS Status,
    COUNT(*) AS Total_Rows_Loaded,
    SUM(CASE WHEN IsValid = 1 THEN 1 ELSE 0 END) AS Valid_Transactions,
    COUNT(DISTINCT InvoiceNo) AS Unique_Invoices,
    COUNT(DISTINCT StockCode) AS Unique_Products,
    COUNT(DISTINCT CustomerID) AS Unique_Customers,
    COUNT(DISTINCT Country) AS Unique_Countries,
    MIN(InvoiceDate) AS First_Date,
    MAX(InvoiceDate) AS Last_Date,
    CAST(SUM(LineTotal_USD) AS DECIMAL(15,2)) AS Total_Revenue_USD
FROM prod.Transactions
WHERE IsValid = 1;
GO

-- =============================================================================
-- PART F: VALIDATION CHECKS
-- =============================================================================

PRINT 'Part F: Running Validation Checks...';
GO

-- F1: Check for duplicates
SELECT 
    'Duplicate Check' AS Check_Type,
    COUNT(*) AS Total_Rows,
    COUNT(DISTINCT CONCAT(InvoiceNo, StockCode, CAST(CustomerID AS VARCHAR))) AS Unique_Combinations,
    COUNT(*) - COUNT(DISTINCT CONCAT(InvoiceNo, StockCode, CAST(CustomerID AS VARCHAR))) AS Potential_Duplicates
FROM prod.Transactions
WHERE IsValid = 1;
GO

-- F2: Revenue validation
SELECT 
    'Revenue Validation' AS Check_Type,
    SUM(LineTotal_USD) AS Calculated_Revenue,
    SUM(Quantity * UnitPrice_USD) AS Recalculated_Revenue,
    ABS(SUM(LineTotal_USD) - SUM(Quantity * UnitPrice_USD)) AS Difference
FROM prod.Transactions
WHERE IsValid = 1;
GO

-- F3: Date range validation
SELECT 
    'Date Range Validation' AS Check_Type,
    MIN(InvoiceDate) AS Earliest_Transaction,
    MAX(InvoiceDate) AS Latest_Transaction,
    DATEDIFF(DAY, MIN(InvoiceDate), MAX(InvoiceDate)) AS Days_Covered,
    CASE 
        WHEN MIN(InvoiceDate) >= '2010-12-01' AND MAX(InvoiceDate) <= '2011-12-31' 
        THEN 'PASS' 
        ELSE 'CHECK' 
    END AS Validation_Status
FROM prod.Transactions
WHERE IsValid = 1;
GO

-- =============================================================================
-- PART G: SUMMARY STATISTICS
-- =============================================================================

PRINT 'Part G: Summary Statistics';
GO

-- G1: Transaction Summary
SELECT 
    'Valid Transactions Summary' AS Report_Type,
    COUNT(*) AS Total_Transactions,
    COUNT(DISTINCT InvoiceNo) AS Total_Orders,
    COUNT(DISTINCT StockCode) AS Total_Products,
    COUNT(DISTINCT CustomerID) AS Total_Customers,
    CAST(AVG(CAST(Quantity AS FLOAT)) AS DECIMAL(10,2)) AS Avg_Quantity_Per_Line,
    CAST(AVG(UnitPrice_USD) AS DECIMAL(10,2)) AS Avg_Unit_Price_USD,
    CAST(AVG(LineTotal_USD) AS DECIMAL(10,2)) AS Avg_Line_Total_USD,
    CAST(SUM(LineTotal_USD) AS DECIMAL(15,2)) AS Total_Revenue_USD
FROM prod.Transactions
WHERE IsValid = 1;
GO

-- G2: Order-Level Summary
WITH OrderSummary AS (
    SELECT 
        InvoiceNo,
        COUNT(*) AS Lines_Per_Order,
        COUNT(DISTINCT StockCode) AS Products_Per_Order,
        SUM(Quantity) AS Items_Per_Order,
        SUM(LineTotal_USD) AS Order_Value_USD
    FROM prod.Transactions
    WHERE IsValid = 1
    GROUP BY InvoiceNo
)
SELECT 
    'Order-Level Summary' AS Report_Type,
    COUNT(*) AS Total_Orders,
    CAST(AVG(CAST(Lines_Per_Order AS FLOAT)) AS DECIMAL(10,2)) AS Avg_Lines_Per_Order,
    CAST(AVG(CAST(Products_Per_Order AS FLOAT)) AS DECIMAL(10,2)) AS Avg_Products_Per_Order,
    CAST(AVG(CAST(Items_Per_Order AS FLOAT)) AS DECIMAL(10,2)) AS Avg_Items_Per_Order,
    CAST(AVG(Order_Value_USD) AS DECIMAL(10,2)) AS Avg_Order_Value_USD,
    CAST(MIN(Order_Value_USD) AS DECIMAL(10,2)) AS Min_Order_Value_USD,
    CAST(MAX(Order_Value_USD) AS DECIMAL(10,2)) AS Max_Order_Value_USD
FROM OrderSummary;
GO

-- G3: Top 10 Products After Cleaning
SELECT TOP 10
    p.StockCode,
    p.Description,
    p.TotalQuantitySold,
    CAST(p.TotalRevenue_USD AS DECIMAL(12,2)) AS Total_Revenue_USD,
    COUNT(DISTINCT t.InvoiceNo) AS Times_Ordered,
    COUNT(DISTINCT t.CustomerID) AS Unique_Customers
FROM prod.Products p
INNER JOIN prod.Transactions t ON p.StockCode = t.StockCode
WHERE t.IsValid = 1
GROUP BY p.StockCode, p.Description, p.TotalQuantitySold, p.TotalRevenue_USD
ORDER BY p.TotalRevenue_USD DESC;
GO

-- G4: Top 10 Customers After Cleaning
SELECT TOP 10
    CustomerID,
    Country,
    TotalOrders,
    CAST(TotalRevenue_USD AS DECIMAL(12,2)) AS Total_Revenue_USD,
    FirstPurchaseDate,
    LastPurchaseDate,
    DATEDIFF(DAY, FirstPurchaseDate, LastPurchaseDate) AS Days_Active,
    CAST(TotalRevenue_USD / TotalOrders AS DECIMAL(10,2)) AS Avg_Order_Value
FROM prod.Customers
ORDER BY TotalRevenue_USD DESC;
GO

-- =============================================================================
-- PART H: CREATE VIEWS FOR EASY QUERYING
-- =============================================================================

PRINT 'Part H: Creating Analytical Views...';
GO

-- H1: Valid Transactions View
IF OBJECT_ID('prod.vw_ValidTransactions', 'V') IS NOT NULL
    DROP VIEW prod.vw_ValidTransactions;
GO

CREATE VIEW prod.vw_ValidTransactions AS
SELECT 
    TransactionID,
    InvoiceNo,
    StockCode,
    Description,
    Quantity,
    InvoiceDate,
    UnitPrice_USD,
    LineTotal_USD,
    CustomerID,
    Country,
    Year,
    Month,
    DayOfWeek,
    Hour
FROM prod.Transactions
WHERE IsValid = 1;
GO

-- H2: Order Summary View
IF OBJECT_ID('prod.vw_OrderSummary', 'V') IS NOT NULL
    DROP VIEW prod.vw_OrderSummary;
GO

CREATE VIEW prod.vw_OrderSummary AS
SELECT 
    InvoiceNo,
    CustomerID,
    Country,
    InvoiceDate,
    Year,
    Month,
    COUNT(*) AS OrderLines,
    COUNT(DISTINCT StockCode) AS UniqueProducts,
    SUM(Quantity) AS TotalItems,
    SUM(LineTotal_USD) AS OrderValue_USD,
    MAX(InvoiceDate) AS OrderDateTime
FROM prod.vw_ValidTransactions
GROUP BY InvoiceNo, CustomerID, Country, InvoiceDate, Year, Month;
GO

PRINT 'Views Created Successfully!';
GO

PRINT '====================================================================';
PRINT 'DATA CLEANING COMPLETE!';
PRINT '====================================================================';
PRINT 'Summary:';
PRINT '- Raw VARCHAR data converted to proper types';
PRINT '- Invalid records filtered out';
PRINT '- Production tables populated with clean data';
PRINT '- Dimensions created (Products, Customers)';
PRINT '- Analytical views created';
PRINT '';
PRINT 'Expected Results:';
PRINT '- Valid Transactions: ~397,000 rows';
PRINT '- Unique Products: ~3,900';
PRINT '- Unique Customers: ~4,300';
PRINT '';
PRINT 'Next Step: Run Script 04 - Market Basket Analysis';
PRINT '====================================================================';
GO