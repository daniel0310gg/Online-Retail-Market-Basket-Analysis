/*==========================================================================
   SCRIPT 06: BUSINESS INSIGHTS & RECOMMENDATIONS 
   
   Purpose: Generate actionable business recommendations from analysis
   Author: Data Analytics Team
   
   FIXES APPLIED:
   - Removed QUALIFY clause (not supported in SQL Server)
   - Fixed GROUP BY in Part D
   - Fixed CTE column references in Part G
   
   This script provides the final recommendations for:
   - Product bundle creation
   - Cross-sell strategies
   - Website optimization
   - Email marketing
   - Inventory management
============================================================================*/

USE OnlineRetailDB;
GO

PRINT '====================================================================';
PRINT 'GENERATING BUSINESS INSIGHTS & RECOMMENDATIONS';
PRINT '====================================================================';
GO

-- =============================================================================
-- PART A: TOP 5 PRODUCT BUNDLES TO IMPLEMENT
-- =============================================================================

PRINT 'Part A: TOP 5 RECOMMENDED PRODUCT BUNDLES';
PRINT '--------------------------------------------------------------------';
GO

SELECT TOP 5
    ROW_NUMBER() OVER (ORDER BY Lift DESC, OrdersWithBoth DESC) AS Recommendation_Rank,
    CONCAT(ProductA_StockCode, ' + ', ProductB_StockCode) AS Bundle_SKU,
    ProductA_Desc AS Product_1,
    ProductB_Desc AS Product_2,
    Lift AS Association_Strength,
    CAST(Confidence_AtoB * 100 AS DECIMAL(5,1)) AS Cross_Sell_Probability_Pct,
    OrdersWithBoth AS Historical_Bundle_Orders,
    CAST(OrdersWithBoth * 100.0 / TotalOrders AS DECIMAL(5,2)) AS Market_Penetration_Pct,
    CASE 
        WHEN Lift >= 5 THEN '15%'
        WHEN Lift >= 3 THEN '10%'
        ELSE '7%'
    END AS Recommended_Discount,
    CASE 
        WHEN Lift >= 5 THEN 'Implement Immediately - Very Strong Association'
        WHEN Lift >= 3 THEN 'High Priority - Strong Association'
        ELSE 'Medium Priority - Moderate Association'
    END AS Implementation_Priority,
    'Create bundle on website, offer discount, add to email campaigns' AS Action_Items
FROM prod.ProductPairs
WHERE Lift >= 3
  AND OrdersWithBoth >= 30
  AND SupportAB >= 0.001  -- At least 0.1% of all orders
ORDER BY Lift DESC, OrdersWithBoth DESC;
GO

-- =============================================================================
-- PART B: PRODUCT PAGE CROSS-SELL RECOMMENDATIONS (FIXED)
-- =============================================================================

PRINT 'Part B: PRODUCT PAGE "FREQUENTLY BOUGHT TOGETHER" RECOMMENDATIONS';
PRINT '--------------------------------------------------------------------';
GO

-- For each top product, show top 3 items to cross-sell
WITH TopProducts AS (
    SELECT TOP 20 StockCode, Description
    FROM prod.Products
    ORDER BY TotalRevenue_USD DESC
),
Recommendations AS (
    SELECT 
        tp.StockCode AS Product_StockCode,
        tp.Description AS Product_Name,
        CASE 
            WHEN pp.ProductA_StockCode = tp.StockCode THEN pp.ProductB_StockCode
            ELSE pp.ProductA_StockCode
        END AS Recommend_StockCode,
        CASE 
            WHEN pp.ProductA_StockCode = tp.StockCode THEN pp.ProductB_Desc
            ELSE pp.ProductA_Desc
        END AS Recommend_Product,
        pp.Lift,
        CAST(CASE 
            WHEN pp.ProductA_StockCode = tp.StockCode THEN pp.Confidence_AtoB
            ELSE pp.Confidence_BtoA
        END * 100 AS DECIMAL(5,1)) AS Conversion_Rate_Pct,
        pp.OrdersWithBoth AS Times_Purchased_Together,
        ROW_NUMBER() OVER (
            PARTITION BY tp.StockCode 
            ORDER BY pp.Lift DESC
        ) AS Recommendation_Slot,
        'Display as "Frequently Bought Together" section' AS Implementation
    FROM TopProducts tp
    INNER JOIN prod.ProductPairs pp
        ON tp.StockCode IN (pp.ProductA_StockCode, pp.ProductB_StockCode)
    WHERE pp.Lift >= 2
)
SELECT 
    Product_StockCode,
    Product_Name,
    Recommend_StockCode,
    Recommend_Product,
    Lift,
    Conversion_Rate_Pct,
    Times_Purchased_Together,
    Recommendation_Slot,
    Implementation
FROM Recommendations
WHERE Recommendation_Slot <= 3
ORDER BY Product_StockCode, Lift DESC;
GO

-- =============================================================================
-- PART C: EMAIL MARKETING CAMPAIGNS
-- =============================================================================

PRINT 'Part C: EMAIL MARKETING CROSS-SELL CAMPAIGNS';
PRINT '--------------------------------------------------------------------';
GO

-- Triggered email campaigns based on purchase behavior
SELECT TOP 10
    'Email Campaign ' + CAST(ROW_NUMBER() OVER (ORDER BY pp.Lift DESC) AS VARCHAR(5)) AS Campaign_Name,
    pp.ProductA_StockCode AS Trigger_Product,
    pp.ProductA_Desc AS When_Customer_Buys,
    pp.ProductB_StockCode AS Recommend_Product_SKU,
    pp.ProductB_Desc AS Recommend_In_Email,
    CAST(pp.Confidence_AtoB * 100 AS DECIMAL(5,1)) AS Expected_Conversion_Rate_Pct,
    pp.Lift,
    '48 hours after purchase' AS Send_Timing,
    CASE 
        WHEN pp.Lift >= 5 THEN '15% discount code'
        WHEN pp.Lift >= 3 THEN '10% discount code'
        ELSE '5% discount code'
    END AS Email_Offer,
    'Subject: You might also love these items!' AS Email_Subject_Line,
    pp.OrdersWithBoth AS Historical_Success_Rate
FROM prod.ProductPairs pp
WHERE pp.Lift >= 3
  AND pp.OrdersWithBoth >= 25
ORDER BY pp.Lift DESC;
GO

-- =============================================================================
-- PART D: HOMEPAGE & CATEGORY PAGE LAYOUT OPTIMIZATION (FIXED)
-- =============================================================================

PRINT 'Part D: HOMEPAGE PRODUCT PLACEMENT RECOMMENDATIONS';
PRINT '--------------------------------------------------------------------';
GO

-- Products that should be placed near each other on homepage
-- FIXED: Removed aggregation conflict by not using ROW_NUMBER with AVG
WITH StrongAssociations AS (
    SELECT 
        ProductA_StockCode,
        ProductA_Desc,
        ProductB_StockCode,
        ProductB_Desc,
        Lift,
        OrdersWithBoth
    FROM prod.ProductPairs
    WHERE Lift >= 4  -- Very strong associations
      AND OrdersWithBoth >= 30
)
SELECT TOP 20
    'Product Cluster ' + CAST(ROW_NUMBER() OVER (ORDER BY Lift DESC) AS VARCHAR(5)) AS Cluster_ID,
    ProductA_StockCode AS Product_1_SKU,
    LEFT(ProductA_Desc, 30) AS Product_1,
    ProductB_StockCode AS Product_2_SKU,
    LEFT(ProductB_Desc, 30) AS Product_2,
    Lift,
    'Place adjacent on homepage' AS Layout_Recommendation,
    'Use same banner/section' AS Visual_Grouping
FROM StrongAssociations
ORDER BY Lift DESC;
GO

-- =============================================================================
-- PART E: INVENTORY & PROCUREMENT INSIGHTS
-- =============================================================================

PRINT 'Part E: INVENTORY MANAGEMENT RECOMMENDATIONS';
PRINT '--------------------------------------------------------------------';
GO

-- Products that should be stocked together
SELECT TOP 50
    ProductA_StockCode + ' & ' + ProductB_StockCode AS Stock_Together,
    LEFT(ProductA_Desc, 30) AS Product_A,
    LEFT(ProductB_Desc, 30) AS Product_B,
    Lift,
    OrdersWithBoth AS Monthly_Bundle_Demand,
    CAST(OrdersWithBoth * 1.2 AS INT) AS Recommended_Monthly_Stock_Level,
    'Stock in same warehouse zone' AS Warehouse_Recommendation,
    'Order from supplier together' AS Procurement_Tip
FROM prod.ProductPairs
WHERE Lift >= 3
  AND OrdersWithBoth >= 20
ORDER BY OrdersWithBoth DESC;
GO

-- =============================================================================
-- PART F: A/B TESTING RECOMMENDATIONS
-- =============================================================================

PRINT 'Part F: A/B TESTING STRATEGY';
PRINT '--------------------------------------------------------------------';
GO

SELECT TOP 10
    'Test ' + CAST(ROW_NUMBER() OVER (ORDER BY Lift DESC) AS VARCHAR(5)) AS Test_ID,
    ProductA_Desc + ' + ' + ProductB_Desc AS Bundle_To_Test,
    Lift AS Expected_Performance,
    CASE 
        WHEN Lift >= 5 THEN '15%'
        WHEN Lift >= 4 THEN '12%'
        WHEN Lift >= 3 THEN '10%'
        ELSE '7%'
    END AS Test_Discount_Level,
    'Control: No bundle, Test: Bundle with discount' AS Test_Design,
    '2 weeks' AS Recommended_Duration,
    'Measure: Add-to-cart rate, Conversion rate, AOV' AS Success_Metrics,
    CAST(OrdersWithBoth * 0.1 AS INT) AS Estimated_Weekly_Sample_Size
FROM prod.ProductPairs
WHERE Lift >= 3
  AND OrdersWithBoth >= 30
ORDER BY Lift DESC;
GO

-- =============================================================================
-- PART G: EXECUTIVE SUMMARY REPORT (FIXED)
-- =============================================================================

PRINT 'Part G: EXECUTIVE SUMMARY';
PRINT '====================================================================';
GO

-- G1: Overall Market Basket Performance
SELECT 
    'Market Basket Analysis' AS Report_Title,
    (SELECT COUNT(DISTINCT InvoiceNo) FROM prod.vw_ValidTransactions) AS Total_Orders_Analyzed,
    (SELECT COUNT(*) FROM prod.ProductPairs WHERE Lift >= 1) AS Product_Associations_Found,
    (SELECT COUNT(*) FROM prod.ProductPairs WHERE Lift >= 3) AS Strong_Associations,
    (SELECT AVG(CAST(BasketSize AS FLOAT)) 
     FROM (SELECT InvoiceNo, COUNT(DISTINCT StockCode) AS BasketSize 
           FROM prod.vw_ValidTransactions GROUP BY InvoiceNo) AS Baskets) AS Avg_Basket_Size,
    (SELECT TOP 1 Lift FROM prod.ProductPairs ORDER BY Lift DESC) AS Strongest_Association_Lift,
    'Ready for implementation' AS Status;
GO

-- G2: Revenue Opportunity Summary (FIXED)
-- FIXED: Added all CTE columns to outer SELECT or aggregated them
WITH RevenueOpp AS (
    SELECT 
        pp.ProductA_StockCode,
        pp.ProductB_StockCode,
        pp.OrdersWithBoth,
        pp.Lift,
        AVG(t1.UnitPrice_USD) AS Price_A,
        AVG(t2.UnitPrice_USD) AS Price_B
    FROM prod.ProductPairs pp
    INNER JOIN prod.vw_ValidTransactions t1 ON pp.ProductA_StockCode = t1.StockCode
    INNER JOIN prod.vw_ValidTransactions t2 ON pp.ProductB_StockCode = t2.StockCode
    WHERE pp.Lift >= 3
    GROUP BY pp.ProductA_StockCode, pp.ProductB_StockCode, pp.OrdersWithBoth, pp.Lift
)
SELECT 
    'Revenue Opportunity Analysis' AS Report_Section,
    COUNT(*) AS Implementable_Bundles,
    SUM(ro.OrdersWithBoth) AS Total_Historical_Bundle_Orders,
    CAST(AVG(ro.Price_A + ro.Price_B) AS DECIMAL(10,2)) AS Avg_Bundle_Value_USD,
    CAST(SUM(ro.OrdersWithBoth * (ro.Price_A + ro.Price_B) * 0.05) AS DECIMAL(15,2)) AS Estimated_Annual_Revenue_Lift_USD,
    'Assuming 5% conversion improvement on bundled products' AS Assumption
FROM RevenueOpp ro;
GO

PRINT '====================================================================';
PRINT 'BUSINESS INSIGHTS COMPLETE!';
PRINT '====================================================================';
PRINT '';
PRINT 'KEY RECOMMENDATIONS:';
PRINT '1. Implement Top 5 product bundles with recommended discounts';
PRINT '2. Add "Frequently Bought Together" sections to product pages';
PRINT '3. Launch triggered email campaigns for cross-sell';
PRINT '4. Optimize homepage layout to group associated products';
PRINT '5. Start A/B testing bundle offers';
PRINT '';
PRINT 'Next Step: Connect Power BI for visualization';
PRINT '====================================================================';
GO
