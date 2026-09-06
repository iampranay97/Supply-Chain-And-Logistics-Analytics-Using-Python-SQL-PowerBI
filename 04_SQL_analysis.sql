CREATE TABLE supply_chain_data (
    product_type VARCHAR(50),
    sku VARCHAR(20) PRIMARY KEY,
    price NUMERIC(10, 2),
    availability INT,
    number_of_products_sold INT,
    revenue_generated NUMERIC(12, 2),
    customer_demographics VARCHAR(50),
    stock_levels INT,
    lead_times INT,
    order_quantities INT,
    shipping_times INT,
    shipping_carriers VARCHAR(50),
    shipping_costs NUMERIC(10, 2),
    supplier_name VARCHAR(50),
    location VARCHAR(50),
    lead_time_supplier INT,
    production_volumes INT,
    manufacturing_lead_time INT,
    manufacturing_costs NUMERIC(10, 2),
    inspection_results VARCHAR(50),
    defect_rates NUMERIC(8, 4),
    transportation_modes VARCHAR(50),
    routes VARCHAR(50),
    costs NUMERIC(10, 2),
    total_logistics_cost NUMERIC(12, 2),
    net_profit NUMERIC(12, 2),
    profit_margin_pct NUMERIC(8, 4),
    stock_status VARCHAR(50)
);

SELECT COUNT(*) AS total_rows FROM supply_chain_data;

SELECT * FROM supply_chain_data;


-- Step 1 :- Inventory Recorder Alert Analysis

SELECT 
    stock_status,
    COUNT(sku) AS total_skus,
    SUM(stock_levels) AS total_inventory_units,
    ROUND(AVG(price), 2) AS avg_unit_price
FROM supply_chain_data
GROUP BY stock_status
ORDER BY total_skus DESC;


-- Step 2 :- Supplier Quality & Defect Rate Evaluation

SELECT 
    supplier_name,
    COUNT(sku) AS total_supplied_skus,
    ROUND(AVG(defect_rates), 2) AS avg_defect_rate,
    SUM(CASE WHEN inspection_results = 'Fail' THEN 1 ELSE 0 END) AS failed_inspections
FROM supply_chain_data
GROUP BY supplier_name
ORDER BY avg_defect_rate DESC;


-- Step 3 :- Logistics Cost Efficiency by Mode & Carrier

SELECT 
    transportation_modes,
    shipping_carriers,
    ROUND(AVG(shipping_costs), 2) AS avg_shipping_cost,
    ROUND(AVG(shipping_times), 2) AS avg_delivery_days
FROM supply_chain_data
GROUP BY transportation_modes, shipping_carriers
ORDER BY transportation_modes, avg_shipping_cost ASC;


-- Step 4 :- Category Profitability & Margin Ranking

SELECT 
    product_type,
    SUM(revenue_generated) AS total_revenue,
    SUM(net_profit) AS total_profit,
    ROUND(AVG(profit_margin_pct), 2) AS avg_margin_pct,
    DENSE_RANK() OVER (ORDER BY SUM(net_profit) DESC) AS profit_rank
FROM supply_chain_data
GROUP BY product_type;


-- Step 5 :- High Lead Time Risk SKU Detection

SELECT 
    sku,
    product_type,
    supplier_name,
    stock_levels,
    lead_times,
    stock_status
FROM supply_chain_data
WHERE stock_status = 'Critical Reorder Required'
ORDER BY lead_times DESC;


-- Step 6 :- Cohort Segmentation & Pareto Analysis

WITH revenue_ranked AS (
    SELECT 
        sku,
        product_type,
        revenue_generated,
        SUM(revenue_generated) OVER (ORDER BY revenue_generated DESC) AS cumulative_revenue,
        SUM(revenue_generated) OVER () AS grand_total_revenue
    FROM supply_chain_data
)
SELECT 
    sku,
    product_type,
    revenue_generated,
    ROUND((cumulative_revenue / grand_total_revenue) * 100, 2) AS cumulative_revenue_pct,
    CASE 
        WHEN (cumulative_revenue / grand_total_revenue) <= 0.80 THEN 'Top 80% Revenue Contributor (A-Category)'
        ELSE 'Remaining 20% Revenue Contributor (B/C-Category)'
    END AS pareto_segment
FROM revenue_ranked
ORDER BY revenue_generated DESC;


-- Step 7 :- Supplier Risk Matrix Score

WITH supplier_metrics AS (
    SELECT 
        supplier_name,
        COUNT(sku) AS total_orders,
        AVG(defect_rates) AS avg_defect_rate,
        AVG(lead_time_supplier) AS avg_lead_time,
        SUM(CASE WHEN inspection_results = 'Fail' THEN 1 ELSE 0 END) AS total_failures
    FROM supply_chain_data
    GROUP BY supplier_name
)
SELECT 
    supplier_name,
    total_orders,
    ROUND(avg_defect_rate::numeric, 2) AS avg_defect_rate_pct,
    ROUND(avg_lead_time::numeric, 1) AS avg_lead_time_days,
    total_failures,
    CASE 
        WHEN avg_defect_rate > 2.5 OR avg_lead_time > 18 OR total_failures >= 3 THEN 'High Risk Supplier'
        WHEN avg_defect_rate BETWEEN 1.5 AND 2.5 THEN 'Moderate Risk Supplier'
        ELSE 'Low Risk / Preferred Supplier'
    END AS supplier_risk_category
FROM supplier_metrics
ORDER BY total_failures DESC, avg_defect_rate DESC;


-- Step 8 :- Outlier & Anomaly Detection for Shipping Costs (Z-Score Analysis)

WITH route_stats AS (
    SELECT 
        sku,
        shipping_carriers,
        routes,
        shipping_costs,
        AVG(shipping_costs) OVER (PARTITION BY shipping_carriers, routes) AS avg_route_cost,
        STDDEV(shipping_costs) OVER (PARTITION BY shipping_carriers, routes) AS stddev_route_cost
    FROM supply_chain_data
)
SELECT 
    sku,
    shipping_carriers,
    routes,
    shipping_costs,
    ROUND(avg_route_cost, 2) AS avg_route_cost,
    ROUND(((shipping_costs - avg_route_cost) / NULLIF(stddev_route_cost, 0)), 2) AS z_score,
    CASE 
        WHEN (shipping_costs - avg_route_cost) / NULLIF(stddev_route_cost, 0) > 1.5 THEN 'High Cost Mismatch'
        WHEN (shipping_costs - avg_route_cost) / NULLIF(stddev_route_cost, 0) < -1.5 THEN 'Unusually Low Cost'
        ELSE 'Normal Range'
    END AS cost_anomaly_status
FROM route_stats
ORDER BY z_score DESC;


-- Step 9 :- Inventory Profitability & Days of Stock Burn Rate

WITH inventory_turnover AS (
    SELECT 
        sku,
        product_type,
        stock_levels,
        number_of_products_sold,
        net_profit,
        ROUND((revenue_generated / NULLIF(costs, 0))::numeric, 2) AS ROI_ratio,
        NTILE(4) OVER (ORDER BY (revenue_generated / NULLIF(costs, 0)) DESC) AS profitability_quartile
    FROM supply_chain_data
)
SELECT 
    sku,
    product_type,
    stock_levels,
    number_of_products_sold,
    ROI_ratio,
    profitability_quartile,
    CASE 
        WHEN profitability_quartile = 1 THEN 'Top Performing Product (Tier 1)'
        WHEN profitability_quartile = 2 THEN 'Above Average (Tier 2)'
        WHEN profitability_quartile = 3 THEN 'Below Average (Tier 3)'
        ELSE 'Underperforming Asset (Tier 4)'
    END AS performance_tier
FROM inventory_turnover
ORDER BY profitability_quartile ASC, ROI_ratio DESC;


-- Step 10 :- Route Optimization & Bottleneck Identification (Multi-Stage Analysis)

WITH route_performance AS (
    SELECT 
        routes,
        transportation_modes,
        COUNT(sku) AS total_shipments,
        ROUND(AVG(lead_times), 2) AS avg_lead_time_days,
        ROUND(AVG(shipping_costs), 2) AS avg_shipping_cost,
        ROUND(AVG(defect_rates), 2) AS avg_defect_rate,
        RANK() OVER (PARTITION BY transportation_modes ORDER BY AVG(lead_times) DESC) AS bottleneck_rank
    FROM supply_chain_data
    GROUP BY routes, transportation_modes
)
SELECT 
    routes,
    transportation_modes,
    total_shipments,
    avg_lead_time_days,
    avg_shipping_cost,
    avg_defect_rate,
    bottleneck_rank
FROM route_performance
WHERE bottleneck_rank = 1
ORDER BY avg_lead_time_days DESC;