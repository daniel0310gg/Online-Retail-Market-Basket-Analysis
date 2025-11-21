/*============================================================================
   SCRIPT 01: DATABASE SETUP & DATA IMPORT
   
   Purpose: Create database, schema, and import Online Retail data
   Author: Data Analytics Team
   Date: 2024
   
   Prerequisites:
   - MS SQL Server installed
   - Online_Retail.xlsx converted to CSV or use SSMS Import Wizard
============================================================================*/

-- =============================================================================
-- SECTION 1: CREATE DATABASE
-- =============================================================================

-- Drop database if exists (CAUTION: Use only in development)
IF DB_ID('OnlineRetailDB') IS NOT NULL
BEGIN
    ALTER DATABASE OnlineRetailDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE OnlineRetailDB;
END
GO

-- Create new database
CREATE DATABASE OnlineRetailDB;
GO

USE OnlineRetailDB;
GO

PRINT 'Database OnlineRetailDB created successfully!';
GO

-- =============================================================================
-- SECTION 2: CREATE STAGING TABLE
-- =============================================================================

-- Create schema for organization
CREATE SCHEMA staging;
GO

-- Drop staging table if exists
IF OBJECT_ID('staging.OnlineRetail_Raw', 'U') IS NOT NULL
    DROP TABLE staging.OnlineRetail_Raw;
GO

CREATE TABLE staging.OnlineRetail_Raw (
    InvoiceNo       VARCHAR(20) NOT NULL,
    StockCode       VARCHAR(50) NOT NULL,
    Description     VARCHAR(500) NULL,
    Quantity        VARCHAR(50) NULL,      
    InvoiceDate     VARCHAR(50) NULL,      
    UnitPrice       VARCHAR(50) NULL,      
    CustomerID      VARCHAR(50) NULL,      
    Country         VARCHAR(100) NOT NULL
);
GO

PRINT 'Staging table created successfully!';
GO

-- =============================================================================
-- SECTION 3: IMPORT DATA
-- =============================================================================

/*
METHOD 1: Using BULK INSERT (if you have CSV file)
---------------------------------------------------
Make sure CSV is saved in a location SQL Server can access.
Example: C:\Data\Online_Retail.csv
*/

BULK INSERT staging.OnlineRetail_Raw
FROM 'C:\Data\online_retail.csv'
WITH (
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
    FIRSTROW = 2,  -- Skip header row
    TABLOCK,
    MAXERRORS = 100,  -- Allow some errors
    CODEPAGE = '65001'  -- UTF-8
);
GO

-- Verify the import
SELECT 
    'Data Import Complete' AS Status,
    COUNT(*) AS TotalRows,
    COUNT(DISTINCT InvoiceNo) AS UniqueInvoices,
    COUNT(DISTINCT StockCode) AS UniqueProducts
FROM staging.OnlineRetail_Raw;
GO


/*
METHOD 2: Using SSMS Import Wizard (RECOMMENDED)
------------------------------------------------
1. Right-click on OnlineRetailDB
2. Tasks > Import Data
3. Choose "Microsoft Excel" as data source
4. Select Online_Retail.xlsx file
5. Choose destination: SQL Server Native Client
6. Destination database: OnlineRetailDB
7. Source table: Sheet1$
8. Destination table: staging.OnlineRetail_Raw
9. Map columns appropriately
10. Execute immediately
*/

-- =============================================================================
-- SECTION 4: CREATE PRODUCTION TABLES
-- =============================================================================

-- Create production schema
CREATE SCHEMA prod;
GO

-- Create cleaned transactions table
IF OBJECT_ID('prod.Transactions', 'U') IS NOT NULL
    DROP TABLE prod.Transactions;
GO

CREATE TABLE prod.Transactions (
    TransactionID       INT IDENTITY(1,1) PRIMARY KEY,
    InvoiceNo           VARCHAR(20) NOT NULL,
    StockCode           VARCHAR(50) NOT NULL,
    Description         VARCHAR(500) NULL,
    Quantity            INT NOT NULL,
    InvoiceDate         DATETIME NOT NULL,
    UnitPrice_Sterling  DECIMAL(10,3) NOT NULL,
    UnitPrice_USD       DECIMAL(10,3) NOT NULL,  -- Converted to USD
    LineTotal_USD       DECIMAL(12,2) NOT NULL,
    CustomerID          INT NULL,
    Country             VARCHAR(100) NOT NULL,
    IsCancellation      BIT NOT NULL,
    IsReturn            BIT NOT NULL,
    IsValid             BIT NOT NULL,
    Year                INT NOT NULL,
    Month               INT NOT NULL,
    DayOfWeek           VARCHAR(10) NOT NULL,
    Hour                INT NOT NULL,
    LoadDate            DATETIME DEFAULT GETDATE()
);
GO

-- Create products dimension table
IF OBJECT_ID('prod.Products', 'U') IS NOT NULL
    DROP TABLE prod.Products;
GO

CREATE TABLE prod.Products (
    ProductID           INT IDENTITY(1,1) PRIMARY KEY,
    StockCode           VARCHAR(50) UNIQUE NOT NULL,
    Description         VARCHAR(500) NULL,
    FirstSeenDate       DATETIME NOT NULL,
    LastSeenDate        DATETIME NOT NULL,
    TotalQuantitySold   INT NOT NULL,
    TotalRevenue_USD    DECIMAL(12,2) NOT NULL,
    LoadDate            DATETIME DEFAULT GETDATE()
);
GO

-- Create customers dimension table
IF OBJECT_ID('prod.Customers', 'U') IS NOT NULL
    DROP TABLE prod.Customers;
GO

CREATE TABLE prod.Customers (
    CustomerID          INT PRIMARY KEY,
    Country             VARCHAR(100) NOT NULL,
    FirstPurchaseDate   DATETIME NOT NULL,
    LastPurchaseDate    DATETIME NOT NULL,
    TotalOrders         INT NOT NULL,
    TotalRevenue_USD    DECIMAL(12,2) NOT NULL,
    LoadDate            DATETIME DEFAULT GETDATE()
);
GO

-- Create market basket analysis results table
IF OBJECT_ID('prod.ProductPairs', 'U') IS NOT NULL
    DROP TABLE prod.ProductPairs;
GO

CREATE TABLE prod.ProductPairs (
    PairID              INT IDENTITY(1,1) PRIMARY KEY,
    ProductA_StockCode  VARCHAR(50) NOT NULL,
    ProductA_Desc       VARCHAR(500) NULL,
    ProductB_StockCode  VARCHAR(50) NOT NULL,
    ProductB_Desc       VARCHAR(500) NULL,
    SupportA            DECIMAL(10,6) NOT NULL,
    SupportB            DECIMAL(10,6) NOT NULL,
    SupportAB           DECIMAL(10,6) NOT NULL,
    Confidence_AtoB     DECIMAL(10,6) NOT NULL,
    Confidence_BtoA     DECIMAL(10,6) NOT NULL,
    Lift                DECIMAL(10,4) NOT NULL,
    OrdersWithBoth      INT NOT NULL,
    TotalOrders         INT NOT NULL,
    AnalysisDate        DATETIME DEFAULT GETDATE()
);
GO

PRINT 'Production tables created successfully!';
GO

-- =============================================================================
-- SECTION 5: CREATE INDEXES FOR PERFORMANCE
-- =============================================================================

-- Indexes on Transactions
CREATE NONCLUSTERED INDEX IX_Transactions_InvoiceNo 
    ON prod.Transactions(InvoiceNo);

CREATE NONCLUSTERED INDEX IX_Transactions_StockCode 
    ON prod.Transactions(StockCode);

CREATE NONCLUSTERED INDEX IX_Transactions_CustomerID 
    ON prod.Transactions(CustomerID);

CREATE NONCLUSTERED INDEX IX_Transactions_InvoiceDate 
    ON prod.Transactions(InvoiceDate);

-- Indexes on Products
CREATE NONCLUSTERED INDEX IX_Products_StockCode 
    ON prod.Products(StockCode);

-- Indexes on ProductPairs
CREATE NONCLUSTERED INDEX IX_ProductPairs_Lift 
    ON prod.ProductPairs(Lift DESC);

CREATE NONCLUSTERED INDEX IX_ProductPairs_ProductA 
    ON prod.ProductPairs(ProductA_StockCode);

GO

PRINT 'Indexes created successfully!';
GO

-- =============================================================================
-- SECTION 6: VERIFY DATA IMPORT
-- =============================================================================

-- Check row count
SELECT 
    'Raw Data Loaded' AS Status,
    COUNT(*) AS TotalRows,
    COUNT(DISTINCT InvoiceNo) AS UniqueInvoices,
    COUNT(DISTINCT StockCode) AS UniqueProducts,
    COUNT(DISTINCT CustomerID) AS UniqueCustomers,
    COUNT(DISTINCT Country) AS UniqueCountries,
    MIN(InvoiceDate) AS FirstTransaction,
    MAX(InvoiceDate) AS LastTransaction
FROM staging.OnlineRetail_Raw;
GO

-- Check for missing values
SELECT 
    'Missing Values Check' AS CheckType,
    SUM(CASE WHEN Description IS NULL THEN 1 ELSE 0 END) AS Missing_Description,
    SUM(CASE WHEN CustomerID IS NULL THEN 1 ELSE 0 END) AS Missing_CustomerID,
    SUM(CASE WHEN UnitPrice = 0 THEN 1 ELSE 0 END) AS Zero_Price,
    SUM(CASE WHEN Quantity = 0 THEN 1 ELSE 0 END) AS Zero_Quantity,
    SUM(CASE WHEN Quantity < 0 THEN 1 ELSE 0 END) AS Negative_Quantity
FROM staging.OnlineRetail_Raw;
GO

-- Sample data preview
SELECT TOP 20 
    InvoiceNo,
    StockCode,
    Description,
    Quantity,
    InvoiceDate,
    UnitPrice,
    CustomerID,
    Country
FROM staging.OnlineRetail_Raw
ORDER BY InvoiceDate;
GO

PRINT '====================================================================';
PRINT 'DATABASE SETUP COMPLETE!';
PRINT '====================================================================';
PRINT 'Next Steps:';
PRINT '1. Verify data is loaded into staging.OnlineRetail_Raw';
PRINT '2. Run Script 02 - Data Exploration';
PRINT '3. Run Script 03 - Data Cleaning';
PRINT '====================================================================';
GO