/*============================================================================
   SCRIPT 04: MARKET BASKET ANALYSIS
   
   Purpose: Calculate Support, Confidence, and Lift for product pairs
   Author: Data Analytics Team
   
   Key Concepts:
   - Support(A): % of orders containing Product A
   - Support(A,B): % of orders containing both A and B
   - Confidence(A→B): Probability of buying B given A was bought
   - Lift(A,B): How much more likely A and B are bought together vs. independently
   
   Lift Interpretation:
   - Lift > 1: Products bought together MORE than expected (positive association)
   - Lift = 1: No association (independent purchases)
   - Lift < 1: Negative association (buying one discourages buying the other)
============================================================================*/

USE OnlineRetailDB;
GO

PRINT '====================================================================';
PRINT 'STARTING MARKET BASKET ANALYSIS';
PRINT '====================================================================';
GO

-- =============================================================================
-- PART A: PREPARE DATA FOR ANALYSIS
-- =============================================================================

PRINT 'Part A: Preparing Data for Market Basket Analysis...';
GO

-- A1: Get total number of valid orders (for support calculation)
DECLARE @TotalOrders INT;
SELECT @TotalOrders = COUNT(DISTINCT InvoiceNo)
FROM prod.vw_ValidTransactions;

PRINT 'Total Valid Orders: ' + CAST(@TotalOrders AS VARCHAR(20));
GO

-- A2: Create temporary table of distinct order-product combinations
IF OBJECT_ID('tempdb..#OrderProducts') IS NOT NULL
    DROP TABLE #OrderProducts;

SELECT DISTINCT
    InvoiceNo,
    StockCode,
    Description
INTO #OrderProducts
FROM prod.vw_ValidTransactions
WHERE Description IS NOT NULL
  AND Description <> '';

CREATE CLUSTERED INDEX IX_OrderProducts ON #OrderProducts(InvoiceNo, StockCode);

PRINT 'Order-Product Matrix Created: ' + CAST(@@ROWCOUNT AS VARCHAR(20)) + ' combinations';
GO

-- =============================================================================
-- PART B: CALCULATE INDIVIDUAL PRODUCT SUPPORT
-- =============================================================================

PRINT 'Part B: Calculating Individual Product Support...';
GO

-- B1: Calculate support for each product
IF OBJECT_ID('tempdb..#ProductSupport') IS NOT NULL
    DROP TABLE #ProductSupport;

SELECT 
    StockCode,
    MAX(Description) AS Description,
    COUNT(DISTINCT InvoiceNo) AS OrdersContainingProduct,
    CAST(COUNT(DISTINCT InvoiceNo) * 1.0 / (SELECT COUNT(DISTINCT InvoiceNo) FROM prod.vw_ValidTransactions) AS DECIMAL(10,6)) AS Support
INTO #ProductSupport
FROM #OrderProducts
GROUP BY StockCode;

CREATE CLUSTERED INDEX IX_ProductSupport ON #ProductSupport(StockCode);

PRINT 'Product Support Calculated: ' + CAST(@@ROWCOUNT AS VARCHAR(20)) + ' products';
GO

-- B2: View top products by support
SELECT TOP 20
    StockCode,
    Description,
    OrdersContainingProduct,
    Support,
    CAST(Support * 100 AS DECIMAL(5,2)) AS Support_Percentage
FROM #ProductSupport
ORDER BY Support DESC;
GO

-- =============================================================================
-- PART C: IDENTIFY PRODUCT PAIRS (CO-OCCURRENCES)
-- =============================================================================

PRINT 'Part C: Identifying Product Pairs...';
GO

-- C1: Find all product pairs that occur together in same order
-- This is the computationally intensive step
IF OBJECT_ID('tempdb..#ProductPairs') IS NOT NULL
    DROP TABLE #ProductPairs;

SELECT 
    a.StockCode AS ProductA_StockCode,
    a.Description AS ProductA_Desc,
    b.StockCode AS ProductB_StockCode,
    b.Description AS ProductB_Desc,
    COUNT(DISTINCT a.InvoiceNo) AS OrdersWithBoth
INTO #ProductPairs
FROM #OrderProducts a
INNER JOIN #OrderProducts b
    ON a.InvoiceNo = b.InvoiceNo
    AND a.StockCode < b.StockCode  -- Avoid duplicate pairs (A-B is same as B-A)
GROUP BY a.StockCode, a.Description, b.StockCode, b.Description
HAVING COUNT(DISTINCT a.InvoiceNo) >= 10;  -- Min 10 co-occurrences for statistical significance

CREATE CLUSTERED INDEX IX_ProductPairs ON #ProductPairs(ProductA_StockCode, ProductB_StockCode);

PRINT 'Product Pairs Identified: ' + CAST(@@ROWCOUNT AS VARCHAR(20)) + ' pairs';
GO

-- =============================================================================
-- PART D: CALCULATE SUPPORT, CONFIDENCE, AND LIFT
-- =============================================================================

PRINT 'Part D: Calculating Association Rule Metrics...';
GO

-- D1: Calculate all metrics
IF OBJECT_ID('tempdb..#ProductPairsWithMetrics') IS NOT NULL
    DROP TABLE #ProductPairsWithMetrics;

SELECT 
    pp.ProductA_StockCode,
    pp.ProductA_Desc,
    pp.ProductB_StockCode,
    pp.ProductB_Desc,
    pp.OrdersWithBoth,
    
    -- Support values
    psa.Support AS SupportA,
    psb.Support AS SupportB,
    CAST(pp.OrdersWithBoth * 1.0 / (SELECT COUNT(DISTINCT InvoiceNo) FROM prod.vw_ValidTransactions) AS DECIMAL(10,6)) AS SupportAB,
    
    -- Confidence values
    CAST(pp.OrdersWithBoth * 1.0 / psa.OrdersContainingProduct AS DECIMAL(10,6)) AS Confidence_AtoB,
    CAST(pp.OrdersWithBoth * 1.0 / psb.OrdersContainingProduct AS DECIMAL(10,6)) AS Confidence_BtoA,
    
    -- Lift (most important metric for association strength)
    CAST(
        (pp.OrdersWithBoth * 1.0 / (SELECT COUNT(DISTINCT InvoiceNo) FROM prod.vw_ValidTransactions))
        / (psa.Support * psb.Support)
    AS DECIMAL(10,4)) AS Lift,
    
    (SELECT COUNT(DISTINCT InvoiceNo) FROM prod.vw_ValidTransactions) AS TotalOrders
INTO #ProductPairsWithMetrics
FROM #ProductPairs pp
INNER JOIN #ProductSupport psa ON pp.ProductA_StockCode = psa.StockCode
INNER JOIN #ProductSupport psb ON pp.ProductB_StockCode = psb.StockCode;

PRINT 'Association Metrics Calculated: ' + CAST(@@ROWCOUNT AS VARCHAR(20)) + ' product pairs';
GO

-- =============================================================================
-- PART E: LOAD RESULTS INTO PRODUCTION TABLE
-- =============================================================================

PRINT 'Part E: Loading Results into Production Table...';
GO

-- Clear existing results
TRUNCATE TABLE prod.ProductPairs;
GO

-- Insert results
INSERT INTO prod.ProductPairs (
    ProductA_StockCode,
    ProductA_Desc,
    ProductB_StockCode,
    ProductB_Desc,
    SupportA,
    SupportB,
    SupportAB,
    Confidence_AtoB,
    Confidence_BtoA,
    Lift,
    OrdersWithBoth,
    TotalOrders
)
SELECT 
    ProductA_StockCode,
    ProductA_Desc,
    ProductB_StockCode,
    ProductB_Desc,
    SupportA,
    SupportB,
    SupportAB,
    Confidence_AtoB,
    Confidence_BtoA,
    Lift,
    OrdersWithBoth,
    TotalOrders
FROM #ProductPairsWithMetrics
WHERE Lift > 1  -- Only keep positive associations
  AND OrdersWithBoth >= 10;  -- Minimum statistical significance

PRINT 'Results Loaded: ' + CAST(@@ROWCOUNT AS VARCHAR(20)) + ' product pairs';
GO

-- =============================================================================
-- PART F: ANALYSIS RESULTS - TOP PRODUCT PAIRS
-- =============================================================================

PRINT 'Part F: Analyzing Top Product Pairs...';
GO

-- F1: Top 20 Product Pairs by Lift
PRINT 'Top 20 Product Pairs by Lift (Strongest Associations):';
SELECT TOP 20
    ProductA_StockCode,
    LEFT(ProductA_Desc, 40) AS Product_A,
    ProductB_StockCode,
    LEFT(ProductB_Desc, 40) AS Product_B,
    OrdersWithBoth AS Co_Occurrences,
    CAST(SupportAB * 100 AS DECIMAL(5,2)) AS Support_Pct,
    CAST(Confidence_AtoB * 100 AS DECIMAL(5,2)) AS Confidence_A_to_B_Pct,
    CAST(Confidence_BtoA * 100 AS DECIMAL(5,2)) AS Confidence_B_to_A_Pct,
    Lift,
    CASE 
        WHEN Lift >= 5 THEN 'Very Strong'
        WHEN Lift >= 3 THEN 'Strong'
        WHEN Lift >= 2 THEN 'Moderate'
        ELSE 'Weak'
    END AS Association_Strength
FROM prod.ProductPairs
ORDER BY Lift DESC;
GO

-- F2: Top 20 Product Pairs by Support (Most Frequent)
PRINT 'Top 20 Product Pairs by Support (Most Frequent):';
SELECT TOP 20
    ProductA_StockCode,
    LEFT(ProductA_Desc, 40) AS Product_A,
    ProductB_StockCode,
    LEFT(ProductB_Desc, 40) AS Product_B,
    OrdersWithBoth AS Co_Occurrences,
    CAST(SupportAB * 100 AS DECIMAL(5,2)) AS Support_Pct,
    CAST(Confidence_AtoB * 100 AS DECIMAL(5,2)) AS Confidence_A_to_B_Pct,
    Lift
FROM prod.ProductPairs
ORDER BY SupportAB DESC;
GO

-- F3: Top 20 Product Pairs by Confidence (High Conversion)
PRINT 'Top 20 Product Pairs by Confidence (If you buy A, likely to buy B):';
SELECT TOP 20
    ProductA_StockCode,
    LEFT(ProductA_Desc, 40) AS Product_A,
    ProductB_StockCode,
    LEFT(ProductB_Desc, 40) AS Product_B,
    OrdersWithBoth AS Co_Occurrences,
    CAST(Confidence_AtoB * 100 AS DECIMAL(5,2)) AS Confidence_Pct,
    Lift,
    CASE 
        WHEN Confidence_AtoB >= 0.5 THEN 'Very High'
        WHEN Confidence_AtoB >= 0.3 THEN 'High'
        WHEN Confidence_AtoB >= 0.2 THEN 'Moderate'
        ELSE 'Low'
    END AS Conversion_Likelihood
FROM prod.ProductPairs
WHERE Lift > 1
ORDER BY Confidence_AtoB DESC;
GO

-- =============================================================================
-- PART G: CROSS-SELL RECOMMENDATIONS BY PRODUCT
-- =============================================================================

PRINT 'Part G: Generating Cross-Sell Recommendations...';
GO

-- G1: Top 5 Products for Cross-Selling (Most Associated Items)
-- For each popular product, show best items to recommend
WITH PopularProducts AS (
    SELECT TOP 10 StockCode
    FROM #ProductSupport
    ORDER BY OrdersContainingProduct DESC
)
SELECT 
    pp.ProductA_StockCode AS Product_StockCode,
    pp.ProductA_Desc AS Product_Description,
    pp.ProductB_StockCode AS Recommend_StockCode,
    pp.ProductB_Desc AS Recommend_Description,
    pp.Lift,
    CAST(pp.Confidence_AtoB * 100 AS DECIMAL(5,2)) AS Conversion_Rate_Pct,
    pp.OrdersWithBoth,
    ROW_NUMBER() OVER (PARTITION BY pp.ProductA_StockCode ORDER BY pp.Lift DESC) AS Recommendation_Rank
FROM prod.ProductPairs pp
INNER JOIN PopularProducts pop ON pp.ProductA_StockCode = pop.StockCode
WHERE pp.Lift >= 2  -- At least 2x more likely
  AND pp.OrdersWithBoth >= 20
ORDER BY pp.ProductA_StockCode, pp.Lift DESC;
GO

-- =============================================================================
-- PART H: BASKET SIZE IMPACT ON ASSOCIATIONS
-- =============================================================================

PRINT 'Part H: Analyzing Basket Size Impact...';
GO

-- H1: Average basket size for orders containing each product pair
SELECT TOP 20
    pp.ProductA_StockCode,
    LEFT(pp.ProductA_Desc, 30) AS Product_A,
    pp.ProductB_StockCode,
    LEFT(pp.ProductB_Desc, 30) AS Product_B,
    pp.Lift,
    AVG(CAST(bs.BasketSize AS FLOAT)) AS Avg_Basket_Size,
    AVG(bs.OrderValue) AS Avg_Order_Value_USD
FROM prod.ProductPairs pp
INNER JOIN (
    SELECT 
        InvoiceNo,
        COUNT(DISTINCT StockCode) AS BasketSize,
        SUM(LineTotal_USD) AS OrderValue
    FROM prod.vw_ValidTransactions
    GROUP BY InvoiceNo
) bs ON EXISTS (
    SELECT 1 
    FROM prod.vw_ValidTransactions t
    WHERE t.InvoiceNo = bs.InvoiceNo
      AND t.StockCode IN (pp.ProductA_StockCode, pp.ProductB_StockCode)
)
WHERE pp.Lift >= 3
GROUP BY pp.ProductA_StockCode, pp.ProductA_Desc, pp.ProductB_StockCode, pp.ProductB_Desc, pp.Lift
ORDER BY pp.Lift DESC;
GO

-- =============================================================================
-- PART I: SUMMARY STATISTICS
-- =============================================================================

PRINT 'Part I: Market Basket Analysis Summary...';
GO

-- I1: Overall Statistics
SELECT 
    'Market Basket Analysis Summary' AS Report_Type,
    COUNT(*) AS Total_Product_Pairs_Analyzed,
    AVG(Lift) AS Avg_Lift,
    MAX(Lift) AS Max_Lift,
    MIN(Lift) AS Min_Lift,
    AVG(Confidence_AtoB) AS Avg_Confidence,
    SUM(CASE WHEN Lift >= 5 THEN 1 ELSE 0 END) AS Very_Strong_Associations,
    SUM(CASE WHEN Lift >= 3 AND Lift < 5 THEN 1 ELSE 0 END) AS Strong_Associations,
    SUM(CASE WHEN Lift >= 2 AND Lift < 3 THEN 1 ELSE 0 END) AS Moderate_Associations,
    SUM(CASE WHEN Lift >= 1 AND Lift < 2 THEN 1 ELSE 0 END) AS Weak_Associations
FROM prod.ProductPairs;
GO

-- I2: Distribution of Lift values
SELECT 
    CASE 
        WHEN Lift >= 10 THEN '10+ (Extremely Strong)'
        WHEN Lift >= 5 THEN '5-10 (Very Strong)'
        WHEN Lift >= 3 THEN '3-5 (Strong)'
        WHEN Lift >= 2 THEN '2-3 (Moderate)'
        WHEN Lift >= 1.5 THEN '1.5-2 (Weak-Moderate)'
        ELSE '1-1.5 (Weak)'
    END AS Lift_Range,
    COUNT(*) AS Pair_Count,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() AS DECIMAL(5,2)) AS Percentage,
    AVG(Confidence_AtoB) AS Avg_Confidence,
    AVG(CAST(OrdersWithBoth AS FLOAT)) AS Avg_Co_Occurrences
FROM prod.ProductPairs
GROUP BY 
    CASE 
        WHEN Lift >= 10 THEN '10+ (Extremely Strong)'
        WHEN Lift >= 5 THEN '5-10 (Very Strong)'
        WHEN Lift >= 3 THEN '3-5 (Strong)'
        WHEN Lift >= 2 THEN '2-3 (Moderate)'
        WHEN Lift >= 1.5 THEN '1.5-2 (Weak-Moderate)'
        ELSE '1-1.5 (Weak)'
    END
ORDER BY MIN(Lift) DESC;
GO

-- =============================================================================
-- PART J: CREATE VIEWS FOR POWER BI
-- =============================================================================

PRINT 'Part J: Creating Views for Power BI...';
GO

-- J1: Top Associations View
IF OBJECT_ID('prod.vw_TopProductAssociations', 'V') IS NOT NULL
    DROP VIEW prod.vw_TopProductAssociations;
GO

CREATE VIEW prod.vw_TopProductAssociations AS
SELECT TOP 100
    PairID,
    ProductA_StockCode,
    ProductA_Desc,
    ProductB_StockCode,
    ProductB_Desc,
    SupportA,
    SupportB,
    SupportAB,
    Confidence_AtoB,
    Confidence_BtoA,
    Lift,
    OrdersWithBoth,
    CASE 
        WHEN Lift >= 5 THEN 'Very Strong'
        WHEN Lift >= 3 THEN 'Strong'
        WHEN Lift >= 2 THEN 'Moderate'
        ELSE 'Weak'
    END AS AssociationStrength
FROM prod.ProductPairs
WHERE Lift >= 1.5
ORDER BY Lift DESC;
GO

PRINT 'Views Created for Power BI!';
GO

-- Clean up temp tables
DROP TABLE IF EXISTS #OrderProducts;
DROP TABLE IF EXISTS #ProductSupport;
DROP TABLE IF EXISTS #ProductPairs;
DROP TABLE IF EXISTS #ProductPairsWithMetrics;
GO

PRINT '====================================================================';
PRINT 'MARKET BASKET ANALYSIS COMPLETE!';
PRINT '====================================================================';
PRINT 'Key Outputs:';
PRINT '- prod.ProductPairs table populated with association rules';
PRINT '- Top product pairs identified by Lift, Support, and Confidence';
PRINT '- Cross-sell recommendations generated';
PRINT '- Views created for Power BI visualization';
PRINT '';
PRINT 'Next Step: Run Script 05 - Product Pairs Analysis (Deep Dive)';
PRINT '====================================================================';
GO
