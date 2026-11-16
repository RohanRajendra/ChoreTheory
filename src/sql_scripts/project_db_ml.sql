-- =============================================================
-- ML PROCEDURES
-- Stored procedures that feed data into the ML models in
-- src/routers/ml.py
--
-- Procedure 1: get_monthly_expense_data
--   Used by: Linear Regression expense forecaster
--   Returns monthly expense totals for a house, ordered by time.
--   The Python layer assigns a period_index (0,1,2,...) and
--   trains sklearn LinearRegression on it.
--
-- Procedure 2: get_booking_matrix_data
--   Used by: KNN collaborative-filter resource recommender
--   Returns per-user per-resource booking counts for a house.
--   The Python layer pivots this into a user-resource matrix and
--   runs sklearn NearestNeighbors (cosine) to find similar users.
-- =============================================================

USE project_db;

DELIMITER $$

-- -------------------------------------------------------------
-- get_monthly_expense_data
-- Returns one row per (year, month) for a given house showing
-- the total expense amount that month.
-- Joins: expense -> user_expense -> user_house (3 tables)
-- Used by: /ml/houses/{id}/expense-forecast
-- -------------------------------------------------------------
DROP PROCEDURE IF EXISTS get_monthly_expense_data$$
CREATE PROCEDURE get_monthly_expense_data(IN p_house_id INT)
BEGIN
    SELECT
        YEAR(e.creation_date)  AS yr,
        MONTH(e.creation_date) AS mo,
        SUM(e.amount)          AS total
    FROM expense e
    JOIN user_expense ue ON e.expense_id = ue.expense_id
    JOIN user_house   uh ON ue.email     = uh.email
    WHERE uh.house_id = p_house_id
    GROUP BY
        YEAR(e.creation_date),
        MONTH(e.creation_date)
    ORDER BY yr ASC, mo ASC;
END$$


-- -------------------------------------------------------------
-- get_booking_matrix_data
-- Returns one row per (user, resource) pair showing how many
-- times that user has booked that resource in the house.
-- Joins: booking -> resource_table -> resource_space /
--        resource_appliance (4 tables via LEFT JOINs)
-- Used by: /ml/houses/{id}/resource-recommendations
-- -------------------------------------------------------------
DROP PROCEDURE IF EXISTS get_booking_matrix_data$$
CREATE PROCEDURE get_booking_matrix_data(IN p_house_id INT)
BEGIN
    SELECT
        b.user_email,
        r.resource_id,
        r.name AS resource_name,
        CASE
            WHEN rs.resource_id IS NOT NULL THEN 'space'
            WHEN ra.resource_id IS NOT NULL THEN 'appliance'
            ELSE 'base'
        END AS resource_type,
        COUNT(*) AS booking_count
    FROM booking b
    JOIN resource_table   r  ON b.resource_id  = r.resource_id
    LEFT JOIN resource_space    rs ON r.resource_id = rs.resource_id
    LEFT JOIN resource_appliance ra ON r.resource_id = ra.resource_id
    WHERE r.house_id = p_house_id
    GROUP BY
        b.user_email,
        r.resource_id,
        r.name,
        resource_type;
END$$


DELIMITER ;
