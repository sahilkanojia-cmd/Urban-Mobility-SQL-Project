/* ============================================================================
   MOBILITY IQ — DATABASE SETUP & DATA LOAD SCRIPT
   Purpose : Creates the mobility_analytics database, defines all core tables
             (cities, users, drivers, vehicles, rides, payments,
             ratings_feedback, promotions), loads each table from a local
             CSV via LOAD DATA LOCAL INFILE, and runs basic sanity checks.
   ========================================================================== */

-- Allow the MySQL client/server to read files from the local filesystem.
-- Required for LOAD DATA LOCAL INFILE to work; must be enabled both
-- server-side (this variable) and client-side (connection option).
SET GLOBAL local_infile = 1;

-- Create and switch into the project database.
CREATE DATABASE mobility_analytics;
USE mobility_analytics;

-- ----------------------------------------------------------------------------
-- TABLE: cities
-- Lookup table of service cities. Referenced by users, drivers, and rides.
-- Created first (with no dependencies) since users/drivers/rides all FK to it.
-- ----------------------------------------------------------------------------
CREATE TABLE cities (
  city_id VARCHAR(10) PRIMARY KEY,   -- unique city code, e.g. 'DEL', 'BLR'
  city_name VARCHAR(50),
  state VARCHAR(50),
  tier VARCHAR(10)                   -- city classification, e.g. Tier 1/2/3
);

-- ----------------------------------------------------------------------------
-- TABLE: users
-- One row per rider. Self-referencing FK (referred_by_user_id) supports
-- tracking the referral program (who invited whom).
-- ----------------------------------------------------------------------------
CREATE TABLE users (
  user_id VARCHAR(15) PRIMARY KEY,
  name VARCHAR(100),
  email VARCHAR(150),
  phone VARCHAR(15),
  signup_date DATE,
  city_id VARCHAR(10),
  device_type VARCHAR(20),                 -- e.g. Android / iOS
  preferred_payment_mode VARCHAR(20),       -- e.g. wallet / UPI / card / cash
  wallet_balance DECIMAL(10,2),
  referral_code VARCHAR(20),                -- this user's own referral code
  referred_by_user_id VARCHAR(15),          -- FK to users; NULL = organic signup
  rating DECIMAL(3,2),                      -- rider's average rating from drivers
  is_active TINYINT,                        -- 1 = active account, 0 = inactive
  total_rides INT,
  last_ride_date DATE,
  FOREIGN KEY (city_id) REFERENCES cities(city_id),
  FOREIGN KEY (referred_by_user_id) REFERENCES users(user_id)
);

-- Re-confirm local_infile is on right before the first LOAD DATA (defensive,
-- in case the session/connection reset it).
SET GLOBAL local_infile = 1;

-- Load rider records from CSV.
-- Columns prefixed with '@' are staged into user variables first so that
-- empty-string values from the CSV can be converted to true SQL NULLs
-- via NULLIF before landing in the table (avoids storing '' where a
-- DATE/DECIMAL/FK column expects NULL).
LOAD DATA LOCAL INFILE 'C:\\Users\\sagar\\Downloads\\users.csv'
INTO TABLE users
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS                              -- skip CSV header row
(user_id, name, @email, @phone, signup_date, city_id, device_type,
 preferred_payment_mode, wallet_balance, referral_code, @referred_by_user_id,
 @rating, is_active, total_rides, @last_ride_date)
SET
  email = NULLIF(@email, ''),
  phone = NULLIF(@phone, ''),
  referred_by_user_id = NULLIF(@referred_by_user_id, ''),
  rating = NULLIF(@rating, ''),
  last_ride_date = NULLIF(@last_ride_date, '');

-- Sanity check: confirm the server-side setting actually took effect.
SHOW GLOBAL VARIABLES LIKE 'local_infile';

-- Surface any row-level warnings from the load (e.g. truncated values,
-- bad dates) that MySQL doesn't raise as hard errors by default.
SHOW WARNINGS;

-- Quick visual check that users loaded as expected.
select * from users;


-- Load city lookup data into the cities table created above.
-- No @staging vars needed here since none of the columns require
-- NULL-handling.
LOAD DATA LOCAL INFILE 'C:\\Users\\sagar\\Downloads\\cities.csv'
INTO TABLE cities
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

select * from cities;


-- ----------------------------------------------------------------------------
-- TABLE: drivers
-- One row per driver. linked_user_id optionally connects a driver back to
-- a rider account (drivers who also use the app as riders). vehicle_id is
-- added as an FK later, after the vehicles table exists (avoids a circular
-- dependency at creation time, since vehicles also references drivers).
-- ----------------------------------------------------------------------------
CREATE TABLE drivers (
  driver_id VARCHAR(15) PRIMARY KEY,
  name VARCHAR(100),
  phone VARCHAR(15),
  city_id VARCHAR(10),
  join_date DATE,
  license_number VARCHAR(20),
  vehicle_id VARCHAR(15),                  -- FK added later via ALTER TABLE
  linked_user_id VARCHAR(15),              -- optional link to a users row
  rating DECIMAL(3,2),                     -- driver's average rating from riders
  total_rides_completed INT,
  is_active TINYINT,
  background_check_status VARCHAR(20),     -- e.g. verified / pending / failed
  weekly_hours_online DECIMAL(4,1),
  acceptance_rate DECIMAL(4,1),            -- % of ride requests accepted
  cancellation_rate DECIMAL(4,1),          -- % of accepted rides later cancelled
  FOREIGN KEY (city_id) REFERENCES cities(city_id),
  FOREIGN KEY (linked_user_id) REFERENCES users(user_id)
);

-- Load driver records; NULL-handle the optional linked_user_id and
-- background_check_status fields the same way as above.
LOAD DATA LOCAL INFILE 'C:\\Users\\sagar\\Downloads\\drivers.csv'
INTO TABLE drivers
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(driver_id, name, phone, city_id, join_date, license_number, vehicle_id,
 @linked_user_id, rating, total_rides_completed, is_active, @bg_status,
 weekly_hours_online, acceptance_rate, cancellation_rate)
SET
  linked_user_id = NULLIF(@linked_user_id, ''),
  background_check_status = NULLIF(@bg_status, '');
  
select * from drivers;

-- Check: drivers who are also riders (i.e. linked_user_id points to a
-- real users row) — inner join surfaces only the overlap.
select 
	*
from users as u
join drivers as d
on u.user_id = d.linked_user_id;

-- select * from users;

-- ----------------------------------------------------------------------------
-- TABLE: vehicles
-- One row per vehicle, owned/operated by a driver. driver_id here is a
-- simple FK (not yet enforced as 1:1); the drivers.vehicle_id FK added
-- below closes the loop from the other direction.
-- ----------------------------------------------------------------------------
CREATE TABLE vehicles (
  vehicle_id VARCHAR(15) PRIMARY KEY,
  driver_id VARCHAR(15),
  vehicle_type VARCHAR(20),                -- e.g. sedan / hatchback / bike / SUV
  make VARCHAR(50),
  model VARCHAR(50),
  year INT,
  registration_number VARCHAR(20),
  fuel_type VARCHAR(20),
  insurance_expiry_date DATE,
  last_service_date DATE,
  FOREIGN KEY (driver_id) REFERENCES drivers(driver_id)
);


-- Load vehicle records; only last_service_date needs NULL-handling
-- (some vehicles may not yet have a service record).
LOAD DATA LOCAL INFILE 'C:\\Users\\sagar\\Downloads\\vehicles.csv'
INTO TABLE vehicles
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(vehicle_id, driver_id, vehicle_type, make, model, year,
 registration_number, fuel_type, insurance_expiry_date, @last_service_date)
SET last_service_date = NULLIF(@last_service_date, '');

-- Now that vehicles exists, retroactively enforce that drivers.vehicle_id
-- points to a real vehicle (completes the drivers <-> vehicles relationship).
ALTER TABLE drivers ADD CONSTRAINT fk_driver_vehicle
FOREIGN KEY (vehicle_id) REFERENCES vehicles(vehicle_id);

select * from vehicles;


-- ----------------------------------------------------------------------------
-- TABLE: rides
-- Core fact table: one row per ride, linking a rider, driver, vehicle and
-- city, with trip timing, distance, fare breakdown and outcome status.
-- ----------------------------------------------------------------------------
CREATE TABLE rides (
  ride_id VARCHAR(15) PRIMARY KEY,
  user_id VARCHAR(15),
  driver_id VARCHAR(15),
  vehicle_id VARCHAR(15),
  city_id VARCHAR(10),
  pickup_time DATETIME,
  drop_time DATETIME,                      -- NULL for cancelled/incomplete rides
  distance_km DECIMAL(6,2),
  duration_min DECIMAL(6,1),
  base_fare DECIMAL(10,2),
  surge_multiplier DECIMAL(3,2),
  total_fare DECIMAL(10,2),
  payment_mode VARCHAR(20),
  ride_status VARCHAR(15),                 -- e.g. completed / cancelled / ongoing
  cancellation_reason VARCHAR(100),        -- NULL unless ride_status = cancelled
  FOREIGN KEY (user_id) REFERENCES users(user_id),
  FOREIGN KEY (driver_id) REFERENCES drivers(driver_id),
  FOREIGN KEY (vehicle_id) REFERENCES vehicles(vehicle_id),
  FOREIGN KEY (city_id) REFERENCES cities(city_id)
);

-- Load ride records. Most trip-detail columns (drop_time, distance,
-- duration, fares, cancellation_reason) can legitimately be blank for
-- cancelled/incomplete rides, so they're all routed through NULLIF.
LOAD DATA LOCAL INFILE 'C:\\Users\\sagar\\Downloads\\rides.csv'
INTO TABLE rides
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(ride_id, user_id, driver_id, vehicle_id, city_id, pickup_time,
 @drop_time, @distance_km, @duration_min, @base_fare, @surge_multiplier,
 total_fare, payment_mode, ride_status, @cancellation_reason)
SET
  drop_time = NULLIF(@drop_time, ''),
  distance_km = NULLIF(@distance_km, ''),
  duration_min = NULLIF(@duration_min, ''),
  base_fare = NULLIF(@base_fare, ''),
  surge_multiplier = NULLIF(@surge_multiplier, ''),
  cancellation_reason = NULLIF(@cancellation_reason, '');
  
  
select count(*) from rides;

-- NOTE: this join has no ON clause, so MySQL treats it as a CROSS JOIN
-- filtered by the WHERE condition — it works, but 'join ... on ...' would
-- be the clearer/standard way to write an inner join.
select * from rides
join users
where rides.user_id = users.user_id;


-- ----------------------------------------------------------------------------
-- TABLE: payments
-- One row per payment transaction tied to a ride (a ride could in theory
-- have retry transactions, hence a separate table rather than columns
-- bolted onto rides).
-- ----------------------------------------------------------------------------
CREATE TABLE payments (
  payment_id VARCHAR(15) PRIMARY KEY,
  ride_id VARCHAR(15),
  amount DECIMAL(10,2),
  payment_mode VARCHAR(20),
  payment_status VARCHAR(15),              -- e.g. success / failed / pending
  transaction_id VARCHAR(20),              -- gateway/reference id, may be blank
  timestamp DATETIME,
  wallet_used TINYINT,                     -- 1 = wallet balance used, 0 = not
  cashback_applied DECIMAL(8,2),
  FOREIGN KEY (ride_id) REFERENCES rides(ride_id)
);

-- Load payment records; NULL-handle transaction_id and cashback_applied,
-- which are legitimately empty for failed/cashback-free transactions.
LOAD DATA LOCAL INFILE 'C:\\Users\\sagar\\Downloads\\payments.csv'
INTO TABLE payments
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(payment_id, ride_id, amount, payment_mode, payment_status,
 @transaction_id, timestamp, wallet_used, @cashback_applied)
SET
  transaction_id = NULLIF(@transaction_id, ''),
  cashback_applied = NULLIF(@cashback_applied, '');
  
  
-- ----------------------------------------------------------------------------
-- TABLE: ratings_feedback
-- One row per ride's post-trip feedback: rider's rating of the driver,
-- driver's rating of the rider, free-text comments and tags.
-- ----------------------------------------------------------------------------
CREATE TABLE ratings_feedback (
  feedback_id VARCHAR(15) PRIMARY KEY,
  ride_id VARCHAR(15),
  user_rating DECIMAL(3,1),                -- rating the rider gave the driver
  driver_rating DECIMAL(3,1),              -- rating the driver gave the rider
  user_comment VARCHAR(255),
  driver_comment VARCHAR(255),
  feedback_tags VARCHAR(50),               -- e.g. 'clean_car', 'late_pickup'
  FOREIGN KEY (ride_id) REFERENCES rides(ride_id)
);

-- Load feedback records; most fields here are optional per ride.
LOAD DATA LOCAL INFILE 'C:\\Users\\sagar\\Downloads\\ratings_feedback.csv'
INTO TABLE ratings_feedback
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(feedback_id, ride_id, user_rating, @driver_rating, @user_comment,
 @driver_comment, @feedback_tags)
SET
  driver_rating = NULLIF(@driver_rating, ''),
  user_comment = NULLIF(@user_comment, ''),
  driver_comment = NULLIF(@driver_comment, ''),
  feedback_tags = NULLIF(@feedback_tags, '');
  
  
-- ----------------------------------------------------------------------------
-- TABLE: promotions
-- One row per coupon/discount applied to a ride.
-- ----------------------------------------------------------------------------
CREATE TABLE promotions (
  coupon_id VARCHAR(15) PRIMARY KEY,
  ride_id VARCHAR(15),
  coupon_code VARCHAR(20),
  campaign_name VARCHAR(50),
  discount_type VARCHAR(15),               -- e.g. flat / percentage
  discount_value DECIMAL(6,2),             -- the flat amount or % configured
  discount_amt DECIMAL(8,2),               -- actual discount amount applied
  valid_from DATE,
  valid_to DATE,
  FOREIGN KEY (ride_id) REFERENCES rides(ride_id)
);

-- Load promotion/coupon records. No NULLIF handling here — assumes the
-- CSV has no blank values in these columns.
LOAD DATA LOCAL INFILE 'C:\\Users\\sagar\\Downloads\\promotions.csv'
INTO TABLE promotions
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;


-- ----------------------------------------------------------------------------
-- FINAL CHECK: row counts across every table in one glance, to confirm all
-- CSVs loaded fully (compare against expected source row counts).
-- ----------------------------------------------------------------------------
-- checking the count of data-- 
SELECT
    (SELECT COUNT(*) FROM cities) AS cities_count,
    (SELECT COUNT(*) FROM drivers) AS drivers_count,
    (SELECT COUNT(*) FROM payments) AS payments_count,
    (SELECT COUNT(*) FROM promotions) AS promotions_count,
    (SELECT COUNT(*) FROM ratings_feedback) AS ratings_feedback_count,
    (SELECT COUNT(*) FROM rides) AS rides_count,
    (SELECT COUNT(*) FROM users) AS users_count,
    (SELECT COUNT(*) FROM vehicles) AS vehicles_count;

-- ----------------------------------------------------------------------------------- 
-- DATA ANALYSIS
-- --------------------------------------------------------------------------------------
-- 1. How many rides were completed? What is the ride status distribution?
SELECT ride_status,
  COUNT(*) AS ride_count,
  SUM(CASE WHEN ride_status = 'Completed'
      THEN 1 ELSE 0 END) AS completed
FROM rides
GROUP BY ride_status
ORDER BY ride_count DESC;

-- 2. Which cities have the highest ride volume? / What is the revenue distribution by city?
SELECT c.city_name,
  COUNT(r.ride_id) AS rides,
  SUM(r.total_fare) AS revenue
FROM rides r
JOIN cities c ON c.city_id = r.city_id
GROUP BY c.city_name
ORDER BY revenue DESC;

-- 3. What are the popular vehicle types by ride count? / What are the average fares by vehicle type?
SELECT v.vehicle_type,
 COUNT(r.ride_id) AS rides,
 ROUND(AVG(r.total_fare), 2) AS avg_fare
FROM rides r
JOIN vehicles v ON v.vehicle_id=r.vehicle_id
GROUP BY v.vehicle_type
ORDER BY rides DESC;

-- 4. Who are the top drivers by revenue?  Who are the top customers by spending?
SELECT d.name, SUM(r.total_fare) revenue
FROM drivers d JOIN rides r USING(driver_id)
GROUP BY d.driver_id, d.name
ORDER BY revenue DESC LIMIT 10;

-- 5. Who are the top customers by spending?
SELECT user_id, SUM(total_fare) spend
FROM rides GROUP BY user_id
ORDER BY spend DESC LIMIT 10;

-- 6. Cancellation reasons · best-performing campaign

SELECT cancellation_reason, COUNT(*) total
FROM rides WHERE ride_status='Cancelled'
GROUP BY cancellation_reason;

-- 7. · payment modes and status-- 
SELECT payment_status, payment_mode, COUNT(*)
FROM payments GROUP BY payment_status, payment_mode;

-- 8· best-performing campaign
SELECT campaign_name, SUM(discount_amt) discount
FROM promotions GROUP BY campaign_name;

-- CTEs · Window Functions · RANK() · DENSE_RANK() · Subqueries · CASE WHEN · JOINs · Aggregations

-- 9. Who are the top-revenue drivers in each city based on completed rides?
WITH driver_revenue AS (
 SELECT city_id, driver_id,
   SUM(total_fare) AS revenue
 FROM rides
 WHERE ride_status='Completed'
 GROUP BY city_id, driver_id
)
SELECT *, RANK() OVER(
 PARTITION BY city_id ORDER BY revenue DESC
) AS city_rank
FROM driver_revenue;

-- 10. Identify top-performing drivers within each city using rankings.
WITH x AS (
 SELECT c.city_name, d.name,
   SUM(r.total_fare) revenue
 FROM rides r JOIN cities c USING(city_id)
 JOIN drivers d USING(driver_id)
 GROUP BY c.city_name, d.name
)
SELECT *,
 RANK() OVER(PARTITION BY city_name ORDER BY revenue DESC) rnk,
 DENSE_RANK() OVER(PARTITION BY city_name ORDER BY revenue DESC) dense_rnk
FROM x;

-- 11. Drivers above a ride threshold · performance vs city average · customer spend ranks · filtered aggregates
WITH driver_totals AS (
 SELECT driver_id, city_id, COUNT(*) rides,
   SUM(total_fare) revenue
 FROM rides GROUP BY driver_id, city_id
), city_avg AS (
 SELECT city_id, AVG(revenue) avg_revenue
 FROM driver_totals GROUP BY city_id
)
SELECT d.* FROM driver_totals d
JOIN city_avg c USING(city_id)
WHERE d.rides > 50 AND d.revenue > c.avg_revenue;