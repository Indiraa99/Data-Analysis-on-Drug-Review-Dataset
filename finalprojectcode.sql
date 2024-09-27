-- Select the entire dataset for review
USE hap780project;
SELECT * FROM dbo.drugs_dataset;

---- DATA PREPROCESSING ----

-- Change data types for each column to ensure consistent data formats
SELECT 
      TRY_CAST (id as int) as ID,  -- Ensure ID is an integer
      TRY_CAST (drugName as nvarchar(max)) as DrugName,  -- Ensure drugName is text
      TRY_CAST(condition as nvarchar(max)) as DiseaseCondition,  -- Ensure condition is text
      TRY_CAST (review as nvarchar(max)) as Review_of_Drug,  -- Ensure review is text
      TRY_CAST (rating as int) as Rating,  -- Ensure rating is an integer
      TRY_CAST (date as date) as Date,  -- Ensure date is in date format
      TRY_CAST (usefulCount as int) as UsefulDrugCount  -- Ensure usefulCount is an integer
FROM dbo.drugs_dataset;

-- Identifying null values in each critical column
SELECT * FROM dbo.drugs_dataset WHERE ID IS NULL;  -- Check for null IDs
SELECT * FROM dbo.drugs_dataset WHERE drugName IS NULL;  -- Check for null drug names
SELECT * FROM dbo.drugs_dataset WHERE condition IS NULL;  -- Check for null conditions (1194 found)
SELECT * FROM dbo.drugs_dataset WHERE review IS NULL;  -- Check for null reviews
SELECT * FROM dbo.drugs_dataset WHERE Rating IS NULL;  -- Check for null ratings
SELECT * FROM dbo.drugs_dataset WHERE Date IS NULL;  -- Check for null dates
SELECT * FROM dbo.drugs_dataset WHERE usefulCount IS NULL;  -- Check for null usefulCount

-- Remove rows where the 'condition' column is null
DELETE FROM dbo.drugs_dataset WHERE condition IS NULL;  -- 1194 rows removed

-- Trim whitespace from 'drugName' and 'condition' and convert to lowercase for standardization
UPDATE dbo.drugs_dataset
SET condition = LOWER(TRIM(condition)),
    drugName = LOWER(TRIM(drugName));  -- Standardize text and ensure uniform formatting


	-- Remove any duplicate rows based on the 'id' column
WITH CTE AS (
    SELECT *, 
           ROW_NUMBER() OVER (PARTITION BY id ORDER BY id) AS rn
    FROM dbo.drugs_dataset
)
DELETE FROM CTE WHERE rn > 1;  -- Keep only the first occurrence of each ID

-- Identify any outliers in 'rating' where the value is not between 1 and 10
SELECT * 
FROM dbo.drugs_dataset 
WHERE rating < 1 OR rating > 10;  -- Ensure ratings are within expected range

---- FEATURE ENGINEERING ----

-- Add a new column 'word_count' to count the number of words in each review
ALTER TABLE dbo.drugs_dataset ADD word_count INT;

-- Populate 'word_count' with the number of words in each review
UPDATE dbo.drugs_dataset
SET word_count = LEN(review) - LEN(REPLACE(review, ' ', '')) + 1;  -- Calculate word count

-- Split the 'date' column into separate 'year', 'month', and 'day' columns for easier time-based analysis
ALTER TABLE dbo.drugs_dataset ADD year INT;
ALTER TABLE dbo.drugs_dataset ADD month INT;
ALTER TABLE dbo.drugs_dataset ADD day INT;

-- Populate the 'year', 'month', and 'day' columns with data extracted from the 'date' column
UPDATE dbo.drugs_dataset
SET year = YEAR(date),
    month = MONTH(date),
    day = DAY(date);  -- Split the date into separate components

	select * from dbo.drugs_dataset



-- Calculate mean and standard deviation for 'usefulCount' to identify outliers
WITH Stats AS (
    SELECT 
        AVG(usefulCount) as MeanUsefulCount,
        STDEV(usefulCount) as StdDevUsefulCount
    FROM dbo.drugs_dataset
),
Outliers AS (
    SELECT *,
           (usefulCount - Stats.MeanUsefulCount) / Stats.StdDevUsefulCount as ZScore
    FROM dbo.drugs_dataset, Stats
)
SELECT *
FROM Outliers
WHERE ABS(ZScore) > 3;  -- Identify reviews where 'usefulCount' is an outlier

-- Delete outliers based on the calculated Z-Score
WITH Stats AS (
    SELECT 
        AVG(usefulCount) as MeanUsefulCount,
        STDEV(usefulCount) as StdDevUsefulCount
    FROM dbo.drugs_dataset
),
Outliers AS (
    SELECT *,
           (usefulCount - Stats.MeanUsefulCount) / Stats.StdDevUsefulCount as ZScore
    FROM dbo.drugs_dataset, Stats
)
DELETE FROM dbo.drugs_dataset
WHERE ID IN (SELECT ID FROM Outliers WHERE ABS(ZScore) > 3);  -- Remove outliers ----(3929 rows affected)

select COUNT(*) from dbo.drugs_dataset ---209940 rows


-- Check for any leading or trailing spaces in 'drugName' and 'condition'
SELECT * 
FROM dbo.drugs_dataset
WHERE LTRIM(RTRIM(drugName)) <> drugName
   OR LTRIM(RTRIM(condition)) <> condition;  -- Identify records with unintended spaces

-- Add a 'sentiment' column to classify reviews as positive (1), negative (-1), or neutral (0)
ALTER TABLE dbo.drugs_dataset ADD sentiment INT;

-- Populate the 'sentiment' column based on keywords in the review
UPDATE dbo.drugs_dataset
SET sentiment = CASE
    WHEN LOWER(review) LIKE '%good%' OR LOWER(review) LIKE '%great%' OR LOWER(review) LIKE '%excellent%' THEN 1  -- Positive sentiment
    WHEN LOWER(review) LIKE '%bad%' OR LOWER(review) LIKE '%terrible%' OR LOWER(review) LIKE '%poor%' THEN -1  -- Negative sentiment
    ELSE 0  -- Neutral sentiment
END;

-- Check the table after sentiment analysis
SELECT * FROM dbo.drugs_dataset;


---- BINARIZATION ----

-- Add a binary column 'rating_binary' to classify ratings as high (1) or low (0)
ALTER TABLE dbo.drugs_dataset ADD rating_binary VARCHAR(10);

-- Populate 'rating_binary' based on the 'rating' column (1 if rating >= 7, else 0)
UPDATE dbo.drugs_dataset
SET rating_binary = CASE 
                       WHEN rating >= 7 THEN '1'  -- High rating
                       ELSE '0'  -- Low rating
                    END;

-- Final check of the processed data
SELECT * FROM dbo.drugs_dataset;

select COUNT(*) from dbo.drugs_dataset

select top 1500 * from dbo.drugs_dataset
