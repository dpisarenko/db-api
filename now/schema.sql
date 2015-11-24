SET client_min_messages TO ERROR;
DROP SCHEMA IF EXISTS now CASCADE;
BEGIN;

CREATE SCHEMA now;
SET search_path = now;

CREATE TABLE now.urls (
	id serial primary key,
	person_id integer REFERENCES peeps.people(id) ON DELETE CASCADE,
	created_at date not null default CURRENT_DATE,
	updated_at date,
	short varchar(72) UNIQUE,
	long varchar(100) UNIQUE CONSTRAINT url_format CHECK (long ~ '^https?://[0-9a-zA-Z_-]+\.[a-zA-Z0-9]+')
);

COMMIT;

----------------------------
----------------- FUNCTIONS:
----------------------------

-- PARAMS: now.urls.id
CREATE OR REPLACE FUNCTION now.find_person(integer) RETURNS SETOF integer AS $$
BEGIN
	RETURN QUERY SELECT p.person_id
	FROM now.urls n
	INNER JOIN peeps.urls p
	ON (regexp_replace(n.short, '/.*$', '') =
	regexp_replace(regexp_replace(regexp_replace(lower(p.url), '^https?://', ''), '^www.', ''), '/.*$', ''))
	WHERE n.id = $1;
END;
$$ LANGUAGE plpgsql;

----------------------------------------
------------------------- API FUNCTIONS:
----------------------------------------

-- now.urls with person_id
CREATE OR REPLACE FUNCTION now.knowns(
	OUT status smallint, OUT js json) AS $$
BEGIN
	status := 200;
	js := json_agg(r) FROM
		(SELECT id, person_id, short FROM now.urls
			WHERE person_id IS NOT NULL ORDER BY short) r;
END;
$$ LANGUAGE plpgsql;


-- now.urls missing person_id
CREATE OR REPLACE FUNCTION now.unknowns(
	OUT status smallint, OUT js json) AS $$
BEGIN
	status := 200;
	js := json_agg(r) FROM
		(SELECT id, short, long FROM now.urls WHERE person_id IS NULL) r;
	IF js IS NULL THEN js := '[]'; END IF;
END;
$$ LANGUAGE plpgsql;


-- PARAMS: now.urls.id
CREATE OR REPLACE FUNCTION now.url(integer,
	OUT status smallint, OUT js json) AS $$
BEGIN
	status := 200;
	js := row_to_json(r.*) FROM now.urls r WHERE id = $1;
	IF js IS NULL THEN 
	status := 404;
	js := '{}';
 END IF;
END;
$$ LANGUAGE plpgsql;


-- PARAMS: now.urls.id
CREATE OR REPLACE FUNCTION now.unknown_find(integer,
	OUT status smallint, OUT js json) AS $$
BEGIN
	status := 200;
	js := json_agg(r) FROM (SELECT * FROM peeps.people_view WHERE id IN
		(SELECT * FROM now.find_person($1))) r;
	IF js IS NULL THEN js := '[]'; END IF;
END;
$$ LANGUAGE plpgsql;


-- PARAMS: now.urls.id, person_id
CREATE OR REPLACE FUNCTION now.unknown_assign(integer, integer,
	OUT status smallint, OUT js json) AS $$
BEGIN
	status := 200;
	UPDATE now.urls SET person_id = $2 WHERE id = $1;
	js := row_to_json(r.*) FROM now.urls r WHERE id = $1;
	IF js IS NULL THEN 
	status := 404;
	js := '{}';
 END IF;
END;
$$ LANGUAGE plpgsql;


-- PARAMS: person_id
CREATE OR REPLACE FUNCTION now.urls_for_person(integer,
	OUT status smallint, OUT js json) AS $$
BEGIN
	status := 200;
	js := json_agg(r) FROM
		(SELECT * FROM now.urls WHERE person_id=$1 ORDER BY id) r;
	IF js IS NULL THEN js := '[]'; END IF;
END;
$$ LANGUAGE plpgsql;


-- PARAMS: person_id
CREATE OR REPLACE FUNCTION now.stats_for_person(integer,
	OUT status smallint, OUT js json) AS $$
BEGIN
	status := 200;
	js := json_agg(r) FROM
		(SELECT id, statkey AS name, statvalue AS value, created_at
			FROM peeps.stats WHERE person_id=$1 AND statkey LIKE 'now-%'
			ORDER BY id) r;
	IF js IS NULL THEN js := '[]'; END IF;
END;
$$ LANGUAGE plpgsql;


-- PARAMS: person_id, short
CREATE OR REPLACE FUNCTION now.add_url(integer, text,
	OUT status smallint, OUT js json) AS $$
DECLARE

	err_code text;
	err_msg text;
	err_detail text;
	err_context text;

BEGIN
	status := 200;
	WITH nu AS (INSERT INTO now.urls(person_id, short)
		VALUES ($1, $2) RETURNING *)
		SELECT row_to_json(r) INTO js FROM (SELECT * FROM nu) r;

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


-- PARAMS: now.urls.id, JSON of new values
CREATE OR REPLACE FUNCTION now.update_url(integer, json,
	OUT status smallint, OUT js json) AS $$
DECLARE

	err_code text;
	err_msg text;
	err_detail text;
	err_context text;

BEGIN
	PERFORM core.jsonupdate('now.urls', $1, $2,
		core.cols2update('now', 'urls', ARRAY['id', 'created_at', 'updated_at']));
	status := 200;
	UPDATE now.urls SET updated_at=NOW() WHERE id = $1;
	js := row_to_json(r.*) FROM now.urls r WHERE id = $1;
	IF js IS NULL THEN 
	status := 404;
	js := '{}';
 END IF;

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

-- NOTE: will also use from peeps schema:
-- peeps.update_stat(id, json)
-- peeps.add_stat(person_id, name, value)

