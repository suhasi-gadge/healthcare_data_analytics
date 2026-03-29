-- ============================================================================
-- HEALTHCARE ANALYTICS PROJECT
-- Script:  00_create_schema.sql
-- Purpose: Create PostgreSQL schema for Synthea healthcare dataset
-- Target:  PostgreSQL 14+ / pgAdmin 4
-- ============================================================================

-- Create a dedicated schema to keep things organized
CREATE SCHEMA IF NOT EXISTS healthcare;
SET search_path TO healthcare;

-- ============================================================================
-- DIMENSION TABLES (reference / lookup tables)
-- ============================================================================

-- Organizations: Hospitals, clinics, and care facilities
CREATE TABLE organizations (
    id              UUID PRIMARY KEY,
    name            VARCHAR(200) NOT NULL,
    address         VARCHAR(200),
    city            VARCHAR(100),
    state           VARCHAR(2),
    zip             VARCHAR(10),
    lat             NUMERIC(10,6),
    lon             NUMERIC(10,6),
    phone           VARCHAR(50),
    revenue         NUMERIC(14,2),
    utilization     INTEGER
);

-- Providers: Individual physicians and clinicians
CREATE TABLE providers (
    id              UUID PRIMARY KEY,
    organization    UUID REFERENCES organizations(id),
    name            VARCHAR(200),
    gender          VARCHAR(5),
    speciality      VARCHAR(100),
    address         VARCHAR(200),
    city            VARCHAR(100),
    state           VARCHAR(2),
    zip             VARCHAR(10),
    lat             NUMERIC(10,6),
    lon             NUMERIC(10,6),
    utilization     INTEGER
);

-- Payers: Insurance companies and government programs
CREATE TABLE payers (
    id                      UUID PRIMARY KEY,
    name                    VARCHAR(100) NOT NULL,
    address                 VARCHAR(200),
    city                    VARCHAR(100),
    state_headquartered     VARCHAR(2),
    zip                     VARCHAR(10),
    phone                   VARCHAR(50),
    amount_covered          NUMERIC(14,2),
    amount_uncovered        NUMERIC(14,2),
    revenue                 NUMERIC(14,2),
    covered_encounters      INTEGER,
    uncovered_encounters    INTEGER,
    covered_medications     INTEGER,
    uncovered_medications   INTEGER,
    covered_procedures      INTEGER,
    uncovered_procedures    INTEGER,
    covered_immunizations   INTEGER,
    uncovered_immunizations INTEGER,
    unique_customers        INTEGER,
    qols_avg                NUMERIC(10,6),
    member_months           INTEGER
);

-- Patients: Core demographic table
CREATE TABLE patients (
    id                  UUID PRIMARY KEY,
    birthdate           DATE NOT NULL,
    deathdate           DATE,
    ssn                 VARCHAR(15),
    drivers             VARCHAR(20),
    passport            VARCHAR(20),
    prefix              VARCHAR(10),
    first               VARCHAR(100),
    last                VARCHAR(100),
    suffix              VARCHAR(10),
    maiden              VARCHAR(100),
    marital             VARCHAR(5),
    race                VARCHAR(50),
    ethnicity           VARCHAR(50),
    gender              VARCHAR(5),
    birthplace          VARCHAR(200),
    address             VARCHAR(200),
    city                VARCHAR(100),
    state               VARCHAR(100),
    county              VARCHAR(100),
    zip                 VARCHAR(10),
    lat                 NUMERIC(10,6),
    lon                 NUMERIC(10,6),
    healthcare_expenses NUMERIC(14,2),
    healthcare_coverage NUMERIC(14,2)
);

-- ============================================================================
-- FACT / TRANSACTIONAL TABLES
-- ============================================================================

-- Encounters: Central transactional table — every clinical event
CREATE TABLE encounters (
    id                    UUID PRIMARY KEY,
    start                 TIMESTAMP NOT NULL,
    stop                  TIMESTAMP,
    patient               UUID NOT NULL REFERENCES patients(id),
    organization          UUID REFERENCES organizations(id),
    provider              UUID REFERENCES providers(id),
    payer                 UUID REFERENCES payers(id),
    encounterclass        VARCHAR(50),
    code                  BIGINT,
    description           VARCHAR(500),
    base_encounter_cost   NUMERIC(12,2),
    total_claim_cost      NUMERIC(12,2),
    payer_coverage        NUMERIC(12,2),
    reasoncode            BIGINT,
    reasondescription     VARCHAR(500)
);

-- Conditions: Diagnoses tied to encounters
CREATE TABLE conditions (
    start           DATE NOT NULL,
    stop            DATE,
    patient         UUID NOT NULL REFERENCES patients(id),
    encounter       UUID NOT NULL REFERENCES encounters(id),
    code            BIGINT NOT NULL,
    description     VARCHAR(500)
);

-- Medications: Prescriptions and drug dispensing
CREATE TABLE medications (
    start               TIMESTAMP NOT NULL,
    stop                TIMESTAMP,
    patient             UUID NOT NULL REFERENCES patients(id),
    payer               UUID REFERENCES payers(id),
    encounter           UUID NOT NULL REFERENCES encounters(id),
    code                BIGINT NOT NULL,
    description         VARCHAR(500),
    base_cost           NUMERIC(12,2),
    payer_coverage      NUMERIC(12,2),
    dispenses           INTEGER,
    totalcost           NUMERIC(12,2),
    reasoncode          BIGINT,
    reasondescription   VARCHAR(500)
);

-- Procedures: Clinical procedures performed during encounters
CREATE TABLE procedures (
    date                TIMESTAMP NOT NULL,
    patient             UUID NOT NULL REFERENCES patients(id),
    encounter           UUID NOT NULL REFERENCES encounters(id),
    code                BIGINT NOT NULL,
    description         VARCHAR(500),
    base_cost           NUMERIC(12,2),
    reasoncode          BIGINT,
    reasondescription   VARCHAR(500)
);

-- Observations: Lab results, vitals, and clinical measurements
CREATE TABLE observations (
    date            TIMESTAMP NOT NULL,
    patient         UUID NOT NULL REFERENCES patients(id),
    encounter       UUID REFERENCES encounters(id),
    code            VARCHAR(20) NOT NULL,
    description     VARCHAR(500),
    value           VARCHAR(500),
    units           VARCHAR(50),
    type            VARCHAR(20)
);

-- Allergies: Patient allergy records
CREATE TABLE allergies (
    start           DATE NOT NULL,
    stop            DATE,
    patient         UUID NOT NULL REFERENCES patients(id),
    encounter       UUID NOT NULL REFERENCES encounters(id),
    code            BIGINT NOT NULL,
    description     VARCHAR(200)
);

-- Care Plans: Treatment plans for chronic and acute conditions
CREATE TABLE careplans (
    id                  UUID PRIMARY KEY,
    start               DATE NOT NULL,
    stop                DATE,
    patient             UUID NOT NULL REFERENCES patients(id),
    encounter           UUID NOT NULL REFERENCES encounters(id),
    code                BIGINT NOT NULL,
    description         VARCHAR(500),
    reasoncode          BIGINT,
    reasondescription   VARCHAR(500)
);

-- Immunizations: Vaccination records
CREATE TABLE immunizations (
    date            TIMESTAMP NOT NULL,
    patient         UUID NOT NULL REFERENCES patients(id),
    encounter       UUID NOT NULL REFERENCES encounters(id),
    code            BIGINT NOT NULL,
    description     VARCHAR(200),
    base_cost       NUMERIC(12,2)
);

-- Devices: Implanted medical devices
CREATE TABLE devices (
    start           TIMESTAMP NOT NULL,
    stop            TIMESTAMP,
    patient         UUID NOT NULL REFERENCES patients(id),
    encounter       UUID NOT NULL REFERENCES encounters(id),
    code            BIGINT NOT NULL,
    description     VARCHAR(500),
    udi             VARCHAR(200)
);

-- Imaging Studies: Radiology and diagnostic imaging
CREATE TABLE imaging_studies (
    id                      UUID PRIMARY KEY,
    date                    TIMESTAMP NOT NULL,
    patient                 UUID NOT NULL REFERENCES patients(id),
    encounter               UUID NOT NULL REFERENCES encounters(id),
    bodysite_code           BIGINT,
    bodysite_description    VARCHAR(200),
    modality_code           VARCHAR(10),
    modality_description    VARCHAR(200),
    sop_code                VARCHAR(50),
    sop_description         VARCHAR(200)
);

-- Payer Transitions: Insurance coverage changes over time
CREATE TABLE payer_transitions (
    patient         UUID NOT NULL REFERENCES patients(id),
    start_year      INTEGER NOT NULL,
    end_year        INTEGER NOT NULL,
    payer           UUID NOT NULL REFERENCES payers(id),
    ownership       VARCHAR(50)
);

-- ============================================================================
-- INDEXES for common query patterns
-- ============================================================================

-- Patient lookups
CREATE INDEX idx_patients_gender ON patients(gender);
CREATE INDEX idx_patients_race ON patients(race);
CREATE INDEX idx_patients_city ON patients(city);
CREATE INDEX idx_patients_state ON patients(state);

-- Encounter queries (most frequent joins)
CREATE INDEX idx_encounters_patient ON encounters(patient);
CREATE INDEX idx_encounters_start ON encounters(start);
CREATE INDEX idx_encounters_class ON encounters(encounterclass);
CREATE INDEX idx_encounters_payer ON encounters(payer);
CREATE INDEX idx_encounters_org ON encounters(organization);

-- Clinical tables — patient + encounter joins
CREATE INDEX idx_conditions_patient ON conditions(patient);
CREATE INDEX idx_conditions_encounter ON conditions(encounter);
CREATE INDEX idx_conditions_code ON conditions(code);

CREATE INDEX idx_medications_patient ON medications(patient);
CREATE INDEX idx_medications_encounter ON medications(encounter);

CREATE INDEX idx_procedures_patient ON procedures(patient);
CREATE INDEX idx_procedures_encounter ON procedures(encounter);

CREATE INDEX idx_observations_patient ON observations(patient);
CREATE INDEX idx_observations_encounter ON observations(encounter);
CREATE INDEX idx_observations_code ON observations(code);

CREATE INDEX idx_immunizations_patient ON immunizations(patient);
CREATE INDEX idx_allergies_patient ON allergies(patient);
CREATE INDEX idx_careplans_patient ON careplans(patient);

CREATE INDEX idx_payer_transitions_patient ON payer_transitions(patient);
CREATE INDEX idx_payer_transitions_payer ON payer_transitions(payer);

-- Provider speciality filtering
CREATE INDEX idx_providers_speciality ON providers(speciality);
CREATE INDEX idx_providers_org ON providers(organization);

-- ============================================================================
-- End of Schema
-- ============================================================================
