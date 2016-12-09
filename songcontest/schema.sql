SET client_min_messages TO ERROR;
DROP SCHEMA IF EXISTS songcontest CASCADE;
BEGIN;

CREATE SCHEMA songcontest;
SET search_path = songcontest;

-- Insert table creation statements here

CREATE TABLE songcontest.songs(
	id serial primary key,
	owner_id integer NOT NULL REFERENCES peeps.people(id) ON DELETE RESTRICT,
	name VARCHAR(256)
);

CREATE TABLE songcontest.feedback(
	person_id integer NOT NULL REFERENCES peeps.people(id) ON DELETE RESTRICT,
	song_id integer NOT NULL REFERENCES songcontest.songs(id) ON DELETE RESTRICT,
	grade smallint NOT NULL DEFAULT 0,
	grade_comment TEXT NOT NULL,
	UNIQUE (person_id, song_id)
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

CREATE OR REPLACE FUNCTION songcontest.song_create(person_id integer, song_name VARCHAR(256)) RETURNS SETOF songcontest.songs AS $$
BEGIN
	RETURN QUERY INSERT INTO songcontest.songs (owner_id, name) VALUES (person_id, song_name) RETURNING songcontest.songs.*;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION songcontest.create_song(person_id integer, song_name VARCHAR(256), OUT status smallint, OUT js json) AS $$
DECLARE
	sid integer;

	err_code text;
	err_msg text;
	err_detail text;
	err_context text;

BEGIN
	SELECT id INTO sid FROM songcontest.song_create($1, $2);
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

-- Functions for finding the next song that a given user (fan)
-- hasn't listened to yet.
CREATE OR REPLACE FUNCTION songcontest.song_find(listener_id integer) RETURNS SETOF songcontest.songs AS $$
BEGIN
	RETURN QUERY SELECT songcontest.songs.*
	FROM songcontest.songs
	WHERE songcontest.songs.id NOT IN (SELECT DISTINCT songcontest.feedback.song_id FROM songcontest.feedback WHERE songcontest.feedback.person_id=listener_id)
	LIMIT 1;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION songcontest.find_song(person_id integer, OUT status smallint, OUT js json) AS $$
DECLARE
	song RECORD;

	err_code text;
	err_msg text;
	err_detail text;
	err_context text;

BEGIN
	SELECT * INTO song FROM songcontest.song_find($1);
	status := 200;
	js := row_to_json(song.*);
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

-- @db.call('create_feedback', @person_id, song_id, grade, comment)

CREATE OR REPLACE FUNCTION songcontest.feedback_create(p_person_id integer, p_song_id integer, p_grade smallint, p_grade_comment TEXT) RETURNS SETOF songcontest.feedback AS $$
BEGIN
	RETURN QUERY INSERT INTO songcontest.feedback (person_id, song_id, grade, grade_comment) VALUES (p_person_id, p_song_id, p_grade, p_grade_comment) RETURNING songcontest.feedback.*;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION songcontest.create_feedback(p_person_id integer, p_song_id integer, p_grade smallint, p_grade_comment TEXT, OUT status smallint, OUT js json) AS $$
DECLARE
	fb RECORD;
	err_code text;
	err_msg text;
	err_detail text;
	err_context text;
BEGIN
	SELECT * INTO fb FROM songcontest.feedback_create($1, $2, $3, $4);
	status := 200;
	js := row_to_json(fb.*);
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

CREATE OR REPLACE FUNCTION songcontest.compose_all_songs_stats(p_person_id integer) RETURNS TABLE(song_id INTEGER, song_name VARCHAR(256), avg_grade NUMERIC, feedback_count BIGINT) AS $$
BEGIN
	RETURN QUERY
		SELECT songcontest.songs.id, songcontest.songs.name, AVG(songcontest.feedback.grade), COUNT(songcontest.feedback.grade)
		FROM songcontest.songs, songcontest.feedback
		WHERE songcontest.feedback.song_id = songcontest.songs.id
		GROUP BY songcontest.songs.id, songcontest.songs.name
		HAVING songcontest.songs.owner_id = p_person_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION songcontest.all_songs_stats(person_id integer, OUT status smallint, OUT js json) AS $$
DECLARE
	err_code text;
	err_msg text;
	err_detail text;
	err_context text;
BEGIN
	SELECT array_to_json(array_agg(r)) INTO js FROM songcontest.compose_all_songs_stats(person_id) r;	
	status := 200;
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
