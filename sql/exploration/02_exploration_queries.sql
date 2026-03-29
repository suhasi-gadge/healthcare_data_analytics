-- ============================================================================
-- HEALTHCARE ANALYTICS PROJECT
-- Script:  02_exploration_queries.sql
-- Purpose: Exploratory queries to understand data patterns and validate quality
-- Target:  PostgreSQL 14+ / pgAdmin 4
-- ============================================================================

SET search_path TO healthcare;


-- ============================================================================
-- SECTION 1: PATIENT DEMOGRAPHICS EXPLORATION
-- ============================================================================

-- 1.1  Patient count by gender
SELECT 
    gender,
    COUNT(*) AS patient_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 1) AS pct
FROM patients
GROUP BY gender
ORDER BY patient_count DESC;


-- 1.2  Age distribution (bucketed into 10-year bands)
SELECT 
    CASE 
        WHEN AGE_YEARS < 10  THEN '0-9'
        WHEN AGE_YEARS < 20  THEN '10-19'
        WHEN AGE_YEARS < 30  THEN '20-29'
        WHEN AGE_YEARS < 40  THEN '30-39'
        WHEN AGE_YEARS < 50  THEN '40-49'
        WHEN AGE_YEARS < 60  THEN '50-59'
        WHEN AGE_YEARS < 70  THEN '60-69'
        WHEN AGE_YEARS < 80  THEN '70-79'
        WHEN AGE_YEARS < 90  THEN '80-89'
        ELSE '90+'
    END AS age_group,
    COUNT(*) AS patient_count
FROM (
    SELECT 
        EXTRACT(YEAR FROM AGE(DATE '2020-04-01', birthdate)) AS AGE_YEARS
    FROM patients
) sub
GROUP BY age_group
ORDER BY age_group;


-- 1.3  Race and ethnicity breakdown
SELECT 
    race,
    ethnicity,
    COUNT(*) AS patient_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 1) AS pct
FROM patients
GROUP BY race, ethnicity
ORDER BY patient_count DESC;


-- 1.4  Geographic distribution — top 10 cities
SELECT 
    city,
    state,
    COUNT(*) AS patient_count
FROM patients
GROUP BY city, state
ORDER BY patient_count DESC
LIMIT 10;


-- 1.5  Alive vs deceased patients with average age
SELECT 
    CASE WHEN deathdate IS NULL THEN 'Alive' ELSE 'Deceased' END AS vital_status,
    COUNT(*) AS patient_count,
    ROUND(AVG(EXTRACT(YEAR FROM AGE(
        COALESCE(deathdate, DATE '2020-04-01'), birthdate
    ))), 1) AS avg_age
FROM patients
GROUP BY vital_status;


-- ============================================================================
-- SECTION 2: ENCOUNTER PATTERNS
-- ============================================================================

-- 2.1  Encounters by class (ambulatory, emergency, inpatient, etc.)
SELECT 
    encounterclass,
    COUNT(*) AS encounter_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 1) AS pct,
    ROUND(AVG(total_claim_cost), 2) AS avg_cost,
    ROUND(SUM(total_claim_cost), 2) AS total_cost
FROM encounters
GROUP BY encounterclass
ORDER BY encounter_count DESC;


-- 2.2  Encounters per year — trend over time
SELECT 
    EXTRACT(YEAR FROM start) AS encounter_year,
    COUNT(*) AS encounter_count,
    ROUND(SUM(total_claim_cost), 2) AS total_cost
FROM encounters
GROUP BY encounter_year
ORDER BY encounter_year;


-- 2.3  Average encounters per patient
SELECT 
    ROUND(AVG(enc_count), 1) AS avg_encounters_per_patient,
    MIN(enc_count) AS min_encounters,
    MAX(enc_count) AS max_encounters,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY enc_count) AS median_encounters
FROM (
    SELECT patient, COUNT(*) AS enc_count
    FROM encounters
    GROUP BY patient
) sub;


-- 2.4  Top 10 most common encounter reasons
SELECT 
    description,
    COUNT(*) AS encounter_count,
    ROUND(AVG(total_claim_cost), 2) AS avg_cost
FROM encounters
GROUP BY description
ORDER BY encounter_count DESC
LIMIT 10;


-- 2.5  Encounter duration analysis (average hours by class)
SELECT 
    encounterclass,
    COUNT(*) AS encounter_count,
    ROUND(AVG(EXTRACT(EPOCH FROM (stop - start)) / 3600.0), 1) AS avg_hours
FROM encounters
WHERE stop IS NOT NULL
GROUP BY encounterclass
ORDER BY avg_hours DESC;


-- ============================================================================
-- SECTION 3: CLINICAL CONDITIONS EXPLORATION
-- ============================================================================

-- 3.1  Top 20 diagnosed conditions
SELECT 
    description,
    COUNT(*) AS diagnosis_count,
    COUNT(DISTINCT patient) AS unique_patients
FROM conditions
GROUP BY description
ORDER BY diagnosis_count DESC
LIMIT 20;


-- 3.2  Chronic vs resolved conditions
SELECT 
    CASE WHEN stop IS NULL THEN 'Active/Chronic' ELSE 'Resolved' END AS status,
    COUNT(*) AS condition_count,
    COUNT(DISTINCT patient) AS unique_patients
FROM conditions
GROUP BY status;


-- 3.3  Patients with the most conditions (high-complexity patients)
SELECT 
    p.first || ' ' || p.last AS patient_name,
    p.gender,
    EXTRACT(YEAR FROM AGE(DATE '2020-04-01', p.birthdate))::INT AS age,
    COUNT(DISTINCT c.code) AS unique_conditions,
    COUNT(*) AS total_condition_records
FROM conditions c
JOIN patients p ON c.patient = p.id
GROUP BY p.id, p.first, p.last, p.gender, p.birthdate
ORDER BY unique_conditions DESC
LIMIT 15;


-- 3.4  Conditions by age group
SELECT 
    CASE 
        WHEN AGE_YEARS < 18  THEN 'Pediatric (0-17)'
        WHEN AGE_YEARS < 40  THEN 'Young Adult (18-39)'
        WHEN AGE_YEARS < 65  THEN 'Middle Age (40-64)'
        ELSE 'Senior (65+)'
    END AS age_group,
    c.description AS condition,
    COUNT(*) AS diagnosis_count
FROM conditions c
JOIN (
    SELECT id, EXTRACT(YEAR FROM AGE(DATE '2020-04-01', birthdate)) AS AGE_YEARS
    FROM patients
) p ON c.patient = p.id
GROUP BY age_group, c.description
ORDER BY age_group, diagnosis_count DESC;


-- ============================================================================
-- SECTION 4: DATA QUALITY CHECKS
-- ============================================================================

-- 4.1  Orphan check: encounters referencing non-existent patients
SELECT COUNT(*) AS orphan_encounters
FROM encounters e
LEFT JOIN patients p ON e.patient = p.id
WHERE p.id IS NULL;


-- 4.2  Orphan check: conditions referencing non-existent encounters
SELECT COUNT(*) AS orphan_conditions
FROM conditions c
LEFT JOIN encounters e ON c.encounter = e.id
WHERE e.id IS NULL;


-- 4.3  Null analysis across key columns
SELECT 
    'patients'   AS tbl, 'deathdate'  AS col, COUNT(*) FILTER (WHERE deathdate IS NULL) AS null_count, COUNT(*) AS total FROM patients
UNION ALL
SELECT 
    'encounters', 'reasoncode', COUNT(*) FILTER (WHERE reasoncode IS NULL), COUNT(*) FROM encounters
UNION ALL
SELECT 
    'encounters', 'stop', COUNT(*) FILTER (WHERE stop IS NULL), COUNT(*) FROM encounters
UNION ALL
SELECT 
    'conditions', 'stop', COUNT(*) FILTER (WHERE stop IS NULL), COUNT(*) FROM conditions
UNION ALL
SELECT 
    'medications', 'stop', COUNT(*) FILTER (WHERE stop IS NULL), COUNT(*) FROM medications
UNION ALL
SELECT 
    'medications', 'reasoncode', COUNT(*) FILTER (WHERE reasoncode IS NULL), COUNT(*) FROM medications;


-- 4.4  Duplicate check — patients table
SELECT 
    id, COUNT(*) AS dup_count
FROM patients
GROUP BY id
HAVING COUNT(*) > 1;


-- 4.5  Date sanity check — encounters where stop < start
SELECT COUNT(*) AS invalid_date_encounters
FROM encounters
WHERE stop < start;


-- ============================================================================
-- SECTION 5: PAYER & ORGANIZATION OVERVIEW
-- ============================================================================

-- 5.1  Payer distribution — who is covering these patients?
SELECT 
    py.name AS payer_name,
    COUNT(*) AS encounter_count,
    COUNT(DISTINCT e.patient) AS unique_patients,
    ROUND(SUM(e.total_claim_cost), 2) AS total_billed,
    ROUND(SUM(e.payer_coverage), 2) AS total_covered,
    ROUND(SUM(e.payer_coverage) * 100.0 / NULLIF(SUM(e.total_claim_cost), 0), 1) AS coverage_pct
FROM encounters e
JOIN payers py ON e.payer = py.id
GROUP BY py.name
ORDER BY encounter_count DESC;


-- 5.2  Top 10 organizations by encounter volume
SELECT 
    o.name AS organization_name,
    o.city,
    COUNT(*) AS encounter_count,
    COUNT(DISTINCT e.patient) AS unique_patients,
    ROUND(SUM(e.total_claim_cost), 2) AS total_revenue
FROM encounters e
JOIN organizations o ON e.organization = o.id
GROUP BY o.id, o.name, o.city
ORDER BY encounter_count DESC
LIMIT 10;


-- 5.3  Provider specialty mix
SELECT 
    speciality,
    COUNT(*) AS provider_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 1) AS pct
FROM providers
GROUP BY speciality
ORDER BY provider_count DESC;
