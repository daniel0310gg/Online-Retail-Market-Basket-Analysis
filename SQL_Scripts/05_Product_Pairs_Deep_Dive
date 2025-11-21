/*============================================================================
   SCRIPT 05: PRODUCT PAIRS DEEP DIVE ANALYSIS
   
   Purpose: Deep analysis of product associations and bundle recommendations
   Author: Data Analytics Team
   
   This script provides:
   - Detailed product pair analysis
   - Seasonal patterns in associations
   - Country-specific patterns
   - Bundle recommendations
============================================================================*/

USE OnlineRetailDB;
GO

PRINT '====================================================================';
PRINT 'STARTING PRODUCT PAIRS DEEP DIVE ANALYSIS';
PRINT '====================================================================';
GO

-- =============================================================================
-- PART A: PRODUCT NETWORK ANALYSIS
-- =============================================================================

PRINT 'Part A: Product Network Analysis...';
GO

-- A1: Products with most associations (Hub products)
SELECT TOP 20
    StockCode,
    Description,
    AssociationCount,
    AvgLift,
    TotalCoOccurrences,
    CASE 
        WHEN AssociationCount >= 50 THEN 'Super Hub'
        WHEN AssociationCount >= 30 THEN 'Major Hub'
        WHEN AssociationCount >= 15 THEN 'Hub'
        ELSE 'Regular'
    END AS ProductType
FROM (
    SELECT 
        ProductA_StockCode AS StockCode,
        ProductA_Desc AS Description,
        COUNT(*) AS AssociationCount,
        AVG(Lift) AS AvgLift,
        SUM(OrdersWithBoth) AS TotalCoOccurrences
    FROM prod.ProductPairs
    WHERE Lift >= 2
    GROUP BY ProductA_StockCode, ProductA_Desc
    
    UNION ALL
    
    SELECT 
        ProductB_StockCode AS StockCode,
        ProductB_Desc AS Description,
        COUNT(*) AS AssociationCount,
        AVG(Lift) AS AvgLift,
        SUM(OrdersWithBoth) AS TotalCoOccurrences
    FROM prod.ProductPairs
    WHERE Lift >= 2
    GROUP BY ProductB_StockCode, ProductB_Desc
) AS ProductConnections
GROUP BY StockCode, Description, AssociationCount, AvgLift, TotalCoOccurrences
ORDER BY AssociationCount DESC;
GO

-- =============================================================================
-- PART B: TEMPORAL PATTERNS IN ASSOCIATIONS
-- =============================================================================

PRINT 'Part B: Analyzing Temporal Patterns...';
GO

-- B1: Product pairs by month (seasonality)
SELECT 
    pp.ProductA_StockCode,
    LEFT(pp.ProductA_Desc, 30) AS Product_A,
    pp.ProductB_StockCode,
    LEFT(pp.ProductB_Desc, 30) AS Product_B,
    t.Month,
    DATENAME(MONTH, DATEFROMPARTS(2011, t.Month, 1)) AS Month_Name,
    COUNT(DISTINCT t.InvoiceNo) AS Orders_This_Month,
    pp.Lift AS Overall_Lift
FROM prod.ProductPairs pp
CROSS APPLY (
    SELECT t1.InvoiceNo, t1.Month
    FROM prod.vw_ValidTransactions t1
    WHERE t1.StockCode = pp.ProductA_StockCode
      AND EXISTS (
          SELECT 1 
          FROM prod.vw_ValidTransactions t2
          WHERE t2.InvoiceNo = t1.InvoiceNo
            AND t2.StockCode = pp.ProductB_StockCode
      )
) t
WHERE pp.Lift >= 3
GROUP BY pp.ProductA_StockCode, pp.ProductA_Desc, pp.ProductB_StockCode, pp.ProductB_Desc, t.Month, pp.Lift
HAVING COUNT(DISTINCT t.InvoiceNo) >= 5
ORDER BY pp.Lift DESC, t.Month;
GO

-- =============================================================================
-- PART C: COUNTRY-SPECIFIC PATTERNS
-- =============================================================================

PRINT 'Part C: Analyzing Country-Specific Patterns...';
GO

-- C1: Top associations by country
WITH CountryPairs AS (
    SELECT 
        t1.Country,
        t1.StockCode AS ProductA,
        MAX(t1.Description) AS ProductA_Desc,
        t2.StockCode AS ProductB,
        MAX(t2.Description) AS ProductB_Desc,
        COUNT(DISTINCT t1.InvoiceNo) AS OrdersWithBoth,
        COUNT(DISTINCT t1.InvoiceNo) * 1.0 / 
            (SELECT COUNT(DISTINCT InvoiceNo) FROM prod.vw_ValidTransactions WHERE Country = t1.Country) AS Support
    FROM prod.vw_ValidTransactions t1
    INNER JOIN prod.vw_ValidTransactions t2
        ON t1.InvoiceNo = t2.InvoiceNo
        AND t1.StockCode < t2.StockCode
    WHERE t1.Country IN ('United Kingdom', 'Germany', 'France', 'EIRE', 'Spain')
    GROUP BY t1.Country, t1.StockCode, t2.StockCode
    HAVING COUNT(DISTINCT t1.InvoiceNo) >= 5
)
SELECT TOP 20
    Country,
    ProductA,
    LEFT(ProductA_Desc, 25) AS Product_A,
    ProductB,
    LEFT(ProductB_Desc, 25) AS Product_B,
    OrdersWithBoth,
    CAST(Support * 100 AS DECIMAL(5,2)) AS Support_Pct
FROM CountryPairs
ORDER BY Country, OrdersWithBoth DESC;
GO

-- =============================================================================
-- PART D: BUNDLE RECOMMENDATIONS
-- =============================================================================

PRINT 'Part D: Generating Bundle Recommendations...';
GO

-- D1: Top 10 Product Bundles (2-item bundles)
PRINT 'Top 10 Two-Item Bundles:';
SELECT TOP 10
    CONCAT(ProductA_StockCode, ' + ', ProductB_StockCode) AS Bundle_Code,
    CONCAT(LEFT(ProductA_Desc, 30), ' + ', LEFT(ProductB_Desc, 30)) AS Bundle_Description,
    Lift,
    CAST(Confidence_AtoB * 100 AS DECIMAL(5,2)) AS Cross_Sell_Rate_Pct,
    OrdersWithBoth AS Orders_With_Bundle,
    TotalOrders,
    CAST(OrdersWithBoth * 100.0 / TotalOrders AS DECIMAL(5,2)) AS Bundle_Penetration_Pct,
    CASE 
        WHEN Lift >= 5 THEN '15% discount recommended'
        WHEN Lift >= 3 THEN '10% discount recommended'
        ELSE '5% discount recommended'
    END AS Pricing_Recommendation
FROM prod.ProductPairs
WHERE Lift >= 3
  AND OrdersWithBoth >= 30
ORDER BY Lift DESC, OrdersWithBoth DESC;
GO

-- D2: 3-Product Bundles (Advanced)
PRINT 'Top 10 Three-Item Bundles:';
WITH ThreeProductCombos AS (
    SELECT 
        t1.StockCode AS Product1,
        MAX(t1.Description) AS Product1_Desc,
        t2.StockCode AS Product2,
        MAX(t2.Description) AS Product2_Desc,
        t3.StockCode AS Product3,
        MAX(t3.Description) AS Product3_Desc,
        COUNT(DISTINCT t1.InvoiceNo) AS OrdersWithAll3
    FROM prod.vw_ValidTransactions t1
    INNER JOIN prod.vw_ValidTransactions t2
        ON t1.InvoiceNo = t2.InvoiceNo
        AND t1.StockCode < t2.StockCode
    INNER JOIN prod.vw_ValidTransactions t3
        ON t1.InvoiceNo = t3.InvoiceNo
        AND t2.StockCode < t3.StockCode
    GROUP BY t1.StockCode, t2.StockCode, t3.StockCode
    HAVING COUNT(DISTINCT t1.InvoiceNo) >= 10
)
SELECT TOP 10
    CONCAT(Product1, ' + ', Product2, ' + ', Product3) AS Bundle_Code,
    LEFT(Product1_Desc, 20) AS Item_1,
    LEFT(Product2_Desc, 20) AS Item_2,
    LEFT(Product3_Desc, 20) AS Item_3,
    OrdersWithAll3,
    CAST(OrdersWithAll3 * 100.0 / (SELECT COUNT(DISTINCT InvoiceNo) FROM prod.vw_ValidTransactions) AS DECIMAL(5,2)) AS Support_Pct
FROM ThreeProductCombos
ORDER BY OrdersWithAll3 DESC;
GO

-- =============================================================================
-- PART E: CROSS-SELL MATRIX
-- =============================================================================

PRINT 'Part E: Creating Cross-Sell Opportunity Matrix...';
GO

-- E1: Cross-sell matrix for top 20 products
WITH TopProducts AS (
    SELECT TOP 20 StockCode
    FROM prod.Products
    ORDER BY TotalRevenue_USD DESC
)
SELECT 
    tp1.StockCode AS Product,
    tp2.StockCode AS Cross_Sell_To,
    ISNULL(pp.Lift, 0) AS Lift,
    CASE 
        WHEN pp.Lift >= 3 THEN 'High Priority'
        WHEN pp.Lift >= 2 THEN 'Medium Priority'
        WHEN pp.Lift >= 1.5 THEN 'Low Priority'
        ELSE 'No Association'
    END AS Priority,
    ISNULL(pp.OrdersWithBoth, 0) AS Co_Occurrences
FROM TopProducts tp1
CROSS JOIN TopProducts tp2
LEFT JOIN prod.ProductPairs pp
    ON (tp1.StockCode = pp.ProductA_StockCode AND tp2.StockCode = pp.ProductB_StockCode)
    OR (tp1.StockCode = pp.ProductB_StockCode AND tp2.StockCode = pp.ProductA_StockCode)
WHERE tp1.StockCode <> tp2.StockCode
ORDER BY tp1.StockCode, ISNULL(pp.Lift, 0) DESC;
GO

-- =============================================================================
-- PART F: REVENUE IMPACT ANALYSIS
-- =============================================================================

PRINT 'Part F: Analyzing Revenue Impact...';
GO

-- F1: Potential revenue from bundles
WITH BundleRevenue AS (
    SELECT 
        pp.ProductA_StockCode,
        pp.ProductA_Desc,
        pp.ProductB_StockCode,
        pp.ProductB_Desc,
        pp.Lift,
        pp.OrdersWithBoth,
        AVG(t1.UnitPrice_USD) AS AvgPrice_A,
        AVG(t2.UnitPrice_USD) AS AvgPrice_B,
        AVG(t1.UnitPrice_USD) + AVG(t2.UnitPrice_USD) AS Bundle_Price,
        pp.TotalOrders - pp.OrdersWithBoth AS Missed_Opportunities
    FROM prod.ProductPairs pp
    INNER JOIN prod.vw_ValidTransactions t1 ON pp.ProductA_StockCode = t1.StockCode
    INNER JOIN prod.vw_ValidTransactions t2 ON pp.ProductB_StockCode = t2.StockCode
    WHERE pp.Lift >= 3
    GROUP BY pp.ProductA_StockCode, pp.ProductA_Desc, pp.ProductB_StockCode, pp.ProductB_Desc, 
             pp.Lift, pp.OrdersWithBoth, pp.TotalOrders
)
SELECT TOP 20
    ProductA_StockCode + ' + ' + ProductB_StockCode AS Bundle_Code,
    LEFT(ProductA_Desc, 25) AS Product_A,
    LEFT(ProductB_Desc, 25) AS Product_B,
    Lift,
    OrdersWithBoth AS Current_Bundle_Sales,
    Missed_Opportunities,
    CAST(Bundle_Price AS DECIMAL(10,2)) AS Bundle_Price_USD,
    CAST(Missed_Opportunities * Bundle_Price * 0.1 AS DECIMAL(12,2)) AS Potential_Additional_Revenue_USD,
    CASE 
        WHEN Lift >= 5 THEN 'Implement immediately'
        WHEN Lift >= 3 THEN 'High priority'
        ELSE 'Consider'
    END AS Recommendation
FROM BundleRevenue
ORDER BY Potential_Additional_Revenue_USD DESC;
GO

-- =============================================================================
-- PART G: CUSTOMER SEGMENT ANALYSIS
-- =============================================================================

PRINT 'Part G: Analyzing Customer Segments...';
GO

-- G1: High-value customers and their basket patterns
WITH HighValueCustomers AS (
    SELECT TOP 20 PERCENT CustomerID
    FROM prod.Customers
    ORDER BY TotalRevenue_USD DESC
),
LowValueCustomers AS (
    SELECT TOP 20 PERCENT CustomerID
    FROM prod.Customers
    ORDER BY TotalRevenue_USD ASC
)
SELECT 
    'High Value Customers' AS Segment,
    AVG(BasketSize) AS Avg_Basket_Size,
    AVG(OrderValue) AS Avg_Order_Value_USD,
    COUNT(DISTINCT CustomerID) AS Customer_Count,
    COUNT(DISTINCT InvoiceNo) AS Order_Count
FROM (
    SELECT 
        t.CustomerID,
        t.InvoiceNo,
        COUNT(DISTINCT t.StockCode) AS BasketSize,
        SUM(t.LineTotal_USD) AS OrderValue
    FROM prod.vw_ValidTransactions t
    INNER JOIN HighValueCustomers hvc ON t.CustomerID = hvc.CustomerID
    GROUP BY t.CustomerID, t.InvoiceNo
) AS HighValueOrders

UNION ALL

SELECT 
    'Low Value Customers' AS Segment,
    AVG(BasketSize) AS Avg_Basket_Size,
    AVG(OrderValue) AS Avg_Order_Value_USD,
    COUNT(DISTINCT CustomerID) AS Customer_Count,
    COUNT(DISTINCT InvoiceNo) AS Order_Count
FROM (
    SELECT 
        t.CustomerID,
        t.InvoiceNo,
        COUNT(DISTINCT t.StockCode) AS BasketSize,
        SUM(t.LineTotal_USD) AS OrderValue
    FROM prod.vw_ValidTransactions t
    INNER JOIN LowValueCustomers lvc ON t.CustomerID = lvc.CustomerID
    GROUP BY t.CustomerID, t.InvoiceNo
) AS LowValueOrders;
GO

PRINT '====================================================================';
PRINT 'PRODUCT PAIRS DEEP DIVE COMPLETE!';
PRINT '====================================================================';
PRINT 'Analysis Complete:';
PRINT '- Hub products identified';
PRINT '- Seasonal patterns analyzed';
PRINT '- Country-specific insights generated';
PRINT '- Bundle recommendations created';
PRINT '- Revenue impact calculated';
PRINT '';
PRINT 'Next Step: Run Script 06 - Business Insights & Recommendations';
PRINT '====================================================================';
GO
