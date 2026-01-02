-- RECOMMENDED PATTERN
-- ✅ Example: Secure function template
-- CREATE OR REPLACE FUNCTION internal.get_secret_key()
-- RETURNS TEXT
-- LANGUAGE plpgsql
-- SECURITY DEFINER
-- AS $$
-- BEGIN
--   RETURN '🔐-TOP-SECRET-KEY';
-- END;
-- $$;
--
-- -- 🚫 Revoke public access
-- REVOKE ALL ON FUNCTION internal.get_secret_key() FROM PUBLIC;
--
-- -- ✅ Grant only to trusted internal role
-- GRANT EXECUTE ON FUNCTION internal.get_secret_key() TO internal_ops;

-----------------------------------------------------------------------------------------------
-- TODO: Add an index on users(email)
-- FIXME: This JOIN might be too slow
-- BUG: Fails when request_payload is null
-- NOTE: Faculty can unsubmit pending approval
-- STATUS: Condition or state of the development

-----------------------------------------------------------------------------------------------
------------------------------- INTERNAL SCHEMA -----------------------------------------------


------------------------------------------------------------------------------------------------------------------------
-- TASK 1).View Assigned Courses                                                                    STATUS: _DEVELOPED

CREATE OR REPLACE FUNCTION internal.my_assigned_courses()
RETURNS TABLE(
    id TEXT, -- 1
    code TEXT, -- 2
    course TEXT, -- 3
    units TEXT, -- 4
    students TEXT,
    rating TEXT,
    likes TEXT,
    semester TEXT, -- 5
    duration TEXT, -- 6
    assigned_at TEXT, -- 7
    assigned_by TEXT, -- 8
    status TEXT, -- 9
    wallpaper TEXT -- 10
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
BEGIN
    -- Only run main query if key exists and confirm the user role
    IF (
        (SELECT check_user_role(ARRAY['faculty'])) = TRUE AND
        internal.get_secret_key('my_assigned_courses') IS NOT NULL) THEN
        RETURN QUERY
            SELECT
            -- 1.) ID (encrypted)
            encode(
                pgp_sym_encrypt(
                    jsonb_build_object(
                        'version_id', cvf.version_id::INT,
                        'status',   CASE
                                        WHEN (COALESCE(COUNT(l.lesson_id), 0) = 0 AND COALESCE(COUNT(ca.ca_id), 0) = 0) AND cv.is_ready IS FALSE AND cv.apvd_rvwd_by IS NULL THEN 'Not Started'
                                        WHEN (COALESCE(COUNT(l.lesson_id), 0) > 0 OR COALESCE(COUNT(ca.ca_id), 0) > 0) AND cv.is_ready IS FALSE AND cv.apvd_rvwd_by IS NULL THEN 'Drafting'
                                        WHEN cv.is_ready IS FALSE AND cv.apvd_rvwd_by IS NULL AND cv.feedback IS NOT NULL THEN 'Rejected'
                                        WHEN cv.is_ready IS TRUE AND cv.apvd_rvwd_by IS NULL THEN 'Pending Approval'
                                        WHEN cv.is_ready IS TRUE AND cv.apvd_rvwd_by IS NOT NULL THEN 'Published'
                                    END
                        )::text,
                        internal.get_secret_key('my_assigned_courses')
                        ),
                        'base64'
            )::text,

            -- 2.) Course code
            pc.crs_code::TEXT,

            -- 3.) Course Title
            c.crs_title::TEXT,

            -- 4.) units
            c.units::TEXT,

            -- 5.) number of students
            (
                SELECT coalesce(COUNT(sq_mc.user_id), 0)::TEXT FROM my_courses sq_mc WHERE sq_mc.version_id = cvf.version_id
            ),

            -- 6.) Rating
            (
                SELECT
                    CASE
                        WHEN COUNT(sq_mc.rating) FILTER (WHERE sq_mc.rating IS NOT NULL) >= 5
                        THEN ROUND(AVG(sq_mc.rating)::numeric, 1)::text
                        ELSE '0'
                    END::TEXT
                FROM my_courses sq_mc WHERE sq_mc.version_id = cvf.version_id
            ),

            -- 7.) Likes (only TRUE)
            (
                SELECT
                    CASE
                        WHEN COUNT(sq_mc.*) FILTER (WHERE sq_mc.is_liked IS TRUE) = 0
                            THEN '0'
                        ELSE COUNT(sq_mc.*) FILTER (WHERE sq_mc.is_liked IS TRUE)::TEXT
                    END::TEXT
                FROM my_courses sq_mc WHERE sq_mc.version_id = cvf.version_id
            ),


            -- 8.) semester
            s.sem_name::TEXT,

            -- 9.) duration of semester
            to_char(lower(ps.duration), 'Mon DD, YYYY') || ' - ' ||
            to_char(upper(ps.duration), 'Mon DD, YYYY'),

            -- 10.) Assigned at
            TO_CHAR(cvf.asgnd_date, 'MM/DD/YYYY')::TEXT,

            -- 11.) Assigned by
            CONCAT(asb.lname, ', ', asb.fname, ' ', COALESCE(asb.mname, ''))::TEXT,

            -- 12.) Status
            CASE
                WHEN (COALESCE(COUNT(l.lesson_id), 0) = 0 AND COALESCE(COUNT(ca.ca_id), 0) = 0) AND cv.is_ready IS FALSE AND cv.apvd_rvwd_by IS NULL THEN 'Not Started'
                WHEN (COALESCE(COUNT(l.lesson_id), 0) > 0 OR COALESCE(COUNT(ca.ca_id), 0) > 0) AND cv.is_ready IS FALSE AND cv.apvd_rvwd_by IS NULL AND cv.feedback IS NULL THEN 'Drafting'
                WHEN cv.is_ready IS FALSE AND cv.apvd_rvwd_by IS NULL AND cv.feedback IS NOT NULL THEN 'Rejected'
                WHEN cv.is_ready IS TRUE AND cv.apvd_rvwd_by IS NULL THEN 'Pending Approval'
                WHEN cv.is_ready IS TRUE AND cv.apvd_rvwd_by IS NOT NULL THEN 'Published'
            end,

            -- 13.) wallpaper
            o.name

        FROM course_version_faculty cvf
            INNER JOIN internal.users u ON u.user_id = cvf.user_id
            INNER JOIN internal.users asb on asb.user_id = cvf.asgnd_by
            INNER JOIN internal.course_version cv ON cv.version_id = cvf.version_id
                INNER JOIN storage.objects o ON o.id = cv.wallpaper_id
                INNER JOIN internal.prospectus_course pc on pc.pc_id = cv.version_id
                    INNER JOIN internal.course c on pc.crs_id = c.crs_id
                    INNER JOIN internal.prospectus_semester ps on ps.prosem_id = pc.prosem_id
                        INNER JOIN internal.semester s on s.sem_id = ps.sem_id
                LEFT JOIN internal.lesson l on cv.version_id = l.version_id
                LEFT JOIN internal.course_assessment ca on cv.version_id = ca.version_id
            WHERE u.auth_id = auth.uid()
            group by cvf.version_id, pc.crs_code, s.sem_name, ps.duration,
                     asb.lname, asb.fname, asb.mname, cv.is_ready, cv.apvd_rvwd_by, c.crs_title, c.units,cvf.asgnd_date, o.name, cv.feedback;
    ELSE
        -- No secret key, return empty result set
        RETURN QUERY
        SELECT NULL::TEXT, NULL::TEXT, NULL::TEXT, NULL::TEXT,
               NULL::TEXT, NULL::TEXT, NULL::TEXT, NULL::TEXT, NULL::TEXT, NULL::TEXT, NULL::TEXT, NULL::TEXT,  NULL::TEXT
        WHERE FALSE;
    END IF;
END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION internal.my_assigned_courses() FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION internal.my_assigned_courses() TO authenticated;


--- SUBTASK 1.1.1 View Feedback           STATUS: _DEVELOPED

CREATE OR REPLACE FUNCTION internal.view_feedback(IN p_my_assigned_course_id TEXT)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    request_payload JSONB;
    dcrpt_version_id INT;
    f_feedback TEXT;
BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['faculty'])) = FALSE THEN
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    END IF;

    -- decrypt VERSION ID
    BEGIN
        request_payload = (pgp_sym_decrypt(
                    decode(p_my_assigned_course_id, 'base64'),
                    internal.get_secret_key('my_assigned_courses')
                ))::jsonb;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Valid Course ID required.'
                        USING ERRCODE = 'P1000';
    END;

    dcrpt_version_id := (request_payload->>'version_id')::INT;

    IF request_payload->>'status' = 'Pending Approval' THEN
        RAISE EXCEPTION 'This course is currently pending approval. No feedback available yet.'
            USING ERRCODE = 'P0051';
    END IF;

    IF request_payload->>'status' = 'Published' THEN
        RAISE EXCEPTION 'This course is already published. Editing is disabled in the 7.) Course Creator Studio.'
            USING ERRCODE = 'P0051';
    END IF;

    -- CHECK IF FACULTY MATCH
    IF NOT EXISTS (
        SELECT 1
        FROM course_version_faculty
        WHERE version_id = dcrpt_version_id
        AND user_id = (SELECT user_id FROM users WHERE auth_id = auth.uid())
    ) THEN
        RAISE EXCEPTION 'You are not authorized to perform any actions on this course.'
                USING ERRCODE = 'P0050';
    end if;


    -- begin extracting data

    SELECT feedback INTO f_feedback FROM course_version WHERE version_id = dcrpt_version_id;

    RETURN f_feedback;

END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION internal.view_feedback(IN p_my_assigned_course_id TEXT) FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION internal.view_feedback(IN p_my_assigned_course_id TEXT) TO authenticated;

-- note:
--     p_my_assigned_course_id TEXT,
--     p_about TEXT,
--     p_wallpaper_id UUID,
--     p_syllabus_id UUID,
--     p_lessons JSONB

--- SUBTASK 1.2.1 Get Data of Phase 1: Basics (e.g. lessons, wallpaper, syllabus, and etc)            STATUS: _DEVELOPED

CREATE OR REPLACE FUNCTION internal.get_phase1_data(IN p_my_assigned_course_id TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    request_payload JSONB;
    dcrpt_version_id INT;
    part_a JSONB;
    part_b JSONB;
    part_c JSONB;

BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['faculty'])) = FALSE THEN
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    END IF;

    -- decrypt VERSION ID
    BEGIN
        request_payload = (pgp_sym_decrypt(
                    decode(p_my_assigned_course_id, 'base64'),
                    internal.get_secret_key('my_assigned_courses')
                ))::jsonb;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Valid Course ID required.'
                        USING ERRCODE = 'P1000';
    END;

    dcrpt_version_id := (request_payload->>'version_id')::INT;

    IF request_payload->>'status' = 'Pending Approval' THEN
        RAISE EXCEPTION 'This course is currently pending approval. You may wait for review or choose to unsubmit it to make further edits in the 7.) Course Creator Studio.'
            USING ERRCODE = 'P0051';
    END IF;

    IF request_payload->>'status' = 'Published' THEN
        RAISE EXCEPTION 'This course is already published. Editing is disabled in the 7.) Course Creator Studio.'
            USING ERRCODE = 'P0051';
    END IF;

    -- CHECK IF FACULTY MATCH
    IF NOT EXISTS (
        SELECT 1
        FROM course_version_faculty
        WHERE version_id = dcrpt_version_id
        AND user_id = (SELECT user_id FROM users WHERE auth_id = auth.uid())
    ) THEN
        RAISE EXCEPTION 'You are not authorized to perform any actions on this course.'
                USING ERRCODE = 'P0050';
    end if;


    -- begin extracting data

    SELECT
        jsonb_build_object(
            'about', cv.about,
            'wallpaper_iid',
                CASE
                    WHEN o.name IS NOT NULL THEN encode(pgp_sym_encrypt(cv.wallpaper_id::TEXT, internal.get_secret_key('get_phase1_data')),'base64')::text
                END,
            'p_wallpaper_id', (
                    SELECT substring(
                        o.name::text
                        FROM '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'
                    )::uuid AS uuid
                ),
            'wallpaper_path', o.name,
            'syllabus_iid', encode(pgp_sym_encrypt(cv.syllabus_id::TEXT, internal.get_secret_key('get_phase1_data')),'base64')::text,
            'p_syllabus_id', (
                    SELECT substring(
                        o2.name::text
                        FROM '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'
                    )::uuid AS uuid
                ),
            'syllabus_path', o2.name
        ) INTO part_a
    FROM course_version cv
        left join storage.objects o on o.id = cv.wallpaper_id AND o.owner = auth.uid()
        left join storage.objects o2 on o2.id = cv.syllabus_id
    WHERE cv.version_id = dcrpt_version_id;

    IF request_payload->>'status' = 'Not Started' THEN
        RETURN jsonb_build_object(
            'course_details', coalesce(part_a, '[]'::jsonb),
            'course_lessons', '[]'::jsonb,
            'course_details_status', 'fresh'
        );

    ELSE
        SELECT
            json_agg(
                jsonb_build_object(
                    'lesson_id', encode(pgp_sym_encrypt(lesson_id::TEXT, internal.get_secret_key('get_phase1_data')),'base64')::text,
                    'lesson_no', lesson_num::int,
                    'lesson_title', lesson_name,
                    'lesson_description', lesson_descr
                ) ORDER BY lesson_num
            ) INTO part_b
        FROM lesson
        WHERE version_id = dcrpt_version_id;

        RETURN jsonb_build_object(
            'course_details', coalesce(part_a, '[]'::jsonb),
            'course_lessons', coalesce(part_b, '[]'::jsonb),
            'course_data_status', 'drafted'
        );
    END IF;

END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION internal.get_phase1_data(IN p_my_assigned_course_id TEXT) FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION internal.get_phase1_data(IN p_my_assigned_course_id TEXT) TO authenticated;


--- SUBTASK 1.2.2 Get Data of Phase 2: Course Assessment percentage                                   STATUS: _DEVELOPED

CREATE OR REPLACE FUNCTION internal.get_phase2_data(IN p_my_assigned_course_id TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    request_payload JSONB;
    dcrpt_version_id INT;
    part_c JSONB;

BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['faculty'])) = FALSE THEN
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    END IF;

    -- decrypt VERSION ID
    BEGIN
        request_payload = (pgp_sym_decrypt(
                    decode(p_my_assigned_course_id, 'base64'),
                    internal.get_secret_key('my_assigned_courses')
                ))::jsonb;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Valid Course ID required.'
                        USING ERRCODE = 'P1000';
    END;

    dcrpt_version_id := (request_payload->>'version_id')::INT;

    IF request_payload->>'status' = 'Pending Approval' THEN
        RAISE EXCEPTION 'This course is currently pending approval. You may wait for review or choose to unsubmit it to make further edits in the 7.) Course Creator Studio.'
            USING ERRCODE = 'P0051';
    END IF;

    IF request_payload->>'status' = 'Published' THEN
        RAISE EXCEPTION 'This course is already published. Editing is disabled in the 7.) Course Creator Studio.'
            USING ERRCODE = 'P0051';
    END IF;

    -- CHECK IF FACULTY MATCH
    IF NOT EXISTS (
        SELECT 1
        FROM course_version_faculty
        WHERE version_id = dcrpt_version_id
        AND user_id = (SELECT user_id FROM users WHERE auth_id = auth.uid())
    ) THEN
        RAISE EXCEPTION 'You are not authorized to perform any actions on this course.'
                USING ERRCODE = 'P0050';
    end if;


    -- begin extracting data

    IF request_payload->>'status' = 'Not Started' THEN
        RETURN jsonb_build_object(
            'course_assessment_structure', '[]'::jsonb,
            'course_data_status', 'fresh'
        );

    ELSE
        SELECT
            json_agg(
                jsonb_build_object(
                    'course_assessment_id', encode(pgp_sym_encrypt(ca_id::TEXT, internal.get_secret_key('get_phase2_data')),'base64')::text,
                    'assessment_type_id',   encode(pgp_sym_encrypt(a.asmt_type_id::TEXT, internal.get_secret_key('get_assessment_types')),'base64')::text,
                    'assessment_type', a.asmt_name,
                    'custom_assessment_name', custom_asmt,
                    'weight', weight
                )
            ) INTO part_c
        FROM course_assessment
        LEFT join internal.assessment_type a on a.asmt_type_id = course_assessment.asmt_type_id
        WHERE version_id = dcrpt_version_id;

        RETURN jsonb_build_object(
            'course_assessment_structure', coalesce(part_c, '[]'::jsonb),
            'course_data_status', 'drafted'
        );
    END IF;


END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION internal.get_phase2_data(IN p_my_assigned_course_id TEXT) FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION internal.get_phase2_data(IN p_my_assigned_course_id TEXT) TO authenticated;


--- SUBTASK 1.2.3 Get Data of Phase 3: Course Materials (e.g. videos, additional reading materials)   STATUS: _DEVELOPED

CREATE OR REPLACE FUNCTION internal.get_phase3_data(IN p_my_assigned_course_id TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    request_payload JSONB;
    dcrpt_version_id INT;
    lesson_ids INT[];
    idd INT;
    part_d JSONB := '[]'::jsonb;
    video_materials JSONB;
    other_resources JSONB;
    links JSONB;
BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['faculty'])) = FALSE THEN
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    END IF;

    -- decrypt VERSION ID
    BEGIN
        request_payload = (pgp_sym_decrypt(
                    decode(p_my_assigned_course_id, 'base64'),
                    internal.get_secret_key('my_assigned_courses')
                ))::jsonb;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Valid Course ID required.'
                        USING ERRCODE = 'P1000';
    END;

    dcrpt_version_id := (request_payload->>'version_id')::INT;

    IF request_payload->>'status' = 'Pending Approval' THEN
        RAISE EXCEPTION 'This course is currently pending approval. You may wait for review or choose to unsubmit it to make further edits in the 7.) Course Creator Studio.'
            USING ERRCODE = 'P0051';
    END IF;

    IF request_payload->>'status' = 'Published' THEN
        RAISE EXCEPTION 'This course is already published. Editing is disabled in the 7.) Course Creator Studio.'
            USING ERRCODE = 'P0051';
    END IF;

    -- CHECK IF FACULTY MATCH
    IF NOT EXISTS (
        SELECT 1
        FROM course_version_faculty
        WHERE version_id = dcrpt_version_id
        AND user_id = (SELECT user_id FROM users WHERE auth_id = auth.uid())
    ) THEN
        RAISE EXCEPTION 'You are not authorized to perform any actions on this course.'
                USING ERRCODE = 'P0050';
    end if;


    -- begin extracting data

    IF request_payload->>'status' = 'Not Started' THEN
        RETURN jsonb_build_object(
            'course_materials', '[]'::jsonb,
            'course_data_status', 'fresh'
        );

    ELSE

        -- get all the lessons of this course
        SELECT array_agg(lesson_id) INTO lesson_ids
        FROM lesson
        WHERE version_id = dcrpt_version_id;

        -- VIDEOS --
        FOREACH idd IN ARRAY lesson_ids LOOP

            -- get the videos
            SELECT
                json_agg(
                    jsonb_build_object(
                        'material_id', encode(pgp_sym_encrypt(cm.material_id::TEXT, internal.get_secret_key('get_phase3_data')),'base64')::text,
                        'video_title', cm.material_name::text,
                        'video_id', (
                            SELECT substring(
                                o.name::text
                                FROM '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'
                            )::uuid AS uuid
                            ),
                        'video_duration', cm.video_duration::text,
                        'video_path', o.name
                    )
                ) INTO video_materials
            FROM course_material cm
            inner join storage.objects o on cm.material = o.id
            inner join internal.lesson l on l.lesson_id = cm.lesson_id
            WHERE l.lesson_id = idd AND cm.material IS NOT NULL AND o.name like 'video-materials/%';

            -- get the other resources
            SELECT
                json_agg(
                    jsonb_build_object(
                        'material_id', encode(pgp_sym_encrypt(cm.material_id::TEXT, internal.get_secret_key('get_phase3_data')),'base64')::text,
                        'resource_id', (
                            SELECT substring(
                                o.name::text
                                FROM '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'
                            )::uuid AS uuid
                            ),
                        'resource_name', cm.material_name,
                        'resource_path', o.name
                    )
                ) INTO other_resources
            FROM course_material cm
            inner join storage.objects o on cm.material = o.id
            inner join internal.lesson l on l.lesson_id = cm.lesson_id
            WHERE l.lesson_id = idd AND cm.material IS NOT NULL AND o.name like 'other-resources/%';

            -- links
            SELECT
                json_agg(
                    jsonb_build_object(
                        'material_id', encode(pgp_sym_encrypt(material_id::TEXT, internal.get_secret_key('get_phase3_data')),'base64')::text,
                        'url', cm.link::text
                    )
                ) INTO links
            FROM course_material cm
            inner join internal.lesson l on l.lesson_id = cm.lesson_id
            WHERE l.lesson_id = idd AND cm.link IS NOT NULL;


            part_d := part_d || jsonb_build_object(
                                'lesson_id',
                                    encode(
                                        pgp_sym_encrypt(
                                            jsonb_build_object(
                                                'lesson_id', idd::INT,
                                                'status', (
                                                        SELECT
                                                            CASE
                                                                WHEN (COALESCE(COUNT(l.lesson_id), 0) = 0 AND COALESCE(COUNT(ca.ca_id), 0) = 0) AND cv.is_ready IS FALSE AND cv.apvd_rvwd_by IS NULL THEN 'Not Started'
                                                                WHEN (COALESCE(COUNT(l.lesson_id), 0) > 0 OR COALESCE(COUNT(ca.ca_id), 0) > 0) AND cv.is_ready IS FALSE AND cv.apvd_rvwd_by IS NULL THEN 'Drafting'
                                                                WHEN cv.is_ready IS TRUE AND cv.apvd_rvwd_by IS NULL THEN 'Pending Approval'
                                                                WHEN cv.is_ready IS TRUE AND cv.apvd_rvwd_by IS NOT NULL THEN 'Published'
                                                            END
                                                        FROM course_version_faculty cvf
                                                            INNER JOIN internal.course_version cv ON cv.version_id = cvf.version_id
                                                                LEFT JOIN internal.lesson l on cv.version_id = l.version_id
                                                                LEFT JOIN internal.course_assessment ca on cv.version_id = ca.version_id
                                                            WHERE cvf.version_id = dcrpt_version_id
                                                            group by cvf.version_id, cv.is_ready, cv.apvd_rvwd_by
                                                    )
                                                )::text,
                                                internal.get_secret_key('get_lessons')
                                                ),
                                                'base64'
                                    )::text,
                                'lesson_no', (SELECT l.lesson_num FROM internal.lesson l WHERE l.lesson_id = idd)::int,
                                'lesson_name', (SELECT l.lesson_name FROM internal.lesson l WHERE l.lesson_id = idd)::text,
                                'video_materials', video_materials,
                                'other_resources', other_resources,
                                'links', links
                            );
        end loop;

        RETURN jsonb_build_object(
            'p_contents', coalesce(part_d, '[]'::jsonb),
            'course_data_status', 'drafted'
        );
    END IF;


END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION internal.get_phase3_data(IN p_my_assigned_course_id TEXT) FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION internal.get_phase3_data(IN p_my_assigned_course_id TEXT) TO authenticated;


--- SUBTASK 1.2.4 Get Data of Phase 4: Assignments/Activities                                         STATUS: _DEVELOPED

CREATE OR REPLACE FUNCTION internal.get_phase4_data(IN p_my_assigned_course_id TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    request_payload JSONB;
    dcrpt_version_id INT;
    lesson_ids INT[];
    idd INT;
    part_e JSONB := '[]'::jsonb;
    assignments JSONB;
BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['faculty'])) = FALSE THEN
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    END IF;

    -- decrypt VERSION ID
    BEGIN
        request_payload = (pgp_sym_decrypt(
                    decode(p_my_assigned_course_id, 'base64'),
                    internal.get_secret_key('my_assigned_courses')
                ))::jsonb;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Valid Course ID required.'
                        USING ERRCODE = 'P1000';
    END;

    dcrpt_version_id := (request_payload->>'version_id')::INT;

    IF request_payload->>'status' = 'Pending Approval' THEN
        RAISE EXCEPTION 'This course is currently pending approval. You may wait for review or choose to unsubmit it to make further edits in the 7.) Course Creator Studio.'
            USING ERRCODE = 'P0051';
    END IF;

    IF request_payload->>'status' = 'Published' THEN
        RAISE EXCEPTION 'This course is already published. Editing is disabled in the 7.) Course Creator Studio.'
            USING ERRCODE = 'P0051';
    END IF;

    -- CHECK IF FACULTY MATCH
    IF NOT EXISTS (
        SELECT 1
        FROM course_version_faculty
        WHERE version_id = dcrpt_version_id
        AND user_id = (SELECT user_id FROM users WHERE auth_id = auth.uid())
    ) THEN
        RAISE EXCEPTION 'You are not authorized to perform any actions on this course.'
                USING ERRCODE = 'P0050';
    end if;


    -- begin extracting data

    IF request_payload->>'status' = 'Not Started' THEN
        RETURN jsonb_build_object(
            'course_assignments', '[]'::jsonb,
            'course_data_status', 'fresh'
        );

    ELSE

        -- get all the lessons of this course
        SELECT array_agg(lesson_id) INTO lesson_ids
        FROM lesson
        WHERE version_id = dcrpt_version_id;

        -- ASSIGNMENTS
        FOREACH idd IN ARRAY lesson_ids LOOP

            SELECT
                json_agg(
                    jsonb_build_object(
                        'assignment_id', encode(pgp_sym_encrypt(ass.ass_id::TEXT, internal.get_secret_key('get_phase4_data')),'base64')::text,
                        'title', ass.ass_title::text,
                        'maximum_points', ass.total_points,
                        'description', ass.descr,
                        'relative_offset', ass.relative_offset,
                        'structured_assessment_id',
                            encode(
                                pgp_sym_encrypt(
                                    jsonb_build_object(
                                        'ca_id', ass.ca_id::INT,
                                        'status', (
                                                SELECT
                                                    CASE
                                                        WHEN (COALESCE(COUNT(l.lesson_id), 0) = 0 AND COALESCE(COUNT(ca.ca_id), 0) = 0) AND cv.is_ready IS FALSE AND cv.apvd_rvwd_by IS NULL THEN 'Not Started'
                                                        WHEN (COALESCE(COUNT(l.lesson_id), 0) > 0 OR COALESCE(COUNT(ca.ca_id), 0) > 0) AND cv.is_ready IS FALSE AND cv.apvd_rvwd_by IS NULL THEN 'Drafting'
                                                        WHEN cv.is_ready IS TRUE AND cv.apvd_rvwd_by IS NULL THEN 'Pending Approval'
                                                        WHEN cv.is_ready IS TRUE AND cv.apvd_rvwd_by IS NOT NULL THEN 'Published'
                                                    END
                                                FROM course_version_faculty cvf
                                                    INNER JOIN internal.course_version cv ON cv.version_id = cvf.version_id
                                                        LEFT JOIN internal.lesson l on cv.version_id = l.version_id
                                                        LEFT JOIN internal.course_assessment ca on cv.version_id = ca.version_id
                                                    WHERE cvf.version_id = dcrpt_version_id
                                                    group by cvf.version_id, cv.is_ready, cv.apvd_rvwd_by
                                            )
                                        )::text,
                                        internal.get_secret_key('get_structured_assessments')
                                        ),
                                        'base64'
                            )::text,
                        'structured_assessment_name', coalesce(c.custom_asmt, at.asmt_name),
                        'lesson_id',
                            encode(
                                pgp_sym_encrypt(
                                    jsonb_build_object(
                                        'lesson_id', ass.lesson_id::INT,
                                        'status', (
                                                SELECT
                                                    CASE
                                                        WHEN (COALESCE(COUNT(l.lesson_id), 0) = 0 AND COALESCE(COUNT(ca.ca_id), 0) = 0) AND cv.is_ready IS FALSE AND cv.apvd_rvwd_by IS NULL THEN 'Not Started'
                                                        WHEN (COALESCE(COUNT(l.lesson_id), 0) > 0 OR COALESCE(COUNT(ca.ca_id), 0) > 0) AND cv.is_ready IS FALSE AND cv.apvd_rvwd_by IS NULL THEN 'Drafting'
                                                        WHEN cv.is_ready IS TRUE AND cv.apvd_rvwd_by IS NULL THEN 'Pending Approval'
                                                        WHEN cv.is_ready IS TRUE AND cv.apvd_rvwd_by IS NOT NULL THEN 'Published'
                                                    END
                                                FROM course_version_faculty cvf
                                                    INNER JOIN internal.course_version cv ON cv.version_id = cvf.version_id
                                                        LEFT JOIN internal.lesson l on cv.version_id = l.version_id
                                                        LEFT JOIN internal.course_assessment ca on cv.version_id = ca.version_id
                                                    WHERE cvf.version_id = dcrpt_version_id
                                                    group by cvf.version_id, cv.is_ready, cv.apvd_rvwd_by
                                            )
                                        )::text,
                                        internal.get_secret_key('get_lessons')
                                        ),
                                        'base64'
                            )::text,
                        'lesson_name', l.lesson_name,
                        'attachments', coalesce((
                                SELECT
                                    json_agg(
                                            jsonb_build_object(
                                                'attachment_iid', encode(pgp_sym_encrypt(att.attachment_id::TEXT, internal.get_secret_key('get_phase4_data')),'base64')::text,
                                                'attachment_id', substring(
                                                            o.name::text
                                                            FROM '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'
                                                        )::uuid,
                                                'attachment_path', o.name
                                            )
                                    )
                                FROM attachment att
                                INNER JOIN storage.objects o on o.id = att.file_id
                                WHERE att.ass_id = ass.ass_id
                            ), '[]'::json)
                    )
                ) INTO assignments
            FROM assignment ass
                inner join internal.lesson l on l.lesson_id = ass.lesson_id
                inner join internal.course_assessment c on c.ca_id = ass.ca_id
                left join internal.assessment_type at on c.asmt_type_id = at.asmt_type_id
            WHERE l.lesson_id = idd;


            part_e := part_e || coalesce(assignments, '[]'::jsonb);
        end loop;

        RETURN jsonb_build_object(
            'course_assignments', coalesce(part_e, '[]'::jsonb),
            'course_data_status', 'drafted'
        );
    END IF;


END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION internal.get_phase4_data(IN p_my_assigned_course_id TEXT) FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION internal.get_phase4_data(IN p_my_assigned_course_id TEXT) TO authenticated;


--- SUBTASK 1.2.5 Get Data of Phase 5: Test/Exams                                                     STATUS: _DEVELOPED

CREATE OR REPLACE FUNCTION internal.get_phase5_data(IN p_my_assigned_course_id TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    request_payload JSONB;
    dcrpt_version_id INT;
    lesson_ids INT[];
    idd INT;
    part_f JSONB := '[]'::jsonb;
    test JSONB;
BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['faculty'])) = FALSE THEN
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    END IF;

    -- decrypt VERSION ID
    BEGIN
        request_payload = (pgp_sym_decrypt(
                    decode(p_my_assigned_course_id, 'base64'),
                    internal.get_secret_key('my_assigned_courses')
                ))::jsonb;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Valid Course ID required.'
                        USING ERRCODE = 'P1000';
    END;

    dcrpt_version_id := (request_payload->>'version_id')::INT;

    IF request_payload->>'status' = 'Pending Approval' THEN
        RAISE EXCEPTION 'This course is currently pending approval. You may wait for review or choose to unsubmit it to make further edits in the 7.) Course Creator Studio.'
            USING ERRCODE = 'P0051';
    END IF;

--     IF request_payload->>'status' = 'Published' THEN
--         RAISE EXCEPTION 'This course is already published. Editing is disabled in the 7.) Course Creator Studio.'
--             USING ERRCODE = 'P0051';
--     END IF;

    -- CHECK IF FACULTY MATCH
    IF NOT EXISTS (
        SELECT 1
        FROM course_version_faculty
        WHERE version_id = dcrpt_version_id
        AND user_id = (SELECT user_id FROM users WHERE auth_id = auth.uid())
    ) THEN
        RAISE EXCEPTION 'You are not authorized to perform any actions on this course.'
                USING ERRCODE = 'P0050';
    end if;


    -- begin extracting data

    IF request_payload->>'status' = 'Not Started' THEN
        RETURN jsonb_build_object(
            'course_exams', '[]'::jsonb,
            'course_data_status', 'fresh'
        );

    ELSE
        -- get all the lessons of this course
        SELECT array_agg(lesson_id) INTO lesson_ids
        FROM lesson
        WHERE version_id = dcrpt_version_id;

        -- ASSIGNMENTS
        FOREACH idd IN ARRAY lesson_ids LOOP

            SELECT
                jsonb_agg(
                    jsonb_build_object(
                        'test_id', encode(pgp_sym_encrypt(t.test_id::TEXT, internal.get_secret_key('get_phase5_data')),'base64')::text,
                        'title', t.test_title::text,
                        'description', t.descr,
                        'time_limit', t.time_limit::text,
                        'allowed_attempts', t.allowed_attempts::int,
                        'structured_assessment_id',
                            encode(
                                pgp_sym_encrypt(
                                    jsonb_build_object(
                                        'ca_id', t.ca_id::INT,
                                        'status', (
                                                SELECT
                                                    CASE
                                                        WHEN (COALESCE(COUNT(l.lesson_id), 0) = 0 AND COALESCE(COUNT(ca.ca_id), 0) = 0) AND cv.is_ready IS FALSE AND cv.apvd_rvwd_by IS NULL THEN 'Not Started'
                                                        WHEN (COALESCE(COUNT(l.lesson_id), 0) > 0 OR COALESCE(COUNT(ca.ca_id), 0) > 0) AND cv.is_ready IS FALSE AND cv.apvd_rvwd_by IS NULL THEN 'Drafting'
                                                        WHEN cv.is_ready IS TRUE AND cv.apvd_rvwd_by IS NULL THEN 'Pending Approval'
                                                        WHEN cv.is_ready IS TRUE AND cv.apvd_rvwd_by IS NOT NULL THEN 'Published'
                                                    END
                                                FROM course_version_faculty cvf
                                                    INNER JOIN internal.course_version cv ON cv.version_id = cvf.version_id
                                                        LEFT JOIN internal.lesson l on cv.version_id = l.version_id
                                                        LEFT JOIN internal.course_assessment ca on cv.version_id = ca.version_id
                                                    WHERE cvf.version_id = dcrpt_version_id
                                                    group by cvf.version_id, cv.is_ready, cv.apvd_rvwd_by
                                            )
                                        )::text,
                                        internal.get_secret_key('get_structured_assessments')
                                        ),
                                        'base64'
                            )::text,
                        'structured_assessment_name', coalesce(c.custom_asmt, at.asmt_name),
                        'lesson_id',
                            encode(
                                pgp_sym_encrypt(
                                    jsonb_build_object(
                                        'lesson_id', t.lesson_id::INT,
                                        'status', (
                                                SELECT
                                                    CASE
                                                        WHEN (COALESCE(COUNT(l.lesson_id), 0) = 0 AND COALESCE(COUNT(ca.ca_id), 0) = 0) AND cv.is_ready IS FALSE AND cv.apvd_rvwd_by IS NULL THEN 'Not Started'
                                                        WHEN (COALESCE(COUNT(l.lesson_id), 0) > 0 OR COALESCE(COUNT(ca.ca_id), 0) > 0) AND cv.is_ready IS FALSE AND cv.apvd_rvwd_by IS NULL THEN 'Drafting'
                                                        WHEN cv.is_ready IS TRUE AND cv.apvd_rvwd_by IS NULL THEN 'Pending Approval'
                                                        WHEN cv.is_ready IS TRUE AND cv.apvd_rvwd_by IS NOT NULL THEN 'Published'
                                                    END
                                                FROM course_version_faculty cvf
                                                    INNER JOIN internal.course_version cv ON cv.version_id = cvf.version_id
                                                        LEFT JOIN internal.lesson l on cv.version_id = l.version_id
                                                        LEFT JOIN internal.course_assessment ca on cv.version_id = ca.version_id
                                                    WHERE cvf.version_id = dcrpt_version_id
                                                    group by cvf.version_id, cv.is_ready, cv.apvd_rvwd_by
                                            )
                                        )::text,
                                        internal.get_secret_key('get_lessons')
                                        ),
                                        'base64'
                            )::text,
                        'lesson_title', l.lesson_name,
                        'questions', coalesce((
                                SELECT
                                    jsonb_agg(
                                            jsonb_build_object(
                                                'question_id', encode(pgp_sym_encrypt(q.question_id::TEXT, internal.get_secret_key('get_phase5_data')),'base64')::text,
                                                'question', q.question,
                                                'total_points', q.total_points::int,
                                                'answer_type_id', encode(pgp_sym_encrypt(q.anst_id::TEXT, internal.get_secret_key('get_answer_types')),'base64')::text,
                                                'answer_type_name', a.answer_type,
                                                'answers',
                                                    CASE
                                                        WHEN a.answer_type = 'multiple choice' THEN
                                                            coalesce((
                                                                SELECT
                                                                    jsonb_agg(
                                                                            jsonb_build_object(
                                                                                'key_id', encode(pgp_sym_encrypt(ak.key_id::TEXT, internal.get_secret_key('get_phase5_data')),'base64')::text,
                                                                                'item_choice', ak.text_key,
                                                                                'is_correct', ak.is_correct
                                                                            )
                                                                    )
                                                                FROM answer_key ak
                                                                WHERE ak.question_id = q.question_id
                                                            ), '[]'::jsonb)

                                                        WHEN a.answer_type = 'true/false' THEN
                                                            coalesce((
                                                                SELECT
                                                                    jsonb_agg(
                                                                            jsonb_build_object(
                                                                                'key_id', encode(pgp_sym_encrypt(ak.key_id::TEXT, internal.get_secret_key('get_phase5_data')),'base64')::text,
                                                                                'tof_key', ak.tof_key
                                                                            )
                                                                    )
                                                                FROM answer_key ak
                                                                WHERE ak.question_id = q.question_id
                                                            ), '[]'::jsonb)

                                                        WHEN a.answer_type = 'identification' THEN
                                                            coalesce((
                                                                SELECT
                                                                    jsonb_agg(
                                                                            jsonb_build_object(
                                                                                'key_id', encode(pgp_sym_encrypt(ak.key_id::TEXT, internal.get_secret_key('get_phase5_data')),'base64')::text,
                                                                                'item_choice', ak.text_key
                                                                            )
                                                                    )
                                                                FROM answer_key ak
                                                                WHERE ak.question_id = q.question_id
                                                            ), '[]'::jsonb)

                                                        WHEN a.answer_type = 'enumeration' THEN
                                                            coalesce((
                                                                SELECT
                                                                    jsonb_build_object(
                                                                        'key_id', encode(
                                                                            pgp_sym_encrypt(ak.key_id::TEXT,
                                                                                            internal.get_secret_key('get_phase5_data')),
                                                                            'base64')::text,
                                                                        'required_items', ak.required_items,
                                                                        'possible_answers', ak.enum_keys::text[]
                                                                    )
                                                                FROM answer_key ak
                                                                WHERE ak.question_id = q.question_id
                                                            ), '[]'::jsonb)

                                                        WHEN a.answer_type = 'essay' THEN '[]'::jsonb

                                                    END
                                            )
                                    )
                                FROM question q
                                inner join internal.answer_type a on a.anst_id = q.anst_id
                                WHERE q.test_id = t.test_id
                            ), '[]'::jsonb)
                    )
                ) INTO test
            FROM test t
                inner join internal.lesson l on l.lesson_id = t.lesson_id
                inner join internal.course_assessment c on c.ca_id = t.ca_id
                    left join internal.assessment_type at on c.asmt_type_id = at.asmt_type_id
            WHERE l.lesson_id = idd;


            part_f := part_f || coalesce(test, '[]'::jsonb);
        end loop;

        RETURN jsonb_build_object(
            'course_exams', coalesce(part_f, '[]'::jsonb),
            'course_data_status', 'drafted'
        );
    END IF;


END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION internal.get_phase5_data(IN p_my_assigned_course_id TEXT) FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION internal.get_phase5_data(IN p_my_assigned_course_id TEXT) TO authenticated;




--- SUBTASK 1.3.1 Choose course to clone                                                              STATUS: _DEVELOPED

CREATE OR REPLACE FUNCTION internal.get2clone_media(
    IN p_my_target_course_id TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    request_payload JSONB;
    dcrpt_version_id INT;
    file JSONB;
    media JSONB;
BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['faculty'])) = FALSE THEN
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    END IF;

    -- decrypt VERSION ID
    BEGIN
        request_payload = (pgp_sym_decrypt(
                    decode(p_my_target_course_id, 'base64'),
                    internal.get_secret_key('my_assigned_courses')
                ))::jsonb;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Valid Course ID required.'
                        USING ERRCODE = 'P1000';
    END;

    dcrpt_version_id := (request_payload->>'version_id')::INT;

    IF request_payload->>'status' != 'Published' THEN
        RAISE EXCEPTION
            'Cloning is not allowed. Only previously published courses can be cloned in the 7.) Course Creator Studio.'
            USING ERRCODE = 'P0061';
    END IF;

    -- CHECK IF FACULTY MATCH
    IF NOT EXISTS (
        SELECT 1
        FROM course_version_faculty
        WHERE version_id = dcrpt_version_id
        AND user_id = (SELECT user_id FROM users WHERE auth_id = auth.uid())
    ) THEN
        RAISE EXCEPTION 'You are not authorized to perform any actions on this course.'
                USING ERRCODE = 'P0050';
    end if;



    -- starts basics e.g. wallpaper, syllabus
    WITH t as
        (
            SELECT
                o.bucket_id AS bucket,
                o.name AS original_path,
                (
                    regexp_replace(
                                    o.name,
                                    '([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})',
                                    gen_random_uuid()::text
                                    )
                    ) as new_path
            FROM course_version cv
            INNER JOIN storage.objects o on o.id = cv.wallpaper_id AND o.owner = auth.uid()
            WHERE version_id = dcrpt_version_id

            UNION ALL

            SELECT
                o2.bucket_id AS bucket,
                o2.name AS original_path,
                (
                    regexp_replace(
                                    o2.name,
                                    '([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})',
                                    gen_random_uuid()::text
                                    )
                    ) as new_path
            FROM course_version cv
            INNER JOIN storage.objects o2 on o2.id = cv.syllabus_id
            WHERE version_id = dcrpt_version_id

            UNION ALL

            SELECT
                o.bucket_id as bucket,
                o.name as original_path,
                (
                    regexp_replace(
                                    o.name,
                                    '([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})',
                                    gen_random_uuid()::text
                                    )
                    ) as new_path
            FROM course_material cm
            INNER JOIN storage.objects o on o.id = cm.material
            INNER JOIN internal.lesson l on l.lesson_id = cm.lesson_id
            WHERE l.version_id = dcrpt_version_id


            UNION ALL

            SELECT
                o.bucket_id as bucket,
                o.name as original_path,
                (
                    regexp_replace(
                                    o.name,
                                    '([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})',
                                    gen_random_uuid()::text
                                    )
                    ) as new_path
            FROM attachment att
            INNER JOIN storage.objects o on o.id = att.file_id
            INNER JOIN internal.assignment a on att.ass_id = a.ass_id
            INNER JOIN internal.lesson l on l.lesson_id = a.lesson_id
            WHERE l.version_id = dcrpt_version_id

        )
    SELECT
        json_agg(
            jsonb_build_object(
                'bucket', bucket,
                'original_path', original_path,
                'new_path', new_path
            )
        ) INTO media
    FROM t;

    RETURN jsonb_build_object(
            'course_materials', coalesce(media, '[]'::jsonb),
            'trace_id', encode(
                            pgp_sym_encrypt(
                                jsonb_build_object(
                                    'original_version_id', dcrpt_version_id::int,
                                    'course_material', coalesce(media, '[]'::jsonb)
                                        )::text,
                                    internal.get_secret_key('get2clone_media')
                                    ),'base64'
                                )::text
        );

END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION internal.get2clone_media(IN p_my_target_course_id TEXT) FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION internal.get2clone_media(IN p_my_target_course_id TEXT) TO authenticated;


--- SUBTASK 1.3.2 Copy/Clone entire course content to new one                                         STATUS: _DEVELOPED

CREATE OR REPLACE PROCEDURE internal.clone_course(
    IN p_my_assigned_course_id TEXT,
    IN p_trace_id TEXT
)
SET search_path = internal
AS $$
DECLARE
    request_payload JSONB;
    dcrpt_version_id INT;
    trace_token JSONB;
    original_version_id INT;
    media JSONB;
BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['faculty'])) = FALSE THEN
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    END IF;

    -- decrypt VERSION ID
    BEGIN
        request_payload = (pgp_sym_decrypt(
                    decode(p_my_assigned_course_id, 'base64'),
                    internal.get_secret_key('my_assigned_courses')
                ))::jsonb;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Valid Course ID required.'
                        USING ERRCODE = 'P1000';
    END;

    dcrpt_version_id := (request_payload->>'version_id')::INT;

    IF request_payload->>'status' != 'Not Started' THEN
        RAISE EXCEPTION
            'This course isn''t eligible for cloning.'
            USING ERRCODE = 'P0062';
    END IF;


    -- decrypt VERSION ID -- TRACE ID
    BEGIN
        trace_token = (pgp_sym_decrypt(
                    decode(p_trace_id, 'base64'),
                    internal.get_secret_key('get2clone_media')
                ))::jsonb;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Valid Trace ID required.'
                        USING ERRCODE = 'P1000';
    END;

    original_version_id := (trace_token->>'original_version_id')::INT;
    media := (trace_token->>'course_material')::JSONB;

    -- check if this is the faculty of the course
    IF NOT EXISTS(
                SELECT 1
                FROM course_version_faculty cvf
                INNER JOIN internal.users u on u.user_id = cvf.user_id
                INNER JOIN auth.users a on a.id = u.auth_id
                WHERE u.auth_id = auth.uid() AND cvf.version_id = dcrpt_version_id) THEN
        RAISE EXCEPTION 'You are not authorized to perform any actions on this course.'
            USING ERRCODE = 'P0050';
    end if;


    -- Step 1 – Create temp tables that mimic structure

    CREATE TEMP TABLE tmp_course_version AS
    SELECT * FROM course_version WHERE version_id = original_version_id;

    CREATE TEMP TABLE tmp_lesson AS
    SELECT * FROM lesson WHERE version_id = original_version_id;

    CREATE TEMP TABLE tmp_course_material AS
    SELECT m.*
    FROM course_material m
    JOIN lesson l ON m.lesson_id = l.lesson_id
    WHERE l.version_id = original_version_id;

    CREATE TEMP TABLE tmp_course_assessment AS
    SELECT * FROM course_assessment WHERE version_id = original_version_id;

    CREATE TEMP TABLE tmp_assignment AS
    SELECT a.*
    FROM assignment a
    JOIN lesson l ON a.lesson_id = l.lesson_id
    WHERE l.version_id = original_version_id;

    CREATE TEMP TABLE tmp_attachment AS
    SELECT at.*
    FROM attachment at
    JOIN internal.assignment a2 on at.ass_id = a2.ass_id
    JOIN lesson l ON a2.lesson_id = l.lesson_id
    WHERE l.version_id = original_version_id;

    CREATE TEMP TABLE tmp_test AS
    SELECT t.*
    FROM test t
    JOIN lesson l ON t.lesson_id = l.lesson_id
    WHERE l.version_id = original_version_id;

    CREATE TEMP TABLE tmp_question AS
    SELECT q.*
    FROM question q
    JOIN test t ON t.test_id = q.test_id
    JOIN lesson l ON t.lesson_id = l.lesson_id
    WHERE l.version_id = original_version_id;

    CREATE TEMP TABLE tmp_answer_key AS
    SELECT ak.*
    FROM answer_key ak
    JOIN internal.question q on q.question_id = ak.question_id
    JOIN test t ON t.test_id = q.test_id
    JOIN lesson l ON t.lesson_id = l.lesson_id
    WHERE l.version_id = original_version_id;


    -- Step 2 – Add mapping columns

    ALTER TABLE tmp_lesson ADD COLUMN new_lesson_id INT;
    ALTER TABLE tmp_course_material ADD COLUMN new_material_id INT;
    ALTER TABLE tmp_course_assessment ADD COLUMN new_ca_id INT;
    ALTER TABLE tmp_assignment ADD COLUMN new_ass_id INT;
    ALTER TABLE tmp_attachment ADD COLUMN new_attachment_id INT;
    ALTER TABLE tmp_test ADD COLUMN new_test_id INT;
    ALTER TABLE tmp_question ADD COLUMN new_question_id INT;
    ALTER TABLE tmp_answer_key ADD COLUMN new_key_id INT;


    -- Step 3 – Generate new IDs
    UPDATE tmp_lesson SET new_lesson_id = nextval(pg_get_serial_sequence('lesson', 'lesson_id')) WHERE TRUE; --
    UPDATE tmp_course_material SET new_material_id = nextval(pg_get_serial_sequence('course_material', 'material_id')) WHERE TRUE; --
    UPDATE tmp_course_assessment SET new_ca_id = nextval(pg_get_serial_sequence('course_assessment', 'ca_id')) WHERE TRUE; --
    UPDATE tmp_assignment SET new_ass_id = nextval(pg_get_serial_sequence('assignment', 'ass_id')) WHERE TRUE;
    UPDATE tmp_attachment SET new_attachment_id = nextval(pg_get_serial_sequence('attachment', 'attachment_id')) WHERE TRUE;
    UPDATE tmp_test SET new_test_id = nextval(pg_get_serial_sequence('test', 'test_id')) WHERE TRUE;
    UPDATE tmp_question SET new_question_id = nextval(pg_get_serial_sequence('question', 'question_id')) WHERE TRUE;
    UPDATE tmp_answer_key SET new_key_id = nextval(pg_get_serial_sequence('answer_key', 'key_id')) WHERE TRUE;


    -- Step 4 – Update foreign keys inside the temp tables

    UPDATE tmp_lesson
    SET version_id = dcrpt_version_id
    WHERE TRUE;

    UPDATE tmp_course_assessment
    SET version_id = dcrpt_version_id
    WHERE TRUE;

    UPDATE tmp_course_material cm
    SET lesson_id = l.new_lesson_id FROM tmp_lesson l
    WHERE cm.lesson_id = l.lesson_id;

    UPDATE tmp_assignment ass
    SET lesson_id = l.new_lesson_id, ca_id = ca.new_ca_id FROM tmp_lesson l, tmp_course_assessment ca
    WHERE ass.lesson_id = l.lesson_id AND ass.ca_id = ca.ca_id;

    UPDATE tmp_attachment att
    SET ass_id = ass.new_ass_id FROM tmp_assignment ass
    WHERE att.ass_id = ass.ass_id;

    UPDATE tmp_test t
    SET lesson_id = l.new_lesson_id, ca_id = ca.new_ca_id FROM tmp_lesson l, tmp_course_assessment ca
    WHERE t.lesson_id = l.lesson_id AND t.ca_id = ca.ca_id;

    UPDATE tmp_question q
    SET test_id = t.new_test_id FROM tmp_test t
    WHERE q.test_id = t.test_id;

    UPDATE tmp_answer_key ak
    SET question_id = q.new_question_id FROM tmp_question q
    WHERE ak.question_id = q.question_id;

    -- Step 5 – Insert into the real tables

    UPDATE course_version cv
    SET about = tcv.about,
        fee = tcv.fee,
        syllabus_id = COALESCE(
            (SELECT id
             FROM storage.objects
             WHERE name = (
                SELECT elem->>'new_path'
                FROM jsonb_array_elements(media) AS elem
                WHERE elem->>'original_path' = (SELECT o2.name
                                                 from course_version cv2
                                                     inner join storage.objects o2 on o2.id = cv2.syllabus_id
                                                 WHERE cv2.version_id = tcv.version_id
                                                 )
                 )
             ), cv.syllabus_id),
        wallpaper_id = COALESCE(
            (SELECT id
             FROM storage.objects
             WHERE name = (
                SELECT elem->>'new_path'
                FROM jsonb_array_elements(media) AS elem
                WHERE elem->>'original_path' = (SELECT o3.name
                                                 from course_version cv3
                                                     inner join storage.objects o3 on o3.id = cv3.wallpaper_id
                                                 WHERE cv3.version_id = tcv.version_id
                                                 )
                 )
             ), cv.wallpaper_id),
        ll_id = tcv.ll_id
        FROM tmp_course_version tcv
    WHERE cv.version_id = dcrpt_version_id;

    INSERT INTO lesson (lesson_id, lesson_name, lesson_descr, version_id, lesson_num)
    SELECT tmp_l.new_lesson_id, tmp_l.lesson_name, tmp_l.lesson_descr, tmp_l.version_id, tmp_l.lesson_num
    FROM tmp_lesson tmp_l;

    INSERT INTO course_assessment (ca_id, weight, custom_asmt, asmt_type_id, version_id)
    SELECT tmp_ca.new_ca_id, tmp_ca.weight, tmp_ca.custom_asmt, tmp_ca.asmt_type_id, tmp_ca.version_id
    FROM tmp_course_assessment tmp_ca;

    INSERT INTO course_material (material_id, link, material_name, video_duration, material, origin_id, lesson_id)
    SELECT tmp_cm.new_material_id,
           tmp_cm.link,
           tmp_cm.material_name,
           tmp_cm.video_duration,
           (
           SELECT id
           FROM storage.objects
           WHERE name = (
                SELECT elem->>'new_path'
                FROM jsonb_array_elements(media) AS elem
                WHERE elem->>'original_path' = (
                        SELECT name from storage.objects WHERE id = tmp_cm.material
                    )
                 )
           ),
           tmp_cm.user_id,
           tmp_cm.lesson_id
    FROM tmp_course_material tmp_cm;


    INSERT INTO assignment (ass_id, ass_title, total_points, descr, ca_id, lesson_id)
    SELECT tmp_ass.new_ass_id, tmp_ass.ass_title, tmp_ass.total_points, tmp_ass.descr, tmp_ass.ca_id, tmp_ass.lesson_id
    FROM tmp_assignment tmp_ass;

    INSERT INTO attachment (attachment_id, file_id, ass_id)
    SELECT tmp_att.new_attachment_id,
           (
           SELECT id
           FROM storage.objects
           WHERE name = (
                SELECT elem->>'new_path'
                FROM jsonb_array_elements(media) AS elem
                WHERE elem->>'original_path' = (
                        SELECT name from storage.objects WHERE id = tmp_att.file_id
                    )
                 )
           ),
           tmp_att.ass_id
    FROM tmp_attachment tmp_att;

    INSERT INTO test (test_id, test_title, descr, time_limit, allowed_attempts, ca_id, lesson_id)
    SELECT tmp_t.new_test_id, tmp_t.test_title, tmp_t.descr, tmp_t.time_limit, tmp_t.allowed_attempts, tmp_t.ca_id, tmp_t.lesson_id
    FROM tmp_test tmp_t;

    INSERT INTO question (question_id, question, total_points, test_id, anst_id)
    SELECT tmp_q.new_question_id, tmp_q.question, tmp_q.total_points, tmp_q.test_id, tmp_q.anst_id
    FROM tmp_question tmp_q;

    INSERT INTO answer_key (key_id, text_key, tof_key, enum_keys, is_correct, required_items, question_id)
    SELECT tmp_ak.new_key_id, tmp_ak.text_key, tmp_ak.tof_key, tmp_ak.enum_keys, tmp_ak.is_correct,  tmp_ak.required_items,tmp_ak.question_id
    FROM tmp_answer_key tmp_ak;

    DROP TABLE IF EXISTS
        tmp_course_version,
        tmp_lesson,
        tmp_course_material,
        tmp_course_assessment,
        tmp_assignment,
        tmp_attachment,
        tmp_test,
        tmp_question,
        tmp_answer_key;


END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
REVOKE ALL ON PROCEDURE internal.clone_course(
    IN p_my_assigned_course_id TEXT,
    IN p_trace_id TEXT
) FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE internal.clone_course(
    IN p_my_assigned_course_id TEXT,
    IN p_trace_id TEXT
) TO authenticated;

















-- TASK 2). Manage Assigned Courses

------------------------------------------------------------------------------------------------------------------------

--- SUBTASK 2.1.1 Setup Basics and create lessons                                           STATUS: _DEVELOPED

CREATE OR REPLACE PROCEDURE internal.build_course_lessons(
    IN p_my_assigned_course_id TEXT,
    IN p_about TEXT,
    IN p_wallpaper_id UUID,
    IN p_syllabus_id UUID,
    IN p_lessons JSONB
)
SET search_path = internal
AS $$
DECLARE
    request_payload JSONB;
    dcrpt_version_id INT;
    l RECORD;
    wallpaper_uuid UUID := null;
    syllabus_uuid UUID := null;
    order_num INT := 1;
    dcrpt_lesson_id INT;
BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['faculty'])) = FALSE THEN
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    END IF;

    -- decrypt VERSION ID
    BEGIN
        request_payload = (pgp_sym_decrypt(
                    decode(p_my_assigned_course_id, 'base64'),
                    internal.get_secret_key('my_assigned_courses')
                ))::jsonb;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Valid Course ID required.'
                        USING ERRCODE = 'P1000';
    END;

    dcrpt_version_id := (request_payload->>'version_id')::INT;

    IF request_payload->>'status' = 'Pending Approval' THEN
        RAISE EXCEPTION 'This course is currently pending approval. You may wait for review or choose to unsubmit it to make further edits in the 7.) Course Creator Studio.'
            USING ERRCODE = 'P0051';
    END IF;

    IF request_payload->>'status' = 'Published' THEN
        RAISE EXCEPTION 'This course is already published. Editing is disabled in the 7.) Course Creator Studio.'
            USING ERRCODE = 'P0051';
    END IF;


    -- check if this is the faculty of the course
    IF NOT EXISTS(
                SELECT 1
                FROM course_version_faculty cvf
                INNER JOIN internal.users u on u.user_id = cvf.user_id
                INNER JOIN auth.users a on a.id = u.auth_id
                WHERE u.auth_id = auth.uid() AND cvf.version_id = dcrpt_version_id) THEN
        RAISE EXCEPTION 'You are not authorized to perform any actions on this course.'
            USING ERRCODE = 'P0050';
    end if;


    if p_wallpaper_id is not null then
        select id INTO wallpaper_uuid
        from storage.objects
        where bucket_id = 'course-wallpaper'
        and name like concat(p_wallpaper_id, '%')
        and owner = auth.uid();

        if wallpaper_uuid is null then
            RAISE EXCEPTION 'Parameter "Wallpaper id" is missing or file doesn''t exist. Please review it again.'
                USING ERRCODE = 'P0035';
        end if;
    end if;


    select id INTO syllabus_uuid
    from storage.objects
    where bucket_id = 'course-materials'
      and name like concat('syllabus/',p_syllabus_id,'%');

    if syllabus_uuid is null then
        RAISE EXCEPTION 'Parameter "Syllabus id" is missing or file doesn''t exist. Please review it again.'
            USING ERRCODE = 'P0035';
    end if;


    -- UPDATE THE ABOUT AND WALLPAPER
    UPDATE course_version
    SET about = p_about,
        wallpaper_id = coalesce(wallpaper_uuid, wallpaper_id),
        syllabus_id = coalesce(syllabus_uuid, syllabus_id)
    WHERE version_id = dcrpt_version_id;

    -- SET UP LESSONS
    FOR l IN
    SELECT lesson_id,
           lesson_no::INT,
           lesson_title,
           lesson_description
    FROM jsonb_to_recordset(p_lessons)
         AS x( lesson_id TEXT, lesson_no INT, lesson_title TEXT, lesson_description TEXT)
    LOOP
        IF l.lesson_title IS NULL or l.lesson_title = '' THEN
            RAISE EXCEPTION 'Parameter "Lesson Title" is required. Please review it again.'
            USING ERRCODE = 'P0035';
        ELSIF l.lesson_description IS NULL or l.lesson_description = '' THEN
            RAISE EXCEPTION 'Parameter "Lesson description" is required. Please review it again.'
            USING ERRCODE = 'P0035';
        end if;


        IF l.lesson_id IS NOT NULL THEN
            BEGIN
                dcrpt_lesson_id := pgp_sym_decrypt(
                    decode(l.lesson_id, 'base64'),
                    get_secret_key('get_phase1_data')
                )::INT;
            EXCEPTION
                WHEN OTHERS THEN
                    RAISE EXCEPTION 'Valid Lesson ID required.'
                        USING ERRCODE = 'P1000';
            END;

            IF EXISTS (SELECT 1 FROM lesson WHERE version_id = dcrpt_version_id AND lesson_name = trim(l.lesson_title) AND lesson_id != dcrpt_lesson_id) THEN
                RAISE EXCEPTION 'Duplicate Lesson Title isn''t allowed "%". Please review it again.', trim(l.lesson_title)
                USING ERRCODE = 'P0035';
            end if;

            UPDATE lesson
            SET lesson_num = l.lesson_no,
                lesson_name = trim(l.lesson_title),
                lesson_descr = l.lesson_description
            WHERE lesson_id = dcrpt_lesson_id;
        ELSE
            IF EXISTS (SELECT 1 FROM lesson WHERE version_id = dcrpt_version_id AND lesson_name = trim(l.lesson_title)) THEN
                RAISE EXCEPTION 'Duplicate Lesson Title isn''t allowed "%". Please review it again.', trim(l.lesson_title)
                USING ERRCODE = 'P0035';
            end if;

            INSERT INTO lesson (lesson_num, lesson_name, lesson_descr, version_id)
            VALUES (l.lesson_no, trim(l.lesson_title), l.lesson_description, dcrpt_version_id)
            ON CONFLICT DO NOTHING; -- avoid duplicate enrollments
        end if;

    END LOOP;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
REVOKE ALL ON PROCEDURE internal.build_course_lessons(
    IN p_my_assigned_course_id TEXT,
    IN p_about TEXT,
    IN p_wallpaper_id UUID,
    IN p_syllabus_id UUID,
    IN p_lessons JSONB
) FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE internal.build_course_lessons(
    IN p_my_assigned_course_id TEXT,
    IN p_about TEXT,
    IN p_wallpaper_id UUID,
    IN p_syllabus_id UUID,
    IN p_lessons JSONB
) TO authenticated;



--- TASK 2.2. Setup Assessments and corresponding Weight

---- SUBTASK 2.2.1 Get Assessment types                                                             STATUS: _DEVELOPED

CREATE OR REPLACE FUNCTION internal.get_assessment_types()
RETURNS TABLE(
    id TEXT, -- 1
    name TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
BEGIN
    -- Only run main query if key exists and confirm the user role
    IF (
        (SELECT check_user_role(ARRAY['faculty'])) = TRUE AND
        internal.get_secret_key('get_assessment_types') IS NOT NULL) THEN
        RETURN QUERY
            SELECT
            -- 1.) ID (encrypted)
            encode(
                pgp_sym_encrypt(asmt_type_id::TEXT, internal.get_secret_key('get_assessment_types')),
                'base64'
            )::TEXT,

            asmt_name::text

            FROM assessment_type;
    ELSE
        -- No secret key, return empty result set
        RETURN QUERY
        SELECT NULL::TEXT, NULL::TEXT
        WHERE FALSE;
    END IF;
END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION internal.get_assessment_types() FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION internal.get_assessment_types() TO authenticated;


---- SUBTASK 2.2.2 SETUP COURSE ASSESSMENTS                                                         STATUS: _DEVELOPED


CREATE OR REPLACE PROCEDURE internal.build_course_assessments(
    IN p_my_assigned_course_id TEXT,
    IN p_assessments JSONB
)
SET search_path = internal
AS $$
DECLARE
    request_payload JSONB;
    dcrpt_version_id INT;
    dcrpt_asmt_type_id INT;
    c RECORD;
    total_weight INT := 0;
    dcrpt_ca_id INT;
BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['faculty'])) = FALSE THEN
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    END IF;

    -- decrypt VERSION ID
    BEGIN
        request_payload = (pgp_sym_decrypt(
                    decode(p_my_assigned_course_id, 'base64'),
                    internal.get_secret_key('my_assigned_courses')
                ))::jsonb;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Valid Course ID required.'
                        USING ERRCODE = 'P1000';
    END;

    dcrpt_version_id := (request_payload->>'version_id')::INT;

    IF request_payload->>'status' = 'Pending Approval' THEN
        RAISE EXCEPTION 'This course is currently pending approval. You may wait for review or choose to unsubmit it to make further edits in the 7.) Course Creator Studio.'
            USING ERRCODE = 'P0051';
    END IF;

    IF request_payload->>'status' = 'Published' THEN
        RAISE EXCEPTION 'This course is already published. Editing is disabled in the 7.) Course Creator Studio.'
            USING ERRCODE = 'P0051';
    END IF;

    -- check if this is the faculty of the course
    IF NOT EXISTS(
                SELECT 1
                FROM course_version_faculty cvf
                INNER JOIN internal.users u on u.user_id = cvf.user_id
                INNER JOIN auth.users a on a.id = u.auth_id
                WHERE u.auth_id = auth.uid() AND cvf.version_id = dcrpt_version_id) THEN
        RAISE EXCEPTION 'You are not authorized to perform any actions on this course.'
            USING ERRCODE = 'P0050';
    end if;

    -- SET UP ASSESSMENTS
    FOR c IN
    SELECT course_assessment_id, assessment_type_id, custom_assessment_name, weight::INT
    FROM jsonb_to_recordset(p_assessments)
         AS x(course_assessment_id TEXT, assessment_type_id TEXT, custom_assessment_name TEXT, weight INT)
    LOOP
        -- Validate Value
        IF c.assessment_type_id IS NULL or c.assessment_type_id = '' THEN
            IF c.custom_assessment_name IS NULL or c.custom_assessment_name = '' THEN
                RAISE EXCEPTION 'Parameter "Custom Assessment" is required. Please review it again.'
                USING ERRCODE = 'P0035';
            END IF;
        ELSIF c.custom_assessment_name IS NULL or c.custom_assessment_name = '' THEN
            IF c.assessment_type_id IS NULL or c.assessment_type_id = '' THEN
                RAISE EXCEPTION 'Parameter "Assessment Type" is required. Please review it again.'
                USING ERRCODE = 'P0035';
            END IF;
        ELSIF c.weight IS NULL THEN
            RAISE EXCEPTION 'Parameter "Weight" is required. Please review it again.'
            USING ERRCODE = 'P0035';
        end if;


        IF c.course_assessment_id IS NOT NULL THEN -- update

            BEGIN
                dcrpt_ca_id := pgp_sym_decrypt(
                        decode(c.course_assessment_id, 'base64'),
                        get_secret_key('get_phase2_data')
                    )::INT;
            EXCEPTION
                WHEN OTHERS THEN
                    RAISE EXCEPTION 'Valid Course Assessment ID required.'
                            USING ERRCODE = 'P1000';
            END;

            IF c.assessment_type_id is not null THEN
                dcrpt_asmt_type_id := pgp_sym_decrypt(
                    decode(c.assessment_type_id, 'base64'),
                    get_secret_key('get_assessment_types')
                )::INT;

                UPDATE course_assessment
                SET asmt_type_id = dcrpt_asmt_type_id,
                    weight = c.weight
                WHERE ca_id = dcrpt_ca_id;
            ELSE
                UPDATE course_assessment
                SET custom_asmt = c.custom_assessment_name,
                    weight = c.weight
                WHERE ca_id = dcrpt_ca_id;

            end if;
        ELSE -- insert
            IF c.assessment_type_id is not null THEN
                dcrpt_asmt_type_id := pgp_sym_decrypt(
                    decode(c.assessment_type_id, 'base64'),
                    get_secret_key('get_assessment_types')
                )::INT;
                INSERT INTO course_assessment (version_id, asmt_type_id, weight)
                VALUES (dcrpt_version_id, dcrpt_asmt_type_id, c.weight)
                ON CONFLICT DO NOTHING; -- avoid duplicate enrollments
            ELSE
                INSERT INTO course_assessment (version_id, custom_asmt, weight)
                VALUES (dcrpt_version_id, c.custom_assessment_name, c.weight)
                ON CONFLICT DO NOTHING; -- avoid duplicate enrollments
            end if;

        END IF;

        total_weight := total_weight + c.weight;

    END LOOP;

    IF total_weight != 100 THEN
        RAISE EXCEPTION 'All weights of assessments should add up to exactly 100%%. Please review it again'
            USING ERRCODE = 'P0052';
    end if;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
REVOKE ALL ON PROCEDURE internal.build_course_assessments(
    IN p_my_assigned_course_id TEXT,
    IN p_assessments JSONB
) FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE internal.build_course_assessments(
    IN p_my_assigned_course_id TEXT,
    IN p_assessments JSONB
) TO authenticated;




--- TASK 2.3 Upload Course Materials

---- SUBTASK 2.3.1 Get lessons                                                                      STATUS: _DEVELOPED

CREATE OR REPLACE FUNCTION internal.get_lessons(IN p_my_assigned_course_id TEXT)
RETURNS TABLE(
    id TEXT, -- 1
    name TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    request_payload JSONB;
    dcrpt_version_id INT;
BEGIN

    -- decrypt VERSION ID
    BEGIN
        request_payload = (pgp_sym_decrypt(
                    decode(p_my_assigned_course_id, 'base64'),
                    internal.get_secret_key('my_assigned_courses')
                ))::jsonb;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Valid Course ID required.'
                        USING ERRCODE = 'P1000';
    END;

    dcrpt_version_id := (request_payload->>'version_id')::INT;

    IF request_payload->>'status' = 'Pending Approval' THEN
        RETURN QUERY
        SELECT NULL::TEXT, NULL::TEXT
        WHERE FALSE;
    END IF;

    IF request_payload->>'status' = 'Published' THEN
        RETURN QUERY
        SELECT NULL::TEXT, NULL::TEXT
        WHERE FALSE;
    END IF;

    -- Only run main query if key exists and confirm the user role
    IF (
        (SELECT check_user_role(ARRAY['faculty'])) = TRUE AND
        internal.get_secret_key('get_lessons') IS NOT NULL) THEN
        RETURN QUERY
            SELECT
            -- 1.) ID (encrypted)
            encode(
                pgp_sym_encrypt(
                    jsonb_build_object(
                        'lesson_id', lesson_id::INT,
                        'status', (
                                SELECT
                                    CASE
                                        WHEN (COALESCE(COUNT(l.lesson_id), 0) = 0 AND COALESCE(COUNT(ca.ca_id), 0) = 0) AND cv.is_ready IS FALSE AND cv.apvd_rvwd_by IS NULL THEN 'Not Started'
                                        WHEN (COALESCE(COUNT(l.lesson_id), 0) > 0 OR COALESCE(COUNT(ca.ca_id), 0) > 0) AND cv.is_ready IS FALSE AND cv.apvd_rvwd_by IS NULL THEN 'Drafting'
                                        WHEN cv.is_ready IS TRUE AND cv.apvd_rvwd_by IS NULL THEN 'Pending Approval'
                                        WHEN cv.is_ready IS TRUE AND cv.apvd_rvwd_by IS NOT NULL THEN 'Published'
                                    END
                                FROM course_version_faculty cvf
                                    INNER JOIN internal.course_version cv ON cv.version_id = cvf.version_id
                                        LEFT JOIN internal.lesson l on cv.version_id = l.version_id
                                        LEFT JOIN internal.course_assessment ca on cv.version_id = ca.version_id
                                    WHERE cvf.version_id = dcrpt_version_id
                                    group by cvf.version_id, cv.is_ready, cv.apvd_rvwd_by
                            )
                        )::text,
                        internal.get_secret_key('get_lessons')
                        ),
                        'base64'
            )::text,

            lesson_name::text

            FROM lesson where version_id = dcrpt_version_id;
    ELSE
        -- No secret key, return empty result set
        RETURN QUERY
        SELECT NULL::TEXT, NULL::TEXT
        WHERE FALSE;
    END IF;
END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION internal.get_lessons(IN p_my_assigned_course_id TEXT) FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION internal.get_lessons(IN p_my_assigned_course_id TEXT) TO authenticated;


---- SUBTASK 2.3.2 Attach Course Materials UUID                                                     STATUS: _DEVELOPED

CREATE OR REPLACE PROCEDURE internal.build_course_materials(
    IN p_contents JSONB
)
SET search_path = internal
AS $$
DECLARE
    request_payload JSONB;
    dcrpt_lesson_id INT;
    item RECORD;
    video UUID;
    resource UUID;
    link text;
    video_uuid UUID := NULL;
    other_uuid UUID := NULL;
    v record;
    dcrpt_material_id INT;
BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['faculty'])) = FALSE THEN
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    END IF;

    FOR item IN
        SELECT
            lesson_id, -- text to be decrypt to jsonb and extract lesson_id and status
            video_materials,
            other_resources,
            links
        FROM jsonb_to_recordset(p_contents)
            AS x(
                lesson_id TEXT,
                video_materials JSONB,
                other_resources JSONB, -- FROM UUID[] TO JSONB
                links JSONB -- from text[] to jsonb
            )
    LOOP
        -- Validate lesson ID
        IF item.lesson_id IS NULL OR item.lesson_id = '' THEN
            RAISE EXCEPTION 'Parameter "Lesson ID" is required. Please review it again.'
                USING ERRCODE = 'P0035';
        END IF;

        IF item.video_materials IS NULL OR jsonb_array_length(item.video_materials) = 0 THEN
            RAISE EXCEPTION 'Lesson % has no video materials', item.lesson_id
                USING ERRCODE = 'P0035';
        END IF;

        -- decrypt lesson ID
        BEGIN
            request_payload = (pgp_sym_decrypt(
                        decode(item.lesson_id, 'base64'),
                        internal.get_secret_key('get_lessons')
                    ))::jsonb;
        EXCEPTION
            WHEN OTHERS THEN
                RAISE EXCEPTION 'Valid Lesson ID required.'
                            USING ERRCODE = 'P1000';
        END;

        dcrpt_lesson_id := (request_payload->>'lesson_id')::INT;

        IF request_payload->>'status' = 'Pending Approval' THEN
            RAISE EXCEPTION 'This course is currently pending approval. You may wait for review or choose to unsubmit it to make further edits in the 7.) Course Creator Studio.'
                USING ERRCODE = 'P0051';
        END IF;

        IF request_payload->>'status' = 'Published' THEN
            RAISE EXCEPTION 'This course is already published. Editing is disabled in the 7.) Course Creator Studio.'
                USING ERRCODE = 'P0051';
        END IF;

        -- check if this is the faculty of the course
        IF NOT EXISTS(
                    SELECT 1
                    FROM course_version_faculty cvf
                    INNER JOIN internal.users u on u.user_id = cvf.user_id
                    INNER JOIN auth.users a on a.id = u.auth_id
                    WHERE u.auth_id = auth.uid() AND cvf.version_id = (SELECT DISTINCT version_id FROM lesson where lesson_id = dcrpt_lesson_id)
        ) THEN
            RAISE EXCEPTION 'You are not authorized to perform any actions on this course.'
                USING ERRCODE = 'P0050';
        end if;

        IF NOT EXISTS(SELECT 1 FROM LESSON WHERE LESSON_ID = dcrpt_lesson_id) THEN
            RAISE EXCEPTION 'This lesson ID does not exists. Please review it again.'
                USING ERRCODE = 'P0060';
        end if;

        -- TODO: insert into your course_materials table here

        -- VIDEOS
        FOR v IN
        SELECT
            material_id,
            video_title,
            (video_id)::UUID,
            video_duration
        FROM jsonb_to_recordset(item.video_materials)
            AS x(
                material_id TEXT,
                video_title TEXT,
                video_id UUID,
                video_duration TEXT
            )
        LOOP
            SELECT id INTO video_uuid
            FROM STORAGE.OBJECTS
            WHERE bucket_id = 'course-materials'
            AND  name like CONCAT('video-materials/', v.video_id ,'%')
            and owner = auth.uid();

            IF video_uuid IS NULL THEN
                RAISE EXCEPTION 'This Course Video doesn''t exists'
                    USING ERRCODE = 'P0035';
            end if;


            IF v.material_id IS NOT NULL THEN -- update
                BEGIN
                    dcrpt_material_id := pgp_sym_decrypt(
                            decode(v.material_id, 'base64'),
                            get_secret_key('get_phase3_data')
                        )::INT;
                EXCEPTION
                    WHEN OTHERS THEN
                        RAISE EXCEPTION 'Valid Material ID required.'
                                USING ERRCODE = 'P1000';
                END;

                IF EXISTS (SELECT 1 FROM course_material WHERE material_name = trim(v.video_title) AND lesson_id = dcrpt_lesson_id AND material_id != dcrpt_material_id) THEN
                    RAISE EXCEPTION 'Material name "%" already exists.', trim(v.video_title)
                        USING ERRCODE = 'P0035';
                end if;

                UPDATE course_material
                SET material_name = trim(v.video_title),
                    video_duration = v.video_duration::INTERVAL,
                    material = video_uuid
                WHERE material_id = dcrpt_material_id;

                -- CHANGING LESSON OR MOVING MATERIAL TO ANOTHER LESSON ISN'T SUPPORTED YET

            else -- insert new
                IF EXISTS (SELECT 1 FROM course_material WHERE material_name = trim(v.video_title) AND lesson_id = dcrpt_lesson_id) THEN
                    RAISE EXCEPTION 'Material name "%" already exists.', trim(v.video_title)
                        USING ERRCODE = 'P0035';
                end if;

                INSERT INTO course_material (material_name, video_duration, material, lesson_id)
                VALUES (trim(v.video_title), v.video_duration::INTERVAL, video_uuid, dcrpt_lesson_id);

            end if;

        end loop;

        -- OTHER RESOURCES [OPTIONAL]
        IF item.other_resources IS NOT NULL OR jsonb_array_length(item.other_resources) > 0 THEN
            FOR v IN
            SELECT
                material_id,
                (resource_id)::UUID,
                resource_name
            FROM jsonb_to_recordset(item.other_resources)
                AS x(
                    material_id TEXT,
                    resource_id UUID,
                    resource_name TEXT
                )
            LOOP
                SELECT id INTO other_uuid
                FROM STORAGE.OBJECTS
                WHERE bucket_id = 'course-materials'
                AND  name like CONCAT('other-resources/', v.resource_id ,'%')
                and owner = auth.uid();

                IF other_uuid IS NULL THEN
                    RAISE EXCEPTION 'This additional material doesn''t exists'
                        USING ERRCODE = 'P0035';
                end if;


                IF v.material_id IS NOT NULL THEN
                    BEGIN
                        dcrpt_material_id := pgp_sym_decrypt(
                                decode(v.material_id, 'base64'),
                                get_secret_key('get_phase3_data')
                            )::INT;
                    EXCEPTION
                        WHEN OTHERS THEN
                            RAISE EXCEPTION 'Valid Material ID required.'
                                    USING ERRCODE = 'P1000';
                    END;

                    UPDATE course_material
                    SET material = other_uuid,
                        material_name = v.resource_name,
                        video_duration = null
                    WHERE material_id = dcrpt_material_id;

                ELSE
                    INSERT INTO course_material (material, lesson_id, material_name, video_duration)
                        VALUES (other_uuid, dcrpt_lesson_id, v.resource_name, null);

                end if;

            end loop;

        END IF;


        -- LINKS
        IF item.links IS NOT NULL OR jsonb_array_length(item.links) > 0 THEN
            FOR v IN
            SELECT
                material_id,
                url
            FROM jsonb_to_recordset(item.links)
                AS x(
                    material_id TEXT,
                    url TEXT
                )
            LOOP

                IF v.material_id IS NOT NULL THEN
                    BEGIN
                        dcrpt_material_id := pgp_sym_decrypt(
                                decode(v.material_id, 'base64'),
                                get_secret_key('get_phase3_data')
                            )::INT;
                    EXCEPTION
                        WHEN OTHERS THEN
                            RAISE EXCEPTION 'Valid Material ID required.'
                                    USING ERRCODE = 'P1000';
                    END;

                    UPDATE course_material
                    SET link = trim(v.url)
                    WHERE material_id = dcrpt_material_id;

                ELSE
                    INSERT INTO course_material (link, lesson_id, material_name)
                        VALUES (trim(v.url), dcrpt_lesson_id, 'link' || substr(md5(random()::text), 1, 8));
                end if;

            end loop;

        END IF;


    END LOOP;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
REVOKE ALL ON PROCEDURE internal.build_course_materials(
    IN p_contents JSONB
) FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE internal.build_course_materials(
    IN p_contents JSONB
) TO authenticated;



--- TASK 2.4 Add Assessment: Assignments

---- SUBTASK 2.4.1 get Structured Assessments                                                       STATUS: _DEVELOPED

CREATE OR REPLACE FUNCTION internal.get_structured_assessments (IN p_my_assigned_course_id TEXT)
RETURNS TABLE(
    id TEXT, -- 1
    name TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    request_payload JSONB;
    dcrpt_version_id INT;
BEGIN
    -- decrypt VERSION ID
    BEGIN
        request_payload = (pgp_sym_decrypt(
                    decode(p_my_assigned_course_id, 'base64'),
                    internal.get_secret_key('my_assigned_courses')
                ))::jsonb;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Valid Course ID required.'
                        USING ERRCODE = 'P1000';
    END;

    dcrpt_version_id := (request_payload->>'version_id')::INT;

    IF request_payload->>'status' = 'Pending Approval' THEN
        RETURN QUERY
        SELECT NULL::TEXT, NULL::TEXT
        WHERE FALSE;
    END IF;

    IF request_payload->>'status' = 'Published' THEN
        RETURN QUERY
        SELECT NULL::TEXT, NULL::TEXT
        WHERE FALSE;
    END IF;

    -- Only run main query if key exists and confirm the user role
    IF (
        (SELECT check_user_role(ARRAY['faculty'])) = TRUE AND
        internal.get_secret_key('get_structured_assessments') IS NOT NULL) THEN
        RETURN QUERY
            SELECT
            -- 1.) ID (encrypted)
            encode(
                pgp_sym_encrypt(
                    jsonb_build_object(
                        'ca_id', ca.ca_id::INT,
                        'status', (
                                SELECT
                                    CASE
                                        WHEN (COALESCE(COUNT(l.lesson_id), 0) = 0 AND COALESCE(COUNT(ca.ca_id), 0) = 0) AND cv.is_ready IS FALSE AND cv.apvd_rvwd_by IS NULL THEN 'Not Started'
                                        WHEN (COALESCE(COUNT(l.lesson_id), 0) > 0 OR COALESCE(COUNT(ca.ca_id), 0) > 0) AND cv.is_ready IS FALSE AND cv.apvd_rvwd_by IS NULL THEN 'Drafting'
                                        WHEN cv.is_ready IS TRUE AND cv.apvd_rvwd_by IS NULL THEN 'Pending Approval'
                                        WHEN cv.is_ready IS TRUE AND cv.apvd_rvwd_by IS NOT NULL THEN 'Published'
                                    END
                                FROM course_version_faculty cvf
                                    INNER JOIN internal.course_version cv ON cv.version_id = cvf.version_id
                                        LEFT JOIN internal.lesson l on cv.version_id = l.version_id
                                        LEFT JOIN internal.course_assessment ca on cv.version_id = ca.version_id
                                    WHERE cvf.version_id = dcrpt_version_id
                                    group by cvf.version_id, cv.is_ready, cv.apvd_rvwd_by
                            )
                        )::text,
                        internal.get_secret_key('get_structured_assessments')
                        ),
                        'base64'
            )::text,

            CASE
                WHEN ca.asmt_type_id IS NULL THEN ca.custom_asmt::TEXT
                ELSE a.asmt_name::TEXT
            END

            FROM course_assessment ca
            left join internal.assessment_type a on a.asmt_type_id = ca.asmt_type_id
            where version_id = dcrpt_version_id;
    ELSE
        -- No secret key, return empty result set
        RETURN QUERY
        SELECT NULL::TEXT, NULL::TEXT
        WHERE FALSE;
    END IF;
END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION internal.get_structured_assessments (IN p_my_assigned_course_id TEXT) FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION internal.get_structured_assessments (IN p_my_assigned_course_id TEXT) TO authenticated;


---- SUBTASK 2.4.2 Structure assignments                                                            STATUS: _DEVELOPED

CREATE OR REPLACE PROCEDURE internal.build_course_assignments(
    IN p_assignments JSONB
)
SET search_path = internal
AS $$
DECLARE
    request_payload JSONB;
    request_payload2 JSONB;
    dcrpt_lesson_id INT;
    dcrpt_ca_id INT;
    item RECORD;
    attach UUID;
    attachment_uuid UUID := NULL;
    v RECORD;
    dcrpt_attachment_id INT;
    dcrpt_ass_id INT;
    returned_ass_id INT;
BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['faculty'])) = FALSE THEN
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    END IF;


    -- SET UP ASSIGNMENTS
    FOR item IN
    SELECT
            assignment_id, title, maximum_points::INT, description, structured_assessment_id, lesson_id, attachments, relative_offset::INT
    FROM jsonb_to_recordset(p_assignments)
        AS x(
            assignment_id text,
            title TEXT,
            maximum_points INT,
            description TEXT,
            structured_assessment_id TEXT, -- id here ca_id
            lesson_id TEXT, -- id here lesson_id
            attachments JSONB,
            relative_offset INT
        )
    LOOP
        -- Validate Value
        IF item.title IS NULL or item.title = '' THEN
            RAISE EXCEPTION 'Parameter "Assignment Title" is required. Please review it again.'
                USING ERRCODE = 'P0043';
        ELSIF item.maximum_points IS NULL THEN
            RAISE EXCEPTION 'Parameter "Maximum Achievable Points" is required. Please review it again.'
                USING ERRCODE = 'P0043';
        ELSIF item.description IS NULL or item.description = '' THEN
            RAISE EXCEPTION 'Parameter "Description" is required. Please review it again.'
            USING ERRCODE = 'P0043';
        ELSIF item.structured_assessment_id IS NULL or item.structured_assessment_id = '' THEN
            RAISE EXCEPTION 'Parameter "Assessment" is required. Please review it again.'
            USING ERRCODE = 'P0043';
        end if;

        -- decrypt Course Assessment ID
        BEGIN
            request_payload = (pgp_sym_decrypt(
                        decode(item.structured_assessment_id, 'base64'),
                        internal.get_secret_key('get_structured_assessments')
                    ))::jsonb;
        EXCEPTION
            WHEN OTHERS THEN
                RAISE EXCEPTION 'Valid Course Assessment ID required.'
                            USING ERRCODE = 'P1000';
        END;

        dcrpt_ca_id := (request_payload->>'ca_id')::INT;

        IF request_payload->>'status' = 'Pending Approval' THEN
            RAISE EXCEPTION 'This course is currently pending approval. You may wait for review or choose to unsubmit it to make further edits in the 7.) Course Creator Studio.'
                USING ERRCODE = 'P0051';
        END IF;

        IF request_payload->>'status' = 'Published' THEN
            RAISE EXCEPTION 'This course is already published. Editing is disabled in the 7.) Course Creator Studio.'
                USING ERRCODE = 'P0051';
        END IF;

        -- decrypt Lesson ID
        BEGIN
            request_payload2 = (pgp_sym_decrypt(
                        decode(item.lesson_id, 'base64'),
                        internal.get_secret_key('get_lessons')
                    ))::jsonb;
        EXCEPTION
            WHEN OTHERS THEN
                RAISE EXCEPTION 'Valid Lesson ID required.'
                            USING ERRCODE = 'P1000';
        END;

        dcrpt_lesson_id := (request_payload2->>'lesson_id')::INT;

        -- check if this is the faculty of the course
        IF NOT EXISTS(
                    SELECT 1
                    FROM course_version_faculty cvf
                    INNER JOIN internal.users u on u.user_id = cvf.user_id
                    INNER JOIN auth.users a on a.id = u.auth_id
                    WHERE u.auth_id = auth.uid() AND cvf.version_id = (SELECT DISTINCT version_id FROM lesson where lesson_id = dcrpt_lesson_id)) THEN
            RAISE EXCEPTION 'You are not authorized to perform any actions on this course.'
                USING ERRCODE = 'P0050';
        end if;

        IF item.assignment_id IS NOT NULL THEN
            BEGIN
                dcrpt_ass_id := pgp_sym_decrypt(
                    decode(item.assignment_id, 'base64'),
                    get_secret_key('get_phase4_data')
                )::INT;
            EXCEPTION
                WHEN OTHERS THEN
                    RAISE EXCEPTION 'Valid Assignment ID required.'
                        USING ERRCODE = 'P1000';
            END;

            UPDATE assignment
            SET ass_title = trim(item.title),
                total_points = item.maximum_points,
                descr = item.description,
                lesson_id = dcrpt_lesson_id,
                ca_id = dcrpt_ca_id,
                relative_offset = (item.relative_offset * INTERVAL '1 day')
            WHERE ass_id = dcrpt_ass_id;
        ELSE
            INSERT INTO assignment (ass_title, total_points, descr, lesson_id, ca_id, relative_offset)
            VALUES (trim(item.title), item.maximum_points, item.description, dcrpt_lesson_id, dcrpt_ca_id, (item.relative_offset * INTERVAL '1 day'))
            ON CONFLICT DO NOTHING
            RETURNING ass_id INTO returned_ass_id; -- avoid duplicate enrollments
        end if;


        IF item.attachments IS NOT NULL OR jsonb_array_length(item.attachments) > 0 THEN
            FOR v IN
            SELECT
                attachment_iid,
                (attachment_id)::UUID
            FROM jsonb_to_recordset(item.attachments)
                AS x(
                    attachment_iid TEXT,
                    attachment_id UUID
                )
            LOOP

                IF v.attachment_iid IS NOT NULL THEN
                    BEGIN
                        dcrpt_attachment_id := pgp_sym_decrypt(
                                decode(v.attachment_iid, 'base64'),
                                get_secret_key('get_phase4_data')
                            )::INT;
                    EXCEPTION
                        WHEN OTHERS THEN
                            RAISE EXCEPTION 'Valid Attachment ID required.'
                                    USING ERRCODE = 'P1000';
                    END;

                    SELECT id INTO attachment_uuid
                    FROM STORAGE.OBJECTS
                    WHERE bucket_id = 'course-materials'
                    AND  name like CONCAT('assignment-attachments/', v.attachment_id ,'%')
                    and owner = auth.uid();

                    IF attachment_uuid IS NULL THEN
                        RAISE EXCEPTION 'This Attachment doesn''t exists'
                            USING ERRCODE = 'P0035';
                    end if;

                    UPDATE attachment
                    SET file_id = attachment_uuid
                    WHERE attachment_id = dcrpt_attachment_id;

                ELSE
                    SELECT id INTO attachment_uuid
                    FROM STORAGE.OBJECTS
                    WHERE bucket_id = 'course-materials'
                    AND  name like CONCAT('assignment-attachments/', v.attachment_id ,'%')
                    and owner = auth.uid();

                    IF attachment_uuid IS NULL THEN
                        RAISE EXCEPTION 'This Attachment doesn''t exists'
                            USING ERRCODE = 'P0035';
                    end if;

                    INSERT INTO attachment (file_id, ass_id)
                    VALUES (attachment_uuid, returned_ass_id);
                end if;
            end loop;
        END IF;

    END LOOP;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
REVOKE ALL ON PROCEDURE internal.build_course_assignments(
    IN p_assignments JSONB
) FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE internal.build_course_assignments(
    IN p_assignments JSONB
) TO authenticated;



--- TASK 2.5 Add Assessment: Quizes or Exams

---- SUBTASK 2.5.1 get answer types                                                                 STATUS: _DEVELOPED

CREATE OR REPLACE FUNCTION internal.get_answer_types()
RETURNS TABLE(
    id TEXT, -- 1
    name TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    dcrpt_version_id INT;
BEGIN
    -- Only run main query if key exists and confirm the user role
    IF (
        (SELECT check_user_role(ARRAY['faculty'])) = TRUE AND
        internal.get_secret_key('get_answer_types') IS NOT NULL) THEN
        RETURN QUERY
            SELECT
            -- 1.) ID (encrypted)
            encode(
                pgp_sym_encrypt(anst_id::TEXT, internal.get_secret_key('get_answer_types')),
                'base64'
            )::TEXT,

            answer_type::text

            FROM answer_type;
    ELSE
        -- No secret key, return empty result set
        RETURN QUERY
        SELECT NULL::TEXT, NULL::TEXT
        WHERE FALSE;
    END IF;
END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION internal.get_answer_types() FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION internal.get_answer_types() TO authenticated;



---- SUBTASK 2.5.2 Add tests                                                                        STATUS: _DEVELOPED

CREATE OR REPLACE PROCEDURE internal.build_course_tests(
    IN p_tests JSONB
)
SET search_path = internal
AS $proc$
DECLARE
    request_payload JSONB;
    request_payload2 JSONB;
    dcrpt_ca_id       INT;
    dcrpt_lesson_id   INT;
    dcrpt_anst_id     INT;

    item              RECORD; -- one test
    item2             RECORD; -- one question
    item3             RECORD; -- one answer option

    f_test_id         INT;
    f_question_id     INT;

    answer            TEXT;   -- answer type label (e.g., 'multiple choice')
    correct_counter   INT;

    dcrpt_test_id     INT;
    dcrpt_question_id INT;
    dcrpt_key_id INT;
BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['faculty'])) = FALSE THEN
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    END IF;

    -- expand top-level tests
    FOR item IN
        SELECT
            test_id,
            title,
            description,
            (time_limit)::interval AS time_limit,
            (allowed_attempts)::int AS allowed_attempts,
            structured_assessment_id,
            lesson_id,
            questions
        FROM jsonb_to_recordset(p_tests) AS x(
            test_id TEXT,
            title                   TEXT,
            description             TEXT,
            time_limit              INTERVAL,
            allowed_attempts        INT,
            structured_assessment_id TEXT, -- ca_id
            lesson_id               TEXT, -- lesson_id
            questions               JSONB
        )
    LOOP
        -- validations
        IF item.title IS NULL OR item.title = '' THEN
            RAISE EXCEPTION 'Parameter "Assignment Title" is required. Please review it again.'
                USING ERRCODE = 'P0043';
        ELSIF item.time_limit IS NULL THEN
            RAISE EXCEPTION 'Parameter "Time Limit" is required. Please review it again.'
                USING ERRCODE = 'P0043';
        ELSIF item.description IS NULL OR item.description = '' THEN
            RAISE EXCEPTION 'Parameter "Description" is required. Please review it again.'
                USING ERRCODE = 'P0043';
        ELSIF item.allowed_attempts IS NULL THEN
            RAISE EXCEPTION 'Parameter "Allowed Attempts" is required. Please review it again.'
                USING ERRCODE = 'P0043';
        ELSIF item.structured_assessment_id IS NULL OR item.structured_assessment_id = '' THEN
            RAISE EXCEPTION 'Parameter "Assessment" is required. Please review it again.'
                USING ERRCODE = 'P0043';
        ELSIF item.questions IS NULL
              OR jsonb_typeof(item.questions) <> 'array'
              OR jsonb_array_length(item.questions) = 0 THEN
            RAISE EXCEPTION 'Parameter "Questions" is required and cannot be empty.'
                USING ERRCODE = 'P0043';
        END IF;

        -- decrypt Course Assessment ID
        BEGIN
            request_payload = (pgp_sym_decrypt(
                        decode(item.structured_assessment_id, 'base64'),
                        internal.get_secret_key('get_structured_assessments')
                    ))::jsonb;
        EXCEPTION
            WHEN OTHERS THEN
                RAISE EXCEPTION 'Valid Course Assessment ID required.'
                            USING ERRCODE = 'P1000';
        END;

        dcrpt_ca_id := (request_payload->>'ca_id')::INT;

        IF request_payload->>'status' = 'Pending Approval' THEN
            RAISE EXCEPTION 'This course is currently pending approval. You may wait for review or choose to unsubmit it to make further edits in the 7.) Course Creator Studio.'
                USING ERRCODE = 'P0051';
        END IF;

        IF request_payload->>'status' = 'Published' THEN
            RAISE EXCEPTION 'This course is already published. Editing is disabled in the 7.) Course Creator Studio.'
                USING ERRCODE = 'P0051';
        END IF;

        -- decrypt Lesson ID
        BEGIN
            request_payload2 = (pgp_sym_decrypt(
                        decode(item.lesson_id, 'base64'),
                        internal.get_secret_key('get_lessons')
                    ))::jsonb;
        EXCEPTION
            WHEN OTHERS THEN
                RAISE EXCEPTION 'Valid Course ID required.'
                            USING ERRCODE = 'P1000';
        END;

        dcrpt_lesson_id := (request_payload2->>'lesson_id')::INT;

        -- check if this is the faculty of the course
        IF NOT EXISTS(
                    SELECT 1
                    FROM course_version_faculty cvf
                    INNER JOIN internal.users u on u.user_id = cvf.user_id
                    INNER JOIN auth.users a on a.id = u.auth_id
                    WHERE u.auth_id = auth.uid() AND cvf.version_id = (SELECT DISTINCT version_id FROM lesson where lesson_id = dcrpt_lesson_id)) THEN
            RAISE EXCEPTION 'You are not authorized to perform any actions on this course.'
                USING ERRCODE = 'P0050';
        end if;

        IF item.test_id IS NOT NULL THEN
            BEGIN
                dcrpt_test_id = (pgp_sym_decrypt(
                            decode(item.test_id, 'base64'),
                            internal.get_secret_key('get_phase5_data')
                        ))::jsonb;
            EXCEPTION
                WHEN OTHERS THEN
                    RAISE EXCEPTION 'Valid Test ID required.'
                                USING ERRCODE = 'P1000';
            END;

            UPDATE test
            SET test_title = trim(item.title),
                descr = item.description,
                time_limit = item.time_limit,
                allowed_attempts = item.allowed_attempts,
                ca_id = dcrpt_ca_id,
                lesson_id = dcrpt_lesson_id
            WHERE test_id = dcrpt_test_id;
        ELSE
            -- insert test
            INSERT INTO test (test_title, descr, time_limit, allowed_attempts, ca_id, lesson_id)
            VALUES (trim(item.title), item.description, item.time_limit, item.allowed_attempts, dcrpt_ca_id, dcrpt_lesson_id)
            RETURNING test_id INTO f_test_id;
        end if;

        -- expand questions
        FOR item2 IN
            SELECT
                question_id,
                question,
                (total_points)::int AS total_points,
                answer_type_id,
                answers
            FROM jsonb_to_recordset(item.questions) AS x(
                question_id     TEXT,
                question        TEXT,
                total_points    INT,
                answer_type_id  TEXT,
                answers         JSONB
            )
        LOOP
            -- decrypt answer type id
            BEGIN
                dcrpt_anst_id := pgp_sym_decrypt(
                    decode(item2.answer_type_id, 'base64'),
                    get_secret_key('get_answer_types')
                )::INT;
            EXCEPTION
                WHEN OTHERS THEN
                    RAISE EXCEPTION 'Valid Answer Type ID required.'
                                USING ERRCODE = 'P1000';
            END;

            -- fetch answer type label
            SELECT at.answer_type
              INTO answer
            FROM internal.answer_type at
            WHERE at.anst_id = dcrpt_anst_id;

            IF item2.question_id IS NOT NULL THEN
                BEGIN
                    dcrpt_question_id = (pgp_sym_decrypt(
                                decode(item2.question_id, 'base64'),
                                internal.get_secret_key('get_phase5_data')
                            ))::jsonb;
                EXCEPTION
                    WHEN OTHERS THEN
                        RAISE EXCEPTION 'Valid Question ID required.'
                                    USING ERRCODE = 'P1000';
                END;

                UPDATE question
                SET question = trim(item2.question),
                    test_id = dcrpt_test_id,
                    anst_id = dcrpt_anst_id,
                    total_points = item2.total_points
                WHERE question_id = dcrpt_question_id;
            ELSE
                -- insert question
                INSERT INTO question (question, test_id, anst_id, total_points)
                VALUES (trim(item2.question), COALESCE(f_test_id, dcrpt_test_id), dcrpt_anst_id, item2.total_points)
                RETURNING question_id INTO f_question_id;
            END IF;

            -- reset per question
            correct_counter := 0;

            -- branch per answer type
            IF answer = 'multiple choice' THEN
                FOR item3 IN
                    SELECT key_id, item_choice, is_correct
                    FROM jsonb_to_recordset(item2.answers) AS x(
                        key_id TEXT,
                        item_choice TEXT,
                        is_correct  BOOLEAN
                    )
                LOOP
                    IF item3.key_id IS NOT NULL THEN
                        BEGIN
                            dcrpt_key_id = (pgp_sym_decrypt(
                                        decode(item3.key_id, 'base64'),
                                        internal.get_secret_key('get_phase5_data')
                                    ))::jsonb;
                        EXCEPTION
                            WHEN OTHERS THEN
                                RAISE EXCEPTION 'Valid Key ID required.'
                                            USING ERRCODE = 'P1000';
                        END;

                        UPDATE answer_key
                        SET text_key = trim(item3.item_choice),
                            is_correct = item3.is_correct
                        WHERE key_id = dcrpt_key_id;
                    ELSE
                        INSERT INTO internal.answer_key (text_key, is_correct, question_id)
                        VALUES (trim(item3.item_choice), item3.is_correct, COALESCE(f_question_id, dcrpt_question_id));
                    END IF;

                    IF item3.is_correct IS TRUE THEN
                        correct_counter := correct_counter + 1;
                    END IF;
                END LOOP;

                IF correct_counter <> 1 THEN
                    RAISE EXCEPTION 'A Multiple choice type question "%" must have exactly 1 true answer (found: %).',
                        item2.question, correct_counter
                        USING ERRCODE = 'P0035';
                END IF;

            ELSIF answer = 'true/false' THEN
                FOR item3 IN
                    SELECT key_id, tof_key
                    FROM jsonb_to_recordset(item2.answers) AS x(
                        key_id  TEXT,
                        tof_key BOOLEAN
                    )
                LOOP
                    IF item3.key_id IS NOT NULL THEN
                        BEGIN
                            dcrpt_key_id = (pgp_sym_decrypt(
                                        decode(item3.key_id, 'base64'),
                                        internal.get_secret_key('get_phase5_data')
                                    ))::jsonb;
                        EXCEPTION
                            WHEN OTHERS THEN
                                RAISE EXCEPTION 'Valid Key ID required.'
                                            USING ERRCODE = 'P1000';
                        END;

                        UPDATE answer_key
                        SET tof_key = item3.tof_key
                        WHERE key_id = dcrpt_key_id;
                    ELSE
                        INSERT INTO internal.answer_key (tof_key, question_id)
                        VALUES (item3.tof_key, COALESCE(f_question_id, dcrpt_question_id));
                    END IF;

                    correct_counter := correct_counter + 1;
                END LOOP;

                IF correct_counter <> 1 THEN
                    RAISE EXCEPTION 'A True/False type question "%" must have exactly 1 answer (found: %).',
                        item2.question, correct_counter
                        USING ERRCODE = 'P0035';
                END IF;

            ELSIF answer = 'identification' THEN
                FOR item3 IN
                    SELECT key_id, item_choice
                    FROM jsonb_to_recordset(item2.answers) AS x(
                        key_id  TEXT,
                        item_choice TEXT
                    )
                LOOP
                    IF item3.key_id IS NOT NULL THEN
                        BEGIN
                            dcrpt_key_id = (pgp_sym_decrypt(
                                        decode(item3.key_id, 'base64'),
                                        internal.get_secret_key('get_phase5_data')
                                    ))::jsonb;
                        EXCEPTION
                            WHEN OTHERS THEN
                                RAISE EXCEPTION 'Valid Key ID required.'
                                            USING ERRCODE = 'P1000';
                        END;

                        UPDATE answer_key
                        SET
                            text_key = trim(item3.item_choice)
                        WHERE key_id = dcrpt_key_id;
                    ELSE
                        INSERT INTO internal.answer_key (text_key, question_id)
                        VALUES (trim(item3.item_choice), COALESCE(f_question_id, dcrpt_question_id));
                    END IF;

                    correct_counter := correct_counter + 1;
                END LOOP;

                IF correct_counter <> 1 THEN
                    RAISE EXCEPTION 'An Identification type question "%" must have exactly 1 answer (found: %).',
                        item2.question, correct_counter
                        USING ERRCODE = 'P0035';
                END IF;


            ELSIF answer = 'enumeration' THEN
                FOR item3 IN
                    SELECT key_id, required_items, possible_answers
                    FROM jsonb_to_recordset(item2.answers) AS x(
                        key_id TEXT,
                        required_items INT,
                        possible_answers TEXT[]
                    )
                LOOP
                    IF item3.key_id IS NOT NULL THEN
                        BEGIN
                            dcrpt_key_id = (pgp_sym_decrypt(
                                        decode(item3.key_id, 'base64'),
                                        internal.get_secret_key('get_phase5_data')
                                    ))::jsonb;
                        EXCEPTION
                            WHEN OTHERS THEN
                                RAISE EXCEPTION 'Valid Key ID required.'
                                            USING ERRCODE = 'P1000';
                        END;

                        UPDATE answer_key
                        SET
                            required_items = item3.required_items,
                            enum_keys = item3.possible_answers
                        WHERE key_id = dcrpt_key_id;
                    ELSE
                        INSERT INTO internal.answer_key (required_items, enum_keys, question_id)
                        VALUES (item3.required_items, item3.possible_answers, COALESCE(f_question_id, dcrpt_question_id));
                    END IF;
                END LOOP;

            ELSIF answer = 'essay' THEN

                IF item2.question_id IS NULL THEN
                    INSERT INTO internal.answer_key (question_id)
                    VALUES ( f_question_id);
                END IF;

            ELSE
                RAISE EXCEPTION 'Unknown answer type "%".', answer
                    USING ERRCODE = 'P0035';
            END IF;

            -- (optional) ensure clean state
            correct_counter := 0;
        END LOOP; -- questions

    END LOOP; -- tests
END;
$proc$ LANGUAGE plpgsql SECURITY DEFINER;
REVOKE ALL ON PROCEDURE internal.build_course_tests(
    IN p_tests JSONB
) FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE internal.build_course_tests(
    IN p_tests JSONB
) TO authenticated;






--- TASK 3. Submit Course for Review [Pre-Publish]                                                  STATUS: _DEVELOPED

CREATE OR REPLACE PROCEDURE internal.submit_course_for_review(
    IN p_my_assigned_course_id TEXT
)
SET search_path = internal
AS $$
DECLARE
    dcrpt_version_id INT;
    request_payload JSONB;
BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['faculty'])) = FALSE THEN
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    END IF;

    -- decrypt version ID
    BEGIN
        request_payload = (pgp_sym_decrypt(
                    decode(p_my_assigned_course_id, 'base64'),
                    internal.get_secret_key('my_assigned_courses')
                ))::jsonb;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Valid Course ID required.'
                        USING ERRCODE = 'P1000';
    END;

    dcrpt_version_id := (request_payload->>'version_id')::INT;

    IF request_payload->>'status' = 'Pending Approval' THEN
        RAISE EXCEPTION 'This course is currently pending approval. You may wait for review or choose to unsubmit it to make further edits in the 7.) Course Creator Studio.'
            USING ERRCODE = 'P0051';
    END IF;

    IF request_payload->>'status' = 'Published' THEN
        RAISE EXCEPTION 'This course is already published. Editing is disabled in the 7.) Course Creator Studio.'
            USING ERRCODE = 'P0051';
    END IF;

    -- check if this is the faculty of the course OR COURSE DON'T EXIST IN GENERAL
    IF NOT EXISTS(
                SELECT 1
                FROM course_version_faculty cvf
                INNER JOIN internal.users u on u.user_id = cvf.user_id
                INNER JOIN auth.users a on a.id = u.auth_id
                WHERE u.auth_id = auth.uid() AND cvf.version_id = dcrpt_version_id) THEN
        RAISE EXCEPTION 'You are not authorized to perform any actions on this course.'
            USING ERRCODE = 'P0050';
    end if;

    IF NOT EXISTS(
        SELECT 1 FROM lesson WHERE course_version = dcrpt_version_id
    )
    AND NOT EXISTS(
        SELECT 1 FROM course_assessment WHERE course_version = dcrpt_version_id
    ) THEN
        RAISE EXCEPTION 'Course can''t be submitted for review: no content found (lessons or assessments required).'
            USING ERRCODE = 'P0059';
    END IF;

    -- set the course to be ready for review
    UPDATE course_version
    SET is_ready = TRUE
    WHERE version_id = dcrpt_version_id;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
REVOKE ALL ON PROCEDURE internal.submit_course_for_review(
    IN p_my_assigned_course_id TEXT
) FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE internal.submit_course_for_review(
    IN p_my_assigned_course_id TEXT
) TO authenticated;





--- TASK 4. Enroll a student with COR upload                                                        STATUS: _DEVELOPED

CREATE OR REPLACE PROCEDURE internal.enroll_with_cor(
    IN p_my_assigned_course_id TEXT,
    IN p_student_email TEXT,
    IN p_cor_id UUID
)
SET search_path = internal
AS $proc$
DECLARE
    request_payload JSONB;
    dcrpt_version_id INT;
    v_student_id INT;
    cor_uuid UUID := NULL;

    rows_updated INT := NULL;
    act_sender INT;
    act_recipient INT;
    act_version_id INT;
    msg TEXT;

    f_cor UUID;
BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['faculty'])) = FALSE THEN
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    END IF;

    -- decrypt version ID
    BEGIN
        request_payload = (pgp_sym_decrypt(
                    decode(p_my_assigned_course_id, 'base64'),
                    internal.get_secret_key('my_assigned_courses')
                ))::jsonb;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Valid Course ID required.'
                        USING ERRCODE = 'P1000';
    END;

    dcrpt_version_id := (request_payload->>'version_id')::INT;

    IF request_payload->>'status' = 'Pending Approval' THEN
        RAISE EXCEPTION 'This course is currently pending approval. You may wait for review or choose to unsubmit it to make further edits in the 7.) Course Creator Studio.'
            USING ERRCODE = 'P0051';
    END IF;

--     IF request_payload->>'status' = 'Published' THEN
--         RAISE EXCEPTION 'This course is already published. Editing is disabled in the 7.) Course Creator Studio.'
--             USING ERRCODE = 'P0051';
--     END IF;

    if EXISTS (SELECT 1 FROM course_version WHERE version_id = dcrpt_version_id) THEN
        if NOT EXISTS (SELECT 1 FROM course_version WHERE apvd_rvwd_by IS NOT NULL AND version_id = dcrpt_version_id) THEN
        RAISE EXCEPTION 'Enrollment will be open once the Course is Published'
            USING ERRCODE = 'P0053';
        end if;
    else
        RAISE EXCEPTION 'Course doesn''t exist'
            USING ERRCODE = 'P0054';
    end if;

    -- check if this is the faculty of the course
    IF NOT EXISTS(
                SELECT 1
                FROM course_version_faculty cvf
                INNER JOIN internal.users u on u.user_id = cvf.user_id
                INNER JOIN auth.users a on a.id = u.auth_id
                WHERE u.auth_id = auth.uid() AND cvf.version_id = dcrpt_version_id) THEN
        RAISE EXCEPTION 'You are not authorized to perform any actions on this course.'
            USING ERRCODE = 'P0050';
    end if;

--     -- see if this is the faculty of this course
--     IF NOT EXISTS (SELECT 1
--                FROM course_version_faculty cvf
--                INNER JOIN internal.users u on u.user_id = cvf.user_id
--                WHERE u.auth_id = auth.uid()
--                AND version_id = dcrpt_version_id ) THEN
--         RAISE EXCEPTION 'You are not allowed to enroll a student in this course.'
--             USING ERRCODE = 'P0050';
--     end if;

    SELECT id INTO cor_uuid
    FROM STORAGE.OBJECTS
    WHERE bucket_id = 'enrollment-docs'
    AND  name like CONCAT('cor/', p_cor_id ,'%')
    and owner = auth.uid();

    IF cor_uuid IS NULL THEN
        RAISE EXCEPTION 'This COR file doesn''t exists'
            USING ERRCODE = 'P0035';
    end if;

    SELECT u.user_id INTO v_student_id
    FROM users u
    inner join auth.users a on u.auth_id = a.id
    inner join internal.designation_and_role d on u.dar_id = d.dar_id
    WHERE a.email = p_student_email and d.dar_name = 'student';

    if v_student_id is not null then

        -- enroll the student but check if this might be enrolled already
        IF EXISTS(
            SELECT 1 FROM my_courses WHERE user_id = v_student_id AND version_id = dcrpt_version_id
        )THEN

            SELECT cor INTO f_cor FROM my_courses WHERE user_id = v_student_id AND version_id = dcrpt_version_id;

            UPDATE my_courses
            SET enrollment_status = TRUE,
                cor = cor_uuid,
                proof_of_credit = null,
                official_list = null,
                enrld_date = now()
            WHERE user_id = v_student_id AND version_id = dcrpt_version_id;

            DELETE FROM storage.objects WHERE id = f_cor AND owner = auth.uid();

        ELSE
            INSERT INTO my_courses (user_id, version_id, cor)
            VALUES (v_student_id, dcrpt_version_id, cor_uuid);
        end if;

        GET DIAGNOSTICS rows_updated = ROW_COUNT;

            IF rows_updated > 0 THEN

                act_version_id := dcrpt_version_id;
                act_sender := (SELECT user_id FROM users WHERE auth_id = auth.uid());
                act_recipient := v_student_id;
                msg := format(
                    'Congratulations! You’re now enrolled in %s. Get ready to start learning and explore new ideas!',
                    (SELECT c.crs_title FROM prospectus_course pc INNER JOIN internal.course c ON c.crs_id = pc.crs_id WHERE pc.pc_id = act_version_id)
                );

                INSERT INTO course_activity (sender_id, recipient_id, version_id, type, metadata, message)
                    VALUES (
                        act_sender,
                        act_recipient,
                        act_version_id,
                        'faculty-enrollment',
                        jsonb_build_object(
                            'visibility', jsonb_build_array('analytics', 'notification'),
                            'pc_id', act_version_id
                        ),
                    msg
                    );
            end if;
    else
        RAISE EXCEPTION 'This student does''t exist.'
            USING ERRCODE = 'P0014';
    end if;

END;
$proc$ LANGUAGE plpgsql SECURITY DEFINER;
REVOKE ALL ON PROCEDURE internal.enroll_with_cor(
    IN p_my_assigned_course_id TEXT,
    IN p_student_email TEXT,
    IN p_cor_id UUID
) FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE internal.enroll_with_cor(
    IN p_my_assigned_course_id TEXT,
    IN p_student_email TEXT,
    IN p_cor_id UUID
) TO authenticated;





--- TASK 5. Remove Items in Creator Studio                                                          STATUS: _DEVELOPED

---- SUBTASK 5.1 Remove Wallpaper   STATUS: _DEVELOPED

CREATE OR REPLACE PROCEDURE internal.phase1_remove_wallpaper(IN p_wallpaper_iid TEXT)
SET search_path = internal
AS $$
DECLARE
    dcrpt_wallpaper_id UUID;
    f_version_id INT;
BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['faculty'])) = FALSE THEN
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    END IF;

    -- decrypt WALLPAPER ID
    BEGIN
        dcrpt_wallpaper_id := pgp_sym_decrypt(
            decode(p_wallpaper_iid, 'base64'),
            get_secret_key('get_phase1_data')
        )::UUID;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Valid "Wallpaper IDD" Required.'
                USING ERRCODE = 'P1000';
    END;

    f_version_id := (SELECT version_id FROM course_version WHERE wallpaper_id = dcrpt_wallpaper_id);

    -- CHECK IF FACULTY MATCH
    IF EXISTS (
        SELECT 1
        FROM course_version_faculty
        WHERE version_id = f_version_id
        AND user_id = (SELECT user_id FROM users WHERE auth_id = auth.uid())
    ) THEN

        -- CHECK IF COURSE ALREADY PUBLISHED
        IF EXISTS (
            SELECT 1 FROM course_version WHERE version_id = f_version_id AND apvd_rvwd_by is NULL
        )THEN
            -- if this wallpaper exists
            IF EXISTS(
                SELECT 1
                FROM storage.objects
                WHERE bucket_id = 'course-wallpaper'
                AND id = dcrpt_wallpaper_id
                AND owner = auth.uid()
            )THEN
                DELETE
                FROM storage.objects
                WHERE bucket_id = 'course-wallpaper'
                AND id = dcrpt_wallpaper_id
                AND owner = auth.uid();
            end if;
        ELSE
            RAISE EXCEPTION 'This course is already published. Editing is disabled in the 7.) Course Creator Studio.'
                USING ERRCODE = 'P0051';
        end if;

    ELSE
        RAISE EXCEPTION 'You are not authorized to perform any actions on this course.'
                USING ERRCODE = 'P0050';
    end if;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
REVOKE ALL ON PROCEDURE internal.phase1_remove_wallpaper(IN p_wallpaper_iid TEXT) FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE internal.phase1_remove_wallpaper(IN p_wallpaper_iid TEXT) TO authenticated;

---- SUBTASK 5.2 Remove Syllabus    STATUS: _DEVELOPED

CREATE OR REPLACE PROCEDURE internal.phase1_remove_syllabus(IN p_syllabus_iid TEXT)
SET search_path = internal
AS $$
DECLARE
    dcrpt_syllabus_id UUID;
    f_version_id int;
BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['faculty'])) = FALSE THEN
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    END IF;

    -- decrypt SYLLABUS ID
    BEGIN
        dcrpt_syllabus_id := pgp_sym_decrypt(
            decode(p_syllabus_iid, 'base64'),
            get_secret_key('get_phase1_data')
        )::UUID;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Valid "Syllabus IDD" Required.'
                USING ERRCODE = 'P1000';
    END;

    BEGIN
        f_version_id := (SELECT version_id FROM course_version WHERE syllabus_id = dcrpt_syllabus_id);
    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'duplicate use of syllabus id: % across different courses.', dcrpt_syllabus_id
                USING ERRCODE = 'P1000';
    END;

    -- CHECK IF FACULTY MATCH
    IF EXISTS (
        SELECT 1
        FROM course_version_faculty
        WHERE version_id = (SELECT version_id FROM course_version WHERE syllabus_id = dcrpt_syllabus_id)
        AND user_id = (SELECT user_id FROM users WHERE auth_id = auth.uid())
    ) THEN

        -- CHECK IF COURSE ALREADY PUBLISHED
        IF EXISTS (
            SELECT 1 FROM course_version WHERE version_id = f_version_id AND apvd_rvwd_by is null
        )THEN
            -- if this syllabus exists
            IF EXISTS(
                SELECT 1
                FROM storage.objects
                WHERE bucket_id = 'course-materials'
                AND id = dcrpt_syllabus_id
                AND owner = auth.uid()
            )THEN

                UPDATE course_version
                SET syllabus_id = NULL
                WHERE version_id = f_version_id;

                DELETE
                FROM storage.objects
                WHERE bucket_id = 'course-materials'
                AND id = dcrpt_syllabus_id
                AND owner = auth.uid();
            end if;

        ELSE
            RAISE EXCEPTION 'This course is already published. Editing is disabled in the 7.) Course Creator Studio.'
                USING ERRCODE = 'P0051';
        END IF;

    ELSE
        RAISE EXCEPTION 'You are not authorized to perform any actions on this course.'
                USING ERRCODE = 'P0050';
    end if;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
REVOKE ALL ON PROCEDURE internal.phase1_remove_syllabus(IN p_syllabus_iid TEXT) FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE internal.phase1_remove_syllabus(IN p_syllabus_iid TEXT) TO authenticated;


---- SUBTASK 5.3 Remove Lesson  STATUS: _DEVELOPED

CREATE OR REPLACE FUNCTION internal.phase1_attempt_remove_lesson(IN p_lesson_id TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    dcrpt_lesson_id INT;
    material_count INT;
    assignment_count INT;
    test_count INT;
    msg TEXT;
    f_version_id INT;
BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['faculty'])) = FALSE THEN
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    END IF;

    -- decrypt SYLLABUS ID
    BEGIN
        dcrpt_lesson_id := pgp_sym_decrypt(
            decode(p_lesson_id, 'base64'),
            get_secret_key('get_phase1_data')
        )::TEXT;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Valid "Lesson ID" Required.'
                USING ERRCODE = 'P1000';
    END;

    f_version_id := (SELECT version_id FROM lesson WHERE lesson_id = dcrpt_lesson_id);

    -- CHECK IF FACULTY MATCH
    IF EXISTS (
        SELECT 1
        FROM course_version_faculty
        WHERE version_id = f_version_id
        AND user_id = (SELECT user_id FROM users WHERE auth_id = auth.uid())
    ) THEN

        -- CHECK IF COURSE ALREADY PUBLISHED
        IF EXISTS (
            SELECT 1 FROM course_version WHERE version_id = f_version_id AND apvd_rvwd_by is null
        )THEN
            -- Count related records safely
            SELECT
                COUNT(DISTINCT cm.material_id),
                COUNT(DISTINCT a.ass_id),
                COUNT(DISTINCT t.test_id)
            INTO
                material_count,
                assignment_count,
                test_count
            FROM lesson l
            LEFT JOIN internal.course_material cm ON l.lesson_id = cm.lesson_id
            LEFT JOIN internal.assignment a       ON l.lesson_id = a.lesson_id
            LEFT JOIN internal.test t ON l.lesson_id = t.lesson_id
            WHERE l.lesson_id = dcrpt_lesson_id;

            -- Build message
            IF material_count = 0 AND assignment_count = 0 AND test_count = 0 THEN
                msg := 'This lesson has no related materials, assignments, or tests. Are you sure you want to delete it?';
            ELSE
                msg := 'This lesson contains the following:';
                IF material_count > 0 THEN
                    msg := msg || E'\n- Course Material(s): ' || material_count;
                END IF;
                IF assignment_count > 0 THEN
                    msg := msg || E'\n- Assignment(s): ' || assignment_count;
                END IF;
                IF test_count > 0 THEN
                    msg := msg || E'\n- Test(s): ' || test_count;
                END IF;
                msg := msg || E'\n\nAre you sure you want to delete this lesson?';
            END IF;

            RETURN jsonb_build_object(
                        'confirmation_id', encode(
                                            pgp_sym_encrypt(
                                                jsonb_build_object(
                                                    'lesson_id', dcrpt_lesson_id,
                                                    'expires_at', (now() + interval '5 minutes')  -- set expiry window here
                                                )::text,
                                                internal.get_secret_key('phase1_attempt_remove_lesson')
                                            ),
                                            'base64'
                                        )::text,
                        'message', msg
                    );

        ELSE
            RAISE EXCEPTION 'This course is already published. Editing is disabled in the 7.) Course Creator Studio.'
                USING ERRCODE = 'P0051';
        END IF;

    ELSE
        RAISE EXCEPTION 'You are not authorized to perform any actions on this course.'
                USING ERRCODE = 'P0050';
    end if;


END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION internal.phase1_attempt_remove_lesson(IN p_lesson_id TEXT) FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION internal.phase1_attempt_remove_lesson(IN p_lesson_id TEXT) TO authenticated;


CREATE OR REPLACE PROCEDURE internal.phase1_confirm_remove_lesson(IN p_confirmation_id TEXT)
SET search_path = internal
AS $$
DECLARE
    dcrpt_lesson_id INT;
    confirmation_payload JSONB;
BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['faculty'])) = FALSE THEN
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    END IF;

    -- decrypt lesson id
    BEGIN
        confirmation_payload = (pgp_sym_decrypt(
                    decode(p_confirmation_id, 'base64'),
                    internal.get_secret_key('phase1_attempt_remove_lesson')
                ))::jsonb;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Valid Confirmation Token required.'
                        USING ERRCODE = 'P0035';
    END;

    IF (confirmation_payload->>'expires_at')::timestamptz < now() THEN -- if payload still valid
            RAISE EXCEPTION 'Confirmation token expired.'
                USING ERRCODE = 'P0044';
    end if;

    dcrpt_lesson_id := (confirmation_payload->>'lesson_id')::int;

    -- CHECK IF FACULTY MATCH
    IF EXISTS (
        SELECT 1
        FROM course_version_faculty
        WHERE version_id = (SELECT version_id FROM lesson WHERE lesson_id = dcrpt_lesson_id)
        AND user_id = (SELECT user_id FROM users WHERE auth_id = auth.uid())
    ) THEN

        DELETE FROM lesson WHERE lesson_id = dcrpt_lesson_id;

    ELSE
        RAISE EXCEPTION 'You are not authorized to perform any actions on this course.'
                USING ERRCODE = 'P0050';
    end if;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
REVOKE ALL ON PROCEDURE internal.phase1_confirm_remove_lesson(IN p_confirmation_id TEXT) FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE internal.phase1_confirm_remove_lesson(IN p_confirmation_id TEXT) TO authenticated;


---- SUBTASK 5.4 Remove Course Assessment   STATUS: _DEVELOPED

CREATE OR REPLACE PROCEDURE internal.phase2_remove_course_assessment(IN p_course_assessment_id TEXT)
SET search_path = internal
AS $$
DECLARE
    dcrpt_ca_id INT;
    f_version_id int;
BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['faculty'])) = FALSE THEN
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    END IF;

    -- decrypt SYLLABUS ID
    BEGIN
        dcrpt_ca_id := pgp_sym_decrypt(
            decode(p_course_assessment_id, 'base64'),
            get_secret_key('get_phase2_data')
        )::INT;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Valid "Course Assessment ID" Required.'
                USING ERRCODE = 'P1000';
    END;

    f_version_id := (SELECT version_id FROM course_assessment WHERE ca_id = dcrpt_ca_id);

    -- CHECK IF FACULTY MATCH
    IF EXISTS (
        SELECT 1
        FROM course_version_faculty
        WHERE version_id = f_version_id
        AND user_id = (SELECT user_id FROM users WHERE auth_id = auth.uid())
    ) THEN

        -- CHECK IF COURSE ALREADY PUBLISHED
        IF EXISTS (
            SELECT 1 FROM course_version WHERE version_id = f_version_id AND apvd_rvwd_by is null
        )THEN
            IF EXISTS (
                SELECT 1 FROM assignment WHERE ca_id = dcrpt_ca_id
            ) OR
            EXISTS (
                SELECT 1 FROM test WHERE ca_id = dcrpt_ca_id
            ) THEN
                RAISE EXCEPTION 'Course assessment cannot be deleted because it is referenced by existing assignment(s) or test(s)/exam(s).'
                    USING ERRCODE = 'P1000';
            ELSE
                DELETE FROM course_assessment WHERE ca_id = dcrpt_ca_id;
            end if;

        ELSE
            RAISE EXCEPTION 'This course is already published. Editing is disabled in the 7.) Course Creator Studio.'
                USING ERRCODE = 'P0051';
        END IF;
    ELSE
        RAISE EXCEPTION 'You are not authorized to perform any actions on this course.'
                USING ERRCODE = 'P0050';
    end if;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
REVOKE ALL ON PROCEDURE internal.phase2_remove_course_assessment(IN p_course_assessment_id TEXT) FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE internal.phase2_remove_course_assessment(IN p_course_assessment_id TEXT) TO authenticated;


---- SUBTASK 5.5 Remove Course Material (e.g. Video, additional material, and links)    STATUS: _DEVELOPED

CREATE OR REPLACE PROCEDURE internal.phase3_remove_course_material(IN p_material_id TEXT)
SET search_path = internal
AS $$
DECLARE
    dcrpt_material_id INT;
    returned_material_uuid UUID;
    f_version_id INT;
BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['faculty'])) = FALSE THEN
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    END IF;

    -- decrypt SYLLABUS ID
    BEGIN
        dcrpt_material_id := pgp_sym_decrypt(
            decode(p_material_id, 'base64'),
            get_secret_key('get_phase3_data')
        )::INT;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Valid "Material ID" Required.'
                USING ERRCODE = 'P1000';
    END;

    f_version_id := (SELECT version_id FROM course_material cm INNER JOIN internal.lesson l2 on l2.lesson_id = cm.lesson_id WHERE cm.material_id = dcrpt_material_id);

    -- CHECK IF FACULTY MATCH
    IF EXISTS (
        SELECT 1
        FROM course_version_faculty
        WHERE version_id = f_version_id
        AND user_id = (SELECT user_id FROM users WHERE auth_id = auth.uid())
    ) THEN

        -- CHECK IF COURSE ALREADY PUBLISHED
        IF EXISTS (
            SELECT 1 FROM course_version WHERE version_id = f_version_id AND apvd_rvwd_by is null
        )THEN

            -- if this material exists
            IF EXISTS(
                SELECT *
                FROM storage.objects
                WHERE bucket_id = 'course-materials'
                and id = (SELECT material FROM course_material WHERE material_id = dcrpt_material_id)
                AND owner = auth.uid()
            )THEN
                DELETE
                FROM course_material
                WHERE material_id = dcrpt_material_id
                returning material INTO returned_material_uuid;

                DELETE
                FROM storage.objects
                WHERE bucket_id = 'course-materials'
                AND id = returned_material_uuid
                AND owner = auth.uid();
            ELSE
                DELETE
                FROM course_material
                WHERE material_id = dcrpt_material_id;
            end if;

        ELSE
            RAISE EXCEPTION 'This course is already published. Editing is disabled in the 7.) Course Creator Studio.'
                USING ERRCODE = 'P0051';
        END IF;
    ELSE
        RAISE EXCEPTION 'You are not authorized to perform any actions on this course.'
                USING ERRCODE = 'P0050';
    end if;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
REVOKE ALL ON PROCEDURE internal.phase3_remove_course_material(IN p_material_id TEXT) FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE internal.phase3_remove_course_material(IN p_material_id TEXT) TO authenticated;



---- SUBTASK 5.6 Assignment STATUS: _DEVELOPED

CREATE OR REPLACE PROCEDURE internal.phase4_remove_assignment(IN p_assignment_id TEXT)
SET search_path = internal
AS $$
DECLARE
    dcrpt_ass_id INT;
    f_version_id INT;
BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['faculty'])) = FALSE THEN
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    END IF;

    -- decrypt SYLLABUS ID
    BEGIN
        dcrpt_ass_id := pgp_sym_decrypt(
            decode(p_assignment_id, 'base64'),
            get_secret_key('get_phase4_data')
        )::INT;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Valid "Assignment ID" Required.'
                USING ERRCODE = 'P1000';
    END;

    f_version_id := (SELECT version_id FROM assignment a INNER JOIN internal.lesson l2 on l2.lesson_id = a.lesson_id WHERE a.ass_id = dcrpt_ass_id);

    -- CHECK IF FACULTY MATCH
    IF EXISTS (
        SELECT 1
        FROM course_version_faculty
        WHERE version_id = f_version_id
        AND user_id = (SELECT user_id FROM users WHERE auth_id = auth.uid())
    ) THEN

        -- CHECK IF COURSE ALREADY PUBLISHED
        IF EXISTS (
            SELECT 1 FROM course_version WHERE version_id = f_version_id AND apvd_rvwd_by is null
        )THEN

            DELETE FROM assignment WHERE ass_id = dcrpt_ass_id;

        ELSE
            RAISE EXCEPTION 'This course is already published. Editing is disabled in the 7.) Course Creator Studio.'
                USING ERRCODE = 'P0051';
        END IF;

    ELSE
        RAISE EXCEPTION 'You are not authorized to perform any actions on this course.'
                USING ERRCODE = 'P0050';
    end if;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
REVOKE ALL ON PROCEDURE internal.phase4_remove_assignment(IN p_assignment_id TEXT) FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE internal.phase4_remove_assignment(IN p_assignment_id TEXT) TO authenticated;



---- SUBTASK 5.7.1 Remove Test  STATUS: _DEVELOPED

CREATE OR REPLACE FUNCTION internal.phase5_attempt_remove_test(IN p_test_id TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    dcrpt_test_id INT;
    f_version_id INT;
    msg TEXT;
    item_count INT;
BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['faculty'])) = FALSE THEN
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    END IF;

    -- decrypt SYLLABUS ID
    BEGIN
        dcrpt_test_id := pgp_sym_decrypt(
            decode(p_test_id, 'base64'),
            get_secret_key('get_phase5_data')
        )::INT;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Valid "Test ID" Required.'
                USING ERRCODE = 'P1000';
    END;

    f_version_id := (SELECT version_id FROM test t INNER JOIN internal.lesson l2 on l2.lesson_id = t.lesson_id WHERE t.test_id = dcrpt_test_id);

    -- CHECK IF FACULTY MATCH
    IF EXISTS (
        SELECT 1
        FROM course_version_faculty
        WHERE version_id = f_version_id
        AND user_id = (SELECT user_id FROM users WHERE auth_id = auth.uid())
    ) THEN

        -- CHECK IF COURSE ALREADY PUBLISHED
        IF EXISTS (
            SELECT 1 FROM course_version WHERE version_id = f_version_id AND apvd_rvwd_by is null
        )THEN

            item_count := (SELECT COALESCE(COUNT(*), 0) FROM question WHERE test_id = dcrpt_test_id);
            msg := concat('This Test contains ', item_count::text ,' item(s). Are you sure you want to delete it?');

            RETURN jsonb_build_object(
                        'confirmation_id', encode(
                                            pgp_sym_encrypt(
                                                jsonb_build_object(
                                                    'test_id', dcrpt_test_id,
                                                    'expires_at', (now() + interval '5 minutes')  -- set expiry window here
                                                )::text,
                                                internal.get_secret_key('phase5_attempt_remove_test')
                                            ),
                                            'base64'
                                        )::text,
                        'message', msg
                    );

        ELSE
            RAISE EXCEPTION 'This course is already published. Editing is disabled in the 7.) Course Creator Studio.'
                USING ERRCODE = 'P0051';
        END IF;

    ELSE
        RAISE EXCEPTION 'You are not authorized to perform any actions on this course.'
                USING ERRCODE = 'P0050';
    end if;


END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION internal.phase5_attempt_remove_test(IN p_test_id TEXT) FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION internal.phase5_attempt_remove_test(IN p_test_id TEXT) TO authenticated;

CREATE OR REPLACE PROCEDURE internal.phase5_confirm_remove_test(IN p_test_id TEXT)
SET search_path = internal
AS $$
DECLARE
    dcrpt_test_id INT;
    confirmation_payload JSONB;
BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['faculty'])) = FALSE THEN
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    END IF;

    -- decrypt lesson id
    BEGIN
        confirmation_payload = (pgp_sym_decrypt(
                    decode(p_test_id, 'base64'),
                    internal.get_secret_key('phase5_attempt_remove_test')
                ))::jsonb;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Valid Confirmation Token required.'
                        USING ERRCODE = 'P0035';
    END;

    IF (confirmation_payload->>'expires_at')::timestamptz < now() THEN -- if payload still valid
            RAISE EXCEPTION 'Confirmation token expired.'
                USING ERRCODE = 'P0044';
    end if;

    dcrpt_test_id := (confirmation_payload->>'test_id')::int;

    -- CHECK IF FACULTY MATCH
    IF EXISTS (
        SELECT 1
        FROM course_version_faculty
        WHERE version_id = (SELECT l.version_id FROM test t inner join internal.lesson l on t.lesson_id = l.lesson_id WHERE t.test_id = dcrpt_test_id)
        AND user_id = (SELECT user_id FROM users WHERE auth_id = auth.uid())
    ) THEN

        DELETE FROM test WHERE test_id = dcrpt_test_id;

    ELSE
        RAISE EXCEPTION 'You are not authorized to perform any actions on this course.'
                USING ERRCODE = 'P0050';
    end if;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
REVOKE ALL ON PROCEDURE internal.phase5_confirm_remove_test(IN p_confirmation_id TEXT) FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE internal.phase5_confirm_remove_test(IN p_confirmation_id TEXT) TO authenticated;


---- SUBTASK 5.7.2 Remove Question  STATUS: _DEVELOPED

CREATE OR REPLACE PROCEDURE internal.phase5_remove_question(IN p_question_id TEXT)
SET search_path = internal
AS $$
DECLARE
    dcrpt_question_id INT;
    f_version_id INT;
BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['faculty'])) = FALSE THEN
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    END IF;

    -- decrypt SYLLABUS ID
    BEGIN
        dcrpt_question_id := pgp_sym_decrypt(
            decode(p_question_id, 'base64'),
            get_secret_key('get_phase5_data')
        )::INT;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Valid "Question ID" Required.'
                USING ERRCODE = 'P1000';
    END;

    f_version_id := (
            SELECT l.version_id
            FROM question q
            INNER JOIN internal.test t on q.test_id = t.test_id
            INNER JOIN internal.lesson l on t.lesson_id = l.lesson_id
            WHERE q.question_id = dcrpt_question_id
        );

    -- CHECK IF FACULTY MATCH
    IF EXISTS (
        SELECT 1
        FROM course_version_faculty
        WHERE version_id = f_version_id
        AND user_id = (SELECT user_id FROM users WHERE auth_id = auth.uid())
    ) THEN

        -- CHECK IF COURSE ALREADY PUBLISHED
        IF EXISTS (
            SELECT 1 FROM course_version WHERE version_id = f_version_id AND apvd_rvwd_by is null
        )THEN
            DELETE FROM question WHERE question_id = dcrpt_question_id;
        ELSE
            RAISE EXCEPTION 'This course is already published. Editing is disabled in the 7.) Course Creator Studio.'
                USING ERRCODE = 'P0051';
        END IF;

    ELSE
        RAISE EXCEPTION 'You are not authorized to perform any actions on this course.'
                USING ERRCODE = 'P0050';
    end if;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
REVOKE ALL ON PROCEDURE internal.phase5_remove_question(IN p_question_id TEXT) FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE internal.phase5_remove_question(IN p_question_id TEXT) TO authenticated;


---- SUBTASK 5.7.3 Remove choice    STATUS: _DEVELOPED

CREATE OR REPLACE PROCEDURE internal.phase5_remove_choice(IN p_key_id TEXT)
SET search_path = internal
AS $$
DECLARE
    dcrpt_key_id INT;
    f_version_id INT;
BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['faculty'])) = FALSE THEN
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    END IF;

    -- decrypt SYLLABUS ID
    BEGIN
        dcrpt_key_id := pgp_sym_decrypt(
            decode(p_key_id, 'base64'),
            get_secret_key('get_phase5_data')
        )::INT;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Valid "key ID" Required.'
                USING ERRCODE = 'P1000';
    END;

    f_version_id := (
            SELECT l.version_id
            FROM answer_key ak
            INNER JOIN internal.question q on q.question_id = ak.question_id
            INNER JOIN internal.test t on q.test_id = t.test_id
            INNER JOIN internal.lesson l on t.lesson_id = l.lesson_id
            WHERE ak.key_id = dcrpt_key_id
        );

    -- CHECK IF FACULTY MATCH
    IF EXISTS (
        SELECT 1
        FROM course_version_faculty
        WHERE version_id = f_version_id
        AND user_id = (SELECT user_id FROM users WHERE auth_id = auth.uid())
    ) THEN

        -- CHECK IF COURSE ALREADY PUBLISHED
        IF EXISTS (
            SELECT 1 FROM course_version WHERE version_id = f_version_id AND apvd_rvwd_by is null
        )THEN

            DELETE FROM answer_key WHERE key_id = dcrpt_key_id;

        ELSE
            RAISE EXCEPTION 'This course is already published. Editing is disabled in the 7.) Course Creator Studio.'
                USING ERRCODE = 'P0051';
        END IF;

    ELSE
        RAISE EXCEPTION 'You are not authorized to perform any actions on this course.'
                USING ERRCODE = 'P0050';
    end if;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
REVOKE ALL ON PROCEDURE internal.phase5_remove_choice(IN p_key_id TEXT) FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE internal.phase5_remove_choice(IN p_key_id TEXT) TO authenticated;





--- TASK 6. VIEW ENROLLED STUDENTS

CREATE OR REPLACE FUNCTION internal.view_enrolled_students2(IN p_course_id TEXT)
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
    request_payload JSONB;
    dcrpt_version_id INT;
BEGIN
    -- Only run main query if key exists and confirm the user role
    IF (
        (SELECT check_user_role(ARRAY['faculty', 'dean', 'admin'])) = TRUE AND
        internal.get_secret_key('view_enrolled_students2') IS NOT NULL) THEN

        -- decrypt VERSION ID
        BEGIN
            request_payload = (pgp_sym_decrypt(
                        decode(p_course_id, 'base64'),
                        internal.get_secret_key('my_assigned_courses')
                    ))::jsonb;

            dcrpt_version_id := (request_payload->>'version_id')::INT;
        EXCEPTION
            WHEN OTHERS THEN
                BEGIN
                dcrpt_version_id := pgp_sym_decrypt(
                    decode(p_course_id, 'base64'),
                    get_secret_key('select_prospectus')
                )::INT;
                EXCEPTION
                    WHEN OTHERS THEN
                        RAISE EXCEPTION 'Valid Course ID required.'
                            USING ERRCODE = 'P1000';
                END;
        END;

        RETURN QUERY
            SELECT
                -- 1.) id
                encode(
                    pgp_sym_encrypt(
                        jsonb_build_object(
                            'user_id', u.user_id::INT,
                            'version_id', dcrpt_version_id
                        )::text,
                        internal.get_secret_key('view_enrolled_students2')
                    ),
                    'base64'
                )::text,

                -- 2.) avatar path
                av.name::TEXT,

                -- 3.) stduent full name
                CONCAT(u.lname, ', ', u.fname, ' ', COALESCE(u.mname, ''))::TEXT,

                -- 4.) email
                au.email::TEXT,

                -- 5.) progress percentage
                (
                    SELECT (
                        ROUND(
                            100.0 * COUNT(*) FILTER (WHERE progress3 = 'finished') / COUNT(*),
                            2
                        )
                    )::TEXT
                    FROM (
                        SELECT DISTINCT ON (cm1.material_id)
                            CASE
                                WHEN scp1.material_id IS NULL THEN 'not started'
                                WHEN scp1.material_id IS NOT NULL AND scp1.finished_date IS NULL THEN 'pending'
                                WHEN scp1.material_id IS NOT NULL AND scp1.finished_date IS NOT NULL THEN 'finished'
                            END AS progress3
                        FROM internal.course_version cv1
                        INNER JOIN internal.lesson l1 ON cv1.version_id = l1.version_id
                        INNER JOIN internal.course_material cm1 ON l1.lesson_id = cm1.lesson_id
                        LEFT JOIN internal.student_cm_progress scp1
                          ON cm1.material_id = scp1.material_id
                         AND scp1.user_id = mc.user_id            -- correlated properly
                        WHERE cv1.version_id = mc.version_id
                          AND cm1.video_duration IS NOT NULL

                        UNION ALL

                        SELECT DISTINCT ON (a2.ass_id)
                            CASE
                                WHEN sap2.sap_id IS NULL THEN 'not started'
                                WHEN sap2.sap_id IS NOT NULL AND sap2.completed_at IS NULL THEN 'pending'
                                WHEN sap2.sap_id IS NOT NULL AND sap2.completed_at IS NOT NULL THEN 'finished'
                            END AS progress3
                        FROM internal.course_version cv2
                        INNER JOIN internal.lesson l2 ON cv2.version_id = l2.version_id
                        INNER JOIN internal.assignment a2 ON l2.lesson_id = a2.lesson_id
                        LEFT JOIN internal.student_ass_progress sap2
                          ON a2.ass_id = sap2.ass_id
                         AND sap2.user_id = mc.user_id            -- correlated properly
                        WHERE cv2.version_id = mc.version_id

                        UNION ALL

                        SELECT DISTINCT ON (t3.test_id)
                            CASE
                                WHEN str3.ut_id IS NULL THEN 'not started'
                                WHEN str3.ut_id IS NOT NULL AND str3.completed_at IS NULL THEN 'pending'
                                WHEN str3.ut_id IS NOT NULL AND str3.completed_at IS NOT NULL THEN 'finished'
                            END AS progress3
                        FROM internal.course_version cv3
                        INNER JOIN internal.lesson l3 ON cv3.version_id = l3.version_id
                        INNER JOIN internal.test t3 ON l3.lesson_id = t3.lesson_id
                        LEFT JOIN internal.student_test_record str3
                          ON t3.test_id = str3.test_id
                         AND str3.user_id = mc.user_id            -- correlated properly
                        WHERE cv3.version_id = mc.version_id
                    ) AS progress_sub
                )::TEXT,


                -- 6.) enrollment status
                CASE
                    WHEN mc.enrollment_status IS FALSE THEN 'Dropped/Withdrawn'

                    WHEN mc.enrollment_status IS TRUE
                         AND now()::date <@ ps.duration
                         AND get_progress(mc.user_id, mc.version_id) <= 0.00
                         THEN 'Enrolled'

                    WHEN mc.enrollment_status IS TRUE
                         AND now()::date <@ ps.duration
                         AND get_progress(mc.user_id, mc.version_id) > 0.00
                         AND get_progress(mc.user_id, mc.version_id) < 99.99
                         THEN 'In Progress'

                    WHEN mc.enrollment_status IS TRUE
                         AND (now()::date <@ ps.duration OR now()::date > upper(ps.duration))
                         AND get_progress(mc.user_id, mc.version_id) >= 99.99
                         AND get_grade(mc.user_id, mc.version_id) <= 3.0
                         THEN CONCAT('Completed - Passed [',COALESCE(get_grade(mc.user_id, mc.version_id)::TEXT, '-'),']')

                    WHEN mc.enrollment_status IS TRUE
                         AND (now()::date <@ ps.duration OR now()::date > upper(ps.duration))
                         AND get_progress(mc.user_id, mc.version_id) >= 99.99
                         AND get_grade(mc.user_id, mc.version_id) > 3.0
                         THEN CONCAT('Completed - Failed [',COALESCE(get_grade(mc.user_id, mc.version_id)::TEXT, '-'),']')

                    WHEN mc.enrollment_status IS TRUE
                         AND now()::date > upper(ps.duration)
                         AND now()::date <= upper(ps.duration) + INTERVAL '1 year'
                         AND get_progress(mc.user_id, mc.version_id) >= 99.99
                         AND get_grade(mc.user_id, mc.version_id) <= 3.0
                         THEN CONCAT('Completed - Passed [ ',COALESCE(get_grade(mc.user_id, mc.version_id)::TEXT, '-'),' ] (Within 1 Year)')

                    WHEN mc.enrollment_status IS TRUE
                         AND now()::date > upper(ps.duration)
                         AND now()::date <= upper(ps.duration) + INTERVAL '1 year'
                         AND get_progress(mc.user_id, mc.version_id) < 99.99
                         AND get_grade(mc.user_id, mc.version_id) > 3.0
                         THEN CONCAT('Incomplete - Failed [ ', COALESCE(get_grade(mc.user_id, mc.version_id)::TEXT, '-'),' ] (Within 1 Year)')

                    WHEN mc.enrollment_status IS TRUE
                         AND now()::date > upper(ps.duration) + INTERVAL '1 year'
                         AND get_progress(mc.user_id, mc.version_id) < 99.99
                         AND get_grade(mc.user_id, mc.version_id) > 3.0
                         THEN 'Failed (Over 1 Year)'

                    WHEN mc.enrollment_status IS TRUE
                         AND get_progress(mc.user_id, mc.version_id) >= 99.99
                         AND get_grade(mc.user_id, mc.version_id) is null
                         THEN 'Completed - [Pending Evaluation]'

                    ELSE 'Dropped/Withdrawn'
                END,



                -- 7.) Last Activity
                (
                    SELECT COALESCE((
                        SELECT TO_CHAR(created_at, 'MM/DD/YYYY')
                        FROM course_activity cak
                        WHERE cak.version_id = mc.version_id AND cak.sender_id = mc.user_id
                        ORDER BY created_at DESC
                        LIMIT 1
                    ), 'Not Started')
                )::TEXT,

                -- 8.) Activity Indicator
                (
                    SELECT COALESCE((
                        SELECT
                            CASE
                                WHEN created_at IS NULL THEN 'red'
                                WHEN created_at >= NOW() - INTERVAL '3 days' THEN 'green'
                                WHEN created_at >= NOW() - INTERVAL '7 days' THEN 'yellow'
                                WHEN created_at >= NOW() - INTERVAL '10 days' THEN 'orange'
                                ELSE 'red'
                            END
                        FROM course_activity
                        WHERE version_id = mc.version_id
                          AND sender_id = mc.user_id
                        ORDER BY created_at DESC
                        LIMIT 1
                    ), 'red')
                )::text,

                -- 9.) Enrolled date
                TO_CHAR(mc.enrld_date, 'MM/DD/YYYY')::TEXT,

                -- 10.) enrolled by
                CONCAT(er.lname, ', ', er.fname, ' ', COALESCE(er.mname, ''))::TEXT

            FROM my_courses mc
            INNER JOIN internal.users u on u.user_id = mc.user_id
                INNER JOIN storage.objects av on av.id = u.profile_id
                INNER JOIN auth.users au on au.id = u.auth_id
            INNER JOIN internal.users er on er.user_id = mc.enrld_by
            INNER JOIN internal.prospectus_course pc on pc.pc_id = mc.version_id
                LEFT JOIN internal.prospectus_semester ps on ps.prosem_id = pc.prosem_id
            WHERE mc.version_id = dcrpt_version_id
            ORDER BY u.lname, u.fname, u.mname;
    ELSE
        -- No secret key, return empty result set
        RETURN QUERY
        SELECT NULL::TEXT, NULL::TEXT, NULL::TEXT, NULL::TEXT,
               NULL::TEXT, NULL::TEXT, NULL::TEXT, NULL::TEXT, NULL::TEXT, NULL::TEXT
        WHERE FALSE;
    END IF;
END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION internal.view_enrolled_students2(IN p_course_id TEXT) FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION internal.view_enrolled_students2(IN p_course_id TEXT) TO authenticated;


-- SUBTASK 6.1 CALCULATE STUDENT GRADE

CREATE OR REPLACE FUNCTION internal.get_grade(IN p_user_id INT, IN p_version_id INT)
RETURNS numeric(2,1)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    s_assignment_ids INT[];
    s_test_ids INT[];

    final_grade NUMERIC(2,1) := NULL;
BEGIN
    -- Only run main query if key exists and confirm the user role
    IF (
        (SELECT check_user_role(ARRAY['faculty', 'dean', 'admin', 'student'])) = TRUE AND
        internal.get_secret_key('get_grade') IS NOT NULL) THEN

            -- CHECK IF course already published
            IF EXISTS(
                SELECT 1 FROM course_version WHERE version_id = p_version_id AND is_ready IS TRUE AND apvd_rvwd_by IS NOT NULL
            ) THEN
                -- check if enrolled
                IF EXISTS(
                    SELECT 1 FROM my_courses WHERE user_id = p_user_id and version_id = p_version_id AND enrollment_status = TRUE
                ) THEN

                    -- GET ALL ASSIGNMENT_IDS OF THIS student
                    SELECT
                        coalesce(array_agg(sap1.ass_id), '{}') INTO s_assignment_ids
                    FROM student_ass_progress sap1
                        INNER JOIN internal.assignment a3 on a3.ass_id = sap1.ass_id
                            INNER JOIN internal.lesson l on l.lesson_id = a3.lesson_id
                    WHERE l.version_id = p_version_id
                      AND sap1.user_id = p_user_id
                      AND sap1.completed_at IS NOT NULL
                      AND sap1.eval_points is not null;

                    -- GET ALL TEST_IDS OF THIS student
                    SELECT
                        coalesce(array_agg(str1.test_id), '{}') INTO s_test_ids
                    FROM student_test_record str1
                        INNER JOIN internal.test t2 on t2.test_id = str1.test_id
                            INNER JOIN internal.lesson l2 on l2.lesson_id = t2.lesson_id
                    INNER JOIN internal.student_answer s on str1.ut_id = s.ut_id
                    WHERE l2.version_id = p_version_id
                      AND str1.user_id = p_user_id
                      AND str1.completed_at IS NOT NULL
                      AND (view_attempt_result(encode(pgp_sym_encrypt(str1.ut_id::text, internal.get_secret_key('view_exam')), 'base64')::text)->>'pending_essays')::int = 0;


                    -- CHECK IF STUDENT HAVE ALREADY COMPILED ASSIGNMENTS COMPLETELY
                    IF NOT EXISTS(
                        SELECT 1
                        FROM assignment ass3
                            INNER JOIN internal.lesson l3 on l3.lesson_id = ass3.lesson_id
                        WHERE l3.version_id = p_version_id
                          AND ass3.ass_id NOT IN (SELECT unnest(s_assignment_ids)) -- ass_id not in student's record
                    ) THEN
                        -- CHECK IF STUDENT HAVE ALREADY COMPILED TESTS COMPLETELY
                        IF NOT EXISTS(
                            SELECT 1
                            FROM test t4
                                INNER JOIN internal.lesson l4 on l4.lesson_id = t4.lesson_id
                            WHERE l4.version_id = p_version_id
                              AND t4.test_id NOT IN (SELECT unnest(s_test_ids)) -- ass_id not in student's record
                        ) THEN

                            WITH grade as (
                                WITH t as (
                                    SELECT
                                        ca.ca_id as id,
                                        CASE WHEN ca.custom_asmt IS NULL THEN a.asmt_name ELSE ca.custom_asmt END as term,
                                        ca.weight,
                                        SUM(sap.eval_points) as points_earned,
                                        SUM(a2.total_points) as points_possible
                                    FROM internal.course_assessment ca
                                    LEFT JOIN internal.assessment_type a on a.asmt_type_id = ca.asmt_type_id
                                    INNER JOIN internal.assignment a2 on a2.ca_id = ca.ca_id
                                        INNER JOIN internal.student_ass_progress sap on a2.ass_id = sap.ass_id
                                    WHERE ca.version_id = p_version_id AND sap.user_id = p_user_id
                                    group by ca.ca_id, ca.custom_asmt, a.asmt_name, ca.weight

                                    union all

                                    SELECT
                                        ca.ca_id as id,
                                        CASE WHEN ca.custom_asmt IS NULL THEN a.asmt_name ELSE ca.custom_asmt END as term,
                                        ca.weight,
                                        (
                                            SELECT
                                                COALESCE(SUM(
                                                    CASE
                                                        WHEN a.answer_type = 'multiple choice'
                                                            AND ak.is_correct IS TRUE
                                                            AND sa.key_id = ak.key_id THEN q.total_points
                                                        WHEN a.answer_type = 'true/false'
                                                            AND sa.tof_ans = ak.tof_key
                                                            AND sa.key_id = ak.key_id THEN q.total_points
                                                        WHEN a.answer_type IN ('identification', 'enumeration')
                                                            AND trim(lower(sa.text_ans)) = trim(lower(ak.text_key))
                                                            AND sa.key_id = ak.key_id THEN q.total_points
                                                        WHEN a.answer_type = 'essay'
                                                            AND sa.key_id = ak.key_id THEN COALESCE(sa.essay_given_points, 0)
                                                        ELSE 0
                                                    END
                                                ), 0)
                                            FROM internal.student_answer sa
                                            INNER JOIN internal.answer_key ak ON ak.key_id = sa.key_id
                                            INNER JOIN internal.question q ON q.question_id = ak.question_id
                                            INNER JOIN internal.answer_type a ON a.anst_id = q.anst_id
                                            WHERE sa.ut_id = str.ut_id
                                        ) as points_earned,
                                        (
                                            SELECT SUM(points)
                                            FROM (
                                                SELECT DISTINCT q3.question_id, q3.total_points AS points
                                                FROM internal.answer_key ak3
                                                    JOIN internal.question q3 ON q3.question_id = ak3.question_id
                                                    JOIN internal.answer_type at3 ON at3.anst_id = q3.anst_id
                                            WHERE q3.test_id = t.test_id
                                            ) t
                                        ) as points_possible
                                    FROM internal.course_assessment ca
                                    LEFT JOIN internal.assessment_type a on a.asmt_type_id = ca.asmt_type_id
                                    INNER JOIN internal.test t on t.ca_id = ca.ca_id
                                        INNER JOIN internal.student_test_record str on str.test_id = t.test_id
                                            AND str.user_id = p_user_id
                                            AND str.ut_id = (
                                                    SELECT str2.ut_id
                                                    FROM internal.student_test_record str2
                                                    WHERE str2.test_id = t.test_id
                                                      AND str2.user_id =  str.user_id
                                                    ORDER BY str2.created_at DESC  -- use your actual “latest attempt” column
                                                    LIMIT 1
                                                )
                                    WHERE ca.version_id = p_version_id
                                    group by ca.ca_id, ca.custom_asmt, a.asmt_name, ca.weight, t.test_id, str.ut_id
                                )
                                SELECT
                                    t.id,
                                    t.term,
                                    ((SUM(t.points_earned) / SUM(t.points_possible)) * t.weight) as percent
                                FROM t
                                group by t.id, t.term, t.weight
                            )
                            SELECT
                            CASE
                                WHEN SUM(grade.percent) >= 95 THEN 1.0
                                WHEN SUM(grade.percent) >= 94 THEN 1.1
                                WHEN SUM(grade.percent) >= 93 THEN 1.2
                                WHEN SUM(grade.percent) >= 92 THEN 1.3
                                WHEN SUM(grade.percent) >= 91 THEN 1.4
                                WHEN SUM(grade.percent) >= 90 THEN 1.5
                                WHEN SUM(grade.percent) >= 89 THEN 1.6
                                WHEN SUM(grade.percent) >= 88 THEN 1.7
                                WHEN SUM(grade.percent) >= 87 THEN 1.8
                                WHEN SUM(grade.percent) >= 86 THEN 1.9
                                WHEN SUM(grade.percent) >= 85 THEN 2.0
                                WHEN SUM(grade.percent) >= 84 THEN 2.1
                                WHEN SUM(grade.percent) >= 83 THEN 2.2
                                WHEN SUM(grade.percent) >= 82 THEN 2.3
                                WHEN SUM(grade.percent) >= 81 THEN 2.4
                                WHEN SUM(grade.percent) >= 80 THEN 2.5
                                WHEN SUM(grade.percent) >= 79 THEN 2.6
                                WHEN SUM(grade.percent) >= 78 THEN 2.7
                                WHEN SUM(grade.percent) >= 77 THEN 2.8
                                WHEN SUM(grade.percent) >= 76 THEN 2.9
                                WHEN SUM(grade.percent) >= 75 THEN 3.0
                                WHEN SUM(grade.percent) >= 74 THEN 3.1
                                WHEN SUM(grade.percent) >= 73 THEN 3.2
                                WHEN SUM(grade.percent) >= 72 THEN 3.3
                                WHEN SUM(grade.percent) >= 71 THEN 3.4
                                WHEN SUM(grade.percent) >= 70 THEN 3.5
                                WHEN SUM(grade.percent) >= 65 THEN 3.6
                                WHEN SUM(grade.percent) >= 60 THEN 3.7
                                WHEN SUM(grade.percent) >= 55 THEN 3.8
                                WHEN SUM(grade.percent) >= 50 THEN 3.9
                                ELSE 5.0
                            END INTO final_grade
                            FROM grade;

                        ELSE
                            NULL; -- HAVEN'T COMPLETELY COMPILED TESTS
                        end if;

                    ELSE
                        NULL; -- HAVEN'T COMPLETELY COMPILED ASSIGNMENTS
                    end if;

                ELSE
                    NULL; -- NOT ENROLLED
                end if;
            ELSE
                NULL; -- COURSE ISN'T PUBLISHED OR DOESN'T EXISTS
            end if;

        RETURN final_grade;

    ELSE
        RETURN NULL;
    END IF;
END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION internal.get_grade(IN p_user_id INT, IN p_version_id INT) FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION internal.get_grade(IN p_user_id INT, IN p_version_id INT) TO authenticated;

-- SUBTASK 6.2 CALCULATE STUDENT COURSE PROGRESS

CREATE OR REPLACE FUNCTION internal.get_progress(IN p_user_id INT, IN p_version_id INT)
RETURNS numeric(5,2)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    s_assignment_ids INT[];
    s_test_ids INT[];

    pg numeric(5,2) := 0.0;
BEGIN
    -- Only run main query if key exists and confirm the user role
    IF (
        (SELECT check_user_role(ARRAY['faculty', 'dean', 'admin','student'])) = TRUE AND
        internal.get_secret_key('get_progress') IS NOT NULL) THEN


            -- CHECK IF course already published
            IF EXISTS(
                SELECT 1 FROM course_version WHERE version_id = p_version_id AND is_ready IS TRUE AND apvd_rvwd_by IS NOT NULL
            ) THEN
                -- check if enrolled
                IF EXISTS(
                    SELECT 1 FROM my_courses WHERE user_id = p_user_id and version_id = p_version_id AND enrollment_status = TRUE
                ) THEN

                    SELECT (
                        COALESCE(ROUND(
                            100.0 * COUNT(*) FILTER (WHERE progress3 = 'finished') / NULLIF(COUNT(*), 0),
                            2
                            ), 0.00)
                        ) INTO pg
                    FROM (
                        SELECT DISTINCT ON (cm1.material_id)
                                    CASE
                                        WHEN scp1.material_id IS NULL THEN 'not started'
                                        WHEN scp1.material_id IS NOT NULL AND scp1.finished_date IS NULL THEN 'pending'
                                        WHEN scp1.material_id IS NOT NULL AND scp1.finished_date IS NOT NULL THEN 'finished'
                                    END AS progress3
                        FROM internal.course_version cv1
                            INNER JOIN internal.lesson l1 ON cv1.version_id = l1.version_id
                                INNER JOIN internal.course_material cm1 ON l1.lesson_id = cm1.lesson_id
                                    LEFT JOIN internal.student_cm_progress scp1
                                        ON cm1.material_id = scp1.material_id
                                        AND scp1.user_id = p_user_id           -- correlated properly
                        WHERE cv1.version_id = p_version_id
                            AND cm1.video_duration IS NOT NULL

                        UNION ALL

                        SELECT DISTINCT ON (a2.ass_id)
                                    CASE
                                        WHEN sap2.sap_id IS NULL THEN 'not started'
                                        WHEN sap2.sap_id IS NOT NULL AND sap2.completed_at IS NULL THEN 'pending'
                                        WHEN sap2.sap_id IS NOT NULL AND sap2.completed_at IS NOT NULL THEN 'finished'
                                    END AS progress3
                        FROM internal.course_version cv2
                            INNER JOIN internal.lesson l2 ON cv2.version_id = l2.version_id
                                INNER JOIN internal.assignment a2 ON l2.lesson_id = a2.lesson_id
                                    LEFT JOIN internal.student_ass_progress sap2
                                        ON a2.ass_id = sap2.ass_id
                                        AND sap2.user_id = p_user_id          -- correlated properly
                        WHERE cv2.version_id = p_version_id

                        UNION ALL

                        SELECT DISTINCT ON (t3.test_id)
                                    CASE
                                        WHEN str3.ut_id IS NULL THEN 'not started'
                                        WHEN str3.ut_id IS NOT NULL AND str3.completed_at IS NULL THEN 'pending'
                                        WHEN str3.ut_id IS NOT NULL AND str3.completed_at IS NOT NULL THEN 'finished'
                                    END AS progress3
                        FROM internal.course_version cv3
                            INNER JOIN internal.lesson l3 ON cv3.version_id = l3.version_id
                                INNER JOIN internal.test t3 ON l3.lesson_id = t3.lesson_id
                                    LEFT JOIN internal.student_test_record str3
                                        ON t3.test_id = str3.test_id
                                        AND str3.user_id = p_user_id            -- correlated properly
                        WHERE cv3.version_id = p_version_id
                    ) AS progress_sub;

                ELSE
                    NULL; -- NOT ENROLLED
                end if;
            ELSE
                NULL; -- COURSE ISN'T PUBLISHED OR DOESN'T EXISTS
            end if;


        RETURN pg;
    ELSE
        RETURN 0.0;
    END IF;
END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION internal.get_progress(IN p_user_id INT, IN p_version_id INT) FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION internal.get_progress(IN p_user_id INT, IN p_version_id INT) TO authenticated;





--- TASK 7. MONITOR STUDENT'S PROGRESS & ASSESSMENTS

---- SUBTASK 7.1 VIEW STUDENTS VIDEO PROGRESS

CREATE OR REPLACE FUNCTION internal.view_video_progress(IN p_video_id TEXT)
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
    dcrpt_video_id INT;
BEGIN

    -- Only run main query if key exists and confirm the user role
    IF (
        (SELECT check_user_role(ARRAY['faculty'])) = TRUE AND
        internal.get_secret_key('view_video_progress') IS NOT NULL) THEN

        -- DECRYPT THE VIDEO ID
        BEGIN
            dcrpt_video_id := pgp_sym_decrypt(
                    decode(p_video_id, 'base64'),
                    get_secret_key('view_course')
            )::INT;
        EXCEPTION
            WHEN OTHERS THEN
            RAISE EXCEPTION 'Valid "Video ID" Required.'
            USING ERRCODE = 'P0043';
        END;

        RETURN QUERY
            SELECT
                -- 1.) id
                encode(
                    pgp_sym_encrypt(
                        jsonb_build_object(
                            'user_id', scmp.user_id::INT,
                            'material_id', scmp.material_id::INT
                        )::text,
                        internal.get_secret_key('view_video_progress')
                    ),
                    'base64'
                )::text,

                -- 2.) avatar path
                av.name::TEXT,

                -- 3.) stduent full name
                CONCAT(u.lname, ', ', u.fname, ' ', COALESCE(u.mname, ''))::TEXT,

                -- 4.) email
                au.email::TEXT,

                -- 5.) progress percentage
                (
                COALESCE(ROUND(
                    (EXTRACT(EPOCH FROM scmp.last_record_time::INTERVAL) / EXTRACT(EPOCH FROM cm.video_duration::interval)) * 100
                    ), 0)
                )::TEXT

            FROM student_cm_progress scmp
            INNER JOIN internal.users u on u.user_id = scmp.user_id
                INNER JOIN storage.objects av on av.id = u.profile_id
                INNER JOIN auth.users au on au.id = u.auth_id
            INNER JOIN internal.course_material cm on cm.material_id = scmp.material_id
            WHERE scmp.material_id = dcrpt_video_id;

    ELSE
        -- No secret key, return empty result set
        RETURN QUERY
        SELECT NULL::TEXT, NULL::TEXT, NULL::TEXT, NULL::TEXT,
               NULL::TEXT
        WHERE FALSE;
    END IF;
END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION internal.view_video_progress(IN p_course_id TEXT) FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION internal.view_video_progress(IN p_course_id TEXT) TO authenticated;


---- SUBTASK 7.2.1 VIEW STUDENTS ASSIGNMENT PROGRESS

CREATE OR REPLACE FUNCTION internal.view_assignment_progress(IN p_assignment_id TEXT)
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
    dcrpt_ass_id INT;
BEGIN

    -- Only run main query if key exists and confirm the user role
    IF (
        (SELECT check_user_role(ARRAY['faculty'])) = TRUE AND
        internal.get_secret_key('view_assignment_progress') IS NOT NULL) THEN

        BEGIN
            dcrpt_ass_id := pgp_sym_decrypt(
                decode(p_assignment_id, 'base64'),
                get_secret_key('view_course') -- if screen from enrolled courses
            )::INT;
        EXCEPTION
            WHEN OTHERS THEN
                RAISE EXCEPTION 'Valid Assignment ID is required.'
                USING ERRCODE = 'P0035';
        END;

        RETURN QUERY
            SELECT
                -- 1.) id
                encode(
                    pgp_sym_encrypt(sap.sap_id::TEXT, internal.get_secret_key('view_assignment_progress')),
                    'base64'
                )::TEXT,

                -- 2.) avatar path
                av.name::TEXT,

                -- 3.) stduent full name
                CONCAT(u.lname, ', ', u.fname, ' ', COALESCE(u.mname, ''))::TEXT,

                -- 4.) email
                au.email::TEXT,

                -- 5.) completed
                CASE WHEN sap.completed_at IS NOT NULL THEN TO_CHAR(sap.completed_at, 'Mon DD, YYYY') ELSE 'Not Started' END,

                -- 6.) -- MARK GIVEN
                COALESCE(sap.eval_points::text, 'pending evaluation')

            FROM student_ass_progress sap
            INNER JOIN internal.users u on u.user_id = sap.user_id
                INNER JOIN storage.objects av on av.id = u.profile_id
                INNER JOIN auth.users au on au.id = u.auth_id
            INNER JOIN internal.assignment a on a.ass_id = sap.ass_id
            WHERE sap.ass_id = dcrpt_ass_id;

    ELSE
        -- No secret key, return empty result set
        RETURN QUERY
        SELECT NULL::TEXT, NULL::TEXT, NULL::TEXT, NULL::TEXT,
               NULL::TEXT,NULL::TEXT
        WHERE FALSE;
    END IF;
END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION internal.view_assignment_progress(IN p_assignment_id TEXT) FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION internal.view_assignment_progress(IN p_assignment_id TEXT) TO authenticated;


----- SUBTASK 7.2.2 VIEW STUDENT'S ASSIGNMENT

CREATE OR REPLACE FUNCTION internal.view_student_assignment(IN p_student_assignment_id TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    dcrpt_sap_id INT;
    assignment_details JSONB;
    faculty_attachments JSONB;
    student_attachments_file JSONB;
    student_attachments_url JSONB;
BEGIN

    -- Only run main query if key exists and confirm the user role
    IF (
        (SELECT check_user_role(ARRAY['faculty'])) = TRUE AND
        internal.get_secret_key('view_assignment_progress') IS NOT NULL) THEN

        -- decrypt sap_id
        BEGIN
            dcrpt_sap_id := pgp_sym_decrypt(
                decode(p_student_assignment_id, 'base64'),
                get_secret_key('view_assignment_progress') -- if screen from enrolled courses
            )::INT;
        EXCEPTION
            WHEN OTHERS THEN
                RAISE EXCEPTION 'Valid Student Assignment ID is required.'
                USING ERRCODE = 'P0035';
        END;

        -- ABOUT THE ASSIGNMENT
        SELECT
            jsonb_build_object(
            'student_assignment_id', encode(pgp_sym_encrypt(sap.sap_id::TEXT, internal.get_secret_key('view_student_assignment')),'base64')::text,
            'lesson_title', l.lesson_name::TEXT,
            'submission_status',    CASE
                                        WHEN sap.completed_at IS NOT NULL THEN TRUE
                                        ELSE FALSE
                                    END,
            'assignment_title', aa.ass_title::TEXT,
            'total_points', aa.total_points::TEXT,
            'description', aa.descr::TEXT,
            'student_mark', coalesce(sap.eval_points::text, 'pending evaluation')
            ) INTO assignment_details
        FROM assignment aa
        INNER JOIN lesson l ON l.lesson_id = aa.lesson_id
        LEFT JOIN student_ass_progress sap ON sap.ass_id = aa.ass_id
        WHERE sap.sap_id = dcrpt_sap_id;

        -- ATTACHMENTS ATTACHED BY FACULTY
        SELECT
            json_agg(
                jsonb_build_object(
                    'attachment_name', regexp_replace(o.name::text, '^.*/', ''),
                    'attachment_path', o.name::TEXT
                )
            ) INTO faculty_attachments
        FROM attachment at
        INNER JOIN storage.objects o ON o.id = at.file_id
        WHERE at.ass_id = (SELECT ass_id FROM student_ass_progress WHERE sap_id = dcrpt_sap_id);

        -- STUDENT ATTACHMENT DURING TURNING IN
        SELECT
            json_agg(
                jsonb_build_object(
                    'my_attachment_name', regexp_replace(o.name::text, '^.*/', ''),
                    'my_attachment_path', o.name::TEXT
                )
            ) INTO student_attachments_file
        FROM student_ass_attachment at
        INNER JOIN storage.objects o ON o.id = at.file_id
        INNER JOIN internal.student_ass_progress s on at.sap_id = s.sap_id
        INNER JOIN internal.users u on u.user_id = s.user_id
        WHERE at.sap_id = dcrpt_sap_id
          AND at.file_id IS NOT NULL;

        SELECT
            json_agg(
                jsonb_build_object(
                    'my_attachment_url', at.url::text
                )
            ) INTO student_attachments_url
        FROM student_ass_attachment at
        INNER JOIN internal.student_ass_progress s on at.sap_id = s.sap_id
        INNER JOIN internal.users u on u.user_id = s.user_id
        WHERE at.sap_id = dcrpt_sap_id
          AND at.url IS NOT NULL;

        -------------------------------------------------------------------
        -- FINAL RETURN
        -------------------------------------------------------------------
        RETURN jsonb_build_object(
            'student_attachments_url', coalesce(student_attachments_url, '[]'::jsonb),
            'student_attachments_file', coalesce(student_attachments_file, '[]'::jsonb),
            'faculty_attachments', coalesce(faculty_attachments, '[]'::jsonb),
            'assignment_details', assignment_details
        );


    END IF;
END;
$$; -- NEW
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION internal.view_student_assignment(IN p_student_assignment_id TEXT) FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION internal.view_student_assignment(IN p_student_assignment_id TEXT) TO authenticated;

----- SUBTASK 7.2.3 EVALUATE STUDENT'S ASSIGNMENT

CREATE OR REPLACE PROCEDURE internal.evaluate_student_assignment(IN p_student_assignment_id TEXT, IN p_student_mark INT)
SET search_path = internal
AS $$
DECLARE
    dcrpt_sap_id INT;
    f_version_id INT;
    f_total_points INT;
BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['faculty'])) = FALSE THEN
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    END IF;

    -- decrypt sap_id
    BEGIN
            dcrpt_sap_id := pgp_sym_decrypt(
                decode(p_student_assignment_id, 'base64'),
                get_secret_key('view_student_assignment') -- if screen from enrolled courses
            )::INT;
    EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Valid Student Assignment ID is required.'
            USING ERRCODE = 'P0035';
    END;

    f_version_id := (
            SELECT l.version_id
            FROM student_ass_progress sap
            INNER JOIN internal.assignment a on a.ass_id = sap.ass_id
            INNER JOIN internal.lesson l on l.lesson_id = a.lesson_id
            WHERE sap.sap_id = dcrpt_sap_id

        );

    -- CHECK IF FACULTY MATCH
    IF EXISTS (
        SELECT 1
        FROM course_version_faculty
        WHERE version_id = f_version_id
        AND user_id = (SELECT user_id FROM users WHERE auth_id = auth.uid())
    ) THEN

        SELECT total_points INTO f_total_points FROM assignment WHERE ass_id  = (select ass_id FROM student_ass_progress WHERE sap_id = dcrpt_sap_id);

        IF p_student_mark NOT BETWEEN 0 AND f_total_points THEN
            RAISE EXCEPTION 'Invalid mark: % (must be between 0 and %)',
                p_student_mark, f_total_points
                USING ERRCODE = 'P0064';
        end if;

        UPDATE student_ass_progress SET eval_points = p_student_mark WHERE sap_id = dcrpt_sap_id;
    ELSE
        RAISE EXCEPTION 'You are not authorized to perform any actions on this course.'
                USING ERRCODE = 'P0050';
    end if;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
REVOKE ALL ON PROCEDURE internal.evaluate_student_assignment(IN p_student_assignment_id TEXT, IN p_student_mark INT) FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE internal.evaluate_student_assignment(IN p_student_assignment_id TEXT, IN p_student_mark INT) TO authenticated;


---- SUBTASK 7.3.1 VIEW STUDENTS EXAM PROGRESS

CREATE OR REPLACE FUNCTION internal.view_exam_progress(IN p_exam_id TEXT)
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
    dcrpt_test_id INT;
BEGIN

    -- Only run main query if key exists and confirm the user role
    IF (
        (SELECT check_user_role(ARRAY['faculty'])) = TRUE AND
        internal.get_secret_key('view_exam_progress') IS NOT NULL) THEN

        BEGIN
            dcrpt_test_id := pgp_sym_decrypt(
                decode(p_exam_id, 'base64'),
                get_secret_key('view_course') -- if screen from enrolled courses
            )::INT;
        EXCEPTION
            WHEN OTHERS THEN
                RAISE EXCEPTION 'Valid Exam ID is required.'
                USING ERRCODE = 'P0035';
        END;

        RETURN QUERY
            SELECT DISTINCT ON (u.user_id)
                -- 1.) id
                encode(
                    pgp_sym_encrypt(str.ut_id::TEXT, internal.get_secret_key('view_exam_progress')),
                    'base64'
                )::TEXT,

                -- 2.) avatar path
                av.name::TEXT,

                -- 3.) stduent full name
                CONCAT(u.lname, ', ', u.fname, ' ', COALESCE(u.mname, ''))::TEXT,

                -- 4.) email
                au.email::TEXT,

                -- 5.) completed
                (
                    SELECT
                        case
                            when coalesce(count(*), 0) <= 0 then 'not started'
                            when (count(*) filter ( where  str1.completed_at is not null)) > 0 then
                                COALESCE((SELECT TO_CHAR(str2.completed_at, 'Mon DD, YYYY')
                                 from student_test_record str2
                                 where test_id = t.test_id and user_id = str.user_id order by completed_at desc limit 1), 'on going')::text
                            else 'on going'
                        end
                    FROM student_test_record str1
                    WHERE str1.test_id = t.test_id and str1.user_id = str.user_id
                ) as completed_at

            FROM student_test_record str
            INNER JOIN internal.users u on u.user_id = str.user_id
                INNER JOIN storage.objects av on av.id = u.profile_id
                INNER JOIN auth.users au on au.id = u.auth_id
            INNER JOIN internal.test t on t.test_id = str.test_id
            WHERE str.test_id = dcrpt_test_id;

    ELSE
        -- No secret key, return empty result set
        RETURN QUERY
        SELECT NULL::TEXT, NULL::TEXT, NULL::TEXT, NULL::TEXT,
               NULL::TEXT
        WHERE FALSE;
    END IF;
END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION internal.view_exam_progress(IN p_exam_id TEXT) FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION internal.view_exam_progress(IN p_exam_id TEXT) TO authenticated;


---- SUBTASK 7.3.2 VIEW STUDENTS EXAM ATTEMPTS


CREATE OR REPLACE FUNCTION internal.view_student_attempts(IN p_student_exam_id TEXT)
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
    dcrpt_ut_id INT;
    f_test_id INT;
    f_user_id INT;
BEGIN

    -- Only run main query if key exists and confirm the user role
    IF (
        (SELECT check_user_role(ARRAY['faculty'])) = TRUE AND
        internal.get_secret_key('view_student_attempts') IS NOT NULL) THEN

        BEGIN
            dcrpt_ut_id := pgp_sym_decrypt(
                decode(p_student_exam_id, 'base64'),
                get_secret_key('view_exam_progress') -- if screen from enrolled courses
            )::INT;
        EXCEPTION
            WHEN OTHERS THEN
                RAISE EXCEPTION 'Valid Student Exam ID is required.'
                USING ERRCODE = 'P0035';
        END;

        SELECT test_id, user_id INTO f_test_id, f_user_id
        FROM student_test_record WHERE ut_id = dcrpt_ut_id;


        RETURN QUERY
            WITH ranked_attempts AS (
                    SELECT
                        str.ut_id,
                        str.user_id,
                        str.test_id,
                        str.created_at,
                        str.completed_at,

                        ROW_NUMBER() OVER (
                            PARTITION BY str.user_id, str.test_id
                            ORDER BY COALESCE(str.completed_at, str.created_at)
                        ) AS attempt_number
                    FROM internal.student_test_record str
                    WHERE str.user_id = f_user_id
                      AND str.test_id = f_test_id
                )
                SELECT
                    encode(pgp_sym_encrypt(ra.ut_id::TEXT, internal.get_secret_key('view_student_attempts')), 'base64')::text,
                    CONCAT('Attempt ', ra.attempt_number)::TEXT,
                    -- 🕒 Time taken
                    (CASE
                        WHEN ra.completed_at IS NULL THEN 'on going'
                        ELSE
                            TRIM(BOTH ' ' FROM
                                CONCAT_WS(' ',
                                    CASE
                                        WHEN EXTRACT(HOUR FROM (ra.completed_at - ra.created_at)) > 0
                                            THEN EXTRACT(HOUR FROM (ra.completed_at - ra.created_at))::INT || 'h'
                                    END,
                                    CASE
                                        WHEN EXTRACT(MINUTE FROM (ra.completed_at - ra.created_at)) > 0
                                            THEN EXTRACT(MINUTE FROM (ra.completed_at - ra.created_at))::INT || 'm'
                                    END,
                                    CASE
                                        WHEN EXTRACT(HOUR FROM (ra.completed_at - ra.created_at)) = 0
                                            AND EXTRACT(MINUTE FROM (ra.completed_at - ra.created_at)) = 0
                                            AND EXTRACT(SECOND FROM (ra.completed_at - ra.created_at)) > 0
                                                THEN ROUND(EXTRACT(SECOND FROM (ra.completed_at - ra.created_at))::NUMERIC, 0)::INT || 's'
                                    END
                                )
                            )
                    END),
                    view_attempt_result(encode(pgp_sym_encrypt(ra.ut_id::TEXT, internal.get_secret_key('view_exam')), 'base64')::text)->>'student_score', -- uses view_exam key to view the scores
                    CASE
                        WHEN (view_attempt_result(encode(pgp_sym_encrypt(ra.ut_id::TEXT, internal.get_secret_key('view_exam')), 'base64')::text)->>'pending_essays')::int > 0 THEN 'Preliminary (Pending Faculty Evaluation)'
                        ELSE 'Final/Official'
                    END
                FROM ranked_attempts ra
                ORDER BY ra.attempt_number desc;

    ELSE
        -- No secret key, return empty result set
        RETURN QUERY
        SELECT NULL::TEXT, NULL::TEXT, NULL::TEXT, NULL::TEXT,
               NULL::TEXT
        WHERE FALSE;
    END IF;
END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION internal.view_student_attempts(IN p_student_exam_id TEXT) FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION internal.view_student_attempts(IN p_student_exam_id TEXT) TO authenticated;

---- SUBTASK 7.3.3 VIEW STUDENT'S EXAM answers

CREATE OR REPLACE FUNCTION internal.view_students_exam_result(IN p_student_attempt_id TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    dcrpt_ut_id INT;
    questionnaire_set JSONB := '[]'::jsonb;
    f_question_ids INT[];
    id INT;
    v_answer_type TEXT;
    v_question JSONB;
    v_items JSONB;
BEGIN
    BEGIN
        dcrpt_ut_id := pgp_sym_decrypt(
            decode(p_student_attempt_id, 'base64'),
            get_secret_key('view_student_attempts') -- if screen from enrolled courses
        )::INT;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Valid Student Attempt ID is required.'
                USING ERRCODE = 'P0035';
    END;

    -- Only run main query if key exists and confirm the user role
    IF (
        (SELECT check_user_role(ARRAY['faculty'])) = TRUE AND
        internal.get_secret_key('view_students_exam_result') IS NOT NULL) THEN

            -- GET ALL QUESTION IDS
            SELECT array_agg(question_id) INTO f_question_ids
            FROM question
            WHERE test_id = (SELECT test_id FROM student_test_record WHERE ut_id = dcrpt_ut_id);

            -- BUILD QUESTIONARE
            IF f_question_ids IS NOT NULL OR array_length(f_question_ids, 1) != 0 THEN
                FOREACH id IN ARRAY f_question_ids LOOP

                    -- get question details
                    SELECT
                        json_build_object(
                            'record_id', encode(
                                        pgp_sym_encrypt(
                                            jsonb_build_object(
                                                'ut_id', dcrpt_ut_id::INT,
                                                'question_id', q.question_id::INT,
                                                'answer_type', a.answer_type::text
                                            )::text,
                                            internal.get_secret_key('view_students_exam_result')
                                        ),
                                        'base64'
                                    ),
                            'question', q.question::text,
                            'points', q.total_points,
                            'answer_type', a.answer_type::text
                        ),
                        a.answer_type::text
                    INTO v_question, v_answer_type
                    FROM question q
                    inner join internal.answer_type a on a.anst_id = q.anst_id
                    where question_id = id;

                    -- get items if there are
                    IF v_answer_type = 'multiple choice' THEN
                        SELECT
                            json_agg(
                                json_build_object(
                                'student_answer_id', encode(pgp_sym_encrypt(sa.sta_id::TEXT, internal.get_secret_key('view_students_exam_result')),'base64')::text,
                                'student_answer', ak.text_key::text,
                                'is_correct', ak.is_correct,
                                'answer_time', TO_CHAR(sa.answer_time, 'HH24:MI:SS'),
                                'correct_answer', (SELECT ak2.text_key FROM answer_key ak2 WHERE ak2.is_correct IS TRUE AND ak2.question_id = id)
                            )
                        ) INTO v_items
                        FROM answer_key ak
                        INNER JOIN internal.student_answer sa on ak.key_id = sa.key_id
                        WHERE ak.question_id = id AND sa.ut_id = dcrpt_ut_id;

                        questionnaire_set = questionnaire_set || jsonb_build_object(
                                'question_details', v_question,
                                'item_details', v_items
                            );
                    end if;

                    IF v_answer_type = 'true/false' THEN
                        SELECT
                            json_agg(
                                json_build_object(
                                'student_answer_id', encode(pgp_sym_encrypt(sa.sta_id::TEXT, internal.get_secret_key('view_students_exam_result')),'base64')::text,
                                'student_answer', sa.tof_ans,
                                'is_correct', CASE WHEN sa.tof_ans = ak.tof_key THEN TRUE ELSE FALSE END,
                                'answer_time', TO_CHAR(sa.answer_time, 'HH24:MI:SS'),
                                'correct_answer', ak.tof_key
                            )
                        ) INTO v_items
                        FROM answer_key ak
                        INNER JOIN internal.student_answer sa on ak.key_id = sa.key_id
                        WHERE ak.question_id = id AND sa.ut_id = dcrpt_ut_id;

                        questionnaire_set = questionnaire_set || jsonb_build_object(
                                'question_details', v_question,
                                'item_details', v_items
                            );
                    end if;

                    IF v_answer_type = 'identification' THEN
                        SELECT
                            json_agg(
                                json_build_object(
                                'student_answer_id', encode(pgp_sym_encrypt(sa.sta_id::TEXT, internal.get_secret_key('view_students_exam_result')),'base64')::text,
                                'student_answer', sa.text_ans,
                                'is_correct', CASE WHEN sa.text_ans = ak.text_key THEN TRUE ELSE FALSE END,
                                'answer_time', TO_CHAR(sa.answer_time, 'HH24:MI:SS'),
                                'correct_answer', ak.text_key
                            )
                        ) INTO v_items
                        FROM answer_key ak
                        INNER JOIN internal.student_answer sa on ak.key_id = sa.key_id
                        WHERE ak.question_id = id AND sa.ut_id = dcrpt_ut_id;

                        questionnaire_set = questionnaire_set || jsonb_build_object(
                                'question_details', v_question,
                                'item_details', v_items
                            );
                    end if;

                    IF v_answer_type = 'essay' THEN
                        SELECT
                            json_agg(
                                json_build_object(
                                'student_answer_id', encode(pgp_sym_encrypt(sa.sta_id::TEXT, internal.get_secret_key('view_students_exam_result')),'base64')::text,
                                'student_answer', sa.text_ans,
                                'is_correct', null,
                                'answer_time', TO_CHAR(sa.answer_time, 'HH24:MI:SS'),
                                'mark', CASE WHEN sa.essay_given_points is null then 'pending evaluation' ELSE sa.essay_given_points::TEXT END
                            )
                        ) INTO v_items
                        FROM answer_key ak
                        INNER JOIN internal.student_answer sa on ak.key_id = sa.key_id
                        WHERE ak.question_id = id AND sa.ut_id = dcrpt_ut_id;

                        questionnaire_set = questionnaire_set || jsonb_build_object(
                                'question_details', v_question,
                                'item_details', v_items
                            );
                    end if;

                    IF v_answer_type = 'enumeration' THEN

                        SELECT
                            json_agg(
                                json_build_object(
                                'student_answer_id', encode(pgp_sym_encrypt(sa.sta_id::TEXT, internal.get_secret_key('view_students_exam_result')),'base64')::text,
                                'student_answer', sa.enum_ans,
                                'is_correct',   CASE
                                                    WHEN ((
                                                            WITH correct_list AS (
                                                                SELECT trim(lower(x)) AS val FROM unnest(ak.enum_keys) AS x
                                                            ),
                                                            student_list AS (
                                                                SELECT trim(lower(s)) AS val FROM unnest(sa.enum_ans) AS s
                                                            )
                                                            SELECT jsonb_build_object(
                                                                'corrects', (SELECT COUNT(*) FROM student_list s WHERE s.val IN (SELECT val FROM correct_list)),
                                                                'wrongs',  (SELECT COUNT(*) FROM student_list s WHERE s.val NOT IN (SELECT val FROM correct_list))
                                                            )
                                                        )->>'corrects')::int > 0 THEN TRUE
                                                    ELSE FALSE
                                                END,
                                'answer_time', TO_CHAR(sa.answer_time, 'HH24:MI:SS'),
                                'correct_answer', ak.enum_keys,
                                'credit_earned', (
                                                    WITH correct_list AS (
                                                        SELECT trim(lower(x)) AS val FROM unnest(ak.enum_keys) AS x
                                                    ),
                                                    student_list AS (
                                                        SELECT trim(lower(s)) AS val FROM unnest(sa.enum_ans) AS s
                                                    )
                                                    SELECT
                                                        CONCAT(
                                                            (SELECT COUNT(*) FROM student_list s WHERE s.val IN (SELECT val FROM correct_list)),
                                                            '/',
                                                            COALESCE(array_length(ak.enum_keys, 1), 0)
                                                        )
                                                )
                            )
                        ) INTO v_items
                        FROM answer_key ak
                        INNER JOIN internal.student_answer sa on ak.key_id = sa.key_id
                        WHERE ak.question_id = id AND sa.ut_id = dcrpt_ut_id;

                        questionnaire_set = questionnaire_set || jsonb_build_object(
                                'question_details', v_question,
                                'item_details', v_items
                            );

                    end if;

                END LOOP;

                RETURN jsonb_build_object(
                    'questionnaire', questionnaire_set
                );

            ELSE
                RAISE EXCEPTION 'This Test/Exam is empty.'
                    USING ERRCODE = 'P0046';
            END IF;

    ELSE
        RETURN jsonb_build_object(
                    'questionnaire', '[]'::jsonb
                );
    END IF;

END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION internal.view_students_exam_result(IN p_student_attempt_id TEXT) FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION internal.view_students_exam_result(IN p_student_attempt_id TEXT) TO authenticated;


----- SUBTASK 7.3.4 EVALUATE STUDENT'S essay answer

CREATE OR REPLACE PROCEDURE internal.evaluate_student_essay(IN p_student_answer_id TEXT, IN p_student_mark INT)
SET search_path = internal
AS $$
DECLARE
    dcrpt_sta_id INT;
    f_version_id INT;
    f_total_points INT;
BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['faculty'])) = FALSE THEN
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    END IF;

    -- decrypt sta_id
    BEGIN
            dcrpt_sta_id := pgp_sym_decrypt(
                decode(p_student_answer_id, 'base64'),
                get_secret_key('view_students_exam_result') -- if screen from enrolled courses
            )::INT;
    EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Valid Student Answer ID is required.'
            USING ERRCODE = 'P0035';
    END;

    f_version_id := (
            SELECT l.version_id
            FROM student_answer sa
            INNER JOIN internal.student_test_record str on str.ut_id = sa.ut_id
            INNER JOIN internal.test t on t.test_id = str.test_id
            INNER JOIN internal.lesson l on t.lesson_id = l.lesson_id
            WHERE sa.sta_id = dcrpt_sta_id

        );

    -- CHECK IF FACULTY MATCH
    IF EXISTS (
        SELECT 1
        FROM course_version_faculty
        WHERE version_id = f_version_id
        AND user_id = (SELECT user_id FROM users WHERE auth_id = auth.uid())
    ) THEN

        SELECT q.total_points INTO f_total_points
        FROM question q
        INNER JOIN internal.answer_key ak on q.question_id = ak.question_id
        INNER JOIN internal.student_answer s on ak.key_id = s.key_id
        WHERE s.sta_id  = dcrpt_sta_id;

        IF p_student_mark NOT BETWEEN 0 AND f_total_points THEN
            RAISE EXCEPTION 'Invalid mark: % (must be between 0 and %)',
                p_student_mark, f_total_points
                USING ERRCODE = 'P0064';
        end if;

        UPDATE student_answer SET essay_given_points = p_student_mark WHERE sta_id = dcrpt_sta_id;
    ELSE
        RAISE EXCEPTION 'You are not authorized to perform any actions on this course.'
                USING ERRCODE = 'P0050';
    end if;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
REVOKE ALL ON PROCEDURE internal.evaluate_student_essay(IN p_student_answer_id TEXT, IN p_student_mark INT) FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE internal.evaluate_student_essay(IN p_student_answer_id TEXT, IN p_student_mark INT) TO authenticated;


-- TASK 8) LIST OF ALL STUDENTS UNDER FACULTY WHO ARE ASSIGNED TO COMPREHENSIVE EXAM

CREATE OR REPLACE FUNCTION internal.view_compre_ready_students()
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
BEGIN
    -- Only run main query if key exists and confirm the user role
    IF (
        (SELECT check_user_role(ARRAY['faculty', 'dean'])) = TRUE AND
        internal.get_secret_key('view_compre_ready_students') IS NOT NULL) THEN


        RETURN QUERY
            SELECT
                -- 1.) id
                encode(pgp_sym_encrypt(mc.enrollee_id::TEXT, internal.get_secret_key('view_compre_ready_students')),'base64')::text,

                -- 2.) avatar path
                av.name::TEXT,

                -- 3.) stduent full name
                CONCAT(u.lname, ', ', u.fname, ' ', COALESCE(u.mname, ''))::TEXT,

                -- 4.) email
                au.email::TEXT,

                -- 5.) program
                 CASE
                    WHEN s.specialization IS NULL THEN
                        CONCAT(p2.prog_name, ', ', p2.prog_abbr)
                    ELSE
                        CONCAT(p2.prog_name, ' major in ', s.specialization, ', ',
                               p2.prog_abbr, ' - ', s.special_abbr)
                END::TEXT as program,

                -- 6.) course
                c.crs_title::text as course,

                -- 7.) GRADE
                COALESCE(get_grade(u.user_id, mc.version_id)::text,'Pending Evaluation'),

                -- 8.) tentative_date
                compre_tentative_date::TEXT,

                -- 9.) FAculty Confirmation
                CASE
                    WHEN mc.confirmed_at IS NOT NULL THEN concat('Confirmed at ', (mc.confirmed_at)::date)
                    ELSE 'Pending Evaluation'
                END
            FROM my_courses mc
            inner join internal.course_version_faculty cvf on mc.version_id = cvf.version_id
                inner join internal.users u1 on u1.user_id = cvf.user_id
                    INNER JOIN internal.college_and_office cao on cao.cao_id = u1.cao_id
            INNER JOIN internal.users u on u.user_id = mc.user_id
                INNER JOIN storage.objects av on av.id = u.profile_id
                INNER JOIN auth.users au on au.id = u.auth_id
            INNER JOIN internal.prospectus_course pc on pc.pc_id = mc.version_id
                inner join internal.course c on c.crs_id = pc.crs_id
                inner JOIN internal.prospectus p on p.prospectus_id = pc.prospectus_id
                    inner join internal.specialization s on s.special_id = p.special_id
                        inner JOIN internal.program p2 on p2.prog_id = s.prog_id
            WHERE mc.compre_tentative_date IS NOT NULL
            AND (
                check_user_role(ARRAY['dean']) = TRUE
                OR u1.auth_id = auth.uid()
            )
            ORDER BY u.lname, u.fname, u.mname, p.prospectus_id, -- DISTINCT ON requires this
                    program, course;
    ELSE
        -- No secret key, return empty result set
        RETURN QUERY
        SELECT NULL::TEXT, NULL::TEXT, NULL::TEXT, NULL::TEXT,
               NULL::TEXT, NULL::TEXT, NULL::TEXT, NULL::TEXT, NULL::TEXT
        WHERE FALSE;
    END IF;
END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION internal.view_compre_ready_students() FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION internal.view_compre_ready_students() TO authenticated;



-- TASK 8.1.1 TO CONFIRM STUDENT IF ALREADY TAKEN THE COMPREHENSIVE EXAM [faculty]

CREATE OR REPLACE PROCEDURE internal.confirm_student(IN p_student_id TEXT)
SET search_path = internal
AS $$
DECLARE
    dcrpt_enrollee_id INT;
BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['faculty'])) = FALSE THEN
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    END IF;

    -- decrypt ENROLLEE ID
    BEGIN
            dcrpt_enrollee_id := pgp_sym_decrypt(
                decode(p_student_id, 'base64'),
                get_secret_key('view_compre_ready_students') -- if screen from enrolled courses
            )::INT;
    EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Valid Student ID is required.'
            USING ERRCODE = 'P0035';
    END;

    -- check if this is the professor
    -- CHECK IF FACULTY MATCH
    IF NOT EXISTS (
        SELECT 1
        FROM course_version_faculty
        WHERE version_id = (SELECT version_id FROM my_courses WHERE enrollee_id = dcrpt_enrollee_id)
        AND user_id = (SELECT user_id FROM users WHERE auth_id = auth.uid())
    ) THEN
        RAISE EXCEPTION 'You are not authorized to perform any actions on this course.'
                USING ERRCODE = 'P0050';
    end if;

    IF EXISTS(
        SELECT 1 FROM my_courses WHERE enrollee_id = dcrpt_enrollee_id AND now() >= compre_tentative_date
    ) THEN
        UPDATE my_courses SET confirmed_at = now() where enrollee_id = dcrpt_enrollee_id;
    else
        RAISE EXCEPTION
        'The comprehensive examination cannot be marked as completed. The scheduled tentative date has not yet been reached.'
        USING ERRCODE = 'P0035';
    end if;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
REVOKE ALL ON PROCEDURE internal.confirm_student(IN p_student_id TEXT) FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE internal.confirm_student(IN p_student_id TEXT) TO authenticated;

-- TASK 8.1.2 RESCHEDULE COMPREHENSIVE EXAM DATE [dean]

CREATE OR REPLACE PROCEDURE internal.resched_compre_date(IN p_student_id TEXT, IN p_selected_date TIMESTAMPTZ)
SET search_path = internal
AS $$
DECLARE
    dcrpt_enrollee_id INT;
    f_prospectus_id INT;
    f_courses INT[];
    f_sem_end_date DATE;
BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['dean'])) = FALSE THEN
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    END IF;

    -- decrypt ENROLLEE ID
    BEGIN
            dcrpt_enrollee_id := pgp_sym_decrypt(
                decode(p_student_id, 'base64'),
                get_secret_key('view_compre_ready_students') -- if screen from enrolled courses
            )::INT;
    EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Valid Student ID is required.'
            USING ERRCODE = 'P0035';
    END;

    IF EXISTS(
        SELECT 1 FROM my_courses WHERE enrollee_id = dcrpt_enrollee_id
    ) THEN
        -- get the enrollees prrospectus_id
        SELECT pc1.prospectus_id INTO f_prospectus_id FROM prospectus_course pc1 WHERE pc1.pc_id = (SELECT version_id FROM my_courses WHERE enrollee_id = dcrpt_enrollee_id);

        -- get all the courses that belongs in that prospectus_id Except that belongs to Research Design & Writing
        SELECT array_agg(mc.version_id) INTO f_courses
        FROM my_courses mc
            INNER JOIN internal.course_version cv on cv.version_id = mc.version_id
                INNER JOIN internal.prospectus_course pc on pc.pc_id = cv.version_id
                    INNER JOIN internal.classification_unit u on u.cu_id = pc.cu_id
                        INNER JOIN internal.classification c2 on c2.classification_id = u.classification_id
        WHERE pc.prospectus_id = f_prospectus_id
        AND c2.classification != 'Research Design & Writing'
        AND mc.user_id = (SELECT user_id FROM my_courses WHERE enrollee_id = dcrpt_enrollee_id);

        -- begin updating all rows
        UPDATE my_courses
        SET compre_tentative_date = p_selected_date
        WHERE version_id = ANY(f_courses) AND user_id = (SELECT user_id FROM my_courses WHERE enrollee_id = dcrpt_enrollee_id);

    else
        RAISE EXCEPTION
        'The student does not exist or is not yet eligible for the comprehensive examination.'
        USING ERRCODE = 'P0035';
    end if;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
REVOKE ALL ON PROCEDURE internal.resched_compre_date(IN p_student_id TEXT, IN p_selected_date TIMESTAMPTZ) FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE internal.resched_compre_date(IN p_student_id TEXT, IN p_selected_date TIMESTAMPTZ) TO authenticated;


