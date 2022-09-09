--SELECT *
--FROM dbo.CovidDeaths
----Sorting by column 3 (location) and 4 (date)
--ORDER BY 3,4

--SELECT *
--FROM dbo.CovidVaccinations
--ORDER BY 3,4

--Select data to use

SELECT location, date, total_cases, new_cases, total_deaths, population
FROM dbo.CovidDeaths
ORDER BY 1, 2

--Look for total cases vs. total deaths
--Shows the likelihood of dying if contract covid in your country

SELECT location, date, total_cases, total_deaths, (total_deaths/total_cases)*100 AS DeathPercentage
FROM dbo.CovidDeaths
WHERE location LIKE '%states'
AND continent IS NOT NULL
ORDER BY 1, 2

--Look for total cases vs. population
--Shows percentage of population got covid

SELECT location, date, population, total_cases, (total_cases/population)*100 AS PercentPopulatInfected
FROM dbo.CovidDeaths
--WHERE location LIKE '%states'
ORDER BY 1, 2

--Look for countries with highest infection rate compare to population

SELECT location, population, MAX(total_cases) AS HighestInfectCount, MAX(total_cases/population)*100 AS PercentPopulatInfected
FROM dbo.CovidDeaths
GROUP BY location, population
ORDER BY 4 DESC --Highest number first

--Look for countries with highest death count per population
--MAX is an aggregate function
--In this case total_deaths column has data type as nvarchar, we need to convert (cast) it as integer

SELECT location, continent, MAX(CAST(total_deaths AS int)) AS HighestDeathsCount
FROM dbo.CovidDeaths
GROUP BY location, continent
ORDER BY HighestDeathsCount DESC --Highest number first

--The location column not only includes countries but also includes continents, whole world and groups of countries according to their income
--In that case we pull data in which continent column IS NOT null

SELECT location, MAX(CAST(total_deaths AS int)) AS HighestDeathsCount
FROM dbo.CovidDeaths
WHERE continent IS NOT NULL
GROUP BY location
ORDER BY HighestDeathsCount DESC --Highest number first

---BREAKING DATA DOWN BY CONTINENT

SELECT continent, MAX(CAST(total_deaths AS int)) AS HighestDeathsCount
FROM dbo.CovidDeaths
WHERE continent IS NOT NULL
GROUP BY continent
ORDER BY HighestDeathsCount DESC --Highest number first

--GLOBAL NUMBERS PER DAY

--new_deaths column is a nvarchar type, we need to convert it to integer
SELECT date, SUM(new_cases) AS sum_new_cases, SUM(CAST(new_deaths AS int)) AS sum_new_deaths, SUM(CAST(new_deaths AS int))/SUM(new_cases)*100 AS Deathpercentage
FROM dbo.CovidDeaths
WHERE continent IS NOT NULL
GROUP BY date
ORDER BY 1,2

--Total new cases per day
SELECT SUM(new_cases) AS sum_new_cases, SUM(CAST(new_deaths AS int)) AS sum_new_deaths, SUM(CAST(new_deaths AS int))/SUM(new_cases)*100 AS Deathpercentage
FROM dbo.CovidDeaths
WHERE continent IS NOT NULL
ORDER BY 1,2

--JOINING TWO TABLES

--dea is a short name for deaths table / vac is a short name for vaccination table
--Joining ON (is how we are going to join these table together
SELECT *
FROM dbo.CovidDeaths dea
JOIN dbo.CovidVaccinations vac
	ON dea.location = vac.location
	AND dea.date = vac.date

--Show total population vs. new_vaccinations
SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations
FROM dbo.CovidDeaths dea
JOIN dbo.CovidVaccinations vac
	ON dea.location = vac.location
	AND dea.date = vac.date
WHERE dea.continent IS NOT NULL
ORDER BY 2,3

--PARTITION BY / ROLLING COUNT (ACCUMULATIVE SUM)

--Create a column for the accumulative new vaccinations (rolling count vaccinated)
--CONVERT() does the same task as CAST

SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations, SUM(CONVERT(INT,vac.new_vaccinations)) 
OVER (PARTITION BY dea.location ORDER BY dea.location, dea.date) AS RollingCountVaccinated
FROM dbo.CovidDeaths dea
JOIN dbo.CovidVaccinations vac
	ON dea.location = vac.location
	AND dea.date = vac.date
WHERE dea.continent IS NOT NULL
ORDER BY 2,3

--Show the total population vs. the vaccinations using the max number of the RollingCountVaccinated column
--Use that number and divide by the total population to know how many ppl in a specific country is vaccinated
--For this, we can't use the RollingCountVaccinated column, so we need to either create a CTE or a TEMP TABLE

SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations, SUM(CONVERT(INT,vac.new_vaccinations)) 
OVER (PARTITION BY dea.location ORDER BY dea.location, dea.date) AS RollingCountVaccinated
, (RollingCountVaccinated/population)*100
FROM dbo.CovidDeaths dea
JOIN dbo.CovidVaccinations vac
	ON dea.location = vac.location
	AND dea.date = vac.date
WHERE dea.continent IS NOT NULL
ORDER BY 2,3

--Using CTE

--Use WITH, specify the columns we're going to input
--If the number of columns in the CTE is different than the number of columns below it will show error
WITH PopulatVsVacc (continent, location, date, population, new_vaccinations, RollingCountVaccinated)
AS
(
SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations, SUM(CONVERT(INT,vac.new_vaccinations)) 
OVER (PARTITION BY dea.location ORDER BY dea.location, dea.date) AS RollingCountVaccinated
FROM dbo.CovidDeaths dea
JOIN dbo.CovidVaccinations vac
	ON dea.location = vac.location
	AND dea.date = vac.date
WHERE dea.continent IS NOT NULL
)
--Now we can do the calculation to know what percentage of the population of the country is vaccinated 
SELECT *, (RollingCountVaccinated/population)*100 AS Percentagepopulvaccinated --This is a comparison between the RollingCountVaccinated column and Population
FROM PopulatVsVacc

--Using TEMP TABLE (Go back, it didn't work)--

DROP TABLE IF EXISTS #PercentPopulatVaccinated
CREATE TABLE #PercentPopulatVaccinated --Here we named the new table and specify the columns
(
Continent nvarchar(255),
Location nvarchar(255),
Date datetime,
Population numeric ,
New_vaccinations nvarchar(255),
RollingCountVaccinated numeric
)

INSERT INTO #PercentPopulatVaccinated --Here we insert the previous columns into the new table
SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations, SUM(CONVERT(int,vac.new_vaccinations))
OVER (PARTITION BY dea.location ORDER BY dea.location, dea.date) AS RollingCountVaccinated
FROM dbo.CovidDeaths dea
JOIN dbo.CovidVaccinations vac
	ON dea.location = vac.location
	AND dea.date = vac.date
WHERE dea.continent IS NOT NULL
SELECT *, (RollingCountVaccinated/population)*100
FROM #PercentPopulatVaccinated

-- CREATING VIEWS TO STORE DATA FOR LATER VISUALISATIONS

CREATE VIEW PercentagPopulationVaccinated AS
WITH PopulatVsVacc (continent, location, date, population, new_vaccinations, RollingCountVaccinated)
AS
(
SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations, SUM(CONVERT(INT,vac.new_vaccinations)) 
OVER (PARTITION BY dea.location ORDER BY dea.location, dea.date) AS RollingCountVaccinated
FROM dbo.CovidDeaths dea
JOIN dbo.CovidVaccinations vac
	ON dea.location = vac.location
	AND dea.date = vac.date
WHERE dea.continent IS NOT NULL
)
--Now we can do the calculation to know what percentage of the population of the country is vaccinated 
SELECT *, (RollingCountVaccinated/population)*100 AS Percentagepopulvaccinated --This is a comparison between the RollingCountVaccinated column and Population
FROM PopulatVsVacc

--We can see the views as tables
SELECT *
FROM dbo.PercentagPopulationVaccinated