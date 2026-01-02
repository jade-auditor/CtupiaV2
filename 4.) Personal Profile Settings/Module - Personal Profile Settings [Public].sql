------------------------------------------------------------------------------------------------------------------------
------------------------------- PUBLIC SCHEMA --------------------------------------------------------------------------


------------------------------------------------------------------------------------------------------------------------
-- TASK 1._ My Notifications

CREATE OR REPLACE FUNCTION public.my_assigned_courses()
RETURNS TABLE(id text, avatar text, message text, "time" text, status boolean)
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
        SELECT * FROM internal.my_notifications();
EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
        IF err_code IN ('P0015') THEN
            RETURN QUERY
            -- SELECT 'X'::TEXT, err_msg::TEXT;
            SELECT '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT;
        END IF;

        -- Generic fallback logging
        SELECT internal.log_error_wrapper(
                       err_code,
                       err_msg,
                       'public.my_notifications',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        RETURN QUERY
        --SELECT 'X'::TEXT, concat('Something went wrong. ', error_code)::TEXT;
        SELECT '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT;

END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION public.my_assigned_courses() FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION public.my_assigned_courses() TO authenticated;


-- TASK 2._ Update Bio

CREATE OR REPLACE FUNCTION public.update_bio(p_new_bio character varying)
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
    CALL internal.update_bio(p_new_bio);

    -- RETURN 'You have successfully updated your bio. 💬.';
    RETURN jsonb_build_object(
        'status', 'success',
        'message', 'You have successfully updated your bio. 💬.'
    );

EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
        IF err_code IN ('P0010') THEN -- currently there is no declared custom exception. p0009 is just a placeholder.
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
                       'public.update_bio',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        -- RETURN concat('Something went wrong. ', error_code);
        RETURN jsonb_build_object(
            'status', 'error',
            'message', concat('Something went wrong. ', error_code)
        );

END;
$$;
REVOKE ALL ON FUNCTION public.update_bio(p_new_bio character varying) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.update_bio(p_new_bio character varying) TO authenticated;



-- TASK 3._ Update Avatar

CREATE OR REPLACE FUNCTION public.update_avatar(p_profile_upload uuid)
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
    CALL internal.update_avatar(p_profile_upload);

    -- RETURN 'You have successfully updated your bio. 💬.';
    RETURN jsonb_build_object(
        'status', 'success',
        'message', 'You have successfully updated your avatar.'
    );

EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
        IF err_code IN ('P0010', 'P0043') THEN -- currently there is no declared custom exception. p0009 is just a placeholder.
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
                       'public.update_avatar',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        -- RETURN concat('Something went wrong. ', error_code);
        RETURN jsonb_build_object(
            'status', 'error',
            'message', concat('Something went wrong. ', error_code)
        );

END;
$$;
REVOKE ALL ON FUNCTION public.update_avatar(p_profile_upload uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.update_avatar(p_profile_upload uuid) TO authenticated;



-- TASK 4._ Update Sensitive Info

CREATE OR REPLACE FUNCTION public.update_sensitive_info(p_new_fname text, p_new_mname text, p_new_lname text, p_new_birth date)
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
    CALL internal.update_sensitive_info(
    p_new_fname,
    p_new_mname,
    p_new_lname,
    p_new_birth);

    -- RETURN 'You have successfully updated your information. 🤫.';
    RETURN jsonb_build_object(
        'status', 'success',
        'message', 'You have successfully updated your information. 🤫.'
    );


EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
        IF err_code IN ('P0010', 'P0019') THEN -- currently there is no declared custom exception. p0009 is just a placeholder.
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
                       'public.update_sensitive_info',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        -- RETURN concat('Something went wrong. ', error_code);
        RETURN jsonb_build_object(
            'status', 'error',
            'message', concat('Something went wrong. ', error_code)
        );

END;
$$;
REVOKE ALL ON FUNCTION public.update_sensitive_info(p_new_fname text, p_new_mname text, p_new_lname text, p_new_birth date) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.update_sensitive_info(p_new_fname text, p_new_mname text, p_new_lname text, p_new_birth date) TO authenticated;

