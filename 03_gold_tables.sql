CREATE TABLE gold.dim_date (
    date_key            INT          NOT NULL,
    full_date           DATE         NOT NULL,
    [year]              INT,
    [quarter]           INT,
    month_num           INT,
    month_name          NVARCHAR(20),
    year_month          CHAR(7),
    policy_period       NVARCHAR(30),
    policy_period_sort  INT,
    is_complete_month   BIT,
    CONSTRAINT PK_dim_date PRIMARY KEY (date_key)
);

CREATE TABLE gold.dim_community (
    community_key   INT IDENTITY(1,1) NOT NULL,
    community_code  NVARCHAR(20),
    community_name  NVARCHAR(150),
    CONSTRAINT PK_dim_community PRIMARY KEY (community_key)
);

CREATE TABLE gold.dim_housing_type (
    housing_type_key   INT NOT NULL,
    housing_type       NVARCHAR(50),
    is_missing_middle  BIT,
    sort_order         INT,
    CONSTRAINT PK_dim_housing_type PRIMARY KEY (housing_type_key)
);

CREATE TABLE gold.dim_contractor (
    contractor_key   INT IDENTITY(1,1) NOT NULL,
    contractor_name  NVARCHAR(255),
    CONSTRAINT PK_dim_contractor PRIMARY KEY (contractor_key)
);

CREATE TABLE gold.fact_permit (
    permit_num        NVARCHAR(50) NOT NULL,
    issued_date_key   INT NOT NULL,
    applied_date_key  INT,
    community_key     INT NOT NULL,
    housing_type_key  INT NOT NULL,
    contractor_key    INT NOT NULL,
    housing_units     INT,
    est_project_cost  DECIMAL(18,2),
    latitude          DECIMAL(9,6),
    longitude         DECIMAL(9,6),
    CONSTRAINT PK_fact_permit              PRIMARY KEY (permit_num),
    CONSTRAINT FK_fact_permit_issued_date  FOREIGN KEY (issued_date_key)  REFERENCES gold.dim_date (date_key),
    CONSTRAINT FK_fact_permit_applied_date FOREIGN KEY (applied_date_key) REFERENCES gold.dim_date (date_key),
    CONSTRAINT FK_fact_permit_community    FOREIGN KEY (community_key)    REFERENCES gold.dim_community (community_key),
    CONSTRAINT FK_fact_permit_housing_type FOREIGN KEY (housing_type_key) REFERENCES gold.dim_housing_type (housing_type_key),
    CONSTRAINT FK_fact_permit_contractor   FOREIGN KEY (contractor_key)   REFERENCES gold.dim_contractor (contractor_key)
);