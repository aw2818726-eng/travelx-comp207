# TravelX: الـ Relational Model (Phase 4)

مبني على الـ `EER` المعتمد (Phase 3) وعلى ملف `01_create_database_and_tables.sql` اللي في الـ zip، فالأسماء والـ `Constraints` هنا مطابقة للكود. **23 جدول، 30 `Foreign Key`.**

**الرموز:** `PK` بالخط العريض. `FK` ليها السهم `→`. `U` يعني `UNIQUE`. `NN` يعني `NOT NULL`. اللي من غير علامة `NN` بيقبل `NULL`.

---

## 1) خطوات تحويل الـ EER إلى Relational

| # | القاعدة | اتطبقت على |
|---|---|---|
| 1 | كل `Strong Entity` = جدول، والـ `PK` بديل (`AUTO_INCREMENT`) | 19 جدول (كلهم ما عدا `submitted_document` والتلات فروع) |
| 2 | كل `1:N` = `FK` على جهة الـ `N` | R1 إلى R22، R24 إلى R27 |
| 3 | `Recursive M:N` على `Country` = جدول `Associative` | `visa_requirement` (`nationality_country_id`، `destination_country_id`) |
| 4 | `Weak/Associative Entity` = `PK` مركب من `FK`ين | `submitted_document` |
| 5 | `Specialization` بطريقة `8A`: جدول للأب وجدول لكل فرع، و`PK` الفرع = `FK` للأب | `booking_item` ← `flight_item` و`hotel_item` و`car_item` |
| 6 | `1:1` = `FK` بقيد `UNIQUE` | `refund.booking_item_id` |
| 7 | `Derived Attribute` مش بيتخزن | حالة `Booking`، إجمالي الحجز، المتبقي، عمر العميل |
| 8 | `Entity` أقرب `Weak` بتاخد `PK` بديل مع `UNIQUE` على المفتاح الطبيعي | `city` و`room_type` و`required_document` (D-41) |

---

## 2) الـ Schema بالصيغة الرياضية

### التأشيرة والعميل

```
country(**country_id**, country_name [U, NN], iso_code [U])

customer(**customer_id**, first_name [NN], last_name [NN], email [U], phone, date_of_birth)

passport(**passport_id**, customer_id → customer [NN], issuing_country_id → country [NN],
         passport_number [NN], issue_date [NN], expiry_date [NN])
         U(issuing_country_id, passport_number)

visa_requirement(**requirement_id**, nationality_country_id → country [NN],
                 destination_country_id → country [NN], is_required [NN], visa_type)
         U(nationality_country_id, destination_country_id)

required_document(**required_document_id**, requirement_id → visa_requirement [NN],
                  document_name [NN])
         U(requirement_id, document_name)

visa_application(**application_id**, passport_id → passport [NN],
                 destination_country_id → country [NN], application_date [NN],
                 status [NN], visa_expiry_date)

submitted_document(**application_id** → visa_application, **required_document_id** → required_document,
                   submission_date [NN])
```

### الطيران

```
city(**city_id**, country_id → country [NN], city_name [NN])
         U(country_id, city_name)

airline(**airline_id**, airline_name [U, NN])

airport(**airport_id**, iata_code [U, NN], airport_name [NN], city_id → city [NN])

flight(**flight_id**, flight_number [U, NN], airline_id → airline [NN],
       departure_airport_id → airport [NN], arrival_airport_id → airport [NN])

scheduled_flight(**scheduled_flight_id**, flight_id → flight [NN], departure_datetime [NN],
                 arrival_datetime [NN], capacity [NN], price [NN], status [NN])
         U(flight_id, departure_datetime)
```

### الفندق والعربية

```
hotel(**hotel_id**, hotel_name [NN], city_id → city [NN], address)
         U(hotel_name, city_id)

room_type(**room_type_id**, hotel_id → hotel [NN], type_name [NN], price_per_night [NN], capacity [NN])
         U(hotel_id, type_name)

room(**room_id**, room_type_id → room_type [NN], room_number [NN])
         U(room_type_id, room_number)

car(**car_id**, plate_number [U, NN], model_name [NN], category [NN], daily_price [NN],
    city_id → city [NN])
```

### الحجز والدفع

```
booking(**booking_id**, customer_id → customer [NN], booking_date [NN])

booking_item(**booking_item_id**, booking_id → booking [NN], traveler_id → customer [NN],
             service_type [NN], price [NN], status [NN])

flight_item(**booking_item_id** → booking_item, scheduled_flight_id → scheduled_flight [NN],
            seat_number, ticket_number [U])
         U(scheduled_flight_id, seat_number)

hotel_item(**booking_item_id** → booking_item, room_id → room [NN], check_in_date [NN],
           check_out_date [NN], guest_count [NN])

car_item(**booking_item_id** → booking_item, car_id → car [NN], pickup_date [NN], return_date [NN])

payment(**payment_id**, booking_id → booking [NN], amount [NN], payment_date [NN],
        method [NN], status [NN])

refund(**refund_id**, booking_item_id → booking_item [NN, U], amount [NN], refund_date [NN],
       reason [NN])
```

---

## 3) الـ Referential Integrity (الـ 30 `FK`)

الافتراضي `ON DELETE RESTRICT`. الاستثناء `CASCADE` على الـ 4 اللي معلّمين.

| # | من (الابن) | العمود | إلى (الأب) | الدور |
|---|---|---|---|---|
| 1 | `passport` | `customer_id` | `customer` | صاحب الجواز |
| 2 | `passport` | `issuing_country_id` | `country` | بلد الإصدار |
| 3 | `visa_requirement` | `nationality_country_id` | `country` | الجنسية |
| 4 | `visa_requirement` | `destination_country_id` | `country` | الوجهة |
| 5 | `required_document` | `requirement_id` | `visa_requirement` | |
| 6 | `visa_application` | `passport_id` | `passport` | |
| 7 | `visa_application` | `destination_country_id` | `country` | الوجهة |
| 8 | `submitted_document` | `application_id` | `visa_application` | `CASCADE` |
| 9 | `submitted_document` | `required_document_id` | `required_document` | |
| 10 | `city` | `country_id` | `country` | |
| 11 | `airport` | `city_id` | `city` | |
| 12 | `flight` | `airline_id` | `airline` | |
| 13 | `flight` | `departure_airport_id` | `airport` | المغادرة |
| 14 | `flight` | `arrival_airport_id` | `airport` | الوصول |
| 15 | `scheduled_flight` | `flight_id` | `flight` | |
| 16 | `hotel` | `city_id` | `city` | |
| 17 | `room_type` | `hotel_id` | `hotel` | |
| 18 | `room` | `room_type_id` | `room_type` | |
| 19 | `car` | `city_id` | `city` | |
| 20 | `booking` | `customer_id` | `customer` | صاحب الحجز |
| 21 | `booking_item` | `booking_id` | `booking` | |
| 22 | `booking_item` | `traveler_id` | `customer` | المسافر |
| 23 | `flight_item` | `booking_item_id` | `booking_item` | `CASCADE` (`PK`) |
| 24 | `flight_item` | `scheduled_flight_id` | `scheduled_flight` | |
| 25 | `hotel_item` | `booking_item_id` | `booking_item` | `CASCADE` (`PK`) |
| 26 | `hotel_item` | `room_id` | `room` | |
| 27 | `car_item` | `booking_item_id` | `booking_item` | `CASCADE` (`PK`) |
| 28 | `car_item` | `car_id` | `car` | |
| 29 | `payment` | `booking_id` | `booking` | |
| 30 | `refund` | `booking_item_id` | `booking_item` | `UNIQUE` (`1:1`) |

**جداول بتتشاور عليها أكتر من مرة:** `country` (5 مرات: جواز، جنسية، وجهة قاعدة، وجهة طلب، مدينة)، `customer` (3: صاحب الجواز، صاحب الحجز، المسافر)، `airport` (2)، `booking_item` (4: التلات فروع و`refund`).

---

## 4) الـ Normalization

**الأساس:** كل الجداول فيها قيم ذرّية (`1NF`)، ومفيش `Multivalued Attribute`. الاسم مقسوم لـ `first_name` و`last_name`.

### الـ Functional Dependencies وملاحظات الـ `BCNF`

| الجدول | الـ FDs الأساسية | الحكم |
|---|---|---|
| `country` | `country_id` → كل الأعمدة. `country_name` → `country_id`. `iso_code` → `country_id` | `BCNF` (كل المحددات مفاتيح مرشحة) |
| `customer` | `customer_id` → الباقي. `email` → `customer_id` | `BCNF` |
| `passport` | `passport_id` → الباقي. `(issuing_country_id, passport_number)` → `passport_id` | `BCNF` |
| `visa_requirement` | `requirement_id` → الباقي. `(nationality, destination)` → `requirement_id` | `BCNF` |
| `visa_application` | `application_id` → الباقي | `BCNF` |
| `submitted_document` | `(application_id, required_document_id)` → `submission_date` | `BCNF`، ومفيش `Partial Dependency` (`submission_date` بيعتمد على الاتنين مع بعض) |
| `city` وغيرها من الجداول المرجعية | `city_id` → الباقي. `(country_id, city_name)` → `city_id` | `BCNF` |
| `flight` | `flight_id` → الباقي. `flight_number` → `flight_id` | `BCNF` |
| `scheduled_flight` | `scheduled_flight_id` → الباقي. `(flight_id, departure_datetime)` → `scheduled_flight_id` | `BCNF` |
| `room_type` | `room_type_id` → الباقي. `(hotel_id, type_name)` → `room_type_id` | `BCNF` |
| `booking_item` | `booking_item_id` → الباقي | `BCNF` |
| `flight_item` | `booking_item_id` → الباقي. `(scheduled_flight_id, seat_number)` → `booking_item_id`. `ticket_number` → `booking_item_id` | `BCNF` |
| `refund` | `refund_id` → الباقي. `booking_item_id` → `refund_id` | `BCNF` |

باقي الجداول (`airline` و`airport` و`hotel` و`room` و`car` و`booking` و`hotel_item` و`car_item` و`payment`) نفس النمط: المحدد الوحيد هو `PK` أو مفتاح مرشح، فهي `BCNF` وبالتبعية `3NF`.

### أمثلة على الـ Anomalies اللي التصميم منعها

| القرار | اللي كان هيحصل من غيره | النوع |
|---|---|---|
| مفيش `country_id` على `airport` و`hotel` و`car` (D-30) | `airport` ← `city` ← `country`، فتخزين البلد `Transitive Dependency`. تغيير بلد مدينة يتطلب تحديث صفوف كتير | `Update Anomaly` |
| `price_per_night` و`capacity` في `room_type` مش في `room` (D-39) | غرفة ← نوع ← سعر، فتكرار السعر على كل غرفة | `Update Anomaly` |
| `Flight` منفصل عن `ScheduledFlight` | بيانات الخط (الشركة والمطارات) تتكرر مع كل تاريخ | `Redundancy` |
| مفيش `customer_id` على `visa_application` | العميل بيتعرف من الجواز، فتخزينه `Transitive Dependency` (طلب ← جواز ← عميل) | `Update Anomaly` |
| مفيش جنسية على `customer` | الجنسية بتيجي من الجواز، والعميل ممكن يبقى عنده أكتر من جواز | `Update Anomaly` |
| حالة `Booking` وإجماليه مش مخزنين (D-32) | لازم تتزامن مع البنود والدفعات من غير `Triggers` | `Update Anomaly` |

### قرارات مقصودة خارج الـ Normalization الصارم

| العمود | ليه مش `Derived` | الخطر |
|---|---|---|
| `booking_item.price` | سعر المصدر (`scheduled_flight.price` وغيره) ممكن يتغير بعد الحجز، والمطلوب تثبيت السعر وقت الحجز (D-10) | مفيش، ده مش تكرار لأن القيمتين ممكن يختلفوا فعلًا |
| `booking_item.service_type` | ممكن نعرفه من وجود صف في أحد الفروع | تكرار مقصود بيخدم Q25. التناقض بين `service_type` والفرع محتاج `Query` فحص (D-31) |
| `visa_application.visa_expiry_date` | السفارة هي اللي بتحدده، مش قابل للاشتقاق (D-34) | `NULL` لحد الاعتماد، والـ `CHECK` بيربطه بالحالة |

---

## 5) اللي الـ Schema لا يضمنه لوحده

دي نفس قائمة Phase 3 (القسم 3)، متثبتة هنا عشان التقرير:

| القاعدة | الإنفاذ |
|---|---|
| كل بند ليه فرع واحد بالظبط ومطابق لـ `service_type` | بيانات + `Query` فحص |
| الحجز فيه بند واحد على الأقل | بيانات + `Query` فحص |
| مستند الطلب من قاعدة الطلب نفسه، وكل طلب ليه قاعدة | بيانات + `Query` فحص |
| نزلاء الغرفة ≤ سعة النوع، وركاب الرحلة ≤ السعة | `Query` فحص (قيد بين جدولين) |
| تداخل حجز الغرف والعربيات | `Trigger` |
| الاسترداد ≤ سعر البند، ومجموع الاستردادات ≤ المدفوع (BR-24) | `Query` فحص |
| رقم الغرفة فريد جوه الفندق (القيد على مستوى النوع بس) | بيانات |

---

## 6) تعديل مقترح على القسم 04 في التقرير

القسم 04 الحالي في الـ `PDF` جدول أعمدة بس، من غير أنواع ولا `NN` ولا `UNIQUE` ولا قائمة `FK`. اللي فوق (الأقسام 1 و2 و3 و4) يتحط بداله أو جنبه. ومحتاج يتأكد إن عدد الـ `FK` والـ 3NF مكتوبين بنفس الأرقام (30 و23).
