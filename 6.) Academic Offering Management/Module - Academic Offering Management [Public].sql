-----------------------------------------------------------------------------------------------
------------------------------- INTERNAL SCHEMA -----------------------------------------------


------------------------------------------------------------------------------------------------------------------------
-- 1. Manage Programs---------------------------------------------------------------------------------------------------

--- 1.1 View all Programs

CREATE OR REPLACE FUNCTION public.view_all_programs()
RETURNS TABLE(
    id TEXT,
    name TEXT,
    rating TEXT,
    likes TEXT,
    college TEXT,
    certifications TEXT[],
    date TEXT,
    status TEXT,
    created_by TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    error_code TEXT;
    err_code TEXT;
    err_msg TEXT;
BEGIN
    RETURN QUERY
    SELECT * FROM internal.view_all_programs();
EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
        IF err_code IN ('P0015') THEN
            RETURN QUERY
            -- SELECT 'X'::TEXT, err_msg::TEXT;
            SELECT '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT;

        END IF;

        -- Generic fallback logging
        SELECT internal.log_error_wrapper(
                       err_code,
                       err_msg,
                       'public.view_all_programs',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        RETURN QUERY
        --SELECT 'X'::TEXT, concat('Something went wrong. ', error_code)::TEXT;
        SELECT '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT;


END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION public.view_all_programs() FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION public.view_all_programs() TO authenticated;

--- 1.1.2 SELECT & VIEW PROGRAM

CREATE OR REPLACE FUNCTION public.select_program(IN p_special_id TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    error_code TEXT;
    err_code TEXT;
    err_msg TEXT;
    result JSONB;
BEGIN
    -- Main procedure call
    result := internal.select_program(
        p_special_id
    );

    -- RETURN '✅ Program successfully deleted.';
    RETURN jsonb_build_object(
        'status', 'success',
        'message', result
    );

EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
        IF err_code IN ('P0010') THEN
            -- RETURN err_msg;
            RETURN jsonb_build_object(
                'status', 'warning',
                'message', err_msg
            );
        END IF;

        -- Generic fallback logging
        SELECT internal.log_error_wrapper(
                       err_code,
                       err_msg,
                       'public.select_program',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        -- RETURN concat('Something went wrong. ', error_code);
        RETURN jsonb_build_object(
                'status', 'error',
                'message', concat('Something went wrong. ', error_code)
            );

END;
$$;
REVOKE ALL ON FUNCTION public.select_program(IN p_special_id TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.select_program(IN p_special_id TEXT) TO authenticated;

--- 1.2 Create Program

CREATE OR REPLACE FUNCTION public.create_program(
    IN p_prog_name VARCHAR(255),
    IN p_prog_abbr VARCHAR(50),
    IN p_cao_id TEXT,
    IN p_exs_mprog_id TEXT,
    IN p_special_name VARCHAR(255),
    IN p_special_abbr VARCHAR(50),
    IN p_about  TEXT,
    IN p_entry_requirements TEXT[],
    IN p_certification_ids TEXT[] DEFAULT NULL -- array of base64-encoded certification IDs
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    error_code TEXT;
    err_code TEXT;
    err_msg TEXT;
BEGIN
    -- Main procedure call
    CALL internal.create_program(
        p_prog_name,
        p_prog_abbr,
        p_cao_id,
        p_exs_mprog_id,
        p_special_name,
        p_special_abbr,
        p_about,
        p_entry_requirements,
        p_certification_ids
    );

    -- RETURN '✅ Program successfully created.';
    RETURN jsonb_build_object(
        'status', 'success',
        'message', '✅ Program successfully created.'
    );

EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
        IF err_code IN ('P0010', 'P0020','P0021', 'P0022','P0023','P0024') THEN
            -- RETURN err_msg;
            RETURN jsonb_build_object(
                'status', 'warning',
                'message', err_msg
            );
        END IF;

        -- Generic fallback logging
        SELECT internal.log_error_wrapper(
                       err_code,
                       err_msg,
                       'public.create_program',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        -- RETURN concat('Something went wrong. ', error_code);
        RETURN jsonb_build_object(
                'status', 'error',
                'message', concat('Something went wrong. ', error_code)
            );

END;
$$;
REVOKE ALL ON FUNCTION public.create_program(
    IN p_prog_name VARCHAR(255),
    IN p_prog_abbr VARCHAR(50),
    IN p_cao_id TEXT,
    IN p_exs_mprog_id TEXT,
    IN p_special_name VARCHAR(255),
    IN p_special_abbr VARCHAR(50),
    IN p_about TEXT,
    IN p_entry_requirements TEXT[],
    IN p_certification_ids TEXT[]-- array of base64-encoded certification IDs
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_program(
    IN p_prog_name VARCHAR(255),
    IN p_prog_abbr VARCHAR(50),
    IN p_cao_id TEXT,
    IN p_exs_mprog_id TEXT,
    IN p_special_name VARCHAR(255),
    IN p_special_abbr VARCHAR(50),
    IN p_about TEXT,
    IN p_entry_requirements TEXT[],
    IN p_certification_ids TEXT[]-- array of base64-encoded certification IDs
) TO authenticated;

---- 1.2.1 Get all certification types

CREATE OR REPLACE FUNCTION public.get_certification_types()
RETURNS TABLE(id TEXT, name TEXT)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    error_code TEXT;
    err_code TEXT;
    err_msg TEXT;
BEGIN
    RETURN QUERY
    SELECT * FROM internal.get_certification_types();
EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
        IF err_code IN ('P0015') THEN
            RETURN QUERY
            SELECT '*'::TEXT, '*'::TEXT;

        END IF;

        -- Generic fallback logging
        SELECT internal.log_error_wrapper(
                       err_code,
                       err_msg,
                       'public.get_certification_types',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        RETURN QUERY
        --SELECT 'X'::TEXT, concat('Something went wrong. ', error_code)::TEXT;
        SELECT '*'::TEXT, '*'::TEXT;


END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION public.get_certification_types() FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION public.get_certification_types() TO authenticated;

---- 1.2.2 Get all main programs for dropdown

CREATE OR REPLACE FUNCTION public.get_main_programs()
RETURNS TABLE(id TEXT, name TEXT)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    error_code TEXT;
    err_code TEXT;
    err_msg TEXT;
BEGIN
    RETURN QUERY
    SELECT * FROM internal.get_main_programs();
EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
        IF err_code IN ('P0015') THEN
            RETURN QUERY
            SELECT '*'::TEXT, '*'::TEXT;
        END IF;

        -- Generic fallback logging
        SELECT internal.log_error_wrapper(
                       err_code,
                       err_msg,
                       'public.get_main_programs',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        RETURN QUERY
        --SELECT 'X'::TEXT, concat('Something went wrong. ', error_code)::TEXT;
        SELECT '*'::TEXT, '*'::TEXT;


END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION public.get_main_programs() FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION public.get_main_programs() TO authenticated;

--- 1.3 Update Program

CREATE OR REPLACE FUNCTION public.update_program(
    IN p_special_id TEXT,
    IN p_prog_name VARCHAR(255),
    IN p_prog_abbr VARCHAR(50),
    IN p_cao_id TEXT,
    IN p_exs_mprog_id TEXT,
    IN p_special_name VARCHAR(255),
    IN p_special_abbr VARCHAR(50),
    IN p_about TEXT,
    IN p_entry_requirements TEXT[],
    IN p_certification_ids TEXT[] DEFAULT NULL -- array of base64-encoded certification IDs
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    error_code TEXT;
    err_code TEXT;
    err_msg TEXT;
BEGIN
    -- Main procedure call
    CALL internal.update_program(
        p_special_id,
        p_prog_name,
        p_prog_abbr,
        p_cao_id,
        p_exs_mprog_id,
        p_special_name,
        p_special_abbr,
        p_about,
        p_entry_requirements,
        p_certification_ids
    );

    -- RETURN '✅ Program successfully updated.';
    RETURN jsonb_build_object(
        'status', 'success',
        'message', '✅ Program successfully updated.'
    );

EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
        IF err_code IN ('P0010', 'P0020', 'P0021', 'P0022','P0023','P0024','P0025','P0026') THEN
            -- RETURN err_msg;
            RETURN jsonb_build_object(
                'status', 'warning',
                'message', err_msg
            );
        END IF;

        -- Generic fallback logging
        SELECT internal.log_error_wrapper(
                       err_code,
                       err_msg,
                       'public.update_program',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        -- RETURN concat('Something went wrong. ', error_code);
        RETURN jsonb_build_object(
                'status', 'error',
                'message', concat('Something went wrong. ', error_code)
            );

END;
$$;
REVOKE ALL ON FUNCTION public.update_program(
    IN p_special_id TEXT,
    IN p_prog_name VARCHAR(255),
    IN p_prog_abbr VARCHAR(50),
    IN p_cao_id TEXT,
    IN p_exs_mprog_id TEXT,
    IN p_special_name VARCHAR(255),
    IN p_special_abbr VARCHAR(50),
    IN p_about TEXT,
    IN p_entry_requirements TEXT[],
    IN p_certification_ids TEXT[]-- array of base64-encoded certification IDs
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.update_program(
    IN p_special_id TEXT,
    IN p_prog_name VARCHAR(255),
    IN p_prog_abbr VARCHAR(50),
    IN p_cao_id TEXT,
    IN p_exs_mprog_id TEXT,
    IN p_special_name VARCHAR(255),
    IN p_special_abbr VARCHAR(50),
    IN p_about TEXT,
    IN p_entry_requirements TEXT[],
    IN p_certification_ids TEXT[]-- array of base64-encoded certification IDs
) TO authenticated;

--- 1.4 Delete Program

CREATE OR REPLACE FUNCTION public.delete_program(
    IN p_special_id TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    error_code TEXT;
    err_code TEXT;
    err_msg TEXT;
BEGIN
    -- Main procedure call
    CALL internal.delete_program(
        p_special_id
    );

    -- RETURN '✅ Program successfully deleted.';
    RETURN jsonb_build_object(
        'status', 'success',
        'message', '✅ Program successfully deleted.'
    );


EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
        IF err_code IN ('P0010') THEN
            -- RETURN err_msg;
            RETURN jsonb_build_object(
                'status', 'warning',
                'message', err_msg
            );
        END IF;

        -- Generic fallback logging
        SELECT internal.log_error_wrapper(
                       err_code,
                       err_msg,
                       'public.delete_program',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        -- RETURN concat('Something went wrong. ', error_code);
        RETURN jsonb_build_object(
                'status', 'error',
                'message', concat('Something went wrong. ', error_code)
            );

END;
$$;
REVOKE ALL ON FUNCTION public.delete_program(IN p_special_id TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.delete_program(IN p_special_id TEXT) TO authenticated;



------------------------------------------------------------------------------------------------------------------------
-- 2. Manage Prospectus ------------------------------------------------------------------------------------------------


--- 2.1 View all Prospectus

CREATE OR REPLACE FUNCTION public.view_all_prospectus(IN p_special_id TEXT)
RETURNS TABLE(
    id TEXT,
    code TEXT,
    date TEXT,
    created_by TEXT,
    year TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    error_code TEXT;
    err_code TEXT;
    err_msg TEXT;
BEGIN
    RETURN QUERY
    SELECT * FROM internal.view_all_prospectus(p_special_id);
EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
        IF err_code IN ('P0015') THEN
            RETURN QUERY
            -- SELECT 'X'::TEXT, err_msg::TEXT;
            SELECT '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT;
        END IF;

        -- Generic fallback logging
        SELECT internal.log_error_wrapper(
                       err_code,
                       err_msg,
                       'public.view_all_prospectus',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        RETURN QUERY
        --SELECT 'X'::TEXT, concat('Something went wrong. ', error_code)::TEXT;
        SELECT '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT;

END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION public.view_all_prospectus(IN p_special_id TEXT) FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION public.view_all_prospectus(IN p_special_id TEXT) TO authenticated;

--//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
--- 2.2 Delete Prospectus

CREATE OR REPLACE FUNCTION public.delete_prospectus(
    IN p_prospectus_id TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    error_code TEXT;
    err_code TEXT;
    err_msg TEXT;
BEGIN
    -- Main procedure call
    CALL internal.delete_prospectus(
        p_prospectus_id
    );

    -- RETURN '✅ Prospectus successfully deleted.';
    RETURN jsonb_build_object(
        'status', 'success',
        'message', '✅ Prospectus successfully deleted.'
    );

EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
        IF err_code IN ('P0010') THEN
            -- RETURN err_msg;
            RETURN jsonb_build_object(
                'status', 'warning',
                'message', err_msg
            );
        END IF;

        -- Generic fallback logging
        SELECT internal.log_error_wrapper(
                       err_code,
                       err_msg,
                       'public.delete_prospectus',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        -- RETURN concat('Something went wrong. ', error_code);
        RETURN jsonb_build_object(
            'status', 'error',
            'message', concat('Something went wrong. ', error_code)
        );

END;
$$;
REVOKE ALL ON FUNCTION public.delete_prospectus(IN p_prospectus_id TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.delete_prospectus(IN p_prospectus_id TEXT) TO authenticated;

--//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

--- 2.3  Create Prospectus

CREATE OR REPLACE FUNCTION public.create_prospectus(
    IN p_special_id TEXT,
    IN p_year INTEGER,
    IN p_semesters_and_duration JSONB,
    IN p_classifications_and_units JSONB,
    IN p_courses_and_classification_units JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    error_code TEXT;
    err_code TEXT;
    err_msg TEXT;
BEGIN
    -- Main procedure call
    CALL internal.create_prospectus(
            p_special_id,
            p_year,
            p_semesters_and_duration,
            p_classifications_and_units,
            p_courses_and_classification_units
    );

    -- RETURN '✅ Prospectus successfully created.';
    RETURN jsonb_build_object(
        'status', 'success',
        'message', '✅ Prospectus successfully created.'
    );

EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
        IF err_code IN ('P0010','P0029','P0027', 'P0028','P0030','P0031','P0032', 'P0035') THEN
            -- RETURN err_msg;
            RETURN jsonb_build_object(
                'status', 'warning',
                'message', err_msg
            );
        END IF;

        -- Generic fallback logging
        SELECT internal.log_error_wrapper(
                       err_code,
                       err_msg,
                       'public.create_prospectus',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        -- RETURN concat('Something went wrong. ', error_code);
        RETURN jsonb_build_object(
            'status', 'error',
            'message', concat('Something went wrong. ', error_code)
        );

END;
$$;
REVOKE ALL ON FUNCTION public.create_prospectus(
    IN p_special_id TEXT,
    IN p_year INTEGER,
    IN p_semesters_and_duration JSONB,
    IN p_classifications_and_units JSONB,
    IN p_courses_and_classification_units JSONB
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_prospectus(
    IN p_special_id TEXT,
    IN p_year INTEGER,
    IN p_semesters_and_duration JSONB,
    IN p_classifications_and_units JSONB,
    IN p_courses_and_classification_units JSONB
) TO authenticated;


---- 2.3.1 Get all semesters

CREATE OR REPLACE FUNCTION public.get_semesters()
RETURNS TABLE(id TEXT, name TEXT)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    error_code TEXT;
    err_code TEXT;
    err_msg TEXT;
BEGIN
    RETURN QUERY
    SELECT * FROM internal.get_semesters();
EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
        IF err_code IN ('P0015') THEN
            RETURN QUERY
            SELECT '*'::TEXT, '*'::TEXT;

        END IF;

        -- Generic fallback logging
        SELECT internal.log_error_wrapper(
                       err_code,
                       err_msg,
                       'public.get_semesters',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        RETURN QUERY
        --SELECT 'X'::TEXT, concat('Something went wrong. ', error_code)::TEXT;
        SELECT '*'::TEXT, '*'::TEXT;

END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION public.get_semesters() FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION public.get_semesters() TO authenticated;

---- 2.3.2 Get all classifications

CREATE OR REPLACE FUNCTION public.get_classifications()
RETURNS TABLE(id TEXT, name TEXT)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    error_code TEXT;
    err_code TEXT;
    err_msg TEXT;
BEGIN
    RETURN QUERY
    SELECT * FROM internal.get_classifications();
EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
        IF err_code IN ('P0015') THEN
            RETURN QUERY
            SELECT '*'::TEXT, '*'::TEXT;
        END IF;

        -- Generic fallback logging
        SELECT internal.log_error_wrapper(
                       err_code,
                       err_msg,
                       'public.get_classifications',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        RETURN QUERY
        --SELECT 'X'::TEXT, concat('Something went wrong. ', error_code)::TEXT;
        SELECT '*'::TEXT, '*'::TEXT;


END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION public.get_classifications() FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION public.get_classifications() TO authenticated;

---- 2.3.3 Get all courses

CREATE OR REPLACE FUNCTION public.get_courses()
RETURNS TABLE(id TEXT, name TEXT, unit TEXT)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    error_code TEXT;
    err_code TEXT;
    err_msg TEXT;
BEGIN
    RETURN QUERY
    SELECT * FROM internal.get_courses();
EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
        IF err_code IN ('P0015') THEN
            RETURN QUERY
            SELECT '*'::TEXT, '*'::TEXT, '*'::TEXT;
        END IF;

        -- Generic fallback logging
        SELECT internal.log_error_wrapper(
                       err_code,
                       err_msg,
                       'public.get_courses',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        RETURN QUERY
        --SELECT 'X'::TEXT, concat('Something went wrong. ', error_code)::TEXT;
        SELECT '*'::TEXT, '*'::TEXT, '*'::TEXT;
END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION public.get_courses() FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION public.get_courses() TO authenticated;

---- 2.3.4 Get all years

CREATE OR REPLACE FUNCTION public.get_years()
RETURNS TABLE(id TEXT, name TEXT)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    error_code TEXT;
    err_code TEXT;
    err_msg TEXT;
BEGIN
    RETURN QUERY
    SELECT * FROM internal.get_years();
EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
        IF err_code IN ('P0015') THEN
            RETURN QUERY
            SELECT '*'::TEXT, '*'::TEXT;

        END IF;

        -- Generic fallback logging
        SELECT internal.log_error_wrapper(
                       err_code,
                       err_msg,
                       'public.get_years',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        RETURN QUERY
        --SELECT 'X'::TEXT, concat('Something went wrong. ', error_code)::TEXT;
        SELECT '*'::TEXT, '*'::TEXT;

END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION public.get_years() FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION public.get_years() TO authenticated;



--//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

--- 2.4  Update Prospectus


---- 2.4.1 Update the Effective Period

CREATE OR REPLACE FUNCTION public.update_pps_year(
    IN p_prospectus_id TEXT,
    IN p_new_year INTEGER
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    error_code TEXT;
    err_code TEXT;
    err_msg TEXT;
BEGIN
    -- Main procedure call
    CALL internal.update_pps_year(
    p_prospectus_id,
    p_new_year
);

    -- RETURN '✅ Prospectus''s effective period updated successfully.';
    RETURN jsonb_build_object(
        'status', 'success',
        'message', '✅ Prospectus''s year updated successfully.'
    );

EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
        IF err_code IN ('P0010','P0035') THEN
            -- RETURN err_msg;
            RETURN jsonb_build_object(
                'status', 'warning',
                'message', err_msg
            );
        END IF;

        -- Generic fallback logging
        SELECT internal.log_error_wrapper(
                       err_code,
                       err_msg,
                       'public.update_pps_year',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        -- RETURN concat('Something went wrong. ', error_code);
        RETURN jsonb_build_object(
            'status', 'error',
            'message', concat('Something went wrong. ', error_code)
        );

END;
$$;
REVOKE ALL ON FUNCTION public.update_pps_year(
    IN p_prospectus_id TEXT,
    IN p_new_year INTEGER
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.update_pps_year(
    IN p_prospectus_id TEXT,
    IN p_new_year INTEGER
) TO authenticated;

------------------------------------------------------------------------------------------------------------------------

----- 2.4.2 View prospectus's Semester

CREATE OR REPLACE FUNCTION public.view_pps_semesters(IN p_prospectus_id TEXT)
RETURNS TABLE(id TEXT, name TEXT, year TEXT, duration TEXT)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    error_code TEXT;
    err_code TEXT;
    err_msg TEXT;
BEGIN
    RETURN QUERY
    SELECT * FROM internal.view_pps_semesters(p_prospectus_id);
EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
        IF err_code IN ('P0015') THEN
            RETURN QUERY
            SELECT '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT;
        END IF;

        -- Generic fallback logging
        SELECT internal.log_error_wrapper(
                       err_code,
                       err_msg,
                       'public.view_pps_semesters',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        RETURN QUERY
        --SELECT 'X'::TEXT, concat('Something went wrong. ', error_code)::TEXT;
        SELECT '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT;
END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION public.view_pps_semesters(IN p_prospectus_id TEXT) FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION public.view_pps_semesters(IN p_prospectus_id TEXT) TO authenticated;

----- 2.4.2.1 Update Prospectus's Semester

CREATE OR REPLACE FUNCTION public.update_pps_semester(
    IN p_pps_sem_id TEXT,
    IN p_new_starting DATE,
    IN p_new_ending DATE,
    IN p_new_sem_year_id JSONB -- incase they wanna change the semester of this row (optional)
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    error_code TEXT;
    err_code TEXT;
    err_msg TEXT;
BEGIN
    -- Main procedure call
    CALL internal.update_pps_semester(
            p_pps_sem_id,
            p_new_starting,
            p_new_ending,
         p_new_sem_year_id
    );

    -- RETURN '✅ Semester updated successfully.';
    RETURN jsonb_build_object(
        'status', 'success',
        'message', '✅ Semester updated successfully.'
    );

EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
        IF err_code IN ('P0010','P0035','P0029','P0028','P0034','P0027') THEN
            -- RETURN err_msg;
            RETURN jsonb_build_object(
                'status', 'warning',
                'message', err_msg
            );
        END IF;

        -- Generic fallback logging
        SELECT internal.log_error_wrapper(
                       err_code,
                       err_msg,
                       'public.update_pps_semester',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        -- RETURN concat('Something went wrong. ', error_code);
        RETURN jsonb_build_object(
            'status', 'error',
            'message', concat('Something went wrong. ', error_code)
        );

END;
$$;
REVOKE ALL ON FUNCTION public.update_pps_semester(
    IN p_pps_sem_id TEXT,
    IN p_new_starting DATE,
    IN p_new_ending DATE,
    IN p_new_sem_year_id JSONB -- incase they wanna change the semester of this row (optional)
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.update_pps_semester(
    IN p_pps_sem_id TEXT,
    IN p_new_starting DATE,
    IN p_new_ending DATE,
    IN p_new_sem_year_id JSONB -- incase they wanna change the semester of this row (optional)
)TO authenticated;

----- 2.4.2.2 Add Prospectus's Semester

CREATE OR REPLACE FUNCTION public.add_pps_semester(
    IN p_prospectus_id TEXT,
    IN p_sem_id TEXT,
    IN p_year_id TEXT,
    IN p_starting DATE,
    IN p_ending DATE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    error_code TEXT;
    err_code TEXT;
    err_msg TEXT;
BEGIN
    -- Main procedure call
    CALL internal.add_pps_semester(
            p_prospectus_id,
            p_sem_id,
            p_year_id,
            p_starting,
            p_ending
    );

    -- RETURN '✅ Semester added successfully.';
    RETURN jsonb_build_object(
        'status', 'success',
        'message', '✅ Semester added successfully.'
    );

EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
        IF err_code IN ('P0010','P0035','P0029','P0028','P0034','P0027') THEN
            -- RETURN err_msg;
            RETURN jsonb_build_object(
                'status', 'warning',
                'message', err_msg
            );
        END IF;

        -- Generic fallback logging
        SELECT internal.log_error_wrapper(
                       err_code,
                       err_msg,
                       'public.add_pps_semester',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        -- RETURN concat('Something went wrong. ', error_code);
        RETURN jsonb_build_object(
                'status', 'error',
                'message', concat('Something went wrong. ', error_code)
            );

END;
$$;
REVOKE ALL ON FUNCTION public.add_pps_semester(
    IN p_prospectus_id TEXT,
    IN p_sem_id TEXT,
    IN p_year_id TEXT,
    IN p_starting DATE,
    IN p_ending DATE
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.add_pps_semester(
    IN p_prospectus_id TEXT,
    IN p_sem_id TEXT,
    IN p_year_id TEXT,
    IN p_starting DATE,
    IN p_ending DATE
) TO authenticated;

----- 2.4.2.3 Delete Prospectus's Semester

CREATE OR REPLACE FUNCTION public.delete_pps_semester(
    IN p_pps_sem_id TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    error_code TEXT;
    err_code TEXT;
    err_msg TEXT;
BEGIN
    -- Main procedure call
    CALL internal.delete_pps_semester(
            p_pps_sem_id
    );

    -- RETURN '✅ Semester deleted successfully.';
    RETURN jsonb_build_object(
        'status', 'success',
        'message', '✅ Semester deleted successfully.'
    );

EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
        IF err_code IN ('P0010','P0036') THEN
            -- RETURN err_msg;
            RETURN jsonb_build_object(
                'status', 'success',
                'message', err_msg
            );
        END IF;

        -- Generic fallback logging
        SELECT internal.log_error_wrapper(
                       err_code,
                       err_msg,
                       'public.delete_pps_semester',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        -- RETURN concat('Something went wrong. ', error_code);
        RETURN jsonb_build_object(
                'status', 'success',
                'message', concat('Something went wrong. ', error_code)
            );

END;
$$;
REVOKE ALL ON FUNCTION public.delete_pps_semester(IN p_pps_sem_id TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.delete_pps_semester(IN p_pps_sem_id TEXT) TO authenticated;



------------------------------------------------------------------------------------------------------------------------

----- 2.4.3 View prospectus's Classifications

CREATE OR REPLACE FUNCTION public.view_pps_classifications(IN p_prospectus_id TEXT)
RETURNS TABLE(id TEXT, name TEXT, units TEXT)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    error_code TEXT;
    err_code TEXT;
    err_msg TEXT;
BEGIN
    RETURN QUERY
    SELECT * FROM internal.view_pps_classifications(p_prospectus_id);
EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
        IF err_code IN ('P0015') THEN
            RETURN QUERY
            SELECT '*'::TEXT, '*'::TEXT, '*'::TEXT;
        END IF;

        -- Generic fallback logging
        SELECT internal.log_error_wrapper(
                       err_code,
                       err_msg,
                       'public.view_pps_classifications',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        RETURN QUERY
        --SELECT 'X'::TEXT, concat('Something went wrong. ', error_code)::TEXT;
        SELECT '*'::TEXT, '*'::TEXT, '*'::TEXT;
END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION public.view_pps_classifications(IN p_prospectus_id TEXT) FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION public.view_pps_classifications(IN p_prospectus_id TEXT) TO authenticated;


----- 2.4.3.1 Update Prospectus's Classifications and corresponding required units

CREATE OR REPLACE FUNCTION public.update_pps_classification(
    IN p_pps_cu_id TEXT,
    IN p_new_unit NUMERIC(4,2),
    IN p_new_class_id TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    error_code TEXT;
    err_code TEXT;
    err_msg TEXT;
BEGIN
    -- Main procedure call
    CALL internal.update_pps_classification(
            p_pps_cu_id,
            p_new_unit,
            p_new_class_id
    );

    -- RETURN '✅ Semester updated successfully.';
    RETURN jsonb_build_object(
        'status', 'success',
        'message', '✅ Classification updated successfully.'
    );

EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
        IF err_code IN ('P0010','P0035','P0030') THEN
            -- RETURN err_msg;
            RETURN jsonb_build_object(
                'status', 'warning',
                'message', err_msg
            );
        END IF;

        -- Generic fallback logging
        SELECT internal.log_error_wrapper(
                       err_code,
                       err_msg,
                       'public.update_pps_classification',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        -- RETURN concat('Something went wrong. ', error_code);
        RETURN jsonb_build_object(
            'status', 'error',
            'message', concat('Something went wrong. ', error_code)
        );

END;
$$;
REVOKE ALL ON FUNCTION public.update_pps_classification(
    IN p_pps_cu_id TEXT,
    IN p_new_unit NUMERIC(4,2),
    IN p_new_class_id TEXT
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.update_pps_classification(
    IN p_pps_cu_id TEXT,
    IN p_new_unit NUMERIC(4,2),
    IN p_new_class_id TEXT
) TO authenticated;

----- 2.4.3.2 Add Prospectus's Classifications and corresponding required units

CREATE OR REPLACE FUNCTION public.add_pps_classification(
    IN p_prospectus_id TEXT,
    IN p_class_id TEXT,
    IN p_units NUMERIC(4,2)
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    error_code TEXT;
    err_code TEXT;
    err_msg TEXT;
BEGIN
    -- Main procedure call
    CALL internal.add_pps_classification(
            p_prospectus_id,
            p_class_id,
            p_units
    );

    -- RETURN '✅ Semester added successfully.';
    RETURN jsonb_build_object(
        'status', 'success',
        'message', '✅ Classification added successfully.'
    );

EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
        IF err_code IN ('P0010','P0035','P0030') THEN
            -- RETURN err_msg;
            RETURN jsonb_build_object(
                'status', 'warning',
                'message', err_msg
            );
        END IF;

        -- Generic fallback logging
        SELECT internal.log_error_wrapper(
                       err_code,
                       err_msg,
                       'public.add_pps_classification',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        -- RETURN concat('Something went wrong. ', error_code);
        RETURN jsonb_build_object(
                'status', 'error',
                'message', concat('Something went wrong. ', error_code)
            );

END;
$$;
REVOKE ALL ON FUNCTION public.add_pps_classification(
    IN p_prospectus_id TEXT,
    IN p_class_id TEXT,
    IN p_units NUMERIC(4,2)
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.add_pps_classification(
    IN p_prospectus_id TEXT,
    IN p_class_id TEXT,
    IN p_units NUMERIC(4,2)
) TO authenticated;

----- 2.4.3.3 Delete Prospectus's Classfication

CREATE OR REPLACE FUNCTION public.delete_pps_classification(IN p_pps_cu_id TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    error_code TEXT;
    err_code TEXT;
    err_msg TEXT;
BEGIN
    -- Main procedure call
    CALL internal.delete_pps_classification(
            p_pps_cu_id
    );

    -- RETURN '✅ Semester deleted successfully.';
    RETURN jsonb_build_object(
        'status', 'success',
        'message', '✅ Classification deleted successfully.'
    );

EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
        IF err_code IN ('P0010','P0036') THEN
            -- RETURN err_msg;
            RETURN jsonb_build_object(
                'status', 'warning',
                'message', err_msg
            );
        END IF;

        -- Generic fallback logging
        SELECT internal.log_error_wrapper(
                       err_code,
                       err_msg,
                       'public.delete_pps_classification',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        -- RETURN concat('Something went wrong. ', error_code);
        RETURN jsonb_build_object(
                'status', 'error',
                'message', concat('Something went wrong. ', error_code)
            );

END;
$$;
REVOKE ALL ON FUNCTION public.delete_pps_classification(IN p_pps_cu_id TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.delete_pps_classification(IN p_pps_cu_id TEXT) TO authenticated;


------------------------------------------------------------------------------------------------------------------------

----- 2.4.4 View prospectus's Courses

CREATE OR REPLACE FUNCTION public.view_pps_courses(IN p_prospectus_id TEXT)
RETURNS TABLE(id TEXT, code TEXT, name TEXT, classification TEXT)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    error_code TEXT;
    err_code TEXT;
    err_msg TEXT;
BEGIN
    RETURN QUERY
    SELECT * FROM internal.view_pps_courses(p_prospectus_id);
EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
        IF err_code IN ('P0015') THEN
            RETURN QUERY
            SELECT '*'::TEXT, '*'::TEXT, '*'::TEXT;
        END IF;

        -- Generic fallback logging
        SELECT internal.log_error_wrapper(
                       err_code,
                       err_msg,
                       'public.view_pps_courses',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        RETURN QUERY
        --SELECT 'X'::TEXT, concat('Something went wrong. ', error_code)::TEXT;
        SELECT '*'::TEXT, '*'::TEXT, '*'::TEXT;
END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION public.view_pps_courses(IN p_prospectus_id TEXT) FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION public.view_pps_courses(IN p_prospectus_id TEXT) TO authenticated;


----- 2.4.4.1 Update Prospectus's Courses

CREATE OR REPLACE FUNCTION public.update_pps_course(
    IN p_pps_pc_id TEXT,
    IN p_new_class_id TEXT,
    IN p_new_crs_code TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    error_code TEXT;
    err_code TEXT;
    err_msg TEXT;
BEGIN
    -- Main procedure call
    CALL internal.update_pps_course(
            p_pps_pc_id,
         p_new_class_id,
         p_new_crs_code

    );

    -- RETURN '✅ Semester updated successfully.';
    RETURN jsonb_build_object(
        'status', 'success',
        'message', '✅ Course updated successfully.'
    );

EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
        IF err_code IN ('P0010','P0035') THEN
            -- RETURN err_msg;
            RETURN jsonb_build_object(
                'status', 'warning',
                'message', err_msg
            );
        END IF;

        -- Generic fallback logging
        SELECT internal.log_error_wrapper(
                       err_code,
                       err_msg,
                       'public.update_pps_course',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        -- RETURN concat('Something went wrong. ', error_code);
        RETURN jsonb_build_object(
            'status', 'error',
            'message', concat('Something went wrong. ', error_code)
        );

END;
$$;
REVOKE ALL ON FUNCTION public.update_pps_course(
    IN p_pps_pc_id TEXT,
    IN p_new_class_id TEXT,
    IN p_new_crs_code TEXT
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.update_pps_course(
    IN p_pps_pc_id TEXT,
    IN p_new_class_id TEXT,
    IN p_new_crs_code TEXT
) TO authenticated;

----- 2.4.4.2 Add Prospectus's Course

CREATE OR REPLACE FUNCTION public.add_pps_course(
    IN p_prospectus_id TEXT,
    IN p_crs_id TEXT,
    IN p_class_id TEXT,
    IN p_crs_code TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    error_code TEXT;
    err_code TEXT;
    err_msg TEXT;
BEGIN
    -- Main procedure call
    CALL internal.add_pps_course(
            p_prospectus_id,
            p_crs_id,
            p_class_id,
         p_crs_code
    );

    -- RETURN '✅ Semester added successfully.';
    RETURN jsonb_build_object(
        'status', 'success',
        'message', '✅ Course added successfully.'
    );

EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
        IF err_code IN ('P0010','P0035','P0031','P0032') THEN
            -- RETURN err_msg;
            RETURN jsonb_build_object(
                'status', 'warning',
                'message', err_msg
            );
        END IF;

        -- Generic fallback logging
        SELECT internal.log_error_wrapper(
                       err_code,
                       err_msg,
                       'public.add_pps_course',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        -- RETURN concat('Something went wrong. ', error_code);
        RETURN jsonb_build_object(
                'status', 'error',
                'message', concat('Something went wrong. ', error_code)
            );

END;
$$;
REVOKE ALL ON FUNCTION public.add_pps_course(
    IN p_prospectus_id TEXT,
    IN p_crs_id TEXT,
    IN p_class_id TEXT,
    IN p_crs_code TEXT
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.add_pps_course(
    IN p_prospectus_id TEXT,
    IN p_crs_id TEXT,
    IN p_class_id TEXT,
    IN p_crs_code TEXT
) TO authenticated;

----- 2.4.4.3 Delete Prospectus's Course

CREATE OR REPLACE FUNCTION public.delete_pps_course(IN p_pps_pc_id TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    error_code TEXT;
    err_code TEXT;
    err_msg TEXT;
BEGIN
    -- Main procedure call
    CALL internal.delete_pps_course(
            p_pps_pc_id
    );

    -- RETURN '✅ Semester deleted successfully.';
    RETURN jsonb_build_object(
        'status', 'success',
        'message', '✅ Course removed successfully.'
    );

EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
        IF err_code IN ('P0010','P0036') THEN
            -- RETURN err_msg;
            RETURN jsonb_build_object(
                'status', 'warning',
                'message', err_msg
            );
        END IF;

        -- Generic fallback logging
        SELECT internal.log_error_wrapper(
                       err_code,
                       err_msg,
                       'public.delete_pps_course',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        -- RETURN concat('Something went wrong. ', error_code);
        RETURN jsonb_build_object(
                'status', 'error',
                'message', concat('Something went wrong. ', error_code)
            );

END;
$$;
REVOKE ALL ON FUNCTION public.delete_pps_course(IN p_pps_pc_id TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.delete_pps_course(IN p_pps_pc_id TEXT) TO authenticated;










-- 3. Manage Courses


--- 3.1 Create course

CREATE OR REPLACE FUNCTION public.create_course(
    IN p_course_title TEXT,
    IN p_units NUMERIC(4,2),
    IN p_certification_ids TEXT[]
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    error_code TEXT;
    err_code TEXT;
    err_msg TEXT;
BEGIN
    -- Main procedure call
    CALL internal.create_course(
            p_course_title,
            p_units,
            p_certification_ids
    );

    -- RETURN '✅ Course successfully created.';
    RETURN jsonb_build_object(
        'status', 'success',
        'message', '✅ Course successfully created.'
    );

EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
        IF err_code IN ('P0010','P0033') THEN
            -- RETURN err_msg;
            RETURN jsonb_build_object(
                'status', 'warning',
                'message', err_msg
            );
        END IF;

        -- Generic fallback logging
        SELECT internal.log_error_wrapper(
                       err_code,
                       err_msg,
                       'public.create_course',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        -- RETURN concat('Something went wrong. ', error_code);
        RETURN jsonb_build_object(
            'status', 'error',
            'message', concat('Something went wrong. ', error_code)
        );

END;
$$;
REVOKE ALL ON FUNCTION public.create_course(
    IN p_course_title TEXT,
    IN p_units NUMERIC(4,2),
    IN p_certification_ids TEXT[]
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_course(
    IN p_course_title TEXT,
    IN p_units NUMERIC(4,2),
    IN p_certification_ids TEXT[]
) TO authenticated;


-- ///////        from here onwards it is the dean's job to make a scheduling for the courses in a prospectus)     //////

--- 3.2 View all Courses in the Prospectus

CREATE OR REPLACE FUNCTION public.select_prospectus(IN p_prospectus_id TEXT)
RETURNS TABLE(
    id TEXT,
    code TEXT,
    room TEXT,
    name TEXT,
    units TEXT,
    classification TEXT,
    term TEXT,
    term_duration text,
    day TEXT,
    schedule TEXT,
    faculty TEXT,
    status TEXT
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    error_code TEXT;
    err_code TEXT;
    err_msg TEXT;
BEGIN
    RETURN QUERY
    SELECT * FROM internal.select_prospectus(p_prospectus_id);
EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
        IF err_code IN ('P0015') THEN
            RETURN QUERY
            SELECT '*'::TEXT, '*'::TEXT , '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT;

        END IF;

        -- Generic fallback logging
        SELECT internal.log_error_wrapper(
                       err_code,
                       err_msg,
                       'public.select_prospectus',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        RETURN QUERY
        --SELECT 'X'::TEXT, concat('Something went wrong. ', error_code)::TEXT;
        SELECT '*'::TEXT, '*'::TEXT , '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT;

END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION public.select_prospectus(IN p_prospectus_id TEXT) FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION public.select_prospectus(IN p_prospectus_id TEXT) TO authenticated;


--- 3.3 create a scheduling //a prospectus course cant have a scheduling if it isnt assigned to any semester yet

CREATE OR REPLACE FUNCTION public.create_schedule(
    IN p_pc_id TEXT,
    IN p_prosem_id TEXT,
--     IN p_room_id TEXT,
    IN p_schedule JSONB,
    IN p_faculty TEXT[]
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    error_code TEXT;
    err_code TEXT;
    err_msg TEXT;
    result JSONB;
BEGIN
    -- Main procedure call
    result := internal.create_schedule(p_pc_id,p_prosem_id,null,p_schedule,p_faculty);

    -- RETURN '✅ Semester deleted successfully.';
    RETURN jsonb_build_object(
        'status', 'success',
        'message', result
    );

EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
        IF err_code IN ('P0010','P0035') THEN
            -- RETURN err_msg;
            RETURN jsonb_build_object(
                'status', 'warning',
                'message', err_msg
            );
        END IF;

        -- Generic fallback logging
        SELECT internal.log_error_wrapper(
                       err_code,
                       err_msg,
                       'public.create_schedule',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        -- RETURN concat('Something went wrong. ', error_code);
        RETURN jsonb_build_object(
                'status', 'error',
                'message', concat('Something went wrong. ', error_code)
            );

END;
$$;
REVOKE ALL ON FUNCTION public.create_schedule(
    IN p_pc_id TEXT,
    IN p_prosem_id TEXT,
--     IN p_room_id TEXT,
    IN p_schedule JSONB,
    IN p_faculty TEXT[]
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_schedule(
    IN p_pc_id TEXT,
    IN p_prosem_id TEXT,
--     IN p_room_id TEXT,
    IN p_schedule JSONB,
    IN p_faculty TEXT[]
) TO authenticated;

--- 3.3 confirm create schedule

CREATE OR REPLACE FUNCTION public.confirm_create_schedule(IN p_response_id TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    error_code TEXT;
    err_code TEXT;
    err_msg TEXT;
BEGIN
    -- Main procedure call
    CALL internal.confirm_create_schedule(p_response_id);

    -- RETURN '✅ Semester deleted successfully.';
    RETURN jsonb_build_object(
        'status', 'success',
        'message', '✅ Schedule created successfully.'
    );

EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
        IF err_code IN ('P0010','P0035', 'P0044', 'P0042', 'P0037', 'P0034', 'P0038') THEN
            -- RETURN err_msg;
            RETURN jsonb_build_object(
                'status', 'warning',
                'message', err_msg
            );
        END IF;

        -- Generic fallback logging
        SELECT internal.log_error_wrapper(
                       err_code,
                       err_msg,
                       'public.confirm_create_schedule',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        -- RETURN concat('Something went wrong. ', error_code);
        RETURN jsonb_build_object(
                'status', 'error',
                'message', concat('Something went wrong. ', error_code)
            );

END;
$$;
REVOKE ALL ON FUNCTION public.confirm_create_schedule(IN p_response_id TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.confirm_create_schedule(IN p_response_id TEXT) TO authenticated;


--- 3.3.1 get faculties (will be used in assigning faculty in a course)

CREATE OR REPLACE FUNCTION public.get_faculties()
RETURNS TABLE(id TEXT, name TEXT, current_load TEXT, maximum_load TEXT, email TEXT)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    error_code TEXT;
    err_code TEXT;
    err_msg TEXT;
BEGIN
    RETURN QUERY
    SELECT * FROM internal.get_faculties();
EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
        IF err_code IN ('P0015') THEN
            RETURN QUERY
            SELECT '*'::TEXT, '*'::TEXT , '*'::TEXT, '*'::TEXT, '*'::TEXT;

        END IF;

        -- Generic fallback logging
        SELECT internal.log_error_wrapper(
                       err_code,
                       err_msg,
                       'public.get_faculties',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        RETURN QUERY
        --SELECT 'X'::TEXT, concat('Something went wrong. ', error_code)::TEXT;
        SELECT '*'::TEXT, '*'::TEXT , '*'::TEXT, '*'::TEXT, '*'::TEXT;
END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION public.get_faculties() FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION public.get_faculties() TO authenticated;

--- 3.3.2 get Days for the scheduling

CREATE OR REPLACE FUNCTION public.get_days()
RETURNS TABLE(id TEXT, name TEXT)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    error_code TEXT;
    err_code TEXT;
    err_msg TEXT;
BEGIN
    RETURN QUERY
    SELECT * FROM internal.get_days();
EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
        IF err_code IN ('P0015') THEN
            RETURN QUERY
            SELECT '*'::TEXT, '*'::TEXT;
        END IF;

        -- Generic fallback logging
        SELECT internal.log_error_wrapper(
                       err_code,
                       err_msg,
                       'public.get_days',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        RETURN QUERY
        --SELECT 'X'::TEXT, concat('Something went wrong. ', error_code)::TEXT;
        SELECT '*'::TEXT, '*'::TEXT;
END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION public.get_days() FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION public.get_days() TO authenticated;

--- 3.3.2 get rooms

CREATE OR REPLACE FUNCTION public.get_rooms()
RETURNS TABLE(id TEXT, name TEXT)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    error_code TEXT;
    err_code TEXT;
    err_msg TEXT;
BEGIN
    RETURN QUERY
    SELECT * FROM internal.get_rooms();
EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
        IF err_code IN ('P0015') THEN
            RETURN QUERY
            SELECT '*'::TEXT, '*'::TEXT;
        END IF;

        -- Generic fallback logging
        SELECT internal.log_error_wrapper(
                       err_code,
                       err_msg,
                       'public.get_rooms',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        RETURN QUERY
        --SELECT 'X'::TEXT, concat('Something went wrong. ', error_code)::TEXT;
        SELECT '*'::TEXT, '*'::TEXT;
END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION public.get_rooms() FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION public.get_rooms() TO authenticated;


--- 3.3.3 Create Room

CREATE OR REPLACE FUNCTION public.create_room(IN p_room_code TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    error_code TEXT;
    err_code TEXT;
    err_msg TEXT;
BEGIN
    -- Main procedure call
    CALL internal.create_room(p_room_code);

    -- RETURN '✅ Semester deleted successfully.';
    RETURN jsonb_build_object(
        'status', 'success',
        'message', '✅ Room created successfully.'
    );

EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
        IF err_code IN ('P0010','P0035') THEN
            -- RETURN err_msg;
            RETURN jsonb_build_object(
                'status', 'warning',
                'message', err_msg
            );
        END IF;

        -- Generic fallback logging
        SELECT internal.log_error_wrapper(
                       err_code,
                       err_msg,
                       'public.create_room',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        -- RETURN concat('Something went wrong. ', error_code);
        RETURN jsonb_build_object(
                'status', 'error',
                'message', concat('Something went wrong. ', error_code)
            );

END;
$$;
REVOKE ALL ON FUNCTION public.create_room(IN p_room_code TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_room(IN p_room_code TEXT) TO authenticated;

--- 3.3.4 Update Schedule

CREATE OR REPLACE FUNCTION public.update_schedule(
    IN p_pc_id TEXT,
    IN p_prosem_id TEXT,
--     IN p_room_id TEXT,
    IN p_schedule JSONB,
    IN p_faculty TEXT[]
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    error_code TEXT;
    err_code TEXT;
    err_msg TEXT;
    result JSONB;
BEGIN
    -- Main procedure call
    result := internal.update_schedule(p_pc_id,p_prosem_id,null,p_schedule,p_faculty);

    -- RETURN '✅ Semester deleted successfully.';
    RETURN jsonb_build_object(
        'status', 'success',
        'message', result
    );

EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
        IF err_code IN ('P0010','P0035') THEN
            -- RETURN err_msg;
            RETURN jsonb_build_object(
                'status', 'warning',
                'message', err_msg
            );
        END IF;

        -- Generic fallback logging
        SELECT internal.log_error_wrapper(
                       err_code,
                       err_msg,
                       'public.update_schedule',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        -- RETURN concat('Something went wrong. ', error_code);
        RETURN jsonb_build_object(
                'status', 'error',
                'message', concat('Something went wrong. ', error_code)
            );

END;
$$;
REVOKE ALL ON FUNCTION public.update_schedule(
    IN p_pc_id TEXT,
    IN p_prosem_id TEXT,
--     IN p_room_id TEXT,
    IN p_schedule JSONB,
    IN p_faculty TEXT[]
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.update_schedule(
    IN p_pc_id TEXT,
    IN p_prosem_id TEXT,
--     IN p_room_id TEXT,
    IN p_schedule JSONB,
    IN p_faculty TEXT[] -- optional
) TO authenticated;

--- 3.3.4.2 Confirm Update Schedule

CREATE OR REPLACE FUNCTION public.confirm_update_schedule(IN p_response_id TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    error_code TEXT;
    err_code TEXT;
    err_msg TEXT;
BEGIN
    -- Main procedure call
    CALL internal.confirm_update_schedule(p_response_id);

    -- RETURN '✅ Semester deleted successfully.';
    RETURN jsonb_build_object(
        'status', 'success',
        'message', '✅ Schedule updated successfully.'
    );

EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
        IF err_code IN ('P0010','P0035', 'P0044', 'P0042', 'P0037', 'P0034', 'P0038','P0027') THEN
            -- RETURN err_msg;
            RETURN jsonb_build_object(
                'status', 'warning',
                'message', err_msg
            );
        END IF;

        -- Generic fallback logging
        SELECT internal.log_error_wrapper(
                       err_code,
                       err_msg,
                       'public.confirm_update_schedule',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        -- RETURN concat('Something went wrong. ', error_code);
        RETURN jsonb_build_object(
                'status', 'error',
                'message', concat('Something went wrong. ', error_code)
            );

END;
$$;
REVOKE ALL ON FUNCTION public.confirm_update_schedule(IN p_response_id TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.confirm_update_schedule(IN p_response_id TEXT) TO authenticated;






--- 3.4.1 Enrollment -  Bulk enrollment of students for regulars

CREATE OR REPLACE FUNCTION public.bulk_enrollment_regular(
    IN p_course_ids TEXT[],
    IN p_student_list JSONB,
    IN p_official_list_file_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    error_code TEXT;
    err_code TEXT;
    err_msg TEXT;
BEGIN
    -- Main procedure call
    CALL internal.bulk_enrollment_regular(p_course_ids,p_student_list,p_official_list_file_id);

    -- RETURN '✅ Semester deleted successfully.';
    RETURN jsonb_build_object(
        'status', 'success',
        'message', '✅ Students enrolled successfully'
    );

EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;
        BEGIN
            call internal.file_rollback(p_official_list_file_id, 'enrollment-docs', 'official_list');
        EXCEPTION
            WHEN OTHERS THEN
                GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                         err_msg = MESSAGE_TEXT;
                -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
                IF err_code IN ('P0010') THEN
                    -- RETURN err_msg;
                    RETURN jsonb_build_object(
                        'status', 'warning',
                        'message', err_msg
                    );
                ELSE
                    -- Generic fallback logging
                    SELECT internal.log_error_wrapper(
                                   err_code,
                                   err_msg,
                                   'public.file_rollback',
                                   jsonb_build_object('sqlerrm', SQLERRM)
                           ) INTO error_code;

                    -- RETURN concat('Something went wrong. ', error_code);
                    RETURN jsonb_build_object(
                            'status', 'error',
                            'message', concat('Something went wrong. ', error_code)
                        );
                END IF;
        END;

        -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
        IF err_code IN ('P0010','P0035', 'P1000', 'P0041', 'P0055', 'P0014') THEN
            -- RETURN err_msg;
            RETURN jsonb_build_object(
                'status', 'warning',
                'message', err_msg
            );
        ELSE
            -- Generic fallback logging
            SELECT internal.log_error_wrapper(
                           err_code,
                           err_msg,
                           'public.bulk_enrollment_regular',
                           jsonb_build_object('sqlerrm', SQLERRM)
                   ) INTO error_code;

            -- RETURN concat('Something went wrong. ', error_code);
            RETURN jsonb_build_object(
                    'status', 'error',
                    'message', concat('Something went wrong. ', error_code)
                );
        END IF;

END;
$$;
REVOKE ALL ON FUNCTION public.bulk_enrollment_regular(
    IN p_course_ids TEXT[],
    IN p_student_list JSONB,
    IN p_official_list_file_id UUID
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.bulk_enrollment_regular(
    IN p_course_ids TEXT[],
    IN p_student_list JSONB,
    IN p_official_list_file_id UUID
) TO authenticated;


--- 3.4.1 Enrollment -  Bulk enrollment of students for regulars

CREATE OR REPLACE FUNCTION public.bulk_enrollment_regular(
    IN p_prospectus_id TEXT,
    IN p_student_list JSONB,
    IN p_official_list_file_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    error_code TEXT;
    err_code TEXT;
    err_msg TEXT;
BEGIN
    -- Main procedure call
    CALL internal.bulk_enrollment_regular(p_prospectus_id,p_student_list,p_official_list_file_id);

    -- RETURN '✅ Semester deleted successfully.';
    RETURN jsonb_build_object(
        'status', 'success',
        'message', '✅ Students enrolled successfully'
    );

EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;
        BEGIN
            call internal.file_rollback(p_official_list_file_id, 'enrollment-docs', 'official_list');
        EXCEPTION
            WHEN OTHERS THEN
                GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                         err_msg = MESSAGE_TEXT;
                -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
                IF err_code IN ('P0010','P0035', 'P0041', 'P0014') THEN
                    -- RETURN err_msg;
                    RETURN jsonb_build_object(
                        'status', 'warning',
                        'message', err_msg
                    );
                ELSE
                    -- Generic fallback logging
                    SELECT internal.log_error_wrapper(
                                   err_code,
                                   err_msg,
                                   'public.file_rollback',
                                   jsonb_build_object('sqlerrm', SQLERRM)
                           ) INTO error_code;

                    -- RETURN concat('Something went wrong. ', error_code);
                    RETURN jsonb_build_object(
                            'status', 'error',
                            'message', concat('Something went wrong. ', error_code)
                        );
                END IF;
        END;

        -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
        IF err_code IN ('P0010','P0035', 'P0041', 'P0014') THEN
            -- RETURN err_msg;
            RETURN jsonb_build_object(
                'status', 'warning',
                'message', err_msg
            );
        ELSE
            -- Generic fallback logging
            SELECT internal.log_error_wrapper(
                           err_code,
                           err_msg,
                           'public.bulk_enrollment',
                           jsonb_build_object('sqlerrm', SQLERRM)
                   ) INTO error_code;

            -- RETURN concat('Something went wrong. ', error_code);
            RETURN jsonb_build_object(
                    'status', 'error',
                    'message', concat('Something went wrong. ', error_code)
                );
        END IF;



END;
$$;
REVOKE ALL ON FUNCTION public.bulk_enrollment_regular(
    IN p_prospectus_id TEXT,
    IN p_student_list JSONB,
    IN p_official_list_file_id UUID
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.bulk_enrollment_regular(
    IN p_prospectus_id TEXT,
    IN p_student_list JSONB,
    IN p_official_list_file_id UUID
) TO authenticated;


--- 3.4.2 Enrollment -   Single Enrollment for irregular/Transferee using Proof of Credit

CREATE OR REPLACE FUNCTION public.transferee_enrollment(
    IN p_student_email TEXT,
    IN p_course_ids TEXT[],
    IN p_proof_of_credit_file_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    error_code TEXT;
    err_code TEXT;
    err_msg TEXT;
    err_code2 TEXT;
    err_msg2 TEXT;
BEGIN
    -- Main procedure call
    CALL internal.transferee_enrollment(p_student_email,p_course_ids,p_proof_of_credit_file_id);

    -- RETURN '✅ Semester deleted successfully.';
    RETURN jsonb_build_object(
        'status', 'success',
        'message', '✅ Student enrolled successfully'
    );

EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;
        BEGIN
            call internal.file_rollback(p_proof_of_credit_file_id, 'enrollment-docs', 'poc');
        EXCEPTION
            WHEN OTHERS THEN
                GET STACKED DIAGNOSTICS err_code2 = RETURNED_SQLSTATE,
                                         err_msg2 = MESSAGE_TEXT;
                -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
                IF err_code2 IN ('P0010') THEN
                    -- RETURN err_msg;
                    RETURN jsonb_build_object(
                        'status', 'warning',
                        'message', err_msg
                    );
                ELSE
                    -- Generic fallback logging
                    SELECT internal.log_error_wrapper(
                                   err_code2,
                                   err_msg2,
                                   'public.file_rollback',
                                   jsonb_build_object('sqlerrm', SQLERRM)
                           ) INTO error_code;

                    -- RETURN concat('Something went wrong. ', error_code);
                    RETURN jsonb_build_object(
                            'status', 'error',
                            'message', concat('Something went wrong. ', error_code)
                        );
                END IF;
        END;

        -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
        IF err_code IN ('P0010','P0035', 'P0041', 'P0014', 'P1000', 'P0035', 'P0056') THEN
            -- RETURN err_msg;
            RETURN jsonb_build_object(
                'status', 'warning',
                'message', err_msg
            );
        ELSE
            -- Generic fallback logging
            SELECT internal.log_error_wrapper(
                           err_code,
                           err_msg,
                           'public.transferee_enrollment',
                           jsonb_build_object('sqlerrm', SQLERRM)
                   ) INTO error_code;

            -- RETURN concat('Something went wrong. ', error_code);
            RETURN jsonb_build_object(
                    'status', 'error',
                    'message', concat('Something went wrong. ', error_code)
                );
        END IF;

END;
$$;
REVOKE ALL ON FUNCTION public.transferee_enrollment(
    IN p_student_email TEXT,
    IN p_course_ids TEXT[],
    IN p_proof_of_credit_file_id UUID
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.transferee_enrollment(
    IN p_student_email TEXT,
    IN p_course_ids TEXT[],
    IN p_proof_of_credit_file_id UUID
) TO authenticated;







--- 3.5 View enrolled students

CREATE OR REPLACE FUNCTION public.view_enrolled_students(IN p_version_id TEXT)
RETURNS TABLE(
    id TEXT,
    name TEXT,
    email TEXT,
    enrollment_status TEXT,
    learning_progress TEXT -- soon
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    error_code TEXT;
    err_code TEXT;
    err_msg TEXT;
BEGIN
    RETURN QUERY
    SELECT * FROM internal.view_enrolled_students(p_version_id);
EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
        IF err_code IN ('P0015') THEN
            RETURN QUERY
            SELECT '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT;
        END IF;

        -- Generic fallback logging
        SELECT internal.log_error_wrapper(
                       err_code,
                       err_msg,
                       'public.view_enrolled_students',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        RETURN QUERY
        --SELECT 'X'::TEXT, concat('Something went wrong. ', error_code)::TEXT;
        SELECT '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT;
END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION public.view_enrolled_students(IN p_version_id TEXT) FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION public.view_enrolled_students(IN p_version_id TEXT) TO authenticated;



-- 4.) DOWNLOAD PROSPECTUS

CREATE OR REPLACE FUNCTION public.get_prospectus_data(IN p_prospectus_id TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    error_code TEXT;
    err_code TEXT;
    err_msg TEXT;
    result JSONB;
BEGIN
    -- Call the internal implementation
    result := internal.get_prospectus_data( p_prospectus_id );

    RETURN jsonb_build_object(
                'status', 'success',
                'message', result
            );
EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
        IF err_code IN ('P0035') THEN
            -- RETURN err_msg;
            RETURN jsonb_build_object(
                'status', 'warning',
                'message', err_msg
            );
        END IF;

        -- Generic fallback logging
        SELECT internal.log_error_wrapper(
                       err_code,
                       err_msg,
                       'public.get_prospectus_data',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        -- RETURN concat('Something went wrong. ', error_code);
        RETURN jsonb_build_object(
                'status', 'error',
                'message', concat('Something went wrong. ', error_code)
            );

END;
$$;
REVOKE ALL ON FUNCTION public.get_prospectus_data(IN p_prospectus_id TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_prospectus_data(IN p_prospectus_id TEXT) TO authenticated;



-- 5.) APPROVE COURSE

CREATE OR REPLACE FUNCTION public.approve_course(IN p_pc_id TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    error_code TEXT;
    err_code TEXT;
    err_msg TEXT;
BEGIN
    -- Main procedure call
    CALL internal.approve_course(p_pc_id);

    -- RETURN '✅ Semester deleted successfully.';
    RETURN jsonb_build_object(
        'status', 'success',
        'message', '✅ Course approved and published.'
    );

EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
        IF err_code IN ('P0010','P0035', 'P0057', 'P0058', 'P0054') THEN
            -- RETURN err_msg;
            RETURN jsonb_build_object(
                'status', 'warning',
                'message', err_msg
            );
        ELSE
            -- Generic fallback logging
            SELECT internal.log_error_wrapper(
                           err_code,
                           err_msg,
                           'public.approve_course',
                           jsonb_build_object('sqlerrm', SQLERRM)
                   ) INTO error_code;

            -- RETURN concat('Something went wrong. ', error_code);
            RETURN jsonb_build_object(
                    'status', 'error',
                    'message', concat('Something went wrong. ', error_code)
                );
        END IF;

END;
$$;
REVOKE ALL ON FUNCTION public.approve_course(IN p_pc_id TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.approve_course(IN p_pc_id TEXT) TO authenticated;

-- 5.1) DISAPPROVE COURSE

CREATE OR REPLACE FUNCTION public.disapprove_course( IN p_pc_id TEXT, IN p_feedback TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    error_code TEXT;
    err_code TEXT;
    err_msg TEXT;
BEGIN
    -- Main procedure call
    CALL internal.disapprove_course( p_pc_id, p_feedback);

    -- RETURN '✅ Semester deleted successfully.';
    RETURN jsonb_build_object(
        'status', 'success',
        'message', '✅ Course disapproved.'
    );

EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
        IF err_code IN ('P0010','P0035', 'P0057', 'P0058', 'P0054') THEN
            -- RETURN err_msg;
            RETURN jsonb_build_object(
                'status', 'warning',
                'message', err_msg
            );
        ELSE
            -- Generic fallback logging
            SELECT internal.log_error_wrapper(
                           err_code,
                           err_msg,
                           'public.disapprove_course',
                           jsonb_build_object('sqlerrm', SQLERRM)
                   ) INTO error_code;

            -- RETURN concat('Something went wrong. ', error_code);
            RETURN jsonb_build_object(
                    'status', 'error',
                    'message', concat('Something went wrong. ', error_code)
                );
        END IF;

END;
$$;
REVOKE ALL ON FUNCTION public.disapprove_course( IN p_pc_id TEXT, IN p_feedback TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.disapprove_course( IN p_pc_id TEXT, IN p_feedback TEXT) TO authenticated;


