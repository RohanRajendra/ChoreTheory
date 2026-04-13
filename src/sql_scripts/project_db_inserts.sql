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
('bhaichung.bhutia@gmail.com', 1, TRUE),
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
(1, 1, '2026-04-14 09:00:00'),
(2, 1, '2026-04-14 09:30:00'),
(3, 2, '2026-04-14 12:00:00'),
(4, 3, '2026-04-15 08:00:00'),
(5, 4, '2026-04-15 14:30:00'),
(6, 6, '2026-04-17 07:30:00');

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
('cristiano.ronaldo@gmail.com', 1, 600.00, 'paid'),
('bhaichung.bhutia@gmail.com', 1, 600.00, 'paid'),
('cristiano.ronaldo@gmail.com', 2, 75.25, 'unpaid'),
('bhaichung.bhutia@gmail.com', 2, 75.25, 'unpaid'),
('sunil.chhetri@gmail.com', 3, 37.50, 'partial'),
('lionel.messi@gmail.com', 3, 37.50, 'partial'),
('lionel.messi@gmail.com', 4, 40.00, 'paid'),
('sergio.ramos@gmail.com', 5, 200.00, 'unpaid'),
('carlos.luiz@gmail.com', 6, 30.00, 'unpaid'),
('sergio.ramos@gmail.com', 6, 30.00, 'unpaid');

COMMIT;
