------------------------------------------------------------------------------------------------------------------------
------------------------------- PUBLIC SCHEMA --------------------------------------------------------------------------


------------------------------------------------------------------------------------------------------------------------
-- TASK 1._ Admin Dashboard

CREATE OR REPLACE FUNCTION public.admin_dashboard()
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
    result := internal.admin_dashboard();

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
                       'public.admin_dashboard',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        -- RETURN concat('Something went wrong. ', error_code);
        RETURN jsonb_build_object(
                'status', 'error',
                'message', concat('Something went wrong. ', error_code)
            );

END;
$$;



-- TASK 2._ Dean Dashboard

CREATE OR REPLACE FUNCTION public.dean_dashboard()
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
    result := internal.dean_dashboard();

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
                       'public.dean_dashboard',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        -- RETURN concat('Something went wrong. ', error_code);
        RETURN jsonb_build_object(
                'status', 'error',
                'message', concat('Something went wrong. ', error_code)
            );

END;
$$;



-- TASK 3._ Faculty Dashboard

CREATE OR REPLACE FUNCTION public.faculty_dashboard()
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
    result := internal.faculty_dashboard();

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
                       'public.faculty_dashboard',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        -- RETURN concat('Something went wrong. ', error_code);
        RETURN jsonb_build_object(
                'status', 'error',
                'message', concat('Something went wrong. ', error_code)
            );

END;
$$;

