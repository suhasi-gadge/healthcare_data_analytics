# Data Dictionary — Healthcare Analytics Project

**Dataset:** Synthea Synthetic Patient Data (April 2020 Release)
**Database:** PostgreSQL (`healthcare` schema) + Power BI Star Schema CSVs
**Last Updated:** March 2026

---

## Raw Data Tables (16 files, `data/raw/`)

### patients.csv — 1,171 records

| Column | Type | Description |
|---|---|---|
| Id | UUID | Primary key — unique patient identifier |
| BIRTHDATE | Date | Patient date of birth |
| DEATHDATE | Date | Date of death (NULL if alive) |
| SSN | String | Social Security Number (synthetic) |
| DRIVERS | String | Driver's license number (synthetic) |
| PASSPORT | String | Passport number (synthetic) |
| PREFIX | String | Name prefix (Mr., Mrs., Ms.) |
| FIRST | String | First name |
| LAST | String | Last name |
| SUFFIX | String | Name suffix (NULL if none) |
| MAIDEN | String | Maiden name (NULL if not applicable) |
| MARITAL | String | Marital status (M = Married, S = Single; NULL for minors) |
| RACE | String | Race (white, black, asian, native, other) |
| ETHNICITY | String | Ethnicity (nonhispanic, hispanic) |
| GENDER | String | Gender (M, F) |
| BIRTHPLACE | String | City and state of birth |
| ADDRESS | String | Street address |
| CITY | String | City of residence |
| STATE | String | State (Massachusetts) |
| COUNTY | String | County of residence (14 MA counties represented) |
| ZIP | String | ZIP code |
| LAT | Float | Latitude coordinate |
| LON | Float | Longitude coordinate |
| HEALTHCARE_EXPENSES | Float | Cumulative lifetime healthcare expenses ($) |
| HEALTHCARE_COVERAGE | Float | Cumulative lifetime insurance coverage received ($) |

### encounters.csv — 53,346 records

| Column | Type | Description |
|---|---|---|
| Id | UUID | Primary key — unique encounter identifier |
| START | Datetime | Encounter start timestamp |
| STOP | Datetime | Encounter end timestamp |
| PATIENT | UUID | Foreign key → patients.Id |
| ORGANIZATION | UUID | Foreign key → organizations.Id |
| PROVIDER | UUID | Foreign key → providers.Id |
| PAYER | UUID | Foreign key → payers.Id |
| ENCOUNTERCLASS | String | Care setting: ambulatory, wellness, outpatient, urgentcare, emergency, inpatient |
| CODE | String | SNOMED encounter code |
| DESCRIPTION | String | Encounter description |
| BASE_ENCOUNTER_COST | Float | Base cost before adjustments ($) |
| TOTAL_CLAIM_COST | Float | Total billed claim amount ($) |
| PAYER_COVERAGE | Float | Amount covered by insurance ($) |
| REASONCODE | String | SNOMED code for reason (NULL if routine) |
| REASONDESCRIPTION | String | Reason description |

### conditions.csv — 8,376 records

| Column | Type | Description |
|---|---|---|
| START | Date | Condition onset date |
| STOP | Date | Condition resolution date (NULL if active/chronic) |
| PATIENT | UUID | Foreign key → patients.Id |
| ENCOUNTER | UUID | Foreign key → encounters.Id |
| CODE | String | SNOMED condition code |
| DESCRIPTION | String | Condition name (e.g., "Hypertension", "Viral sinusitis") |

### medications.csv — 42,989 records

| Column | Type | Description |
|---|---|---|
| START | Datetime | Prescription start date |
| STOP | Datetime | Prescription end date (NULL if ongoing) |
| PATIENT | UUID | Foreign key → patients.Id |
| PAYER | UUID | Foreign key → payers.Id |
| ENCOUNTER | UUID | Foreign key → encounters.Id |
| CODE | String | RxNorm medication code |
| DESCRIPTION | String | Full medication name and dosage |
| BASE_COST | Float | Base cost per dispense ($) |
| PAYER_COVERAGE | Float | Amount covered by payer per dispense ($) |
| DISPENSES | Integer | Number of times dispensed |
| TOTALCOST | Float | Total cost (BASE_COST × DISPENSES) |
| REASONCODE | String | SNOMED code for prescribing reason |
| REASONDESCRIPTION | String | Reason description |

### procedures.csv — 34,981 records

| Column | Type | Description |
|---|---|---|
| DATE | Date | Procedure date |
| PATIENT | UUID | Foreign key → patients.Id |
| ENCOUNTER | UUID | Foreign key → encounters.Id |
| CODE | String | SNOMED procedure code |
| DESCRIPTION | String | Procedure description |
| BASE_COST | Float | Procedure cost ($) |
| REASONCODE | String | SNOMED reason code |
| REASONDESCRIPTION | String | Reason description |

### observations.csv — 299,697 records

| Column | Type | Description |
|---|---|---|
| DATE | Date | Observation date |
| PATIENT | UUID | Foreign key → patients.Id |
| ENCOUNTER | UUID | Foreign key → encounters.Id |
| CODE | String | LOINC observation code |
| DESCRIPTION | String | Observation name (e.g., "Body Mass Index", "Systolic Blood Pressure") |
| VALUE | String | Observed value (numeric or text) |
| UNITS | String | Unit of measurement |
| TYPE | String | Observation type (numeric, text) |

### payers.csv — 10 records

| Column | Type | Description |
|---|---|---|
| Id | UUID | Primary key — unique payer identifier |
| NAME | String | Payer name (e.g., "Medicare", "Blue Cross Blue Shield", "NO_INSURANCE") |
| ADDRESS | String | Headquarters address |
| CITY | String | Headquarters city |
| STATE_HEADQUARTERED | String | Headquarters state |
| ZIP | String | Headquarters ZIP |
| PHONE | String | Contact phone |
| AMOUNT_COVERED | Float | Total amount covered across all claims ($) |
| AMOUNT_UNCOVERED | Float | Total amount not covered ($) |
| REVENUE | Float | Payer revenue ($) |
| COVERED_ENCOUNTERS | Integer | Number of encounters with coverage |
| UNCOVERED_ENCOUNTERS | Integer | Number of encounters without coverage |
| COVERED_MEDICATIONS | Integer | Medications with coverage |
| UNCOVERED_MEDICATIONS | Integer | Medications without coverage |
| COVERED_PROCEDURES | Integer | Procedures with coverage |
| UNCOVERED_PROCEDURES | Integer | Procedures without coverage |
| COVERED_IMMUNIZATIONS | Integer | Immunizations with coverage |
| UNCOVERED_IMMUNIZATIONS | Integer | Immunizations without coverage |
| UNIQUE_CUSTOMERS | Integer | Unique patient count |
| QOLS_AVG | Float | Average quality of life score |
| MEMBER_MONTHS | Integer | Total member-months of coverage |

### organizations.csv — 1,119 records

| Column | Type | Description |
|---|---|---|
| Id | UUID | Primary key — unique organization identifier |
| NAME | String | Facility name |
| ADDRESS | String | Street address |
| CITY | String | City |
| STATE | String | State |
| ZIP | String | ZIP code |
| LAT | Float | Latitude |
| LON | Float | Longitude |
| PHONE | String | Contact phone |
| REVENUE | Float | Facility revenue ($) |
| UTILIZATION | Integer | Total encounter count |

### providers.csv — 5,855 records

| Column | Type | Description |
|---|---|---|
| Id | UUID | Primary key — unique provider identifier |
| ORGANIZATION | UUID | Foreign key → organizations.Id |
| NAME | String | Provider full name |
| GENDER | String | Provider gender (M, F) |
| SPECIALITY | String | Medical specialty (e.g., "GENERAL PRACTICE", "INTERNAL") |
| ADDRESS | String | Practice address |
| CITY | String | City |
| STATE | String | State |
| ZIP | String | ZIP code |
| LAT | Float | Latitude |
| LON | Float | Longitude |
| UTILIZATION | Integer | Total encounter count |

### Additional Tables

| Table | Records | Key Columns |
|---|---|---|
| immunizations.csv | 15,478 | PATIENT, ENCOUNTER, CODE, DESCRIPTION, BASE_COST |
| allergies.csv | 597 | PATIENT, ENCOUNTER, CODE, DESCRIPTION |
| careplans.csv | 3,483 | PATIENT, ENCOUNTER, CODE, DESCRIPTION, REASONCODE |
| payer_transitions.csv | 3,801 | PATIENT, PAYER, START_YEAR, END_YEAR, OWNERSHIP |
| devices.csv | 78 | PATIENT, ENCOUNTER, CODE, DESCRIPTION, UDI |
| imaging_studies.csv | 855 | PATIENT, ENCOUNTER, MODALITY_CODE, BODYSITE_CODE |
| supplies.csv | 0 | Empty — excluded from analysis |

---

## Power BI Star Schema Tables (`data/processed/`)

### dim_date.csv — 7,671 records (2000–2020)

| Column | Type | Description |
|---|---|---|
| Date | Date | Calendar date |
| Year | Integer | Year |
| Quarter | Integer | Quarter (1–4) |
| QuarterLabel | String | "Q1", "Q2", "Q3", "Q4" |
| Month | Integer | Month number (1–12) |
| MonthName | String | Full month name |
| MonthShort | String | Abbreviated month name |
| MonthYear | String | "Jan 2020" format |
| Day | Integer | Day of month |
| DayOfWeek | Integer | Day of week (0 = Monday) |
| DayName | String | Full day name |
| WeekOfYear | Integer | ISO week number |
| IsWeekend | Integer | 1 if Saturday/Sunday |
| FiscalYear | Integer | July–June fiscal year |
| YearMonth | String | "2020-01" format |
| DateKey | Integer | YYYYMMDD integer key (joins to fact tables) |

### dim_patient.csv — 1,171 records

| Column | Type | Description |
|---|---|---|
| PatientId | UUID | Primary key |
| BirthDate | Date | Date of birth |
| DeathDate | Date | Date of death (empty if alive) |
| IsAlive | Integer | 1 = alive, 0 = deceased |
| Age | Integer | Age at data cutoff (or at death) |
| Gender | String | M or F |
| Race | String | white, black, asian, native, other |
| Ethnicity | String | nonhispanic, hispanic |
| MaritalStatus | String | M, S, or Unknown |
| City | String | City of residence |
| County | String | County |
| State | String | State |
| Zip | String | ZIP code |
| Latitude | Float | Latitude |
| Longitude | Float | Longitude |
| LifetimeExpenses | Float | Total lifetime healthcare expenses ($) |
| LifetimeCoverage | Float | Total lifetime insurance coverage ($) |
| AgeGroup | String | 0-17, 18-29, 30-44, 45-59, 60-74, 75+ |
| OutOfPocket | Float | LifetimeExpenses − LifetimeCoverage ($) |
| CoverageRatio | Float | LifetimeCoverage / LifetimeExpenses |

### dim_payer.csv — 10 records

| Column | Type | Description |
|---|---|---|
| PayerId | UUID | Primary key |
| PayerName | String | Insurance carrier name |
| PayerType | String | Commercial, Public, or Uninsured |
| City | String | Headquarters city |
| State | String | Headquarters state |
| AmountCovered | Float | Total covered amount ($) |
| AmountUncovered | Float | Total uncovered amount ($) |
| Revenue | Float | Payer revenue ($) |
| UniqueCustomers | Integer | Unique patient count |
| MemberMonths | Integer | Total member-months |

### fact_encounters.csv — 53,346 records

| Column | Type | Description |
|---|---|---|
| EncounterId | UUID | Primary key |
| DateKey | Integer | Foreign key → dim_date.DateKey |
| StartDate | Date | Encounter start date |
| StopDate | Date | Encounter end date |
| StartYear | Integer | Year of encounter |
| StartMonth | Integer | Month of encounter |
| PatientId | UUID | Foreign key → dim_patient.PatientId |
| OrganizationId | UUID | Foreign key → dim_organization.OrganizationId |
| ProviderId | UUID | Foreign key → dim_provider.ProviderId |
| PayerId | UUID | Foreign key → dim_payer.PayerId |
| EncounterClass | String | Foreign key → dim_encounter_class.EncounterClass |
| Description | String | Encounter description |
| TotalClaimCost | Float | Total billed amount ($) |
| PayerCoverage | Float | Insurance coverage amount ($) |
| OutOfPocketCost | Float | TotalClaimCost − PayerCoverage ($) |
| BaseEncounterCost | Float | Base encounter cost ($) |
| LOS_Hours | Float | Length of stay in hours |
| LOS_Days | Float | Length of stay in days |
| ReasonCode | String | SNOMED reason code |
| ReasonDescription | String | Reason description |

### fact_conditions.csv — 8,376 records

| Column | Type | Description |
|---|---|---|
| PatientId | UUID | Foreign key → dim_patient.PatientId |
| EncounterId | UUID | Foreign key → fact_encounters.EncounterId |
| ConditionCode | String | SNOMED condition code |
| ConditionDescription | String | Condition name |
| OnsetDate | Date | Condition onset date |
| ResolvedDate | Date | Resolution date (empty if active) |
| IsActive | Integer | 1 = unresolved, 0 = resolved |
| IsChronic | Integer | 1 = chronic condition, 0 = acute |

### fact_medications.csv — 42,989 records

| Column | Type | Description |
|---|---|---|
| PatientId | UUID | Foreign key → dim_patient.PatientId |
| PayerId | UUID | Foreign key → dim_payer.PayerId |
| EncounterId | UUID | Foreign key → fact_encounters.EncounterId |
| MedicationCode | String | RxNorm code |
| MedicationDescription | String | Full drug name and dosage |
| StartDate | Date | Prescription start |
| StopDate | Date | Prescription end |
| BaseCost | Float | Cost per dispense ($) |
| PayerCoverage | Float | Payer coverage per dispense ($) |
| Dispenses | Integer | Number of dispenses |
| TotalCost | Float | Total cost ($) |
| ReasonDescription | String | Prescribing reason |

### dim_encounter_class.csv — 6 records

| Column | Type | Description |
|---|---|---|
| EncounterClass | String | Primary key (ambulatory, wellness, outpatient, urgentcare, emergency, inpatient) |
| EncounterClassLabel | String | Display label |
| SortOrder | Integer | Sort order for consistent chart ordering |
| IsAcute | Integer | 1 = acute setting (emergency, inpatient, urgentcare), 0 = routine |
