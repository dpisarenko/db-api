SET client_min_messages TO ERROR;
DROP SCHEMA IF EXISTS songcontest CASCADE;
BEGIN;

CREATE SCHEMA songcontest;
SET search_path = songcontest;

-- Insert table creation statements here

INSERT INTO peeps.atkeys(atkey, description) VALUES('fan', 'Person is a fan.');
INSERT INTO peeps.atkeys(atkey, description) VALUES('musician', 'Person is a musician.');

COMMIT;

----------------------------
----------------- FUNCTIONS:
----------------------------


----------------------------
------------------ TRIGGERS:
----------------------------


----------------------------------------
------------------------- API FUNCTIONS:
----------------------------------------
