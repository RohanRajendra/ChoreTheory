-- =============================================================
-- DATABASE PROGRAMMING OBJECTS
-- Functions, Procedures, Triggers
-- =============================================================

USE project_db;

DELIMITER $$

-- =============================================================
-- FUNCTIONS
-- =============================================================

-- -------------------------------------------------------------
-- get_total_house_expenses
-- Returns the total amount of all expenses created by users
-- belonging to a given house.
-- -------------------------------------------------------------
DROP FUNCTION IF EXISTS get_total_house_expenses$$
CREATE FUNCTION get_total_house_expenses(p_house_id INT)
RETURNS DECIMAL(10,2)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE total DECIMAL(10,2) DEFAULT 0.00;

    SELECT COALESCE(SUM(e.amount), 0.00)
    INTO total
    FROM expense e
    JOIN user_expense ue ON e.expense_id = ue.expense_id
    JOIN user_house uh ON ue.email = uh.email
    WHERE uh.house_id = p_house_id;

    RETURN total;
END$$


-- -------------------------------------------------------------
-- get_user_balance
-- Returns the total unpaid amount a user owes across all
-- expenses in a given house. Partial payments are counted
-- as unpaid since the full share has not been settled.
-- -------------------------------------------------------------
DROP FUNCTION IF EXISTS get_user_balance$$
CREATE FUNCTION get_user_balance(p_email VARCHAR(255), p_house_id INT)
RETURNS DECIMAL(10,2)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE balance DECIMAL(10,2) DEFAULT 0.00;

    SELECT COALESCE(SUM(ue.user_share), 0.00)
    INTO balance
    FROM user_expense ue
    JOIN expense e ON ue.expense_id = e.expense_id
    JOIN user_house uh ON ue.email = uh.email
    WHERE ue.email = p_email
      AND uh.house_id = p_house_id
      AND ue.payment_status != 'paid';

    RETURN balance;
END$$


-- -------------------------------------------------------------
-- is_resource_available
-- Returns 1 if the resource has no overlapping bookings
-- in the requested window, 0 if it is already booked.
-- Overlap condition: existing booking starts before the
-- requested end AND ends after the requested start.
-- -------------------------------------------------------------
DROP FUNCTION IF EXISTS is_resource_available$$
CREATE FUNCTION is_resource_available(
    p_resource_id INT,
    p_start_time  DATETIME,
    p_end_time    DATETIME
)
RETURNS TINYINT(1)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE conflict_count INT DEFAULT 0;

    SELECT COUNT(*)
    INTO conflict_count
    FROM booking
    WHERE resource_id = p_resource_id
      AND start_time  < p_end_time
      AND end_time    > p_start_time;

    IF conflict_count > 0 THEN
        RETURN 0;
    END IF;

    RETURN 1;
END$$


-- =============================================================
-- PROCEDURES
-- =============================================================

-- -------------------------------------------------------------
-- create_booking
-- Validates availability using is_resource_available then
-- inserts a new booking. Raises an error if the resource
-- is already booked in the requested window.
-- -------------------------------------------------------------
DROP PROCEDURE IF EXISTS create_booking$$
CREATE PROCEDURE create_booking(
    IN p_user_email  VARCHAR(255),
    IN p_resource_id INT,
    IN p_start_time  DATETIME,
    IN p_end_time    DATETIME
)
BEGIN
    -- Guard: time window must be valid
    IF p_end_time <= p_start_time THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'end_time must be after start_time.';
    END IF;

    -- Guard: resource must be available in the requested window
    IF is_resource_available(p_resource_id, p_start_time, p_end_time) = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Resource is already booked for the requested time window.';
    END IF;

    INSERT INTO booking (start_time, end_time, user_email, resource_id)
    VALUES (p_start_time, p_end_time, p_user_email, p_resource_id);
END$$


-- -------------------------------------------------------------
-- add_user_to_house
-- Verifies the calling user is an admin of the house before
-- inserting a new member into user_house. Raises an error
-- if the caller is not an admin.
-- -------------------------------------------------------------
DROP PROCEDURE IF EXISTS add_user_to_house$$
CREATE PROCEDURE add_user_to_house(
    IN p_admin_email    VARCHAR(255),
    IN p_new_user_email VARCHAR(255),
    IN p_house_id       INT
)
BEGIN
    DECLARE admin_check INT DEFAULT 0;

    -- Verify caller is an admin of this house
    SELECT COUNT(*)
    INTO admin_check
    FROM user_house
    WHERE email    = p_admin_email
      AND house_id = p_house_id
      AND is_admin = TRUE;

    IF admin_check = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Only an admin of this house can add new members.';
    END IF;

    -- Guard: user must not already be a member
    IF EXISTS (
        SELECT 1 FROM user_house
        WHERE email = p_new_user_email AND house_id = p_house_id
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'User is already a member of this house.';
    END IF;

    INSERT INTO user_house (email, house_id, is_admin)
    VALUES (p_new_user_email, p_house_id, FALSE);
END$$


-- -------------------------------------------------------------
-- split_expense
-- Inserts user_expense rows for a list of participants.
-- Accepts participants as a comma-separated string of emails
-- and a corresponding comma-separated string of share amounts.
-- Each pair is processed as a loop iteration.
-- NOTE: MySQL does not support array parameters. The caller
-- must pass equal-length comma-separated strings.
-- For application use, call this procedure once per participant
-- rather than using the CSV approach — see overload below.
-- -------------------------------------------------------------

-- Single-participant version (call once per user from app layer)
DROP PROCEDURE IF EXISTS split_expense$$
CREATE PROCEDURE split_expense(
    IN p_expense_id INT,
    IN p_email      VARCHAR(255),
    IN p_share      DECIMAL(10,2)
)
BEGIN
    IF p_share <= 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'User share must be a positive amount.';
    END IF;

    -- Guard: do not insert a duplicate participant
    IF EXISTS (
        SELECT 1 FROM user_expense
        WHERE expense_id = p_expense_id AND email = p_email
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'This user has already been added to this expense.';
    END IF;

    INSERT INTO user_expense (email, expense_id, user_share, payment_status)
    VALUES (p_email, p_expense_id, p_share, 'unpaid');
END$$


-- -------------------------------------------------------------
-- settle_payment
-- Updates a user's payment_status to 'paid' for a given
-- expense. Raises an error if the record does not exist
-- or is already paid.
-- -------------------------------------------------------------
DROP PROCEDURE IF EXISTS settle_payment$$
CREATE PROCEDURE settle_payment(
    IN p_email      VARCHAR(255),
    IN p_expense_id INT
)
BEGIN
    DECLARE current_status VARCHAR(20) DEFAULT NULL;

    SELECT payment_status
    INTO current_status
    FROM user_expense
    WHERE email = p_email AND expense_id = p_expense_id;

    IF current_status IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'No expense record found for this user.';
    END IF;

    IF current_status = 'paid' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'This expense is already marked as paid.';
    END IF;

    UPDATE user_expense
    SET payment_status = 'paid'
    WHERE email = p_email AND expense_id = p_expense_id;
END$$


-- =============================================================
-- TRIGGERS
-- =============================================================

-- -------------------------------------------------------------
-- before_booking_insert
-- Fires before every INSERT on booking.
-- Validates end_time > start_time and checks for resource
-- conflicts. The CHECK constraint on the table handles the
-- time order but this trigger reinforces it with a clear
-- error message and also enforces the overlap rule which
-- a CHECK constraint alone cannot do.
-- -------------------------------------------------------------
DROP TRIGGER IF EXISTS before_booking_insert$$
CREATE TRIGGER before_booking_insert
BEFORE INSERT ON booking
FOR EACH ROW
BEGIN
    IF NEW.end_time <= NEW.start_time THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Booking end_time must be after start_time.';
    END IF;

    IF is_resource_available(NEW.resource_id, NEW.start_time, NEW.end_time) = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Resource is already booked for the requested time window.';
    END IF;
END$$


-- -------------------------------------------------------------
-- after_booking_insert
-- Fires after every INSERT on booking.
-- Automatically creates a default reminder 30 minutes before
-- the booking start time so the user always has a reminder
-- without needing to create one manually.
-- -------------------------------------------------------------
DROP TRIGGER IF EXISTS after_booking_insert$$
CREATE TRIGGER after_booking_insert
AFTER INSERT ON booking
FOR EACH ROW
BEGIN
    INSERT INTO reminder (booking_id, reminder_time, status, message)
    VALUES (
        NEW.booking_id,
        DATE_SUB(NEW.start_time, INTERVAL 30 MINUTE),
        'pending',
        'Reminder: your booking starts in 30 minutes.'
    );
END$$


-- -------------------------------------------------------------
-- after_expense_insert
-- Fires after every INSERT on expense.
-- Automatically inserts a user_expense row for the creator
-- so the creator is always a participant in their own expense.
-- Only fires when created_by is not NULL.
-- -------------------------------------------------------------
DROP TRIGGER IF EXISTS after_expense_insert$$
CREATE TRIGGER after_expense_insert
AFTER INSERT ON expense
FOR EACH ROW
BEGIN
    IF NEW.created_by IS NOT NULL THEN
        INSERT INTO user_expense (email, expense_id, user_share, payment_status)
        VALUES (NEW.created_by, NEW.expense_id, NEW.amount, 'unpaid');
    END IF;
END$$


-- -------------------------------------------------------------
-- before_user_house_insert
-- Fires before every INSERT on user_house.
-- Enforces that each house has at most one admin.
-- Raises an error if is_admin = TRUE and an admin already
-- exists for that house.
-- -------------------------------------------------------------
DROP TRIGGER IF EXISTS before_user_house_insert$$
CREATE TRIGGER before_user_house_insert
BEFORE INSERT ON user_house
FOR EACH ROW
BEGIN
    DECLARE existing_admin INT DEFAULT 0;

    IF NEW.is_admin = TRUE THEN
        SELECT COUNT(*)
        INTO existing_admin
        FROM user_house
        WHERE house_id = NEW.house_id
          AND is_admin = TRUE;

        IF existing_admin > 0 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'This house already has an admin.';
        END IF;
    END IF;
END$$


DELIMITER ;