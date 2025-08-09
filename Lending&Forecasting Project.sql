--MODELING TABLE / Create the analysis table
---Step 1: Define the structure

CREATE TABLE ibdr_analysis (
    countryEconomy NVARCHAR(100),
    region NVARCHAR(100),
    fiscalYear INT,
    IBRDCommitments FLOAT,
    grossDisbursement FLOAT,
    repayments FLOAT,
    netFlow FLOAT,
    variance_vs_commitments FLOAT,
    debt_service_ratio FLOAT,
    interest FLOAT,
    fees FLOAT
);

---Step 2: Populate with calculated data

INSERT INTO ibdr_analysis
SELECT
    countryEconomy,
    region,
    fiscalYear,
    IBRDCommitments,
    grossDisbursement,
    repayments,
    grossDisbursement - repayments AS netFlow,
    CASE 
        WHEN IBRDCommitments = 0 THEN NULL
        ELSE (grossDisbursement - repayments) / IBRDCommitments
    END AS variance_vs_commitments,
    CASE 
        WHEN grossDisbursement = 0 THEN NULL
        ELSE repayments / grossDisbursement
    END AS debt_service_ratio,
    interest,
    fees
FROM ibdr_data;


--EXPLORING DATA
---Summary stats for netFlow

SELECT DISTINCT
    ROUND(AVG(netFlow) OVER (), 2) AS avg_netFlow,
    ROUND(MIN(netFlow) OVER (), 2) AS min_netFlow,
    ROUND(MAX(netFlow) OVER (), 2) AS max_netFlow,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY netFlow) OVER (), 2) AS median_netFlow,
    ROUND(STDEV(netFlow) OVER (), 2) AS stddev_netFlow
FROM ibdr_analysis;


--PROFILING DATA
---Count how many countries have commitment and the percentage of the total number

WITH country_totals AS (
    SELECT COUNT(DISTINCT countryEconomy) AS total_countries
    FROM ibdr_analysis
),
country_with_commitments AS (
    SELECT COUNT(DISTINCT countryEconomy) AS countries_with_commitments
    FROM ibdr_analysis
    WHERE IBRDCommitments > 0
)
SELECT
    cwc.countries_with_commitments,
    ct.total_countries,
    ROUND(
        CAST(cwc.countries_with_commitments AS FLOAT) / ct.total_countries * 100, 2
    ) AS percent_with_commitments
FROM country_with_commitments cwc
CROSS JOIN country_totals ct;


--CLEANING DATA
---Filtering out years/countries with no lending activity
---Step 1: Define the structure (copy from ibdr_analysis)

CREATE TABLE ibdr_cleaned (
    countryEconomy NVARCHAR(100),
    region NVARCHAR(100),
    fiscalYear INT,
    IBRDCommitments FLOAT,
    grossDisbursement FLOAT,
    repayments FLOAT,
    netFlow FLOAT,
    variance_vs_commitments FLOAT,
    debt_service_ratio FLOAT,
    interest FLOAT,
    fees FLOAT
);

---Step 2: Insert only active lending records
INSERT INTO ibdr_cleaned
SELECT *
FROM ibdr_analysis
WHERE 
    NOT (
        grossDisbursement = 0 AND
        repayments = 0 AND
        IBRDCommitments = 0
    );

---Verify outliers and handle
---Step 1: Use a CTE to calculate bounds

WITH bounds AS (
    SELECT 
        PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY netFlow) OVER () AS p01,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY netFlow) OVER () AS p99
    FROM ibdr_cleaned
)
SELECT c.*, 
    CASE 
        WHEN c.netFlow < b.p01 OR c.netFlow > b.p99 THEN 1 
        ELSE 0 
    END AS is_outlier
INTO vw_ibdr_outliers_temp
FROM ibdr_cleaned c
CROSS APPLY (
    SELECT TOP 1 * FROM bounds
) b;

---Step 2: Then turn that into a view:

CREATE OR ALTER VIEW vw_ibdr_outliers AS

---Step 3: Show the created view

SELECT * FROM vw_ibdr_outliers_temp;

---Step 4: Prevent access outlier

---Store percentiles in variables
DECLARE @p01 FLOAT, @p99 FLOAT;

SELECT 
    @p01 = PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY netFlow) OVER (),
    @p99 = PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY netFlow) OVER ()
FROM ibdr_cleaned;
---Optionally print values
SELECT @p01 AS p01, @p99 AS p99;

---Step 5: Use those values to filter or flag outliers
---Previous output was:
---@p01 = -473880910.44, @p99 = 1564179679.7135007

CREATE OR ALTER VIEW vw_ibdr_outliers AS
SELECT *,
    CASE 
        WHEN netFlow < -473880910.44 OR netFlow > 1564179679.7135007 THEN 1
        ELSE 0
    END AS is_outlier
FROM ibdr_cleaned;

---Step 6: Final Check: Count outliers

SELECT 
    COUNT(*) AS total_rows,
    SUM(CASE WHEN is_outlier = 1 THEN 1 ELSE 0 END) AS outlier_count,
    ROUND(
        CAST(SUM(CASE WHEN is_outlier = 1 THEN 1 ELSE 0 END) AS FLOAT) / COUNT(*) * 100, 2
    ) AS outlier_percent
FROM vw_ibdr_outliers;

---To see only the outliers

SELECT *
FROM vw_ibdr_outliers
WHERE is_outlier = 1;


--SHAPING DATA
---Caculate YoY growth

SELECT
    countryEconomy,
    region,
    fiscalYear,
    netFlow AS NetFlow_capped,
    ROUND(
        (netFlow - LAG(netFlow) OVER (PARTITION BY countryEconomy ORDER BY fiscalYear)) * 1.0 /
        NULLIF(LAG(netFlow) OVER (PARTITION BY countryEconomy ORDER BY fiscalYear), 0), 6
    ) AS YoY_growth
FROM ibdr_cleaned
ORDER BY countryEconomy, fiscalYear;

---Aggregate regions 

SELECT
    region,
    fiscalYear,
    SUM(netFlow) AS region_netflow,
    SUM(IBRDCommitments) AS region_commit,
    SUM(repayments) AS region_repay
FROM ibdr_cleaned
GROUP BY region, fiscalYear
ORDER BY region, fiscalYear;


--ANALYZING DATA
---Rank countries by variance vs. commitments (last year)

;WITH latest_year AS (
    SELECT MAX(fiscalYear) AS max_year
    FROM dbo.ibdr_cleaned
),
ranked_variance AS (
    SELECT
        countryEconomy,
        region,
        fiscalYear,
        grossDisbursement,
        repayments,
        netFlow,
        IBRDCommitments,
        CAST(netFlow AS FLOAT) - CAST(IBRDCommitments AS FLOAT) AS variance_vs_commitments,
        RANK() OVER (
            ORDER BY CAST(netFlow AS FLOAT) - CAST(IBRDCommitments AS FLOAT) DESC
        ) AS variance_rank
    FROM dbo.ibdr_cleaned
    WHERE fiscalYear = (SELECT max_year FROM latest_year)
)
SELECT *
FROM ranked_variance
ORDER BY variance_rank;

---Countries faces the highest debt-service burden

;WITH latest_year AS (
  SELECT MAX(fiscalYear) AS max_year FROM dbo.ibdr_cleaned
)
SELECT TOP (10)
  countryEconomy,
  fiscalYear,
  grossDisbursement,
  repayments,
  CAST(repayments AS FLOAT) / NULLIF(grossDisbursement, 0) AS debt_service_ratio
FROM dbo.ibdr_cleaned
WHERE fiscalYear = (SELECT max_year FROM latest_year)
  AND grossDisbursement > 0
ORDER BY debt_service_ratio DESC;


---Calculate Debt-Service ratio distribution

SELECT
    CASE 
        WHEN CAST(repayments AS FLOAT) / NULLIF(grossDisbursement, 0) < 0.25 THEN 'Under 25%'
        WHEN CAST(repayments AS FLOAT) / NULLIF(grossDisbursement, 0) < 0.50 THEN '25% - 50%'
        WHEN CAST(repayments AS FLOAT) / NULLIF(grossDisbursement, 0) < 0.75 THEN '50% - 75%'
        WHEN CAST(repayments AS FLOAT) / NULLIF(grossDisbursement, 0) < 1.00 THEN '75% - 100%'
        ELSE 'Over 100%'
    END AS ratio_range,
    COUNT(*) AS count_in_range
FROM ibdr_cleaned
WHERE grossDisbursement > 0
GROUP BY 
    CASE 
        WHEN CAST(repayments AS FLOAT) / NULLIF(grossDisbursement, 0) < 0.25 THEN 'Under 25%'
        WHEN CAST(repayments AS FLOAT) / NULLIF(grossDisbursement, 0) < 0.50 THEN '25% - 50%'
        WHEN CAST(repayments AS FLOAT) / NULLIF(grossDisbursement, 0) < 0.75 THEN '50% - 75%'
        WHEN CAST(repayments AS FLOAT) / NULLIF(grossDisbursement, 0) < 1.00 THEN '75% - 100%'
        ELSE 'Over 100%'
    END
ORDER BY ratio_range;

---Forecast next year's netFlow
--Step 1: Prepare base data

WITH base_data AS (
    SELECT 
        FiscalYear,
        CountryEconomy,
        AVG(NetFlow) AS avg_netflow
    FROM ibdr_cleaned
    GROUP BY CountryEconomy, FiscalYear
),

---Step 2: Compute regression stats per country

stats AS (
    SELECT 
        CountryEconomy,
        COUNT(*) AS n,
        SUM(FiscalYear) AS sum_x,
        SUM(avg_netflow) AS sum_y,
        SUM(FiscalYear * avg_netflow) AS sum_xy,
        SUM(FiscalYear * FiscalYear) AS sum_x2
    FROM base_data
    GROUP BY CountryEconomy
),

---Step 3: Calculate slope and intercept


regression AS (
    SELECT
        CountryEconomy,
        CAST((n * sum_xy - sum_x * sum_y) AS FLOAT) /
            NULLIF((n * sum_x2 - sum_x * sum_x), 0) AS slope,
        CAST((sum_y - 
              ((n * sum_xy - sum_x * sum_y) / NULLIF((n * sum_x2 - sum_x * sum_x), 0)) * sum_x
            ) AS FLOAT) / n AS intercept
    FROM stats
),

---Step 4: Forecast netflow for 2026 (hardcoded)

forecast AS (
    SELECT 
        CountryEconomy,
        2026 AS forecast_year,
        ROUND(slope * 2026 + intercept, 0) AS forecast_netflow
    FROM regression
)

---Step 5: Output

SELECT * FROM forecast
ORDER BY forecast_netflow DESC;

---Calculate an interest-rate shock scenario
---Interest Rate Shock Scenario allows shocks between -2% and +5%

---Step 1: Set the interest rate shock parameter

DECLARE @InterestRateShock FLOAT = 0.03;  -- change this value as needed

---Step 2: Validate shock range to avoid bad inputs

IF @InterestRateShock < -0.02 OR @InterestRateShock > 0.05
BEGIN
    RAISERROR ('Interest Rate Shock must be between -2%% and +5%%.', 16, 1);
    RETURN;
END

---Step 3: Create temp table for scenario results

;WITH latest_year AS (
    SELECT MAX(fiscalYear) AS max_year
    FROM dbo.ibdr_data  
)
SELECT
    countryEconomy,
    fiscalYear,
    grossDisbursement,
    repayments,
    netDisbursement,
    interest,
    ROUND(interest * (1 + @InterestRateShock), 2) AS shocked_interest,
    ROUND(netDisbursement - (interest * @InterestRateShock), 2) AS netFlow_shocked,
    ROUND((repayments + (interest * @InterestRateShock)) / NULLIF(grossDisbursement, 0), 4) AS debt_service_ratio_shocked,
    ROUND((netDisbursement - (interest * @InterestRateShock)) - netDisbursement, 2) AS netFlow_impact
INTO #shock_scenario
FROM dbo.ibdr_data
WHERE fiscalYear = (SELECT max_year FROM latest_year);

---Step 4: View full results

SELECT *
FROM #shock_scenario
ORDER BY countryEconomy;

---Step 5: Top 10 most negatively impacted countries

SELECT TOP 10 *
FROM #shock_scenario
ORDER BY netFlow_impact ASC;
