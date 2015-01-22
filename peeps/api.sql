-- API REQUIRES AUTHENTICATION. User must be in peeps.emailers
-- peeps.emailers.id needed as first argument to many functions here

-- GET /emails/unopened/count
-- Grouped summary of howmany unopened emails in each profile/category
-- JSON format: {profiles:{categories:howmany}}
--{"derek@sivers":{"derek@sivers":43,"derek":2,"programmer":1},
-- "we@woodegg":{"woodeggRESEARCH":1,"woodegg":1,"we@woodegg":1}}
-- PARAMS: emailer_id
CREATE FUNCTION unopened_email_count(integer, OUT mime text, OUT js text) AS $$
BEGIN
	mime := 'application/json';
	SELECT json_object_agg(profile, cats) INTO js FROM (WITH unopened AS
		(SELECT profile, category FROM emails WHERE id IN
			(SELECT * FROM unopened_email_ids($1)))
		SELECT profile, (SELECT json_object_agg(category, num) FROM
			(SELECT category, COUNT(*) AS num FROM unopened u2
				WHERE u2.profile=unopened.profile
				GROUP BY category ORDER BY num DESC) rr)
		AS cats FROM unopened GROUP BY profile) r;  
	IF js IS NULL THEN
		js := '{}';
	END IF;
END;
$$ LANGUAGE plpgsql;


-- GET /emails/unopened/:profile/:category
-- PARAMS: emailer_id, profile, category
CREATE FUNCTION unopened_emails(integer, text, text, OUT mime text, OUT js text) AS $$
BEGIN
	mime := 'application/json';
	SELECT json_agg(r) INTO js FROM (SELECT * FROM emails_view WHERE id IN
		(SELECT id FROM emails WHERE id IN (SELECT * FROM unopened_email_ids($1))
			AND profile = $2 AND category = $3)) r;
	IF js IS NULL THEN
		js := '[]';
	END IF;
END;
$$ LANGUAGE plpgsql;


-- POST /emails/next/:profile/:category
-- Opens email (updates status as opened by this emailer) then returns view
-- PARAMS: emailer_id, profile, category
CREATE FUNCTION open_next_email(integer, text, text, OUT mime text, OUT js text) AS $$
DECLARE
	eid integer;
BEGIN
	SELECT id INTO eid FROM emails
		WHERE id IN (SELECT * FROM unopened_email_ids($1))
		AND profile=$2 AND category=$3 LIMIT 1;
	IF eid IS NULL THEN
m4_NOTFOUND
	ELSE
		mime := 'application/json';
		PERFORM open_email($1, eid);
		SELECT row_to_json(r) INTO js FROM
			(SELECT * FROM email_view WHERE id = eid) r;
	END IF;
END;
$$ LANGUAGE plpgsql;


-- GET /emails/opened
-- PARAMS: emailer_id
CREATE FUNCTION opened_emails(integer, OUT mime text, OUT js text) AS $$
BEGIN
	mime := 'application/json';
	SELECT json_agg(r) INTO js FROM (SELECT * FROM emails_view WHERE id IN
		(SELECT * FROM opened_email_ids($1))) r;
	IF js IS NULL THEN
		js := '[]';
	END IF;
END;
$$ LANGUAGE plpgsql;


-- GET /emails/:id
-- PARAMS: emailer_id, email_id
CREATE FUNCTION get_email(integer, integer, OUT mime text, OUT js text) AS $$
DECLARE
	eid integer;
BEGIN
	eid := open_email($1, $2);
	IF eid IS NULL THEN
m4_NOTFOUND
	ELSE
		mime := 'application/json';
		SELECT row_to_json(r) INTO js FROM
			(SELECT * FROM email_view WHERE id = eid) r;
	END IF;
END;
$$ LANGUAGE plpgsql;


-- PUT /emails/:id
-- PARAMS: emailer_id, email_id, JSON of new values
CREATE FUNCTION update_email(integer, integer, json, OUT mime text, OUT js text) AS $$
DECLARE
	eid integer;
m4_ERRVARS
BEGIN
	eid := ok_email($1, $2);
	IF eid IS NULL THEN
m4_NOTFOUND
	ELSE
		PERFORM public.jsonupdate('peeps.emails', eid, $3,
			public.cols2update('peeps', 'emails', ARRAY['id', 'created_at']));
		mime := 'application/json';
		SELECT row_to_json(r) INTO js FROM
			(SELECT * FROM email_view WHERE id = eid) r;
	END IF;
m4_ERRCATCH
END;
$$ LANGUAGE plpgsql;


-- DELETE /emails/:id
-- PARAMS: emailer_id, email_id
CREATE FUNCTION delete_email(integer, integer, OUT mime text, OUT js text) AS $$
DECLARE
	eid integer;
BEGIN
	eid := ok_email($1, $2);
	IF eid IS NULL THEN
m4_NOTFOUND
	ELSE
		mime := 'application/json';
		SELECT row_to_json(r) INTO js FROM
			(SELECT * FROM email_view WHERE id = eid) r;
		DELETE FROM emails WHERE id = eid;
	END IF;
END;
$$ LANGUAGE plpgsql;


-- PUT /emails/:id/close
-- PARAMS: emailer_id, email_id
CREATE FUNCTION close_email(integer, integer, OUT mime text, OUT js text) AS $$
DECLARE
	eid integer;
BEGIN
	eid := ok_email($1, $2);
	IF eid IS NULL THEN
m4_NOTFOUND
	ELSE
		UPDATE emails SET closed_at=NOW(), closed_by=$1 WHERE id = eid;
		mime := 'application/json';
		SELECT row_to_json(r) INTO js FROM
			(SELECT * FROM email_view WHERE id = eid) r;
	END IF;
END;
$$ LANGUAGE plpgsql;


-- PUT /emails/:id/unread
-- PARAMS: emailer_id, email_id
CREATE FUNCTION unread_email(integer, integer, OUT mime text, OUT js text) AS $$
DECLARE
	eid integer;
BEGIN
	eid := ok_email($1, $2);
	IF eid IS NULL THEN
m4_NOTFOUND
	ELSE
		UPDATE emails SET opened_at=NULL, opened_by=NULL WHERE id = eid;
		mime := 'application/json';
		SELECT row_to_json(r) INTO js FROM
			(SELECT * FROM email_view WHERE id = eid) r;
	END IF;
END;
$$ LANGUAGE plpgsql;


-- PUT /emails/:id/notme
-- PARAMS: emailer_id, email_id
CREATE FUNCTION not_my_email(integer, integer, OUT mime text, OUT js text) AS $$
DECLARE
	eid integer;
BEGIN
	eid := ok_email($1, $2);
	IF eid IS NULL THEN
m4_NOTFOUND
	ELSE
		UPDATE emails SET opened_at=NULL, opened_by=NULL, category=(SELECT
			substring(concat('not-', split_part(people.email,'@',1)) from 1 for 32)
			FROM emailers JOIN people ON emailers.person_id=people.id
			WHERE emailers.id = $1) WHERE id = eid;
		mime := 'application/json';
		SELECT row_to_json(r) INTO js FROM
			(SELECT * FROM email_view WHERE id = eid) r;
	END IF;
END;
$$ LANGUAGE plpgsql;

