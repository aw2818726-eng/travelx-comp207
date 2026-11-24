-- Project members: Ahmed Walid Mohamed; David Tarek Rizk Khalil; Andrew Esmat Zaki Abdelmalek; Anton Hany Rady; Anas Ibrahim Gamil; Youssef Mostafa Abdelrahim Abdallah; Johnny Samir Attia
-- Faculty of Science, Ain Shams University - COMP 207 Database Systems, December 2026
-- =====================================================================
-- File 06: CHECK QUERIES - rules that no constraint can enforce (known weaknesses).
-- Every query must return ZERO rows on valid data. Run after any bulk load.
-- =====================================================================
USE travelx;

-- C1 (BR-04) international flight items whose traveler has no passport valid 6 months after arrival.
SELECT bi.booking_item_id, bi.traveler_id, sf.arrival_datetime
FROM booking_item bi
JOIN flight_item fi ON fi.booking_item_id = bi.booking_item_id
JOIN scheduled_flight sf ON sf.scheduled_flight_id = fi.scheduled_flight_id
JOIN flight f ON f.flight_id = sf.flight_id
JOIN airport a1 ON a1.airport_id = f.departure_airport_id
JOIN airport a2 ON a2.airport_id = f.arrival_airport_id
JOIN city c1 ON c1.city_id = a1.city_id
JOIN city c2 ON c2.city_id = a2.city_id
WHERE bi.status = 'Confirmed' AND c1.country_id <> c2.country_id
  AND bi.traveler_id NOT IN (SELECT p.customer_id FROM passport p
                             WHERE p.expiry_date >= DATE_ADD(DATE(sf.arrival_datetime), INTERVAL 6 MONTH));

-- C2 (BR-12) scheduled flights with more confirmed passengers than capacity.
SELECT sf.scheduled_flight_id, sf.capacity, COUNT(*) AS confirmed
FROM scheduled_flight sf
JOIN flight_item fi ON fi.scheduled_flight_id = sf.scheduled_flight_id
JOIN booking_item bi ON bi.booking_item_id = fi.booking_item_id
WHERE bi.status = 'Confirmed'
GROUP BY sf.scheduled_flight_id, sf.capacity
HAVING COUNT(*) > sf.capacity;

-- C3 (BR-14) hotel stays with more guests than the room type capacity.
SELECT hi.booking_item_id, hi.guest_count, rt.capacity
FROM hotel_item hi
JOIN room r ON r.room_id = hi.room_id
JOIN room_type rt ON rt.room_type_id = r.room_type_id
WHERE hi.guest_count > rt.capacity;

-- C4 (BR-18) bookings with no item at all.
SELECT booking_id FROM booking
WHERE booking_id NOT IN (SELECT booking_id FROM booking_item);

-- C5 (BR-18 / disjoint + total) booking items that do not have exactly one matching subclass row.
SELECT bi.booking_item_id, bi.service_type
FROM booking_item bi
WHERE (bi.service_type = 'Flight' AND bi.booking_item_id NOT IN (SELECT booking_item_id FROM flight_item))
   OR (bi.service_type = 'Hotel'  AND bi.booking_item_id NOT IN (SELECT booking_item_id FROM hotel_item))
   OR (bi.service_type = 'Car'    AND bi.booking_item_id NOT IN (SELECT booking_item_id FROM car_item))
   OR (bi.service_type <> 'Flight' AND bi.booking_item_id IN (SELECT booking_item_id FROM flight_item))
   OR (bi.service_type <> 'Hotel'  AND bi.booking_item_id IN (SELECT booking_item_id FROM hotel_item))
   OR (bi.service_type <> 'Car'    AND bi.booking_item_id IN (SELECT booking_item_id FROM car_item));

-- C6 (BR-24) a refund bigger than the price of its item, or on an item that is not cancelled.
SELECT r.refund_id, r.amount, bi.price, bi.status
FROM refund r JOIN booking_item bi ON bi.booking_item_id = r.booking_item_id
WHERE r.amount > bi.price OR bi.status <> 'Cancelled';

-- C7 (BR-24) bookings whose refunds exceed the successful payments.
SELECT b.booking_id
FROM booking b
WHERE (SELECT SUM(r.amount) FROM refund r WHERE r.booking_item_id IN
         (SELECT bi.booking_item_id FROM booking_item bi WHERE bi.booking_id = b.booking_id))
    > IFNULL((SELECT SUM(p.amount) FROM payment p WHERE p.booking_id = b.booking_id AND p.status = 'Successful'), 0);

-- C8 (BR-08) Submitted / Under Review / Approved applications that still miss documents.
SELECT va.application_id, va.status
FROM visa_application va
JOIN passport p ON p.passport_id = va.passport_id
WHERE va.status IN ('Submitted', 'Under Review', 'Approved')
  AND (SELECT COUNT(*) FROM submitted_document sd WHERE sd.application_id = va.application_id)
    < (SELECT COUNT(*) FROM required_document rd WHERE rd.requirement_id IN
         (SELECT vr.requirement_id FROM visa_requirement vr
           WHERE vr.nationality_country_id = p.issuing_country_id
             AND vr.destination_country_id = va.destination_country_id));

-- C9 (D-39) room number repeated inside the same hotel (unique only per room type).
SELECT rt.hotel_id, r.room_number, COUNT(*) AS times
FROM room r JOIN room_type rt ON rt.room_type_id = r.room_type_id
GROUP BY rt.hotel_id, r.room_number
HAVING COUNT(*) > 1;

-- C10 (BR-17) car rented in a city and booked for a hotel/flight in another city is not modelled; instead check
-- that a cancelled flight item has no seat (D-23).
SELECT fi.booking_item_id FROM flight_item fi
JOIN booking_item bi ON bi.booking_item_id = fi.booking_item_id
WHERE bi.status = 'Cancelled' AND fi.seat_number IS NOT NULL;

-- C11 (D-42) visa applications for a (passport country, destination) pair that has no visa rule, or a rule saying no visa is needed.
SELECT va.application_id, p.issuing_country_id, va.destination_country_id
FROM visa_application va
JOIN passport p ON p.passport_id = va.passport_id
WHERE (p.issuing_country_id, va.destination_country_id) NOT IN
      (SELECT nationality_country_id, destination_country_id FROM visa_requirement WHERE is_required = TRUE);
