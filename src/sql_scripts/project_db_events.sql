-- =============================================================
-- DATABASE EVENTS
-- =============================================================

USE project_db;

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