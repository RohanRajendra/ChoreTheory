

-- Create and use the database
DROP DATABASE IF EXISTS project_db;
CREATE DATABASE project_db;
USE project_db;


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

