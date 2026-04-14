-- =============================================================
-- DATABASE PROGRAMMING OBJECTS 
-- procedures and functions and triggers. 
-- =============================================================

USE project_db;

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
    INSERT INTO user_house (email, house_id, is_admin)
    VALUES (p_creator_email, p_house_id, TRUE);
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
    SELECT h.house_id, h.address, h.name, uh.is_admin
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
    IN p_house_id       INT
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

    INSERT INTO user_house (email, house_id, is_admin)
    VALUES (p_new_user_email, p_house_id, FALSE);
END$$


-- -------------------------------------------------------------
-- get_house_members
-- Returns all members of a house with their admin status.
-- -------------------------------------------------------------
DROP PROCEDURE IF EXISTS get_house_members$$
CREATE PROCEDURE get_house_members(IN p_house_id INT)
BEGIN
    SELECT u.email, u.name, uh.is_admin
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