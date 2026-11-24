-- Project members: Ahmed Walid Mohamed; David Tarek Rizk Khalil; Andrew Esmat Zaki Abdelmalek; Anton Hany Rady; Anas Ibrahim Gamil; Youssef Mostafa Abdelrahim Abdallah; Johnny Samir Attia
-- Faculty of Science, Ain Shams University - COMP 207 Database Systems, December 2026
-- =====================================================================
-- File 07: Tests. Lines marked EXPECT ERROR must fail; the rest must succeed.
-- Test rows use ids >= 9000 and are deleted at the end (no transactions used).
-- Run with:  mysql --force -u root < 07_tests.sql
-- =====================================================================
USE travelx;

-- T1 EXPECT ERROR (trigger, BR-13/15): same room, overlapping dates. Room 1 is already booked 2026-11-26..2026-12-05 (booking item for room 105 hotel 1).
INSERT INTO booking (booking_id, customer_id, booking_date) VALUES (9001, 1, '2026-11-20 10:00:00');
INSERT INTO booking_item (booking_item_id, booking_id, traveler_id, service_type, price) VALUES (9001, 9001, 1, 'Hotel', 1000);
INSERT INTO hotel_item (booking_item_id, room_id, check_in_date, check_out_date, guest_count)
SELECT 9001, hi.room_id, '2026-11-28', '2026-12-01', 1
FROM hotel_item hi JOIN booking_item bi ON bi.booking_item_id = hi.booking_item_id
WHERE bi.status = 'Confirmed' AND hi.check_in_date = '2026-11-26' AND hi.check_out_date = '2026-12-05' LIMIT 1;

-- T2 must SUCCEED (BR-15): back-to-back stay, new check-in = old check-out day.
INSERT INTO hotel_item (booking_item_id, room_id, check_in_date, check_out_date, guest_count)
SELECT 9001, hi.room_id, '2026-12-05', '2026-12-07', 1
FROM hotel_item hi JOIN booking_item bi ON bi.booking_item_id = hi.booking_item_id
WHERE bi.status = 'Confirmed' AND hi.check_in_date = '2026-11-26' AND hi.check_out_date = '2026-12-05' LIMIT 1;

-- T3 EXPECT ERROR (CHECK chk_hi_dates): check-out not after check-in.
INSERT INTO booking_item (booking_item_id, booking_id, traveler_id, service_type, price) VALUES (9002, 9001, 1, 'Hotel', 500);
INSERT INTO hotel_item (booking_item_id, room_id, check_in_date, check_out_date, guest_count) VALUES (9002, 1, '2027-03-05', '2027-03-05', 1);

-- T4 EXPECT ERROR (UNIQUE uq_fi_seat, BR-11): second confirmed passenger on a taken seat.
INSERT INTO booking_item (booking_item_id, booking_id, traveler_id, service_type, price) VALUES (9003, 9001, 1, 'Flight', 100);
INSERT INTO flight_item (booking_item_id, scheduled_flight_id, seat_number, ticket_number)
SELECT 9003, scheduled_flight_id, seat_number, 'TEST-9003' FROM flight_item WHERE seat_number IS NOT NULL LIMIT 1;

-- T5 EXPECT ERROR (CHECK chk_sf_times, BR-10): arrival before departure.
INSERT INTO scheduled_flight (flight_id, departure_datetime, arrival_datetime, capacity, price)
VALUES (1, '2027-05-01 10:00:00', '2027-05-01 09:00:00', 100, 100);

-- T6 EXPECT ERROR (CHECK chk_flight_airports, BR-10): departure airport = arrival airport.
INSERT INTO flight (flight_number, airline_id, departure_airport_id, arrival_airport_id) VALUES ('XX9', 1, 1, 1);

-- T7 EXPECT ERROR (UNIQUE uq_vr_pair, BR-05): second rule for the same (nationality, destination).
INSERT INTO visa_requirement (nationality_country_id, destination_country_id, is_required, visa_type) VALUES (1, 4, TRUE, 'Tourist');

-- T8 EXPECT ERROR (CHECK chk_va_expiry_status): Approved application without expiry date.
INSERT INTO visa_application (passport_id, destination_country_id, application_date, status) VALUES (1, 4, '2026-11-01', 'Approved');

-- T9 EXPECT ERROR (CHECK chk_payment_amount, BR-21): zero payment.
INSERT INTO payment (booking_id, amount, payment_date, method, status) VALUES (9001, 0, '2026-11-21 10:00:00', 'Card', 'Successful');

-- T10 EXPECT ERROR (UNIQUE uq_refund_item, D-36): two refunds for one item.
INSERT INTO refund (booking_item_id, amount, refund_date, reason)
SELECT booking_item_id, 1, '2026-11-22 10:00:00', 'duplicate test' FROM refund LIMIT 1;

-- Phase 7 scenario - partial cancellation (BR-23/24): booking with flight + hotel + car, hotel cancelled, partly refunded.
INSERT INTO booking (booking_id, customer_id, booking_date) VALUES (9010, 2, '2026-11-20 09:00:00');
INSERT INTO booking_item (booking_item_id, booking_id, traveler_id, service_type, price) VALUES
  (9010, 9010, 2, 'Flight', 3000), (9011, 9010, 2, 'Hotel', 4000), (9012, 9010, 2, 'Car', 1000);
INSERT INTO flight_item (booking_item_id, scheduled_flight_id, seat_number, ticket_number) VALUES (9010, 1, '90Z', 'TEST-9010');
INSERT INTO hotel_item (booking_item_id, room_id, check_in_date, check_out_date, guest_count) VALUES (9011, 1, '2027-04-01', '2027-04-05', 1);
INSERT INTO car_item (booking_item_id, car_id, pickup_date, return_date) VALUES (9012, 1, '2027-04-01', '2027-04-05');
INSERT INTO payment (payment_id, booking_id, amount, payment_date, method, status) VALUES (9010, 9010, 8000, '2026-11-20 09:30:00', 'Card', 'Successful');
-- before cancellation
SELECT 'before cancel' AS step, booking_id, active_total, paid, refunded, remaining FROM accountant_view WHERE booking_id = 9010;
UPDATE booking_item SET status = 'Cancelled' WHERE booking_item_id = 9011;
INSERT INTO refund (booking_item_id, amount, refund_date, reason) VALUES (9011, 2000, '2026-11-22 10:00:00', 'Customer cancelled hotel stay (50 percent)');
SELECT 'after partial cancel' AS step, booking_id, active_total, paid, refunded, remaining FROM accountant_view WHERE booking_id = 9010;
-- remaining = 4000 - (8000 - 2000) = -2000 : the customer was charged for the hotel and got back only half.
-- the cancelled room is free again for the same dates (T11 must SUCCEED):
INSERT INTO booking_item (booking_item_id, booking_id, traveler_id, service_type, price) VALUES (9013, 9010, 2, 'Hotel', 4000);
INSERT INTO hotel_item (booking_item_id, room_id, check_in_date, check_out_date, guest_count) VALUES (9013, 1, '2027-04-01', '2027-04-05', 1);
-- Q26 must now list booking 9010; Q25 must NOT count a cancelled hotel as a service type
SELECT 'Q26 sees partial cancel' AS step, COUNT(*) AS found FROM booking b
WHERE b.booking_id = 9010 AND b.booking_id IN (SELECT booking_id FROM booking_item WHERE status = 'Cancelled')
                          AND b.booking_id IN (SELECT booking_id FROM booking_item WHERE status = 'Confirmed');

-- ---- clean up the test rows ----
DELETE FROM refund WHERE booking_item_id >= 9000;
DELETE FROM payment WHERE booking_id >= 9000;
DELETE FROM booking_item WHERE booking_id >= 9000;      -- subclass rows go with ON DELETE CASCADE
DELETE FROM booking WHERE booking_id >= 9000;
SELECT 'cleanup' AS step, (SELECT COUNT(*) FROM booking) AS bookings, (SELECT COUNT(*) FROM booking_item) AS items;
