SET client_min_messages TO ERROR;
DROP SCHEMA IF EXISTS songcontest CASCADE;
BEGIN;

CREATE SCHEMA songcontest;
SET search_path = songcontest;

-- Insert table creation statements here

CREATE TABLE songcontest.songs(
	id serial primary key,
	owner_id integer NOT NULL REFERENCES peeps.people(id) ON DELETE RESTRICT  	
);

DROP VIEW IF EXISTS songcontest.song_view
CASCADE;
CREATE VIEW songcontest.song_view AS
	SELECT id, owner_id
	FROM songcontest.songs;

DO $$
BEGIN
	INSERT INTO peeps.atkeys(atkey, description) VALUES('fan', 'Person is a fan.');
EXCEPTION 
	WHEN UNIQUE_VIOLATION THEN
END $$;

DO $$
BEGIN
	INSERT INTO peeps.atkeys(atkey, description) VALUES('musician', 'Person is a musician.');
EXCEPTION 
	WHEN UNIQUE_VIOLATION THEN
END $$;




----------------------------
----------------- FUNCTIONS:
----------------------------

-- Function to insert a new song
-- person_id - ID of the user, who uploaded the song
-- Return value: Created song record.

CREATE OR REPLACE FUNCTION songcontest.song_create(person_id integer) RETURNS SETOF songcontest.songs AS $$
BEGIN
	RETURN QUERY INSERT INTO songcontest.songs (owner_id) VALUES (person_id) RETURNING songcontest.songs.*;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION songcontest.create_song(person_id integer, OUT status smallint, OUT js json) AS $$
DECLARE
	sid integer;

	err_code text;
	err_msg text;
	err_detail text;
	err_context text;

BEGIN
	SELECT id INTO sid FROM songcontest.song_create($1);
	status := 200;
	js := row_to_json(r.*) FROM songcontest.song_view r WHERE id = sid;
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
