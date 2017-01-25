-- Script for modifying the database in scope of issue 29

CREATE TABLE songcontest.contestStatuses(
	id integer primary key,
	name VARCHAR(256)

);

INSERT INTO songcontest.contestStatuses(id, name) VALUES(1, 'New');
INSERT INTO songcontest.contestStatuses(id, name) VALUES(2, 'Approved');
INSERT INTO songcontest.contestStatuses(id, name) VALUES(3, 'Submitting songs');
INSERT INTO songcontest.contestStatuses(id, name) VALUES(4, 'Voting');
INSERT INTO songcontest.contestStatuses(id, name) VALUES(5, 'Finishing');
INSERT INTO songcontest.contestStatuses(id, name) VALUES(6, 'Completed');
INSERT INTO songcontest.contestStatuses(id, name) VALUES(7, 'Canceled');

CREATE TABLE songcontest.contests(
	id serial primary key,
	name VARCHAR(256),
	sponsor_description TEXT,
	state integer NOT NULL REFERENCES songcontest.statuses(id) ON DELETE RESTRICT,
	terms_description TEXT
);


DO $$
BEGIN
	INSERT INTO peeps.atkeys(atkey, description) VALUES('org', 'Person is a contest organizer.');
EXCEPTION 
	WHEN UNIQUE_VIOLATION THEN
END $$;

ALTER TABLE songcontest.feedback
	ADD COLUMN contest_id integer NOT NULL REFERENCES songcontest.contests(id) ON DELETE RESTRICT;

ALTER TABLE songcontest.feedback
	ADD UNIQUE(person_id, song_id, contest_id);
	
