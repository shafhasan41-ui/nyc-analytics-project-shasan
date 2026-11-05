-- Clean and standardize DOB NOW job filing data
-- One row per job filing (deduplicated on job_filing_number)

WITH source AS (
   SELECT * FROM {{ source('raw', 'source_nyc_dob_job_apps') }}
),

cleaned AS (
   SELECT
       -- Keep every other column as is; transform the ones below
       * EXCEPT (
           job_filing_number,
           filing_status,
           job_type,
           filing_review_type,
           building_type,
           filing_date,
           current_status_date,
           first_permit_date,
           approved_date,
           signoff_date,
           borough,
           house_no,
           street_name,
           postcode,
           latitude,
           longitude
       ),

       -- Identifiers
       CAST(job_filing_number AS STRING) AS job_filing_number,

       -- Filing details
       CAST(filing_status AS STRING) AS filing_status,
       CAST(job_type AS STRING) AS job_type,
       CAST(filing_review_type AS STRING) AS filing_review_type,
       CAST(building_type AS STRING) AS building_type,

       -- Dates
       CAST(filing_date AS TIMESTAMP) AS filing_date,
       CAST(current_status_date AS TIMESTAMP) AS current_status_date,
       CAST(first_permit_date AS TIMESTAMP) AS first_permit_date,
       CAST(approved_date AS TIMESTAMP) AS approved_date,
       CAST(signoff_date AS TIMESTAMP) AS signoff_date,

       -- Location - standardized borough, same values as the 311 staging model
       CASE
           WHEN UPPER(TRIM(borough)) IN ('MANHATTAN', 'NEW YORK COUNTY') THEN 'Manhattan'
           WHEN UPPER(TRIM(borough)) IN ('BRONX', 'THE BRONX') THEN 'Bronx'
           WHEN UPPER(TRIM(borough)) IN ('BROOKLYN', 'KINGS COUNTY') THEN 'Brooklyn'
           WHEN UPPER(TRIM(borough)) IN ('QUEENS', 'QUEEN', 'QUEENS COUNTY') THEN 'Queens'
           WHEN UPPER(TRIM(borough)) IN ('STATEN ISLAND', 'RICHMOND COUNTY') THEN 'Staten Island'
           ELSE 'UNKNOWN or CITYWIDE'
       END AS borough,

       CAST(house_no AS STRING) AS house_no,
       CAST(street_name AS STRING) AS street_name,

       -- Location - postcode renamed to zip (to match the 311 data) and cleaned
       CASE
           WHEN UPPER(TRIM(CAST(postcode AS STRING))) IN ('N/A', 'NA') THEN NULL
           WHEN LENGTH(CAST(postcode AS STRING)) = 5 THEN CAST(postcode AS STRING)
           WHEN LENGTH(CAST(postcode AS STRING)) = 9 THEN CAST(postcode AS STRING)
           WHEN LENGTH(CAST(postcode AS STRING)) = 10
               AND REGEXP_CONTAINS(CAST(postcode AS STRING), r'^\d{5}-\d{4}')
           THEN CAST(postcode AS STRING)
           ELSE NULL
       END AS zip,

       CAST(latitude AS DECIMAL) AS latitude,
       CAST(longitude AS DECIMAL) AS longitude,

       -- Metadata
       CURRENT_TIMESTAMP() AS _stg_loaded_at

   FROM source

   -- Filters
   WHERE job_filing_number IS NOT NULL
   AND filing_date IS NOT NULL

   -- Deduplicate: keep the row with the latest status date for each job filing
   QUALIFY ROW_NUMBER() OVER (PARTITION BY job_filing_number ORDER BY current_status_date DESC) = 1
)

SELECT * FROM cleaned