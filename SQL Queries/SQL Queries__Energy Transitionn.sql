----------------Global Energy Transition & Sustainability Analysis (Optimized SQL Version)----------------

-----------------------------------SQL --------------------------------------
SELECT *
FROM energy_transitionn;


/* =========================================================
SECTION 1: ENERGY CONSUMPTION TRENDS
========================================================= */

---

-- 1. Countries with Highest Growth in Energy Consumption

WITH energy_growth AS (
SELECT
country,
MIN(year) AS first_year,
MAX(year) AS last_year
FROM energy_transitionn
WHERE primary_energy_consumption IS NOT NULL
GROUP BY country
),

energy_values AS (
SELECT
e.country,
    MAX(CASE
        WHEN e.year = g.first_year
        THEN e.primary_energy_consumption
    END) AS start_energy,

    MAX(CASE
        WHEN e.year = g.last_year
        THEN e.primary_energy_consumption
    END) AS end_energy

FROM energy_transitionn e
JOIN energy_growth g
    ON e.country = g.country
GROUP BY e.country

)

SELECT TOP 10
country,
start_energy,
end_energy,
ROUND(
    ((end_energy - start_energy) * 100.0)
    / NULLIF(start_energy,0),
    2
) AS growth_percentage
FROM energy_values
WHERE start_energy IS NOT NULL
AND end_energy IS NOT NULL
ORDER BY growth_percentage DESC;

---

 -- 2. Highest Energy Consumption Per Capita Growth

WITH per_capita_growth AS (
SELECT
country,
year,
energy_per_capita,
    FIRST_VALUE(energy_per_capita) OVER (
        PARTITION BY country
        ORDER BY year
    ) AS start_value,

    LAST_VALUE(energy_per_capita) OVER (
        PARTITION BY country
        ORDER BY year
        ROWS BETWEEN UNBOUNDED PRECEDING
        AND UNBOUNDED FOLLOWING
    ) AS end_value

FROM energy_transitionn
WHERE energy_per_capita IS NOT NULL

)

SELECT DISTINCT TOP 10
country,
start_value,
end_value,
ROUND(
    ((end_value - start_value) * 100.0)
    / NULLIF(start_value,0),
    2
) AS growth_percentage

FROM per_capita_growth
WHERE start_value IS NOT NULL
AND end_value IS NOT NULL
ORDER BY growth_percentage DESC;

---

 -- 3. Top 10 Countries by Energy Consumption Each Year

WITH country_energy AS (
SELECT
year,
country,
SUM(primary_energy_consumption) AS total_energy_consumption
FROM energy_transitionn
WHERE primary_energy_consumption IS NOT NULL
GROUP BY year, country
),

ranked_countries AS (
SELECT *,
DENSE_RANK() OVER (
PARTITION BY year
ORDER BY total_energy_consumption DESC
) AS ranking
FROM country_energy
)

SELECT
year,
country,
total_energy_consumption,
ranking
FROM ranked_countries
WHERE ranking <= 10
ORDER BY year, ranking;

/* =========================================================
SECTION 2: RENEWABLE ENERGY TRANSITION
========================================================= */

---

 -- 4. Countries with Fastest Renewable Adoption

WITH renewable_growth AS (
SELECT
country,
year,
renewables_share_energy,
    FIRST_VALUE(renewables_share_energy) OVER (
        PARTITION BY country
        ORDER BY year
    ) AS start_share,

    LAST_VALUE(renewables_share_energy) OVER (
        PARTITION BY country
        ORDER BY year
        ROWS BETWEEN UNBOUNDED PRECEDING
        AND UNBOUNDED FOLLOWING
    ) AS end_share

FROM energy_transitionn
WHERE renewables_share_energy IS NOT NULL

)

SELECT DISTINCT TOP 10
country,
start_share,
end_share,
ROUND(
    end_share - start_share,
    2
) AS adoption_growth

FROM renewable_growth
ORDER BY adoption_growth DESC;

---

 -- 5. Countries Crossing Renewable Share Milestones

SELECT
country,
MIN(CASE
    WHEN renewables_share_energy >= 25
    THEN year
END) AS first_25_percent,

MIN(CASE
    WHEN renewables_share_energy >= 50
    THEN year
END) AS first_50_percent,

MIN(CASE
    WHEN renewables_share_energy >= 75
    THEN year
END) AS first_75_percent

FROM energy_transitionn
WHERE renewables_share_energy IS NOT NULL
GROUP BY country
ORDER BY country;

---

-- 6. Countries with 5+ Consecutive Years of
-- Increasing Renewable Share
-----------------------------

WITH renewable_trend AS (
SELECT
country,
year,
renewables_share_energy,
    LAG(renewables_share_energy) OVER (
        PARTITION BY country
        ORDER BY year
    ) AS prev_share

FROM energy_transitionn
WHERE renewables_share_energy IS NOT NULL
),

increase_flag AS (
SELECT
country,
year,
    CASE
        WHEN renewables_share_energy > prev_share
        THEN 1
        ELSE 0
    END AS increased

FROM renewable_trend

),

streak_groups AS (
SELECT
country,
year,
increased,

    ROW_NUMBER() OVER (
        PARTITION BY country
        ORDER BY year
    )

    -

    ROW_NUMBER() OVER (
        PARTITION BY country, increased
        ORDER BY year
    ) AS grp

FROM increase_flag

)

SELECT
country,
MIN(year) AS streak_start,
MAX(year) AS streak_end,
COUNT(*) AS consecutive_years

FROM streak_groups
WHERE increased = 1
GROUP BY country, grp
HAVING COUNT(*) >= 5
ORDER BY consecutive_years DESC;

/* =========================================================
SECTION 3: CARBON EMISSIONS & SUSTAINABILITY
========================================================= */

---

-- 7. Countries with Greatest Reduction
-- in Carbon Intensity
----------------------

WITH carbon_trend AS (
SELECT
country,
year,
carbon_intensity_elec,
    FIRST_VALUE(carbon_intensity_elec) OVER (
        PARTITION BY country
        ORDER BY year
    ) AS start_intensity,

    LAST_VALUE(carbon_intensity_elec) OVER (
        PARTITION BY country
        ORDER BY year
        ROWS BETWEEN UNBOUNDED PRECEDING
        AND UNBOUNDED FOLLOWING
    ) AS end_intensity

FROM energy_transitionn
WHERE carbon_intensity_elec IS NOT NULL

)

SELECT DISTINCT TOP 10
country,
start_intensity,
end_intensity,
ROUND(
    start_intensity - end_intensity,
    2
) AS intensity_reduction

FROM carbon_trend
WHERE end_intensity < start_intensity
ORDER BY intensity_reduction DESC;

---

-- 8. Countries Increasing Renewables While
-- Reducing Carbon Intensity
----------------------------

WITH ranked AS (
SELECT
country,
year,
renewables_share_energy,
carbon_intensity_elec,
    ROW_NUMBER() OVER (
        PARTITION BY country
        ORDER BY year ASC
    ) AS rn_start,

    ROW_NUMBER() OVER (
        PARTITION BY country
        ORDER BY year DESC
    ) AS rn_end

FROM energy_transitionn
WHERE renewables_share_energy IS NOT NULL
  AND carbon_intensity_elec IS NOT NULL
),

start_end AS (
SELECT
country,
    MAX(CASE
        WHEN rn_start = 1
        THEN renewables_share_energy
    END) AS start_renewables,

    MAX(CASE
        WHEN rn_end = 1
        THEN renewables_share_energy
    END) AS end_renewables,

    MAX(CASE
        WHEN rn_start = 1
        THEN carbon_intensity_elec
    END) AS start_ci,

    MAX(CASE
        WHEN rn_end = 1
        THEN carbon_intensity_elec
    END) AS end_ci

FROM ranked
GROUP BY country

)

SELECT
country,
start_renewables,
end_renewables,

start_ci,
end_ci,

ROUND(
    end_renewables - start_renewables,
    2
) AS renewables_change,

ROUND(
    start_ci - end_ci,
    2
) AS carbon_intensity_reduction

FROM start_end
WHERE end_renewables > start_renewables
AND end_ci < start_ci
ORDER BY carbon_intensity_reduction DESC;

---

 -- 9. Countries Most Dependent on Fossil Fuels

WITH latest_year AS (
SELECT MAX(year) AS latest_year
FROM energy_transitionn
)

SELECT
country,
fossil_share_energy

FROM energy_transitionn
WHERE year = (
SELECT latest_year
FROM latest_year
)
AND fossil_share_energy IS NOT NULL
ORDER BY fossil_share_energy DESC;

---

-- 10. Countries with Most Diversified Energy Mix
-- (Using HHI Index)
--------------------

SELECT
country,
year,
coal_share_energy,
gas_share_energy,
oil_share_energy,
renewables_share_energy,

ROUND(
    POWER(coal_share_energy / 100.0, 2)
  + POWER(gas_share_energy / 100.0, 2)
  + POWER(oil_share_energy / 100.0, 2)
  + POWER(renewables_share_energy / 100.0, 2),
    4
) AS hhi_index

FROM energy_transitionn
WHERE coal_share_energy IS NOT NULL
AND gas_share_energy IS NOT NULL
AND oil_share_energy IS NOT NULL
AND renewables_share_energy IS NOT NULL

ORDER BY hhi_index ASC;

---

-- 11. Countries with Fastest Decline
-- in Fossil Fuel Share
-----------------------

WITH fossil_trend AS (
SELECT
country,
year,
fossil_share_energy,
    FIRST_VALUE(fossil_share_energy) OVER (
        PARTITION BY country
        ORDER BY year
    ) AS start_fossil,

    LAST_VALUE(fossil_share_energy) OVER (
        PARTITION BY country
        ORDER BY year
        ROWS BETWEEN UNBOUNDED PRECEDING
        AND UNBOUNDED FOLLOWING
    ) AS end_fossil

FROM energy_transitionn
WHERE fossil_share_energy IS NOT NULL

)

SELECT DISTINCT TOP 10
country,
start_fossil,
end_fossil,
ROUND(
    start_fossil - end_fossil,
    2
) AS reduction

FROM fossil_trend
WHERE end_fossil < start_fossil
ORDER BY reduction DESC;

---

 -- 12. Renewable Energy Leaders by Year

WITH ranked AS (
SELECT
year,
country,
renewables_share_energy,
    DENSE_RANK() OVER (
        PARTITION BY year
        ORDER BY renewables_share_energy DESC
    ) AS ranking

FROM energy_transitionn
WHERE renewables_share_energy IS NOT NULL

)

SELECT *
FROM ranked
WHERE ranking <= 5
ORDER BY year, ranking;

---

-- 13. Countries Achieving GDP Growth
-- While Reducing Carbon Intensity
----------------------------------

WITH ranked AS (
SELECT
country,
year,
gdp,
carbon_intensity_elec,
    ROW_NUMBER() OVER (
        PARTITION BY country
        ORDER BY year ASC
    ) AS rn_start,

    ROW_NUMBER() OVER (
        PARTITION BY country
        ORDER BY year DESC
    ) AS rn_end

FROM energy_transitionn
WHERE gdp IS NOT NULL
  AND carbon_intensity_elec IS NOT NULL

),

pivoted AS (
SELECT
country,
    MAX(CASE
        WHEN rn_start = 1
        THEN gdp
    END) AS start_gdp,

    MAX(CASE
        WHEN rn_end = 1
        THEN gdp
    END) AS end_gdp,

    MAX(CASE
        WHEN rn_start = 1
        THEN carbon_intensity_elec
    END) AS start_carbon,

    MAX(CASE
        WHEN rn_end = 1
        THEN carbon_intensity_elec
    END) AS end_carbon

FROM ranked
GROUP BY country

)

SELECT
country,
start_gdp,
end_gdp,
start_carbon,
end_carbon

FROM pivoted
WHERE end_gdp > start_gdp
AND end_carbon < start_carbon
ORDER BY end_gdp DESC;


