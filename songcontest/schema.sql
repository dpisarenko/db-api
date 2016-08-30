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


-- INSERT INTO peeps.atkeys(atkey, description) VALUES('fan', 'Person is a fan.');
-- INSERT INTO peeps.atkeys(atkey, description) VALUES('musician', 'Person is a musician.');


----------------------------
----------------- FUNCTIONS:
----------------------------

-- Function to insert a new song
-- person_id - ID of the user, who uploaded the song
-- Return value: ID of the song (which we may use as filename component).

CREATE OR REPLACE FUNCTION songcontest.song_create(person_id integer) RETURNS SETOF integer AS $$
BEGIN
	RETURN QUERY INSERT INTO songcontest.songs(owner_id) VALUES(person_id) RETURNING songcontest.songs.id;
END;
$$ LANGUAGE plpgsql;


----------------------------
------------------ TRIGGERS:
----------------------------


----------------------------------------
------------------------- API FUNCTIONS:
----------------------------------------

COMMIT;
