/* =====================================================================
   Calgary Housing Permits Pipeline
   04 - Validation checks (run after each pipeline load)

   Results from the Nov 9, 2026 load:
     stg     : 503,585 rows (= ADF rows read/written)
     silver  : 503,585 rows, 0 duplicates, all applied dates converted
               39,120 permits blank cost in source, 0 failed conversions
     gold    : 47,249 permits, 100,986 housing units, 0 orphan dates,
               0 unknown communities, 10,666 unknown contractors
               (mostly secondary suites / unspecified = homeowner-led)
   ===================================================================== */

/* 1. Staging row count (compare with ADF Copy activity rows written) */
SELECT COUNT(*) AS stg_rows FROM stg.building_permits_raw;

/* 2. Silver completeness */
SELECT
    COUNT(*)                 AS total_rows,
    COUNT(applied_date)      AS has_applied,
    COUNT(issued_date)       AS has_issued,
    COUNT(completed_date)    AS has_completed,
    COUNT(est_project_cost)  AS has_cost,
    COUNT(latitude)          AS has_lat,
    MIN(applied_date)        AS first_applied,
    MAX(applied_date)        AS last_applied
FROM silver.building_permits;

/* 3. Missing cost: blank at source vs failed conversion */
SELECT
    SUM(CASE WHEN NULLIF(LTRIM(RTRIM(EstProjectCost)), '') IS NULL THEN 1 ELSE 0 END) AS blank_in_source,
    SUM(CASE WHEN NULLIF(LTRIM(RTRIM(EstProjectCost)), '') IS NOT NULL
              AND TRY_CAST(EstProjectCost AS DECIMAL(18,2)) IS NULL THEN 1 ELSE 0 END) AS failed_conversion
FROM stg.building_permits_raw;

/* 4. Gold reconciliation */
SELECT
    (SELECT COUNT(*)           FROM gold.fact_permit)                         AS fact_rows,
    (SELECT SUM(housing_units) FROM gold.fact_permit)                         AS fact_units,
    (SELECT COUNT(*)           FROM gold.dim_community)                       AS communities,
    (SELECT COUNT(*)           FROM gold.dim_contractor)                      AS contractors,
    (SELECT COUNT(*)           FROM gold.dim_date)                            AS date_rows,
    (SELECT COUNT(*) FROM gold.fact_permit WHERE community_key  = -1)         AS unknown_community,
    (SELECT COUNT(*) FROM gold.fact_permit WHERE contractor_key = -1)         AS unknown_contractor,
    (SELECT COUNT(*) FROM gold.fact_permit f
       LEFT JOIN gold.dim_date d ON d.date_key = f.issued_date_key
       WHERE d.date_key IS NULL)                                              AS orphan_dates;

/* 5. Gold units must equal Silver units for the same grain */
SELECT
    (SELECT SUM(housing_units) FROM gold.fact_permit) AS gold_units,
    (SELECT SUM(housing_units) FROM silver.building_permits
      WHERE housing_units > 0 AND issued_date >= '2022-01-01') AS silver_units;

/* 6. Where unknown contractors fall */
SELECT h.housing_type, COUNT(*) AS no_contractor
FROM gold.fact_permit f
JOIN gold.dim_housing_type h ON h.housing_type_key = f.housing_type_key
WHERE f.contractor_key = -1
GROUP BY h.housing_type
ORDER BY no_contractor DESC;
