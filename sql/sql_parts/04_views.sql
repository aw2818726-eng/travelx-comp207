-- Project members: Ahmed Walid Mohamed; David Tarek Rizk Khalil; Andrew Esmat Zaki Abdelmalek; Anton Hany Rady; Anas Ibrahim Gamil; Youssef Mostafa Abdelrahim Abdallah; Johnny Samir Attia
-- Faculty of Science, Ain Shams University - COMP 207 Database Systems, December 2026
-- =====================================================================
-- File 04: the three external-schema views (one per user role)
-- =====================================================================
USE travelx;

-- V1: CustomerTripView - bookings, status of every item, derived visa warning (BR-09, BR-20).
-- One row per booking item. The warning is derived from the traveler's passport:
--   'Visa required - no approved visa'  when the destination country requires a visa for
--   one of the traveler's passports and no approved, unexpired-at-arrival application exists.
CREATE OR REPLACE VIEW customer_trip_view AS
SELECT b.booking_id,
       b.booking_date,
       b.customer_id          AS booker_id,
       bi.booking_item_id,
       bi.service_type,
       bi.status              AS item_status,
       bi.price,
       t.customer_id          AS traveler_id,
       CONCAT(t.first_name, ' ', t.last_name) AS traveler_name,
       fi.scheduled_flight_id,
       sf.departure_datetime,
       sf.arrival_datetime,
       hi.check_in_date,
       hi.check_out_date,
       ci.pickup_date,
       ci.return_date,
       CASE
         WHEN bi.service_type <> 'Flight' THEN NULL
         WHEN vr.is_required IS NULL OR vr.is_required = FALSE THEN 'No visa needed'
         WHEN va.application_id IS NULL THEN 'Visa required - no approved visa'
         WHEN va.visa_expiry_date < DATE(sf.arrival_datetime) THEN 'Visa expires before arrival'
         ELSE 'Visa OK'
       END AS visa_warning
FROM booking b
JOIN booking_item bi ON bi.booking_id = b.booking_id
JOIN customer t      ON t.customer_id = bi.traveler_id
LEFT JOIN flight_item fi     ON fi.booking_item_id = bi.booking_item_id
LEFT JOIN scheduled_flight sf ON sf.scheduled_flight_id = fi.scheduled_flight_id
LEFT JOIN flight fl          ON fl.flight_id = sf.flight_id
LEFT JOIN airport ap         ON ap.airport_id = fl.arrival_airport_id
LEFT JOIN city cy            ON cy.city_id = ap.city_id
LEFT JOIN hotel_item hi      ON hi.booking_item_id = bi.booking_item_id
LEFT JOIN car_item ci        ON ci.booking_item_id = bi.booking_item_id
LEFT JOIN passport pp        ON pp.passport_id = (SELECT MAX(p2.passport_id) FROM passport p2
                                                   WHERE p2.customer_id = t.customer_id)
LEFT JOIN visa_requirement vr ON vr.nationality_country_id = pp.issuing_country_id
                             AND vr.destination_country_id = cy.country_id
LEFT JOIN visa_application va ON va.application_id =
        (SELECT MAX(v2.application_id) FROM visa_application v2
          JOIN passport p3 ON p3.passport_id = v2.passport_id
         WHERE p3.customer_id = t.customer_id
           AND v2.destination_country_id = cy.country_id
           AND v2.status = 'Approved');

-- V2: VisaOfficerView - applications and missing documents, NO payment data.
CREATE OR REPLACE VIEW visa_officer_view AS
SELECT va.application_id,
       CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
       pc.country_name                        AS passport_country,
       dc.country_name                        AS destination_country,
       va.application_date,
       va.status,
       va.visa_expiry_date,
       (SELECT COUNT(*)
          FROM required_document rd
          JOIN visa_requirement vr ON vr.requirement_id = rd.requirement_id
         WHERE vr.nationality_country_id = pp.issuing_country_id
           AND vr.destination_country_id = va.destination_country_id)  AS documents_required,
       (SELECT COUNT(*) FROM submitted_document sd
         WHERE sd.application_id = va.application_id)                  AS documents_submitted
FROM visa_application va
JOIN passport pp ON pp.passport_id = va.passport_id
JOIN customer c  ON c.customer_id  = pp.customer_id
JOIN country pc  ON pc.country_id  = pp.issuing_country_id
JOIN country dc  ON dc.country_id  = va.destination_country_id;

-- V3: AccountantView - totals, payments, refunds per booking, NO passport data.
-- Totals are computed in separate subqueries so the sums never multiply (D-28).
-- IFNULL turns "no row" into 0 so a booking without payments/refunds still shows.
CREATE OR REPLACE VIEW accountant_view AS
SELECT b.booking_id,
       CONCAT(c.first_name, ' ', c.last_name) AS booker_name,
       IFNULL((SELECT SUM(bi.price) FROM booking_item bi
                WHERE bi.booking_id = b.booking_id AND bi.status = 'Confirmed'), 0) AS active_total,
       IFNULL((SELECT SUM(p.amount) FROM payment p
                WHERE p.booking_id = b.booking_id AND p.status = 'Successful'), 0)  AS paid,
       IFNULL((SELECT SUM(r.amount) FROM refund r
                JOIN booking_item bi2 ON bi2.booking_item_id = r.booking_item_id
                WHERE bi2.booking_id = b.booking_id), 0)                            AS refunded,
       IFNULL((SELECT SUM(bi.price) FROM booking_item bi
                WHERE bi.booking_id = b.booking_id AND bi.status = 'Confirmed'), 0)
       - (IFNULL((SELECT SUM(p.amount) FROM payment p
                WHERE p.booking_id = b.booking_id AND p.status = 'Successful'), 0)
        - IFNULL((SELECT SUM(r.amount) FROM refund r
                JOIN booking_item bi2 ON bi2.booking_item_id = r.booking_item_id
                WHERE bi2.booking_id = b.booking_id), 0))                           AS remaining
FROM booking b
JOIN customer c ON c.customer_id = b.customer_id;
