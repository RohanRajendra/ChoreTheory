-- =============================================================
-- DATABASE DUMP
-- DDL statements
-- DB objects
-- Event schedule
-- DML insert statements
-- =============================================================

-- Create and use the database
DROP DATABASE IF EXISTS project_db;
CREATE DATABASE project_db;
USE project_db;


-- =============================================================
-- DDL 
-- Table Creation statements
-- =============================================================


-- user table
DROP TABLE IF EXISTS user_table;
CREATE TABLE user_table (
    email VARCHAR(255) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    password VARCHAR(255) NOT NULL
);

-- house table
DROP TABLE IF EXISTS house;
CREATE TABLE house (
    house_id INT AUTO_INCREMENT PRIMARY KEY,
    address VARCHAR(255) NOT NULL UNIQUE,
    name VARCHAR(255) NOT NULL
);

-- user to house relationship many to many relationship. 
DROP TABLE IF EXISTS user_house;
CREATE TABLE user_house (
    email VARCHAR(255) NOT NULL,
    house_id INT NOT NULL,
    is_admin TINYINT(1) DEFAULT FALSE,
    PRIMARY KEY (email, house_id),
    FOREIGN KEY (email)
        REFERENCES user_table(email)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    FOREIGN KEY (house_id)
        REFERENCES house(house_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);

-- resource table
DROP TABLE IF EXISTS resource_table;
CREATE TABLE resource_table (
    resource_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    time_limit INT NOT NULL,
    icon VARCHAR(255),
    house_id INT NOT NULL,
    CHECK (time_limit > 0),
    FOREIGN KEY (house_id)
        REFERENCES house(house_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE -- resource cannot exist without a house
);

-- bookable spaces (subclass of resource)
DROP TABLE IF EXISTS resource_space;
CREATE TABLE resource_space (
    resource_id INT PRIMARY KEY,
    clean_after_use TINYINT(1) NOT NULL DEFAULT FALSE,
    max_occupancy INT NOT NULL,
    CHECK (max_occupancy > 0), -- ensures valid occupancy
    FOREIGN KEY (resource_id)
        REFERENCES resource_table(resource_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);

-- bookable appliances (subclass of resource)
DROP TABLE IF EXISTS resource_appliance;
CREATE TABLE resource_appliance (
    resource_id INT PRIMARY KEY,
    requires_maintenance TINYINT(1) NOT NULL DEFAULT FALSE,
    FOREIGN KEY (resource_id)
        REFERENCES resource_table(resource_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);

-- booking table
DROP TABLE IF EXISTS booking;
CREATE TABLE booking (
    booking_id INT AUTO_INCREMENT PRIMARY KEY,
    start_time DATETIME NOT NULL,
    end_time DATETIME NOT NULL,
    user_email VARCHAR(255),
    resource_id INT NOT NULL,
    CHECK (end_time > start_time), -- prevents invalid time ranges
    FOREIGN KEY (user_email)
        REFERENCES user_table(email)
        ON DELETE SET NULL
        ON UPDATE CASCADE, -- booking should persist even if user is deleted
    FOREIGN KEY (resource_id)
        REFERENCES resource_table(resource_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE -- booking meaningless without resource
);

-- reminder table (weak entity depends on booking)
DROP TABLE IF EXISTS reminder;
CREATE TABLE reminder (
    reminder_id INT AUTO_INCREMENT,
    booking_id INT NOT NULL,
    reminder_time DATETIME NOT NULL,
    status ENUM('pending', 'sent', 'cancelled') NOT NULL DEFAULT 'pending',
    message VARCHAR(255),
    PRIMARY KEY (reminder_id, booking_id),
    FOREIGN KEY (booking_id)
        REFERENCES booking(booking_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE -- reminder depends entirely on booking
);

-- expense table
DROP TABLE IF EXISTS expense;
CREATE TABLE expense (
	expense_id INT AUTO_INCREMENT PRIMARY KEY,
    amount DECIMAL(10,2) NOT NULL,
    description VARCHAR(255) NOT NULL,
    due_date DATE NOT NULL,
    creation_date DATE NOT NULL DEFAULT (CURRENT_DATE),
    receipts_attachment VARCHAR(500),
    is_recurring TINYINT(1) NOT NULL DEFAULT FALSE,
    created_by VARCHAR(255),
	UNIQUE (amount, description, due_date),
    CHECK (amount > 0), -- ensures valid monetary values
    FOREIGN KEY (created_by)
        REFERENCES user_table(email)
        ON DELETE SET NULL
        ON UPDATE CASCADE -- expense should persist if creator is removed
);

-- User to expense many to many realtionship. 
DROP TABLE IF EXISTS user_expense;
CREATE TABLE user_expense (
    email VARCHAR(255) NOT NULL,
    expense_id INT NOT NULL,
    user_share DECIMAL(10,2) NOT NULL,
    payment_status ENUM('unpaid', 'paid', 'partial') NOT NULL DEFAULT 'unpaid',
    PRIMARY KEY (email, expense_id),
    CHECK (user_share > 0), -- ensures valid share amounts
    FOREIGN KEY (email)
        REFERENCES user_table(email)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    FOREIGN KEY (expense_id)
        REFERENCES expense(expense_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);

-- =============================================================
-- DATABASE PROGRAMMING OBJECTS
-- Functions, Procedures, Triggers
-- =============================================================


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


-- =============================================================
-- DATABASE EVENTS
-- =============================================================

-- Enable the MySQL event scheduler if not already on.
-- This must be ON for any events to fire.

SET GLOBAL event_scheduler = ON;

-- -------------------------------------------------------------
-- nightly_reminder_status_update
-- Runs every day at midnight.
-- Updates any reminder whose reminder_time has passed and
-- whose status is still 'pending' to 'sent'.
-- Reminders with status 'cancelled' are intentionally
-- excluded — a cancelled reminder should never be auto-sent.
-- -------------------------------------------------------------
DROP EVENT IF EXISTS nightly_reminder_status_update;

CREATE EVENT nightly_reminder_status_update
    ON SCHEDULE EVERY 1 DAY
    STARTS (DATE(NOW()) + INTERVAL 1 DAY)  -- begins at the next midnight
    DO
        UPDATE reminder
        SET status = 'sent'
        WHERE status = 'pending'
          AND reminder_time < NOW();
          
          
-- =============================================================
-- DML 
-- insert statements
-- =============================================================

START TRANSACTION;

-- user_table
INSERT INTO user_table (email, name, password) VALUES
('cristiano.ronaldo@gmail.com', 'Cristiano Ronaldo', '$2b$12$KIXQ1u6LzJ8wF8hZp1lY8e7QeQ1u6LzJ8wF8hZp1lY8e7QeQ1u6LzJ8'),
('bhaichung.bhutia@gmail.com', 'Bhaichung Bhutia', '$2b$12$7uQ1u6LzJ8wF8hZp1lY8eKIXQeQ1u6LzJ8wF8hZp1lY8e7QeQ1u6'),
('carlos.luiz@gmail.com', 'Carlos Luiz', '$2b$12$Zp1lY8e7QeQ1u6LzJ8wF8hKIXQ1u6LzJ8wF8hZp1lY8e7QeQ1'),
('sunil.chhetri@gmail.com', 'Sunil Chhetri', '$2b$12$F8hZp1lY8e7QeQ1u6LzJ8wKIXQ1u6LzJ8wF8hZp1lY8e7QeQ'),
('lionel.messi@gmail.com', 'Lionel Messi', '$2b$12$e7QeQ1u6LzJ8wF8hZp1lY8KIXQ1u6LzJ8wF8hZp1lY8e7QeQ'),
('sergio.ramos@gmail.com', 'Sergio Ramos', '$2b$12$J8wF8hZp1lY8e7QeQ1u6LzKIXQ1u6LzJ8wF8hZp1lY8e7QeQ');

-- house
INSERT INTO house (house_id, name, address) VALUES
(1, 'Maple House', '123 Maple Street, Boston, MA'),
(2, 'Oak Residence', '456 Oak Avenue, Cambridge, MA'),
(3, 'Pine Villa', '789 Pine Road, Somerville, MA');

-- user_house
INSERT INTO user_house (email, house_id, is_admin) VALUES
('cristiano.ronaldo@gmail.com', 1, TRUE),
('bhaichung.bhutia@gmail.com', 1, FALSE),
('carlos.luiz@gmail.com', 1, FALSE),
('sunil.chhetri@gmail.com', 2, TRUE),
('lionel.messi@gmail.com', 2, FALSE),
('cristiano.ronaldo@gmail.com', 2, FALSE),
('sergio.ramos@gmail.com', 3, TRUE),
('carlos.luiz@gmail.com', 3, FALSE);

-- resource_table
INSERT INTO resource_table (resource_id, house_id, name, time_limit) VALUES
(1, 1, 'Living Room', 180),
(2, 1, 'Kitchen', 120),
(3, 2, 'Conference Room', 240),
(4, 2, 'Washing Machine', 90),
(5, 3, 'Garage', 180),
(6, 3, 'Dryer', 60);

-- resource_space (subclass)
INSERT INTO resource_space (resource_id, max_occupancy) VALUES
(1, 10),
(2, 5),
(3, 12);

-- resource_appliance (subclass)
INSERT INTO resource_appliance (resource_id, requires_maintenance) VALUES
(4, TRUE),
(6, FALSE),
(2, FALSE);

-- booking
INSERT INTO booking (booking_id, resource_id, user_email, start_time, end_time) VALUES
(1, 1, 'cristiano.ronaldo@gmail.com', '2026-04-14 10:00:00', '2026-04-14 12:00:00'),
(2, 2, 'bhaichung.bhutia@gmail.com', '2026-04-14 13:00:00', '2026-04-14 14:00:00'),
(3, 3, 'sunil.chhetri@gmail.com', '2026-04-15 09:00:00', '2026-04-15 11:00:00'),
(4, 4, 'lionel.messi@gmail.com', '2026-04-15 15:00:00', '2026-04-15 16:30:00'),
(5, 5, NULL, '2026-04-16 18:00:00', '2026-04-16 20:00:00'),
(6, 6, 'sergio.ramos@gmail.com', '2026-04-17 08:00:00', '2026-04-17 09:00:00');

-- reminder
INSERT INTO reminder (reminder_id, booking_id, reminder_time) VALUES
(2, 1, '2026-04-14 09:00:00'),
(3, 2, '2026-04-14 12:00:00'),
(4, 3, '2026-04-15 08:00:00'),
(5, 4, '2026-04-15 14:30:00'),
(6, 4, '2026-04-17 07:30:00');

-- expense
INSERT INTO expense (expense_id, amount, description, due_date, receipts_attachment, is_recurring, created_by) VALUES
(1, 1200.00, 'April Rent', '2026-04-01', NULL, 1, 'cristiano.ronaldo@gmail.com'),
(2, 150.50, 'Electric Bill', '2026-04-10', '/receipts/electric_april.pdf', 1, 'bhaichung.bhutia@gmail.com'),
(3, 75.00, 'Internet Bill', '2026-04-12', NULL, 1, 'sunil.chhetri@gmail.com'),
(4, 40.00, 'Cleaning Supplies', '2026-04-08', '/receipts/cleaning.png', 0, 'lionel.messi@gmail.com'),
(5, 200.00, 'Furniture Repair', '2026-04-20', NULL, 0, 'sergio.ramos@gmail.com'),
(6, 60.00, 'Water Bill', '2026-04-18', NULL, 1, NULL);

-- user_expense
INSERT INTO user_expense (email, expense_id, user_share, payment_status) VALUES
('bhaichung.bhutia@gmail.com', 1, 600.00, 'paid'),
('cristiano.ronaldo@gmail.com', 2, 75.25, 'unpaid'),
('sunil.chhetri@gmail.com', 2, 75.25, 'unpaid'),
('lionel.messi@gmail.com', 3, 37.50, 'partial'),
('lionel.messi@gmail.com', 5, 40.00, 'paid'),
('carlos.luiz@gmail.com', 6, 30.00, 'unpaid'),
('sergio.ramos@gmail.com', 6, 30.00, 'unpaid');

COMMIT;

