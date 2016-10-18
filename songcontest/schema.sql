SET client_min_messages TO ERROR;
DROP SCHEMA IF EXISTS songcontest CASCADE;
BEGIN;

CREATE SCHEMA songcontest;
SET search_path = songcontest;

-- Insert table creation statements here

CREATE TABLE songcontest.songs(
	id serial primary key,
	owner_id integer NOT NULL UNIQUE REFERENCES peeps.people(id) ON DELETE RESTRICT  	
);


INSERT INTO peeps.atkeys(atkey, description) VALUES('fan', 'Person is a fan.');
INSERT INTO peeps.atkeys(atkey, description) VALUES('musician', 'Person is a musician.');


----------------------------
----------------- FUNCTIONS:
----------------------------

-- Function to insert a new song
-- person_id - ID of the user, who uploaded the song
-- Return value: ID of the song (which we may use as filename component).

CREATE OR REPLACE FUNCTION songcontest.song_create(person_id integer, 
	OUT status smallint) RETURNS AS $$
DECLARE
	err_code text;
	err_msg text;
	err_detail text;
	err_context text;
BEGIN
	status := 200;
	js := row_to_json(r) FROM (QUERY INSERT INTO songcontest.songs(owner_id) VALUES(person_id) RETURNING songcontest.songs.id) r;
EXCEPTION
	WHEN OTHERS THEN GET STACKED DIAGNOSTICS
		err_code = RETURNED_SQLSTATE,
		err_msg = MESSAGE_TEXT,
		err_detail = PG_EXCEPTION_DETAIL,
		err_context = PG_EXCEPTION_CONTEXT;
	status := 500;
	js := json_build_object(
		'type', 'http://www.postgresql.org/docs/9.4/static/errcodes-appendix.html#' || err_code,
		'title', err_msg,
		'detail', err_detail || err_context);
END;
$$ LANGUAGE plpgsql;


----------------------------
------------------ TRIGGERS:
----------------------------


----------------------------------------
------------------------- API FUNCTIONS:
----------------------------------------

COMMIT;
