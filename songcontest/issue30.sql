-- Script for modifying the database in scope of issue 29

TODO: Create table contestStatuses

CREATE TABLE songcontest.contestStatuses(
	id integer primary key,
	name VARCHAR(256)

);

INSERT INTO songcontest.contestStatuses(id, name) VALUES(1, "New");
INSERT INTO songcontest.contestStatuses(id, name) VALUES(2, "Approved");
INSERT INTO songcontest.contestStatuses(id, name) VALUES(3, "Submitting songs");
INSERT INTO songcontest.contestStatuses(id, name) VALUES(4, "Voting");
INSERT INTO songcontest.contestStatuses(id, name) VALUES(5, "Finishing");
INSERT INTO songcontest.contestStatuses(id, name) VALUES(6, "Completed");
INSERT INTO songcontest.contestStatuses(id, name) VALUES(7, "Canceled");

TODO: Create table contests
TODO: Add user type "organizer"
TODO: modify the table feedback so that it contains a link to the contestStatuses database.
