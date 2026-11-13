CREATE OR ALTER PROCEDURE gold.usp_load_gold
AS
BEGIN
    SET NOCOUNT ON;


    IF OBJECT_ID('tempdb..#grain') IS NOT NULL DROP TABLE #grain;

    SELECT
        p.permit_num, p.applied_date, p.issued_date,
        p.housing_units, p.est_project_cost, p.latitude, p.longitude,
        p.community_code, p.community_name,
        CASE
            WHEN LEFT(p.permit_class, 4) IN ('1106','1108')        THEN 1  -- Single Detached
            WHEN LEFT(p.permit_class, 4) IN ('1110','1111','1112') THEN 2  -- Secondary Suite
            WHEN LEFT(p.permit_class, 4) IN ('1113','1114')        THEN 3  -- Backyard Suite
            WHEN LEFT(p.permit_class, 4) IN ('1406','1407','1408') THEN 4  -- Semi-Detached / Duplex
            WHEN LEFT(p.permit_class, 4) = '1606'                  THEN 5  -- Townhouse
            WHEN LEFT(p.permit_class, 4) = '1706'                  THEN 6  -- Rowhouse
            WHEN LEFT(p.permit_class, 4) IN ('1507','1508')        THEN 7  -- Triplex / Fourplex
            WHEN LEFT(p.permit_class, 4) IN ('1502','1506')        THEN 8  -- Apartment
            ELSE 9                                                         -- Other / Unspecified
        END AS housing_type_key,
        NULLIF(UPPER(LTRIM(RTRIM(REPLACE(REPLACE(p.contractor_name, '  ', ' '), '  ', ' ')))), '') AS contractor_clean
    INTO #grain
    FROM silver.building_permits p
    WHERE p.housing_units > 0
      AND p.issued_date >= '2022-01-01';

   
    DECLARE @start_date DATE, @end_date DATE, @max_data_date DATE;

    SELECT @start_date = DATEFROMPARTS(YEAR(MIN(applied_date)), 1, 1),
           @end_date   = DATEFROMPARTS(YEAR(MAX(issued_date)), 12, 31)
    FROM #grain;

    IF @start_date IS NULL OR @start_date > '2022-01-01' SET @start_date = '2022-01-01';

    SELECT @max_data_date = MAX(issued_date) FROM silver.building_permits;

   
    TRUNCATE TABLE gold.fact_permit;
    DELETE FROM gold.dim_date;
    DELETE FROM gold.dim_community;
    DELETE FROM gold.dim_housing_type;
    DELETE FROM gold.dim_contractor;
    DBCC CHECKIDENT ('gold.dim_community',  RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('gold.dim_contractor', RESEED, 0) WITH NO_INFOMSGS;

  
    WITH n AS (
        SELECT TOP (DATEDIFF(DAY, @start_date, @end_date) + 1)
               ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS i
        FROM sys.all_objects a CROSS JOIN sys.all_objects b
    ),
    d AS (SELECT DATEADD(DAY, i, @start_date) AS dt FROM n)
    INSERT INTO gold.dim_date
    SELECT
        YEAR(dt) * 10000 + MONTH(dt) * 100 + DAY(dt),
        dt,
        YEAR(dt),
        DATEPART(QUARTER, dt),
        MONTH(dt),
        DATENAME(MONTH, dt),
        CONVERT(CHAR(7), dt, 126),
        CASE WHEN dt < '2024-08-06' THEN 'Pre-rezoning'
             WHEN dt < '2026-08-04' THEN 'Citywide rezoning'
             ELSE 'Post-repeal' END,
        CASE WHEN dt < '2024-08-06' THEN 1
             WHEN dt < '2026-08-04' THEN 2
             ELSE 3 END,
        CASE WHEN EOMONTH(dt) <= @max_data_date THEN 1 ELSE 0 END
    FROM d;

    
    INSERT INTO gold.dim_housing_type (housing_type_key, housing_type, is_missing_middle, sort_order)
    VALUES (1, 'Single Detached',        0, 1),
           (2, 'Secondary Suite',        0, 2),
           (3, 'Backyard Suite',         0, 3),
           (4, 'Semi-Detached / Duplex', 1, 4),
           (5, 'Townhouse',              1, 5),
           (6, 'Rowhouse',               1, 6),
           (7, 'Triplex / Fourplex',     1, 7),
           (8, 'Apartment',              0, 8),
           (9, 'Other / Unspecified',    0, 9);

   
    SET IDENTITY_INSERT gold.dim_community ON;
    INSERT INTO gold.dim_community (community_key, community_code, community_name)
    VALUES (-1, 'UNK', 'Unknown');
    SET IDENTITY_INSERT gold.dim_community OFF;

    INSERT INTO gold.dim_community (community_code, community_name)
    SELECT community_code, MAX(community_name)
    FROM #grain
    WHERE community_code IS NOT NULL
    GROUP BY community_code;

  
    SET IDENTITY_INSERT gold.dim_contractor ON;
    INSERT INTO gold.dim_contractor (contractor_key, contractor_name)
    VALUES (-1, 'Unknown');
    SET IDENTITY_INSERT gold.dim_contractor OFF;

    INSERT INTO gold.dim_contractor (contractor_name)
    SELECT DISTINCT contractor_clean
    FROM #grain
    WHERE contractor_clean IS NOT NULL;

    INSERT INTO gold.fact_permit
    SELECT
        g.permit_num,
        YEAR(g.issued_date) * 10000 + MONTH(g.issued_date) * 100 + DAY(g.issued_date),
        CASE WHEN g.applied_date IS NULL THEN NULL
             ELSE YEAR(g.applied_date) * 10000 + MONTH(g.applied_date) * 100 + DAY(g.applied_date) END,
        ISNULL(c.community_key, -1),
        g.housing_type_key,
        ISNULL(k.contractor_key, -1),
        g.housing_units,
        g.est_project_cost,
        g.latitude,
        g.longitude
    FROM #grain g
    LEFT JOIN gold.dim_community  c ON c.community_code  = g.community_code
    LEFT JOIN gold.dim_contractor k ON k.contractor_name = g.contractor_clean;
END;