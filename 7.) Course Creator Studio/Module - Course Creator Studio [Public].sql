-----------------------------------------------------------------------------------------------
------------------------------- PUBLIC SCHEMA -----------------------------------------------


------------------------------------------------------------------------------------------------------------------------
-- TASK 1).View Assigned Courses                                                                    STATUS: _DEVELOPED

CREATE OR REPLACE FUNCTION public.my_assigned_courses()
RETURNS TABLE(
    id TEXT, -- 1
    code TEXT, -- 2
    course TEXT, -- 3
    units TEXT, -- 4
    students TEXT, -- 5
    rating TEXT, -- 6
    likes TEXT, -- 7
    semester TEXT, -- 8
    duration TEXT, -- 9
    assigned_at TEXT, -- 10
    assigned_by TEXT, -- 11
    status TEXT, -- 12
    wallpaper TEXT -- 13
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
        SELECT * FROM internal.my_assigned_courses();
EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
        IF err_code IN ('P0015') THEN
            RETURN QUERY
            -- SELECT 'X'::TEXT, err_msg::TEXT;
            SELECT '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT,
                   '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT,
                   '*'::TEXT, '*'::TEXT, '*'::TEXT;
        END IF;

        -- Generic fallback logging
        SELECT internal.log_error_wrapper(
                       err_code,
                       err_msg,
                       'public.my_assigned_courses',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        RETURN QUERY
        --SELECT 'X'::TEXT, concat('Something went wrong. ', error_code)::TEXT;
        SELECT  '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT,
                '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT,
                '*'::TEXT, '*'::TEXT, '*'::TEXT;

END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION public.my_assigned_courses() FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION public.my_assigned_courses() TO authenticated;


--- SUBTASK 1.1.1 View Feedback           STATUS: _DEVELOPED

CREATE OR REPLACE FUNCTION public.view_feedback(IN p_my_assigned_course_id TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    error_code TEXT;
    err_code TEXT;
    err_msg TEXT;
    result TEXT;
BEGIN
    -- Call the internal implementation
    result := internal.view_feedback(p_my_assigned_course_id);

    RETURN jsonb_build_object(
                'status', 'success',
                'message', result
            );
EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
        IF err_code IN ('P0010','P1000','P0051','P0050') THEN
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
                       'public.view_feedback',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        -- RETURN concat('Something went wrong. ', error_code);
        RETURN jsonb_build_object(
                'status', 'error',
                'message', concat('Something went wrong. ', error_code)
            );

END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION public.view_feedback(IN p_my_assigned_course_id TEXT) FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION public.view_feedback(IN p_my_assigned_course_id TEXT) TO authenticated;




--- SUBTASK 1.2.1 Get Data of Phase 1: Basics (e.g. lessons, wallpaper, syllabus, and etc)            STATUS: _DEVELOPED

CREATE OR REPLACE FUNCTION public.get_phase1_data(IN p_my_assigned_course_id TEXT)
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
    result := internal.get_phase1_data(p_my_assigned_course_id);

    RETURN jsonb_build_object(
                'status', 'success',
                'message', result
            );
EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
        IF err_code IN ('P0010','P1000','P0051','P0050') THEN
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
                       'public.get_phase1_data',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        -- RETURN concat('Something went wrong. ', error_code);
        RETURN jsonb_build_object(
                'status', 'error',
                'message', concat('Something went wrong. ', error_code)
            );

END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION public.get_phase1_data(IN p_my_assigned_course_id TEXT) FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION public.get_phase1_data(IN p_my_assigned_course_id TEXT) TO authenticated;


--- SUBTASK 1.2.2 Get Data of Phase 2: Course Assessment percentage                                   STATUS: _DEVELOPED

CREATE OR REPLACE FUNCTION public.get_phase2_data(IN p_my_assigned_course_id TEXT)
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
    result := internal.get_phase2_data(p_my_assigned_course_id);

    RETURN jsonb_build_object(
                'status', 'success',
                'message', result
            );
EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
        IF err_code IN ('P0010','P1000','P0051','P0050') THEN
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
                       'public.get_phase2_data',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        -- RETURN concat('Something went wrong. ', error_code);
        RETURN jsonb_build_object(
                'status', 'error',
                'message', concat('Something went wrong. ', error_code)
            );

END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION public.get_phase2_data(IN p_my_assigned_course_id TEXT) FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION public.get_phase2_data(IN p_my_assigned_course_id TEXT) TO authenticated;


--- SUBTASK 1.2.3 Get Data of Phase 3: Course Materials (e.g. videos, additional reading materials)   STATUS: _DEVELOPED

CREATE OR REPLACE FUNCTION public.get_phase3_data(IN p_my_assigned_course_id TEXT)
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
    result := internal.get_phase3_data(p_my_assigned_course_id);

    RETURN jsonb_build_object(
                'status', 'success',
                'message', result
            );
EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
        IF err_code IN ('P0010','P1000','P0051','P0050') THEN
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
                       'public.get_phase3_data',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        -- RETURN concat('Something went wrong. ', error_code);
        RETURN jsonb_build_object(
                'status', 'error',
                'message', concat('Something went wrong. ', error_code)
            );

END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION public.get_phase3_data(IN p_my_assigned_course_id TEXT) FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION public.get_phase3_data(IN p_my_assigned_course_id TEXT) TO authenticated;


--- SUBTASK 1.2.4 Get Data of Phase 4: Assignments/Activities                                         STATUS: _DEVELOPED

CREATE OR REPLACE FUNCTION public.get_phase4_data(IN p_my_assigned_course_id TEXT)
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
    result := internal.get_phase4_data(p_my_assigned_course_id);

    RETURN jsonb_build_object(
                'status', 'success',
                'message', result
            );
EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
        IF err_code IN ('P0010','P1000','P0051','P0050') THEN
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
                       'public.get_phase4_data',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        -- RETURN concat('Something went wrong. ', error_code);
        RETURN jsonb_build_object(
                'status', 'error',
                'message', concat('Something went wrong. ', error_code)
            );

END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION public.get_phase4_data(IN p_my_assigned_course_id TEXT) FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION public.get_phase4_data(IN p_my_assigned_course_id TEXT) TO authenticated;

--- SUBTASK 1.2.4 Get Data of Phase 4: Assignments/Activities                                         STATUS: _DEVELOPED

CREATE OR REPLACE FUNCTION public.get_phase5_data(IN p_my_assigned_course_id TEXT)
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
    result := internal.get_phase5_data(p_my_assigned_course_id);

    RETURN jsonb_build_object(
                'status', 'success',
                'message', result
            );
EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
        IF err_code IN ('P0010','P1000','P0051','P0050') THEN
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
                       'public.get_phase5_data',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        -- RETURN concat('Something went wrong. ', error_code);
        RETURN jsonb_build_object(
                'status', 'error',
                'message', concat('Something went wrong. ', error_code)
            );

END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION public.get_phase5_data(IN p_my_assigned_course_id TEXT) FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION public.get_phase5_data(IN p_my_assigned_course_id TEXT) TO authenticated;



--- SUBTASK 1.3.1 Choose course to clone                                                              STATUS: _DEVELOPED

CREATE OR REPLACE FUNCTION public.get2clone_media(IN p_my_target_course_id TEXT)
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
    result := internal.get2clone_media(p_my_target_course_id);

    RETURN jsonb_build_object(
                'status', 'success',
                'message', result
            );
EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
        IF err_code IN ('P0010','P1000','P0051','P0050','P0061') THEN
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
                       'public.get2clone_media',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        -- RETURN concat('Something went wrong. ', error_code);
        RETURN jsonb_build_object(
                'status', 'error',
                'message', concat('Something went wrong. ', error_code)
            );

END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION public.get2clone_media(IN p_my_target_course_id TEXT) FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION public.get2clone_media(IN p_my_target_course_id TEXT) TO authenticated;


--- SUBTASK 1.3.2 Begin Cloning                                                             STATUS: _DEVELOPED

CREATE OR REPLACE FUNCTION public.clone_course(
    IN p_my_assigned_course_id TEXT,
    IN p_trace_id TEXT
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
    CALL internal.clone_course(
         p_my_assigned_course_id,p_trace_id
         );

    -- RETURN '✅ Program successfully created.';
    RETURN jsonb_build_object(
        'status', 'success',
        'message', '✅ Course cloned successfully'
    );

EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        IF err_code IN ('P0010', 'P1000', 'P0062', 'P0051', 'P0050') THEN
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
                               'public.clone_course',
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
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION public.clone_course(
    IN p_my_assigned_course_id TEXT,
    IN p_trace_id TEXT
) FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION public.clone_course(
    IN p_my_assigned_course_id TEXT,
    IN p_trace_id TEXT
) TO authenticated;



select * from internal.error_log where code = 'HVK-3AADC53C'



-- TASK 2). Manage Assigned Courses


--- SUBTASK 2.1.1 Setup Basics and create lessons                                                      STATUS: _DEVELOPED

CREATE OR REPLACE FUNCTION public.build_course_lessons(
    IN p_my_assigned_course_id TEXT,
    IN p_about TEXT,
    IN p_wallpaper_id UUID,
    IN p_syllabus_id UUID,
    IN p_lessons JSONB
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
    CALL internal.build_course_lessons(
         p_my_assigned_course_id,
         p_about,
         p_wallpaper_id,
         p_syllabus_id,
         p_lessons
         );

    -- RETURN '✅ Program successfully created.';
    RETURN jsonb_build_object(
        'status', 'success',
        'message', '✅ Basics successfully created.'
    );

EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        BEGIN
            call internal.file_rollback_phase1(p_wallpaper_id, 'course-wallpaper', null);
            call internal.file_rollback_phase1(p_syllabus_id, 'course-materials', 'syllabus');

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
                ELSE
                    -- Generic fallback logging
                    SELECT internal.log_error_wrapper(
                                   err_code2,
                                   err_msg2,
                                   'internal.file_rollback',
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
        IF err_code IN ('P0010', 'P1000', 'P0051', 'P0050', 'P0035') THEN
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
                               'public.build_course_lessons',
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
REVOKE ALL ON FUNCTION public.build_course_lessons(
    IN p_my_assigned_course_id TEXT,
    IN p_about TEXT,
    IN p_wallpaper_id UUID,
    IN p_syllabus_id UUID,
    IN p_lessons JSONB
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.build_course_lessons(
    IN p_my_assigned_course_id TEXT,
    IN p_about TEXT,
    IN p_wallpaper_id UUID,
    IN p_syllabus_id UUID,
    IN p_lessons JSONB
) TO authenticated;


--- TASK 2.2. Setup Assessments and corresponding Weight

---- SUBTASK 2.2.1 Get Assessment types                                                             STATUS: _DEVELOPED

CREATE OR REPLACE FUNCTION public.get_assessment_types()
RETURNS TABLE(
    id TEXT, -- 1
    name TEXT
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
        SELECT * FROM internal.get_assessment_types();
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
                       'public.get_assessment_types',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        RETURN QUERY
        --SELECT 'X'::TEXT, concat('Something went wrong. ', error_code)::TEXT;
        SELECT '*'::TEXT, '*'::TEXT;

END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION public.get_assessment_types() FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION public.get_assessment_types() TO authenticated;


---- SUBTASK 2.2.2 SETUP COURSE ASSESSMENTS                                                         STATUS: _DEVELOPED

CREATE OR REPLACE FUNCTION public.build_course_assessments(
    IN p_my_assigned_course_id TEXT,
    IN p_assessments JSONB
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
    CALL internal.build_course_assessments(
         p_my_assigned_course_id,
         p_assessments
         );

    -- RETURN '✅ Program successfully created.';
    RETURN jsonb_build_object(
        'status', 'success',
        'message', '✅ Course Assessments successfully created.'
    );

EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
        IF err_code IN ('P0010', 'P1000', 'P0051', 'P0050', 'P0035', 'P0052') THEN
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
                       'public.build_course_assessments',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        -- RETURN concat('Something went wrong. ', error_code);
        RETURN jsonb_build_object(
                'status', 'error',
                'message', concat('Something went wrong. ', error_code)
            );

END;
$$;
REVOKE ALL ON FUNCTION public.build_course_assessments(
    IN p_my_assigned_course_id TEXT,
    IN p_assessments JSONB
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.build_course_assessments(
    IN p_my_assigned_course_id TEXT,
    IN p_assessments JSONB
) TO authenticated;


--- TASK 2.3 Upload Course Materials

---- SUBTASK 2.3.1 Get lessons                                                                      STATUS: _DEVELOPED

CREATE OR REPLACE FUNCTION public.get_lessons(IN p_my_assigned_course_id TEXT)
RETURNS TABLE(
    id TEXT, -- 1
    name TEXT
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
        SELECT * FROM internal.get_lessons(p_my_assigned_course_id);
EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
        IF err_code IN ('P1000') THEN
            RETURN QUERY
            -- SELECT 'X'::TEXT, err_msg::TEXT;
            SELECT '*'::TEXT, '*'::TEXT;
        END IF;

        -- Generic fallback logging
        SELECT internal.log_error_wrapper(
                       err_code,
                       err_msg,
                       'public.get_lessons',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        RETURN QUERY
        --SELECT 'X'::TEXT, concat('Something went wrong. ', error_code)::TEXT;
        SELECT '*'::TEXT, '*'::TEXT;

END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION public.get_lessons(IN p_my_assigned_course_id TEXT) FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION public.get_lessons(IN p_my_assigned_course_id TEXT) TO authenticated;


---- SUBTASK 2.3.2 Attach Course Materials UUID                                                     STATUS: _DEVELOPED

CREATE OR REPLACE FUNCTION public.build_course_materials(
    IN p_contents JSONB
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
    CALL internal.build_course_materials(
         p_contents
         );

    -- RETURN '✅ Program successfully created.';
    RETURN jsonb_build_object(
        'status', 'success',
        'message', '✅ Course Materials successfully added.'
    );

EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        BEGIN
            call internal.course_materials_file_rollback(p_contents);
            -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
            IF err_code IN ('P0010', 'P0035', 'P1000', 'P0051', 'P0050') THEN
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
                               'public.build_course_materials',
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
                IF err_code2 IN ('P0010','P0035') THEN
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
                                   'internal.course_materials_file_rollback',
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
REVOKE ALL ON FUNCTION public.build_course_materials(
    IN p_contents JSONB
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.build_course_materials(
    IN p_contents JSONB
) TO authenticated;


--- 2.4 Add Assessment: Assignments

---- SUBTASK 2.4.1 get Structured Assessments                                                       STATUS: _DEVELOPED

CREATE OR REPLACE FUNCTION public.get_structured_assessments (IN p_my_assigned_course_id TEXT)
RETURNS TABLE(
    id TEXT, -- 1
    name TEXT
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
        SELECT * FROM internal.get_structured_assessments(p_my_assigned_course_id);
EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
        IF err_code IN ('P1000') THEN
            RETURN QUERY
            -- SELECT 'X'::TEXT, err_msg::TEXT;
            SELECT '*'::TEXT, '*'::TEXT;
        END IF;

        -- Generic fallback logging
        SELECT internal.log_error_wrapper(
                       err_code,
                       err_msg,
                       'public.get_structured_assessments',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        RETURN QUERY
        --SELECT 'X'::TEXT, concat('Something went wrong. ', error_code)::TEXT;
        SELECT '*'::TEXT, '*'::TEXT;

END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION public.get_structured_assessments (IN p_my_assigned_course_id TEXT) FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION public.get_structured_assessments (IN p_my_assigned_course_id TEXT) TO authenticated;



---- SUBTASK 2.4.2 Structure assignments                                                           STATUS: _DEVELOPED

CREATE OR REPLACE FUNCTION public.build_course_assignments(
    IN p_assignments JSONB
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
    CALL internal.build_course_assignments(
         p_assignments
         );

    -- RETURN '✅ Program successfully created.';
    RETURN jsonb_build_object(
        'status', 'success',
        'message', '✅ Course Assignments successfully added.'
    );

EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
        IF err_code IN ('P0010', 'P0043', 'P1000', 'P0051', 'P0050', 'P0035') THEN
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
                       'public.build_course_assignments',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        -- RETURN concat('Something went wrong. ', error_code);
        RETURN jsonb_build_object(
                'status', 'error',
                'message', concat('Something went wrong. ', error_code)
            );

END;
$$;
REVOKE ALL ON FUNCTION public.build_course_assignments(
    IN p_assignments JSONB
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.build_course_assignments(
    IN p_assignments JSONB
) TO authenticated;



--- TASK 2.5 Add Assessment: Quizes or Exams

---- SUBTASK 2.5.1 get answer types                                                                STATUS: _DEVELOPED

CREATE OR REPLACE FUNCTION public.get_answer_types()
RETURNS TABLE(
    id TEXT, -- 1
    name TEXT
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
        SELECT * FROM internal.get_answer_types();
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
                       'public.get_answer_types',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        RETURN QUERY
        --SELECT 'X'::TEXT, concat('Something went wrong. ', error_code)::TEXT;
        SELECT '*'::TEXT, '*'::TEXT;

END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION public.get_answer_types () FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION public.get_answer_types () TO authenticated;


---- SUBTASK 2.5.2 Add tests                                                                        STATUS: _DEVELOPED

CREATE OR REPLACE FUNCTION public.build_course_tests(
    IN p_tests JSONB
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
    CALL internal.build_course_tests(
         p_tests
         );

    -- RETURN '✅ Program successfully created.';
    RETURN jsonb_build_object(
        'status', 'success',
        'message', '✅ Tests successfully added.'
    );

EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        IF err_code IN ('P0010', 'P0043', 'P1000', 'P0051', 'P0050' , 'P0035') THEN
            RETURN jsonb_build_object(
                'status', 'warning',
                'message', err_msg
            );
        ELSE
            BEGIN
                SELECT internal.log_error_wrapper(
                           err_code,
                           err_msg,
                           'public.build_course_tests',
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
REVOKE ALL ON FUNCTION public.build_course_tests(
    IN p_tests JSONB
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.build_course_tests(
    IN p_tests JSONB
) TO authenticated;




--- TASK 3. Submit Course for Review [Pre-Publish]                                                  STATUS: _DEVELOPED

CREATE OR REPLACE FUNCTION public.submit_course_for_review(
    IN p_my_assigned_course_id TEXT
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
    CALL internal.submit_course_for_review(
         p_my_assigned_course_id
         );

    -- RETURN '✅ Program successfully created.';
    RETURN jsonb_build_object(
        'status', 'success',
        'message', '✅ Course successfully submitted for review. Please wait for approval.'
    );

EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        IF err_code IN ('P0010', 'P1000', 'P0051', 'P0050', 'P0059') THEN
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
                               'public.submit_course_for_review',
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
REVOKE ALL ON FUNCTION public.submit_course_for_review(
    IN p_my_assigned_course_id TEXT
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_course_for_review(
    IN p_my_assigned_course_id TEXT
) TO authenticated;




-- TASK 4. Enroll a student with COR upload                                                         STATUS: _DEVELOPED

CREATE OR REPLACE FUNCTION public.enroll_with_cor(
    IN p_my_assigned_course_id TEXT,
    IN p_student_email TEXT,
    IN p_cor_id UUID
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
    CALL internal.enroll_with_cor(
         p_my_assigned_course_id,
         p_student_email,
         p_cor_id
         );

    -- RETURN '✅ Program successfully created.';
    RETURN jsonb_build_object(
        'status', 'success',
        'message', '✅ Student successfully enrolled.'
    );

EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;
        BEGIN
            call internal.file_rollback(p_cor_id, 'enrollment-docs', 'cor/');
        EXCEPTION
            WHEN OTHERS THEN
                GET STACKED DIAGNOSTICS err_code2 = RETURNED_SQLSTATE,
                                        err_msg2 = MESSAGE_TEXT;

                IF err_code2 IN ('P0010') THEN
                    RETURN jsonb_build_object(
                        'status', 'warning',
                        'message', err_msg2
                    );
                ELSE
                    BEGIN
                        SELECT internal.log_error_wrapper(
                                   err_code,
                                   err_msg,
                                   'public.file_rollback',
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

        IF err_code IN ('P0010', 'P1000','P0051' ,'P0053','P0054','P0050','P0035','P0014') THEN
            RETURN jsonb_build_object(
                'status', 'warning',
                'message', err_msg
            );
        ELSE
            BEGIN
                SELECT internal.log_error_wrapper(
                           err_code,
                           err_msg,
                           'public.enroll_with_cor',
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
REVOKE ALL ON FUNCTION public.enroll_with_cor(
    IN p_my_assigned_course_id TEXT,
    IN p_student_email TEXT,
    IN p_cor_id UUID
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.enroll_with_cor(
    IN p_my_assigned_course_id TEXT,
    IN p_student_email TEXT,
    IN p_cor_id UUID
) TO authenticated;



--- TASK 5. Remove Items in Creator Studio                                                          STATUS: _DEVELOPED

---- SUBTASK 5.1 Remove Wallpaper   STATUS: _DEVELOPED

CREATE OR REPLACE FUNCTION public.phase1_remove_wallpaper(IN p_wallpaper_iid TEXT)
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
    CALL internal.phase1_remove_wallpaper(
         p_wallpaper_iid
         );

    -- RETURN '✅ Program successfully created.';
    RETURN jsonb_build_object(
        'status', 'success',
        'message', '✅ Course wallpaper removed successfully'
    );

EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        IF err_code IN ('P0010', 'P1000', 'P0051', 'P0050') THEN
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
                               'public.phase1_remove_wallpaper',
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
REVOKE ALL ON FUNCTION public.phase1_remove_wallpaper(IN p_wallpaper_iid TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.phase1_remove_wallpaper(IN p_wallpaper_iid TEXT) TO authenticated;

---- SUBTASK 5.2 Remove Syllabus    STATUS: _DEVELOPED

CREATE OR REPLACE FUNCTION public.phase1_remove_syllabus(IN p_syllabus_iid TEXT)
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
    CALL internal.phase1_remove_syllabus(
         p_syllabus_iid
         );

    -- RETURN '✅ Program successfully created.';
    RETURN jsonb_build_object(
        'status', 'success',
        'message', '✅ Course syllabus removed successfully'
    );

EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        IF err_code IN ('P0010', 'P1000', 'P0051', 'P0050') THEN
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
                               'public.phase1_remove_syllabus',
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
REVOKE ALL ON FUNCTION public.phase1_remove_syllabus(IN p_syllabus_iid TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.phase1_remove_syllabus(IN p_syllabus_iid TEXT) TO authenticated;


---- SUBTASK 5.3 Remove Lesson  STATUS: _DEVELOPED

CREATE OR REPLACE FUNCTION public.phase1_attempt_remove_lesson(IN p_lesson_id TEXT)
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
    result := internal.phase1_attempt_remove_lesson( p_lesson_id );

    -- RETURN '✅ Program successfully created.';
    RETURN jsonb_build_object(
        'status', 'success',
        'message', result
    );

EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        IF err_code IN ('P0010', 'P1000', 'P0051', 'P0050') THEN
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
                               'public.phase1_attempt_remove_lesson',
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
REVOKE ALL ON FUNCTION public.phase1_attempt_remove_lesson(IN p_lesson_id TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.phase1_attempt_remove_lesson(IN p_lesson_id TEXT) TO authenticated;


CREATE OR REPLACE FUNCTION public.phase1_confirm_remove_lesson(IN p_confirmation_id TEXT)
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
    CALL internal.phase1_confirm_remove_lesson(
         p_confirmation_id
         );

    -- RETURN '✅ Program successfully created.';
    RETURN jsonb_build_object(
        'status', 'success',
        'message', '✅ Course Lesson removed successfully'
    );

EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        IF err_code IN ('P0010', 'P0035', 'P0044', 'P0050') THEN
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
                               'public.phase1_confirm_remove_lesson',
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
REVOKE ALL ON FUNCTION public.phase1_confirm_remove_lesson(IN p_confirmation_id TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.phase1_confirm_remove_lesson(IN p_confirmation_id TEXT) TO authenticated;



---- SUBTASK 5.4 Remove Course Assessment   STATUS: _DEVELOPED

CREATE OR REPLACE FUNCTION public.phase2_remove_course_assessment(IN p_course_assessment_id TEXT)
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
    CALL internal.phase2_remove_course_assessment(
         p_course_assessment_id
         );

    -- RETURN '✅ Program successfully created.';
    RETURN jsonb_build_object(
        'status', 'success',
        'message', '✅ Course Assessment removed successfully'
    );

EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        IF err_code IN ('P0010', 'P1000', 'P0051', 'P0050') THEN
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
                               'public.phase2_remove_course_assessment',
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
REVOKE ALL ON FUNCTION public.phase2_remove_course_assessment(IN p_course_assessment_id TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.phase2_remove_course_assessment(IN p_course_assessment_id TEXT) TO authenticated;


---- SUBTASK 5.5 Remove Course Material (e.g. Video, additional material, and links)    STATUS: _DEVELOPED

CREATE OR REPLACE FUNCTION public.phase3_remove_course_material(IN p_material_id TEXT)
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
    CALL internal.phase3_remove_course_material(
         p_material_id
         );

    -- RETURN '✅ Program successfully created.';
    RETURN jsonb_build_object(
        'status', 'success',
        'message', '✅ Course Material removed successfully'
    );

EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        IF err_code IN ('P0010', 'P1000', 'P0051', 'P0050') THEN
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
                               'public.phase3_remove_course_material',
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
REVOKE ALL ON FUNCTION public.phase3_remove_course_material(IN p_material_id TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.phase3_remove_course_material(IN p_material_id TEXT)  TO authenticated;


---- SUBTASK 5.6 Assignment STATUS: _DEVELOPED

CREATE OR REPLACE FUNCTION public.phase4_remove_assignment(IN p_assignment_id TEXT)
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
    CALL internal.phase4_remove_assignment(
         p_assignment_id
         );

    -- RETURN '✅ Program successfully created.';
    RETURN jsonb_build_object(
        'status', 'success',
        'message', '✅ Course Assignment removed successfully'
    );

EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        IF err_code IN ('P0010', 'P1000', 'P0051', 'P0050') THEN
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
                               'public.phase4_remove_assignment',
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
REVOKE ALL ON FUNCTION public.phase4_remove_assignment(IN p_assignment_id TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.phase4_remove_assignment(IN p_assignment_id TEXT)  TO authenticated;




---- SUBTASK 5.7.1 Remove Test  STATUS: _DEVELOPED

CREATE OR REPLACE FUNCTION public.phase5_attempt_remove_test(IN p_test_id TEXT)
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
    result := internal.phase5_attempt_remove_test( p_test_id );

    -- RETURN '✅ Program successfully created.';
    RETURN jsonb_build_object(
        'status', 'success',
        'message', result
    );

EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        IF err_code IN ('P0010', 'P1000', 'P0051', 'P0050') THEN
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
                               'public.phase5_attempt_remove_test',
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
REVOKE ALL ON FUNCTION public.phase5_attempt_remove_test(IN p_test_id TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.phase5_attempt_remove_test(IN p_test_id TEXT) TO authenticated;

CREATE OR REPLACE FUNCTION public.phase5_confirm_remove_test(IN p_confirmation_id TEXT)
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
    CALL internal.phase5_confirm_remove_test(
         p_confirmation_id
         );

    -- RETURN '✅ Program successfully created.';
    RETURN jsonb_build_object(
        'status', 'success',
        'message', '✅ Course Test removed successfully'
    );

EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        IF err_code IN ('P0010', 'P0035', 'P0044', 'P0050') THEN
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
                               'public.phase5_confirm_remove_test',
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
REVOKE ALL ON FUNCTION public.phase5_confirm_remove_test(IN p_confirmation_id TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.phase5_confirm_remove_test(IN p_confirmation_id TEXT) TO authenticated;



---- SUBTASK 5.7.2 Remove Question  STATUS: _DEVELOPED

CREATE OR REPLACE FUNCTION public.phase5_remove_question(IN p_question_id TEXT)
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
    CALL internal.phase5_remove_question(
         p_question_id
         );

    -- RETURN '✅ Program successfully created.';
    RETURN jsonb_build_object(
        'status', 'success',
        'message', '✅ Test question removed successfully'
    );

EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        IF err_code IN ('P0010', 'P1000', 'P0051', 'P0050') THEN
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
                               'public.phase5_remove_question',
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
REVOKE ALL ON FUNCTION public.phase5_remove_question(IN p_question_id TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.phase5_remove_question(IN p_question_id TEXT)  TO authenticated;


---- SUBTASK 5.7.3 Remove choice    STATUS: _DEVELOPED

CREATE OR REPLACE FUNCTION public.phase5_remove_choice(IN p_key_id TEXT)
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
    CALL internal.phase5_remove_choice(
         p_key_id
         );

    -- RETURN '✅ Program successfully created.';
    RETURN jsonb_build_object(
        'status', 'success',
        'message', '✅ Item choice removed successfully'
    );

EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        IF err_code IN ('P0010', 'P1000', 'P0051', 'P0050') THEN
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
                               'public.phase5_remove_choice',
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
REVOKE ALL ON FUNCTION public.phase5_remove_choice(IN p_key_id TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.phase5_remove_choice(IN p_key_id TEXT)  TO authenticated;


--- TASK 6. VIEW ENROLLED STUDENTS

CREATE OR REPLACE FUNCTION public.view_enrolled_students2(IN p_course_id TEXT)
RETURNS TABLE(
    id TEXT, -- 1
    avatar TEXT, -- 2
    name TEXT, -- 3
    email TEXT, -- 4
    progress TEXT, -- 5
    enrollment_status TEXT, -- 6
    last_activity TEXT, -- 7
    activity_color TEXT, -- 8
    enrolled_date TEXT, -- 9
    enrolled_by TEXT -- 10
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
        SELECT * FROM internal.view_enrolled_students2(p_course_id);
EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
        IF err_code IN ('P1000') THEN
            RETURN QUERY
            -- SELECT 'X'::TEXT, err_msg::TEXT;
            SELECT '*'::TEXT,'*'::TEXT,'*'::TEXT,'*'::TEXT,'*'::TEXT,'*'::TEXT,'*'::TEXT,'*'::TEXT,'*'::TEXT, '*'::TEXT;
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
        SELECT error_code::TEXT,'*'::TEXT,'*'::TEXT,'*'::TEXT,'*'::TEXT,'*'::TEXT,'*'::TEXT,'*'::TEXT,'*'::TEXT, '*'::TEXT;

END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION public.view_enrolled_students2(IN p_course_id TEXT) FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION public.view_enrolled_students2(IN p_course_id TEXT) TO authenticated;


--- TASK 7. MONITOR STUDENT'S PROGRESS & ASSESSMENTS

---- SUBTAsk 7.1 VIEW STUDENTS VIDEO PROGRESS

CREATE OR REPLACE FUNCTION public.view_video_progress(IN p_video_id TEXT)
RETURNS TABLE(
    id TEXT, -- 1
    avatar TEXT, -- 2
    name TEXT, -- 3
    email TEXT, -- 4
    progress TEXT -- 5
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
        SELECT * FROM internal.view_video_progress(p_video_id);
EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
        IF err_code IN ('P1000') THEN
            RETURN QUERY
            -- SELECT 'X'::TEXT, err_msg::TEXT;
            SELECT '*'::TEXT,'*'::TEXT,'*'::TEXT,'*'::TEXT,'*'::TEXT;
        END IF;

        -- Generic fallback logging
        SELECT internal.log_error_wrapper(
                       err_code,
                       err_msg,
                       'public.view_video_progress',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        RETURN QUERY
        --SELECT 'X'::TEXT, concat('Something went wrong. ', error_code)::TEXT;
        SELECT error_code::TEXT,'*'::TEXT,'*'::TEXT,'*'::TEXT,'*'::TEXT;

END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION public.view_video_progress(IN p_video_id TEXT) FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION public.view_video_progress(IN p_video_id TEXT) TO authenticated;


---- SUBTASK 7.2.1 VIEW STUDENTS ASSIGNMENT PROGRESS

CREATE OR REPLACE FUNCTION public.view_assignment_progress(IN p_assignment_id TEXT)
RETURNS TABLE(
    id TEXT, -- 1
    avatar TEXT, -- 2
    name TEXT, -- 3
    email TEXT, -- 4
    completed TEXT, -- 5
    mark TEXT
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
        SELECT * FROM internal.view_assignment_progress(p_assignment_id);
EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
        IF err_code IN ('P1000') THEN
            RETURN QUERY
            -- SELECT 'X'::TEXT, err_msg::TEXT;
            SELECT '*'::TEXT,'*'::TEXT,'*'::TEXT,'*'::TEXT,'*'::TEXT,'*'::TEXT;
        END IF;

        -- Generic fallback logging
        SELECT internal.log_error_wrapper(
                       err_code,
                       err_msg,
                       'public.view_assignment_progress',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        RETURN QUERY
        --SELECT 'X'::TEXT, concat('Something went wrong. ', error_code)::TEXT;
        SELECT error_code::TEXT,'*'::TEXT,'*'::TEXT,'*'::TEXT,'*'::TEXT,'*'::TEXT;

END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION public.view_assignment_progress(IN p_assignment_id TEXT) FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION public.view_assignment_progress(IN p_assignment_id TEXT) TO authenticated;


---- SUBTASK 7.2.2 VIEW STUDENT'S ASSIGNMENT

CREATE OR REPLACE FUNCTION public.view_student_assignment(IN p_student_assignment_id TEXT)
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
    result := internal.view_student_assignment( p_student_assignment_id );

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
                       'public.view_student_assignment',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        -- RETURN concat('Something went wrong. ', error_code);
        RETURN jsonb_build_object(
                'status', 'error',
                'message', concat('Something went wrong. ', error_code)
            );

END;
$$;
REVOKE ALL ON FUNCTION public.view_student_assignment(IN p_student_assignment_id TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.view_student_assignment(IN p_student_assignment_id TEXT) TO authenticated;

----- SUBTASK 7.2.3 EVALUATE STUDENT'S ASSIGNMENT

CREATE OR REPLACE FUNCTION public.evaluate_student_assignment(IN p_student_assignment_id TEXT, IN p_student_mark INT)
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
    CALL internal.evaluate_student_assignment(
         p_student_assignment_id, p_student_mark
         );

    -- RETURN '✅ Program successfully created.';
    RETURN jsonb_build_object(
        'status', 'success',
        'message', '✅ Assignment successfully evaluated.'
    );

EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        IF err_code IN ('P0010', 'P0064', 'P0035', 'P0050') THEN
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
                               'public.evaluate_student_assignment',
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
REVOKE ALL ON FUNCTION public.evaluate_student_assignment(IN p_student_assignment_id TEXT, IN p_student_mark INT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.evaluate_student_assignment(IN p_student_assignment_id TEXT, IN p_student_mark INT)  TO authenticated;

---- SUBTASK 7.3.1 VIEW STUDENTS EXAM PROGRESS

CREATE OR REPLACE FUNCTION public.view_exam_progress(IN p_exam_id TEXT)
RETURNS TABLE(
    id TEXT, -- 1
    avatar TEXT, -- 2
    name TEXT, -- 3
    email TEXT, -- 4
    completed TEXT -- 5
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
        SELECT * FROM internal.view_exam_progress(p_exam_id);
EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
        IF err_code IN ('P1000', 'P0035') THEN
            RETURN QUERY
            -- SELECT 'X'::TEXT, err_msg::TEXT;
            SELECT '*'::TEXT,'*'::TEXT,'*'::TEXT,'*'::TEXT,'*'::TEXT;
        END IF;

        -- Generic fallback logging
        SELECT internal.log_error_wrapper(
                       err_code,
                       err_msg,
                       'public.view_exam_progress',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        RETURN QUERY
        --SELECT 'X'::TEXT, concat('Something went wrong. ', error_code)::TEXT;
        SELECT error_code::TEXT,'*'::TEXT,'*'::TEXT,'*'::TEXT,'*'::TEXT;

END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION public.view_exam_progress(IN p_exam_id TEXT) FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION public.view_exam_progress(IN p_exam_id TEXT) TO authenticated;

---- SUBTASK 7.3.2 VIEW STUDENTS EXAM ATTEMPTS

CREATE OR REPLACE FUNCTION public.view_student_attempts(IN p_student_exam_id TEXT)
RETURNS TABLE(
    id TEXT, -- 1
    attempt_no TEXT, -- 2
    "time" TEXT, -- 3
    score TEXT, -- 4
    status TEXT -- 5
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
        SELECT * FROM internal.view_student_attempts(p_student_exam_id);
EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
        IF err_code IN ('P1000', 'P0035') THEN
            RETURN QUERY
            -- SELECT 'X'::TEXT, err_msg::TEXT;
            SELECT '*'::TEXT,'*'::TEXT,'*'::TEXT,'*'::TEXT,'*'::TEXT;
        END IF;

        -- Generic fallback logging
        SELECT internal.log_error_wrapper(
                       err_code,
                       err_msg,
                       'public.view_student_attempts',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        RETURN QUERY
        --SELECT 'X'::TEXT, concat('Something went wrong. ', error_code)::TEXT;
        SELECT error_code::TEXT,'*'::TEXT,'*'::TEXT,'*'::TEXT,'*'::TEXT;

END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION public.view_student_attempts(IN p_student_exam_id TEXT) FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION public.view_student_attempts(IN p_student_exam_id TEXT) TO authenticated;


---- SUBTASK 7.3.3 VIEW STUDENT'S EXAM answers

CREATE OR REPLACE FUNCTION public.view_students_exam_result(IN p_student_attempt_id TEXT)
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
--     -- Main procedure call
--     CALL internal.view_students_exam_result(
--          p_student_attempt_id
--          );

    -- RETURN '✅ Program successfully created.';
    RETURN jsonb_build_object(
        'status', 'success',
        'message', internal.view_students_exam_result(
         p_student_attempt_id
         )
    );

EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        IF err_code IN ('P0035') THEN
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
                               'public.view_students_exam_result',
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
REVOKE ALL ON FUNCTION public.view_students_exam_result(IN p_student_attempt_id TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.view_students_exam_result(IN p_student_attempt_id TEXT) TO authenticated;

----- SUBTASK 7.3.4 EVALUATE STUDENT'S essay answer

CREATE OR REPLACE FUNCTION public.evaluate_student_essay(IN p_student_answer_id TEXT, IN p_student_mark INT)
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
    CALL internal.evaluate_student_essay(
         p_student_answer_id, p_student_mark
         );

    -- RETURN '✅ Program successfully created.';
    RETURN jsonb_build_object(
        'status', 'success',
        'message', '✅ Essay successfully evaluated.'
    );

EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        IF err_code IN ('P0010', 'P0064', 'P0035', 'P0050') THEN
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
                               'public.evaluate_student_essay',
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
REVOKE ALL ON FUNCTION public.evaluate_student_essay(IN p_student_answer_id TEXT, IN p_student_mark INT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.evaluate_student_essay(IN p_student_answer_id TEXT, IN p_student_mark INT)  TO authenticated;

-- TASK 8.1) LIST OF ALL STUDENTS UNDER FACULTY WHO ARE ASSIGNED TO COMPREHENSIVE EXAM

CREATE OR REPLACE FUNCTION public.view_compre_ready_students()
RETURNS TABLE(
    id TEXT, -- 1
    avatar TEXT, -- 2
    name TEXT, -- 3
    email TEXT, -- 4
    program TEXT, -- 5
    course TEXT, -- 6
    grade TEXT, -- 7
    tentative_date TEXT, -- 8
    status TEXT -- 9
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
        SELECT * FROM internal.view_compre_ready_students();
EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        -- Optional: handle specific internal RAISEs like P0002, P0003, etc.
        IF err_code IN ('P0015') THEN
            RETURN QUERY
            -- SELECT 'X'::TEXT, err_msg::TEXT;
            SELECT err_msg::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT,'*'::TEXT,'*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT;
        END IF;

        -- Generic fallback logging
        SELECT internal.log_error_wrapper(
                       err_code,
                       err_msg,
                       'public.view_compre_ready_students',
                       jsonb_build_object('sqlerrm', SQLERRM)
               ) INTO error_code;

        RETURN QUERY
        --SELECT 'X'::TEXT, concat('Something went wrong. ', error_code)::TEXT;
        SELECT error_code::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT, '*'::TEXT;

END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION public.view_compre_ready_students() FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION public.view_compre_ready_students() TO authenticated;

-- TASK 8.1.1 TO CONFIRM STUDENT IF ALREADY TAKEN THE COMPREHENSIVE EXAM [faculty]

CREATE OR REPLACE FUNCTION public.confirm_student(IN p_student_id TEXT)
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
    CALL internal.confirm_student(
         p_student_id
         );

    -- RETURN '✅ Program successfully created.';
    RETURN jsonb_build_object(
        'status', 'success',
        'message', '✅ Student''s requirements confirmed.'
    );

EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        IF err_code IN ('P0010','P0035','P0050') THEN
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
                               'public.confirm_student',
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
REVOKE ALL ON FUNCTION public.confirm_student(IN p_student_id TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.confirm_student(IN p_student_id TEXT) TO authenticated;

-- TASK 8.1.2 RESCHEDULE COMPREHENSIVE EXAM DATE [dean]

CREATE OR REPLACE FUNCTION public.resched_compre_date(IN p_student_id TEXT, IN p_selected_date TIMESTAMPTZ)
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
    CALL internal.resched_compre_date(
         p_student_id, p_selected_date
         );

    -- RETURN '✅ Program successfully created.';
    RETURN jsonb_build_object(
        'status', 'success',
        'message', '✅ Tentative date rescheduled successfully.'
    );

EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS err_code = RETURNED_SQLSTATE,
                                 err_msg = MESSAGE_TEXT;

        IF err_code IN ('P0010','P0035') THEN
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
                               'public.resched_compre_date',
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
REVOKE ALL ON FUNCTION public.resched_compre_date(IN p_student_id TEXT, IN p_selected_date TIMESTAMPTZ) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.resched_compre_date(IN p_student_id TEXT, IN p_selected_date TIMESTAMPTZ) TO authenticated;