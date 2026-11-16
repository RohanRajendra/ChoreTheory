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
    role ENUM('admin', 'member', 'guest') NOT NULL DEFAULT 'member',
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
-- Returns the total amount of all expenses associated with
-- users belonging to a given house.
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
-- Returns the total unpaid/partial amount a user owes across
-- all expenses in a given house.
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
-- Returns 1 if no overlapping bookings exist for the resource
-- in the requested window, 0 otherwise.
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
-- PROCEDURES — USERS
-- =============================================================

-- -------------------------------------------------------------
-- create_user
-- Inserts a new user. Raises error if email already exists.
-- Password is expected to be pre-hashed by the application.
-- -------------------------------------------------------------
DROP PROCEDURE IF EXISTS create_user$$
CREATE PROCEDURE create_user(
    IN p_email    VARCHAR(255),
    IN p_name     VARCHAR(255),
    IN p_password VARCHAR(255)
)
BEGIN
    IF EXISTS (SELECT 1 FROM user_table WHERE email = p_email) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'A user with this email already exists.';
    END IF;

    INSERT INTO user_table (email, name, password)
    VALUES (p_email, p_name, p_password);
END$$


-- -------------------------------------------------------------
-- get_user
-- Returns the user row for the given email.
-- Password is excluded from the result set.
-- -------------------------------------------------------------
DROP PROCEDURE IF EXISTS get_user$$
CREATE PROCEDURE get_user(IN p_email VARCHAR(255))
BEGIN
    SELECT email, name
    FROM user_table
    WHERE email = p_email;
END$$


-- -------------------------------------------------------------
-- login_user
-- Returns the stored password hash for the given email so
-- the application layer can verify it. Returns empty result
-- if user does not exist.
-- -------------------------------------------------------------
DROP PROCEDURE IF EXISTS login_user$$
CREATE PROCEDURE login_user(IN p_email VARCHAR(255))
BEGIN
    SELECT email, name, password
    FROM user_table
    WHERE email = p_email;
END$$


-- -------------------------------------------------------------
-- update_user
-- Updates name and/or password for a given user.
-- Null arguments leave the existing value unchanged.
-- -------------------------------------------------------------
DROP PROCEDURE IF EXISTS update_user$$
CREATE PROCEDURE update_user(
    IN p_email    VARCHAR(255),
    IN p_name     VARCHAR(255),
    IN p_password VARCHAR(255)
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM user_table WHERE email = p_email) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'User not found.';
    END IF;

    UPDATE user_table
    SET
        name     = COALESCE(p_name, name),
        password = COALESCE(p_password, password)
    WHERE email = p_email;
END$$


-- -------------------------------------------------------------
-- delete_user
-- Deletes a user. Cascades to user_house and user_expense.
-- Bookings created by this user have user_email SET NULL.
-- Expenses created by this user have created_by SET NULL.
-- -------------------------------------------------------------
DROP PROCEDURE IF EXISTS delete_user$$
CREATE PROCEDURE delete_user(IN p_email VARCHAR(255))
BEGIN
    IF NOT EXISTS (SELECT 1 FROM user_table WHERE email = p_email) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'User not found.';
    END IF;

    DELETE FROM user_table WHERE email = p_email;
END$$


-- =============================================================
-- PROCEDURES — HOUSES
-- =============================================================

-- -------------------------------------------------------------
-- create_house
-- Creates a house and inserts the creator as its admin in
-- user_house in a single operation.
-- Returns the new house_id via OUT parameter.
-- -------------------------------------------------------------
DROP PROCEDURE IF EXISTS create_house$$
CREATE PROCEDURE create_house(
    IN  p_address       VARCHAR(255),
    IN  p_name          VARCHAR(255),
    IN  p_creator_email VARCHAR(255),
    OUT p_house_id      INT
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM user_table WHERE email = p_creator_email) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Creator user not found.';
    END IF;

    IF EXISTS (SELECT 1 FROM house WHERE address = p_address) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'A house with this address already exists.';
    END IF;

    INSERT INTO house (address, name)
    VALUES (p_address, p_name);

    SET p_house_id = LAST_INSERT_ID();

    -- is_admin = TRUE: before_user_house_insert trigger will
    -- confirm no admin exists yet, which is safe on a new house.
    INSERT INTO user_house (email, house_id, is_admin, role)
    VALUES (p_creator_email, p_house_id, TRUE, 'admin');
END$$


-- -------------------------------------------------------------
-- get_house
-- Returns house details for a given house_id.
-- -------------------------------------------------------------
DROP PROCEDURE IF EXISTS get_house$$
CREATE PROCEDURE get_house(IN p_house_id INT)
BEGIN
    SELECT house_id, address, name
    FROM house
    WHERE house_id = p_house_id;
END$$


-- -------------------------------------------------------------
-- get_user_houses
-- Returns all houses a user belongs to, including their
-- admin status in each house.
-- -------------------------------------------------------------
DROP PROCEDURE IF EXISTS get_user_houses$$
CREATE PROCEDURE get_user_houses(IN p_email VARCHAR(255))
BEGIN
    SELECT h.house_id, h.address, h.name, uh.is_admin, uh.role
    FROM house h
    JOIN user_house uh ON h.house_id = uh.house_id
    WHERE uh.email = p_email;
END$$


-- -------------------------------------------------------------
-- update_house
-- Updates house name and/or address.
-- Null arguments leave the existing value unchanged.
-- -------------------------------------------------------------
DROP PROCEDURE IF EXISTS update_house$$
CREATE PROCEDURE update_house(
    IN p_house_id INT,
    IN p_address  VARCHAR(255),
    IN p_name     VARCHAR(255)
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM house WHERE house_id = p_house_id) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'House not found.';
    END IF;

    UPDATE house
    SET
        address = COALESCE(p_address, address),
        name    = COALESCE(p_name, name)
    WHERE house_id = p_house_id;
END$$


-- -------------------------------------------------------------
-- delete_house
-- Deletes a house. Cascades to user_house and resource_table.
-- -------------------------------------------------------------
DROP PROCEDURE IF EXISTS delete_house$$
CREATE PROCEDURE delete_house(IN p_house_id INT)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM house WHERE house_id = p_house_id) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'House not found.';
    END IF;

    DELETE FROM house WHERE house_id = p_house_id;
END$$


-- -------------------------------------------------------------
-- add_user_to_house
-- Verifies the calling user is admin before inserting a new
-- member. Raises error if caller is not admin or user is
-- already a member.
-- -------------------------------------------------------------
DROP PROCEDURE IF EXISTS add_user_to_house$$
CREATE PROCEDURE add_user_to_house(
    IN p_admin_email    VARCHAR(255),
    IN p_new_user_email VARCHAR(255),
    IN p_house_id       INT,
    IN p_role           VARCHAR(20)
)
BEGIN
    DECLARE admin_check INT DEFAULT 0;

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

    IF NOT EXISTS (SELECT 1 FROM user_table WHERE email = p_new_user_email) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'The user to be added does not exist.';
    END IF;

    IF EXISTS (
        SELECT 1 FROM user_house
        WHERE email = p_new_user_email AND house_id = p_house_id
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'User is already a member of this house.';
    END IF;

    INSERT INTO user_house (email, house_id, is_admin, role)
    VALUES (p_new_user_email, p_house_id, FALSE, COALESCE(p_role, 'member'));
END$$


-- -------------------------------------------------------------
-- get_house_members
-- Returns all members of a house with their admin status.
-- -------------------------------------------------------------
DROP PROCEDURE IF EXISTS get_house_members$$
CREATE PROCEDURE get_house_members(IN p_house_id INT)
BEGIN
    SELECT u.email, u.name, uh.is_admin, uh.role
    FROM user_table u
    JOIN user_house uh ON u.email = uh.email
    WHERE uh.house_id = p_house_id;
END$$


-- -------------------------------------------------------------
-- remove_member_from_house
-- Removes a user from a house. Raises error if attempting
-- to remove the admin — house must be deleted instead.
-- -------------------------------------------------------------
DROP PROCEDURE IF EXISTS remove_member_from_house$$
CREATE PROCEDURE remove_member_from_house(
    IN p_email    VARCHAR(255),
    IN p_house_id INT
)
BEGIN
    DECLARE member_is_admin TINYINT(1) DEFAULT FALSE;

    SELECT is_admin
    INTO member_is_admin
    FROM user_house
    WHERE email = p_email AND house_id = p_house_id;

    IF member_is_admin IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'User is not a member of this house.';
    END IF;

    IF member_is_admin = TRUE THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Cannot remove the admin from a house. Delete the house instead.';
    END IF;

    DELETE FROM user_house
    WHERE email = p_email AND house_id = p_house_id;
END$$


-- =============================================================
-- PROCEDURES — RESOURCES
-- =============================================================

-- -------------------------------------------------------------
-- create_resource
-- Inserts a base resource. Returns new resource_id via OUT.
-- Subclass insert is handled by separate procedures below.
-- -------------------------------------------------------------
DROP PROCEDURE IF EXISTS create_resource$$
CREATE PROCEDURE create_resource(
    IN  p_name       VARCHAR(255),
    IN  p_time_limit INT,
    IN  p_icon       VARCHAR(255),
    IN  p_house_id   INT,
    OUT p_resource_id INT
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM house WHERE house_id = p_house_id) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'House not found.';
    END IF;

    IF p_time_limit <= 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'time_limit must be a positive number of minutes.';
    END IF;

    INSERT INTO resource_table (name, time_limit, icon, house_id)
    VALUES (p_name, p_time_limit, p_icon, p_house_id);

    SET p_resource_id = LAST_INSERT_ID();
END$$


-- -------------------------------------------------------------
-- create_space
-- Inserts a resource_space row for an existing resource.
-- Call after create_resource when classifying as a Space.
-- -------------------------------------------------------------
DROP PROCEDURE IF EXISTS create_space$$
CREATE PROCEDURE create_space(
    IN p_resource_id    INT,
    IN p_clean_after_use TINYINT(1),
    IN p_max_occupancy  INT
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM resource_table WHERE resource_id = p_resource_id) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Resource not found.';
    END IF;

    IF EXISTS (SELECT 1 FROM resource_space WHERE resource_id = p_resource_id) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'This resource is already classified as a Space.';
    END IF;

    IF EXISTS (SELECT 1 FROM resource_appliance WHERE resource_id = p_resource_id) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'This resource is already classified as an Appliance.';
    END IF;

    INSERT INTO resource_space (resource_id, clean_after_use, max_occupancy)
    VALUES (p_resource_id, p_clean_after_use, p_max_occupancy);
END$$


-- -------------------------------------------------------------
-- create_appliance
-- Inserts a resource_appliance row for an existing resource.
-- Call after create_resource when classifying as an Appliance.
-- -------------------------------------------------------------
DROP PROCEDURE IF EXISTS create_appliance$$
CREATE PROCEDURE create_appliance(
    IN p_resource_id          INT,
    IN p_requires_maintenance TINYINT(1)
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM resource_table WHERE resource_id = p_resource_id) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Resource not found.';
    END IF;

    IF EXISTS (SELECT 1 FROM resource_appliance WHERE resource_id = p_resource_id) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'This resource is already classified as an Appliance.';
    END IF;

    IF EXISTS (SELECT 1 FROM resource_space WHERE resource_id = p_resource_id) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'This resource is already classified as a Space.';
    END IF;

    INSERT INTO resource_appliance (resource_id, requires_maintenance)
    VALUES (p_resource_id, p_requires_maintenance);
END$$


-- -------------------------------------------------------------
-- get_resource
-- Returns resource details joined with subclass data.
-- resource_type will be 'space', 'appliance', or 'base'.
-- -------------------------------------------------------------
DROP PROCEDURE IF EXISTS get_resource$$
CREATE PROCEDURE get_resource(IN p_resource_id INT)
BEGIN
    SELECT
        r.resource_id,
        r.name,
        r.time_limit,
        r.icon,
        r.house_id,
        CASE
            WHEN rs.resource_id IS NOT NULL THEN 'space'
            WHEN ra.resource_id IS NOT NULL THEN 'appliance'
            ELSE 'base'
        END AS resource_type,
        rs.clean_after_use,
        rs.max_occupancy,
        ra.requires_maintenance
    FROM resource_table r
    LEFT JOIN resource_space    rs ON r.resource_id = rs.resource_id
    LEFT JOIN resource_appliance ra ON r.resource_id = ra.resource_id
    WHERE r.resource_id = p_resource_id;
END$$


-- -------------------------------------------------------------
-- get_house_resources
-- Returns all resources for a house with subclass data.
-- -------------------------------------------------------------
DROP PROCEDURE IF EXISTS get_house_resources$$
CREATE PROCEDURE get_house_resources(IN p_house_id INT)
BEGIN
    SELECT
        r.resource_id,
        r.name,
        r.time_limit,
        r.icon,
        CASE
            WHEN rs.resource_id IS NOT NULL THEN 'space'
            WHEN ra.resource_id IS NOT NULL THEN 'appliance'
            ELSE 'base'
        END AS resource_type,
        rs.clean_after_use,
        rs.max_occupancy,
        ra.requires_maintenance
    FROM resource_table r
    LEFT JOIN resource_space     rs ON r.resource_id = rs.resource_id
    LEFT JOIN resource_appliance ra ON r.resource_id = ra.resource_id
    WHERE r.house_id = p_house_id;
END$$


-- -------------------------------------------------------------
-- update_resource
-- Updates base resource fields. Null arguments leave the
-- existing value unchanged.
-- -------------------------------------------------------------
DROP PROCEDURE IF EXISTS update_resource$$
CREATE PROCEDURE update_resource(
    IN p_resource_id INT,
    IN p_name        VARCHAR(255),
    IN p_time_limit  INT,
    IN p_icon        VARCHAR(255)
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM resource_table WHERE resource_id = p_resource_id) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Resource not found.';
    END IF;

    IF p_time_limit IS NOT NULL AND p_time_limit <= 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'time_limit must be a positive number of minutes.';
    END IF;

    UPDATE resource_table
    SET
        name       = COALESCE(p_name, name),
        time_limit = COALESCE(p_time_limit, time_limit),
        icon       = COALESCE(p_icon, icon)
    WHERE resource_id = p_resource_id;
END$$


-- -------------------------------------------------------------
-- delete_resource
-- Deletes a resource. Cascades to subclass tables and bookings.
-- -------------------------------------------------------------
DROP PROCEDURE IF EXISTS delete_resource$$
CREATE PROCEDURE delete_resource(IN p_resource_id INT)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM resource_table WHERE resource_id = p_resource_id) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Resource not found.';
    END IF;

    DELETE FROM resource_table WHERE resource_id = p_resource_id;
END$$


-- =============================================================
-- PROCEDURES — BOOKINGS
-- =============================================================

-- -------------------------------------------------------------
-- create_booking
-- Validates availability then inserts a booking.
-- The after_booking_insert trigger auto-creates a reminder.
-- -------------------------------------------------------------
DROP PROCEDURE IF EXISTS create_booking$$
CREATE PROCEDURE create_booking(
    IN p_user_email  VARCHAR(255),
    IN p_resource_id INT,
    IN p_start_time  DATETIME,
    IN p_end_time    DATETIME
)
BEGIN
    IF p_end_time <= p_start_time THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'end_time must be after start_time.';
    END IF;

    IF is_resource_available(p_resource_id, p_start_time, p_end_time) = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Resource is already booked for the requested time window.';
    END IF;

    INSERT INTO booking (start_time, end_time, user_email, resource_id)
    VALUES (p_start_time, p_end_time, p_user_email, p_resource_id);
END$$


-- -------------------------------------------------------------
-- get_booking
-- Returns a single booking by ID.
-- -------------------------------------------------------------
DROP PROCEDURE IF EXISTS get_booking$$
CREATE PROCEDURE get_booking(IN p_booking_id INT)
BEGIN
    SELECT
        b.booking_id,
        b.start_time,
        b.end_time,
        b.user_email,
        b.resource_id,
        r.name AS resource_name
    FROM booking b
    JOIN resource_table r ON b.resource_id = r.resource_id
    WHERE b.booking_id = p_booking_id;
END$$


-- -------------------------------------------------------------
-- get_user_bookings
-- Returns all bookings for a given user with resource name.
-- -------------------------------------------------------------
DROP PROCEDURE IF EXISTS get_user_bookings$$
CREATE PROCEDURE get_user_bookings(IN p_email VARCHAR(255))
BEGIN
    SELECT
        b.booking_id,
        b.start_time,
        b.end_time,
        b.resource_id,
        r.name AS resource_name,
        r.house_id
    FROM booking b
    JOIN resource_table r ON b.resource_id = r.resource_id
    WHERE b.user_email = p_email
    ORDER BY b.start_time DESC;
END$$


-- -------------------------------------------------------------
-- delete_booking
-- Deletes a booking. Cascades to all its reminders.
-- -------------------------------------------------------------
DROP PROCEDURE IF EXISTS delete_booking$$
CREATE PROCEDURE delete_booking(IN p_booking_id INT)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM booking WHERE booking_id = p_booking_id) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Booking not found.';
    END IF;

    DELETE FROM booking WHERE booking_id = p_booking_id;
END$$


-- =============================================================
-- PROCEDURES — REMINDERS
-- =============================================================

-- -------------------------------------------------------------
-- create_reminder
-- Inserts a reminder for an existing booking.
-- -------------------------------------------------------------
DROP PROCEDURE IF EXISTS create_reminder$$
CREATE PROCEDURE create_reminder(
    IN p_booking_id   INT,
    IN p_reminder_time DATETIME,
    IN p_message      VARCHAR(255)
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM booking WHERE booking_id = p_booking_id) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Booking not found.';
    END IF;

    INSERT INTO reminder (booking_id, reminder_time, status, message)
    VALUES (p_booking_id, p_reminder_time, 'pending', p_message);
END$$


-- -------------------------------------------------------------
-- get_booking_reminders
-- Returns all reminders for a given booking.
-- -------------------------------------------------------------
DROP PROCEDURE IF EXISTS get_booking_reminders$$
CREATE PROCEDURE get_booking_reminders(IN p_booking_id INT)
BEGIN
    SELECT reminder_id, booking_id, reminder_time, status, message
    FROM reminder
    WHERE booking_id = p_booking_id
    ORDER BY reminder_time ASC;
END$$


-- -------------------------------------------------------------
-- update_reminder
-- Updates reminder_time and/or message.
-- Only pending reminders can be updated.
-- -------------------------------------------------------------
DROP PROCEDURE IF EXISTS update_reminder$$
CREATE PROCEDURE update_reminder(
    IN p_reminder_id   INT,
    IN p_booking_id    INT,
    IN p_reminder_time DATETIME,
    IN p_message       VARCHAR(255)
)
BEGIN
    DECLARE current_status VARCHAR(20) DEFAULT NULL;

    SELECT status INTO current_status
    FROM reminder
    WHERE reminder_id = p_reminder_id AND booking_id = p_booking_id;

    IF current_status IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Reminder not found.';
    END IF;

    IF current_status != 'pending' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Only pending reminders can be updated.';
    END IF;

    UPDATE reminder
    SET
        reminder_time = COALESCE(p_reminder_time, reminder_time),
        message       = COALESCE(p_message, message)
    WHERE reminder_id = p_reminder_id AND booking_id = p_booking_id;
END$$


-- -------------------------------------------------------------
-- delete_reminder
-- Deletes a reminder by composite PK.
-- -------------------------------------------------------------
DROP PROCEDURE IF EXISTS delete_reminder$$
CREATE PROCEDURE delete_reminder(
    IN p_reminder_id INT,
    IN p_booking_id  INT
)
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM reminder
        WHERE reminder_id = p_reminder_id AND booking_id = p_booking_id
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Reminder not found.';
    END IF;

    DELETE FROM reminder
    WHERE reminder_id = p_reminder_id AND booking_id = p_booking_id;
END$$


-- =============================================================
-- PROCEDURES — EXPENSES
-- =============================================================

-- -------------------------------------------------------------
-- create_expense
-- Inserts a new expense. The after_expense_insert trigger
-- automatically adds the creator to user_expense for the
-- full amount with status 'unpaid'.
-- -------------------------------------------------------------
DROP PROCEDURE IF EXISTS create_expense$$
CREATE PROCEDURE create_expense(
    IN p_amount              DECIMAL(10,2),
    IN p_description         VARCHAR(255),
    IN p_due_date            DATE,
    IN p_receipts_attachment VARCHAR(500),
    IN p_is_recurring        TINYINT(1),
    IN p_created_by          VARCHAR(255)
)
BEGIN
    IF p_amount <= 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Expense amount must be positive.';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM user_table WHERE email = p_created_by) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Creating user not found.';
    END IF;

    INSERT INTO expense (
        amount, description, due_date,
        receipts_attachment, is_recurring, created_by
    )
    VALUES (
        p_amount, p_description, p_due_date,
        p_receipts_attachment, p_is_recurring, p_created_by
    );
END$$


-- -------------------------------------------------------------
-- get_expense
-- Returns a single expense by ID with creator name.
-- -------------------------------------------------------------
DROP PROCEDURE IF EXISTS get_expense$$
CREATE PROCEDURE get_expense(IN p_expense_id INT)
BEGIN
    SELECT
        e.expense_id,
        e.amount,
        e.description,
        e.due_date,
        e.creation_date,
        e.receipts_attachment,
        e.is_recurring,
        e.created_by,
        u.name AS creator_name
    FROM expense e
    LEFT JOIN user_table u ON e.created_by = u.email
    WHERE e.expense_id = p_expense_id;
END$$


-- -------------------------------------------------------------
-- get_user_expenses
-- Returns all expenses a user is a participant in,
-- along with their individual share and payment status.
-- -------------------------------------------------------------
DROP PROCEDURE IF EXISTS get_user_expenses$$
CREATE PROCEDURE get_user_expenses(IN p_email VARCHAR(255))
BEGIN
    SELECT
        e.expense_id,
        e.amount,
        e.description,
        e.due_date,
        e.is_recurring,
        e.created_by,
        ue.user_share,
        ue.payment_status
    FROM expense e
    JOIN user_expense ue ON e.expense_id = ue.expense_id
    WHERE ue.email = p_email
    ORDER BY e.due_date ASC;
END$$


-- -------------------------------------------------------------
-- get_expense_participants
-- Returns all users split on a given expense with their
-- share and payment status.
-- -------------------------------------------------------------
DROP PROCEDURE IF EXISTS get_expense_participants$$
CREATE PROCEDURE get_expense_participants(IN p_expense_id INT)
BEGIN
    SELECT
        u.email,
        u.name,
        ue.user_share,
        ue.payment_status
    FROM user_expense ue
    JOIN user_table u ON ue.email = u.email
    WHERE ue.expense_id = p_expense_id;
END$$


-- -------------------------------------------------------------
-- delete_expense
-- Deletes an expense. Cascades to user_expense rows.
-- -------------------------------------------------------------
DROP PROCEDURE IF EXISTS delete_expense$$
CREATE PROCEDURE delete_expense(IN p_expense_id INT)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM expense WHERE expense_id = p_expense_id) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Expense not found.';
    END IF;

    DELETE FROM expense WHERE expense_id = p_expense_id;
END$$


-- -------------------------------------------------------------
-- split_expense
-- Adds a single participant to an expense with their share.
-- Call once per participant from the application layer.
-- The creator is already inserted by the trigger, so calling
-- this for the creator will raise a duplicate error.
-- -------------------------------------------------------------
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

    IF NOT EXISTS (SELECT 1 FROM expense WHERE expense_id = p_expense_id) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Expense not found.';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM user_table WHERE email = p_email) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'User not found.';
    END IF;

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
-- Marks a user's share of an expense as paid.
-- -------------------------------------------------------------
DROP PROCEDURE IF EXISTS settle_payment$$
CREATE PROCEDURE settle_payment(
    IN p_email      VARCHAR(255),
    IN p_expense_id INT
)
BEGIN
    DECLARE current_status VARCHAR(20) DEFAULT NULL;

    SELECT payment_status INTO current_status
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
-- PROCEDURES — ANALYTICS
-- =============================================================

DROP PROCEDURE IF EXISTS get_expense_trend_by_month$$
CREATE PROCEDURE get_expense_trend_by_month(IN p_house_id INT)
BEGIN
    SELECT
        YEAR(e.creation_date)  AS yr,
        MONTH(e.creation_date) AS mo,
        SUM(e.amount)          AS total_amount
    FROM expense e
    JOIN user_expense ue ON e.expense_id = ue.expense_id
    JOIN user_house   uh ON ue.email     = uh.email
    WHERE uh.house_id = p_house_id
    GROUP BY yr, mo
    ORDER BY yr, mo;
END$$


DROP PROCEDURE IF EXISTS get_top_spenders$$
CREATE PROCEDURE get_top_spenders(IN p_house_id INT)
BEGIN
    SELECT
        ue.email,
        u.name,
        SUM(ue.user_share) AS total_spent
    FROM user_expense ue
    JOIN user_table  u  ON ue.email      = u.email
    JOIN user_house  uh ON ue.email      = uh.email
    WHERE uh.house_id = p_house_id
    GROUP BY ue.email, u.name
    ORDER BY total_spent DESC
    LIMIT 5;
END$$


DROP PROCEDURE IF EXISTS get_resource_booking_frequency$$
CREATE PROCEDURE get_resource_booking_frequency(IN p_house_id INT)
BEGIN
    SELECT
        r.resource_id,
        r.name AS resource_name,
        CASE
            WHEN rs.resource_id IS NOT NULL THEN 'space'
            WHEN ra.resource_id IS NOT NULL THEN 'appliance'
            ELSE 'base'
        END AS resource_type,
        COUNT(b.booking_id) AS booking_count
    FROM resource_table r
    LEFT JOIN resource_space    rs ON r.resource_id = rs.resource_id
    LEFT JOIN resource_appliance ra ON r.resource_id = ra.resource_id
    LEFT JOIN booking           b  ON r.resource_id = b.resource_id
    WHERE r.house_id = p_house_id
    GROUP BY r.resource_id, r.name, resource_type
    ORDER BY booking_count DESC;
END$$


DROP PROCEDURE IF EXISTS get_expense_settlement_breakdown$$
CREATE PROCEDURE get_expense_settlement_breakdown(IN p_house_id INT)
BEGIN
    SELECT
        ue.payment_status,
        COUNT(*) AS cnt
    FROM user_expense ue
    JOIN user_house uh ON ue.email = uh.email
    WHERE uh.house_id = p_house_id
    GROUP BY ue.payment_status;
END$$


DROP PROCEDURE IF EXISTS get_resource_utilization_by_type$$
CREATE PROCEDURE get_resource_utilization_by_type(IN p_house_id INT)
BEGIN
    SELECT
        CASE
            WHEN rs.resource_id IS NOT NULL THEN 'space'
            WHEN ra.resource_id IS NOT NULL THEN 'appliance'
            ELSE 'base'
        END AS resource_type,
        SUM(TIMESTAMPDIFF(MINUTE, b.start_time, b.end_time)) AS total_minutes_booked,
        COUNT(b.booking_id) AS booking_count
    FROM booking b
    JOIN resource_table  r  ON b.resource_id = r.resource_id
    LEFT JOIN resource_space    rs ON r.resource_id = rs.resource_id
    LEFT JOIN resource_appliance ra ON r.resource_id = ra.resource_id
    WHERE r.house_id = p_house_id
    GROUP BY resource_type;
END$$

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


-- -------------------------------------------------------------
-- get_monthly_expense_data
-- Returns one row per (year, month) for a given house showing
-- the total expense amount that month.
-- Joins: expense -> user_expense -> user_house (3 tables)
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



-- =============================================================
-- TRIGGERS
-- =============================================================

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
('cristiano.ronaldo@gmail.com', 'Cristiano Ronaldo', '5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8'),
('bhaichung.bhutia@gmail.com', 'Bhaichung Bhutia', '5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8'),
('carlos.luiz@gmail.com', 'Carlos Luiz', '5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8'),
('sunil.chhetri@gmail.com', 'Sunil Chhetri', '5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8'),
('lionel.messi@gmail.com', 'Lionel Messi', '5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8'),
('sergio.ramos@gmail.com', 'Sergio Ramos', '5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8');

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

-- =============================================================
-- ADDITIONAL EXPENSE DML
-- 3 months of historical expense data (January, February, March 2026)
-- NOTE: The after_expense_insert trigger automatically inserts a
-- user_expense row for created_by on every expense INSERT.
-- Those rows are excluded here to avoid duplicate key errors.
-- =============================================================

START TRANSACTION;

-- =============================================================
-- JANUARY 2026
-- =============================================================

-- creator: cristiano.ronaldo@gmail.com → trigger inserts her row automatically
INSERT INTO expense (expense_id, amount, description, due_date, receipts_attachment, is_recurring, created_by) VALUES
(7, 1200.00, 'January Rent', '2026-01-01', NULL, 1, 'cristiano.ronaldo@gmail.com');
INSERT INTO user_expense (email, expense_id, user_share, payment_status) VALUES
('bhaichung.bhutia@gmail.com', 7, 400.00, 'paid'),
('carlos.luiz@gmail.com',      7, 400.00, 'paid');
-- trigger inserted: cristiano.ronaldo@gmail.com, 7, 1200.00 → update her share
UPDATE user_expense SET user_share = 400.00, payment_status = 'paid'
WHERE email = 'cristiano.ronaldo@gmail.com' AND expense_id = 7;

-- creator: bhaichung.bhutia@gmail.com
INSERT INTO expense (expense_id, amount, description, due_date, receipts_attachment, is_recurring, created_by) VALUES
(8, 143.20, 'Electric Bill', '2026-01-10', '/receipts/electric_jan.pdf', 1, 'bhaichung.bhutia@gmail.com');
INSERT INTO user_expense (email, expense_id, user_share, payment_status) VALUES
('cristiano.ronaldo@gmail.com', 8, 71.60, 'paid'),
('carlos.luiz@gmail.com',       8, 71.60, 'paid');
UPDATE user_expense SET user_share = 71.60, payment_status = 'paid'
WHERE email = 'bhaichung.bhutia@gmail.com' AND expense_id = 8;

-- creator: sunil.chhetri@gmail.com
INSERT INTO expense (expense_id, amount, description, due_date, receipts_attachment, is_recurring, created_by) VALUES
(9, 75.00, 'Internet Bill', '2026-01-12', NULL, 1, 'sunil.chhetri@gmail.com');
INSERT INTO user_expense (email, expense_id, user_share, payment_status) VALUES
('lionel.messi@gmail.com', 9, 37.50, 'paid');
UPDATE user_expense SET user_share = 37.50, payment_status = 'paid'
WHERE email = 'sunil.chhetri@gmail.com' AND expense_id = 9;

-- creator: lionel.messi@gmail.com
INSERT INTO expense (expense_id, amount, description, due_date, receipts_attachment, is_recurring, created_by) VALUES
(10, 55.00, 'Groceries Run', '2026-01-15', '/receipts/groceries_jan.png', 0, 'lionel.messi@gmail.com');
INSERT INTO user_expense (email, expense_id, user_share, payment_status) VALUES
('sunil.chhetri@gmail.com', 10, 27.50, 'paid');
UPDATE user_expense SET user_share = 27.50, payment_status = 'paid'
WHERE email = 'lionel.messi@gmail.com' AND expense_id = 10;

-- creator: carlos.luiz@gmail.com
INSERT INTO expense (expense_id, amount, description, due_date, receipts_attachment, is_recurring, created_by) VALUES
(11, 90.00, 'Water Bill', '2026-01-18', NULL, 1, 'carlos.luiz@gmail.com');
INSERT INTO user_expense (email, expense_id, user_share, payment_status) VALUES
('sergio.ramos@gmail.com', 11, 45.00, 'paid');
UPDATE user_expense SET user_share = 45.00, payment_status = 'paid'
WHERE email = 'carlos.luiz@gmail.com' AND expense_id = 11;

-- creator: sergio.ramos@gmail.com
INSERT INTO expense (expense_id, amount, description, due_date, receipts_attachment, is_recurring, created_by) VALUES
(12, 35.00, 'Kitchen Supplies', '2026-01-20', '/receipts/kitchen_jan.png', 0, 'sergio.ramos@gmail.com');
INSERT INTO user_expense (email, expense_id, user_share, payment_status) VALUES
('carlos.luiz@gmail.com', 12, 17.50, 'paid');
UPDATE user_expense SET user_share = 17.50, payment_status = 'paid'
WHERE email = 'sergio.ramos@gmail.com' AND expense_id = 12;

-- creator: cristiano.ronaldo@gmail.com
INSERT INTO expense (expense_id, amount, description, due_date, receipts_attachment, is_recurring, created_by) VALUES
(13, 180.00, 'Heating Bill', '2026-01-22', NULL, 1, 'cristiano.ronaldo@gmail.com');
INSERT INTO user_expense (email, expense_id, user_share, payment_status) VALUES
('bhaichung.bhutia@gmail.com', 13, 60.00, 'paid'),
('carlos.luiz@gmail.com',      13, 60.00, 'paid');
UPDATE user_expense SET user_share = 60.00, payment_status = 'paid'
WHERE email = 'cristiano.ronaldo@gmail.com' AND expense_id = 13;

-- creator: bhaichung.bhutia@gmail.com
INSERT INTO expense (expense_id, amount, description, due_date, receipts_attachment, is_recurring, created_by) VALUES
(14, 48.00, 'Trash Bags and Cleaner', '2026-01-25', NULL, 0, 'bhaichung.bhutia@gmail.com');
INSERT INTO user_expense (email, expense_id, user_share, payment_status) VALUES
('cristiano.ronaldo@gmail.com', 14, 24.00, 'paid');
UPDATE user_expense SET user_share = 24.00, payment_status = 'paid'
WHERE email = 'bhaichung.bhutia@gmail.com' AND expense_id = 14;


-- =============================================================
-- FEBRUARY 2026
-- =============================================================

-- creator: cristiano.ronaldo@gmail.com
INSERT INTO expense (expense_id, amount, description, due_date, receipts_attachment, is_recurring, created_by) VALUES
(15, 1200.00, 'February Rent', '2026-02-01', NULL, 1, 'cristiano.ronaldo@gmail.com');
INSERT INTO user_expense (email, expense_id, user_share, payment_status) VALUES
('bhaichung.bhutia@gmail.com', 15, 400.00, 'paid'),
('carlos.luiz@gmail.com',      15, 400.00, 'paid');
UPDATE user_expense SET user_share = 400.00, payment_status = 'paid'
WHERE email = 'cristiano.ronaldo@gmail.com' AND expense_id = 15;

-- creator: bhaichung.bhutia@gmail.com
INSERT INTO expense (expense_id, amount, description, due_date, receipts_attachment, is_recurring, created_by) VALUES
(16, 160.80, 'Electric Bill', '2026-02-10', '/receipts/electric_feb.pdf', 1, 'bhaichung.bhutia@gmail.com');
INSERT INTO user_expense (email, expense_id, user_share, payment_status) VALUES
('cristiano.ronaldo@gmail.com', 16, 80.40, 'paid'),
('carlos.luiz@gmail.com',       16, 80.40, 'paid');
UPDATE user_expense SET user_share = 80.40, payment_status = 'paid'
WHERE email = 'bhaichung.bhutia@gmail.com' AND expense_id = 16;

-- creator: sunil.chhetri@gmail.com
INSERT INTO expense (expense_id, amount, description, due_date, receipts_attachment, is_recurring, created_by) VALUES
(17, 75.00, 'Internet Bill', '2026-02-12', NULL, 1, 'sunil.chhetri@gmail.com');
INSERT INTO user_expense (email, expense_id, user_share, payment_status) VALUES
('lionel.messi@gmail.com', 17, 37.50, 'paid');
UPDATE user_expense SET user_share = 37.50, payment_status = 'paid'
WHERE email = 'sunil.chhetri@gmail.com' AND expense_id = 17;

-- creator: cristiano.ronaldo@gmail.com
INSERT INTO expense (expense_id, amount, description, due_date, receipts_attachment, is_recurring, created_by) VALUES
(18, 210.00, 'Heating Bill', '2026-02-14', NULL, 1, 'cristiano.ronaldo@gmail.com');
INSERT INTO user_expense (email, expense_id, user_share, payment_status) VALUES
('bhaichung.bhutia@gmail.com', 18, 70.00, 'paid'),
('carlos.luiz@gmail.com',      18, 70.00, 'paid');
UPDATE user_expense SET user_share = 70.00, payment_status = 'paid'
WHERE email = 'cristiano.ronaldo@gmail.com' AND expense_id = 18;

-- creator: carlos.luiz@gmail.com
INSERT INTO expense (expense_id, amount, description, due_date, receipts_attachment, is_recurring, created_by) VALUES
(19, 88.00, 'Water Bill', '2026-02-18', NULL, 1, 'carlos.luiz@gmail.com');
INSERT INTO user_expense (email, expense_id, user_share, payment_status) VALUES
('sergio.ramos@gmail.com', 19, 44.00, 'paid');
UPDATE user_expense SET user_share = 44.00, payment_status = 'paid'
WHERE email = 'carlos.luiz@gmail.com' AND expense_id = 19;

-- creator: lionel.messi@gmail.com
INSERT INTO expense (expense_id, amount, description, due_date, receipts_attachment, is_recurring, created_by) VALUES
(20, 62.50, 'Groceries Run', '2026-02-20', '/receipts/groceries_feb.png', 0, 'lionel.messi@gmail.com');
INSERT INTO user_expense (email, expense_id, user_share, payment_status) VALUES
('sunil.chhetri@gmail.com', 20, 31.25, 'paid');
UPDATE user_expense SET user_share = 31.25, payment_status = 'paid'
WHERE email = 'lionel.messi@gmail.com' AND expense_id = 20;

-- creator: sergio.ramos@gmail.com
INSERT INTO expense (expense_id, amount, description, due_date, receipts_attachment, is_recurring, created_by) VALUES
(21, 120.00, 'Plumber Visit', '2026-02-22', '/receipts/plumber_feb.pdf', 0, 'sergio.ramos@gmail.com');
INSERT INTO user_expense (email, expense_id, user_share, payment_status) VALUES
('carlos.luiz@gmail.com', 21, 60.00, 'unpaid');
UPDATE user_expense SET user_share = 60.00, payment_status = 'partial'
WHERE email = 'sergio.ramos@gmail.com' AND expense_id = 21;

-- creator: bhaichung.bhutia@gmail.com
INSERT INTO expense (expense_id, amount, description, due_date, receipts_attachment, is_recurring, created_by) VALUES
(22, 30.00, 'Cleaning Supplies', '2026-02-25', NULL, 0, 'bhaichung.bhutia@gmail.com');
INSERT INTO user_expense (email, expense_id, user_share, payment_status) VALUES
('cristiano.ronaldo@gmail.com', 22, 15.00, 'paid');
UPDATE user_expense SET user_share = 15.00, payment_status = 'paid'
WHERE email = 'bhaichung.bhutia@gmail.com' AND expense_id = 22;


-- =============================================================
-- MARCH 2026
-- =============================================================

-- creator: cristiano.ronaldo@gmail.com
INSERT INTO expense (expense_id, amount, description, due_date, receipts_attachment, is_recurring, created_by) VALUES
(23, 1200.00, 'March Rent', '2026-03-01', NULL, 1, 'cristiano.ronaldo@gmail.com');
INSERT INTO user_expense (email, expense_id, user_share, payment_status) VALUES
('bhaichung.bhutia@gmail.com', 23, 400.00, 'paid'),
('carlos.luiz@gmail.com',      23, 400.00, 'paid');
UPDATE user_expense SET user_share = 400.00, payment_status = 'paid'
WHERE email = 'cristiano.ronaldo@gmail.com' AND expense_id = 23;

-- creator: bhaichung.bhutia@gmail.com
INSERT INTO expense (expense_id, amount, description, due_date, receipts_attachment, is_recurring, created_by) VALUES
(24, 138.60, 'Electric Bill', '2026-03-10', '/receipts/electric_mar.pdf', 1, 'bhaichung.bhutia@gmail.com');
INSERT INTO user_expense (email, expense_id, user_share, payment_status) VALUES
('cristiano.ronaldo@gmail.com', 24, 69.30, 'paid'),
('carlos.luiz@gmail.com',       24, 69.30, 'paid');
UPDATE user_expense SET user_share = 69.30, payment_status = 'paid'
WHERE email = 'bhaichung.bhutia@gmail.com' AND expense_id = 24;

-- creator: sunil.chhetri@gmail.com
INSERT INTO expense (expense_id, amount, description, due_date, receipts_attachment, is_recurring, created_by) VALUES
(25, 75.00, 'Internet Bill', '2026-03-12', NULL, 1, 'sunil.chhetri@gmail.com');
INSERT INTO user_expense (email, expense_id, user_share, payment_status) VALUES
('lionel.messi@gmail.com', 25, 37.50, 'paid');
UPDATE user_expense SET user_share = 37.50, payment_status = 'paid'
WHERE email = 'sunil.chhetri@gmail.com' AND expense_id = 25;

-- creator: cristiano.ronaldo@gmail.com
INSERT INTO expense (expense_id, amount, description, due_date, receipts_attachment, is_recurring, created_by) VALUES
(26, 165.00, 'Heating Bill', '2026-03-14', NULL, 1, 'cristiano.ronaldo@gmail.com');
INSERT INTO user_expense (email, expense_id, user_share, payment_status) VALUES
('bhaichung.bhutia@gmail.com', 26, 55.00, 'paid'),
('carlos.luiz@gmail.com',      26, 55.00, 'paid');
UPDATE user_expense SET user_share = 55.00, payment_status = 'paid'
WHERE email = 'cristiano.ronaldo@gmail.com' AND expense_id = 26;

-- creator: carlos.luiz@gmail.com
INSERT INTO expense (expense_id, amount, description, due_date, receipts_attachment, is_recurring, created_by) VALUES
(27, 82.00, 'Water Bill', '2026-03-18', NULL, 1, 'carlos.luiz@gmail.com');
INSERT INTO user_expense (email, expense_id, user_share, payment_status) VALUES
('sergio.ramos@gmail.com', 27, 41.00, 'paid');
UPDATE user_expense SET user_share = 41.00, payment_status = 'paid'
WHERE email = 'carlos.luiz@gmail.com' AND expense_id = 27;

-- creator: lionel.messi@gmail.com
INSERT INTO expense (expense_id, amount, description, due_date, receipts_attachment, is_recurring, created_by) VALUES
(28, 95.00, 'Groceries Run', '2026-03-19', '/receipts/groceries_mar.png', 0, 'lionel.messi@gmail.com');
INSERT INTO user_expense (email, expense_id, user_share, payment_status) VALUES
('sunil.chhetri@gmail.com', 28, 47.50, 'paid');
UPDATE user_expense SET user_share = 47.50, payment_status = 'paid'
WHERE email = 'lionel.messi@gmail.com' AND expense_id = 28;

-- creator: carlos.luiz@gmail.com
INSERT INTO expense (expense_id, amount, description, due_date, receipts_attachment, is_recurring, created_by) VALUES
(29, 45.00, 'Kitchen Supplies', '2026-03-21', NULL, 0, 'carlos.luiz@gmail.com');
INSERT INTO user_expense (email, expense_id, user_share, payment_status) VALUES
('cristiano.ronaldo@gmail.com', 29, 22.50, 'paid'),
('bhaichung.bhutia@gmail.com',  29, 22.50, 'paid');
UPDATE user_expense SET user_share = 22.50, payment_status = 'paid'
WHERE email = 'carlos.luiz@gmail.com' AND expense_id = 29;

-- creator: sunil.chhetri@gmail.com
INSERT INTO expense (expense_id, amount, description, due_date, receipts_attachment, is_recurring, created_by) VALUES
(30, 320.00, 'Washing Machine Repair', '2026-03-25', '/receipts/washer_repair_mar.pdf', 0, 'sunil.chhetri@gmail.com');
INSERT INTO user_expense (email, expense_id, user_share, payment_status) VALUES
('lionel.messi@gmail.com', 30, 160.00, 'unpaid');
UPDATE user_expense SET user_share = 160.00, payment_status = 'paid'
WHERE email = 'sunil.chhetri@gmail.com' AND expense_id = 30;

-- creator: sergio.ramos@gmail.com
INSERT INTO expense (expense_id, amount, description, due_date, receipts_attachment, is_recurring, created_by) VALUES
(31, 55.00, 'Cleaning Supplies', '2026-03-27', NULL, 0, 'sergio.ramos@gmail.com');
INSERT INTO user_expense (email, expense_id, user_share, payment_status) VALUES
('carlos.luiz@gmail.com', 31, 27.50, 'unpaid');
UPDATE user_expense SET user_share = 27.50, payment_status = 'paid'
WHERE email = 'sergio.ramos@gmail.com' AND expense_id = 31;

-- creator: bhaichung.bhutia@gmail.com
INSERT INTO expense (expense_id, amount, description, due_date, receipts_attachment, is_recurring, created_by) VALUES
(32, 70.00, 'Light Bulbs and Misc', '2026-03-29', NULL, 0, 'bhaichung.bhutia@gmail.com');
INSERT INTO user_expense (email, expense_id, user_share, payment_status) VALUES
('cristiano.ronaldo@gmail.com', 32, 35.00, 'paid');
UPDATE user_expense SET user_share = 35.00, payment_status = 'paid'
WHERE email = 'bhaichung.bhutia@gmail.com' AND expense_id = 32;

COMMIT;

START TRANSACTION;

-- January expenses (expense_id 7–14)
UPDATE expense SET creation_date = '2026-01-01' WHERE expense_id = 7;
UPDATE expense SET creation_date = '2026-01-10' WHERE expense_id = 8;
UPDATE expense SET creation_date = '2026-01-12' WHERE expense_id = 9;
UPDATE expense SET creation_date = '2026-01-15' WHERE expense_id = 10;
UPDATE expense SET creation_date = '2026-01-18' WHERE expense_id = 11;
UPDATE expense SET creation_date = '2026-01-20' WHERE expense_id = 12;
UPDATE expense SET creation_date = '2026-01-22' WHERE expense_id = 13;
UPDATE expense SET creation_date = '2026-01-25' WHERE expense_id = 14;

-- February expenses (expense_id 15–22)
UPDATE expense SET creation_date = '2026-02-01' WHERE expense_id = 15;
UPDATE expense SET creation_date = '2026-02-10' WHERE expense_id = 16;
UPDATE expense SET creation_date = '2026-02-12' WHERE expense_id = 17;
UPDATE expense SET creation_date = '2026-02-14' WHERE expense_id = 18;
UPDATE expense SET creation_date = '2026-02-18' WHERE expense_id = 19;
UPDATE expense SET creation_date = '2026-02-20' WHERE expense_id = 20;
UPDATE expense SET creation_date = '2026-02-22' WHERE expense_id = 21;
UPDATE expense SET creation_date = '2026-02-25' WHERE expense_id = 22;

-- March expenses (expense_id 23–32)
UPDATE expense SET creation_date = '2026-03-01' WHERE expense_id = 23;
UPDATE expense SET creation_date = '2026-03-10' WHERE expense_id = 24;
UPDATE expense SET creation_date = '2026-03-12' WHERE expense_id = 25;
UPDATE expense SET creation_date = '2026-03-14' WHERE expense_id = 26;
UPDATE expense SET creation_date = '2026-03-18' WHERE expense_id = 27;
UPDATE expense SET creation_date = '2026-03-19' WHERE expense_id = 28;
UPDATE expense SET creation_date = '2026-03-21' WHERE expense_id = 29;
UPDATE expense SET creation_date = '2026-03-25' WHERE expense_id = 30;
UPDATE expense SET creation_date = '2026-03-27' WHERE expense_id = 31;
UPDATE expense SET creation_date = '2026-03-29' WHERE expense_id = 32;

COMMIT;
