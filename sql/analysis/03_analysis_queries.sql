-- ============================================================================
-- HEALTHCARE ANALYTICS PROJECT
-- Script:  03_analysis_queries.sql
-- Purpose: Deep analytical queries — hospital utilization, financial analysis,
--          chronic disease patterns, patient risk, and operational insights
-- Target:  PostgreSQL 14+ / pgAdmin 4
-- ============================================================================

SET search_path TO healthcare;


-- ############################################################################
-- ANALYSIS AREA 1: HOSPITAL UTILIZATION & ENCOUNTER ANALYSIS
-- ############################################################################

-- 1.1  Encounter volume by class and year — trend analysis
--      Identifies growth or decline in specific encounter types
SELECT 
    EXTRACT(YEAR FROM start) AS yr,
    encounterclass,
    COUNT(*) AS encounters,
    ROUND(SUM(total_claim_cost), 2) AS total_cost
FROM encounters
GROUP BY yr, encounterclass
ORDER BY yr, encounters DESC;


-- 1.2  Emergency department utilization — frequent ED visitors
--      Identifies patients with 3+ ED visits (potential care management candidates)
SELECT 
    p.first || ' ' || p.last AS patient_name,
    p.gender,
    EXTRACT(YEAR FROM AGE(DATE '2020-04-01', p.birthdate))::INT AS age,
    COUNT(*) AS ed_visits,
    ROUND(SUM(e.total_claim_cost), 2) AS total_ed_cost,
    STRING_AGG(DISTINCT e.reasondescription, ' | ' ORDER BY e.reasondescription) AS ed_reasons
FROM encounters e
JOIN patients p ON e.patient = p.id
WHERE e.encounterclass = 'emergency'
GROUP BY p.id, p.first, p.last, p.gender, p.birthdate
HAVING COUNT(*) >= 3
ORDER BY ed_visits DESC;


-- 1.3  Inpatient length of stay analysis
--      Average LOS by admission reason — identifies high-resource conditions
SELECT 
    e.reasondescription AS admission_reason,
    COUNT(*) AS admissions,
    ROUND(AVG(EXTRACT(EPOCH FROM (e.stop - e.start)) / 3600.0), 1) AS avg_hours,
    ROUND(AVG(e.total_claim_cost), 2) AS avg_cost,
    ROUND(SUM(e.total_claim_cost), 2) AS total_cost
FROM encounters e
WHERE e.encounterclass = 'inpatient'
  AND e.reasondescription IS NOT NULL
GROUP BY e.reasondescription
HAVING COUNT(*) >= 5
ORDER BY avg_hours DESC;


-- 1.4  30-Day readmission analysis
--      Identifies patients readmitted within 30 days — a key quality metric
WITH ordered_encounters AS (
    SELECT 
        patient,
        id AS encounter_id,
        encounterclass,
        start,
        stop,
        total_claim_cost,
        LAG(stop) OVER (PARTITION BY patient ORDER BY start) AS prev_discharge,
        LAG(encounterclass) OVER (PARTITION BY patient ORDER BY start) AS prev_class
    FROM encounters
    WHERE encounterclass IN ('inpatient', 'emergency')
)
SELECT 
    encounterclass AS readmit_type,
    COUNT(*) AS readmissions,
    ROUND(AVG(total_claim_cost), 2) AS avg_readmit_cost,
    ROUND(AVG(EXTRACT(EPOCH FROM (start - prev_discharge)) / 86400.0), 1) AS avg_days_between
FROM ordered_encounters
WHERE prev_discharge IS NOT NULL
  AND EXTRACT(EPOCH FROM (start - prev_discharge)) / 86400.0 BETWEEN 0 AND 30
GROUP BY encounterclass
ORDER BY readmissions DESC;


-- 1.5  Monthly encounter volume — seasonality detection
SELECT 
    EXTRACT(MONTH FROM start) AS month_num,
    TO_CHAR(start, 'Month') AS month_name,
    COUNT(*) AS encounters,
    COUNT(*) FILTER (WHERE encounterclass = 'emergency') AS ed_encounters,
    COUNT(*) FILTER (WHERE encounterclass = 'inpatient') AS inpatient_encounters
FROM encounters
GROUP BY month_num, month_name
ORDER BY month_num;


-- ############################################################################
-- ANALYSIS AREA 2: FINANCIAL & PAYER ANALYSIS
-- ############################################################################

-- 2.1  Payer performance comparison
--      Coverage ratio, cost per patient, and volume by insurance carrier
SELECT 
    py.name AS payer_name,
    COUNT(DISTINCT e.patient) AS unique_patients,
    COUNT(*) AS total_encounters,
    ROUND(SUM(e.total_claim_cost), 2) AS total_billed,
    ROUND(SUM(e.payer_coverage), 2) AS amount_covered,
    ROUND(SUM(e.total_claim_cost) - SUM(e.payer_coverage), 2) AS patient_liability,
    ROUND(SUM(e.payer_coverage) * 100.0 / NULLIF(SUM(e.total_claim_cost), 0), 1) AS coverage_ratio_pct,
    ROUND(SUM(e.total_claim_cost) / NULLIF(COUNT(DISTINCT e.patient), 0), 2) AS cost_per_patient
FROM encounters e
JOIN payers py ON e.payer = py.id
GROUP BY py.name
ORDER BY total_billed DESC;


-- 2.2  Uninsured / self-pay patient analysis
--      Identify patients with NO_INSURANCE payer — financial risk to hospital
SELECT 
    py.name AS payer_name,
    COUNT(DISTINCT e.patient) AS patients,
    COUNT(*) AS encounters,
    ROUND(SUM(e.total_claim_cost), 2) AS total_billed,
    ROUND(SUM(e.payer_coverage), 2) AS covered,
    ROUND(SUM(e.total_claim_cost) - SUM(e.payer_coverage), 2) AS uncovered_cost
FROM encounters e
JOIN payers py ON e.payer = py.id
WHERE LOWER(py.name) LIKE '%no insurance%'
   OR py.amount_covered = 0
GROUP BY py.name
ORDER BY uncovered_cost DESC;


-- 2.3  Cost breakdown by encounter class
--      Where is the money going? Inpatient vs ED vs ambulatory
SELECT 
    encounterclass,
    COUNT(*) AS encounters,
    ROUND(SUM(total_claim_cost), 2) AS total_cost,
    ROUND(AVG(total_claim_cost), 2) AS avg_cost,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY total_claim_cost)::NUMERIC, 2) AS median_cost,
    ROUND(MAX(total_claim_cost), 2) AS max_cost,
    ROUND(SUM(payer_coverage), 2) AS total_covered,
    ROUND(SUM(total_claim_cost - payer_coverage), 2) AS total_out_of_pocket
FROM encounters
GROUP BY encounterclass
ORDER BY total_cost DESC;


-- 2.4  Top 20 most expensive conditions (total cost)
SELECT 
    c.description AS condition,
    COUNT(DISTINCT c.patient) AS patients_affected,
    COUNT(DISTINCT c.encounter) AS related_encounters,
    ROUND(SUM(e.total_claim_cost), 2) AS total_cost,
    ROUND(AVG(e.total_claim_cost), 2) AS avg_cost_per_encounter
FROM conditions c
JOIN encounters e ON c.encounter = e.id
GROUP BY c.description
ORDER BY total_cost DESC
LIMIT 20;


-- 2.5  Medication cost analysis — most expensive drug categories
SELECT 
    m.description AS medication,
    COUNT(*) AS prescriptions,
    COUNT(DISTINCT m.patient) AS unique_patients,
    ROUND(SUM(m.totalcost), 2) AS total_cost,
    ROUND(AVG(m.totalcost), 2) AS avg_cost,
    ROUND(SUM(m.payer_coverage), 2) AS payer_covered,
    ROUND(SUM(m.totalcost) - SUM(m.payer_coverage), 2) AS patient_cost
FROM medications m
GROUP BY m.description
ORDER BY total_cost DESC
LIMIT 15;


-- 2.6  Year-over-year cost growth
SELECT 
    EXTRACT(YEAR FROM start) AS yr,
    COUNT(*) AS encounters,
    ROUND(SUM(total_claim_cost), 2) AS total_cost,
    ROUND(AVG(total_claim_cost), 2) AS avg_cost,
    ROUND(
        (SUM(total_claim_cost) - LAG(SUM(total_claim_cost)) OVER (ORDER BY EXTRACT(YEAR FROM start)))
        * 100.0 / NULLIF(LAG(SUM(total_claim_cost)) OVER (ORDER BY EXTRACT(YEAR FROM start)), 0)
    , 1) AS yoy_growth_pct
FROM encounters
GROUP BY yr
ORDER BY yr;


-- ############################################################################
-- ANALYSIS AREA 3: CHRONIC DISEASE & COMORBIDITY PATTERNS
-- ############################################################################

-- 3.1  Chronic condition prevalence
--      Conditions that are still active (no STOP date) — ongoing patient burden
SELECT 
    c.description AS chronic_condition,
    COUNT(DISTINCT c.patient) AS patient_count,
    ROUND(COUNT(DISTINCT c.patient) * 100.0 / (SELECT COUNT(*) FROM patients), 1) AS prevalence_pct
FROM conditions c
WHERE c.stop IS NULL
GROUP BY c.description
HAVING COUNT(DISTINCT c.patient) >= 10
ORDER BY patient_count DESC
LIMIT 20;


-- 3.2  Comorbidity analysis — conditions that commonly appear together
--      Self-join on patient to find condition pairs
SELECT 
    c1.description AS condition_1,
    c2.description AS condition_2,
    COUNT(DISTINCT c1.patient) AS co_occurrence_count
FROM conditions c1
JOIN conditions c2 
    ON c1.patient = c2.patient 
   AND c1.description < c2.description    -- avoid duplicates and self-joins
WHERE c1.stop IS NULL AND c2.stop IS NULL  -- both chronic/active
GROUP BY c1.description, c2.description
HAVING COUNT(DISTINCT c1.patient) >= 20
ORDER BY co_occurrence_count DESC
LIMIT 20;


-- 3.3  Diabetes deep dive — patient demographics and cost burden
--      Diabetes + prediabetes as a focus population
SELECT 
    c.description AS diabetes_type,
    COUNT(DISTINCT c.patient) AS patients,
    ROUND(AVG(EXTRACT(YEAR FROM AGE(DATE '2020-04-01', p.birthdate))), 0) AS avg_age,
    ROUND(AVG(p.healthcare_expenses), 2) AS avg_total_expenses,
    ROUND(AVG(p.healthcare_coverage), 2) AS avg_total_coverage,
    ROUND(AVG(p.healthcare_expenses - p.healthcare_coverage), 2) AS avg_out_of_pocket
FROM conditions c
JOIN patients p ON c.patient = p.id
WHERE LOWER(c.description) LIKE '%diabetes%'
   OR LOWER(c.description) LIKE '%prediabetes%'
GROUP BY c.description
ORDER BY patients DESC;


-- 3.4  High-risk patient scoring
--      Patients with 3+ chronic conditions, high encounter volume, and high cost
WITH patient_chronic AS (
    SELECT patient, COUNT(DISTINCT code) AS chronic_conditions
    FROM conditions
    WHERE stop IS NULL
    GROUP BY patient
),
patient_encounters AS (
    SELECT 
        patient, 
        COUNT(*) AS total_encounters,
        COUNT(*) FILTER (WHERE encounterclass = 'emergency') AS ed_visits,
        SUM(total_claim_cost) AS total_cost
    FROM encounters
    GROUP BY patient
)
SELECT 
    p.first || ' ' || p.last AS patient_name,
    p.gender,
    EXTRACT(YEAR FROM AGE(DATE '2020-04-01', p.birthdate))::INT AS age,
    pc.chronic_conditions,
    pe.total_encounters,
    pe.ed_visits,
    ROUND(pe.total_cost, 2) AS total_cost,
    -- Simple risk tier
    CASE 
        WHEN pc.chronic_conditions >= 5 AND pe.ed_visits >= 3 THEN 'CRITICAL'
        WHEN pc.chronic_conditions >= 3 OR pe.ed_visits >= 2 THEN 'HIGH'
        WHEN pc.chronic_conditions >= 2 THEN 'MODERATE'
        ELSE 'LOW'
    END AS risk_tier
FROM patient_chronic pc
JOIN patient_encounters pe ON pc.patient = pe.patient
JOIN patients p ON pc.patient = p.id
WHERE pc.chronic_conditions >= 3
ORDER BY pc.chronic_conditions DESC, pe.total_cost DESC
LIMIT 25;


-- 3.5  Condition onset by age — when do chronic diseases first appear?
SELECT 
    c.description AS condition,
    COUNT(DISTINCT c.patient) AS patients,
    ROUND(AVG(EXTRACT(YEAR FROM AGE(c.start, p.birthdate))), 1) AS avg_onset_age,
    ROUND(MIN(EXTRACT(YEAR FROM AGE(c.start, p.birthdate))), 1) AS min_onset_age,
    ROUND(MAX(EXTRACT(YEAR FROM AGE(c.start, p.birthdate))), 1) AS max_onset_age
FROM conditions c
JOIN patients p ON c.patient = p.id
WHERE c.description IN (
    'Hypertension',
    'Prediabetes',
    'Diabetes',
    'Body mass index 30+ - obesity (finding)',
    'Hyperlipidemia',
    'Chronic sinusitis (disorder)',
    'Anemia (disorder)'
)
GROUP BY c.description
ORDER BY avg_onset_age;


-- ############################################################################
-- ANALYSIS AREA 4: MEDICATION & PROCEDURE ANALYSIS
-- ############################################################################

-- 4.1  Most frequently prescribed medications
SELECT 
    description AS medication,
    COUNT(*) AS prescriptions,
    COUNT(DISTINCT patient) AS unique_patients,
    ROUND(AVG(dispenses), 1) AS avg_dispenses,
    ROUND(SUM(totalcost), 2) AS total_cost
FROM medications
GROUP BY description
ORDER BY prescriptions DESC
LIMIT 15;


-- 4.2  Medication-condition linkage — what drugs treat which conditions?
SELECT 
    m.description AS medication,
    m.reasondescription AS prescribed_for,
    COUNT(*) AS prescription_count,
    ROUND(AVG(m.totalcost), 2) AS avg_cost
FROM medications m
WHERE m.reasondescription IS NOT NULL
GROUP BY m.description, m.reasondescription
ORDER BY prescription_count DESC
LIMIT 20;


-- 4.3  Most common procedures and their costs
SELECT 
    description AS procedure_name,
    COUNT(*) AS procedure_count,
    COUNT(DISTINCT patient) AS unique_patients,
    ROUND(AVG(base_cost), 2) AS avg_cost,
    ROUND(SUM(base_cost), 2) AS total_cost
FROM procedures
GROUP BY description
ORDER BY procedure_count DESC
LIMIT 15;


-- 4.4  Procedures linked to conditions — why are procedures performed?
SELECT 
    pr.description AS procedure_name,
    pr.reasondescription AS reason,
    COUNT(*) AS times_performed,
    ROUND(AVG(pr.base_cost), 2) AS avg_cost
FROM procedures pr
WHERE pr.reasondescription IS NOT NULL
GROUP BY pr.description, pr.reasondescription
ORDER BY times_performed DESC
LIMIT 20;


-- 4.5  Polypharmacy analysis — patients on 5+ concurrent medications
WITH active_meds AS (
    SELECT 
        patient,
        COUNT(DISTINCT code) AS concurrent_meds,
        STRING_AGG(DISTINCT description, ' | ' ORDER BY description) AS medications
    FROM medications
    WHERE stop IS NULL OR stop > CURRENT_TIMESTAMP
    GROUP BY patient
)
SELECT 
    p.first || ' ' || p.last AS patient_name,
    p.gender,
    EXTRACT(YEAR FROM AGE(DATE '2020-04-01', p.birthdate))::INT AS age,
    am.concurrent_meds,
    am.medications
FROM active_meds am
JOIN patients p ON am.patient = p.id
WHERE am.concurrent_meds >= 5
ORDER BY am.concurrent_meds DESC
LIMIT 15;


-- ############################################################################
-- ANALYSIS AREA 5: POPULATION HEALTH & OPERATIONAL INSIGHTS
-- ############################################################################

-- 5.1  Patient coverage gaps — transitions between payers over time
SELECT 
    py.name AS payer_name,
    pt.ownership,
    COUNT(DISTINCT pt.patient) AS patients,
    ROUND(AVG(pt.end_year - pt.start_year), 1) AS avg_years_enrolled
FROM payer_transitions pt
JOIN payers py ON pt.payer = py.id
GROUP BY py.name, pt.ownership
ORDER BY patients DESC;


-- 5.2  Organization performance comparison
--      Revenue, patient volume, and avg cost by facility
SELECT 
    o.name AS facility,
    o.city,
    COUNT(DISTINCT e.patient) AS unique_patients,
    COUNT(*) AS total_encounters,
    ROUND(SUM(e.total_claim_cost), 2) AS total_revenue,
    ROUND(AVG(e.total_claim_cost), 2) AS avg_revenue_per_encounter,
    ROUND(SUM(e.total_claim_cost) / NULLIF(COUNT(DISTINCT e.patient), 0), 2) AS revenue_per_patient
FROM encounters e
JOIN organizations o ON e.organization = o.id
GROUP BY o.id, o.name, o.city
HAVING COUNT(*) >= 100
ORDER BY total_revenue DESC
LIMIT 15;


-- 5.3  Provider workload analysis
--      Encounters per provider, across specialties
SELECT 
    pr.speciality,
    COUNT(DISTINCT pr.id) AS providers,
    COUNT(e.id) AS total_encounters,
    ROUND(COUNT(e.id)::NUMERIC / NULLIF(COUNT(DISTINCT pr.id), 0), 1) AS encounters_per_provider
FROM providers pr
LEFT JOIN encounters e ON pr.id = e.provider
GROUP BY pr.speciality
ORDER BY encounters_per_provider DESC;


-- 5.4  Immunization coverage rates
--      What percentage of patients have received each vaccine?
SELECT 
    i.description AS vaccine,
    COUNT(DISTINCT i.patient) AS patients_vaccinated,
    ROUND(COUNT(DISTINCT i.patient) * 100.0 / (SELECT COUNT(*) FROM patients), 1) AS coverage_pct,
    COUNT(*) AS total_doses
FROM immunizations i
GROUP BY i.description
ORDER BY patients_vaccinated DESC;


-- 5.5  Allergy prevalence
SELECT 
    description AS allergy,
    COUNT(DISTINCT patient) AS patients_affected,
    ROUND(COUNT(DISTINCT patient) * 100.0 / (SELECT COUNT(*) FROM patients), 1) AS prevalence_pct
FROM allergies
GROUP BY description
ORDER BY patients_affected DESC;


-- 5.6  Comprehensive patient summary view
--      Creates a single-row-per-patient analytical view for dashboards
CREATE OR REPLACE VIEW patient_360_summary AS
SELECT 
    p.id AS patient_id,
    p.first || ' ' || p.last AS patient_name,
    p.gender,
    p.race,
    p.ethnicity,
    p.city,
    p.state,
    p.county,
    EXTRACT(YEAR FROM AGE(DATE '2020-04-01', p.birthdate))::INT AS age,
    CASE WHEN p.deathdate IS NULL THEN 'Alive' ELSE 'Deceased' END AS vital_status,
    p.healthcare_expenses AS lifetime_expenses,
    p.healthcare_coverage AS lifetime_coverage,
    p.healthcare_expenses - p.healthcare_coverage AS lifetime_out_of_pocket,
    
    -- Encounter metrics
    COUNT(DISTINCT e.id) AS total_encounters,
    COUNT(DISTINCT e.id) FILTER (WHERE e.encounterclass = 'emergency') AS ed_visits,
    COUNT(DISTINCT e.id) FILTER (WHERE e.encounterclass = 'inpatient') AS inpatient_stays,
    COUNT(DISTINCT e.id) FILTER (WHERE e.encounterclass = 'ambulatory') AS ambulatory_visits,
    ROUND(SUM(e.total_claim_cost), 2) AS total_encounter_cost,
    
    -- Clinical complexity
    COUNT(DISTINCT c.code) AS unique_conditions,
    COUNT(DISTINCT c.code) FILTER (WHERE c.stop IS NULL) AS active_chronic_conditions,
    COUNT(DISTINCT m.code) AS unique_medications,
    COUNT(DISTINCT pr.code) AS unique_procedures,
    COUNT(DISTINCT a.code) AS allergy_count
    
FROM patients p
LEFT JOIN encounters e ON p.id = e.patient
LEFT JOIN conditions c ON p.id = c.patient
LEFT JOIN medications m ON p.id = m.patient
LEFT JOIN procedures pr ON p.id = pr.patient
LEFT JOIN allergies a ON p.id = a.patient
GROUP BY p.id, p.first, p.last, p.gender, p.race, p.ethnicity, 
         p.city, p.state, p.county, p.birthdate, p.deathdate,
         p.healthcare_expenses, p.healthcare_coverage;


-- Quick test of the view
SELECT 
    patient_name, age, gender, vital_status,
    total_encounters, ed_visits, active_chronic_conditions,
    ROUND(lifetime_expenses, 2) AS expenses
FROM patient_360_summary
ORDER BY total_encounters DESC
LIMIT 10;
