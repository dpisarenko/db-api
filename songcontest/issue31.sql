-- Script for modifying the database in scope of issue 31

-- Function pair to retrieve a list of all song contests

CREATE OR REPLACE FUNCTION songcontest.all_contests_get() RETURNS SETOF songcontest.contests AS $$
BEGIN
	RETURN QUERY SELECT songcontest.contests.*
	FROM songcontest.contests
	ORDER BY songcontest.contests.id DESC;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION songcontest.get_all_contests(OUT status smallint, OUT js json) AS $$
DECLARE
	song RECORD;

	err_code text;
	err_msg text;
	err_detail text;
	err_context text;

BEGIN
	-- SELECT array_to_json(array_agg(r)) INTO js FROM songcontest.all_contests_get() r;	
	js := json_agg(r) FROM songcontest.all_contests_get() r;
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

-- Function pair to retrieve the number of song contests

CREATE OR REPLACE FUNCTION songcontest.calculate_contests_count() RETURNS INTEGER AS $$
DECLARE
	contestsCount INTEGER;
BEGIN	
	SELECT COUNT(*)
	INTO contestsCount
	FROM songcontest.contests;
	RETURN contestsCount;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION songcontest.contests_count(OUT status smallint, OUT js json) AS $$
DECLARE
    contestsCount RECORD;
	err_code text;
	err_msg text;
	err_detail text;
	err_context text;
BEGIN
	SELECT * INTO contestsCount FROM songcontest.calculate_contests_count();
	status := 200;
	js := row_to_json(contestsCount.*);
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
