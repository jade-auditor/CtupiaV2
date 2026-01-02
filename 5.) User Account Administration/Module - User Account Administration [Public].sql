-----------------------------------------------------------------------------------------------
------------------------------- PUBLIC SCHEMA -------------------------------------------------

-- 1.1 VIEW ALL ROLES

CREATE OR REPLACE FUNCTION public.get_roles()
RETURNS TABLE(id TEXT, name TEXT)
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
    SELECT * FROM internal.get_roles();
EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
        IF err_code IN ('P0015') THEN
            RETURN QUERY
            -- SELECT 'X'::TEXT, err_msg::TEXT;
            SELECT '*'::TEXT, '*'::TEXT;
        END IF;

        -- Generic fallback logging
        SELECT internal.log_error_wrapper(
                       err_code,
                       err_msg,
                       'public.get_roles',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        RETURN QUERY
        --SELECT 'X'::TEXT, concat('Something went wrong. ', error_code)::TEXT;
        SELECT '*'::TEXT, '*'::TEXT;

END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION public.get_roles() FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION public.get_roles() TO authenticated;


-- 1.2 VIEW ALL COLLEGES AND OFFICES

CREATE OR REPLACE FUNCTION public.get_college_office()
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
    SELECT * FROM internal.get_college_office();
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
                       'public.get_college_office',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        RETURN QUERY
        --SELECT 'X'::TEXT, concat('Something went wrong. ', error_code)::TEXT;
        SELECT '*'::TEXT, '*'::TEXT;


END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION public.get_college_office() FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION public.get_college_office() TO authenticated;


-- set clause is implemented starting here
-- 1.3 VIEW ALL FACULTY RANKS

CREATE OR REPLACE FUNCTION public.get_faculty_ranks()
RETURNS TABLE(id TEXT, name TEXT, salary TEXT, rate TEXT, salary_grade TEXT)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    error_code TEXT;
    err_code TEXT;
    err_msg TEXT;
BEGIN
    RETURN QUERY
    SELECT * FROM internal.get_faculty_ranks();
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
                       'public.get_faculty_ranks',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        RETURN QUERY
        --SELECT 'X'::TEXT, concat('Something went wrong. ', error_code)::TEXT;
        SELECT '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT;

END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION public.get_faculty_ranks() FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION public.get_faculty_ranks() TO authenticated;


-- 1.4.  ADD/CREATE USER

CREATE OR REPLACE FUNCTION public.create_user_wrapper(
    p_email TEXT,
    p_auth_id UUID,
    p_dar_id TEXT,
    p_birth_date DATE,
    p_lname TEXT,
    p_fname TEXT,
    p_mname TEXT DEFAULT NULL,
    p_cao_id TEXT DEFAULT NULL,
    p_rank_id TEXT DEFAULT NULL,
    IN p_degree_id TEXT DEFAULT NULL,
    IN p_undergrad_load INT DEFAULT NULL
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
    CALL internal.create_user(
        p_lname,
        p_fname,
        p_birth_date,
        p_email,
        p_auth_id,
        p_dar_id,
        p_mname,
        p_cao_id,
        p_rank_id,
        p_degree_id,
        p_undergrad_load

    );

    RETURN jsonb_build_object(
        'status', 'success',
        'message', '✅ User account successfully created.'
    );

EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        BEGIN
            -- ROLL BACK THE ACCOUNT CREATED USING THEIR AUTH ID
            CALL internal.acc_rollback(p_auth_id, p_email);
        EXCEPTION
            WHEN OTHERS THEN
                GET STACKED DIAGNOSTICS err_code2 = RETURNED_SQLSTATE,
                                        err_msg2 = MESSAGE_TEXT;

            -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
            IF err_code2 IN ('P0010') THEN
                -- RETURN err_msg;
                RETURN jsonb_build_object(
                    'status', 'warning',
                    'message', err_msg2
                );
            END IF;

            -- Generic fallback logging
            SELECT internal.log_error_wrapper(
                           err_code,
                           err_msg,
                           'public.acc_rollback',
                           jsonb_build_object('sqlerrm', SQLERRM)
                   ) INTO error_code;

            -- RETURN concat('Something went wrong. ', error_code);
            RETURN jsonb_build_object(
                'status', 'error',
                'message', concat('Something went wrong. ', error_code)
            );
        END;


        -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
        IF err_code IN ('P0010', 'P0011', 'P0012', 'P0013') THEN
            -- RETURN err_msg;
            RETURN jsonb_build_object(
                    'status', 'warning',
                    'message', err_msg
                );
        END IF;

        -- Generic fallback logging
        SELECT internal.log_error_wrapper(
            err_code,
            encode(convert_to(coalesce(err_msg, ''), 'UTF8'), 'escape'),
            'public.create_user_wrapper',
            jsonb_build_object('sqlerrm', encode(convert_to(coalesce(SQLERRM, ''), 'UTF8'), 'escape'))
        ) INTO error_code;

        -- RETURN concat('Something went wrong. ', error_code);
        RETURN jsonb_build_object(
            'status', 'error',
            'message', concat('Something went wrong. ', error_code)
        );

END;
$$;
REVOKE ALL ON FUNCTION public.create_user_wrapper(
    p_email TEXT,
    p_auth_id UUID,
    p_dar_id TEXT,
    p_birth_date DATE,
    p_lname TEXT,
    p_fname TEXT,
    p_mname TEXT,
    p_cao_id TEXT,
    p_rank_id TEXT,
    IN p_degree_id TEXT,
    IN p_undergrad_load INT
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_user_wrapper(
    p_email TEXT,
    p_auth_id UUID,
    p_dar_id TEXT,
    p_birth_date DATE,
    p_lname TEXT,
    p_fname TEXT,
    p_mname TEXT,
    p_cao_id TEXT,
    p_rank_id TEXT,
    IN p_degree_id TEXT,
    IN p_undergrad_load INT
) TO authenticated;


-- 2. View Users Account

CREATE OR REPLACE FUNCTION public.get_users()
RETURNS TABLE (
    id TEXT,
    profile_name TEXT,
    lname TEXT,
    fname TEXT,
    mname TEXT,
    birth_date TEXT,
    email TEXT,
    phone TEXT,
    bio TEXT,
    degree TEXT,
    faculty_rank TEXT,
    college TEXT,
    user_role TEXT,
    date_added TEXT,
    account_status TEXT,
    created_by TEXT
)
LANGUAGE plpgsql
SET search_path = internal
AS $$
DECLARE
    error_code TEXT;
    err_code TEXT;
    err_msg TEXT;
BEGIN
    RETURN QUERY
    SELECT * FROM internal.get_users();
EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
        IF err_code IN ('P0015') THEN
            RETURN QUERY
            SELECT '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT;
        END IF;

        -- Generic fallback logging
        SELECT internal.log_error_wrapper(
                       err_code,
                       err_msg,
                       'public.get_users',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        RETURN QUERY
        --SELECT 'X'::TEXT, concat('Something went wrong. ', error_code)::TEXT;
        SELECT '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT;

END;
$$ SECURITY DEFINER;
REVOKE ALL ON FUNCTION public.get_users() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_users() TO authenticated;



-- 3. Delete User Account

CREATE OR REPLACE FUNCTION public.delete_user_wrapper(
    IN p_user_id TEXT
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
    CALL internal.delete_user(p_user_id);

    -- RETURN '✅ User account deleted successfully.';
    RETURN jsonb_build_object(
        'status', 'success',
        'message', '✅ User account deleted successfully.'
    );

EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
        IF err_code IN ('P0010', 'P0014') THEN
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
                       'public.delete_user_wrapper',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        -- RETURN concat('Something went wrong. ', error_code);
        RETURN jsonb_build_object(
            'status', 'error',
            'message', concat('Something went wrong. ', error_code)
        );


END;
$$;
REVOKE ALL ON FUNCTION public.delete_user_wrapper(IN p_user_id TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.delete_user_wrapper(IN p_user_id TEXT) TO authenticated;



-- 4. GET USER'S INFO AFTER LOGGING IN

CREATE OR REPLACE FUNCTION public.get_user_info(IN p_platform_id INT)
RETURNS TABLE (
    profile_name TEXT,
    role TEXT,
    lname TEXT,
    fname TEXT,
    mname TEXT,
    birth_date TEXT,
    email TEXT,
    phone TEXT,
    bio TEXT,
    degree TEXT,
    faculty_rank TEXT,
    college TEXT,
    notification TEXT
)
LANGUAGE plpgsql
SET search_path = internal
AS $$
DECLARE
    error_code TEXT;
    err_code TEXT;
    err_msg TEXT;
BEGIN
    RETURN QUERY
    SELECT * FROM internal.get_user_info(p_platform_id);
EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
        IF err_code IN ('P0016') THEN
            RETURN QUERY
            SELECT '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT
            WHERE FALSE;
        END IF;

        -- Generic fallback logging
        SELECT internal.log_error_wrapper(
                       err_code,
                       err_msg,
                       'public.get_user_info',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        RETURN QUERY
        --SELECT 'X'::TEXT, concat('Something went wrong. ', error_code)::TEXT;
        SELECT '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT
        WHERE FALSE;
END;
$$ SECURITY DEFINER;
REVOKE ALL ON FUNCTION public.get_user_info(IN p_platform_id INT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_user_info(IN p_platform_id INT) TO authenticated;



-- 5.) UPDATE USER'S ACCOUNT

-- 5.1 GET ALL DEGREES

CREATE OR REPLACE FUNCTION public.get_degrees()
RETURNS TABLE(id TEXT, name TEXT)
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
    SELECT * FROM internal.get_degrees();
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
                       'public.get_degrees',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        RETURN QUERY
        --SELECT 'X'::TEXT, concat('Something went wrong. ', error_code)::TEXT;
        SELECT '*'::TEXT, '*'::TEXT;

    END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION public.get_degrees() FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION public.get_degrees() TO authenticated;


-- 5.2 update user

CREATE OR REPLACE FUNCTION public.update_user_wrapper(
    IN p_user_id TEXT,
    IN p_lname TEXT DEFAULT NULL,
    IN p_mname TEXT DEFAULT NULL,
    IN p_fname TEXT DEFAULT NULL,
    IN p_email TEXT DEFAULT NULL,
    IN p_birth DATE DEFAULT NULL,
    IN p_degree_id TEXT DEFAULT NULL,
    IN p_college_office_id TEXT DEFAULT NULL,
    IN p_rank_id TEXT DEFAULT NULL,
    IN p_role_id TEXT DEFAULT NULL,
    IN p_account_status BOOLEAN DEFAULT NULL,
    IN p_default_profile BOOLEAN DEFAULT NULL,
    IN p_undergrad_load INT DEFAULT NULL
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
    CALL internal.update_user(
        p_user_id,
        p_lname,
        p_mname,
        p_fname,
        p_email,
        p_birth,
        p_degree_id,
        p_college_office_id,
        p_rank_id,
        p_role_id,
        p_account_status,
        p_default_profile,
        p_undergrad_load
);

    -- RETURN '✅ User account updated successfully.';
    RETURN jsonb_build_object(
        'status', 'success',
        'message', '✅ User account updated successfully.'
    );

EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
        IF err_code IN ('P0010', 'P0017', 'P0012', 'P0014') THEN
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
                       'public.update_user_wrapper',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        -- RETURN concat('Something went wrong. ', error_code);
        RETURN jsonb_build_object(
            'status', 'error',
            'message', concat('Something went wrong. ', error_code)
        );

END;
$$;
REVOKE ALL ON FUNCTION public.update_user_wrapper(
    IN p_user_id TEXT,
    IN p_lname TEXT,
    IN p_mname TEXT,
    IN p_fname TEXT,
    IN p_email TEXT,
    IN p_birth DATE,
    IN p_degree_id TEXT,
    IN p_college_office_id TEXT,
    IN p_rank_id TEXT,
    IN p_role_id TEXT,
    IN p_account_status BOOLEAN,
    IN p_default_profile BOOLEAN,
    IN p_undergrad_load INT
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.update_user_wrapper(
    IN p_user_id TEXT,
    IN p_lname TEXT,
    IN p_mname TEXT,
    IN p_fname TEXT,
    IN p_email TEXT,
    IN p_birth DATE,
    IN p_degree_id TEXT,
    IN p_college_office_id TEXT,
    IN p_rank_id TEXT,
    IN p_role_id TEXT,
    IN p_account_status BOOLEAN,
    IN p_default_profile BOOLEAN,
    IN p_undergrad_load INT
) TO authenticated;




-- TASK 6. TRACK USER LOG IN

CREATE OR REPLACE FUNCTION public.login_trail()
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
    CALL internal.login_trail();

    -- RETURN '✅ User account deleted successfully.';
    RETURN jsonb_build_object(
        'status', 'success',
        'message', 'ok'
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
                       'public.login_trail()',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        -- RETURN concat('Something went wrong. ', error_code);
        RETURN jsonb_build_object(
            'status', 'error',
            'message', concat('Something went wrong. ', error_code)
        );


END;
$$;
REVOKE ALL ON FUNCTION public.login_trail() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.login_trail() TO authenticated;








-- PLAYGROUND ---------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------

