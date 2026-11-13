/* =====================================================================
   Calgary Housing Permits Pipeline
   02 - Silver layer: silver.building_permits + load procedure

   Source : stg.building_permits_raw (auto-created by ADF, all NVARCHAR(MAX))
   Rules  : - dates (yyyy/mm/dd) -> DATE via TRY_CONVERT style 111
            - costs, sq ft, units, lat/long -> numeric via TRY_CAST
            - trim text, empty strings -> NULL
            - one row per PermitNum (ROW_NUMBER dedupe)
            - drops bulky geometry columns (LocationAddresses,
              LocationsWKT, LocationsGeoJSON, Point); lat/long kept
   Called : ADF activity sp_load_silver
   ===================================================================== */

CREATE TABLE silver.building_permits (
    permit_num          NVARCHAR(50)   NOT NULL PRIMARY KEY,
    status_current      NVARCHAR(100),
    applied_date        DATE,
    issued_date         DATE,
    completed_date      DATE,
    permit_type         NVARCHAR(150),
    permit_type_mapped  NVARCHAR(100),
    permit_class        NVARCHAR(150),
    permit_class_group  NVARCHAR(100),
    permit_class_mapped NVARCHAR(100),
    work_class          NVARCHAR(100),
    work_class_group    NVARCHAR(100),
    work_class_mapped   NVARCHAR(100),
    description         NVARCHAR(1000),
    applicant_name      NVARCHAR(255),
    contractor_name     NVARCHAR(255),
    housing_units       INT,
    est_project_cost    DECIMAL(18,2),
    total_sqft          DECIMAL(18,2),
    original_address    NVARCHAR(255),
    community_code      NVARCHAR(20),
    community_name      NVARCHAR(150),
    latitude            DECIMAL(9,6),
    longitude           DECIMAL(9,6),
    location_count      INT,
    load_ts             DATETIME2 DEFAULT SYSUTCDATETIME()
);
GO

CREATE OR ALTER PROCEDURE silver.usp_load_building_permits
AS
BEGIN
    SET NOCOUNT ON;

    TRUNCATE TABLE silver.building_permits;

    WITH src AS (
        SELECT *,
               ROW_NUMBER() OVER (
                   PARTITION BY CAST(LTRIM(RTRIM(PermitNum)) AS NVARCHAR(50))
                   ORDER BY TRY_CONVERT(DATE, LEFT(CompletedDate, 10), 111) DESC,
                            TRY_CONVERT(DATE, LEFT(IssuedDate, 10), 111) DESC
               ) AS rn
        FROM stg.building_permits_raw
        WHERE NULLIF(LTRIM(RTRIM(PermitNum)), '') IS NOT NULL
    )
    INSERT INTO silver.building_permits (
        permit_num, status_current, applied_date, issued_date, completed_date,
        permit_type, permit_type_mapped, permit_class, permit_class_group, permit_class_mapped,
        work_class, work_class_group, work_class_mapped, description,
        applicant_name, contractor_name, housing_units, est_project_cost, total_sqft,
        original_address, community_code, community_name, latitude, longitude, location_count
    )
    SELECT
        LEFT(LTRIM(RTRIM(PermitNum)), 50),
        LEFT(NULLIF(LTRIM(RTRIM(StatusCurrent)), ''), 100),
        TRY_CONVERT(DATE, LEFT(AppliedDate, 10), 111),
        TRY_CONVERT(DATE, LEFT(IssuedDate, 10), 111),
        TRY_CONVERT(DATE, LEFT(CompletedDate, 10), 111),
        LEFT(NULLIF(LTRIM(RTRIM(PermitType)), ''), 150),
        LEFT(NULLIF(LTRIM(RTRIM(PermitTypeMapped)), ''), 100),
        LEFT(NULLIF(LTRIM(RTRIM(PermitClass)), ''), 150),
        LEFT(NULLIF(LTRIM(RTRIM(PermitClassGroup)), ''), 100),
        LEFT(NULLIF(LTRIM(RTRIM(PermitClassMapped)), ''), 100),
        LEFT(NULLIF(LTRIM(RTRIM(WorkClass)), ''), 100),
        LEFT(NULLIF(LTRIM(RTRIM(WorkClassGroup)), ''), 100),
        LEFT(NULLIF(LTRIM(RTRIM(WorkClassMapped)), ''), 100),
        LEFT(NULLIF(LTRIM(RTRIM(Description)), ''), 1000),
        LEFT(NULLIF(LTRIM(RTRIM(ApplicantName)), ''), 255),
        LEFT(NULLIF(LTRIM(RTRIM(ContractorName)), ''), 255),
        TRY_CAST(TRY_CAST(NULLIF(LTRIM(RTRIM(HousingUnits)), '') AS DECIMAL(18,2)) AS INT),
        TRY_CAST(NULLIF(LTRIM(RTRIM(EstProjectCost)), '') AS DECIMAL(18,2)),
        TRY_CAST(NULLIF(LTRIM(RTRIM(TotalSqFt)), '') AS DECIMAL(18,2)),
        LEFT(NULLIF(LTRIM(RTRIM(OriginalAddress)), ''), 255),
        LEFT(NULLIF(LTRIM(RTRIM(CommunityCode)), ''), 20),
        LEFT(NULLIF(LTRIM(RTRIM(CommunityName)), ''), 150),
        TRY_CAST(NULLIF(LTRIM(RTRIM(Latitude)), '') AS DECIMAL(9,6)),
        TRY_CAST(NULLIF(LTRIM(RTRIM(Longitude)), '') AS DECIMAL(9,6)),
        TRY_CAST(TRY_CAST(NULLIF(LTRIM(RTRIM(LocationCount)), '') AS DECIMAL(18,2)) AS INT)
    FROM src
    WHERE rn = 1;
END;
GO
