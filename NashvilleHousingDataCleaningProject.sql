----------------------------------------------------Nashville Housing Data Cleaning Project--------------------------------------------------
-----------------------------------------------------------------Sections----------------------------------------------------------------------
-- 1) Standardization of the date format for SaleDate column from "YYYY-MM-DD HH:MM:SS" to "YYYY-MM-DD"
-- Implemented concepts: updating the column directly
--                       altering by adding a new column and updating it 
--                       using a transaction process for data safety.

-- 2) Working on the property address column.
-- Implemented concept: Using ISNULL built in function which takes 2 parameters, a colmun value, and a replacement value if it is null.
--                      USING self join (it's like joining two tables but it's the same table just 2 instances of it).
--                      USING JOIN inside of an UPDATE statement.

-- 3) Breaking down address into individual seperate columns (Address, City, State).
-- Implemented Concepts: Using SUBSTRING() to slice a string into 2 parts.
--                       Using CHARINDEX() to get the index of a character.
--                       Using LEN() to get the length of a string.
--                       Altering the table by adding 2 new columns and updating the columns to populate them with the correct data.
--                       Using PARSENAME() instead of SUBSTRING() which easier but seperate (parse) strings on periods only.

-- 4) Changing Y and N values in SoldAsVacant column to be Yes and No.
-- Implemented Concepts: Using CASE statement inside an UPDATE statement to update a column values based on conditions.

-- 5) Removing Duplicates.
--Implemented Concepts: Using ROW_NUMBER() to number a partitioned table on few columns.
--                      Using PARTITION BY to partition the table on 4 or 5 columns similar values and number them
--                      If we get a row number that is > 1 over the partitioned table, it probably means these rows are duplicates.

--Query to see all the data. 
SELECT *
FROM NashvilleHousing

-- 1) standardize date format for sale date 
-- In here we are tyring to update the entire column of SaleDate to a converted date values, however, it might not work.
-- So instead we can try altering the table by adding a new column (let's call it SaleDateConverted) and set its values to what we want.
-- we might delete SaleDate column after that if we want.
-- Note that the strategy of altering and updating the new column can be useful as we are keeping the original data 
-- unlike updating the original directly.
Update NashvilleHousing
SET SaleDate = CONVERT(Date, SaleDate);

-- Altering by adding and Updating (START) TRANSACTION BEGIN--
-- Begin transaction
BEGIN TRANSACTION;

-- Check if column SaleDateConverted doesn't exist in table NashvilleHousing in the first place, if it does, the altering and updating
-- won't be executed.
IF NOT EXISTS (
    SELECT 1
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = 'NashvilleHousing'
    AND COLUMN_NAME = 'SaleDateConverted'
)
-- Alter table to add new column
ALTER TABLE NashvilleHousing
ADD SaleDateConverted Date;

-- Update new column with converted values from old column
UPDATE NashvilleHousing
SET SaleDateConverted = TRY_CONVERT(Date, SaleDate); -- TRY_CONVERT to handle conversion errors gracefully

-- Check for any issues before committing changes
-- For example, check if there are any NULL values in the original column that couldn't be converted

-- If everything looks good, commit changes
COMMIT;

-- If an error occurred or you need to rollback the changes, use the ROLLBACK statement
-- ROLLBACK;
-- Altering by adding and Updating (END) TRANSACTION END--

--Testing of section 1
SELECT SaleDateConverted, CONVERT(Date, SaleDate)
FROM NashvilleHousing
-------------------------------------------------------------------------------------------------------------------------------------------------
--SECTION 2: WORKING ON PROPERTY ADDRESS--
-- First we need to populate all the null property addresses with addresses :D
--Let's take a quick look at the rows with null property address to get a feel for it.
SELECT *
FROM NashvilleHousing
WHERE PropertyAddress IS NULL
-- If we take a look at ParcelIDs column we can see that similar parcel IDs have the same address, so we 
-- might think, okai, what if we have 2 identical parcelIDs and one of them has a null property address,
-- so why can not we populate the empty property address with the property address of the same parcel IDs
-- let's take a look at similar parcelIDs by viewing the table ordered by parcel IDs,
-- You will notice that identical Parcel IDs have the same property address or should have the same, we can leverage this
-- to populate some and not all of null property addresses.
SELECT *
FROM NashvilleHousing
ORDER BY ParcelID
--------------

-- If you run this commented out query after the bottom UPDATE query, it should return empty result set as we will no longer have
-- null property addresses, just leaving here for testing that out.
--SELECT a.ParcelID, a.PropertyAddress, b.ParcelID, b.PropertyAddress, ISNULL(a.propertyAddress, b.PropertyAddress)
--FROM NashvilleHousing a
--JOIN NashvilleHousing b
--ON a.ParcelID = b.ParcelID
--AND a.[UniqueID ] <> b.[UniqueID ]
--WHERE a.PropertyAddress IS NULL

--This self joining the table and finding the rows where we have the same parcel ID, and one of the 2 property addresses is null
-- then we can update it from the other property address value.
-- Note that we joining on unique IDs and the same Parcel IDs to avoid redundancy in the result set.
UPDATE a
SET PropertyAddress = ISNULL(a.propertyAddress, b.PropertyAddress)
FROM NashvilleHousing a
JOIN NashvilleHousing b
ON a.ParcelID = b.ParcelID
AND a.[UniqueID ] <> b.[UniqueID ]
WHERE a.PropertyAddress IS NULL
----------------------------------------------------------------------------------------------------------------------------------
--Section 3: Breaking down address into individual seperate columns (Address, City, State)--
SELECT  PropertyAddress,
	    SUBSTRING(PropertyAddress, 1, CHARINDEX(',', PropertyAddress) - 1) AS Address,
	    SUBSTRING(PropertyAddress, CHARINDEX(',', PropertyAddress)  + 1, LEN(PropertyAddress)) AS City
FROM NashvilleHousing

-- We need to create 2 new columns to populate address and city seperately.
-- Adding 2 new columns for split address and city (START)-----------------
ALTER TABLE NashvilleHousing
ADD PropertySplitAddress nvarchar(255);

UPDATE NashvilleHousing
SET PropertySplitAddress = SUBSTRING(PropertyAddress, 1, CHARINDEX(',', PropertyAddress) - 1)

ALTER TABLE NashvilleHousing
ADD PropertySplitCity nvarchar(255);

UPDATE NashvilleHousing
SET PropertySplitCity = SUBSTRING(PropertyAddress, CHARINDEX(',', PropertyAddress)  + 1, LEN(PropertyAddress))
-- Adding 2 new columns for split address and city (END)-----------------
-- Looking at the 2 new columns inserted at the end with the populated addresses and cities.
SELECT * 
FROM NashvilleHousing
-------------------------------------------------------------------------------------------------------------
--Another way of splitting strings is PARSENAME()
SELECT 
PARSENAME(REPLACE(OwnerAddress, ',', '.'), 3),
PARSENAME(REPLACE(OwnerAddress, ',', '.'), 2),
PARSENAME(REPLACE(OwnerAddress, ',', '.'), 1)
FROM NashvilleHousing

-- We need to create 3 new columns to populate address and city and state of the owner address seperately.
-- Adding 3 new columns for split address and city and state(START)-----------------
ALTER TABLE NashvilleHousing
ADD OwnerSplitAddress nvarchar(255);

UPDATE NashvilleHousing
SET OwnerSplitAddress = PARSENAME(REPLACE(OwnerAddress, ',', '.'), 3)

ALTER TABLE NashvilleHousing
ADD OwnerSplitCity nvarchar(255);

UPDATE NashvilleHousing
SET OwnerSplitCity = PARSENAME(REPLACE(OwnerAddress, ',', '.'), 2)


ALTER TABLE NashvilleHousing
ADD OwnerSplitState nvarchar(255);

UPDATE NashvilleHousing
SET OwnerSplitState = PARSENAME(REPLACE(OwnerAddress, ',', '.'), 1)
-- Adding 3 new columns for split address and city and state (END)-----------------
-- Looking at the 3 new columns inserted at the end with the populated addresses, cities, and states.
SELECT * 
FROM NashvilleHousing
----------------------------------------------------------------------------------------------------------------------------------
--SECTION 4: Changing Y and N values in SoldAsVacant column to be Yes and No.--
-- Use this query to see how many N, Y, YES, and No exists in the column SoldAsVacant before and after the change.
SELECT DISTINCT(SoldAsVacant), COUNT(SoldAsVacant)
FROM NashvilleHousing
GROUP BY SoldAsVacant
ORDER BY 2

-- Updating the SoldAsVacant column when Y to Yes, and when N to No.
UPDATE NashvilleHousing
SET SoldAsVacant = CASE WHEN SoldAsVacant = 'Y' THEN 'YES'
		                WHEN SoldAsVacant = 'N' THEN 'NO'
			            ELSE SoldAsVacant
	               END
-------------------------------------------------------------------------------------------------------------------------------------
--SECTION 5: Removing Duplicates--
--Note that you must always specify an ORDER BY using ROW_NUMBER
WITH RowNumCTE AS (
SELECT *,
	   ROW_NUMBER() OVER (
	   PARTITION BY ParcelID,
					PropertyAddress,
					SalePrice,
					SaleDate,
					LegalReference
	   ORDER BY UniqueID
	   ) AS RowNum
FROM NashvilleHousing
-- A reminder, you can not reference RowNum in the same statment (SELECT) it was created in, so we can use CTEs or Temp tables and so on.
--WHERE RowNum > 1
) 
-- The result set of this select statement after the CTE, is all the duplicates we want to remove as their RowNum is > 1
SELECT *
FROM RowNumCTE
WHERE RowNum > 1

--Use this inseated of the SELECT statement above to delete what you want from CTE.
--DELETE
--FROM RowNumCTE
--WHERE RowNUM > 1
-------------------------------------------------------------------------------------------------------------------------------------------
--Deleting unused columns (can be useful if you are creating views and you don't want a specific column
-- Best practice: Don't delete from raw data (the original table). But for the sake of our small project, we will do that.
SELECT * 
FROM NashvilleHousing

ALTER TABLE NashvilleHousing
DROP COLUMN TaxDistrict
