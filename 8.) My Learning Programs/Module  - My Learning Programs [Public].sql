-----------------------------------------------------------------------------------------------
------------------------------- PUBLIC SCHEMA -----------------------------------------------


------------------------------------------------------------------------------------------------------------------------
-- 1.My learning Programs  --------------------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.my_learning_programs()
RETURNS TABLE(
    id TEXT, -- 1
    name TEXT, -- 2
    code TEXT, -- 3
    period TEXT, -- 4
    wallpaper TEXT -- 5
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
        SELECT * FROM internal.my_learning_programs();
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
                       'public.my_learning_programs',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        RETURN QUERY
        --SELECT 'X'::TEXT, concat('Something went wrong. ', error_code)::TEXT;
        SELECT '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT;

END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION public.my_learning_programs() FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION public.my_learning_programs() TO authenticated;


--2.) My Courses (related Courses)

CREATE OR REPLACE FUNCTION public.my_courses(IN my_learning_program_id TEXT)
RETURNS TABLE(
    id TEXT, -- 1
    name TEXT, -- 2
    code TEXT, -- 3
    semester TEXT, -- 4
    wallpaper TEXT, -- 5
    lessons TEXT, -- 6
    progress TEXT -- 7
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
        SELECT * FROM internal.my_courses( my_learning_program_id );
EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
        IF err_code IN ('P0015','P0043') THEN
            RETURN QUERY
            -- SELECT 'X'::TEXT, err_msg::TEXT;
            SELECT err_msg::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT,'*'::TEXT,'*'::TEXT, '*'::TEXT;
        END IF;

        -- Generic fallback logging
        SELECT internal.log_error_wrapper(
                       err_code,
                       err_msg,
                       'public.my_courses',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        RETURN QUERY
        --SELECT 'X'::TEXT, concat('Something went wrong. ', error_code)::TEXT;
        SELECT error_code::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT;

END;
$$; -- deprecated
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION public.my_courses(IN my_learning_program_id TEXT) FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION public.my_courses(IN my_learning_program_id TEXT) TO authenticated;

-- My Courses Version 2

CREATE OR REPLACE FUNCTION public.my_courses2(IN my_learning_program_id TEXT)
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
    result := internal.my_courses2( my_learning_program_id );

    RETURN jsonb_build_object(
                'status', 'success',
                'message', result
            );
EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
        IF err_code IN ('P0043') THEN
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
                       'public.my_courses2',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        -- RETURN concat('Something went wrong. ', error_code);
        RETURN jsonb_build_object(
                'status', 'error',
                'message', concat('Something went wrong. ', error_code)
            );

END;
$$;
REVOKE ALL ON FUNCTION public.my_courses2(IN my_learning_program_id TEXT)  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.my_courses2(IN my_learning_program_id TEXT) TO authenticated;



-- 3.) View Course (This means all teh details contents and everything in the course)

CREATE OR REPLACE FUNCTION public.view_course(IN p_my_course_id TEXT)
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
    result := internal.view_course(p_my_course_id);

    RETURN jsonb_build_object(
                'status', 'success',
                'message', result
            );
EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
        IF err_code IN ('P0010','P0066') THEN
            -- RETURN err_msg;
            RETURN jsonb_build_object(
                'status', 'warning',
                'message', err_msg
            );
        ELSIF err_code IN ('P0043') THEN
            -- RETURN err_msg;
            RETURN jsonb_build_object(
                'status', 'error',
                'message', err_msg
            );
        END IF;

        -- Generic fallback logging
        SELECT internal.log_error_wrapper(
                       err_code,
                       err_msg,
                       'public.view_course',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        -- RETURN concat('Something went wrong. ', error_code);
        RETURN jsonb_build_object(
                'status', 'error',
                'message', concat('Something went wrong. ', error_code)
            );

END;
$$;
REVOKE ALL ON FUNCTION public.view_course(IN p_my_course_id TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.view_course(IN p_my_course_id TEXT) TO authenticated;


-- 4.) View Faculty's Profile

CREATE OR REPLACE FUNCTION public.view_faculty_profile(IN p_faculty_id TEXT)
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
    result := internal.view_faculty_profile( p_faculty_id );

    RETURN jsonb_build_object(
                'status', 'success',
                'message', result
            );
EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
        IF err_code IN ('P0010','P0043') THEN
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
                       'public.view_faculty_profile',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        -- RETURN concat('Something went wrong. ', error_code);
        RETURN jsonb_build_object(
                'status', 'error',
                'message', concat('Something went wrong. ', error_code)
            );

END;
$$;
REVOKE ALL ON FUNCTION public.view_faculty_profile(IN p_faculty_id TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.view_faculty_profile(IN p_faculty_id TEXT) TO authenticated;

-- 5.) RECORD WATCH VIDEO PROGRESS

CREATE OR REPLACE FUNCTION public.track_progress(
    IN p_video_id TEXT,
    IN p_time_stamp INTERVAL
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
    CALL internal.track_progress(
         p_video_id ,
         p_time_stamp
    );

    -- RETURN '✅ Program successfully created.';
    RETURN jsonb_build_object(
        'status', 'success',
        'message', '✅ Track recorded successfully'
    );

EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        IF err_code IN ('P0010', 'P0043') THEN
            RETURN jsonb_build_object(
                'status', 'warning',
                'message', err_msg
            );
        ELSE
            BEGIN
                SELECT internal.log_error_wrapper(
                           err_code,
                           err_msg,
                           'public.track_progress',
                           jsonb_build_object('sqlerrm', SQLERRM)
                   )
                INTO error_code;
            EXCEPTION WHEN OTHERS THEN
                -- ensure we don’t exit without RETURN
                error_code := 'log-failed';
            END;

            RETURN jsonb_build_object(
                'status', 'error',
                'message', concat('Something went wrong. ', error_code)
            );
        END IF;
END;
$$;
REVOKE ALL ON FUNCTION public.track_progress(
    IN p_video_id TEXT,
    IN p_time_stamp INTERVAL
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.track_progress(
    IN p_video_id TEXT,
    IN p_time_stamp INTERVAL
) TO authenticated;


-- 5.1) GET LAST TIMESTAMP

CREATE OR REPLACE FUNCTION public.get_last_progress(IN p_video_id TEXT)
RETURNS jsonb
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
--     RETURN internal.get_last_progress(p_video_id);

    -- RETURN '✅ Program successfully created.';
    RETURN jsonb_build_object(
        'status', 'success',
        'message', internal.get_last_progress(p_video_id)
    );

EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        IF err_code IN ('P0010', 'P0043') THEN
            RETURN jsonb_build_object(
                'status', 'warning',
                'message', err_msg
            );
        ELSE
            BEGIN
                SELECT internal.log_error_wrapper(
                           err_code,
                           err_msg,
                           'public.get_last_progress',
                           jsonb_build_object('sqlerrm', SQLERRM)
                   )
                INTO error_code;
            EXCEPTION WHEN OTHERS THEN
                -- ensure we don’t exit without RETURN
                error_code := 'log-failed';
            END;

            RETURN jsonb_build_object(
                'status', 'error',
                'message', concat('Something went wrong. ', error_code)
            );
        END IF;
END;
$$;
REVOKE ALL ON FUNCTION public.get_last_progress(IN p_video_id TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_last_progress(IN p_video_id TEXT) TO authenticated;



-- 6.) View Assignment

CREATE OR REPLACE FUNCTION public.view_assignment(IN p_assignment_id TEXT)
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
    result := internal.view_assignment( p_assignment_id );

    RETURN jsonb_build_object(
                'status', 'success',
                'message', result
            );
EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
        IF err_code IN ('P0010', 'P0035') THEN
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
                       'public.view_assignment',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        -- RETURN concat('Something went wrong. ', error_code);
        RETURN jsonb_build_object(
                'status', 'error',
                'message', concat('Something went wrong. ', error_code)
            );

END;
$$;
REVOKE ALL ON FUNCTION public.view_assignment(IN p_assignment_id TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.view_assignment(IN p_assignment_id TEXT) TO authenticated;

-- 6.2 Submit Assignment

CREATE OR REPLACE FUNCTION public.submit_assignment(
    IN p_assignment_id TEXT,
    IN p_files UUID[],
    IN p_links TEXT[]
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
    CALL internal.submit_assignment(
         p_assignment_id,
         p_files,
         p_links
         );

    -- RETURN '✅ Program successfully created.';
    RETURN jsonb_build_object(
        'status', 'success',
        'message', '✅ Turned in successfully.'
    );

    EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        BEGIN
            call internal.student_attachment_rollback(p_files);
            -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
            IF err_code IN ('P0010', 'P0043') THEN
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
                               'public.submit_assignment',
                               jsonb_build_object('sqlerrm', SQLERRM)
                       ) INTO error_code;

                -- RETURN concat('Something went wrong. ', error_code);
                RETURN jsonb_build_object(
                        'status', 'error',
                        'message', concat('Something went wrong. ', error_code)
                    );
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                GET STACKED DIAGNOSTICS err_code2 = RETURNED_SQLSTATE,
                                         err_msg2 = MESSAGE_TEXT;
                -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
                IF err_code2 IN ('P0010','P0043') THEN
                    -- RETURN err_msg;
                    RETURN jsonb_build_object(
                        'status', 'warning',
                        'message', err_msg2
                    );
                ELSE
                    -- Generic fallback logging
                    SELECT internal.log_error_wrapper(
                                   err_code2,
                                   err_msg2,
                                   'internal.student_attachment_rollback',
                                   jsonb_build_object('sqlerrm', SQLERRM)
                           ) INTO error_code;

                    -- RETURN concat('Something went wrong. ', error_code);
                    RETURN jsonb_build_object(
                            'status', 'error',
                            'message', concat('Something went wrong. ', error_code)
                        );
                END IF;
        END;

END;
$$;
REVOKE ALL ON FUNCTION public.submit_assignment(
    IN p_assignment_id TEXT,
    IN p_files UUID[],
    IN p_links TEXT[]
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_assignment(
    IN p_assignment_id TEXT,
    IN p_files UUID[],
    IN p_links TEXT[]
) TO authenticated;


-- 6.3) Unsubmit work

CREATE OR REPLACE FUNCTION public.unsubmit_work(
    IN p_assignment_id TEXT
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
    CALL internal.unsubmit_work(
         p_assignment_id
    );

    -- RETURN '✅ Program successfully created.';
    RETURN jsonb_build_object(
        'status', 'success',
        'message', '✅ Submission cancelled'
    );

EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        IF err_code IN ('P0010', 'P0043') THEN
            RETURN jsonb_build_object(
                'status', 'warning',
                'message', err_msg
            );
        ELSE
            BEGIN
                SELECT internal.log_error_wrapper(
                           err_code,
                           err_msg,
                           'public.unsubmit_work',
                           jsonb_build_object('sqlerrm', SQLERRM)
                   )
                INTO error_code;
            EXCEPTION WHEN OTHERS THEN
                -- ensure we don’t exit without RETURN
                error_code := 'log-failed';
            END;

            RETURN jsonb_build_object(
                'status', 'error',
                'message', concat('Something went wrong. ', error_code)
            );
        END IF;
END;
$$;
REVOKE ALL ON FUNCTION public.unsubmit_work(
    IN p_assignment_id TEXT
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.unsubmit_work(
    IN p_assignment_id TEXT
) TO authenticated;


-- 6.4) Removed attachment

CREATE OR REPLACE FUNCTION public.remove_attachment(
    IN p_my_attachment_id TEXT
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
    CALL internal.remove_attachment(
         p_my_attachment_id
    );

    -- RETURN '✅ Program successfully created.';
    RETURN jsonb_build_object(
        'status', 'success',
        'message', '✅ Attachment removed successfully'
    );
EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        IF err_code IN ('P0010', 'P0043') THEN
            RETURN jsonb_build_object(
                'status', 'warning',
                'message', err_msg
            );
        ELSE
            BEGIN
                SELECT internal.log_error_wrapper(
                           err_code,
                           err_msg,
                           'public.remove_attachment',
                           jsonb_build_object('sqlerrm', SQLERRM)
                   )
                INTO error_code;
            EXCEPTION WHEN OTHERS THEN
                -- ensure we don’t exit without RETURN
                error_code := 'log-failed';
            END;

            RETURN jsonb_build_object(
                'status', 'error',
                'message', concat('Something went wrong. ', error_code)
            );
        END IF;
END;
$$;
REVOKE ALL ON FUNCTION public.remove_attachment(
    IN p_my_attachment_id TEXT
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.remove_attachment(
    IN p_my_attachment_id TEXT
) TO authenticated;




-- 7 Examination

--- 7.1) View Exam

CREATE OR REPLACE FUNCTION public.view_exam(IN p_my_exam_id TEXT)
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
    result := internal.view_exam( p_my_exam_id );

    RETURN jsonb_build_object(
                'status', 'success',
                'message', result
            );
EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
        IF err_code IN ('P0010', 'P0035') THEN
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
                       'public.view_exam',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        -- RETURN concat('Something went wrong. ', error_code);
        RETURN jsonb_build_object(
                'status', 'error',
                'message', concat('Something went wrong. ', error_code)
            );

END;
$$;
REVOKE ALL ON FUNCTION public.view_exam(IN p_my_exam_id TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.view_exam(IN p_my_exam_id TEXT) TO authenticated;


--- 7.2) View Exam Result

CREATE OR REPLACE FUNCTION public.view_attempt_result(IN p_my_attempt_id TEXT)
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
    result := internal.view_attempt_result( p_my_attempt_id );

    RETURN jsonb_build_object(
                'status', 'success',
                'message', result
            );
EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
        IF err_code IN ('P0010', 'P0035') THEN
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
                       'public.view_attempt_result',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        -- RETURN concat('Something went wrong. ', error_code);
        RETURN jsonb_build_object(
                'status', 'error',
                'message', concat('Something went wrong. ', error_code)
            );

END;
$$;
REVOKE ALL ON FUNCTION public.view_attempt_result(IN p_my_attempt_id TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.view_attempt_result(IN p_my_attempt_id TEXT) TO authenticated;

--- 7.3) ATTEMPT EXAM (IF ALLOWED)

CREATE OR REPLACE FUNCTION public.attempt_exam(IN p_my_exam_id TEXT)
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
    result := internal.attempt_exam( p_my_exam_id );

    RETURN jsonb_build_object(
                'status', 'success',
                'message', result
            );
EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
        IF err_code IN ('P0010', 'P0035') THEN
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
                       'public.attempt_exam',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        -- RETURN concat('Something went wrong. ', error_code);
        RETURN jsonb_build_object(
                'status', 'error',
                'message', concat('Something went wrong. ', error_code)
            );

END;
$$;
REVOKE ALL ON FUNCTION public.attempt_exam(IN p_my_exam_id TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.attempt_exam(IN p_my_exam_id TEXT) TO authenticated;

--- 7.4) GET QUESTIONNAIRE

CREATE OR REPLACE FUNCTION public.fetch_questions(IN p_request_token TEXT)
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
    result := internal.fetch_questions( p_request_token );

    RETURN jsonb_build_object(
                'status', 'success',
                'message', result
            );
EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
        IF err_code IN ('P0010', 'P0035', 'P0044', 'P0045', 'P0046', 'P0047') THEN
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
                       'public.fetch_questions',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        -- RETURN concat('Something went wrong. ', error_code);
        RETURN jsonb_build_object(
                'status', 'error',
                'message', concat('Something went wrong. ', error_code)
            );

END;
$$;
REVOKE ALL ON FUNCTION public.fetch_questions(IN p_request_token TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fetch_questions(IN p_request_token TEXT) TO authenticated;


--- 7.5) RECORD ENTRY

CREATE OR REPLACE FUNCTION public.record_entry(
    IN p_my_record_id TEXT,
    IN p_key_id TEXT DEFAULT NULL,
    IN p_tof_ans BOOLEAN DEFAULT NULL,
    IN p_text_ans TEXT DEFAULT NULL,
    IN p_enum_ans TEXT[] DEFAULT NULL
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
    CALL internal.record_entry(
         p_my_record_id,
         p_key_id,
         p_tof_ans,
         p_text_ans,
         p_enum_ans
    );

    -- RETURN '✅ Program successfully created.';
    RETURN jsonb_build_object(
        'status', 'success',
        'message', '✅ Answer recorded.'
    );
EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        IF err_code IN ('P0010', 'P0048', 'P0035', 'P0049') THEN
            RETURN jsonb_build_object(
                'status', 'warning',
                'message', err_msg
            );
        ELSE
            BEGIN
                SELECT internal.log_error_wrapper(
                           err_code,
                           err_msg,
                           'public.record_entry',
                           jsonb_build_object('sqlerrm', SQLERRM)
                   )
                INTO error_code;
            EXCEPTION WHEN OTHERS THEN
                -- ensure we don’t exit without RETURN
                error_code := 'log-failed';
            END;

            RETURN jsonb_build_object(
                'status', 'error',
                'message', concat('Something went wrong. ', error_code)
            );
        END IF;
END;
$$;
REVOKE ALL ON FUNCTION public.record_entry(
    IN p_my_record_id TEXT,
    IN p_key_id TEXT,
    IN p_tof_ans BOOLEAN,
    IN p_text_ans TEXT,
    IN p_enum_ans TEXT[]
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.record_entry(
    IN p_my_record_id TEXT,
    IN p_key_id TEXT,
    IN p_tof_ans BOOLEAN,
    IN p_text_ans TEXT,
    IN p_enum_ans TEXT[]
) TO authenticated;


--- 7.6) END TEST

CREATE OR REPLACE FUNCTION public.end_test(
    IN p_my_record_id TEXT
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
    CALL internal.end_test(
         p_my_record_id
    );

    -- RETURN '✅ Program successfully created.';
    RETURN jsonb_build_object(
        'status', 'success',
        'message', '✅ Assessment successfully ended.'
    );
EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        IF err_code IN ('P0010', 'P0048', 'P0035', 'P0049') THEN
            RETURN jsonb_build_object(
                'status', 'warning',
                'message', err_msg
            );
        ELSE
            BEGIN
                SELECT internal.log_error_wrapper(
                           err_code,
                           err_msg,
                           'public.end_test',
                           jsonb_build_object('sqlerrm', SQLERRM)
                   )
                INTO error_code;
            EXCEPTION WHEN OTHERS THEN
                -- ensure we don’t exit without RETURN
                error_code := 'log-failed';
            END;

            RETURN jsonb_build_object(
                'status', 'error',
                'message', concat('Something went wrong. ', error_code)
            );
        END IF;
END;
$$;
REVOKE ALL ON FUNCTION public.end_test(
    IN p_my_record_id TEXT
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.end_test(
    IN p_my_record_id TEXT
) TO authenticated;


-- 8.) DOWNLOAD PROSPECTUS

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
        IF err_code IN ('P0015') THEN
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


-- TASK 9.) WITHDRAW FROM COURSE

CREATE OR REPLACE FUNCTION public.withdraw_course(IN p_my_withdraw_id TEXT)
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
    CALL internal.withdraw_course(
         p_my_withdraw_id
    );

    -- RETURN '✅ Program successfully created.';
    RETURN jsonb_build_object(
        'status', 'success',
        'message', '✅ You have successfully withdrawn from this course.'
    );
EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        IF err_code IN ('P0010', 'P0043') THEN
            RETURN jsonb_build_object(
                'status', 'warning',
                'message', err_msg
            );
        ELSE
            BEGIN
                SELECT internal.log_error_wrapper(
                           err_code,
                           err_msg,
                           'public.withdraw_course',
                           jsonb_build_object('sqlerrm', SQLERRM)
                   )
                INTO error_code;
            EXCEPTION WHEN OTHERS THEN
                -- ensure we don’t exit without RETURN
                error_code := 'log-failed';
            END;

            RETURN jsonb_build_object(
                'status', 'error',
                'message', concat('Something went wrong. ', error_code)
            );
        END IF;
END;
$$;
REVOKE ALL ON FUNCTION public.withdraw_course(IN p_my_withdraw_id TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.withdraw_course(IN p_my_withdraw_id TEXT) TO authenticated;


-- TASK 10.) LEADERBOARDS

CREATE OR REPLACE FUNCTION public.view_leaderboards(IN p_leaderboards_id TEXT)
RETURNS TABLE(
    id TEXT, -- 1
    avatar TEXT, -- 2
    name TEXT, -- 3
    points TEXT, -- 4
    rank TEXT, -- 5
    status BOOLEAN
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
        SELECT * FROM internal.view_leaderboards(p_leaderboards_id);
EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
        IF err_code IN ('P0035') THEN
            RETURN QUERY
            -- SELECT 'X'::TEXT, err_msg::TEXT;
            SELECT '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT;
        END IF;

        -- Generic fallback logging
        SELECT internal.log_error_wrapper(
                       err_code,
                       err_msg,
                       'public.view_leaderboards',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        RETURN QUERY
        --SELECT 'X'::TEXT, concat('Something went wrong. ', error_code)::TEXT;
        SELECT error_code::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT;

END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION public.view_leaderboards(IN p_leaderboards_id TEXT) FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION public.view_leaderboards(IN p_leaderboards_id TEXT) TO authenticated;


-- TASK 11.) GIVE REVIEW AND RATING

CREATE OR REPLACE FUNCTION public.rate_course(
    IN p_rating_id TEXT,
    IN p_my_rating INT,
    IN p_my_review TEXT
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
    CALL internal.rate_course(
         p_rating_id, p_my_rating, p_my_review
    );

    -- RETURN '✅ Program successfully created.';
    RETURN jsonb_build_object(
        'status', 'success',
        'message', '✅ Your rating has been submitted successfully. Thank you for your feedback!'
    );
EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        IF err_code IN ('P0010', 'P0043') THEN
            RETURN jsonb_build_object(
                'status', 'warning',
                'message', err_msg
            );
        ELSE
            BEGIN
                SELECT internal.log_error_wrapper(
                           err_code,
                           err_msg,
                           'public.rate_course',
                           jsonb_build_object('sqlerrm', SQLERRM)
                   )
                INTO error_code;
            EXCEPTION WHEN OTHERS THEN
                -- ensure we don’t exit without RETURN
                error_code := 'log-failed';
            END;

            RETURN jsonb_build_object(
                'status', 'error',
                'message', concat('Something went wrong. ', error_code)
            );
        END IF;
END;
$$;
REVOKE ALL ON FUNCTION public.rate_course(
    IN p_rating_id TEXT,
    IN p_my_rating INT,
    IN p_my_review TEXT
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rate_course(
    IN p_rating_id TEXT,
    IN p_my_rating INT,
    IN p_my_review TEXT
) TO authenticated;

--- SUBTASK 11.1) DELETE REVIEW AND RATING

CREATE OR REPLACE FUNCTION public.delete_review( IN p_rating_id TEXT)
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
    CALL internal.delete_review(
         p_rating_id
    );

    -- RETURN '✅ Program successfully created.';
    RETURN jsonb_build_object(
        'status', 'success',
        'message', '✅ Your review has been successfully deleted.'
    );
EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        IF err_code IN ('P0010', 'P0043') THEN
            RETURN jsonb_build_object(
                'status', 'warning',
                'message', err_msg
            );
        ELSE
            BEGIN
                SELECT internal.log_error_wrapper(
                           err_code,
                           err_msg,
                           'public.delete_review',
                           jsonb_build_object('sqlerrm', SQLERRM)
                   )
                INTO error_code;
            EXCEPTION WHEN OTHERS THEN
                -- ensure we don’t exit without RETURN
                error_code := 'log-failed';
            END;

            RETURN jsonb_build_object(
                'status', 'error',
                'message', concat('Something went wrong. ', error_code)
            );
        END IF;
END;
$$;
REVOKE ALL ON FUNCTION public.delete_review( IN p_rating_id TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.delete_review( IN p_rating_id TEXT) TO authenticated;


--- SUBTASK 11.2) LIKE OR DISLIKE USER'S REVIEW

CREATE OR REPLACE FUNCTION public.react_review( IN p_review_id TEXT, IN p_reaction BOOLEAN)
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
    CALL internal.react_review(
         p_review_id, p_reaction
    );

    -- RETURN '✅ Program successfully created.';
    RETURN jsonb_build_object(
        'status', 'success',
        'message', 'ok'
    );
EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        IF err_code IN ('P0010', 'P0043') THEN
            RETURN jsonb_build_object(
                'status', 'warning',
                'message', err_msg
            );
        ELSE
            BEGIN
                SELECT internal.log_error_wrapper(
                           err_code,
                           err_msg,
                           'public.react_review',
                           jsonb_build_object('sqlerrm', SQLERRM)
                   )
                INTO error_code;
            EXCEPTION WHEN OTHERS THEN
                -- ensure we don’t exit without RETURN
                error_code := 'log-failed';
            END;

            RETURN jsonb_build_object(
                'status', 'error',
                'message', concat('Something went wrong. ', error_code)
            );
        END IF;
END;
$$;
REVOKE ALL ON FUNCTION public.react_review( IN p_review_id TEXT, IN p_reaction BOOLEAN) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.react_review( IN p_review_id TEXT, IN p_reaction BOOLEAN) TO authenticated;


--- SUBTASK 11.3) REMOVE LIKE FROM USER'S REVIEW

CREATE OR REPLACE FUNCTION public.delete_reaction( IN p_review_id TEXT)
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
    CALL internal.delete_reaction(
         p_review_id
    );

    -- RETURN '✅ Program successfully created.';
    RETURN jsonb_build_object(
        'status', 'success',
        'message', 'ok'
    );
EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        IF err_code IN ('P0010', 'P0043') THEN
            RETURN jsonb_build_object(
                'status', 'warning',
                'message', err_msg
            );
        ELSE
            BEGIN
                SELECT internal.log_error_wrapper(
                           err_code,
                           err_msg,
                           'public.delete_reaction',
                           jsonb_build_object('sqlerrm', SQLERRM)
                   )
                INTO error_code;
            EXCEPTION WHEN OTHERS THEN
                -- ensure we don’t exit without RETURN
                error_code := 'log-failed';
            END;

            RETURN jsonb_build_object(
                'status', 'error',
                'message', concat('Something went wrong. ', error_code)
            );
        END IF;
END;
$$;
REVOKE ALL ON FUNCTION public.delete_reaction( IN p_review_id TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.delete_reaction( IN p_review_id TEXT) TO authenticated;




-- TASK 12. EXPLORE PROGRAMS

CREATE OR REPLACE FUNCTION public.explore_programs()
RETURNS TABLE(
    id TEXT, -- 1
    name TEXT, -- 2
    wallpaper TEXT, -- 3
    about TEXT, -- 4
    reviews TEXT, -- 5
    rating TEXT -- 6
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
        SELECT * FROM internal.explore_programs();
EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
        IF err_code IN ('P0015') THEN
            RETURN QUERY
            -- SELECT 'X'::TEXT, err_msg::TEXT;
            SELECT '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT;
        END IF;

        -- Generic fallback logging
        SELECT internal.log_error_wrapper(
                       err_code,
                       err_msg,
                       'public.explore_programs',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        RETURN QUERY
        --SELECT 'X'::TEXT, concat('Something went wrong. ', error_code)::TEXT;
        SELECT '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT;

END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION public.explore_programs() FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION public.explore_programs() TO authenticated;

-- SUBTASK 12.1 VIEW PROGRAAM

CREATE OR REPLACE FUNCTION public.view_program(IN p_program_id TEXT)
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
    result := internal.view_program( p_program_id );

    RETURN jsonb_build_object(
                'status', 'success',
                'message', result
            );
EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
        IF err_code IN ('P0043') THEN
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
                       'public.view_program',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        -- RETURN concat('Something went wrong. ', error_code);
        RETURN jsonb_build_object(
                'status', 'error',
                'message', concat('Something went wrong. ', error_code)
            );

END;
$$;
REVOKE ALL ON FUNCTION public.view_program(IN p_program_id TEXT)  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.view_program(IN p_program_id TEXT) TO authenticated;

-- SUBTASK 12.2 TOP MOST OFFERED PROGRAMS

CREATE OR REPLACE FUNCTION public.top_offers()
RETURNS TABLE(
    id TEXT, -- 1
    name TEXT, -- 2
    wallpaper TEXT, -- 3
    about TEXT, -- 4
    reviews TEXT, -- 5
    rating TEXT -- 6
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
        SELECT * FROM internal.top_offers();
EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
        IF err_code IN ('P0015') THEN
            RETURN QUERY
            -- SELECT 'X'::TEXT, err_msg::TEXT;
            SELECT '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT;
        END IF;

        -- Generic fallback logging
        SELECT internal.log_error_wrapper(
                       err_code,
                       err_msg,
                       'public.top_offers',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        RETURN QUERY
        --SELECT 'X'::TEXT, concat('Something went wrong. ', error_code)::TEXT;
        SELECT '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT;

END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION public.top_offers() FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION public.top_offers() TO authenticated;

-- SUBTASK 12.3 Recently added courses

CREATE OR REPLACE FUNCTION public.recently_added_courses()
RETURNS TABLE(
    id TEXT, -- 1
    name TEXT, -- 2
    code TEXT, -- 3
    semester TEXT, -- 4
    wallpaper TEXT, -- 5
    lessons TEXT, -- 6
    progress TEXT -- 7
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
        SELECT * FROM internal.recently_added_courses();
EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
        IF err_code IN ('P0015') THEN
            RETURN QUERY
            -- SELECT 'X'::TEXT, err_msg::TEXT;
            SELECT '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT;
        END IF;

        -- Generic fallback logging
        SELECT internal.log_error_wrapper(
                       err_code,
                       err_msg,
                       'public.recently_added_courses',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        RETURN QUERY
        --SELECT 'X'::TEXT, concat('Something went wrong. ', error_code)::TEXT;
        SELECT '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT;

END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION public.recently_added_courses() FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION public.recently_added_courses() TO authenticated;

-- SUBTASK 12.4 Recent work/course interacted

CREATE OR REPLACE FUNCTION public.get_last_course_interaction()
RETURNS TABLE(
    id TEXT, -- 1
    name TEXT, -- 2
    code TEXT, -- 3
    semester TEXT, -- 4
    wallpaper TEXT, -- 5
    lessons TEXT, -- 6
    progress TEXT -- 7
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
        SELECT * FROM internal.get_last_course_interaction();
EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
        IF err_code IN ('P0015') THEN
            RETURN QUERY
            -- SELECT 'X'::TEXT, err_msg::TEXT;
            SELECT '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT;
        END IF;

        -- Generic fallback logging
        SELECT internal.log_error_wrapper(
                       err_code,
                       err_msg,
                       'public.get_last_course_interaction',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        RETURN QUERY
        --SELECT 'X'::TEXT, concat('Something went wrong. ', error_code)::TEXT;
        SELECT '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT;

END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION public.get_last_course_interaction() FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION public.get_last_course_interaction() TO authenticated;



-- TASK 13. EXPLORE PROGRAMS

CREATE OR REPLACE FUNCTION public.get_certificate(IN p_certificate_id TEXT)
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
    result := internal.get_certificate( p_certificate_id );

    RETURN jsonb_build_object(
                'status', 'success',
                'message', result
            );
EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
        IF err_code IN ('P0043', 'P0010','P0065') THEN
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
                       'public.get_certificate',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        -- RETURN concat('Something went wrong. ', error_code);
        RETURN jsonb_build_object(
                'status', 'error',
                'message', concat('Something went wrong. ', error_code)
            );

END;
$$;
REVOKE ALL ON FUNCTION public.get_certificate(IN p_certificate_id TEXT)  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_certificate(IN p_certificate_id TEXT) TO authenticated;