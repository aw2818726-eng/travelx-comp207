# TravelX: Integrated Travel and Reservation Management System

COMP 207 Database Systems project, Faculty of Science, Ain Shams University, December 2026.
Team: Ahmed Walid Mohamed, David Tarek Rizk Khalil, Andrew Esmat Zaki Abdelmalek, Anton Hany Rady, Anas Ibrahim Gamil, Youssef Mostafa Abdelrahim Abdallah, Johnny Samir Attia.
Supervisors: [to fill]. Project code: [to fill].
Deadline: Monday 7 December 2026, 11:59 PM.

MySQL 8.0.16 or later. 23 tables, 2 triggers (hotel and car double booking), 3 views, 32 queries.

## Layout (matches the template's delivery list)
| Path | What |
|---|---|
| `report/` | Project report in PDF and DOCX (official structure) |
| `presentation/` | Slide deck (PPTX and PDF) |
| `sql/travelx_full_database.sql` | Creation, triggers, data and views in one script |
| `sql/travelx_queries.sql` | All queries, each with a comment, separated by `;` |
| `sql/travelx_check_queries.sql`, `travelx_tests.sql` | Integrity checks and tests |
| `sql/travelx_workbench_import.sql` | Tables only, for building the .mwb |
| `diagrams/` | EER and physical diagrams |
| `frontend/` | Small web front end that shows the triggers working |
| `video/video_script.md` | Script split across the 7 members |
| `docs/` | Master context and relational model notes |

## Run the database
```
mysql -u root -p < sql/travelx_full_database.sql
mysql -u root -p < sql/travelx_queries.sql
```

## Run the front end
```
cd frontend
pip install -r requirements.txt
set DB_USER=root & set DB_PASSWORD=yourpassword      (Windows)   or  export DB_USER=root DB_PASSWORD=...
python app.py     # http://localhost:8000
```
Pages: book a hotel room or car (overlapping dates show the trigger error), the 3 views, and all queries with live results.
The front end was written but not run against a live MySQL server by whoever prepared this package. Test it before the discussion.

## Still open before submission
1. **`projectCode.mwb` is missing.** It must come from Workbench: run `sql/travelx_workbench_import.sql`, Database > Reverse Engineer, save as `<projectCode>.mwb`, then Forward Engineer to check it has no errors.
2. Supervisor names and the project code (for the zip name).
3. Record the video (max 20 min), see `video/video_script.md`.
4. Triggers: the team notes say the professor approved 1-2 triggers (decision D-13). That is only written in the team's own notes. Confirm it with the professor.
5. Export the final zip and upload it to the SharePoint link in the template.
