/* =====================================================================
   Calgary Housing Permits Pipeline
   01 - Create schemas (medallion layers inside Azure SQL Database)

   stg    : raw CSV loaded as-is by ADF (all NVARCHAR)
   silver : cleaned, typed, deduplicated permits
   gold   : star schema for Power BI

   Note: Bronze lives in ADLS Gen2 (bronze/building_permits/building_permits.csv)
   ===================================================================== */

CREATE SCHEMA stg;
GO
CREATE SCHEMA silver;
GO
CREATE SCHEMA gold;
GO
