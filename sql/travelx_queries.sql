-- Project members: Ahmed Walid Mohamed; David Tarek Rizk Khalil; Andrew Esmat Zaki Abdelmalek; Anton Hany Rady; Anas Ibrahim Gamil; Youssef Mostafa Abdelrahim Abdallah; Johnny Samir Attia
-- Faculty of Science, Ain Shams University - COMP 207 Database Systems, December 2026
-- =====================================================================
-- TravelX - Queries Q01..Q32 (each query = one user requirement)
-- Every query is commented with: the business question, who asks, the type.
-- Queries are separated by ';'. Only lecture 6/7 SQL is used (JOIN, GROUP BY,
-- HAVING, nested IN / NOT IN / ALL, UNION, aggregates). No NOT EXISTS, CTE,
-- window function, stored procedure.
-- =====================================================================
USE travelx;

-- ---------------- Customer and passport ----------------
-- Q01 (Admin, single table + WHERE + ORDER BY): passports that expire before 2027-03-01, soonest first.
SELECT passport_id, customer_id, passport_number, expiry_date
FROM passport
WHERE expiry_date < '2027-03-01'
ORDER BY expiry_date;

-- Q02 (Admin, GROUP BY + COUNT DISTINCT): number of DIFFERENT customers per passport-issuing country.
-- DISTINCT is needed: a customer with two passports of the same country is counted once.
SELECT c.country_name, COUNT(DISTINCT p.customer_id) AS customers
FROM passport p
JOIN country c ON c.country_id = p.issuing_country_id
GROUP BY c.country_id, c.country_name
ORDER BY customers DESC;

-- Q03 (Admin, GROUP BY + HAVING): customers who hold more than one passport.
SELECT cu.customer_id, cu.first_name, cu.last_name, COUNT(*) AS passports
FROM customer cu
JOIN passport p ON p.customer_id = cu.customer_id
GROUP BY cu.customer_id, cu.first_name, cu.last_name
HAVING COUNT(*) > 1;

-- Q04 (Admin, JOIN): each customer with the country that issued the passport (one row per passport).
SELECT cu.customer_id, cu.first_name, cu.last_name, cu.email, c.country_name AS passport_country, p.passport_number
FROM customer cu
JOIN passport p ON p.customer_id = cu.customer_id
JOIN country c  ON c.country_id = p.issuing_country_id
ORDER BY cu.customer_id;

-- ---------------- Visa ----------------
-- Q05 (Customer, JOIN + WHERE): destinations that an Egyptian passport holder needs a visa for, with visa type.
SELECT d.country_name AS destination, vr.visa_type
FROM visa_requirement vr
JOIN country n ON n.country_id = vr.nationality_country_id
JOIN country d ON d.country_id = vr.destination_country_id
WHERE n.country_name = 'Egypt' AND vr.is_required = TRUE
ORDER BY d.country_name;

-- Q06 (Customer, JOIN of 3 tables): documents required for an Egyptian passport holder going to Turkey.
SELECT rd.document_name
FROM required_document rd
JOIN visa_requirement vr ON vr.requirement_id = rd.requirement_id
JOIN country n ON n.country_id = vr.nationality_country_id
JOIN country d ON d.country_id = vr.destination_country_id
WHERE n.country_name = 'Egypt' AND d.country_name = 'Turkey';

-- Q07 (Visa Officer, GROUP BY + COUNT; view V2): number of visa applications in each status.
SELECT status, COUNT(*) AS applications
FROM visa_application
GROUP BY status
ORDER BY applications DESC;

-- Q08 (Visa Officer, JOIN + WHERE; view V2): applications with status 'Missing Documents', customer and destination.
SELECT va.application_id, cu.first_name, cu.last_name, d.country_name AS destination, va.application_date
FROM visa_application va
JOIN passport p ON p.passport_id = va.passport_id
JOIN customer cu ON cu.customer_id = p.customer_id
JOIN country d ON d.country_id = va.destination_country_id
WHERE va.status = 'Missing Documents'
ORDER BY va.application_id;

-- Q09 (Visa Officer, nested + GROUP BY; view V2): for every 'Missing Documents' application, how many documents are still missing.
-- missing = documents required by the rule (nationality = passport country, destination) - documents submitted.
-- The link to the rule goes through (passport country, destination) because there is no FK (D-42).
SELECT va.application_id,
       (SELECT COUNT(*) FROM required_document rd
         WHERE rd.requirement_id IN (SELECT vr.requirement_id FROM visa_requirement vr
                                      WHERE vr.nationality_country_id = p.issuing_country_id
                                        AND vr.destination_country_id = va.destination_country_id)) AS required_documents,
       COUNT(sd.required_document_id) AS submitted_documents,
       (SELECT COUNT(*) FROM required_document rd
         WHERE rd.requirement_id IN (SELECT vr.requirement_id FROM visa_requirement vr
                                      WHERE vr.nationality_country_id = p.issuing_country_id
                                        AND vr.destination_country_id = va.destination_country_id))
         - COUNT(sd.required_document_id) AS missing_documents
FROM visa_application va
JOIN passport p ON p.passport_id = va.passport_id
LEFT JOIN submitted_document sd ON sd.application_id = va.application_id
WHERE va.status = 'Missing Documents'
GROUP BY va.application_id, p.issuing_country_id, va.destination_country_id
ORDER BY missing_documents DESC, va.application_id;

-- Q10 (Admin, nested NOT IN): customers who applied for a Saudi Arabia visa but have NO confirmed flight booked for them that lands in Saudi Arabia.
-- Decisions: "has a booking" = the TRAVELER of a Confirmed flight item (cancelled items do not count); destination country = country of the arrival airport.
-- IS NOT NULL inside the subquery protects NOT IN from the NULL trap (a single NULL would empty the result).
SELECT DISTINCT cu.customer_id, cu.first_name, cu.last_name
FROM visa_application va
JOIN passport p ON p.passport_id = va.passport_id
JOIN customer cu ON cu.customer_id = p.customer_id
JOIN country d ON d.country_id = va.destination_country_id
WHERE d.country_name = 'Saudi Arabia'
  AND cu.customer_id NOT IN (SELECT bi.traveler_id
                             FROM booking_item bi
                             JOIN flight_item fi ON fi.booking_item_id = bi.booking_item_id
                             JOIN scheduled_flight sf ON sf.scheduled_flight_id = fi.scheduled_flight_id
                             JOIN flight f ON f.flight_id = sf.flight_id
                             JOIN airport a ON a.airport_id = f.arrival_airport_id
                             JOIN city ct ON ct.city_id = a.city_id
                             JOIN country c2 ON c2.country_id = ct.country_id
                             WHERE c2.country_name = 'Saudi Arabia'
                               AND bi.status = 'Confirmed'
                               AND bi.traveler_id IS NOT NULL)
ORDER BY cu.customer_id;

-- Q11 (Visa Officer, multi JOIN + date comparison): travelers whose APPROVED visa expires before the arrival date of their confirmed flight to that country.
SELECT DISTINCT cu.customer_id, cu.first_name, cu.last_name, d.country_name AS destination,
       va.visa_expiry_date, DATE(sf.arrival_datetime) AS arrival_date
FROM visa_application va
JOIN passport p ON p.passport_id = va.passport_id
JOIN customer cu ON cu.customer_id = p.customer_id
JOIN country d ON d.country_id = va.destination_country_id
JOIN booking_item bi ON bi.traveler_id = cu.customer_id AND bi.status = 'Confirmed'
JOIN flight_item fi ON fi.booking_item_id = bi.booking_item_id
JOIN scheduled_flight sf ON sf.scheduled_flight_id = fi.scheduled_flight_id
JOIN flight f ON f.flight_id = sf.flight_id
JOIN airport a ON a.airport_id = f.arrival_airport_id
JOIN city ct ON ct.city_id = a.city_id
WHERE va.status = 'Approved'
  AND ct.country_id = va.destination_country_id
  AND va.visa_expiry_date < DATE(sf.arrival_datetime)
ORDER BY cu.customer_id;

-- Q31 (Admin, RIGHT JOIN + GROUP BY): all countries with the number of visa applications for each as destination (0 if none).
-- COUNT(va.application_id), not COUNT(*), so countries without applications show 0.
SELECT c.country_name, COUNT(va.application_id) AS applications
FROM visa_application va
RIGHT JOIN country c ON c.country_id = va.destination_country_id
GROUP BY c.country_id, c.country_name
ORDER BY applications DESC, c.country_name;

-- ---------------- Flights ----------------
-- Q12 (Customer, JOIN + WHERE + ORDER BY): scheduled flights leaving Cairo (CAI) on 2026-12-05, ordered by departure time.
SELECT f.flight_number, al.airline_name, arr.iata_code AS to_airport, sf.departure_datetime, sf.arrival_datetime, sf.price
FROM scheduled_flight sf
JOIN flight f ON f.flight_id = sf.flight_id
JOIN airline al ON al.airline_id = f.airline_id
JOIN airport dep ON dep.airport_id = f.departure_airport_id
JOIN airport arr ON arr.airport_id = f.arrival_airport_id
WHERE dep.iata_code = 'CAI' AND DATE(sf.departure_datetime) = '2026-12-05' AND sf.status = 'Scheduled'
ORDER BY sf.departure_datetime;

-- Q13 (Admin, JOIN + GROUP BY): number of scheduled flights per airline.
SELECT al.airline_name, COUNT(sf.scheduled_flight_id) AS scheduled_flights
FROM airline al
JOIN flight f ON f.airline_id = al.airline_id
JOIN scheduled_flight sf ON sf.flight_id = f.flight_id
GROUP BY al.airline_id, al.airline_name
ORDER BY scheduled_flights DESC;

-- Q14 (Admin, AVG + GROUP BY): average scheduled-flight price per destination country.
SELECT c.country_name, ROUND(AVG(sf.price), 2) AS avg_price
FROM scheduled_flight sf
JOIN flight f ON f.flight_id = sf.flight_id
JOIN airport a ON a.airport_id = f.arrival_airport_id
JOIN city ct ON ct.city_id = a.city_id
JOIN country c ON c.country_id = ct.country_id
GROUP BY c.country_id, c.country_name
ORDER BY avg_price DESC;

-- Q15 (Admin, nested MAX): the most expensive scheduled flight(s).
SELECT sf.scheduled_flight_id, f.flight_number, sf.departure_datetime, sf.price
FROM scheduled_flight sf
JOIN flight f ON f.flight_id = sf.flight_id
WHERE sf.price = (SELECT MAX(price) FROM scheduled_flight);

-- Q16 (Admin, GROUP BY + HAVING): scheduled flights that are completely booked (confirmed passengers = capacity).
SELECT sf.scheduled_flight_id, f.flight_number, sf.departure_datetime, sf.capacity, COUNT(*) AS confirmed_passengers
FROM scheduled_flight sf
JOIN flight f ON f.flight_id = sf.flight_id
JOIN flight_item fi ON fi.scheduled_flight_id = sf.scheduled_flight_id
JOIN booking_item bi ON bi.booking_item_id = fi.booking_item_id
WHERE bi.status = 'Confirmed'
GROUP BY sf.scheduled_flight_id, f.flight_number, sf.departure_datetime, sf.capacity
HAVING COUNT(*) = sf.capacity;

-- Q17 (Admin, LEFT JOIN + IS NULL): airports that have no departing flight.
-- IS NULL is tested on the PRIMARY KEY of the right table, so it is NULL only when nothing matched.
SELECT a.airport_id, a.iata_code, a.airport_name
FROM airport a
LEFT JOIN flight f ON f.departure_airport_id = a.airport_id
WHERE f.flight_id IS NULL
ORDER BY a.iata_code;

-- Q32 (Customer, nested > ALL): scheduled flights priced higher than EVERY EgyptAir scheduled flight.
-- EgyptAir has data and no NULL prices (price is NOT NULL), so > ALL is safe: an empty subquery would let every row pass.
SELECT sf.scheduled_flight_id, f.flight_number, sf.departure_datetime, sf.price
FROM scheduled_flight sf
JOIN flight f ON f.flight_id = sf.flight_id
WHERE sf.price > ALL (SELECT sf2.price
                      FROM scheduled_flight sf2
                      JOIN flight f2 ON f2.flight_id = sf2.flight_id
                      JOIN airline a2 ON a2.airline_id = f2.airline_id
                      WHERE a2.airline_name = 'EgyptAir')
ORDER BY sf.price DESC;

-- ---------------- Hotels ----------------
-- Q18 (Customer, JOIN + WHERE): hotels in Dubai with their room types and nightly prices.
SELECT h.hotel_name, rt.type_name, rt.capacity, rt.price_per_night
FROM hotel h
JOIN city ct ON ct.city_id = h.city_id
JOIN room_type rt ON rt.hotel_id = h.hotel_id
WHERE ct.city_name = 'Dubai'
ORDER BY h.hotel_name, rt.price_per_night;

-- Q19 (Customer, nested NOT IN): rooms of hotel 1 free between 2026-11-30 and 2026-12-06 (no overlapping confirmed stay).
-- Overlap rule: new_in < old_out AND new_out > old_in. Cancelled stays do not block.
-- With the 8A design the hotel_item table only has hotel rows, so room_id can never be NULL; IS NOT NULL is kept as protection.
SELECT r.room_id, rt.type_name, r.room_number, rt.price_per_night
FROM room r
JOIN room_type rt ON rt.room_type_id = r.room_type_id
WHERE rt.hotel_id = 1
  AND r.room_id NOT IN (SELECT hi.room_id
                        FROM hotel_item hi
                        JOIN booking_item bi ON bi.booking_item_id = hi.booking_item_id
                        WHERE bi.status = 'Confirmed'
                          AND hi.room_id IS NOT NULL
                          AND '2026-11-30' < hi.check_out_date
                          AND '2026-12-06' > hi.check_in_date)
ORDER BY rt.type_name, r.room_number;

-- Q20 (Admin, GROUP BY + HAVING + nested): hotels whose average nightly price is above the average of all room types.
SELECT h.hotel_name, ROUND(AVG(rt.price_per_night), 2) AS avg_night_price
FROM hotel h
JOIN room_type rt ON rt.hotel_id = h.hotel_id
GROUP BY h.hotel_id, h.hotel_name
HAVING AVG(rt.price_per_night) > (SELECT AVG(price_per_night) FROM room_type)
ORDER BY avg_night_price DESC;

-- ---------------- Cars ----------------
-- Q21 (Customer, single table + WHERE + ORDER BY): cars in city 1 (Cairo) cheaper than 1000 per day, cheapest first.
-- Decision D (Q21): filter by city_id so it stays a single-table query.
SELECT car_id, model_name, category, daily_price
FROM car
WHERE city_id = 1 AND daily_price < 1000
ORDER BY daily_price;

-- Q22 (Admin, GROUP BY + COUNT + AVG): number of cars and average daily price in each category.
SELECT category, COUNT(*) AS cars, ROUND(AVG(daily_price), 2) AS avg_daily_price
FROM car
GROUP BY category
ORDER BY avg_daily_price;

-- ---------------- Booking ----------------
-- Q23 (Admin, JOIN + SUM + GROUP BY; view V1): per customer, number of bookings and total spent on non-cancelled items.
-- Only bookings with at least one active item appear (inner join): a fully cancelled booking has nothing to count.
SELECT cu.customer_id, cu.first_name, cu.last_name,
       COUNT(DISTINCT b.booking_id) AS bookings, SUM(bi.price) AS total_active_items
FROM customer cu
JOIN booking b ON b.customer_id = cu.customer_id
JOIN booking_item bi ON bi.booking_id = b.booking_id
WHERE bi.status = 'Confirmed'
GROUP BY cu.customer_id, cu.first_name, cu.last_name
ORDER BY total_active_items DESC;

-- Q24 (Customer, UNION; view V1): all items of booking 4 (flight, hotel, car) with status.
SELECT bi.booking_item_id, 'Flight' AS service, CONCAT(f.flight_number, ' ', sf.departure_datetime) AS details, bi.status, bi.price
FROM booking_item bi
JOIN flight_item fi ON fi.booking_item_id = bi.booking_item_id
JOIN scheduled_flight sf ON sf.scheduled_flight_id = fi.scheduled_flight_id
JOIN flight f ON f.flight_id = sf.flight_id
WHERE bi.booking_id = 4
UNION
SELECT bi.booking_item_id, 'Hotel', CONCAT(h.hotel_name, ' ', hi.check_in_date, ' to ', hi.check_out_date), bi.status, bi.price
FROM booking_item bi
JOIN hotel_item hi ON hi.booking_item_id = bi.booking_item_id
JOIN room r ON r.room_id = hi.room_id
JOIN room_type rt ON rt.room_type_id = r.room_type_id
JOIN hotel h ON h.hotel_id = rt.hotel_id
WHERE bi.booking_id = 4
UNION
SELECT bi.booking_item_id, 'Car', CONCAT(c.model_name, ' ', ci.pickup_date, ' to ', ci.return_date), bi.status, bi.price
FROM booking_item bi
JOIN car_item ci ON ci.booking_item_id = bi.booking_item_id
JOIN car c ON c.car_id = ci.car_id
WHERE bi.booking_id = 4;

-- Q25 (Admin, GROUP BY + HAVING + COUNT DISTINCT): bookings whose ACTIVE items cover exactly all three service types.
-- Decision: only Confirmed items count (a cancelled hotel does not make the booking a "full package").
SELECT bi.booking_id, COUNT(DISTINCT bi.service_type) AS service_types, COUNT(*) AS active_items
FROM booking_item bi
WHERE bi.status = 'Confirmed'
GROUP BY bi.booking_id
HAVING COUNT(DISTINCT bi.service_type) = 3
ORDER BY bi.booking_id;

-- Q26 (Customer, nested; view V1): bookings with at least one cancelled item AND at least one active item (partial cancellation).
SELECT b.booking_id, b.customer_id, b.booking_date
FROM booking b
WHERE b.booking_id IN (SELECT booking_id FROM booking_item WHERE status = 'Cancelled')
  AND b.booking_id IN (SELECT booking_id FROM booking_item WHERE status = 'Confirmed')
ORDER BY b.booking_id;

-- Q27 (Admin, self-JOIN on customer): travelers booked by someone else, and who booked for them.
SELECT DISTINCT trav.customer_id AS traveler_id, CONCAT(trav.first_name, ' ', trav.last_name) AS traveler,
       booker.customer_id AS booker_id, CONCAT(booker.first_name, ' ', booker.last_name) AS booked_by
FROM booking b
JOIN booking_item bi ON bi.booking_id = b.booking_id
JOIN customer trav ON trav.customer_id = bi.traveler_id
JOIN customer booker ON booker.customer_id = b.customer_id
WHERE trav.customer_id <> booker.customer_id
ORDER BY booker.customer_id, trav.customer_id;

-- ---------------- Payments and refunds ----------------
-- Q28 (Accountant, JOIN + SUM + nested; view V3): per booking: total of active items, successful payments, refunds, remaining.
-- Each SUM is in its OWN subquery: joining items and payments in one query would multiply the totals (D-28).
-- remaining = active total - (successful paid - refunded). It can be negative (item cancelled, less refunded than paid).
-- IFNULL(..., 0) turns "no payment / no refund row" into 0 (SUM of nothing is NULL).
SELECT b.booking_id, CONCAT(cu.first_name, ' ', cu.last_name) AS booker,
       IFNULL((SELECT SUM(bi.price) FROM booking_item bi WHERE bi.booking_id = b.booking_id AND bi.status = 'Confirmed'), 0) AS active_total,
       IFNULL((SELECT SUM(p.amount) FROM payment p WHERE p.booking_id = b.booking_id AND p.status = 'Successful'), 0) AS paid,
       IFNULL((SELECT SUM(r.amount) FROM refund r WHERE r.booking_item_id IN
               (SELECT bi2.booking_item_id FROM booking_item bi2 WHERE bi2.booking_id = b.booking_id)), 0) AS refunded,
       IFNULL((SELECT SUM(bi.price) FROM booking_item bi WHERE bi.booking_id = b.booking_id AND bi.status = 'Confirmed'), 0)
       - (IFNULL((SELECT SUM(p.amount) FROM payment p WHERE p.booking_id = b.booking_id AND p.status = 'Successful'), 0)
          - IFNULL((SELECT SUM(r.amount) FROM refund r WHERE r.booking_item_id IN
               (SELECT bi2.booking_item_id FROM booking_item bi2 WHERE bi2.booking_id = b.booking_id)), 0)) AS remaining
FROM booking b
JOIN customer cu ON cu.customer_id = b.customer_id
ORDER BY b.booking_id;

-- Q29 (Accountant, GROUP BY + SUM; view V3): total SUCCESSFUL payments per payment method.
SELECT method, COUNT(*) AS payments, SUM(amount) AS total_paid
FROM payment
WHERE status = 'Successful'
GROUP BY method
ORDER BY total_paid DESC;

-- Q30 (Accountant, JOIN; view V3): every refund, the cancelled item it belongs to, and the reason.
SELECT r.refund_id, bi.booking_id, bi.booking_item_id, bi.service_type, bi.price AS item_price, r.amount AS refunded, r.refund_date, r.reason
FROM refund r
JOIN booking_item bi ON bi.booking_item_id = r.booking_item_id
ORDER BY r.refund_date;
