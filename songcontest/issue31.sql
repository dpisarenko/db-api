-- Script for modifying the database in scope of issue 31

-- Function pair to retrieve a list of all song contests

CREATE OR REPLACE FUNCTION songcontest.all_contests_get RETURNS SETOF songcontest.contests AS $$
BEGIN
	RETURN QUERY SELECT songcontest.contests.*
	FROM songcontest.contests
	ORDER BY songcontest.contests.id DESC
	LIMIT 1;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION songcontest.get_all_contents(OUT status smallint, OUT js json) AS $$
DECLARE
	song RECORD;

	err_code text;
	err_msg text;
	err_detail text;
	err_context text;

BEGIN
	SELECT array_to_json(array_agg(r)) INTO js FROM songcontest.all_contests_get() r;	
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
