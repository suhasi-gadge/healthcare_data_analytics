-- ============================================================================
-- HEALTHCARE ANALYTICS PROJECT
-- Script:  01_load_data.sql
-- Purpose: Load CSV data into PostgreSQL tables
-- Target:  PostgreSQL 14+ / pgAdmin 4
-- ============================================================================
-- 
-- IMPORTANT: Before running this script, ensure:
--   1. You have run 00_create_schema.sql to create all tables
--   2. CSV files are accessible from the PostgreSQL server's file system
--   3. Update the file paths below to match your local CSV directory
--
-- TWO LOADING OPTIONS:
--   Option A: COPY command (run from psql or pgAdmin query tool)
--   Option B: pgAdmin Import/Export wizard (GUI — no SQL needed)
--
-- ============================================================================

SET search_path TO healthcare;

-- ============================================================================
-- OPTION A: COPY COMMANDS
-- ============================================================================
-- Update '/path/to/csv/' to your actual file location, e.g.:
--   Windows: 'C:/Users/Suhasi/Data/synthea_csv/'
--   Mac/Linux: '/home/suhasi/data/synthea_csv/'
-- ============================================================================

-- Load dimension tables first (no foreign key dependencies)

COPY organizations
FROM '/path/to/csv/organizations.csv'
WITH (FORMAT csv, HEADER true, DELIMITER ',');

COPY providers
FROM '/path/to/csv/providers.csv'
WITH (FORMAT csv, HEADER true, DELIMITER ',');

COPY payers
FROM '/path/to/csv/payers.csv'
WITH (FORMAT csv, HEADER true, DELIMITER ',');

COPY patients
FROM '/path/to/csv/patients.csv'
WITH (FORMAT csv, HEADER true, DELIMITER ',');

-- Load fact tables (depend on dimension tables above)

COPY encounters
FROM '/path/to/csv/encounters.csv'
WITH (FORMAT csv, HEADER true, DELIMITER ',');

COPY conditions
FROM '/path/to/csv/conditions.csv'
WITH (FORMAT csv, HEADER true, DELIMITER ',');

COPY medications
FROM '/path/to/csv/medications.csv'
WITH (FORMAT csv, HEADER true, DELIMITER ',');

COPY procedures
FROM '/path/to/csv/procedures.csv'
WITH (FORMAT csv, HEADER true, DELIMITER ',');

COPY observations
FROM '/path/to/csv/observations.csv'
WITH (FORMAT csv, HEADER true, DELIMITER ',');

COPY allergies
FROM '/path/to/csv/allergies.csv'
WITH (FORMAT csv, HEADER true, DELIMITER ',');

COPY careplans
FROM '/path/to/csv/careplans.csv'
WITH (FORMAT csv, HEADER true, DELIMITER ',');

COPY immunizations
FROM '/path/to/csv/immunizations.csv'
WITH (FORMAT csv, HEADER true, DELIMITER ',');

COPY devices
FROM '/path/to/csv/devices.csv'
WITH (FORMAT csv, HEADER true, DELIMITER ',');

COPY imaging_studies
FROM '/path/to/csv/imaging_studies.csv'
WITH (FORMAT csv, HEADER true, DELIMITER ',');

COPY payer_transitions
FROM '/path/to/csv/payer_transitions.csv'
WITH (FORMAT csv, HEADER true, DELIMITER ',');

-- ============================================================================
-- OPTION B: pgAdmin Import/Export Wizard (GUI)
-- ============================================================================
-- 
-- 1. Right-click the target table in pgAdmin → Import/Export Data
-- 2. Toggle to "Import"
-- 3. Set Format: csv | Header: Yes | Delimiter: ,
-- 4. Browse to the CSV file
-- 5. Click OK
--
-- Load in this order to respect foreign keys:
--   1. organizations  →  2. providers  →  3. payers  →  4. patients
--   5. encounters     →  6. conditions →  7. medications → 8. procedures
--   9. observations   → 10. allergies  → 11. careplans   → 12. immunizations
--  13. devices        → 14. imaging_studies → 15. payer_transitions
--
-- Note: supplies.csv is empty (0 data rows) — skip it.
-- ============================================================================


-- ============================================================================
-- POST-LOAD VALIDATION
-- ============================================================================
-- Run these queries after loading to verify row counts match the source CSVs.

SELECT 'organizations'     AS table_name, COUNT(*) AS row_count FROM organizations     UNION ALL
SELECT 'providers',                       COUNT(*)              FROM providers          UNION ALL
SELECT 'payers',                          COUNT(*)              FROM payers             UNION ALL
SELECT 'patients',                        COUNT(*)              FROM patients           UNION ALL
SELECT 'encounters',                      COUNT(*)              FROM encounters         UNION ALL
SELECT 'conditions',                      COUNT(*)              FROM conditions         UNION ALL
SELECT 'medications',                     COUNT(*)              FROM medications        UNION ALL
SELECT 'procedures',                      COUNT(*)              FROM procedures         UNION ALL
SELECT 'observations',                    COUNT(*)              FROM observations       UNION ALL
SELECT 'allergies',                       COUNT(*)              FROM allergies          UNION ALL
SELECT 'careplans',                       COUNT(*)              FROM careplans          UNION ALL
SELECT 'immunizations',                   COUNT(*)              FROM immunizations      UNION ALL
SELECT 'devices',                         COUNT(*)              FROM devices            UNION ALL
SELECT 'imaging_studies',                 COUNT(*)              FROM imaging_studies    UNION ALL
SELECT 'payer_transitions',               COUNT(*)              FROM payer_transitions
ORDER BY table_name;

-- Expected row counts:
-- ┌────────────────────┬───────────┐
-- │ table_name         │ row_count │
-- ├────────────────────┼───────────┤
-- │ allergies          │       597 │
-- │ careplans          │     3,483 │
-- │ conditions         │     8,376 │
-- │ devices            │        78 │
-- │ encounters         │    53,346 │
-- │ imaging_studies    │       855 │
-- │ immunizations      │    15,478 │
-- │ medications        │    42,989 │
-- │ observations       │   299,697 │
-- │ organizations      │     1,119 │
-- │ patients           │     1,171 │
-- │ payer_transitions  │     3,801 │
-- │ payers             │        10 │
-- │ procedures         │    34,981 │
-- │ providers          │     5,855 │
-- └────────────────────┴───────────┘
