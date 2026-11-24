-- Project members: Ahmed Walid Mohamed; David Tarek Rizk Khalil; Andrew Esmat Zaki Abdelmalek; Anton Hany Rady; Anas Ibrahim Gamil; Youssef Mostafa Abdelrahim Abdallah; Johnny Samir Attia
-- Faculty of Science, Ain Shams University - COMP 207 Database Systems, December 2026
-- =====================================================================
-- File 02: Triggers (course limit: only 1-2 triggers; we use two)
--   T1  hotel room double-booking  (BR-13)  - needed, no constraint can do it
--   T2  car double-booking         (BR-15)  - optional, same pattern
-- Overlap rule: two stays overlap when  new.in < old.out  AND  new.out > old.in
-- (back-to-back stays: check-out day = next check-in day is allowed).
-- Only items whose booking_item.status = 'Confirmed' block a room / car.
-- =====================================================================
USE travelx;

DELIMITER $$

CREATE TRIGGER trg_hotel_item_no_overlap
BEFORE INSERT ON hotel_item
FOR EACH ROW
BEGIN
    IF EXISTS (SELECT 1
               FROM hotel_item h
               JOIN booking_item b ON b.booking_item_id = h.booking_item_id
               WHERE h.room_id = NEW.room_id
                 AND b.status = 'Confirmed'
                 AND NEW.check_in_date  < h.check_out_date
                 AND NEW.check_out_date > h.check_in_date) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Room already booked for these dates (BR-13)';
    END IF;
END$$

CREATE TRIGGER trg_car_item_no_overlap
BEFORE INSERT ON car_item
FOR EACH ROW
BEGIN
    IF EXISTS (SELECT 1
               FROM car_item c
               JOIN booking_item b ON b.booking_item_id = c.booking_item_id
               WHERE c.car_id = NEW.car_id
                 AND b.status = 'Confirmed'
                 AND NEW.pickup_date < c.return_date
                 AND NEW.return_date > c.pickup_date) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Car already rented for these dates (BR-15)';
    END IF;
END$$

DELIMITER ;
