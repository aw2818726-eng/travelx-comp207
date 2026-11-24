-- Project members: Ahmed Walid Mohamed; David Tarek Rizk Khalil; Andrew Esmat Zaki Abdelmalek; Anton Hany Rady; Anas Ibrahim Gamil; Youssef Mostafa Abdelrahim Abdallah; Johnny Samir Attia
-- Faculty of Science, Ain Shams University - COMP 207 Database Systems, December 2026
-- =====================================================================
-- TravelX - Integrated Travel and Reservation Management System
-- COMP 207 Database Systems - Project
-- File 01: Database and table creation (23 tables, 3NF)
-- Requires MySQL 8.0.16 or later (CHECK constraints are enforced).
--
-- Naming: entity names of the design documents are written in snake_case
--   Country -> country, VisaRequirement -> visa_requirement, ...
-- Specialisation (method 8A): booking_item is the superclass,
--   flight_item / hotel_item / car_item are the subclasses; each subclass
--   uses the superclass key as PRIMARY KEY and FOREIGN KEY.
-- =====================================================================

DROP DATABASE IF EXISTS travelx;
CREATE DATABASE travelx CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE travelx;

-- ---------------------------------------------------------------------
-- 1. Country (reference table)
-- ---------------------------------------------------------------------
CREATE TABLE country (
    country_id    INT AUTO_INCREMENT PRIMARY KEY,
    country_name  VARCHAR(100) NOT NULL,
    iso_code      CHAR(2) NULL,
    CONSTRAINT uq_country_name UNIQUE (country_name),
    CONSTRAINT uq_country_iso  UNIQUE (iso_code),
    CONSTRAINT chk_country_iso CHECK (iso_code IS NULL OR CHAR_LENGTH(iso_code) = 2)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 2. Customer (a person who books and/or travels).
--    email is UNIQUE but may be NULL (children / companions) - decision D-40.
--    Nationality is NOT stored here: it comes from the passport.
-- ---------------------------------------------------------------------
CREATE TABLE customer (
    customer_id    INT AUTO_INCREMENT PRIMARY KEY,
    first_name     VARCHAR(50)  NOT NULL,
    last_name      VARCHAR(50)  NOT NULL,
    email          VARCHAR(100) NULL,
    phone          VARCHAR(20)  NULL,
    date_of_birth  DATE         NULL,
    CONSTRAINT uq_customer_email UNIQUE (email)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 3. Passport (a physical passport book, independent of customer)
-- ---------------------------------------------------------------------
CREATE TABLE passport (
    passport_id         INT AUTO_INCREMENT PRIMARY KEY,
    customer_id         INT         NOT NULL,
    issuing_country_id  INT         NOT NULL,
    passport_number     VARCHAR(20) NOT NULL,
    issue_date          DATE        NOT NULL,
    expiry_date         DATE        NOT NULL,
    CONSTRAINT fk_passport_customer FOREIGN KEY (customer_id)
        REFERENCES customer (customer_id),
    CONSTRAINT fk_passport_country FOREIGN KEY (issuing_country_id)
        REFERENCES country (country_id),
    CONSTRAINT uq_passport_number UNIQUE (issuing_country_id, passport_number),   -- BR-02
    CONSTRAINT chk_passport_dates CHECK (expiry_date > issue_date)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 4. Visa requirement (rule: nationality -> destination).
--    Associative entity of the recursive M:N relationship on country.
-- ---------------------------------------------------------------------
CREATE TABLE visa_requirement (
    requirement_id          INT AUTO_INCREMENT PRIMARY KEY,
    nationality_country_id  INT NOT NULL,
    destination_country_id  INT NOT NULL,
    is_required             BOOLEAN NOT NULL,
    visa_type               ENUM('Tourist','Business','Transit','e-Visa') NULL,
    CONSTRAINT fk_vr_nationality FOREIGN KEY (nationality_country_id)
        REFERENCES country (country_id),
    CONSTRAINT fk_vr_destination FOREIGN KEY (destination_country_id)
        REFERENCES country (country_id),
    CONSTRAINT uq_vr_pair UNIQUE (nationality_country_id, destination_country_id),  -- BR-05
    CONSTRAINT chk_vr_different CHECK (nationality_country_id <> destination_country_id),
    CONSTRAINT chk_vr_type CHECK ((is_required = TRUE  AND visa_type IS NOT NULL)
                               OR (is_required = FALSE AND visa_type IS NULL))
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 5. Required document (documents needed for one visa rule)
-- ---------------------------------------------------------------------
CREATE TABLE required_document (
    required_document_id  INT AUTO_INCREMENT PRIMARY KEY,
    requirement_id        INT          NOT NULL,
    document_name         VARCHAR(100) NOT NULL,
    CONSTRAINT fk_rd_requirement FOREIGN KEY (requirement_id)
        REFERENCES visa_requirement (requirement_id),
    CONSTRAINT uq_rd_name UNIQUE (requirement_id, document_name)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 6. Visa application (one attempt, one passport, one destination).
--    There is NO foreign key to visa_requirement (decision D-42): the rule
--    is found through (passport.issuing_country_id, destination_country_id).
-- ---------------------------------------------------------------------
CREATE TABLE visa_application (
    application_id          INT AUTO_INCREMENT PRIMARY KEY,
    passport_id             INT  NOT NULL,
    destination_country_id  INT  NOT NULL,
    application_date        DATE NOT NULL,
    status                  ENUM('Draft','Submitted','Under Review','Missing Documents',
                                 'Approved','Rejected') NOT NULL DEFAULT 'Draft',
    visa_expiry_date        DATE NULL,
    CONSTRAINT fk_va_passport FOREIGN KEY (passport_id)
        REFERENCES passport (passport_id),
    CONSTRAINT fk_va_destination FOREIGN KEY (destination_country_id)
        REFERENCES country (country_id),
    CONSTRAINT chk_va_expiry_status CHECK ((status = 'Approved' AND visa_expiry_date IS NOT NULL)
                                        OR (status <> 'Approved' AND visa_expiry_date IS NULL)),
    CONSTRAINT chk_va_expiry_after CHECK (visa_expiry_date IS NULL OR visa_expiry_date > application_date)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 7. Submitted document (weak / associative: application x required document)
-- ---------------------------------------------------------------------
CREATE TABLE submitted_document (
    application_id        INT  NOT NULL,
    required_document_id  INT  NOT NULL,
    submission_date       DATE NOT NULL,
    PRIMARY KEY (application_id, required_document_id),
    CONSTRAINT fk_sd_application FOREIGN KEY (application_id)
        REFERENCES visa_application (application_id) ON DELETE CASCADE,
    CONSTRAINT fk_sd_document FOREIGN KEY (required_document_id)
        REFERENCES required_document (required_document_id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 8. City (country is derived from the city, never stored on airport/hotel/car)
-- ---------------------------------------------------------------------
CREATE TABLE city (
    city_id     INT AUTO_INCREMENT PRIMARY KEY,
    country_id  INT          NOT NULL,
    city_name   VARCHAR(100) NOT NULL,
    CONSTRAINT fk_city_country FOREIGN KEY (country_id)
        REFERENCES country (country_id),
    CONSTRAINT uq_city UNIQUE (country_id, city_name)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 9-12. Flights
-- ---------------------------------------------------------------------
CREATE TABLE airline (
    airline_id    INT AUTO_INCREMENT PRIMARY KEY,
    airline_name  VARCHAR(100) NOT NULL,
    CONSTRAINT uq_airline_name UNIQUE (airline_name)
) ENGINE=InnoDB;

CREATE TABLE airport (
    airport_id    INT AUTO_INCREMENT PRIMARY KEY,
    iata_code     CHAR(3)      NOT NULL,
    airport_name  VARCHAR(100) NOT NULL,
    city_id       INT          NOT NULL,
    CONSTRAINT fk_airport_city FOREIGN KEY (city_id) REFERENCES city (city_id),
    CONSTRAINT uq_airport_iata UNIQUE (iata_code),
    CONSTRAINT chk_airport_iata CHECK (CHAR_LENGTH(iata_code) = 3)
) ENGINE=InnoDB;

-- Flight = the fixed route (flight number between two airports), no date.
CREATE TABLE flight (
    flight_id             INT AUTO_INCREMENT PRIMARY KEY,
    flight_number         VARCHAR(10) NOT NULL,
    airline_id            INT NOT NULL,
    departure_airport_id  INT NOT NULL,
    arrival_airport_id    INT NOT NULL,
    CONSTRAINT fk_flight_airline FOREIGN KEY (airline_id) REFERENCES airline (airline_id),
    CONSTRAINT fk_flight_dep FOREIGN KEY (departure_airport_id) REFERENCES airport (airport_id),
    CONSTRAINT fk_flight_arr FOREIGN KEY (arrival_airport_id)   REFERENCES airport (airport_id),
    CONSTRAINT uq_flight_number UNIQUE (flight_number),
    CONSTRAINT chk_flight_airports CHECK (departure_airport_id <> arrival_airport_id)   -- BR-10
) ENGINE=InnoDB;

-- Scheduled flight = the route on a date and time, with capacity, price, status.
CREATE TABLE scheduled_flight (
    scheduled_flight_id  INT AUTO_INCREMENT PRIMARY KEY,
    flight_id            INT NOT NULL,
    departure_datetime   DATETIME NOT NULL,
    arrival_datetime     DATETIME NOT NULL,
    capacity             INT NOT NULL,
    price                DECIMAL(10,2) NOT NULL,
    status               ENUM('Scheduled','Cancelled','Completed') NOT NULL DEFAULT 'Scheduled',
    CONSTRAINT fk_sf_flight FOREIGN KEY (flight_id) REFERENCES flight (flight_id),
    CONSTRAINT uq_sf_flight_dep UNIQUE (flight_id, departure_datetime),
    CONSTRAINT chk_sf_times CHECK (arrival_datetime > departure_datetime),             -- BR-10
    CONSTRAINT chk_sf_capacity CHECK (capacity > 0),
    CONSTRAINT chk_sf_price CHECK (price > 0)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 13-16. Hotels and cars
-- ---------------------------------------------------------------------
CREATE TABLE hotel (
    hotel_id    INT AUTO_INCREMENT PRIMARY KEY,
    hotel_name  VARCHAR(100) NOT NULL,
    city_id     INT          NOT NULL,
    address     VARCHAR(200) NULL,
    CONSTRAINT fk_hotel_city FOREIGN KEY (city_id) REFERENCES city (city_id),
    CONSTRAINT uq_hotel UNIQUE (hotel_name, city_id)
) ENGINE=InnoDB;

CREATE TABLE room_type (
    room_type_id     INT AUTO_INCREMENT PRIMARY KEY,
    hotel_id         INT           NOT NULL,
    type_name        VARCHAR(50)   NOT NULL,
    price_per_night  DECIMAL(10,2) NOT NULL,
    capacity         INT           NOT NULL,
    CONSTRAINT fk_rt_hotel FOREIGN KEY (hotel_id) REFERENCES hotel (hotel_id),
    CONSTRAINT uq_rt UNIQUE (hotel_id, type_name),
    CONSTRAINT chk_rt_price CHECK (price_per_night > 0),
    CONSTRAINT chk_rt_capacity CHECK (capacity > 0)
) ENGINE=InnoDB;

-- Known weakness (D-39): room_number is unique inside the room type only;
-- uniqueness inside the hotel is guaranteed by the data and by a check query.
CREATE TABLE room (
    room_id       INT AUTO_INCREMENT PRIMARY KEY,
    room_type_id  INT         NOT NULL,
    room_number   VARCHAR(10) NOT NULL,
    CONSTRAINT fk_room_type FOREIGN KEY (room_type_id) REFERENCES room_type (room_type_id),
    CONSTRAINT uq_room UNIQUE (room_type_id, room_number)
) ENGINE=InnoDB;

CREATE TABLE car (
    car_id        INT AUTO_INCREMENT PRIMARY KEY,
    plate_number  VARCHAR(15)   NOT NULL,
    model_name    VARCHAR(50)   NOT NULL,
    category      ENUM('Economy','Compact','SUV','Luxury') NOT NULL,
    daily_price   DECIMAL(10,2) NOT NULL,
    city_id       INT           NOT NULL,
    CONSTRAINT fk_car_city FOREIGN KEY (city_id) REFERENCES city (city_id),
    CONSTRAINT uq_car_plate UNIQUE (plate_number),
    CONSTRAINT chk_car_price CHECK (daily_price > 0)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 17-21. Booking, booking items (superclass) and the three subclasses
--   booking status is NOT stored: it is derived from items and payments (D-32).
-- ---------------------------------------------------------------------
CREATE TABLE booking (
    booking_id    INT AUTO_INCREMENT PRIMARY KEY,
    customer_id   INT      NOT NULL,                      -- the booker
    booking_date  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_booking_customer FOREIGN KEY (customer_id) REFERENCES customer (customer_id)
) ENGINE=InnoDB;

CREATE TABLE booking_item (
    booking_item_id  INT AUTO_INCREMENT PRIMARY KEY,
    booking_id       INT NOT NULL,
    traveler_id      INT NOT NULL,                        -- the person who travels (D-33)
    service_type     ENUM('Flight','Hotel','Car') NOT NULL,   -- defining attribute
    price            DECIMAL(10,2) NOT NULL,              -- frozen at booking time (BR-19)
    status           ENUM('Confirmed','Cancelled') NOT NULL DEFAULT 'Confirmed',
    CONSTRAINT fk_bi_booking  FOREIGN KEY (booking_id)  REFERENCES booking (booking_id),
    CONSTRAINT fk_bi_traveler FOREIGN KEY (traveler_id) REFERENCES customer (customer_id),
    CONSTRAINT chk_bi_price CHECK (price > 0)
) ENGINE=InnoDB;

CREATE TABLE flight_item (
    booking_item_id      INT PRIMARY KEY,
    scheduled_flight_id  INT         NOT NULL,
    seat_number          VARCHAR(5)  NULL,                -- emptied on cancellation (D-23)
    ticket_number        VARCHAR(20) NULL,
    CONSTRAINT fk_fi_item FOREIGN KEY (booking_item_id)
        REFERENCES booking_item (booking_item_id) ON DELETE CASCADE,
    CONSTRAINT fk_fi_sf FOREIGN KEY (scheduled_flight_id)
        REFERENCES scheduled_flight (scheduled_flight_id),
    CONSTRAINT uq_fi_seat   UNIQUE (scheduled_flight_id, seat_number),   -- BR-11 (NULLs allowed)
    CONSTRAINT uq_fi_ticket UNIQUE (ticket_number)
) ENGINE=InnoDB;

CREATE TABLE hotel_item (
    booking_item_id  INT PRIMARY KEY,
    room_id          INT  NOT NULL,
    check_in_date    DATE NOT NULL,
    check_out_date   DATE NOT NULL,
    guest_count      INT  NOT NULL,
    CONSTRAINT fk_hi_item FOREIGN KEY (booking_item_id)
        REFERENCES booking_item (booking_item_id) ON DELETE CASCADE,
    CONSTRAINT fk_hi_room FOREIGN KEY (room_id) REFERENCES room (room_id),
    CONSTRAINT chk_hi_dates CHECK (check_out_date > check_in_date),
    CONSTRAINT chk_hi_guests CHECK (guest_count > 0)
) ENGINE=InnoDB;

CREATE TABLE car_item (
    booking_item_id  INT PRIMARY KEY,
    car_id           INT  NOT NULL,
    pickup_date      DATE NOT NULL,
    return_date      DATE NOT NULL,
    CONSTRAINT fk_ci_item FOREIGN KEY (booking_item_id)
        REFERENCES booking_item (booking_item_id) ON DELETE CASCADE,
    CONSTRAINT fk_ci_car FOREIGN KEY (car_id) REFERENCES car (car_id),
    CONSTRAINT chk_ci_dates CHECK (return_date > pickup_date)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 22-23. Payment (on the booking) and refund (on one item)
-- ---------------------------------------------------------------------
CREATE TABLE payment (
    payment_id    INT AUTO_INCREMENT PRIMARY KEY,
    booking_id    INT           NOT NULL,
    amount        DECIMAL(10,2) NOT NULL,
    payment_date  DATETIME      NOT NULL,
    method        ENUM('Card','Cash','Bank Transfer','Wallet') NOT NULL,
    status        ENUM('Pending','Successful','Failed') NOT NULL,
    CONSTRAINT fk_payment_booking FOREIGN KEY (booking_id) REFERENCES booking (booking_id),
    CONSTRAINT chk_payment_amount CHECK (amount > 0)                                  -- BR-21
) ENGINE=InnoDB;

CREATE TABLE refund (
    refund_id        INT AUTO_INCREMENT PRIMARY KEY,
    booking_item_id  INT           NOT NULL,
    amount           DECIMAL(10,2) NOT NULL,
    refund_date      DATETIME      NOT NULL,
    reason           VARCHAR(200)  NOT NULL,
    CONSTRAINT fk_refund_item FOREIGN KEY (booking_item_id) REFERENCES booking_item (booking_item_id),
    CONSTRAINT uq_refund_item UNIQUE (booking_item_id),                               -- D-36
    CONSTRAINT chk_refund_amount CHECK (amount > 0)
) ENGINE=InnoDB;
