-- Staging model for DOB NOW job filings (minimum cleaning)

WITH source AS (
   SELECT * FROM {{ source('raw', 'source_nyc_dob_job_apps') }}
),

cleaned AS (
   SELECT
       -- Keep every other column as is; transform the ones below
       * EXCEPT (
           job_filing_number,
           filing_date,
           current_status_date,
           first_permit_date,
           approved_date,
           signoff_date,
           postcode,
           zip
       ),

       -- Cast data types
       CAST(job_filing_number AS STRING) AS job_filing_number,
       CAST(filing_date AS TIMESTAMP) AS filing_date,
       CAST(current_status_date AS TIMESTAMP) AS current_status_date,
       CAST(first_permit_date AS TIMESTAMP) AS first_permit_date,
       CAST(approved_date AS TIMESTAMP) AS approved_date,
       CAST(signoff_date AS TIMESTAMP) AS signoff_date,

       -- Rename postcode to zip so it matches the 311 data
       CAST(postcode AS STRING) AS zip

   FROM source

   -- Filter
   WHERE job_filing_number IS NOT NULL
)

SELECT * FROM cleaned