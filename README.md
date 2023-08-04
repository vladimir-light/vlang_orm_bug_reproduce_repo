In order to repdoruce potential bug with oneToMany/oneToOne in ORM
---

1) comment out all init_* functions but not `init_teams()`.
2) run it ( `v -d trace_db run fixtures.v` ) `teams` table will be created and populated with data
3) comment out all init_* functions but not `init_predictions_no_orm()`
4) run it again. `predictions` table will be created and populated with data
5) now, comment everything but not `init_predictions_no_orm()` and run it -> script panics with `"V panic: db.sqlite.SQLError: UNIQUE constraint failed:"` while trying to insert into `teams` instead of inserting into `predictions` table
