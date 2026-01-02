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


-----------------------------------------------------------------------------------------------
------------------------------- INTERNAL SCHEMA -----------------------------------------------



------------------------------------------------------------------------------------------------------------------------
-- 1.My learning Programs  --------------------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION internal.my_learning_programs()
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
BEGIN
    -- Only run main query if key exists and confirm the user role
    IF (
        (SELECT check_user_role(ARRAY['student'])) = TRUE AND
        internal.get_secret_key('my_learning_programs') IS NOT NULL) THEN
        RETURN QUERY
            SELECT DISTINCT ON (p2.prospectus_id)
            -- 1.) ID (encrypted)
            encode(
                pgp_sym_encrypt(s.special_id::TEXT, internal.get_secret_key('my_learning_programs')),
                'base64'
            )::TEXT,

            -- 2.) Program/Specialization name
            CASE
                WHEN s.specialization IS NULL THEN
                    CONCAT(p.prog_name, ', ', p.prog_abbr)
                ELSE
                    CONCAT(p.prog_name, ' major in ', s.specialization, ', ',
                           p.prog_abbr, ' - ', s.special_abbr)
            END::TEXT,

            -- 3.) prospectus code
            p2.prospectus_code::text,

            -- 4.) Effective period
            p2.year::TEXT,

            -- 5.) wallpaper name
            o.name::text


        FROM specialization s
        INNER JOIN storage.objects o on o.id = s.wallpaper_id
        INNER JOIN internal.program p on p.prog_id = s.prog_id
        INNER JOIN internal.prospectus p2 on s.special_id = p2.special_id
        INNER JOIN internal.prospectus_course pc on p2.prospectus_id = pc.prospectus_id
        INNER JOIN internal.course_version cv on pc.pc_id = cv.version_id
        INNER JOIN internal.my_courses mc on cv.version_id = mc.version_id
        INNER JOIN internal.users u on u.user_id = mc.user_id
        WHERE u.auth_id = auth.uid();
    ELSE
        -- No secret key, return empty result set
        RETURN QUERY
        SELECT NULL::TEXT, NULL::TEXT, NULL::TEXT, NULL::TEXT, NULL::TEXT
        WHERE FALSE;
    END IF;
END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION internal.my_learning_programs() FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION internal.my_learning_programs() TO authenticated;

-- 2.) My Courses (related Courses)

CREATE OR REPLACE FUNCTION internal.my_courses(IN my_learning_program_id TEXT) -- deprecated
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
    dcrpt_special_id INT;
BEGIN
    -- decrypt special_id
    BEGIN
        dcrpt_special_id := pgp_sym_decrypt(
        decode(my_learning_program_id, 'base64'),
        get_secret_key('my_learning_programs')
    )::INT;
    EXCEPTION
        WHEN OTHERS THEN
            BEGIN
                dcrpt_special_id := pgp_sym_decrypt(
                    decode(my_learning_program_id, 'base64'),
                    get_secret_key('view_program')
                )::INT;
            EXCEPTION
                WHEN OTHERS THEN
                    RAISE EXCEPTION 'Valid "Program ID" Required.'
                        USING ERRCODE = 'P0043';
            end;
    end;

    -- Only run main query if key exists and confirm the user role
    IF (
        (SELECT check_user_role(ARRAY['student'])) = TRUE AND
        internal.get_secret_key('my_courses') IS NOT NULL) THEN
        RETURN QUERY
            SELECT DISTINCT ON (mc.version_id)
            -- 1.) ID (encrypted)
            encode(
                pgp_sym_encrypt(mc.version_id::TEXT, internal.get_secret_key('my_courses')),
                'base64'
            )::TEXT,

            -- course name
            c.crs_title::text,

            -- course code
            pc.crs_code::text,

            -- semester
            s.sem_name::text,

            -- wallpaper
            o.name::text,

            -- lessons left
            concat('N',' out of ', count(l.lesson_id), ' lessons'),

            -- progress
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
                )::TEXT


        FROM my_courses mc
        INNER JOIN internal.users u on u.user_id = mc.user_id
        INNER JOIN internal.course_version cv on cv.version_id = mc.version_id
        INNER JOIN storage.objects o on o.id = cv.wallpaper_id
        INNER JOIN internal.prospectus_course pc on pc.pc_id = cv.version_id
        INNER JOIN internal.course c on c.crs_id = pc.crs_id
        LEFT JOIN internal.prospectus_semester ps on ps.prosem_id = pc.prosem_id
        LEFT JOIN internal.semester s ON s.sem_id = ps.sem_id
        INNER JOIN internal.prospectus p2 on pc.prospectus_id = p2.prospectus_id
        INNER JOIN internal.specialization s2 on s2.special_id = p2.special_id
        INNER JOIN lesson l on l.version_id = mc.version_id
            WHERE u.auth_id = auth.uid()
              AND s2.special_id = dcrpt_special_id
              AND cv.apvd_rvwd_by IS NOT NULL
              AND mc.enrollment_status = TRUE
              AND (now()::date >= lower(ps.duration) AND now()::date <= upper(ps.duration) + INTERVAL '1 year')
            group by mc.user_id, mc.version_id, s.sem_name, pc.crs_code, c.crs_title, mc.version_id, o.name;
    ELSE
        -- No secret key, return empty result set
        RETURN QUERY
        SELECT NULL::TEXT, NULL::TEXT, NULL::TEXT, NULL::TEXT, NULL::TEXT, NULL::TEXT, NULL::TEXT
        WHERE FALSE;
    END IF;
END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION internal.my_courses(IN my_learning_program_id text) FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION internal.my_courses(IN my_learning_program_id text) TO authenticated;

-- My Courses Version 2

CREATE OR REPLACE FUNCTION internal.my_courses2(IN my_learning_program_id TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    dcrpt_special_id INT;
    data JSONB := NULL;

BEGIN
    -- decrypt special_id
    BEGIN
        dcrpt_special_id := pgp_sym_decrypt(
        decode(my_learning_program_id, 'base64'),
        get_secret_key('my_learning_programs')
    )::INT;
    EXCEPTION
        WHEN OTHERS THEN
            BEGIN
                dcrpt_special_id := pgp_sym_decrypt(
                    decode(my_learning_program_id, 'base64'),
                    get_secret_key('view_program')
                )::INT;
            EXCEPTION
                WHEN OTHERS THEN
                    RAISE EXCEPTION 'Valid "Program ID" Required.'
                        USING ERRCODE = 'P0043';
            end;
    end;

    -- Only run main query if key exists and confirm the user role
    IF (
        (SELECT check_user_role(ARRAY['student'])) = TRUE AND
        internal.get_secret_key('my_courses') IS NOT NULL) THEN


        with tt as (
            SELECT DISTINCT
                p1.prospectus_id,
                p1.prospectus_code,
                p1.date_created
            FROM prospectus p1
                INNER JOIN internal.prospectus_course pc1 on pc1.prospectus_id = p1.prospectus_id
                    INNER JOIN internal.course_version cv1 on cv1.version_id = pc1.pc_id
                        INNER JOIN internal.my_courses mc1 on mc1.version_id = cv1.version_id
            WHERE mc1.user_id = (SELECT user_id FROM users WHERE auth_id = auth.uid())
            AND p1.special_id = dcrpt_special_id
        )
        SELECT
            json_agg(
                jsonb_build_object(
                    'prospectus_code', tt.prospectus_code::text,
                    'tentative_date', COALESCE((
                            SELECT DISTINCT ON (mc2.compre_tentative_date) mc2.compre_tentative_date::text
                            FROM my_courses mc2
                                INNER JOIN internal.users u2 on u2.user_id = mc2.user_id
                                    INNER JOIN internal.prospectus_course pc2 on pc2.pc_id = mc2.version_id
                                        INNER JOIN internal.classification_unit cu2 on cu2.cu_id = pc2.cu_id
                                            INNER JOIN internal.classification c1 on c1.classification_id = cu2.classification_id
                            WHERE pc2.prospectus_id = tt.prospectus_id
                                AND c1.classification != 'Research Design & Writing'
                                AND u2.auth_id = auth.uid() limit 1
                        ), 'Pending Eligibility'),
                    'all_courses', (
                            SELECT
                                json_agg(
                                    jsonb_build_object(
                                        'classification', c3.classification,
                                        'units', CONCAT(
                                                    (SELECT COALESCE(SUM(c4.units), 0)
                                                     FROM my_courses mc4
                                                        INNER JOIN internal.course_version cv4 on cv4.version_id = mc4.version_id
                                                            INNER JOIN internal.prospectus_course pc4 on pc4.pc_id = cv4.version_id
                                                                INNER JOIN internal.course c4 on c4.crs_id = pc4.crs_id
                                                    WHERE pc4.cu_id = cu3.cu_id
                                                      AND mc4.user_id = (select user_id from users where auth_id = auth.uid())
                                                    ),
                                                    '/',
                                                    cu3.required_units
                                                 ),
                                        'courses', (
                                            SELECT
                                                json_agg(
                                                    jsonb_build_object(
                                                        -- 1.) ID (encrypted)
                                                        'course_id', encode(
                                                                        pgp_sym_encrypt(pc5.pc_id::TEXT, internal.get_secret_key('my_courses')),
                                                                        'base64'
                                                                    )::TEXT,

                                                        -- course name
                                                        'course_name', c5.crs_title::text,

                                                        -- course code
                                                        'course_code', pc5.crs_code::text,

                                                        -- semester
                                                        'semester', CASE WHEN sem5.sem_name IS NULL THEN 'TBA' ELSE sem5.sem_name::text END,

                                                        -- wallpaper
                                                        'wallpaper', o5.name::text,

                                                        -- progress
                                                        'progress', get_progress(mc5.user_id, mc5.version_id)::text,

                                                        -- grade
                                                        'grade', coalesce(get_grade(mc5.user_id, mc5.version_id)::text, '-')
                                                    )
                                                )
                                            FROM prospectus_course pc5
                                                INNER JOIN internal.prospectus p5 on p5.prospectus_id = pc5.prospectus_id
                                                    LEFT JOIN internal.specialization s5 on p5.special_id = s5.special_id
                                                LEFT JOIN internal.prospectus_semester ps5 on ps5.prosem_id = pc5.prosem_id
                                                    LEFT JOIN internal.semester sem5 on sem5.sem_id = ps5.sem_id
                                                LEFT JOIN internal.course_version cv5 on pc5.pc_id = cv5.version_id
                                                    LEFT JOIN storage.objects o5 on o5.id = cv5.wallpaper_id
                                                    LEFT JOIN internal.my_courses mc5 ON mc5.version_id = pc5.pc_id AND mc5.user_id = (SELECT user_id from users where auth_id = auth.uid()) -- student id
                                            INNER JOIN internal.course c5 on c5.crs_id = pc5.crs_id
                                            WHERE s5.special_id = dcrpt_special_id AND pc5.cu_id = cu3.cu_id
                                        )
                                    ) ORDER BY
                                      CASE c3.classification::text
                                        WHEN 'Foundation Course' THEN 1
                                        WHEN 'Major Course' THEN 2
                                        WHEN 'Cognates/Electives' THEN 3
                                        WHEN 'Research Design & Writing' THEN 4
                                        ELSE 5
                                      END
                                )
                            FROM classification_unit cu3
                                INNER JOIN internal.classification c3 on c3.classification_id = cu3.classification_id
                            WHERE cu3.prospectus_id = tt.prospectus_id
                        )
                ) ORDER BY tt.date_created DESC
            ) INTO data
        FROM tt;

        call assign_tentative_date(data);

    ELSE
        -- No secret key, return empty result set

    END IF;

    RETURN COALESCE(data, '[]'::jsonb);
END;
$$; -- NEW
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION internal.my_courses2(IN my_learning_program_id TEXT) FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION internal.my_courses2(IN my_learning_program_id TEXT) TO authenticated;

-- auto assign tentative date

CREATE OR REPLACE PROCEDURE internal.assign_tentative_date(IN p_data JSONB)
SET search_path = internal
AS $$
DECLARE
    dcrpt_enrollee_id INT;
    f_prospectus_id INT;
    f_courses INT[];
    f_sem_end_date DATE;

    -- eligibility fields
    pros JSONB;
    course_group JSONB;
    units_text TEXT;
    earned NUMERIC;
    required NUMERIC;
    eligible_foundation BOOLEAN := FALSE;
    eligible_major BOOLEAN := FALSE;
    eligible_cognates BOOLEAN := FALSE;

    updated_count INT;
    act_version_id INT;
    msg TEXT;
BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['student'])) = TRUE THEN

        FOR pros IN
            SELECT value FROM jsonb_array_elements(p_data) AS t(value)
        LOOP
            FOR course_group IN
                SELECT value FROM jsonb_array_elements(pros->'all_courses') AS t(value)
            LOOP
                    units_text := course_group->>'units';
                    earned := split_part(units_text, '/', 1)::numeric;
                    required := split_part(units_text, '/', 2)::numeric;

                CASE course_group->>'classification'
                    WHEN 'Foundation Course' THEN
                        IF earned >= required THEN eligible_foundation := TRUE; END IF;

                    WHEN 'Major Course' THEN
                        IF earned >= required THEN eligible_major := TRUE; END IF;

                    WHEN 'Cognates/Electives' THEN
                        IF earned >= required THEN eligible_cognates := TRUE; END IF;

                    ELSE
                    -- ignore Research Design & Writing and any others
                    NULL;

                END CASE;
            END LOOP;

            -- check if eligible
            IF eligible_foundation IS TRUE AND eligible_major IS TRUE AND eligible_cognates IS TRUE THEN

                IF EXISTS(
                    SELECT 1 FROM my_courses mc1
                    INNER JOIN internal.course_version c on c.version_id = mc1.version_id
                    INNER JOIN internal.prospectus_course p on p.pc_id = c.version_id
                    INNER JOIN internal.prospectus p2 on p2.prospectus_id = p.prospectus_id
                    WHERE p2.prospectus_code = pros->>'prospectus_code'
                    AND mc1.user_id = (SELECT user_id FROM users WHERE auth_id = auth.uid())
                    AND compre_tentative_date IS NULL
                ) THEN
                    -- get prospectus_id
                    SELECT prospectus_id into f_prospectus_id FROM prospectus WHERE prospectus_code = pros->>'prospectus_code';

                    -- get all the courses that belongs in that prospectus_id Except that belongs to Research Design & Writing
                    SELECT array_agg(mc.version_id) INTO f_courses
                    FROM my_courses mc
                        INNER JOIN internal.course_version cv on cv.version_id = mc.version_id
                            INNER JOIN internal.prospectus_course pc on pc.pc_id = cv.version_id
                                INNER JOIN internal.classification_unit u on u.cu_id = pc.cu_id
                                    INNER JOIN internal.classification c2 on c2.classification_id = u.classification_id
                    WHERE pc.prospectus_id = f_prospectus_id
                    AND c2.classification != 'Research Design & Writing'
                    AND mc.user_id = (SELECT user_id FROM users WHERE auth_id = auth.uid());

                    -- GET THE END DATE OF SEMESTER
                    SELECT upper(duration) INTO f_sem_end_date FROM prospectus_semester WHERE prospectus_id = f_prospectus_id AND NOW()::date <@ duration order by duration desc limit 1;

                    -- begin updating all rows
                    UPDATE my_courses
                    SET compre_tentative_date = f_sem_end_date
                    WHERE version_id = ANY(f_courses) AND user_id = (SELECT user_id FROM users WHERE auth_id = auth.uid());

                     GET DIAGNOSTICS updated_count = ROW_COUNT;

                    IF updated_count > 0 THEN
                        msg := format(
                            'Hello %s, congratulations! You have now met all the requirements for the Comprehensive Examination in the %s program. Your tentative Comprehensive Exam date is scheduled for %s. Please prepare accordingly.',
                            (SELECT fname FROM users WHERE user_id = (SELECT user_id FROM users WHERE auth_id = auth.uid())),
                            (
                                SELECT
                                    CASE
                                        WHEN s.specialization IS NULL THEN
                                            CONCAT(p4.prog_name, ', ', p4.prog_abbr)
                                        ELSE
                                            CONCAT(p4.prog_name, ' major in ', s.specialization, ', ',
                                                   p4.prog_abbr, ' - ', s.special_abbr)
                                    END::TEXT
                                FROM prospectus p3
                                    INNER JOIN internal.specialization s on p3.special_id = s.special_id
                                        INNER JOIN internal.program p4 on p4.prog_id = s.prog_id
                                WHERE p3.prospectus_code = pros->>'prospectus_code'
                                ),
                            to_char(f_sem_end_date AT TIME ZONE 'Asia/Manila',
                            'Month DD, YYYY HH12:MI AM')
                        );

                        INSERT INTO course_activity (recipient_id, type, metadata, message)
                                    VALUES (
                                        (SELECT user_id FROM users WHERE auth_id = auth.uid()), -- STUDENT IS THE RECEIVER
                                        'compre-tentative_date',
                                        jsonb_build_object(
                                            'visibility', jsonb_build_array('analytics', 'notification'),
                                            'course_completion_rate', get_progress((SELECT user_id FROM users WHERE auth_id = auth.uid()), act_version_id)
                                        ),
                                    msg
                                    );
                    END IF;



                end if;

            end if;

        END LOOP;

    END IF;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
REVOKE ALL ON PROCEDURE internal.assign_tentative_date(IN p_data JSONB) FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE internal.assign_tentative_date(IN p_data JSONB) TO authenticated;




-- 3.) View Course (This means all teh details contents and everything in the course)

CREATE OR REPLACE FUNCTION internal.view_course(IN p_my_course_id TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    dcrpt_version_id INT;
    is_eligible BOOLEAN := FALSE;

    v_header JSONB;
    faculty JSONB;
    v_about JSONB;
    v_lessons JSONB;
    section1_a JSONB;
    section1_b JSONB;
    ratings JSONB;
    user_reviews JSONB;
    v_reviews JSONB;
    v_more JSONB;
    resources JSONB;
    certificate_id TEXT;
    certificate_name TEXT;
    certificattion JSONB;

    request_payload JSONB;
    progress_user_id INT;

    v_syllabus JSONB;
    v_urls JSONB;

    rec RECORD;
BEGIN
    -- decrypt special_id
    BEGIN
        dcrpt_version_id := pgp_sym_decrypt(
            decode(p_my_course_id, 'base64'),
            get_secret_key('my_courses') -- if screen from enrolled courses
        )::INT;
    EXCEPTION
        WHEN OTHERS THEN
            BEGIN
                dcrpt_version_id := pgp_sym_decrypt(
                    decode(p_my_course_id, 'base64'),
                    get_secret_key('view_faculty_profile') -- if screen from faculty's profile
                )::INT;
            EXCEPTION
                WHEN OTHERS THEN
                    BEGIN
                        request_payload = (pgp_sym_decrypt(
                                    decode(p_my_course_id, 'base64'),
                                    internal.get_secret_key('my_assigned_courses')
                                ))::jsonb;

                        dcrpt_version_id := (request_payload->>'version_id')::INT;

                    EXCEPTION
                        WHEN OTHERS THEN
                            BEGIN
                                dcrpt_version_id := pgp_sym_decrypt(
                                    decode(p_my_course_id, 'base64'),
                                    get_secret_key('recently_added_courses') -- if screen from recently addedd courses
                                )::INT;
                            EXCEPTION
                                WHEN OTHERS THEN
                                    BEGIN
                                        dcrpt_version_id := pgp_sym_decrypt(
                                            decode(p_my_course_id, 'base64'),
                                            get_secret_key('get_last_course_interaction') -- if screen from recently addedd courses
                                        )::INT;
                                    EXCEPTION
                                        WHEN OTHERS THEN
                                            BEGIN
                                                dcrpt_version_id := pgp_sym_decrypt(
                                                    decode(p_my_course_id, 'base64'),
                                                    get_secret_key('recently_added_courses') -- if screen from recently addedd courses
                                                )::INT;
                                            EXCEPTION
                                                WHEN OTHERS THEN
                                                    BEGIN
                                                        dcrpt_version_id := pgp_sym_decrypt(
                                                            decode(p_my_course_id, 'base64'),
                                                            get_secret_key('select_prospectus') -- if screen from select_prospectus(dean)
                                                        )::INT;
                                                    EXCEPTION
                                                        WHEN OTHERS THEN
                                                            RAISE EXCEPTION 'Valid "Course ID" Required.'
                                                                USING ERRCODE = 'P0043';

                                                    end;
                                            end;

                                    end;
                            end;
                    end;
            end;
    END;




    -- CHECKS IF THIS COURSE IS ALREADY PUBLISHED
    IF EXISTS (
        SELECT 1
        FROM course_version
        WHERE version_id = dcrpt_version_id
          AND is_ready IS TRUE AND ( check_user_role(ARRAY['dean']) = TRUE OR apvd_rvwd_by IS NOT NULL)
    ) THEN

        -- CHECK USER REQUIREMENTS
        IF (
            (SELECT check_user_role(ARRAY['student', 'faculty', 'dean'])) = TRUE AND internal.get_secret_key('view_course') IS NOT NULL
        ) THEN
            -- CHECK IF CURRENTLY LOGGED USER IS ELIGIBLE
            IF EXISTS(
            SELECT 1
            FROM my_courses mc
            INNER JOIN internal.users u3 on u3.user_id = mc.user_id
            INNER JOIN internal.prospectus_course pc on pc.pc_id = mc.version_id
            INNER JOIN internal.prospectus_semester ps on ps.prosem_id = pc.prosem_id
            WHERE mc.version_id = dcrpt_version_id
              AND u3.auth_id = auth.uid()
              AND mc.enrollment_status IS TRUE
                AND (now()::date >= lower(ps.duration) AND now()::date <= upper(ps.duration) + INTERVAL '1 year')
            ) THEN
                is_eligible := TRUE;
            END IF;

            progress_user_id := (SELECT user_id FROM users WHERE auth_id = auth.uid());

        -------------------------------------------------------------------
        -- HEADER SECTION
        -------------------------------------------------------------------
        SELECT jsonb_build_object(
                        'wallpaper', o.name,
                       'course_code', pc.crs_code::TEXT,
                       'learning_level', CASE
                                            WHEN ll.level IS NULL THEN 'All levels'
                                            ELSE ll.level::TEXT
                                        END,
                       'course_title', c.crs_title,
                       'course_rating', CONCAT('⭐  ', ROUND(AVG(mc.rating)::numeric, 1)::text, ' (', COUNT(DISTINCT mc.user_id)::text, ')'),
                       'total_students', CONCAT(COUNT(DISTINCT mc.user_id) FILTER ( WHERE mc.enrollment_status IS TRUE ), ' enrolled'),
                        'total_lessons', CASE
                                            WHEN COALESCE(COUNT(distinct l.lesson_id),0) > 1 THEN CONCAT(COALESCE(COUNT(distinct l.lesson_id),0), ' Lessons')
                                            ELSE CONCAT(COALESCE(COUNT(distinct l.lesson_id),0), ' Lesson')
                                        END,
                       'progress', get_progress(progress_user_id, dcrpt_version_id)::TEXT
                   )
        INTO v_header
        FROM course_version cv
        LEFT JOIN storage.objects o ON o.id = cv.wallpaper_id
        LEFT JOIN internal.learning_level ll ON ll.ll_id = cv.ll_id
        INNER JOIN internal.prospectus_course pc ON cv.version_id = pc.pc_id
        INNER JOIN internal.course c ON c.crs_id = pc.crs_id
        LEFT JOIN internal.lesson l ON l.version_id = cv.version_id
        LEFT JOIN internal.my_courses mc ON mc.version_id = cv.version_id
        WHERE cv.version_id = dcrpt_version_id
        GROUP BY pc.crs_code, ll.level, c.crs_title,o.name;


        -------------------------------------------------------------------
        -- ABOUT SECTION (faculty)
        -------------------------------------------------------------------
        SELECT jsonb_build_object(
                   'faculty_id', encode(
                                     pgp_sym_encrypt(u2.user_id::TEXT, internal.get_secret_key('view_course')),
                                     'base64'
                                 )::text,
                   'faculty_avatar', o.name::text,
                   'faculty_name', CONCAT(u2.fname,' ', COALESCE(u2.mname, ''), ' ', u2.lname)::text,
                   'total_students', CONCAT(COUNT(DISTINCT mc.user_id)::int, ' students'),
                   'total_courses', CASE
                                       WHEN COUNT(DISTINCT cvf.version_id) > 1 THEN CONCAT(COUNT(DISTINCT cvf.version_id), ' courses')
                                       ELSE CONCAT(COUNT(DISTINCT cvf.version_id), ' course')
                                    END,
                   'rating', CASE
                                WHEN COUNT(mc.rating) FILTER (WHERE mc.rating IS NOT NULL) >= 5
                                THEN CONCAT('⭐  ', ROUND(AVG(mc.rating)::numeric, 2))  -- only 2 decimals
                                ELSE '⭐  0'
                            END

               )
        INTO faculty
        FROM users u2
        inner join storage.objects o on o.id = u2.profile_id
        LEFT JOIN internal.course_version_faculty cvf ON cvf.user_id = u2.user_id
        LEFT JOIN internal.my_courses mc ON mc.version_id = cvf.version_id
        WHERE u2.user_id = (
            SELECT DISTINCT ON (u2.user_id) u2.user_id
            FROM users u2
            INNER JOIN internal.course_version_faculty cvf ON u2.user_id = cvf.user_id
            WHERE u2.user_id = (select distinct user_id from course_version_faculty where version_id = dcrpt_version_id)
        )
        GROUP BY u2.user_id, o.name;

        v_about := jsonb_build_object(
            'description', (SELECT about FROM course_version WHERE version_id = dcrpt_version_id)::TEXT,
            'key_points',
                ( SELECT string_agg(concat('⭐  ', lesson_name), E'\n')
                    FROM (
                        SELECT lesson_name
                        FROM lesson
                        WHERE version_id = dcrpt_version_id
                        ORDER BY lesson_num
                    ) sub
                )::TEXT,
            'faculty', faculty
        );

        -------------------------------------------------------------------
        -- LESSONS SECTION
        -------------------------------------------------------------------

        -- CHECKS IF THIS COURSE HAS AT LEAST ONE LESSON AND ONE ASSESSMENT
        IF EXISTS (
           SELECT 1
           FROM lesson l
           WHERE l.version_id = dcrpt_version_id
        )
        AND EXISTS (
           SELECT 1
           FROM course_assessment ca
           WHERE ca.version_id = dcrpt_version_id
        ) THEN
            SELECT jsonb_agg(
                       jsonb_build_object(
                           'id', encode(
                                       pgp_sym_encrypt(combined.id::TEXT, internal.get_secret_key('view_course')),
                                       'base64'
                                   )::text,
                           'content_name', combined.content_name::text,
                           'path', COALESCE(combined.path::text, NULL),
                           'lesson_name', combined.lesson_name::text,
                           'lesson_description', combined.lesson_descr::text,
                           'content_type', combined.content_type::text,
                           'security', combined.security::text,
                           'claim_details', combined.claim_details::jsonb
                       ) ORDER BY combined.lesson_num,
                                   CASE combined.content_type WHEN 'video' THEN 1 WHEN 'assignment' THEN 2 WHEN 'exam' THEN 3 END,
                                   combined.id
                   ) INTO v_lessons
            FROM (
                SELECT
                    CASE
                        WHEN is_eligible IS TRUE THEN cm.material_id
                        WHEN (check_user_role(ARRAY['faculty', 'dean']) = TRUE) THEN cm.material_id
                    END AS id,
                    cm.material_name AS content_name,
                    CASE
                        WHEN is_eligible IS TRUE THEN so.name
                        WHEN (check_user_role(ARRAY['faculty', 'dean']) = TRUE) THEN so.name
                    END AS path,
                    l.lesson_num,
                    l.lesson_name,
                    l.lesson_descr,
                    'video' AS content_type,
                    CASE
                        WHEN is_eligible IS TRUE AND l.lesson_num = 0 THEN 'open'
                        WHEN is_eligible IS TRUE
                             AND l.lesson_num > 0
                             AND (SELECT lesson_id
                                  FROM lesson
                                  WHERE lesson_num = (l.lesson_num - 1)
                                    AND version_id = dcrpt_version_id
                                 ) = ANY(get_completed_lessons(progress_user_id, dcrpt_version_id))
                        THEN 'open'
                        ELSE 'locked'
                    END AS security,
                    COALESCE((
                        SELECT
                            jsonb_build_object(
                                'status', scmp.status,
                                'claim_id', encode(
                                        pgp_sym_encrypt(
                                            jsonb_build_object(
                                                'type', 'video',
                                                'material_id',scmp.material_id,
                                                'user_id', scmp.user_id
                                            )::text,
                                            internal.get_secret_key('view_course')
                                        ),
                                        'base64'
                                    )::text
                            )
                        FROM student_cm_progress scmp
                        WHERE scmp.material_id = cm.material_id
                          AND scmp.user_id = (SELECT user_id FROM users WHERE auth_id = auth.uid())
                    ), jsonb_build_object(
                        'status', NULL,
                        'claim_id', NULL
                    )) as claim_details
                FROM course_material cm
                INNER JOIN storage.objects so ON so.id = cm.material
                INNER JOIN lesson l ON l.lesson_id = cm.lesson_id
                WHERE l.version_id = dcrpt_version_id
                  AND so.bucket_id = 'course-materials'
                  AND so.name LIKE 'video-materials/%'


                UNION ALL

                SELECT
                    CASE
                        WHEN is_eligible IS TRUE THEN a.ass_id
                        WHEN (check_user_role(ARRAY['faculty', 'dean']) = TRUE) THEN a.ass_id
                    END AS id,
                    a.ass_title AS content_name,
                    NULL AS path,
                    l.lesson_num,
                    l.lesson_name,
                    l.lesson_descr,
                    'assignment' AS content_type,
                    CASE
                        WHEN is_eligible IS TRUE AND l.lesson_num = 0 THEN 'open'
                        WHEN is_eligible IS TRUE
                             AND l.lesson_num > 0
                             AND (SELECT lesson_id
                                  FROM lesson
                                  WHERE lesson_num = (l.lesson_num - 1)
                                    AND version_id = dcrpt_version_id
                                 ) = ANY(get_completed_lessons(progress_user_id, dcrpt_version_id))
                        THEN 'open'
                        ELSE 'locked'
                    END AS security,
                    COALESCE((
                        SELECT
                            jsonb_build_object(
                                'status', sapx.status,
                                'claim_id', encode(
                                        pgp_sym_encrypt(
                                            jsonb_build_object(
                                                'type', 'assignment',
                                                'sap_id',sapx.sap_id
                                            )::text,
                                            internal.get_secret_key('view_course')
                                        ),
                                        'base64'
                                    )::text
                            )
                        FROM student_ass_progress sapx WHERE sapx.ass_id = a.ass_id AND sapx.user_id = (SELECT user_id FROM users WHERE auth_id = auth.uid())
                    ), jsonb_build_object(
                        'status', NULL,
                        'claim_id', NULL
                    )) as claim_details
                FROM assignment a
                INNER JOIN lesson l ON l.lesson_id = a.lesson_id
                WHERE l.version_id = dcrpt_version_id

                UNION ALL

                SELECT
                    CASE
                        WHEN is_eligible IS TRUE THEN t.test_id
                        WHEN (check_user_role(ARRAY['faculty', 'dean']) = TRUE) THEN t.test_id
                    END AS id,
                    t.test_title AS content_name,
                    NULL AS path,
                    l.lesson_num,
                    l.lesson_name,
                    l.lesson_descr,
                    'exam' AS content_type,
                    CASE
                        WHEN is_eligible IS TRUE AND l.lesson_num = 0 THEN 'open'
                        WHEN is_eligible IS TRUE
                             AND l.lesson_num > 0
                             AND (SELECT lesson_id
                                  FROM lesson
                                  WHERE lesson_num = (l.lesson_num - 1)
                                    AND version_id = dcrpt_version_id
                                 ) = ANY(get_completed_lessons(progress_user_id, dcrpt_version_id))
                        THEN 'open'
                        ELSE 'locked'
                    END AS security,
                    COALESCE((
                        SELECT
                            jsonb_build_object(
                                'status', stpx.status,
                                'claim_id', encode(
                                        pgp_sym_encrypt(
                                            jsonb_build_object(
                                                'type', 'exam',
                                                'ut_id',stpx.ut_id
                                            )::text,
                                            internal.get_secret_key('view_course')
                                        ),
                                        'base64'
                                    )::text
                            )
                        FROM student_test_record stpx WHERE stpx.test_id = t.test_id AND stpx.user_id = (SELECT user_id FROM users WHERE auth_id = auth.uid()) order by completed_at desc limit 1
                    ), jsonb_build_object(
                        'status', NULL,
                        'claim_id', NULL
                    )) as claim_details
                FROM test t
                INNER JOIN lesson l ON l.lesson_id = t.lesson_id
                WHERE l.version_id = dcrpt_version_id
            ) AS combined;
        ELSE
            v_lessons := NULL;
        END IF;


        -- trigger deadline unlocked activities
        FOR rec IN
            SELECT
                CASE
                    WHEN is_eligible IS TRUE THEN a.ass_id
                    WHEN (check_user_role(ARRAY['faculty', 'dean']) = TRUE) THEN a.ass_id
                END AS id,
                a.ass_title AS content_name,
                NULL AS path,
                l.lesson_num,
                l.lesson_name,
                l.lesson_descr,
                'assignment' AS content_type,
                CASE
                    WHEN is_eligible IS TRUE AND l.lesson_num = 0 THEN 'open'
                    WHEN is_eligible IS TRUE
                        AND l.lesson_num > 0
                        AND (SELECT lesson_id
                            FROM lesson
                            WHERE lesson_num = (l.lesson_num - 1)
                            AND version_id = dcrpt_version_id
                            ) = ANY(get_completed_lessons(progress_user_id, dcrpt_version_id))
                    THEN 'open'
                    ELSE 'locked'
                END AS security
            FROM assignment a
            INNER JOIN lesson l ON l.lesson_id = a.lesson_id
            WHERE l.version_id = dcrpt_version_id
        LOOP
            IF rec.security = 'open' THEN
                CALL unlock_assignment(rec.id);
            END IF;
        END LOOP;


        -------------------------------------------------------------------
        -- REVIEWS SECTION
        -------------------------------------------------------------------

        -- CHECK IS THIS COURSE HAS AT LEAST 5 RATINGS
        IF EXISTS (
           SELECT 1
           FROM my_courses
           WHERE version_id = dcrpt_version_id
           GROUP BY version_id
           HAVING COUNT(rating) >= 1
        ) THEN
           -- summary
            SELECT jsonb_build_object(
                       'star', COALESCE(AVG(rating)::numeric(4,2),0),  -- raw average, no rounding as requested
                       'total_ratings', CASE WHEN COUNT(rating) > 1 THEN CONCAT(COUNT(rating), ' Ratings') ELSE CONCAT(COALESCE(COUNT(rating),0), ' Rating') END,
                       'total_reviews', CASE WHEN COUNT(review) > 1 THEN CONCAT(COUNT(review), ' Reviews') ELSE CONCAT(COALESCE(COUNT(review),0), ' Review') END
                   )
            INTO section1_a
            FROM my_courses
            WHERE rating IS NOT NULL
              AND version_id = dcrpt_version_id;

            WITH ratings AS (
                -- All possible rating values (static)
                SELECT g AS stars
                FROM generate_series(5, 1, -1) g
            ),
            counts AS (
                -- Count ratings per value
                SELECT rating, COUNT(*) AS cnt
                FROM my_courses
                WHERE version_id = dcrpt_version_id
                GROUP BY rating
            ),
            total AS (
                -- Get total number of ratings
                SELECT COUNT(*) AS total_cnt
                FROM my_courses
                WHERE version_id = dcrpt_version_id
            )
            SELECT jsonb_agg(
                       jsonb_build_object(
                           'star_order', r.stars,
                           'star_count', COALESCE(c.cnt, 0),
                           'star_percentage',
                               CASE
                                   WHEN t.total_cnt = 0 THEN 0
                                   ELSE ROUND((COALESCE(c.cnt, 0) * 100.0 / t.total_cnt), 2)
                               END
                       )
                       ORDER BY r.stars DESC  -- 👈 must be inside jsonb_agg
                   )
            INTO section1_b
            FROM ratings r
            LEFT JOIN counts c ON r.stars = c.rating
            CROSS JOIN total t;

            ratings := jsonb_build_object(
                'section1', section1_a,
                'section2', COALESCE(section1_b, '[]'::jsonb)
            );

            IF (
               SELECT COUNT(review)
               FROM my_courses
               WHERE version_id = dcrpt_version_id
                 AND rating IS NOT NULL
            ) >= 1 THEN

                SELECT jsonb_agg(
                           jsonb_build_object(
                                'review_id', encode(
                                                pgp_sym_encrypt(mc.enrollee_id::text, internal.get_secret_key('view_course')),
                                                'base64'
                                            )::text,
                                'avatar', COALESCE(o.name,
                                                  (SELECT name
                                                   FROM storage.objects
                                                   WHERE bucket_id = 'profile-photo'
                                                     AND owner IS NULL
                                                   ORDER BY random() LIMIT 1))::text,
                                'anon_name', ('Student' || MOD(u.user_id * 7919, 10000))::text,
                                'rating', mc.rating::int,
                                'review', COALESCE(mc.review::text, ''),
                                'date', TO_CHAR(mc.review_timestamp, 'MM/DD/YYYY')::text,
                                'likes', COALESCE(rl.likes, 0)::int,
                                'dislikes', COALESCE(rl.dislikes, 0)::int,
                                'react_indicator',
                                   CASE
                                       WHEN ur.reaction = 'like' THEN true
                                       WHEN ur.reaction = 'dislike' THEN false
                                       ELSE NULL  -- no reaction
                                   END,
                                'is_owner', CASE
                                                WHEN mc.user_id = (SELECT user_id FROM users WHERE auth_id = auth.uid()) THEN TRUE
                                                ELSE FALSE
                                            END
                           ) ORDER BY mc.review_timestamp DESC
                       ) INTO user_reviews
                FROM my_courses mc
                INNER JOIN internal.users u ON u.user_id = mc.user_id
                LEFT JOIN storage.objects o ON o.id = u.profile_id

                -- aggregate like/dislike counts
                LEFT JOIN LATERAL (
                    SELECT COUNT(*) FILTER (WHERE reaction = 'like') AS likes,
                           COUNT(*) FILTER (WHERE reaction = 'dislike') AS dislikes
                    FROM internal.review_likes rl
                    WHERE rl.enrollee_id = mc.enrollee_id
                ) rl ON TRUE

                -- specific current user's reaction
                LEFT JOIN internal.review_likes ur
                       ON ur.enrollee_id = mc.enrollee_id
                      AND ur.user_liker_id = (
                          SELECT user_id
                          FROM users u
                              inner join auth.users a on a.id = u.auth_id
                          where u.auth_id = auth.uid()
                               )
                WHERE mc.version_id = dcrpt_version_id
                  AND ((mc.rating IS NOT NULL AND mc.review IS NULL) OR ((mc.rating IS NOT NULL AND mc.review IS NOT NULL)));

            ELSE
                user_reviews := null;
            END IF;

            v_reviews := jsonb_build_object(
                'ratings', ratings,
                'user_reviews', user_reviews
            );
        ELSE
            v_reviews := NULL;
        END IF;



        -------------------------------------------------------------------
        -- MORE SECTION
        -------------------------------------------------------------------
        -- CHECKS IF THERE ARE RESOURCES
        IF EXISTS (
            SELECT 1
            FROM course_material cm
            INNER JOIN lesson l ON l.lesson_id = cm.lesson_id
            INNER JOIN storage.objects o ON o.id = cm.material
            WHERE l.version_id = dcrpt_version_id
              AND o.name NOT like 'other-resources/%.mp4'
        ) THEN
            SELECT jsonb_agg(
                       jsonb_build_object(
                           'resource_id', encode(
                                            pgp_sym_encrypt(cm.material_id::TEXT, internal.get_secret_key('view_course')),
                                            'base64'
                                        )::text,
                           'content_name', cm.material_name::text,
                           'path',  CASE
                                        WHEN is_eligible IS TRUE THEN so.name
                                        WHEN (check_user_role(ARRAY['faculty']) = TRUE) THEN so.name
                                    END::text,
                           'lesson_name', l.lesson_name::text,
                           'content_type', 'file_resources',
                           'security', CASE WHEN is_eligible IS TRUE THEN 'open' ELSE 'locked' END
                       ) ORDER BY l.lesson_num
                   ) INTO resources
            FROM course_material cm
            INNER JOIN storage.objects so ON so.id = cm.material
            INNER JOIN lesson l ON l.lesson_id = cm.lesson_id
            WHERE l.version_id = dcrpt_version_id
              AND so.bucket_id = 'course-materials'
              AND so.name LIKE 'other-resources/%'
              AND so.name NOT LIKE '%.mp4';

            SELECT
                jsonb_build_object(
                           'resource_id', encode(
                                            pgp_sym_encrypt(o.id::TEXT, internal.get_secret_key('view_course')),
                                            'base64'
                                        )::text,
                           'content_name', 'Course Syllabus',
                           'path',  CASE
                                        WHEN is_eligible IS TRUE THEN o.name
                                        WHEN (check_user_role(ARRAY['faculty']) = TRUE) THEN o.name
                                    END::text,
                           'lesson_name', 'Course Syllabus',
                           'content_type', 'file_resources',
                           'security', CASE WHEN is_eligible IS TRUE THEN 'open' ELSE 'locked' END
                       ) INTO v_syllabus
            FROM course_version cv
            INNER JOIN storage.objects o on o.id = cv.syllabus_id
            WHERE version_id = dcrpt_version_id;

            resources = resources || COALESCE(v_syllabus, '[]'::jsonb);


            SELECT jsonb_agg(
                       jsonb_build_object(
                           'resource_id', encode(
                                            pgp_sym_encrypt(cm.material_id::TEXT, internal.get_secret_key('view_course')),
                                            'base64'
                                        )::text,
                           'content_name', cm.link::text,
                           'path',  null,
                           'lesson_name', l.lesson_name::text,
                           'content_type', 'url_resources',
                           'security', CASE WHEN is_eligible IS TRUE THEN 'open' ELSE 'locked' END
                       ) ORDER BY l.lesson_num
                   ) INTO v_urls
            FROM course_material cm
            INNER JOIN lesson l ON l.lesson_id = cm.lesson_id
            WHERE l.version_id = dcrpt_version_id
              AND cm.link IS NOT NULL;

            resources = resources || COALESCE(v_urls, '[]'::jsonb);

        ELSE
            resources := NULL;
        END IF;



        --- CERTIFICATION & RATING (note certificate_id is TEXT because it's encoded)
        SELECT DISTINCT ON (mc.version_id)
            encode(
                pgp_sym_encrypt(mc.enrollee_id::text, internal.get_secret_key('view_course')),
                'base64'
            )::TEXT,
            CONCAT('Certificate of Completion for ', c.crs_title)::text
        INTO certificate_id, certificate_name
        FROM my_courses mc
        INNER JOIN internal.prospectus_course pc ON pc.pc_id = mc.version_id
        INNER JOIN internal.course c ON c.crs_id = pc.crs_id
        WHERE mc.version_id = dcrpt_version_id AND mc.user_id = (SELECT user_id FROM users WHERE auth_id = auth.uid());

        certificattion := jsonb_build_object(
            'certificate_id', CASE WHEN is_eligible IS TRUE THEN certificate_id END,
            'certificate_name', certificate_name
        );

        v_more := jsonb_build_object(
            'certificate', certificattion,
            'resources', resources,
            'rating_id', CASE WHEN is_eligible IS TRUE THEN certificate_id END,
            'withdraw_id', CASE WHEN is_eligible IS TRUE THEN certificate_id END,
            'leaderboards_id', encode(
                                    pgp_sym_encrypt(dcrpt_version_id::text, internal.get_secret_key('view_course')),
                                    'base64'
                                )::TEXT
        );


        -------------------------------------------------------------------
        -- FINAL RETURN
        -------------------------------------------------------------------
        RETURN jsonb_build_object(
            'more', v_more,
            'reviews', v_reviews,
            'lessons', v_lessons,
            'about', v_about,
            'header', v_header
        );

        ELSE
            RETURN NULL;
        END IF;
    ELSE
        RAISE EXCEPTION 'This course is not yet available.'
            USING ERRCODE = 'P0066';
    END IF;
END;
$$; -- NEW
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION internal.view_course(IN p_my_course_id TEXT) FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION internal.view_course(IN p_my_course_id TEXT) TO authenticated;


--- 3.1) trigger deadline in when activity is unlocked

CREATE OR REPLACE PROCEDURE internal.unlock_assignment(IN p_ass_id INT)
SET search_path = internal
AS $$
DECLARE
    f_sap_id INT := null;

    act_sender INT;
    act_recipient INT;
    act_version_id INT;
    msg TEXT;

    deadline TIMESTAMPTZ := NULL;
    student_id INT := NULL;
BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['student'])) = TRUE THEN

        -- decrypt special_id
--         BEGIN
--             dcrpt_ass_id := pgp_sym_decrypt(
--                 decode(p_assignment_id, 'base64'),
--                 get_secret_key('view_assignment') -- if screen from enrolled courses
--             )::INT;
--         EXCEPTION
--             WHEN OTHERS THEN
--                 RAISE EXCEPTION 'Valid Assignment ID is required.'
--                 USING ERRCODE = 'P0043';
--         END;

        student_id := (SELECT user_id FROM users WHERE auth_id = auth.uid());

        -- CHECK FIRST IF THIS STUDENT IS ENROLLED IN THIS COURSE
        IF EXISTS (
            SELECT 1
            FROM my_courses mc
            INNER JOIN internal.users u2 on u2.user_id = mc.user_id
            WHERE mc.version_id = (SELECT l2.version_id FROM assignment a INNER JOIN internal.lesson l2 on l2.lesson_id = a.lesson_id WHERE a.ass_id = p_ass_id)
            AND u2.auth_id = auth.uid()
        ) THEN

            -- CHECK IF THIS ASSIGNMENT IS ALREADY In RECORD. [WHEN THEY ALREADY SUBMITTED BEFORE BUT UNSUBMITTED]
            IF NOT EXISTS(
                SELECT 1
                FROM student_ass_progress
                    INNER JOIN internal.users u on u.user_id = student_ass_progress.user_id
                WHERE ass_id = p_ass_id AND u.auth_id = auth.uid()
            ) THEN
                -- COMPLETE THE STUDENT ASSIGNMENT
                INSERT INTO student_ass_progress (ass_id, user_id) -- YELLOW LINES BECAUSE OF THE CTUPIA XP BUT ITS ALREADY AUTO GENERATED THRU TRIGGER
                VALUES (p_ass_id, student_id)
                RETURNING sap_id INTO f_sap_id;

            end if;

            IF f_sap_id IS NOT NULL THEN
                IF EXISTS(
                    SELECT 1 FROM assignment WHERE relative_offset IS NOT NULL AND ass_id = p_ass_id
                ) THEN
                    deadline := (
                        SELECT (sap.date_unlocked + a2.relative_offset)
                        FROM student_ass_progress sap
                        INNER JOIN internal.assignment a2 ON sap.ass_id = a2.ass_id
                        WHERE sap.user_id = student_id AND a2.ass_id = p_ass_id
                    );

                    act_version_id := (SELECT l2.version_id FROM assignment a INNER JOIN internal.lesson l2 on l2.lesson_id = a.lesson_id WHERE a.ass_id = p_ass_id);
                    act_sender := (SELECT user_id FROM users WHERE auth_id = auth.uid());
                    act_recipient := (SELECT user_id FROM course_version_faculty WHERE version_id = act_version_id );

                    -- catch when the deadline could be greater than the end date of semester

                    msg := format(
                        'Hello %s, this is a reminder that you have an upcoming assignment/activity titled "%s" in %s. Please be informed that the deadline is on %s.',
                        (SELECT fname FROM users WHERE auth_id = auth.uid()),
                        (SELECT ass_title FROM assignment WHERE ass_id = p_ass_id),
                        (SELECT c.crs_title FROM prospectus_course pc INNER JOIN internal.course c ON c.crs_id = pc.crs_id WHERE pc.pc_id = act_version_id),
                        to_char(deadline AT TIME ZONE 'Asia/Manila',
                            'Month DD, YYYY HH12:MI AM')

                    );

                    INSERT INTO course_activity (sender_id, recipient_id, version_id, type, metadata, message)
                                VALUES (
                                    act_recipient, -- FACULTY IS THE SENDER
                                    act_sender, -- STUDENT IS THE RECEIVER
                                    act_version_id,
                                    'upcoming-assignment',
                                    jsonb_build_object(
                                        'visibility', jsonb_build_array('analytics', 'notification'),
                                        'assignment_id', p_ass_id,
                                        'course_completion_rate', get_progress(act_sender, act_version_id)
                                    ),
                                msg
                                );
                end if;
            end if;

        ELSE
            -- MEANS THAT  THEY'RE NOT ENROLLED
            -- DO NOTHING
        end if;

    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
REVOKE ALL ON PROCEDURE internal.unlock_assignment(IN p_ass_id INT) FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE internal.unlock_assignment(IN p_ass_id INT) TO authenticated;


-- 4.) View Faculty's Profile

CREATE OR REPLACE FUNCTION internal.view_faculty_profile(IN p_faculty_id TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    dcrpt_faculty_id INT;
    header_section JSONB;
    my_courses JSONB;

BEGIN

    BEGIN
        dcrpt_faculty_id := pgp_sym_decrypt(
            decode(p_faculty_id, 'base64'),
            get_secret_key('view_course')
        )::INT;
    EXCEPTION
        WHEN OTHERS THEN
            BEGIN
                dcrpt_faculty_id := pgp_sym_decrypt(
                    decode(p_faculty_id, 'base64'),
                    get_secret_key('view_program')
                )::INT;
            EXCEPTION
                WHEN OTHERS THEN
                    RAISE EXCEPTION 'Valid "Faculty ID" Required.'
                        USING ERRCODE = 'P0043';
            END;
    END;

    -- Only run main query if key exists and confirm the user role
    IF (
        (SELECT check_user_role(ARRAY['student'])) = TRUE
        AND internal.get_secret_key('view_faculty_profile') IS NOT NULL
    ) THEN

        -------------------------------------------------------------------
        -- HEADER SECTION (faculty)
        -------------------------------------------------------------------
        SELECT jsonb_build_object(
                   'faculty_id', encode(pgp_sym_encrypt(u2.user_id::TEXT, internal.get_secret_key('view_course')),'base64')::text,
                   'faculty_avatar', o.name::text,
                   'faculty_name', CONCAT(u2.fname,' ', COALESCE(u2.mname, ''), ' ', u2.lname)::text,
                   'total_students', COALESCE(COUNT(DISTINCT mc.user_id) FILTER ( WHERE cv.apvd_rvwd_by IS NOT NULL AND cv.is_ready IS TRUE ),0)::INT,
                   'total_courses', COALESCE(COUNT(DISTINCT cvf.version_id) FILTER ( WHERE cv.apvd_rvwd_by IS NOT NULL AND cv.is_ready IS TRUE ),0),
                   'rating', CASE
                                 WHEN COUNT(mc.rating) FILTER (WHERE mc.rating IS NOT NULL AND cv.apvd_rvwd_by IS NOT NULL AND cv.is_ready IS TRUE) >= 5
                                 THEN CONCAT('⭐  ', ROUND(AVG(mc.rating)::numeric, 2))  -- only 2 decimals
                                 ELSE '⭐  0'
                             END,
                   'rank', case
                                when fr.rank_level > 0 then concat(f.faculty_title, ' ',fr.rank_level)
                                else f.faculty_title::text
                            end,
                    'total_reviews', CASE
                                        WHEN COUNT(mc.review) FILTER (WHERE mc.review IS NOT NULL AND cv.apvd_rvwd_by IS NOT NULL AND cv.is_ready IS TRUE) >= 5
                                        THEN COUNT(mc.review)::int  -- only 2 decimals
                                        ELSE 0
                                    END,
                    'bio', u2.bio,
                    'email', au.email::text
               )
        INTO header_section
        FROM users u2
        inner join auth.users au on au.id = u2.auth_id
        INNER JOIN faculty_rank fr ON u2.rank_id = fr.rank_id
            inner join faculty f ON f.faculty_id = fr.faculty_id
        inner join storage.objects o on o.id = u2.profile_id
        LEFT JOIN internal.course_version_faculty cvf ON cvf.user_id = u2.user_id
            LEFT JOIN internal.my_courses mc ON mc.version_id = cvf.version_id
            LEFT JOIN internal.course_version cv on cv.version_id = cvf.version_id
        WHERE u2.user_id = dcrpt_faculty_id
        GROUP BY u2.user_id, o.name, fr.rank_level, f.faculty_title, au.email;



        SELECT jsonb_agg(
                   jsonb_build_object(
                       'course_id', encode(pgp_sym_encrypt(cvf.version_id::TEXT, internal.get_secret_key('view_faculty_profile')),'base64')::TEXT,
                       'course_code', pc.crs_code::TEXT,
                       'course_title', c.crs_title::TEXT,
                       'semester', s.sem_name::TEXT,
                       'year', p.year::text,
                       'wallpaper', o.name
                   )
               )
        INTO my_courses
        FROM course_version_faculty cvf
        INNER JOIN internal.course_version cv ON cv.version_id = cvf.version_id
            LEFT JOIN storage.objects o on o.id = cv.wallpaper_id
        INNER JOIN internal.prospectus_course pc ON pc.pc_id = cv.version_id
        INNER JOIN internal.prospectus p ON pc.prospectus_id = p.prospectus_id
        INNER JOIN internal.course c ON pc.crs_id = c.crs_id
        INNER JOIN internal.prospectus_semester ps ON ps.prosem_id = pc.prosem_id
        INNER JOIN internal.semester s ON s.sem_id = ps.sem_id
        WHERE cvf.user_id = dcrpt_faculty_id AND cv.apvd_rvwd_by IS NOT NULL AND cv.is_ready IS TRUE;



        -------------------------------------------------------------------
        -- FINAL RETURN
        -------------------------------------------------------------------
        RETURN jsonb_build_object(
            'my_courses', my_courses,
            'header', header_section
        );
    END IF;

    -- If guard fails, return NULL (or you can return an error json)
    RETURN NULL;
END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION internal.view_faculty_profile(IN p_faculty_id TEXT) FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION internal.view_faculty_profile(IN p_faculty_id TEXT) TO authenticated;


-- 5.) RECORD WATCH VIDEO PROGRESS

CREATE OR REPLACE PROCEDURE internal.track_progress(
    IN p_video_id TEXT,
    IN p_time_stamp INTERVAL
)
SET search_path = internal
AS $$
DECLARE
    dcrpt_video_id INT;

    act_progress_percentage INT := NULL;
    act_video_duration INTERVAL := NULL;
    rows_updated INT := NULL;
    act_sender INT;
    act_recipient INT;
    act_version_id INT;
    msg TEXT;
BEGIN

    -- confirm user role
    IF (SELECT check_user_role(ARRAY['student'])) = FALSE THEN
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    END IF;

    -- check if video is not null
    IF p_video_id IS NOT NULL THEN

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

        -- CHECK IF THIS USER IS ENROLLED IN THIS COURSE
        IF EXISTS (
            SELECT 1
            FROM my_courses mc
            INNER JOIN internal.users u on u.user_id = mc.user_id
            WHERE u.auth_id = auth.uid()
              AND mc.version_id = (
                  SELECT l.version_id
                  FROM course_material cm
                  INNER JOIN internal.lesson l on l.lesson_id = cm.lesson_id
                  WHERE cm.material_id = dcrpt_video_id
                )
        ) THEN
            act_sender := (SELECT user_id FROM users WHERE auth_id = auth.uid());

            SELECT l2.version_id, cm.video_duration INTO act_version_id, act_video_duration
            FROM course_material cm
                INNER JOIN internal.lesson l2 on l2.lesson_id = cm.lesson_id
            WHERE cm.material_id = dcrpt_video_id;

            act_progress_percentage = COALESCE(ROUND(
                    (EXTRACT(EPOCH FROM p_time_stamp::INTERVAL) / EXTRACT(EPOCH FROM act_video_duration::interval)) * 100
                ), 0);

            -- CHECK IF USER ALREADY UNLOCKED THE PREREQUISITE VIDEO
            -- PENDING

            -- IF ENTRY ALREADY EXISTED
            IF EXISTS(
                SELECT 1
                FROM student_cm_progress cm
                INNER JOIN internal.users u2 on u2.user_id = cm.user_id
                WHERE cm.material_id = dcrpt_video_id
                  AND u2.auth_id = auth.uid()
            ) THEN
                -- update progress
                UPDATE student_cm_progress
                SET last_record_time = p_time_stamp::INTERVAL
                WHERE user_id = act_sender
                AND material_id = dcrpt_video_id
                AND p_time_stamp::INTERVAL > last_record_time;

                GET DIAGNOSTICS rows_updated = ROW_COUNT;

                IF rows_updated > 0 THEN
                    INSERT INTO course_activity (sender_id, version_id, type, metadata)
                        VALUES (
                            act_sender,
                            act_version_id,
                            'video-watched',
                            jsonb_build_object(
                                'visibility', jsonb_build_array('analytics'),
                                'material_id', dcrpt_video_id,
                                'progress', 'in_progress',
                                'duration_watched', p_time_stamp::TEXT,
                                'percentage_completed', act_progress_percentage,
                                'course_completion_rate', get_progress(act_sender, act_version_id)
                            )
                        );
                end if;

            ELSE
                INSERT INTO student_cm_progress (material_id, last_record_time)
                VALUES (dcrpt_video_id, p_time_stamp::INTERVAL);

                GET DIAGNOSTICS rows_updated = ROW_COUNT;

                IF rows_updated > 0 THEN

                    act_recipient := (SELECT user_id FROM course_version_faculty WHERE version_id = act_version_id );
                    msg := format(
                        'Good news! %s just began watching %s in your course %s.',
                        (SELECT CONCAT(lname, ', ', fname, ' ', COALESCE(mname, '')) FROM users WHERE auth_id = auth.uid()),
                        (SELECT material_name FROM course_material WHERE material_id = dcrpt_video_id),
                        (SELECT c.crs_title FROM prospectus_course pc INNER JOIN internal.course c ON c.crs_id = pc.crs_id WHERE pc.pc_id = act_version_id)

                    );

                    INSERT INTO course_activity (sender_id, recipient_id, version_id, type, metadata, message)
                        VALUES (
                            act_sender,
                            act_recipient,
                            act_version_id,
                            'video-watched',
                            jsonb_build_object(
                                'visibility', jsonb_build_array('analytics', 'notification'),
                                'material_id', dcrpt_video_id,
                                'progress', 'started',
                                'duration_watched', p_time_stamp::TEXT,
                                'percentage_completed', act_progress_percentage,
                                'course_completion_rate', get_progress(act_sender, act_version_id)
                            ),
                        msg
                    );
                end if;

            end if;

        end if;

    end if;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
REVOKE ALL ON PROCEDURE internal.track_progress(
    IN p_video_id TEXT,
    IN p_time_stamp INTERVAL
) FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE internal.track_progress(
    IN p_video_id TEXT,
    IN p_time_stamp INTERVAL
) TO authenticated;


-- 5.1) GET LAST TIMESTAMP

CREATE OR REPLACE FUNCTION internal.get_last_progress(IN p_video_id TEXT)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    dcrpt_video_id INT;
BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['student'])) = FALSE THEN
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    END IF;

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

        -- CHECK IF THIS USER IS ENROLLED IN THIS COURSE
    IF EXISTS (
        SELECT 1
        FROM my_courses mc
        INNER JOIN internal.users u on u.user_id = mc.user_id
        WHERE u.auth_id = auth.uid()
            AND mc.version_id = (
                SELECT l.version_id
                FROM course_material cm
                INNER JOIN internal.lesson l on l.lesson_id = cm.lesson_id
                WHERE cm.material_id = dcrpt_video_id
            )
    ) THEN

        RETURN (SELECT COALESCE(last_record_time, '00:00:00') FROM student_cm_progress where material_id = dcrpt_video_id and user_id = (SELECT user_id FROM users WHERE auth_id = auth.uid()));


    ELSE
        RETURN '00:00:00';
    end if;
END;
$$;
REVOKE ALL ON FUNCTION internal.get_last_progress(IN p_video_id TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION internal.get_last_progress(IN p_video_id TEXT) TO authenticated;


-- 6.) View Assignment

CREATE OR REPLACE FUNCTION internal.view_assignment(IN p_assignment_id TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    dcrpt_ass_id INT;
    assignment_details JSONB;
    faculty_attachments JSONB;
    student_attachments_file JSONB;
    student_attachments_url JSONB;
BEGIN
    -- decrypt special_id
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

    -- CHECKS IF THIS COURSE IS ALREADY PUBLISHED
    IF EXISTS (
        SELECT 1
        FROM course_version
        WHERE version_id = (
                SELECT l.version_id
                  FROM assignment ass
                  INNER JOIN internal.lesson l on l.lesson_id = ass.lesson_id
                  WHERE ass.ass_id = dcrpt_ass_id
            )
          AND is_ready IS TRUE AND apvd_rvwd_by IS NOT NULL
    ) THEN

        -- CHECK USER REQUIREMENTS
        IF (
            (SELECT check_user_role(ARRAY['student'])) = TRUE
        ) THEN

        -- ABOUT THE ASSIGNMENT
        SELECT
            jsonb_build_object(
            'assignment_id', encode(pgp_sym_encrypt(aa.ass_id::TEXT, internal.get_secret_key('view_assignment')),'base64')::text,
            'lesson_title', l.lesson_name::TEXT,
            'submission_status',
            (
                SELECT
                    CASE
                        WHEN sap.completed_at IS NOT NULL THEN TRUE
                        ELSE FALSE
                    END
                FROM student_ass_progress sap
                WHERE sap.ass_id = aa.ass_id AND sap.user_id = (SELECT user_id FROM users WHERE auth_id = auth.uid())
            ),
            'assignment_title', aa.ass_title::TEXT,
            'total_points', aa.total_points::TEXT,
            'mark',
            COALESCE((
                SELECT
                    CASE
                        WHEN sap.completed_at IS NOT NULL AND sap.eval_points IS NULL THEN 'Pending Evaluation'
                        WHEN sap.completed_at IS NOT NULL AND sap.eval_points IS NOT NULL THEN sap.eval_points::TEXT
                        ELSE 'Not Submitted'
                    END
                FROM student_ass_progress sap
                WHERE sap.ass_id = aa.ass_id AND sap.user_id = (SELECT user_id FROM users WHERE auth_id = auth.uid())
            ),'Not Submitted'),
            'claim_status',
            (
                SELECT
                    sap.status
                FROM student_ass_progress sap
                WHERE sap.ass_id = aa.ass_id AND sap.user_id = (SELECT user_id FROM users WHERE auth_id = auth.uid())
            ),
            'description', aa.descr::TEXT,
            'due_date', CASE
                            WHEN aa.relative_offset IS NOT NULL
                                THEN (
                                        SELECT to_char((sap.date_unlocked + a2.relative_offset), 'Month DD, YYYY HH12:MI AM')
                                        FROM student_ass_progress sap
                                        INNER JOIN internal.assignment a2 ON sap.ass_id = a2.ass_id
                                        WHERE sap.user_id = (SELECT user_id FROM users WHERE auth_id = auth.uid()) AND a2.ass_id = dcrpt_ass_id
                                    )
                        END
            ) INTO assignment_details
        FROM assignment aa
        INNER JOIN lesson l ON l.lesson_id = aa.lesson_id
        WHERE aa.ass_id = dcrpt_ass_id;

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
        WHERE at.ass_id = dcrpt_ass_id;

        -- STUDENT ATTACHMENT DURING TURNING IN
        SELECT
            json_agg(
                jsonb_build_object(
                    'my_attachment_id', encode(pgp_sym_encrypt(at.saa_id::TEXT, internal.get_secret_key('view_assignment')),'base64')::text,
                    'my_attachment_name', regexp_replace(o.name::text, '^.*/', ''),
                    'my_attachment_path', o.name::TEXT
                )
            ) INTO student_attachments_file
        FROM student_ass_attachment at
        INNER JOIN storage.objects o ON o.id = at.file_id
        INNER JOIN internal.student_ass_progress s on at.sap_id = s.sap_id
        INNER JOIN internal.users u on u.user_id = s.user_id
        WHERE s.ass_id = dcrpt_ass_id
          AND u.auth_id = auth.uid()
          AND at.file_id IS NOT NULL;

        SELECT
            json_agg(
                jsonb_build_object(
                    'my_attachment_id', encode(pgp_sym_encrypt(at.saa_id::TEXT, internal.get_secret_key('view_assignment')),'base64')::text,
                    'my_attachment_url', at.url::text
                )
            ) INTO student_attachments_url
        FROM student_ass_attachment at
        INNER JOIN internal.student_ass_progress s on at.sap_id = s.sap_id
        INNER JOIN internal.users u on u.user_id = s.user_id
        WHERE s.ass_id = dcrpt_ass_id
          AND u.auth_id = auth.uid()
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

        ELSE
            RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
        END IF;
    ELSE
        -- If guard fails, return NULL (or you can return an error json)
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    END IF;
END;
$$; -- NEW
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION internal.view_assignment(IN p_assignment_id TEXT) FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION internal.view_assignment(IN p_assignment_id TEXT) TO authenticated;


-- 6.2 Submit Assignment

CREATE OR REPLACE PROCEDURE internal.submit_assignment(
    IN p_assignment_id TEXT,
    IN p_files UUID[],
    IN p_links TEXT[]
)
SET search_path = internal
AS $$
DECLARE
    dcrpt_ass_id INT;
    attachment UUID;
    link TEXT;
    object_id UUID;
    f_sap_id INT;

    act_sender INT;
    act_recipient INT;
    act_version_id INT;
    msg TEXT;
BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['student'])) = FALSE THEN
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    END IF;

    -- decrypt special_id
    BEGIN
        dcrpt_ass_id := pgp_sym_decrypt(
            decode(p_assignment_id, 'base64'),
            get_secret_key('view_assignment') -- if screen from enrolled courses
        )::INT;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Valid Assignment ID is required.'
            USING ERRCODE = 'P0043';
    END;

    -- CHECK FIRST IF THIS STUDENT IS ENROLLED IN THIS COURSE
    IF EXISTS (
        SELECT 1
        FROM my_courses mc
        INNER JOIN internal.users u2 on u2.user_id = mc.user_id
        WHERE mc.version_id = (SELECT l2.version_id FROM assignment a INNER JOIN internal.lesson l2 on l2.lesson_id = a.lesson_id WHERE a.ass_id = dcrpt_ass_id)
        AND u2.auth_id = auth.uid()
    ) THEN

        -- CHECK IF THIS ASSIGNMENT IS ALREADY In RECORD. [WHEN THEY ALREADY SUBMITTED BEFORE BUT UNSUBMITTED]
        IF EXISTS(
            SELECT 1
            FROM student_ass_progress
                INNER JOIN internal.users u on u.user_id = student_ass_progress.user_id
            WHERE ass_id = dcrpt_ass_id AND u.auth_id = auth.uid()
        ) THEN
            -- IF THEY UNSUBMITTED
            UPDATE student_ass_progress
            SET completed_at = NOW()
            WHERE ass_id = dcrpt_ass_id AND user_id = (SELECT user_id FROM users WHERE auth_id = auth.uid())
            RETURNING sap_id INTO f_sap_id;

        ELSE
            -- COMPLETE THE STUDENT ASSIGNMENT
            INSERT INTO student_ass_progress (ass_id, user_id, completed_at) -- YELLOW LINES BECAUSE OF THE CTUPIA XP BUT ITS ALREADY AUTO GENERATED THRU TRIGGER
            VALUES (dcrpt_ass_id, (SELECT user_id FROM users WHERE auth_id = auth.uid()), now())
            RETURNING sap_id INTO f_sap_id;

        end if;

        -- ATTACH FILES IF THERE ARE
        IF p_files IS NOT NULL OR array_length(p_files, 1) != 0 THEN
            FOREACH attachment IN ARRAY p_files LOOP

                SELECT id INTO object_id
                FROM STORAGE.OBJECTS
                WHERE bucket_id = 'student-resources'
                AND  name like CONCAT('course-assignment-attachments/', attachment ,'%')
                and owner = auth.uid();

                IF object_id IS NULL THEN
                    RAISE EXCEPTION 'This attachment doesn''t exists'
                        USING ERRCODE = 'P0043';
                end if;


                INSERT INTO student_ass_attachment (sap_id, file_id)
                VALUES (f_sap_id, object_id);

            END LOOP;
        END IF;

        -- ATTACH LINKS IF THERE ARE
        IF p_links IS NOT NULL OR array_length(p_links, 1) != 0 THEN
            FOREACH link IN ARRAY p_links LOOP

                IF link ~ '^https?://[a-zA-Z0-9.-]+(:[0-9]+)?(/.*)?$' THEN
                    INSERT INTO student_ass_attachment (sap_id, url)
                    VALUES (f_sap_id, link);
                ELSE
                    RAISE EXCEPTION 'Invalid Url. PLease try again.'
                    USING ERRCODE = 'P0043';
                end if;

            END LOOP;
        END IF;

        IF f_sap_id IS NOT NULL THEN

            act_version_id := (SELECT l2.version_id FROM assignment a INNER JOIN internal.lesson l2 on l2.lesson_id = a.lesson_id WHERE a.ass_id = dcrpt_ass_id);
            act_sender := (SELECT user_id FROM users WHERE auth_id = auth.uid());
            act_recipient := (SELECT user_id FROM course_version_faculty WHERE version_id = act_version_id );
            msg := format(
                'Student %s submitted an assignment/work "%s" in %s',
                (SELECT CONCAT(lname, ', ', fname, ' ', COALESCE(mname, '')) FROM users WHERE auth_id = auth.uid()),
                (SELECT ass_title FROM assignment WHERE ass_id = dcrpt_ass_id),
                (SELECT c.crs_title FROM prospectus_course pc INNER JOIN internal.course c ON c.crs_id = pc.crs_id WHERE pc.pc_id = act_version_id)
            );

            INSERT INTO course_activity (sender_id, recipient_id, version_id, type, metadata, message)
                        VALUES (
                            act_sender,
                            act_recipient,
                            act_version_id,
                            'submit-assignment',
                            jsonb_build_object(
                                'visibility', jsonb_build_array('analytics', 'notification'),
                                'assignment_id', dcrpt_ass_id,
                                'file_attachments', coalesce(array_length(p_files, 1),0),
                                'link_attachments', coalesce(array_length(p_links, 1),0),
                                'course_completion_rate', get_progress(act_sender, act_version_id)
                            ),
                        msg
                        );


        end if;

    ELSE
        -- MEANS THAT  THEY'RE NOT ENROLLED
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    end if;


END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
REVOKE ALL ON PROCEDURE internal.submit_assignment(
    IN p_assignment_id TEXT,
    IN p_files UUID[],
    IN p_links TEXT[]
) FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE internal.submit_assignment(
    IN p_assignment_id TEXT,
    IN p_files UUID[],
    IN p_links TEXT[]
) TO authenticated;

-- 6.3) Unsubmit work

CREATE OR REPLACE PROCEDURE internal.unsubmit_work(
    IN p_assignment_id TEXT
)
SET search_path = internal
AS $$
DECLARE
    dcrpt_ass_id INT;
    returned_sap_id INT;

    act_sender INT;
    act_recipient INT;
    act_version_id INT;
    msg TEXT;
BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['student'])) = FALSE THEN
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    END IF;

    -- decrypt special_id
    BEGIN
        dcrpt_ass_id := pgp_sym_decrypt(
            decode(p_assignment_id, 'base64'),
            get_secret_key('view_assignment') -- if screen from enrolled courses
        )::INT;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Valid Assignment ID is required.'
            USING ERRCODE = 'P0043';
    END;

    -- CHECK FIRST IF THIS STUDENT IS ENROLLED IN THIS COURSE
    IF EXISTS (
        SELECT 1
        FROM my_courses mc
        INNER JOIN internal.users u2 on u2.user_id = mc.user_id
        WHERE mc.version_id = (SELECT l2.version_id FROM assignment a INNER JOIN internal.lesson l2 on l2.lesson_id = a.lesson_id WHERE a.ass_id = dcrpt_ass_id)
        AND u2.auth_id = auth.uid()
    ) THEN

        -- CHECK IF THIS ASSIGNMENT IS ALREADY In RECORD.
        IF EXISTS(
            SELECT 1
            FROM student_ass_progress sap
                INNER JOIN internal.users u on u.user_id = sap.user_id
            WHERE ass_id = dcrpt_ass_id AND u.auth_id = auth.uid() AND sap.completed_at is not null
        ) THEN

        end if;

        -- CHECK IF THIS ASSIGNMENT IS ALREADY In RECORD.
        IF EXISTS(
            SELECT 1
            FROM student_ass_progress sap
                INNER JOIN internal.users u on u.user_id = sap.user_id
            WHERE ass_id = dcrpt_ass_id AND u.auth_id = auth.uid() AND sap.completed_at is not null AND sap.eval_points IS NOT NULL
        ) THEN

            RAISE EXCEPTION 'This work can''t be unsubmitted because it has already been graded. Please contact your instructor if you believe this is an error.'
            USING ERRCODE = 'P0043';

        ELSIF EXISTS(
            SELECT 1
            FROM student_ass_progress sap
                INNER JOIN internal.users u on u.user_id = sap.user_id
            WHERE ass_id = dcrpt_ass_id AND u.auth_id = auth.uid() AND sap.completed_at is not null AND sap.eval_points IS NULL
        ) THEN
            -- IF THEY UNSUBMITTED
            UPDATE student_ass_progress
            SET completed_at = NULL
            WHERE ass_id = dcrpt_ass_id AND user_id = (SELECT user_id FROM users WHERE auth_id = auth.uid())
            RETURNING sap_id INTO returned_sap_id;
        END IF;

        IF returned_sap_id IS NOT NULL THEN

            act_version_id := (SELECT l2.version_id FROM assignment a INNER JOIN internal.lesson l2 on l2.lesson_id = a.lesson_id WHERE a.ass_id = dcrpt_ass_id);
            act_sender := (SELECT user_id FROM users WHERE auth_id = auth.uid());
            act_recipient := (SELECT user_id FROM course_version_faculty WHERE version_id = act_version_id );
            msg := format(
                'Student %s unsubmitted an assignment/work "%s" in %s',
                (SELECT CONCAT(lname, ', ', fname, ' ', COALESCE(mname, '')) FROM users WHERE auth_id = auth.uid()),
                (SELECT ass_title FROM assignment WHERE ass_id = dcrpt_ass_id),
                (SELECT c.crs_title FROM prospectus_course pc INNER JOIN internal.course c ON c.crs_id = pc.crs_id WHERE pc.pc_id = act_version_id)
            );

            INSERT INTO course_activity (sender_id, recipient_id, version_id, type, metadata, message)
                        VALUES (
                            act_sender,
                            act_recipient,
                            act_version_id,
                            'unsubmit-assignment',
                            jsonb_build_object(
                                'visibility', jsonb_build_array('analytics', 'notification'),
                                'assignment_id', dcrpt_ass_id,
                                'course_completion_rate', get_progress(act_sender, act_version_id)
                            ),
                        msg
                        );


        end if;

    ELSE
        -- MEANS THAT  THEY'RE NOT ENROLLED
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    end if;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
REVOKE ALL ON PROCEDURE internal.unsubmit_work(
    IN p_assignment_id TEXT
) FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE internal.unsubmit_work(
    IN p_assignment_id TEXT
) TO authenticated;


-- 6.4) Removed attachment

CREATE OR REPLACE PROCEDURE internal.remove_attachment(
    IN p_my_attachment_id TEXT
)
SET search_path = internal
AS $$
DECLARE
    dcrpt_saa_id INT;
BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['student'])) = FALSE THEN
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    END IF;

    -- decrypt special_id
    BEGIN
        dcrpt_saa_id := pgp_sym_decrypt(
            decode(p_my_attachment_id, 'base64'),
            get_secret_key('view_assignment') -- if screen from enrolled courses
        )::INT;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Valid Student Attachment ID is required.'
            USING ERRCODE = 'P0043';
    END;

    -- CHECK FIRST IF THIS STUDENT IS ENROLLED IN THIS COURSE
    IF EXISTS(
        SELECT 1
        FROM my_courses mc2
        INNER JOIN internal.lesson l2 on mc2.version_id = l2.version_id
        INNER JOIN internal.assignment a2 on l2.lesson_id = a2.lesson_id
        INNER JOIN internal.student_ass_progress s on a2.ass_id = s.ass_id
        INNER JOIN internal.student_ass_attachment saa on s.sap_id = saa.sap_id
        WHERE saa.saa_id = dcrpt_saa_id
    )THEN

        -- CHECK IF THE ASSIGNMENT ALREADY TURNED IN
        IF NOT EXISTS (
            SELECT 1
            FROM student_ass_progress sap
            INNER JOIN internal.student_ass_attachment a on sap.sap_id = a.sap_id
            WHERE sap.completed_at IS NOT NULL AND a.saa_id = dcrpt_saa_id
        ) THEN
            DELETE FROM student_ass_attachment
            WHERE saa_id = dcrpt_saa_id;

            DELETE FROM storage.objects
            WHERE id = (select file_id from student_ass_attachment where saa_id = dcrpt_saa_id);
        ELSE
            RAISE EXCEPTION 'Please unsubmit assignment before removing attachment.'
            USING ERRCODE = 'P0043';
        end if;

    else
        -- not enrolled
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    end if;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
REVOKE ALL ON PROCEDURE internal.remove_attachment(
    IN p_my_attachment_id TEXT
) FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE internal.remove_attachment(
    IN p_my_attachment_id TEXT
) TO authenticated;


-- 7.) Examination

--- 7.1) View Exam

CREATE OR REPLACE FUNCTION internal.view_exam(IN p_my_exam_id TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    dcrpt_test_id INT;
    attempts_made INT;
    attempts_allowed int;
    about_assignment JSONB;
    attempt_history jsonb;
BEGIN
    -- decrypt special_id
    BEGIN
        dcrpt_test_id := pgp_sym_decrypt(
            decode(p_my_exam_id, 'base64'),
            get_secret_key('view_course') -- if screen from enrolled courses
        )::INT;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Valid Exam ID is required.'
            USING ERRCODE = 'P0035';
    END;

    -- CHECKS IF THIS COURSE IS ALREADY PUBLISHED
    IF EXISTS (
        SELECT 1
        FROM course_version
        WHERE version_id = (
                SELECT l.version_id
                  FROM test t
                  INNER JOIN internal.lesson l on l.lesson_id = t.lesson_id
                  WHERE t.test_id = dcrpt_test_id
            )
          AND is_ready IS TRUE AND apvd_rvwd_by IS NOT NULL
    ) THEN

        -- CHECK USER REQUIREMENTS
        IF (
            (SELECT check_user_role(ARRAY['student'])) = TRUE
        ) THEN

            SELECT COALESCE(COUNT(*),0) INTO attempts_made
            FROM student_test_record
            WHERE test_id = dcrpt_test_id AND user_id = (SELECT user_id FROM users WHERE auth_id = auth.uid());

            SELECT allowed_attempts into attempts_allowed
            FROM test
            WHERE test_id = dcrpt_test_id;

            SELECT
                jsonb_build_object(
                'test_id', encode(pgp_sym_encrypt(t.test_id::TEXT, internal.get_secret_key('view_exam')),'base64')::text,
                'lesson_title', l2.lesson_name::TEXT,
                'test_title', t.test_title::TEXT,
                'attempt_status', CASE WHEN attempts_made >= attempts_allowed THEN FALSE ELSE TRUE END,
                'time_limit', t.time_limit::text,
                'total_questions', COUNT(DISTINCT q.question_id),
                'total_points', (
                            SELECT SUM(points) AS total_sum
                            FROM (
                                -- case 1: multiple choice → distinct per question_id
                                SELECT DISTINCT q3.question_id, q3.total_points AS points
                                FROM answer_key a2
                                JOIN internal.question q3 ON q3.question_id = a2.question_id
                                JOIN internal.answer_type at3 ON at3.anst_id = q3.anst_id
                                WHERE q3.test_id = dcrpt_test_id
                                  AND at3.answer_type = 'multiple choice'

                                UNION ALL

                                -- case 2: all other types → keep duplicates
                                SELECT q3.question_id, q3.total_points AS points
                                FROM answer_key a2
                                JOIN internal.question q3 ON q3.question_id = a2.question_id
                                JOIN internal.answer_type at3 ON at3.anst_id = q3.anst_id
                                WHERE q3.test_id = dcrpt_test_id
                                  AND at3.answer_type <> 'multiple choice'
                            ) t
                        ),
                'claim_status', str.status,
                'test_description', t.descr
                ) INTO about_assignment
            FROM test t
                INNER JOIN internal.lesson l2 on t.lesson_id = l2.lesson_id
                LEFT JOIN internal.question q on t.test_id = q.test_id
                LEFT JOIN internal.student_test_record str on q.test_id = str.test_id
            where t.test_id = dcrpt_test_id
            group by t.test_id, l2.lesson_name, t.time_limit, str.status, t.descr;


--             WITH base_attempts AS (
--                 -- unique rows per attempt, before joins can multiply them
--                 SELECT
--                     str.ut_id,
--                     str.test_id,
--                     str.user_id,
--                     str.created_at,
--                     str.completed_at,
--                     ROW_NUMBER() OVER (
--                         PARTITION BY str.test_id, str.user_id
--                         ORDER BY str.created_at ASC
--                     ) AS attempt_number
--                 FROM student_test_record str
--                 INNER JOIN internal.users u on u.user_id = str.user_id
--                 WHERE str.completed_at IS NOT NULL
--                 AND u.auth_id = auth.uid()
--                 AND str.test_id = dcrpt_test_id
--             ),
--             attempts AS (
--                 SELECT DISTINCT ON (ba.ut_id)   -- ✅ preserve your per-key_id status logic
--                     ba.ut_id,
--                     ba.test_id,
--                     ba.user_id,
--                     ba.attempt_number,
--                     ba.created_at,
--                     ba.completed_at,
--                     TRIM(BOTH ' ' FROM
--                         CONCAT_WS(' ',
--                             CASE
--                                 WHEN EXTRACT(HOUR FROM (ba.completed_at - ba.created_at)) > 0
--                                     THEN EXTRACT(HOUR FROM (ba.completed_at - ba.created_at))::INT || ' hour' ||
--                                          CASE WHEN EXTRACT(HOUR FROM (ba.completed_at - ba.created_at)) > 1 THEN 's' END
--                             END,
--                             CASE
--                                 WHEN EXTRACT(MINUTE FROM (ba.completed_at - ba.created_at)) > 0
--                                     THEN EXTRACT(MINUTE FROM (ba.completed_at - ba.created_at))::INT || ' minute' ||
--                                          CASE WHEN EXTRACT(MINUTE FROM (ba.completed_at - ba.created_at)) > 1 THEN 's' END
--                             END
--                         )
--                     ) AS time_taken,
--                     (
--                         SELECT
--                             CASE
--                                 WHEN COUNT(*) >= 1 THEN 'Preliminary (Pending Faculty Evaluation)'
--                                 ELSE 'Final/Official'
--                             END
--                         FROM student_answer sa
--                             INNER JOIN answer_key ak on ak.key_id = sa.key_id
--                             INNER JOIN internal.question q on q.question_id = ak.question_id
--                             INNER JOIN internal.answer_type a on a.anst_id = q.anst_id
--                         where sa.essay_given_points IS NULL
--                             AND sa.ut_id = ba.ut_id
--                             AND ak.key_id = sa.key_id
--                             and a.answer_type = 'essay'
--                     ) AS status,
--                     CONCAT(
--                         (
--                             SELECT
--                                 SUM(
--                                     CASE
--                                         WHEN a.answer_type = 'multiple choice'
--                                              AND ak.is_correct IS TRUE
--                                              AND sa.key_id = ak.key_id
--                                             THEN (1 * q.total_points)
--
--                                         WHEN a.answer_type = 'true/false'
--                                              AND sa.tof_ans = ak.tof_key
--                                              AND sa.key_id = ak.key_id
--                                             THEN (1 * q.total_points)
--
--                                         WHEN a.answer_type = 'identification'
--                                              AND trim(lower(sa.text_ans)) = trim(lower(ak.text_key))
--                                              AND sa.key_id = ak.key_id
--                                             THEN (1 * q.total_points)
--
--                                         WHEN a.answer_type = 'enumeration'
--                                              AND trim(lower(sa.text_ans)) = trim(lower(ak.text_key))
--                                              AND sa.key_id = ak.key_id
--                                             THEN (1 * q.total_points)
--
--                                         WHEN a.answer_type = 'essay'
--                                              AND sa.key_id = ak.key_id
--                                             THEN coalesce(sa.essay_given_points, 0)
--
--                                         ELSE 0
--                                     END
--                                 )
--                             FROM student_answer sa
--                             INNER JOIN internal.answer_key ak ON ak.key_id = sa.key_id
--                             INNER JOIN internal.question q ON q.question_id = ak.question_id
--                             INNER JOIN internal.answer_type a ON a.anst_id = q.anst_id
--                             WHERE sa.ut_id = ba.ut_id
--                         ),
--                         ' out of ',
--                         (
--                             SELECT SUM(points) AS total_sum
--                             FROM (
--                                 -- case 1: multiple choice → distinct per question_id
--                                 SELECT DISTINCT q3.question_id, q3.total_points AS points
--                                 FROM answer_key a2
--                                 JOIN internal.question q3 ON q3.question_id = a2.question_id
--                                 JOIN internal.answer_type at3 ON at3.anst_id = q3.anst_id
--                                 WHERE q3.test_id = ba.test_id
--                                   AND at3.answer_type = 'multiple choice'
--
--                                 UNION ALL
--
--                                 -- case 2: all other types → keep duplicates
--                                 SELECT q3.question_id, q3.total_points AS points
--                                 FROM answer_key a2
--                                 JOIN internal.question q3 ON q3.question_id = a2.question_id
--                                 JOIN internal.answer_type at3 ON at3.anst_id = q3.anst_id
--                                 WHERE q3.test_id = ba.test_id
--                                   AND at3.answer_type <> 'multiple choice'
--                             ) t
--                         )
--                     ) AS score
--                 FROM base_attempts ba
--                 INNER JOIN internal.test t ON t.test_id = ba.test_id
--                 LEFT JOIN internal.question q2 ON ba.test_id = q2.test_id
--                 INNER JOIN internal.answer_type a ON q2.anst_id = a.anst_id
--                 LEFT JOIN internal.answer_key ak ON q2.question_id = ak.question_id
--                 LEFT JOIN internal.student_answer sa ON ak.key_id = sa.key_id
--                 ORDER BY ba.ut_id, ak.key_id
--             )
--             SELECT json_agg(
--                        jsonb_build_object(
--                            'attempt_id', encode(pgp_sym_encrypt(ut_id::TEXT, internal.get_secret_key('view_exam')), 'base64')::text,
--                            'attempt_number', CONCAT('Attempt ', attempt_number),
--                            'time_taken', time_taken,
--                            'status', status,
--                            'score', score
--                        )
--                        ORDER BY ut_id DESC
--                    ) INTO attempt_history
--             FROM attempts;

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
                WHERE str.user_id = (SELECT user_id FROM users WHERE auth_id = auth.uid())
                  AND str.test_id = dcrpt_test_id
            )
            SELECT json_agg(
                jsonb_build_object(
                    'attempt_number', CONCAT('Attempt ', ra.attempt_number),
                    'attempt_id', encode(pgp_sym_encrypt(ra.ut_id::TEXT, internal.get_secret_key('view_exam')), 'base64')::text,
                    'time_taken',
                       -- 🕒 Time taken
                           CASE
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
                            END,
                    'score', view_attempt_result(encode(pgp_sym_encrypt(ra.ut_id::TEXT, internal.get_secret_key('view_exam')), 'base64')::text)->>'student_score',
                    'status',
                        CASE
                            WHEN (view_attempt_result(encode(pgp_sym_encrypt(ra.ut_id::TEXT, internal.get_secret_key('view_exam')), 'base64')::text)->>'pending_essays')::int > 0 THEN 'Preliminary (Pending Faculty Evaluation)'
                            ELSE 'Final/Official'
                        END
                ) ORDER BY ra.attempt_number desc
            ) INTO attempt_history
            FROM ranked_attempts ra;

            -------------------------------------------------------------------
            -- FINAL RETURN
            -------------------------------------------------------------------
            RETURN jsonb_build_object(
                'attempt_hisotry', coalesce(attempt_history, '[]'::jsonb),
                'about', coalesce(about_assignment, '[]'::jsonb)
            );

        ELSE
            RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
        END IF;
    ELSE
        -- If guard fails, return NULL (or you can return an error json)
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    END IF;
END;
$$; -- NEW
REVOKE ALL ON FUNCTION internal.view_exam(IN p_my_exam_id TEXT) FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION internal.view_exam(IN p_my_exam_id TEXT) TO authenticated;


--- 7.2) VIEW EXAM RESULT

CREATE OR REPLACE FUNCTION internal.view_attempt_result(IN p_my_attempt_id TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    dcrpt_ut_id INT;

    v_right_answer INT := 0;
    v_mistakes INT := 0;
    v_unanswered INT := 0;
    v_essay_g INT := 0;
    v_essay_p INT := 0;
    v_avg_time numeric (5,2):= 0.0;

    v_total_points INT := 0;
    v_earned_points TEXT;

    v_percentage numeric (5,2);
BEGIN
    -- decrypt special_id
    BEGIN
        dcrpt_ut_id := pgp_sym_decrypt(
            decode(p_my_attempt_id, 'base64'),
            get_secret_key('view_exam') -- if screen from enrolled courses
        )::INT;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Valid Attempt ID is required.'
            USING ERRCODE = 'P0035';
    END;

    -- CHECKS IF THIS COURSE IS ALREADY PUBLISHED
    IF EXISTS (
        SELECT 1
        FROM course_version
        WHERE version_id = (
                SELECT l.version_id
                  FROM test t
                  INNER JOIN internal.lesson l on l.lesson_id = t.lesson_id
                  WHERE t.test_id = (SELECT test_id FROM student_test_record WHERE ut_id = dcrpt_ut_id)
            )
          AND is_ready IS TRUE AND apvd_rvwd_by IS NOT NULL
    ) THEN

        -- CHECK USER REQUIREMENTS
        IF (
            (SELECT check_user_role(ARRAY['student','faculty', 'dean'])) = TRUE
        ) THEN

            WITH table_wrap AS (
                SELECT
                    q.question_id,
--                     q.question,
                    q.total_points,
                    at2.answer_type,
                    k.key_id,
--                     k.is_correct,
--                     k.text_key,
--                     k.tof_key,
                    k.enum_keys,
--                     sa.enum_ans,
--                     sa.tof_ans,
--                     sa.text_ans,
                    CASE
                        WHEN sa.key_id IS NULL THEN jsonb_build_object('status', 'unanswered')

                        WHEN at2.answer_type = 'essay'
                            AND sa.essay_given_points IS NOT NULL THEN
                                jsonb_build_object('status', 'essay-graded', 'p_earned', coalesce(sa.essay_given_points, 0))

                        WHEN at2.answer_type = 'essay'
                            AND sa.essay_given_points IS NULL THEN
                                jsonb_build_object('status', 'essay-pending')

                        WHEN at2.answer_type = 'multiple choice'
                            AND sa.key_id = k.key_id
                            AND k.is_correct = FALSE THEN jsonb_build_object('status', 'wrong')

                        WHEN at2.answer_type = 'multiple choice'
                            AND sa.key_id = k.key_id
                            AND k.is_correct = TRUE THEN jsonb_build_object('status', 'correct', 'p_earned', (1 * q.total_points))

                        WHEN at2.answer_type = 'true/false'
                            AND sa.tof_ans IS NOT NULL
                            AND sa.tof_ans <> k.tof_key THEN jsonb_build_object('status', 'wrong')

                        WHEN at2.answer_type = 'true/false'
                            AND sa.tof_ans IS NOT NULL
                            AND sa.tof_ans = k.tof_key THEN jsonb_build_object('status', 'correct', 'p_earned', (1 * q.total_points))

                        WHEN at2.answer_type = 'identification'
                            AND sa.text_ans IS NOT NULL
                            AND trim(lower(sa.text_ans)) <> trim(lower(k.text_key)) THEN jsonb_build_object('status', 'wrong')

                        WHEN at2.answer_type = 'identification'
                            AND sa.text_ans IS NOT NULL
                            AND trim(lower(sa.text_ans)) = trim(lower(k.text_key)) THEN jsonb_build_object('status', 'correct','p_earned', (1 * q.total_points))

                        WHEN at2.answer_type = 'enumeration' THEN (
                            WITH correct_list AS (
                                SELECT trim(lower(x)) AS val FROM unnest(k.enum_keys) AS x
                            ),
                            student_list AS (
                                SELECT trim(lower(s)) AS val FROM unnest(sa.enum_ans) AS s
                            )
                            SELECT jsonb_build_object(
                                'corrects', (SELECT COUNT(*) FROM student_list s WHERE s.val IN (SELECT val FROM correct_list)),
                                'p_earned', ((SELECT COUNT(*) FROM student_list s WHERE s.val IN (SELECT val FROM correct_list)) * q.total_points),
                                'wrongs',  (SELECT COUNT(*) FROM student_list s WHERE s.val NOT IN (SELECT val FROM correct_list))
                            )
                        )
                    END AS answer_status
                FROM internal.question q
                INNER JOIN internal.answer_type at2 ON q.anst_id = at2.anst_id
                INNER JOIN internal.answer_key k ON q.question_id = k.question_id
                LEFT JOIN internal.student_answer sa ON sa.key_id = k.key_id AND sa.ut_id = dcrpt_ut_id
                WHERE q.test_id = (SELECT test_id FROM student_test_record WHERE ut_id = dcrpt_ut_id)
            )
            SELECT
                SUM(
                    CASE
                        WHEN s.answer_type = 'enumeration' THEN (COALESCE(s.answer_status->>'corrects','0'))::int
                        WHEN s.answer_status->>'status' = 'correct' THEN 1
                        ELSE 0
                    END
                ) AS right_answer,

                SUM(
                    CASE
                        WHEN s.answer_type = 'enumeration' THEN (COALESCE(s.answer_status->>'wrongs','0'))::int
                        WHEN s.answer_status->>'status' = 'wrong' THEN 1
                        ELSE 0
                    END
                ) AS mistakes,

                SUM(CASE WHEN s.answer_status->>'status' = 'unanswered' THEN 1 ELSE 0 END) AS unanswered,
                SUM(CASE WHEN s.answer_status->>'status' = 'essay-pending' THEN 1 ELSE 0 END) AS essay_pending,
                SUM(CASE WHEN s.answer_status->>'status' = 'essay-graded' THEN 1 ELSE 0 END) AS essay_graded,
                CONCAT(
                    SUM(
                        CASE
                            WHEN s.answer_type = 'enumeration' THEN (COALESCE(s.answer_status->>'corrects','0'))::int
                            WHEN s.answer_status->>'status' = 'correct' THEN 1
                            ELSE 0
                        END
                    ), '/',
                    SUM(
                        CASE
                            WHEN s.answer_type = 'enumeration'
                                THEN s.total_points * COALESCE(array_length(s.enum_keys, 1), 0)
                            ELSE s.total_points
                        END
                    )
                ) AS student_score,
                ROUND( ( (SUM(
                        CASE
                            WHEN s.answer_type = 'enumeration' THEN (COALESCE(s.answer_status->>'corrects','0'))::int
                            WHEN s.answer_status->>'status' = 'correct' THEN 1
                            ELSE 0
                        END
                    )::decimal / SUM(
                        CASE
                            WHEN s.answer_type = 'enumeration'
                                THEN s.total_points * COALESCE(array_length(s.enum_keys, 1), 0)
                            ELSE s.total_points
                        END
                    )::decimal) * 100 ), 2 ) as accuracy
          INTO v_right_answer, v_mistakes, v_unanswered, v_essay_p, v_essay_g, v_earned_points, v_percentage
            FROM table_wrap s
            WHERE
                -- keep answered rows
                s.answer_status->>'status' IN ('correct','wrong','essay-pending','essay-graded')

                OR

                -- keep exactly ONE unanswered row per question
                (
                     s.answer_status->>'status' = 'unanswered'
                     AND s.key_id = (
                         SELECT MIN(key_id)
                         FROM table_wrap t
                         WHERE t.question_id = s.question_id
                     )
                     AND NOT EXISTS (
                         SELECT 1
                         FROM table_wrap x
                         WHERE x.question_id = s.question_id
                         AND x.answer_status->>'status' IN ('correct','wrong')
                     )
                );

            -------------------------------------------------------------------
            -- FINAL RETURN
            -------------------------------------------------------------------
            RETURN jsonb_build_object(
                'corrects', v_right_answer,
                'mistakes', v_mistakes,
                'unanswered', v_unanswered,
                'pending_essays', v_essay_p,
                'graded_essays', v_essay_g,
                'student_score', v_earned_points,
                'accuracy', v_percentage
            );

        ELSE
            RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
        END IF;
    ELSE
        -- If guard fails, return NULL (or you can return an error json)
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    END IF;
END;
$$;
REVOKE ALL ON FUNCTION internal.view_attempt_result(IN p_my_attempt_id TEXT) FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION internal.view_attempt_result(IN p_my_attempt_id TEXT) TO authenticated;


--- 7.3) ATTEMPT EXAM (IF ALLOWED)

CREATE OR REPLACE FUNCTION internal.attempt_exam(IN p_my_exam_id TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    dcrpt_test_id INT;
    attempts_made int;
    attempts_allowed INT;
BEGIN
    -- decrypt special_id
    BEGIN
        dcrpt_test_id := pgp_sym_decrypt(
            decode(p_my_exam_id, 'base64'),
            get_secret_key('view_course') -- if screen from enrolled courses
        )::INT;
    EXCEPTION
        WHEN OTHERS THEN
            BEGIN
                dcrpt_test_id := pgp_sym_decrypt(
                    decode(p_my_exam_id, 'base64'),
                    get_secret_key('view_exam') -- if screen from enrolled courses
                )::INT;
            EXCEPTION
                WHEN OTHERS THEN
                    RAISE EXCEPTION 'Valid Exam ID is required.'
                    USING ERRCODE = 'P0035';
            END;
    END;

    -- CHECKS IF THIS COURSE IS ALREADY PUBLISHED
    IF EXISTS (
        SELECT 1
        FROM course_version
        WHERE version_id = (
                SELECT l.version_id
                FROM test t
                  INNER JOIN internal.lesson l on l.lesson_id = t.lesson_id
                WHERE t.test_id = dcrpt_test_id
            )
          AND is_ready IS TRUE AND apvd_rvwd_by IS NOT NULL
    ) THEN

        -- CHECK USER REQUIREMENTS
        IF (
            (SELECT check_user_role(ARRAY['student'])) = TRUE
        ) THEN

            SELECT COALESCE(COUNT(*),0) INTO attempts_made
            FROM student_test_record
            WHERE test_id = dcrpt_test_id and user_id = (select user_id from users where auth_id = auth.uid());

            SELECT allowed_attempts into attempts_allowed
            FROM test
            WHERE test_id = dcrpt_test_id;

            IF attempts_made >= attempts_allowed THEN
                RETURN jsonb_build_object(
                    'response_id', encode(
                                        pgp_sym_encrypt(
                                            jsonb_build_object(
                                                'request_type', null,
                                                'message', 'denied',
                                                'key', null,
                                                'expires_at', (now() + interval '5 minutes')  -- set expiry window here
                                            )::text,
                                            internal.get_secret_key('attempt_exam')
                                        ),
                                        'base64'
                                    )::text,
                    'response_status', false,
                    'response_message','Exam Attempt Limit' || E'\n' ||
                                'You have used ' || attempts_made || ' of ' || attempts_allowed || ' attempts for this exam. ' ||
                                'No further attempts are allowed. Please contact your instructor if you believe this is an error.'
                );
            else
                IF EXISTS(
                    SELECT 1
                    FROM student_test_record
                    WHERE test_id = dcrpt_test_id
                    and user_id = (select user_id from users where auth_id = auth.uid())
                    and completed_at is null
                ) THEN

                    RETURN jsonb_build_object(
                    'response_id', encode(
                                        pgp_sym_encrypt(
                                            jsonb_build_object(
                                                'request_type', 'resume-attempt',
                                                'message', 'ok',
                                                'key',
                                                (
                                                    SELECT
                                                        ut_id::int
                                                    FROM student_test_record
                                                    WHERE test_id = dcrpt_test_id
                                                    and user_id = (select user_id from users where auth_id = auth.uid())
                                                    and completed_at is null order by completed_at desc limit 1
                                                ),
                                                'expires_at', (now() + interval '5 minutes')  -- set expiry window here
                                            )::text,
                                            internal.get_secret_key('attempt_exam')
                                        ),
                                        'base64'
                                    )::text,
                    'response_status', true,
                    'response_message', 'Pending Exam Detected' || E'\n' ||
                                            'You currently have an unfinished exam attempt.' || E'\n' ||
                                            'Would you like to continue answering your existing attempt?'
                );
                ELSE
                    RETURN jsonb_build_object(
                        'response_id', encode(
                                            pgp_sym_encrypt(
                                                jsonb_build_object(
                                                    'request_type', 'initial',
                                                    'message', 'ok',
                                                    'key', dcrpt_test_id::INT,
                                                    'expires_at', (now() + interval '5 minutes')  -- set expiry window here
                                                )::text,
                                                internal.get_secret_key('attempt_exam')
                                            ),
                                            'base64'
                                        )::text,
                        'response_status', true,
                        'response_message', 'Exam Attempt Limit' || E'\n' ||
                                    'You have used ' || attempts_made || ' of ' || attempts_allowed || ' attempts for this exam. ' ||
                                   'You may continue, but please ensure that you are fully prepared before starting your next attempt.'
                    );
                end if;

            end if;

        ELSE
            RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
        END IF;
    ELSE
        -- If guard fails, return NULL (or you can return an error json)
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    END IF;
END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION internal.attempt_exam(IN p_my_exam_id TEXT) FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION internal.attempt_exam(IN p_my_exam_id TEXT) TO authenticated;


--- 7.4) GET QUESTIONNAIRE

CREATE OR REPLACE FUNCTION internal.fetch_questions(IN p_request_token TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    request_payload JSONB;
    dcrpt_ut_id INT:= NULL;
    mc_set JSONB := '[]'::jsonb;
    tof_set JSONB := '[]'::jsonb;
    enumeration_set JSONB := '[]'::jsonb;
    identification_set JSONB := '[]'::jsonb;
    essay_set JSONB := '[]'::jsonb;
    questionnaire_set JSONB := '[]'::jsonb;
    f_question_ids INT[];
    id INT;
    v_answer_type TEXT;
    v_question JSONB;
    v_items JSONB;
    v_key_id INT;
    v_number_of_enum_items INT;
    v_remaining_time INTERVAL;

    f_enum_amount INT;
    f_enum_user_answer TEXT[];

    act_sender INT;
    act_recipient INT;
    act_version_id INT;
    msg TEXT;
BEGIN
    -- decrypt request id
    BEGIN
        request_payload = (pgp_sym_decrypt(
                    decode(p_request_token, 'base64'),
                    internal.get_secret_key('attempt_exam')
                ))::jsonb;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Valid Request Token required.'
                        USING ERRCODE = 'P0035';
    END;

    IF (request_payload->>'expires_at')::timestamptz < now() THEN -- if payload still valid
            RAISE EXCEPTION 'Request token expired.'
                USING ERRCODE = 'P0044';
    end if;

    if request_payload->>'request_type' = 'initial' OR request_payload->>'request_type' =  'resume-attempt' THEN
        IF request_payload->>'message' = 'ok' THEN
            -- CREATE ATTEMPT/ENTRY

            IF request_payload->>'request_type' =  'initial' THEN
                insert into student_test_record (test_id, user_id)
                VALUES ((request_payload->>'key')::INT, (SELECT user_id from users where auth_id =  auth.uid()))
                returning ut_id INTO dcrpt_ut_id;
            ELSE
                dcrpt_ut_id := request_payload->>'key';
            END IF;




                        -- GET ALL questionnaires

            -- GET ALL QUESTION IDS
            IF request_payload->>'request_type' =  'initial' THEN
                SELECT array_agg(question_id) INTO f_question_ids
                FROM question
                WHERE test_id = (request_payload->>'key')::INT;
            ELSE
                SELECT array_agg(question_id) INTO f_question_ids
                FROM question
                WHERE test_id = (SELECT test_id FROM student_test_record WHERE ut_id = dcrpt_ut_id);
            END IF;

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
                                            internal.get_secret_key('fetch_questions')
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
                                'key_id', encode(pgp_sym_encrypt(key_id::TEXT, internal.get_secret_key('fetch_questions')),'base64')::text,
                                'value', text_key::text,
                                'is_mc_user_answer',
                                    (
                                        SELECT EXISTS (
                                            SELECT 1
                                            FROM student_answer sta1
                                            INNER JOIN internal.student_test_record str1
                                                ON str1.ut_id = sta1.ut_id
                                            WHERE sta1.key_id = answer_key.key_id
                                              AND sta1.ut_id = dcrpt_ut_id
                                              AND str1.user_id = (
                                                  SELECT user_id
                                                  FROM users
                                                  WHERE auth_id = auth.uid()
                                              )
                                        )
                                    )
                            )
                        ) INTO v_items
                        FROM answer_key
                        WHERE question_id = id;

--                         mc_set := mc_set || jsonb_build_object(
--                                 'question_details', v_question,
--                                 'item_details', v_items
--                             );
                        questionnaire_set = questionnaire_set || jsonb_build_object(
                                'question_details', v_question,
                                'item_details', v_items
                            );
                    end if;

                    IF v_answer_type = 'true/false' THEN
                        SELECT
                            json_agg(
                                json_build_object(
                                'key_id', encode(pgp_sym_encrypt(key_id::TEXT, internal.get_secret_key('fetch_questions')),'base64')::text,
                                'value', null,
                                'tof_user_answer',
                                    (
                                        SELECT sta1.tof_ans
                                        FROM student_answer sta1
                                            INNER JOIN internal.student_test_record str1
                                                ON str1.ut_id = sta1.ut_id
                                        WHERE sta1.key_id = answer_key.key_id
                                            AND sta1.ut_id = dcrpt_ut_id
                                            AND str1.user_id = (SELECT user_id
                                                                FROM users
                                                                WHERE auth_id = auth.uid())
                                    )
                            )
                        ) INTO v_items
                        FROM answer_key
                        WHERE question_id = id;

--                         tof_set := tof_set || jsonb_build_object(
--                                 'question_details', v_question,
--                                 'item_details', v_items
--                             );
                        questionnaire_set = questionnaire_set || jsonb_build_object(
                                'question_details', v_question,
                                'item_details', v_items
                            );
                    end if;

                    IF v_answer_type = 'identification' THEN
                        SELECT
                            json_agg(
                                json_build_object(
                                'key_id', encode(pgp_sym_encrypt(key_id::TEXT, internal.get_secret_key('fetch_questions')),'base64')::text,
                                'value', null,
                                'identification_user_answer',
                                    (
                                        SELECT sta1.text_ans
                                        FROM student_answer sta1
                                            INNER JOIN internal.student_test_record str1
                                                ON str1.ut_id = sta1.ut_id
                                        WHERE sta1.key_id = answer_key.key_id
                                            AND sta1.ut_id = dcrpt_ut_id
                                            AND str1.user_id = (SELECT user_id
                                                                FROM users
                                                                WHERE auth_id = auth.uid())
                                    )
                            )
                        ) INTO v_items
                        FROM answer_key
                        WHERE question_id = id;

--                         identification_set := identification_set || jsonb_build_object(
--                                 'question_details', v_question,
--                                 'item_details', v_items
--                             );
                        questionnaire_set = questionnaire_set || jsonb_build_object(
                                'question_details', v_question,
                                'item_details', v_items
                            );
                    end if;

                    IF v_answer_type = 'essay' THEN
                        SELECT
                            json_agg(
                                json_build_object(
                                'key_id', encode(pgp_sym_encrypt(key_id::TEXT, internal.get_secret_key('fetch_questions')),'base64')::text,
                                'value', null,
                                'essay_user_answer',
                                    (
                                        SELECT sta1.text_ans
                                        FROM student_answer sta1
                                            INNER JOIN internal.student_test_record str1
                                                ON str1.ut_id = sta1.ut_id
                                        WHERE sta1.key_id = answer_key.key_id
                                            AND sta1.ut_id = dcrpt_ut_id
                                            AND str1.user_id = (SELECT user_id
                                                                FROM users
                                                                WHERE auth_id = auth.uid())
                                    )
                            )
                        ) INTO v_items
                        FROM answer_key
                        WHERE question_id = id;

--                         essay_set := essay_set || jsonb_build_object(
--                                 'question_details', v_question,
--                                 'item_details', v_items
--                             );
                        questionnaire_set = questionnaire_set || jsonb_build_object(
                                'question_details', v_question,
                                'item_details', v_items
                            );
                    end if;

                    IF v_answer_type = 'enumeration' THEN
                        SELECT
                            ak.required_items,
                            COALESCE(sa.enum_ans, ARRAY[]::TEXT[])
                        INTO f_enum_amount, f_enum_user_answer
                        FROM answer_key ak
                        LEFT JOIN internal.student_answer sa on ak.key_id = sa.key_id AND sa.ut_id = dcrpt_ut_id
                        WHERE ak.question_id = id;

                        SELECT
                            json_agg(
                                json_build_object(
                                'key_id', encode(pgp_sym_encrypt(key_id::TEXT, internal.get_secret_key('fetch_questions')),'base64')::text,
                                'value', null,
                                'enum_amount', f_enum_amount,
                                'enum_user_answer', f_enum_user_answer
                            )
                        ) INTO v_items
                        FROM answer_key
                        WHERE question_id = id;

                        questionnaire_set = questionnaire_set || jsonb_build_object(
                                'question_details', v_question,
                                'item_details', v_items
                            );

                    end if;

                END LOOP;

                IF dcrpt_ut_id IS NOT NULL AND request_payload->>'request_type' = 'initial' THEN

                    act_version_id := (SELECT l2.version_id FROM test t INNER JOIN internal.lesson l2 on l2.lesson_id = t.lesson_id WHERE t.test_id = (request_payload->>'key')::INT);
                    act_sender := (SELECT user_id FROM users WHERE auth_id = auth.uid());
                    act_recipient := (SELECT user_id FROM course_version_faculty WHERE version_id = act_version_id );
                    msg := format(
                        'Student %s started an exam/test "%s" in %s',
                        (SELECT CONCAT(lname, ', ', fname, ' ', COALESCE(mname, '')) FROM users WHERE auth_id = auth.uid()),
                        (SELECT test.test_title FROM test WHERE test_id = (request_payload->>'key')::INT),
                        (SELECT c.crs_title FROM prospectus_course pc INNER JOIN internal.course c ON c.crs_id = pc.crs_id WHERE pc.pc_id = act_version_id)
                    );

                    INSERT INTO course_activity (sender_id, recipient_id, version_id, type, metadata, message)
                                VALUES (
                                    act_sender,
                                    act_recipient,
                                    act_version_id,
                                    'start-exam',
                                    jsonb_build_object(
                                        'visibility', jsonb_build_array('analytics', 'notification'),
                                        'test_record', dcrpt_ut_id,
                                        'course_completion_rate', get_progress(act_sender, act_version_id)
                                    ),
                                msg
                                );


                end if;

                -- FETCH THE REMAINING TIME
                SELECT
                  (st.created_at + t.time_limit - now()) INTO v_remaining_time
                FROM student_test_record st
                JOIN test t ON t.test_id = st.test_id
                WHERE st.ut_id = dcrpt_ut_id;

                RETURN jsonb_build_object(
                    'questionnaire',
                        (
                            SELECT jsonb_agg(elem ORDER BY random())
                            FROM jsonb_array_elements(questionnaire_set) AS elem
                        ),
                    'time_remaining', v_remaining_time::text
                );


            ELSE
                RAISE EXCEPTION 'Something went wrong. Unable to proceed further.'
                    USING ERRCODE = 'P0046';
            END IF;

        ELSE
            RAISE EXCEPTION 'Something went wrong. Unable to proceed further.'
                USING ERRCODE = 'P0045';
        end if;

    ELSE
        RAISE EXCEPTION 'Something went wrong. Unable to proceed further.'
                USING ERRCODE = 'P0045';
    end if;

END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION internal.fetch_questions(IN p_request_token TEXT) FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION internal.fetch_questions(IN p_request_token TEXT) TO authenticated;


--- 7.5) RECORD ENTRY

CREATE OR REPLACE PROCEDURE internal.record_entry(
    IN p_my_record_id TEXT,
    IN p_key_id TEXT DEFAULT NULL,
    IN p_tof_ans BOOLEAN DEFAULT NULL,
    IN p_text_ans TEXT DEFAULT NULL,
    IN p_enum_ans TEXT[] DEFAULT NULL
)
SET search_path = internal
AS $$
DECLARE
    v_record_id JSONB;
    v_key_id INT;
    vc_ut_id INT;
    vc_question_id INT;
    vc_answer_type TEXT;
    enum TEXT;
    f_key_ids INT[];
    f_key_id INT;
    ranking JSONB;
    item RECORD;
    current_key_id INT := NULL;
BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['student'])) = FALSE THEN
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    END IF;

    -- decrypt ENTRY PAYLOAD
    BEGIN
        v_record_id = (pgp_sym_decrypt(
                    decode(p_my_record_id, 'base64'),
                    internal.get_secret_key('fetch_questions')
                ))::jsonb;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Valid Record Token/ID required.'
                        USING ERRCODE = 'P0035';
    END;

    vc_ut_id := (v_record_id->>'ut_id')::INT;
    vc_question_id := (v_record_id->>'question_id')::INT;
    vc_answer_type := (v_record_id->>'answer_type')::TEXT;

    -- CHECK IDENTITY
    IF NOT EXISTS(
        SELECT 1 FROM student_test_record WHERE ut_id = vc_ut_id AND user_id = (SELECT user_id FROM users WHERE auth_id = auth.uid())
    ) THEN
        RAISE EXCEPTION 'Something went wrong. Invalid Identity'
            USING ERRCODE = 'P0048';
    end if;

    -- CHECK PARAMETERS
    IF vc_answer_type = 'multiple choice' THEN
        IF p_key_id IS NOT NULL THEN
            v_key_id := pgp_sym_decrypt(
                decode(p_key_id, 'base64'),
                get_secret_key('fetch_questions')
            )::INT;
        ELSE
            RAISE EXCEPTION 'Parameter p_key_id should be required for Multiple choice item.'
                        USING ERRCODE = 'P0035';
        end if;

        IF p_tof_ans IS NOT NULL THEN
            RAISE EXCEPTION 'Parameter p_tof_ans should be null for Multiple choice item.'
                        USING ERRCODE = 'P0035';
        end if;
        IF p_text_ans IS NOT NULL THEN
            RAISE EXCEPTION 'Parameter p_text_ans should be null for Multiple choice item.'
                        USING ERRCODE = 'P0035';
        end if;
        IF p_enum_ans IS NOT NULL AND array_length(p_enum_ans, 1) > 0 THEN
            RAISE EXCEPTION 'Parameter p_enum_ans should be null for Multiple choice item.'
                        USING ERRCODE = 'P0035';
        end if;

    end if;

    IF vc_answer_type = 'true/false' THEN
        IF p_key_id IS NOT NULL THEN
            v_key_id := pgp_sym_decrypt(
                decode(p_key_id, 'base64'),
                get_secret_key('fetch_questions')
            )::INT;
        ELSE
            RAISE EXCEPTION 'Parameter p_key_id should be required for True/False item.'
                        USING ERRCODE = 'P0035';
        end if;

        IF p_tof_ans IS NULL THEN
            RAISE EXCEPTION 'Parameter p_tof_ans should be required for True/False item.'
                        USING ERRCODE = 'P0035';
        end if;
        IF p_text_ans IS NOT NULL THEN
            RAISE EXCEPTION 'Parameter p_text_ans should be null for True/False item.'
                        USING ERRCODE = 'P0035';
        end if;
        IF p_enum_ans IS NOT NULL AND array_length(p_enum_ans, 1) > 0 THEN
            RAISE EXCEPTION 'Parameter p_enum_ans should be null for True/False item.'
                        USING ERRCODE = 'P0035';
        end if;
    end if;

    IF vc_answer_type = 'identification' THEN
        IF p_key_id IS NOT NULL THEN
            v_key_id := pgp_sym_decrypt(
                decode(p_key_id, 'base64'),
                get_secret_key('fetch_questions')
            )::INT;
        ELSE
            RAISE EXCEPTION 'Parameter p_key_id should be required for Identification item.'
                        USING ERRCODE = 'P0035';
        end if;

        IF p_tof_ans IS NOT NULL THEN
            RAISE EXCEPTION 'Parameter p_tof_ans should be null for Identification item.'
                        USING ERRCODE = 'P0035';
        end if;
        IF p_text_ans IS NULL THEN
            RAISE EXCEPTION 'Parameter p_text_ans should be required for Identification item.'
                        USING ERRCODE = 'P0035';
        end if;
        IF p_enum_ans IS NOT NULL AND array_length(p_enum_ans, 1) > 0 THEN
            RAISE EXCEPTION 'Parameter p_enum_ans should be null for Identification item.'
                        USING ERRCODE = 'P0035';
        end if;
    end if;

    IF vc_answer_type = 'enumeration' THEN
        IF p_key_id IS NOT NULL THEN
            v_key_id := pgp_sym_decrypt(
                decode(p_key_id, 'base64'),
                get_secret_key('fetch_questions')
            )::INT;
        ELSE
            RAISE EXCEPTION 'Parameter p_key_id should be required for Identification item.'
                        USING ERRCODE = 'P0035';
        end if;
        IF p_tof_ans IS NOT NULL THEN
            RAISE EXCEPTION 'Parameter p_tof_ans should be null for Enumeration item.'
                        USING ERRCODE = 'P0035';
        end if;
        IF p_text_ans IS NOT NULL THEN
            RAISE EXCEPTION 'Parameter p_text_ans should be null for Enumeration item.'
                        USING ERRCODE = 'P0035';
        end if;
        IF p_enum_ans IS NULL THEN
            RAISE EXCEPTION 'Parameter p_enum_ans should be required for Enumeration item.'
                        USING ERRCODE = 'P0035';
        end if;
    end if;

    IF vc_answer_type = 'essay' THEN
        IF p_key_id IS NOT NULL THEN
            v_key_id := pgp_sym_decrypt(
                decode(p_key_id, 'base64'),
                get_secret_key('fetch_questions')
            )::INT;
        ELSE
            RAISE EXCEPTION 'Parameter p_key_id should be required for Essay item.'
                        USING ERRCODE = 'P0035';
        end if;

        IF p_tof_ans IS NOT NULL THEN
            RAISE EXCEPTION 'Parameter p_tof_ans should be null for Essay item.'
                        USING ERRCODE = 'P0035';
        end if;
        IF p_text_ans IS NULL THEN
            RAISE EXCEPTION 'Parameter p_text_ans should be required for Essay item.'
                        USING ERRCODE = 'P0035';
        end if;
        IF p_enum_ans IS NOT NULL AND array_length(p_enum_ans, 1) > 0 THEN
            RAISE EXCEPTION 'Parameter p_enum_ans should be null for Essay item.'
                        USING ERRCODE = 'P0035';
        end if;
    end if;

    -- CHECK IF ENTRY IS STILL VALID
    IF NOT EXISTS (
        SELECT 1
        FROM student_test_record
        WHERE ut_id = vc_ut_id
          AND user_id = (SELECT user_id FROM users WHERE auth_id = auth.uid())
          AND completed_at IS NULL
    ) THEN
        RAISE EXCEPTION 'Entry invalid. This test/exam already closed.'
            USING ERRCODE = 'P0049';
    end if;

    -- proceed entry
    IF vc_answer_type = 'multiple choice' THEN
        SELECT sa2.key_id INTO current_key_id
        FROM student_answer sa2
        INNER JOIN internal.answer_key a on a.key_id = sa2.key_id
        WHERE a.question_id = vc_question_id AND sa2.ut_id = vc_ut_id;
    end if;

    -- CHECK IF UPDATE OR NEW ENTRY
    IF EXISTS (
        SELECT 1 FROM student_answer WHERE key_id = coalesce(current_key_id, v_key_id) AND ut_id = vc_ut_id
    ) THEN
        UPDATE student_answer
            SET key_id = COALESCE(v_key_id, key_id),
                tof_ans = COALESCE(p_tof_ans, tof_ans),
                text_ans = COALESCE(p_text_ans, text_ans),
                enum_ans = COALESCE(p_enum_ans, enum_ans)
        WHERE key_id = coalesce(current_key_id, v_key_id) AND ut_id = vc_ut_id;

    ELSE
        INSERT INTO student_answer (tof_ans, text_ans, key_id, ut_id, enum_ans)
        VALUES (p_tof_ans, p_text_ans, v_key_id, vc_ut_id, p_enum_ans);
    end if;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
REVOKE ALL ON PROCEDURE internal.record_entry(
    IN p_my_record_id TEXT,
    IN p_key_id TEXT,
    IN p_tof_ans BOOLEAN,
    IN p_text_ans TEXT,
    IN p_enum_ans TEXT[]
) FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE internal.record_entry(
    IN p_my_record_id TEXT,
    IN p_key_id TEXT,
    IN p_tof_ans BOOLEAN,
    IN p_text_ans TEXT,
    IN p_enum_ans TEXT[]
) TO authenticated;


--- 7.6) END ENTRY/TEST

CREATE OR REPLACE PROCEDURE internal.end_test(
    IN p_my_record_id TEXT
)
SET search_path = internal
AS $$
DECLARE
    v_record_id JSONB;
    vc_ut_id INT;
    vc_question_id INT;
    vc_answer_type TEXT;
    returned_test_id INT;

    act_sender INT;
    act_recipient INT;
    act_version_id INT;
    msg TEXT;
BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['student'])) = FALSE THEN
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    END IF;

    -- decrypt ENTRY PAYLOAD
    BEGIN
        v_record_id = (pgp_sym_decrypt(
                    decode(p_my_record_id, 'base64'),
                    internal.get_secret_key('fetch_questions')
                ))::jsonb;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Valid Record Token/ID required.'
                        USING ERRCODE = 'P0035';
    END;

    vc_ut_id := (v_record_id->>'ut_id')::INT;
    vc_question_id := (v_record_id->>'question_id')::INT;
    vc_answer_type := (v_record_id->>'answer_type')::TEXT;

    -- CHECK IDENTITY
    IF NOT EXISTS(
        SELECT 1 FROM student_test_record WHERE ut_id = vc_ut_id AND user_id = (SELECT user_id FROM users WHERE auth_id = auth.uid())
    ) THEN
        RAISE EXCEPTION 'Something went wrong. Invalid Identity'
            USING ERRCODE = 'P0048';
    end if;

    -- CHECK IF ENTRY IS STILL VALID
    IF EXISTS (
        SELECT 1
        FROM student_test_record
        WHERE ut_id = vc_ut_id
          AND user_id = (SELECT user_id FROM users WHERE auth_id = auth.uid())
          AND completed_at IS NOT NULL
    ) THEN
        RAISE EXCEPTION 'This test/exam already closed.'
            USING ERRCODE = 'P0049';
    ELSE
        update student_test_record
        set completed_at = now()
        where ut_id = vc_ut_id
        and user_id = (SELECT user_id FROM users WHERE auth_id = auth.uid())
        RETURNING test_id INTO returned_test_id;

        IF returned_test_id IS NOT NULL THEN

            act_version_id := (SELECT l2.version_id FROM test t INNER JOIN internal.lesson l2 on l2.lesson_id = t.lesson_id WHERE t.test_id = returned_test_id);
            act_sender := (SELECT user_id FROM users WHERE auth_id = auth.uid());
            act_recipient := (SELECT user_id FROM course_version_faculty WHERE version_id = act_version_id );
            msg := format(
                'Student %s completed an exam/test "%s" in %s',
                (SELECT CONCAT(lname, ', ', fname, ' ', COALESCE(mname, '')) FROM users WHERE auth_id = auth.uid()),
                (SELECT test.test_title FROM test WHERE test_id = returned_test_id),
                (SELECT c.crs_title FROM prospectus_course pc INNER JOIN internal.course c ON c.crs_id = pc.crs_id WHERE pc.pc_id = act_version_id)
            );

            INSERT INTO course_activity (sender_id, recipient_id, version_id, type, metadata, message)
                        VALUES (
                            act_sender,
                            act_recipient,
                            act_version_id,
                            'end-exam',
                            jsonb_build_object(
                                'visibility', jsonb_build_array('analytics', 'notification'),
                                'test_record', vc_ut_id,
                                'course_completion_rate', get_progress(act_sender, act_version_id)
                            ),
                        msg
                        );

        end if;



    end if;


END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
REVOKE ALL ON PROCEDURE internal.end_test(
    IN p_my_record_id TEXT
) FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE internal.end_test(
    IN p_my_record_id TEXT
) TO authenticated;


-- 8.) DOWNLOAD PROSPECTUS - PENDING

-- CREATE OR REPLACE FUNCTION internal.get_prospectus_dataXX(IN p_prospectus_id TEXT)
-- RETURNS JSONB
-- LANGUAGE plpgsql
-- SECURITY DEFINER
-- SET search_path = internal
-- AS $$
-- DECLARE
--     dcrpt_prospectus_id int;
--     head JSONB;
--     body JSONB;
-- BEGIN
--
--     -- decrypt prospectus ID
--     dcrpt_prospectus_id := pgp_sym_decrypt(
--         decode(p_prospectus_id, 'base64'),
--         get_secret_key('view_all_prospectus')
--     )::INT;
--
--     IF (internal.get_secret_key('get_prospectus_data') IS NOT NULL) and
--        ((SELECT check_user_role(ARRAY['admin', 'dean', 'student', 'faculty'])) = TRUE) THEN
--
--             -- get the college
--             -- get the program name
--             SELECT
--                 jsonb_build_object(
--                     'college', cao.cao_name,
--                     'program', CASE
--                                 WHEN s2.specialization IS NULL THEN
--                                     CONCAT(p2.prog_name, ', ', p2.prog_abbr)
--                                 ELSE
--                                     CONCAT(p2.prog_name, ' major in ', s2.specialization, ', ',
--                                            p2.prog_abbr, ' - ', s2.special_abbr)
--                                 END::TEXT
--                 ) INTO head
--             FROM prospectus p
--             INNER JOIN internal.specialization s2 on p.special_id = s2.special_id
--             INNER JOIN internal.program p2 on p2.prog_id = s2.prog_id
--             INNER JOIN internal.college_and_office cao on cao.cao_id = s2.cao_id
--             WHERE prospectus_id = dcrpt_prospectus_id;
--
--             SELECT
--                 json_agg(
--                     jsonb_build_object(
--                         'classification', c3.classification,
--                         'classification_units', u.required_units,
--                         'course_code', pc2.crs_code,
--                         'course_title', c4.crs_title,
--                         'course_units', c4.units
--                     )
--                 ) INTO body
--             FROM prospectus_course pc2
--             INNER JOIN internal.classification_unit u on u.cu_id = pc2.cu_id
--             INNER JOIN internal.classification c3 on c3.classification_id = u.classification_id
--             INNER JOIN internal.course c4 on c4.crs_id = pc2.crs_id
--             WHERE pc2.prospectus_id = dcrpt_prospectus_id;
--
--
--             RETURN jsonb_build_object(
--                    'head', coalesce(head, '[]'::jsonb),
--                    'body', coalesce(body, '[]'::jsonb)
--                 );
--
--
--         -- classification ---------- maximum units
--         -- course code
--         -- course name
--         -- course units
--
--         -- total credits units
--     ELSE
--         RETURN jsonb_build_object(
--                    'head', coalesce(null, '[]'::jsonb),
--                    'body', coalesce(null, '[]'::jsonb)
--                 );
--     END IF;
--
-- END;
-- $$;
-- -- 🚫 Revoke public access
-- REVOKE ALL ON FUNCTION internal.get_prospectus_dataXX(IN p_prospectus_id TEXT) FROM PUBLIC;
-- -- ✅ Grant only to trusted internal role
-- GRANT EXECUTE ON FUNCTION internal.get_prospectus_dataXX(IN p_prospectus_id TEXT) TO authenticated;


-- TASK 9.) WITHDRAW FROM COURSE

CREATE OR REPLACE PROCEDURE internal.withdraw_course(IN p_my_withdraw_id TEXT)
SET search_path = internal
AS $$
DECLARE
    dcrpt_enrolee_id INT;
    rows_updated int := NULL;

    act_faculty INT;
    act_student INT;
    act_version_id INT;
    msg TEXT;
BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['student'])) = FALSE THEN
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    END IF;

    -- decrypt special_id
    BEGIN
        dcrpt_enrolee_id := pgp_sym_decrypt(
            decode(p_my_withdraw_id, 'base64'),
            get_secret_key('view_course')
        )::INT;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Valid Withdraw ID is required.'
            USING ERRCODE = 'P0043';
    END;

    -- CHECK FIRST IF THIS STUDENT IS ENROLLED IN THIS COURSE
    IF EXISTS (
        SELECT 1
        FROM my_courses mc
        INNER JOIN internal.users u2 on u2.user_id = mc.user_id
        WHERE mc.enrollee_id = dcrpt_enrolee_id
        AND u2.auth_id = auth.uid()
    ) THEN

        UPDATE my_courses
        SET enrollment_status = FALSE,
            rating = NULL,
            review = NULL,
            review_timestamp = NULL
        WHERE enrollee_id = dcrpt_enrolee_id
          AND user_id = (SELECT user_id FROM users WHERE auth_id = auth.uid());

        GET DIAGNOSTICS rows_updated = ROW_COUNT;
        IF rows_updated > 0 THEN

            SELECT cvf.user_id, m.user_id, m.version_id INTO act_faculty, act_student, act_version_id
            FROM course_version_faculty cvf
            INNER JOIN internal.my_courses m on cvf.version_id = m.version_id
            WHERE m.enrollee_id = dcrpt_enrolee_id;

            msg := format(
                'Student %s has officially withdrawn from the course %s.',
                (SELECT CONCAT(lname, ', ', fname, ' ', COALESCE(mname, '')) FROM users WHERE auth_id = auth.uid()),
                (SELECT c.crs_title FROM prospectus_course pc INNER JOIN internal.course c ON c.crs_id = pc.crs_id WHERE pc.pc_id = act_version_id)
            );

            INSERT INTO course_activity (sender_id, recipient_id, version_id, type, metadata, message)
                        VALUES (
                            act_student,
                            act_faculty,
                            act_version_id,
                            'unsubmit-assignment',
                            jsonb_build_object(
                                'visibility', jsonb_build_array('analytics', 'notification')
                            ),
                        msg
                        );

            msg := format(
                'You have successfully withdrawn from the course %s.',
                (SELECT c.crs_title FROM prospectus_course pc INNER JOIN internal.course c ON c.crs_id = pc.crs_id WHERE pc.pc_id = act_version_id)
            );

            INSERT INTO course_activity (recipient_id, version_id, type, metadata, message)
                        VALUES (
                            act_student,
                            act_version_id,
                            'unsubmit-assignment',
                            jsonb_build_object(
                                'visibility', jsonb_build_array('analytics', 'notification')
                            ),
                        msg
                        );

        ELSE
            RAISE EXCEPTION 'Failed to withdraw.'
                USING ERRCODE = 'P0010';
        end if;

    ELSE
        -- MEANS THAT  THEY'RE NOT ENROLLED
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    end if;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
REVOKE ALL ON PROCEDURE internal.withdraw_course(IN p_my_withdraw_id TEXT) FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE internal.withdraw_course(IN p_my_withdraw_id TEXT) TO authenticated;


-- TASK 10.) LEADERBOARDS

CREATE OR REPLACE FUNCTION internal.view_leaderboards(IN p_leaderboards_id TEXT)
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
    dcrpt_version_id INT;
BEGIN

    -- Only run main query if key exists and confirm the user role
    IF (
        (SELECT check_user_role(ARRAY['student', 'faculty', 'dean', 'admin'])) = TRUE AND
        internal.get_secret_key('view_leaderboards') IS NOT NULL) THEN

        BEGIN
            dcrpt_version_id := pgp_sym_decrypt(
                decode(p_leaderboards_id, 'base64'),
                get_secret_key('view_course') -- if screen from enrolled courses
            )::INT;
        EXCEPTION
            WHEN OTHERS THEN
                RAISE EXCEPTION 'Valid Leaderboard ID is required.'
                USING ERRCODE = 'P0035';
        END;

        RETURN QUERY
            WITH leaderboards AS (
                SELECT
                    mc.user_id as id,
                    o.name as avatar,
                    CONCAT(u.fname,' ', COALESCE(u.mname, ''), ' ', u.lname)::text as name,
                    COALESCE(SUM(
                        CASE
                            WHEN scp.finished_date IS NOT NULL THEN
                                -- base points
                                COALESCE(pt.base_points, 0)
                                +
                                -- bonus points calculation
                                (
                                    CASE
                                        -- Convert intervals to minutes
                                        WHEN FLOOR(EXTRACT(EPOCH FROM (scp.finished_date - scp.start_date)) / 60)::INT
                                             <= FLOOR(EXTRACT(EPOCH FROM cm.video_duration) / 60)::INT * 1.5
                                        THEN round(COALESCE(pt.base_points, 0) * 1.00)

                                        WHEN FLOOR(EXTRACT(EPOCH FROM (scp.finished_date - scp.start_date)) / 60)::INT
                                             <= FLOOR(EXTRACT(EPOCH FROM cm.video_duration) / 60)::INT * 2
                                        THEN round(COALESCE(pt.base_points, 0) * 0.30)

                                        WHEN FLOOR(EXTRACT(EPOCH FROM (scp.finished_date - scp.start_date)) / 60)::INT
                                             <= FLOOR(EXTRACT(EPOCH FROM cm.video_duration) / 60)::INT * 3
                                        THEN round(COALESCE(pt.base_points, 0) * 0.10)

                                        ELSE 0
                                    END
                                )
                            ELSE
                                0
                        END
                    ),0) AS points
                FROM my_courses mc
                    INNER JOIN internal.users u on u.user_id = mc.user_id
                        LEFT JOIN storage.objects o on o.id = u.profile_id
                    LEFT JOIN internal.student_cm_progress scp on mc.user_id = scp.user_id
                        LEFT JOIN internal.course_material cm on cm.material_id = scp.material_id
                            LEFT JOIN internal.lesson l on l.lesson_id = cm.lesson_id
                    LEFT JOIN point_tiers pt ON FLOOR(EXTRACT(EPOCH FROM cm.video_duration) / 60)::INT <@ pt.duration_range
                WHERE mc.version_id = dcrpt_version_id AND mc.enrollment_status = TRUE
                group by mc.user_id, u.fname, u.mname, u.lname, o.name

                UNION ALL

                SELECT
                    mc.user_id as id,
                    o.name as avatar,
                    CONCAT(u.fname,' ', COALESCE(u.mname, ''), ' ', u.lname)::text as name,
                    COALESCE((SUM(coalesce(sap.ctupia_xp, 0) + coalesce(sap.eval_points, 0)) FILTER ( WHERE completed_at IS NOT NULL)), 0) as points
                FROM my_courses mc
                INNER JOIN internal.users u on u.user_id = mc.user_id
                    LEFT JOIN storage.objects o on o.id = u.profile_id
                LEFT JOIN internal.student_ass_progress sap on u.user_id = sap.user_id
                    LEFT JOIN internal.assignment a on a.ass_id = sap.ass_id
                        LEFT JOIN internal.lesson l on l.lesson_id = a.lesson_id
                WHERE mc.version_id = dcrpt_version_id AND mc.enrollment_status = TRUE
                group by mc.user_id, u.fname, u.mname, u.lname, o.name

                UNION ALL

                SELECT
                    mc.user_id as id,
                    o.name as avatar,
                    CONCAT(u.fname,' ', COALESCE(u.mname, ''), ' ', u.lname)::text as name,
                    COALESCE((SUM(coalesce(str.ctupia_xp, 0)) FILTER ( WHERE completed_at IS NOT NULL )), 0) as points
                FROM my_courses mc
                INNER JOIN internal.users u on u.user_id = mc.user_id
                    LEFT JOIN storage.objects o on o.id = u.profile_id
                LEFT JOIN internal.student_test_record str on u.user_id = str.user_id
                    LEFT JOIN internal.test t on t.test_id = str.test_id
                        LEFT JOIN internal.lesson l on l.lesson_id = t.lesson_id
                WHERE mc.version_id = dcrpt_version_id AND mc.enrollment_status = TRUE
                group by mc.user_id, u.fname, u.mname, u.lname, o.name
            )
            SELECT
                encode(pgp_sym_encrypt(leaderboards.id::TEXT, internal.get_secret_key('view_leaderboards')),'base64')::text,
                leaderboards.avatar::text,
                leaderboards.name::text,
                SUM(leaderboards.points)::text as points,
                ROW_NUMBER() OVER (ORDER BY SUM(leaderboards.points) DESC)::text AS rank,
                CASE WHEN leaderboards.id = (SELECT users.user_id FROM users WHERE auth_id = auth.uid()) THEN TRUE ELSE FALSE END AS status
            FROM leaderboards
            GROUP BY leaderboards.id, leaderboards.name, leaderboards.avatar;

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
REVOKE ALL ON FUNCTION internal.view_leaderboards(IN p_leaderboards_id TEXT) FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION internal.view_leaderboards(IN p_leaderboards_id TEXT) TO authenticated;


-- TASK 11.) GIVE REVIEW AND RATING

CREATE OR REPLACE PROCEDURE internal.rate_course(
    IN p_rating_id TEXT,
    IN p_my_rating INT,
    IN p_my_review TEXT DEFAULT NULL
)
SET search_path = internal
AS $$
DECLARE
    dcrpt_enrollee_id INT;

    rows_updated int := NULL;
BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['student'])) = FALSE THEN
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    END IF;

    -- decrypt special_id
    BEGIN
        dcrpt_enrollee_id := pgp_sym_decrypt(
            decode(p_rating_id, 'base64'),
            get_secret_key('view_course')
        )::INT;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Valid Rating ID is required.'
            USING ERRCODE = 'P0043';
    END;

    IF p_my_rating < 1 AND p_my_rating > 5 THEN
        RAISE EXCEPTION 'Rating must be between 1 and 5.'
            USING ERRCODE = 'P0043';
    end if;

    IF (
        (SELECT get_progress(mc.user_id, mc.version_id)
        FROM my_courses mc
        WHERE enrollee_id = dcrpt_enrollee_id) < 100.00
    ) THEN
        RAISE EXCEPTION 'Please complete the course before leaving a rating. We value your feedback!'
            USING ERRCODE = 'P0043';
    end if;


    -- CHECK FIRST IF THIS STUDENT IS ENROLLED IN THIS COURSE
    IF EXISTS (
        SELECT 1
        FROM my_courses mc
        INNER JOIN internal.users u2 on u2.user_id = mc.user_id
        WHERE mc.enrollee_id = dcrpt_enrollee_id
        AND u2.auth_id = auth.uid()
    ) THEN

        UPDATE my_courses
        SET rating = p_my_rating,
            review = p_my_review,
            review_timestamp = COALESCE(review_timestamp, NOW())
        WHERE enrollee_id = dcrpt_enrollee_id AND user_id = (SELECT user_id FROM users WHERE auth_id = auth.uid());

        GET DIAGNOSTICS rows_updated = ROW_COUNT;
        IF rows_updated <= 0 THEN
            RAISE EXCEPTION 'We couldn’t submit your rating. Please try again later.'
                USING ERRCODE = 'P0010';
        end if;

    ELSE
        -- MEANS THAT  THEY'RE NOT ENROLLED
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    end if;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
REVOKE ALL ON PROCEDURE internal.rate_course(
    IN p_rating_id TEXT,
    IN p_my_rating INT,
    IN p_my_review TEXT
) FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE internal.rate_course(
    IN p_rating_id TEXT,
    IN p_my_rating INT,
    IN p_my_review TEXT
) TO authenticated;

--- SUBTASK 11.1) DELETE REVIEW AND RATING

CREATE OR REPLACE PROCEDURE internal.delete_review( IN p_rating_id TEXT)
SET search_path = internal
AS $$
DECLARE
    dcrpt_enrollee_id INT;
    rows_updated int := NULL;
BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['student'])) = FALSE THEN
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    END IF;

    -- decrypt special_id
    BEGIN
        dcrpt_enrollee_id := pgp_sym_decrypt(
            decode(p_rating_id, 'base64'),
            get_secret_key('view_course')
        )::INT;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Valid Rating ID is required.'
            USING ERRCODE = 'P0043';
    END;

    -- CHECK FIRST IF THIS STUDENT IS ENROLLED IN THIS COURSE
    IF EXISTS (
        SELECT 1
        FROM my_courses mc
        INNER JOIN internal.users u2 on u2.user_id = mc.user_id
        WHERE mc.enrollee_id = dcrpt_enrollee_id
        AND u2.auth_id = auth.uid()
    ) THEN

        UPDATE my_courses
        SET rating = NULL,
            review = NULL,
            review_timestamp = NULL
        WHERE enrollee_id = dcrpt_enrollee_id AND user_id = (SELECT user_id FROM users WHERE auth_id = auth.uid());

        DELETE FROM review_likes WHERE enrollee_id = dcrpt_enrollee_id;

    ELSE
        -- MEANS THAT  THEY'RE NOT ENROLLED
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    end if;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
REVOKE ALL ON PROCEDURE internal.delete_review( IN p_rating_id TEXT) FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE internal.delete_review( IN p_rating_id TEXT) TO authenticated;


--- SUBTASK 11.2) LIKE OR DISLIKE USER'S REVIEW

CREATE OR REPLACE PROCEDURE internal.react_review( IN p_review_id TEXT, IN p_reaction BOOLEAN)
SET search_path = internal
AS $$
DECLARE
    dcrpt_enrollee_id INT;
    f_user_id int := NULL;
BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['student'])) = FALSE THEN
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    END IF;

    -- decrypt special_id
    BEGIN
        dcrpt_enrollee_id := pgp_sym_decrypt(
            decode(p_review_id, 'base64'),
            get_secret_key('view_course')
        )::INT;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Valid Review ID is required.'
            USING ERRCODE = 'P0043';
    END;

    SELECT users.user_id INTO f_user_id FROM users WHERE auth_id = auth.uid();

    IF EXISTS (
        SELECT 1 FROM review_likes WHERE user_liker_id = f_user_id AND enrollee_id = dcrpt_enrollee_id
    ) THEN -- UPDATE

        IF p_reaction IS TRUE THEN -- LIKED
            UPDATE internal.review_likes
            SET reaction = 'like'
            WHERE user_liker_id = f_user_id AND enrollee_id = dcrpt_enrollee_id;

        ELSE -- DISLIKED
            UPDATE internal.review_likes
            SET reaction = 'dislike'
            WHERE user_liker_id = f_user_id AND enrollee_id = dcrpt_enrollee_id;

        end if;
    ELSE -- NEW INSERT
        IF p_reaction IS TRUE THEN -- LIKED
            INSERT INTO internal.review_likes (enrollee_id, user_liker_id, reaction)
                VALUES (dcrpt_enrollee_id,
                        (SELECT users.user_id FROM users WHERE auth_id = auth.uid()),
                        'like');
        ELSE -- DISLIKED
            INSERT INTO internal.review_likes (enrollee_id, user_liker_id, reaction)
                VALUES (dcrpt_enrollee_id,
                        (SELECT users.user_id FROM users WHERE auth_id = auth.uid()),
                        'dislike');
        end if;
    end if;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
REVOKE ALL ON PROCEDURE internal.react_review( IN p_review_id TEXT, IN p_reaction BOOLEAN) FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE internal.react_review( IN p_review_id TEXT, IN p_reaction BOOLEAN) TO authenticated;


--- SUBTASK 11.3) REMOVE LIKE FROM USER'S REVIEW

CREATE OR REPLACE PROCEDURE internal.delete_reaction( IN p_review_id TEXT)
SET search_path = internal
AS $$
DECLARE
    dcrpt_enrollee_id INT;
    f_user_id int := NULL;
BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['student'])) = FALSE THEN
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    END IF;

    -- decrypt special_id
    BEGIN
        dcrpt_enrollee_id := pgp_sym_decrypt(
            decode(p_review_id, 'base64'),
            get_secret_key('view_course')
        )::INT;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Valid Review ID is required.'
            USING ERRCODE = 'P0043';
    END;

    SELECT users.user_id INTO f_user_id FROM users WHERE auth_id = auth.uid();

    IF EXISTS (
        SELECT 1 FROM review_likes WHERE user_liker_id = f_user_id AND enrollee_id = dcrpt_enrollee_id
    ) THEN -- UPDATE

        DELETE FROM internal.review_likes WHERE user_liker_id = f_user_id AND enrollee_id = dcrpt_enrollee_id;
    end if;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
REVOKE ALL ON PROCEDURE internal.delete_reaction( IN p_review_id TEXT) FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE internal.delete_reaction( IN p_review_id TEXT) TO authenticated;


-- TASK 12. EXPLORE PROGRAMS

CREATE OR REPLACE FUNCTION internal.explore_programs()
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
BEGIN
    -- Only run main query if key exists and confirm the user role
    IF (
        (SELECT check_user_role(ARRAY['student'])) = TRUE AND
        internal.get_secret_key('explore_programs') IS NOT NULL) THEN
        RETURN QUERY
            SELECT DISTINCT ON (s.special_id)
                -- 1.) ID (encrypted)
                encode(
                    pgp_sym_encrypt(s.special_id::TEXT, internal.get_secret_key('explore_programs')),
                    'base64'
                )::TEXT,

                -- 2.) Program/Specialization name
                CASE
                    WHEN s.specialization IS NULL THEN
                        CONCAT(p.prog_name, ', ', p.prog_abbr)
                    ELSE
                        CONCAT(p.prog_name, ' major in ', s.specialization, ', ', p.prog_abbr, ' - ', s.special_abbr)
                END::TEXT,

                -- 3.) wallpaper name
                o.name::text,

                -- 4.) about
                coalesce(s.about, 'about this program..'),

                -- 5.) total reviews
                CASE
                    WHEN COUNT(mc.review) > 1 THEN COUNT(mc.review)::text ELSE COALESCE(COUNT(mc.review),0)::text
                END,

                -- 6.) -- rating
                CASE
                    WHEN COUNT(mc.rating) FILTER (WHERE mc.rating IS NOT NULL) >= 5
                        THEN ROUND(AVG(mc.rating)::numeric, 1)::text
                    ELSE '0'
                END::TEXT


            FROM specialization s
            INNER JOIN internal.program p on p.prog_id = s.prog_id
            INNER JOIN storage.objects o on o.id = s.wallpaper_id
            LEFT JOIN internal.prospectus p2 on s.special_id = p2.special_id
                LEFT JOIN internal.prospectus_course pc on p2.prospectus_id = pc.prospectus_id
                    LEFT JOIN internal.course_version cv on pc.pc_id = cv.version_id
                        LEFT JOIN internal.my_courses mc on cv.version_id = mc.version_id
            WHERE s.is_deleted IS FALSE
            group by s.special_id, p.prog_name, p.prog_abbr,  o.name;

    ELSE
        -- No secret key, return empty result set
        RETURN QUERY
        SELECT NULL::TEXT, NULL::TEXT, NULL::TEXT, NULL::TEXT, NULL::TEXT, NULL::TEXT
        WHERE FALSE;
    END IF;
END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION internal.explore_programs() FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION internal.explore_programs() TO authenticated;


-- SUBTASK 12.1 VIEW PROGRAM

CREATE OR REPLACE FUNCTION internal.view_program(IN p_program_id TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    dcrpt_special_id INT;
    faculties JSONB;
    metadata JSONB;
BEGIN
    -- decrypt special_id
    BEGIN
        dcrpt_special_id := pgp_sym_decrypt(
            decode(p_program_id, 'base64'),
            get_secret_key('explore_programs') -- if screen from enrolled courses
        )::INT;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Valid Program ID is required.'
            USING ERRCODE = 'P0043';
    END;

    WITH fac AS(
            SELECT
            u.user_id AS id,
            o.name as avatar,
            CONCAT(u.fname, ' ', COALESCE(u.mname, ''), ' ', u.lname)::text as name,
            (SELECT concat(COALESCE(COUNT(cvf1.version_id), 0), ' course(s)')
                        FROM course_version_faculty cvf1
                        INNER JOIN internal.course_version c on c.version_id = cvf1.version_id
                        WHERE cvf1.user_id = u.user_id
                            AND c.is_ready IS TRUE
                            AND c.apvd_rvwd_by IS NOT NULL) as courses,
            (SELECT concat(COALESCE(COUNT(DISTINCT mc1.user_id), 0), ' student(s)')
                        FROM my_courses mc1
                        INNER JOIN internal.course_version_faculty cvf2 on mc1.version_id = cvf2.version_id
                        INNER JOIN internal.course_version c2 on c2.version_id = cvf2.version_id
                        WHERE cvf2.user_id = u.user_id
                            AND c2.is_ready IS TRUE
                            AND c2.apvd_rvwd_by IS NOT NULL) as students
        FROM prospectus_course pc
        INNER JOIN internal.course_version cv on pc.pc_id = cv.version_id
            INNER JOIN internal.course_version_faculty cvf on cv.version_id = cvf.version_id
                INNER JOIN internal.users u on u.user_id = cvf.user_id
                    INNER JOIN storage.objects o on o.id = u.profile_id
        WHERE pc.prospectus_id = (SELECT prospectus_id FROM prospectus WHERE special_id = dcrpt_special_id AND is_deleted IS FALSE ORDER BY date_created DESC LIMIT 1)
        group by u.user_id, u.fname, u.mname, u.lname, o.name
    )
     SELECT
         json_agg(
            jsonb_build_object(
                    'faculty_id', encode(
                    pgp_sym_encrypt(fac.id::TEXT, internal.get_secret_key('view_program')),
                    'base64'
                                  )::TEXT,
                    'avatar', fac.avatar,
                    'faculty_name', fac.name,
                    'courses', fac.courses,
                    'students', fac.students
            )
         ) INTO faculties
    FROM fac;

    SELECT DISTINCT ON (s.special_id)
        jsonb_build_object(
        'is_enrolled', COALESCE((
                SELECT
                    mc1.enrollment_status
                FROM my_courses mc1
                INNER JOIN users u5 ON u5.user_id = mc1.user_id
                LEFT JOIN prospectus_course pc5 ON pc5.pc_id = mc1.version_id
                LEFT JOIN prospectus_semester ps5 ON ps5.prosem_id = pc5.prosem_id
                WHERE mc1.version_id = mc.version_id AND now()::date <@ ps5.duration LIMIT 1
            ), FALSE),
        'program_id',   encode(
                            pgp_sym_encrypt(s.special_id::TEXT, internal.get_secret_key('view_program')),
                            'base64'
                        )::TEXT,

        'program_name', CASE
                            WHEN s.specialization IS NULL THEN
                                CONCAT(p.prog_name, ', ', p.prog_abbr)
                            ELSE
                                CONCAT(p.prog_name, ' major in ', s.specialization, ', ', p.prog_abbr, ' - ', s.special_abbr)
                        END::TEXT,
        'wallpaper',    o.name::text,
        'about',    '',
        'reviews',  CASE
                        WHEN COUNT(mc.review) > 1 THEN COUNT(mc.review)::text ELSE COALESCE(COUNT(mc.review),0)::text
                    END,
        'rating',   CASE
                        WHEN COUNT(mc.rating) FILTER (WHERE mc.rating IS NOT NULL) >= 5
                            THEN ROUND(AVG(mc.rating)::numeric, 1)::text
                        ELSE '0'
                    END::TEXT,
        'learning_level', 'All Levels',
        'number_of_courses',    (
                                    SELECT COALESCE(COUNT(pc2.pc_id), 0)
                                    FROM prospectus_course pc2
                                    LEFT JOIN internal.prospectus p3 on p3.prospectus_id = pc2.prospectus_id
                                    WHERE p3.prospectus_id = (
                                        SELECT prospectus_id
                                        FROM prospectus
                                        WHERE special_id = s.special_id
                                        AND is_deleted IS FALSE
                                        ORDER BY date_created DESC
                                        LIMIT 1
                                        )
                                )::TEXT,
        'prospectus_id', (
                            SELECT
                                encode(
                                    pgp_sym_encrypt(prospectus_id::TEXT, internal.get_secret_key('view_program')),
                                    'base64'
                                )::TEXT
                            FROM prospectus
                            WHERE special_id = s.special_id AND is_deleted IS FALSE
                            ORDER BY date_created DESC LIMIT 1
                        ),
        'faculties', COALESCE(faculties, '[]'::jsonb),
        'what_to_learn', ARRAY[
                                'Collect, clean, sort, evaluate, and visualize data',
                                'Apply the OSEMN, framework to guide the data analysis process, ' ||
                                'ensuring a comprehensive and structured approach to deriving actionable insights',
                                'Use statistical analysis, including hypothesis testing, regression analysis, and more, to make data-driven decisions',
                                'Develop an understanding of the foundational principles of effective data management and usability of data assets within organizational context'
                            ],
        'overview', coalesce(s.about, 'about this program..'),
        'skills_to_gain', ARRAY['Data Management', 'Spreadsheet Software', 'Data Collection', 'Data Storytelling', 'Data Analysis'],
        'tools_to_learn', ARRAY['Data Analysis', 'Python Programming'],
        'inclusion', ARRAY['Shareable certificate', 'Taught in English', '108 practice exercises']
    ) INTO metadata
    FROM specialization s
    INNER JOIN internal.program p on p.prog_id = s.prog_id
    INNER JOIN storage.objects o on o.id = s.wallpaper_id
    LEFT JOIN internal.prospectus p2 on s.special_id = p2.special_id
        LEFT JOIN internal.prospectus_course pc on p2.prospectus_id = pc.prospectus_id
            LEFT JOIN internal.course_version cv on pc.pc_id = cv.version_id
                LEFT JOIN internal.my_courses mc on cv.version_id = mc.version_id
    WHERE s.special_id = dcrpt_special_id
    group by s.special_id, p.prog_name, p.prog_abbr,  o.name, mc.version_id;

    RETURN metadata;

END;
$$; -- NEW
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION internal.view_program(IN p_program_id TEXT) FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION internal.view_program(IN p_program_id TEXT) TO authenticated;


-- SUBTASK 12.2 TOP MOST OFFERED PROGRAMS

CREATE OR REPLACE FUNCTION internal.top_offers()
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
BEGIN
    -- Only run main query if key exists and confirm the user role
    IF (
        (SELECT check_user_role(ARRAY['student'])) = TRUE AND
        internal.get_secret_key('explore_programs') IS NOT NULL) THEN
        RETURN QUERY
            SELECT DISTINCT ON (s.special_id)
                -- 1.) ID (encrypted)
                encode(
                    pgp_sym_encrypt(s.special_id::TEXT, internal.get_secret_key('explore_programs')),
                    'base64'
                )::TEXT,

                -- 2.) Program/Specialization name
                CASE
                    WHEN s.specialization IS NULL THEN
                        CONCAT(p.prog_name, ', ', p.prog_abbr)
                    ELSE
                        CONCAT(p.prog_name, ' major in ', s.specialization, ', ', p.prog_abbr, ' - ', s.special_abbr)
                END::TEXT,

                -- 3.) wallpaper name
                o.name::text,

                -- 4.) about
                coalesce(s.about, 'about this program..'),

                -- 5.) total reviews
                CASE
                    WHEN COUNT(mc.review) > 1 THEN COUNT(mc.review)::text ELSE COALESCE(COUNT(mc.review),0)::text
                END,

                -- 6.) -- rating
                CASE
                    WHEN COUNT(mc.rating) FILTER (WHERE mc.rating IS NOT NULL) >= 5
                        THEN ROUND(AVG(mc.rating)::numeric, 1)::text
                    ELSE '0'
                END::TEXT as ratinggg
            FROM specialization s
            INNER JOIN internal.program p on p.prog_id = s.prog_id
            INNER JOIN storage.objects o on o.id = s.wallpaper_id
            LEFT JOIN internal.prospectus p2 on s.special_id = p2.special_id
                LEFT JOIN internal.prospectus_course pc on p2.prospectus_id = pc.prospectus_id
                    LEFT JOIN internal.course_version cv on pc.pc_id = cv.version_id
                        LEFT JOIN internal.my_courses mc on cv.version_id = mc.version_id
            WHERE s.is_deleted is false
            group by s.special_id, p.prog_name, p.prog_abbr, o.name
            order by s.special_id, ratinggg limit 8;

    ELSE
        -- No secret key, return empty result set
        RETURN QUERY
        SELECT NULL::TEXT, NULL::TEXT, NULL::TEXT, NULL::TEXT, NULL::TEXT, NULL::TEXT
        WHERE FALSE;
    END IF;
END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION internal.top_offers() FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION internal.top_offers() TO authenticated;

-- SUBTASK 12.3 Recently added courses

CREATE OR REPLACE FUNCTION internal.recently_added_courses()
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
BEGIN

    -- Only run main query if key exists and confirm the user role
    IF (
        (SELECT check_user_role(ARRAY['student'])) = TRUE AND
        internal.get_secret_key('recently_added_courses') IS NOT NULL) THEN
        RETURN QUERY
            SELECT
            -- 1.) ID (encrypted)
            encode(
                pgp_sym_encrypt(mc.version_id::TEXT, internal.get_secret_key('recently_added_courses')),
                'base64'
            )::TEXT,

            -- course name
            c.crs_title::text,

            -- course code
            pc.crs_code::text,

            -- semester
            s.sem_name::text,

            -- wallpaper
            o.name::text,

            -- lessons left
            concat('N',' out of ', count(l.lesson_id), ' lessons'),

            -- progress
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
                )::TEXT


        FROM my_courses mc
        INNER JOIN internal.users u on u.user_id = mc.user_id
        INNER JOIN internal.course_version cv on cv.version_id = mc.version_id
        INNER JOIN storage.objects o on o.id = cv.wallpaper_id
        INNER JOIN internal.prospectus_course pc on pc.pc_id = cv.version_id
        INNER JOIN internal.course c on c.crs_id = pc.crs_id
        LEFT JOIN internal.prospectus_semester ps on ps.prosem_id = pc.prosem_id
        LEFT JOIN internal.semester s ON s.sem_id = ps.sem_id
        INNER JOIN internal.prospectus p2 on pc.prospectus_id = p2.prospectus_id
        INNER JOIN internal.specialization s2 on s2.special_id = p2.special_id
        INNER JOIN lesson l on l.version_id = mc.version_id
            WHERE u.auth_id = auth.uid()
              AND cv.apvd_rvwd_by IS NOT NULL
              AND mc.enrollment_status = TRUE
              AND (now()::date >= lower(ps.duration) AND now()::date <= upper(ps.duration) + INTERVAL '1 year')
            group by mc.user_id, mc.version_id, s.sem_name, pc.crs_code, c.crs_title, mc.version_id, o.name, mc.enrld_date
            order by mc.enrld_date DESC LIMIT 5;
    ELSE
        -- No secret key, return empty result set
        RETURN QUERY
        SELECT NULL::TEXT, NULL::TEXT, NULL::TEXT, NULL::TEXT, NULL::TEXT, NULL::TEXT, NULL::TEXT
        WHERE FALSE;
    END IF;
END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION internal.recently_added_courses() FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION internal.recently_added_courses() TO authenticated;


-- SUBTASK 12.4 Recent work

CREATE OR REPLACE FUNCTION internal.get_last_course_interaction()
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
BEGIN

    -- Only run main query if key exists and confirm the user role
    IF (
        (SELECT check_user_role(ARRAY['student'])) = TRUE AND
        internal.get_secret_key('get_last_course_interaction') IS NOT NULL) THEN
        RETURN QUERY
            SELECT
            -- 1.) ID (encrypted)
            encode(
                pgp_sym_encrypt(mc.version_id::TEXT, internal.get_secret_key('get_last_course_interaction')),
                'base64'
            )::TEXT,

            -- course name
            c.crs_title::text,

            -- course code
            pc.crs_code::text,

            -- semester
            s.sem_name::text,

            -- wallpaper
            o.name::text,

            -- lessons left
            concat('N',' out of ', count(l.lesson_id), ' lessons'),

            -- progress
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
                )::TEXT


        FROM my_courses mc
        INNER JOIN internal.users u on u.user_id = mc.user_id
        INNER JOIN internal.course_version cv on cv.version_id = mc.version_id
        INNER JOIN storage.objects o on o.id = cv.wallpaper_id
        INNER JOIN internal.prospectus_course pc on pc.pc_id = cv.version_id
        INNER JOIN internal.course c on c.crs_id = pc.crs_id
        LEFT JOIN internal.prospectus_semester ps on ps.prosem_id = pc.prosem_id
        LEFT JOIN internal.semester s ON s.sem_id = ps.sem_id
        INNER JOIN internal.prospectus p2 on pc.prospectus_id = p2.prospectus_id
        INNER JOIN internal.specialization s2 on s2.special_id = p2.special_id
        INNER JOIN lesson l on l.version_id = mc.version_id
        INNER JOIN internal.course_activity a on cv.version_id = a.version_id
            WHERE u.auth_id = auth.uid()
              AND cv.apvd_rvwd_by IS NOT NULL
              AND mc.enrollment_status = TRUE
              AND (now()::date >= lower(ps.duration) AND now()::date <= upper(ps.duration) + INTERVAL '1 year')
              AND mc.version_id = (
                                    SELECT ca.version_id
                                    FROM course_activity ca
                                    INNER JOIN internal.users u2 on u2.user_id = ca.sender_id
                                    INNER JOIN internal.my_courses mc
                                      ON ca.version_id = mc.version_id
                                      AND ca.sender_id = mc.user_id   -- ✅ critical!
                                    WHERE u2.auth_id = auth.uid()
                                    AND ca.version_id IS NOT NULL
                                    AND mc.enrollment_status IS TRUE
                                    ORDER BY ca.created_at DESC LIMIT 1
                                )
            group by mc.user_id, mc.version_id, s.sem_name, pc.crs_code, c.crs_title, mc.version_id, o.name, mc.enrld_date
            order by mc.enrld_date DESC LIMIT 1;
    ELSE
        -- No secret key, return empty result set
        RETURN QUERY
        SELECT NULL::TEXT, NULL::TEXT, NULL::TEXT, NULL::TEXT, NULL::TEXT, NULL::TEXT, NULL::TEXT
        WHERE FALSE;
    END IF;
END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION internal.get_last_course_interaction() FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION internal.get_last_course_interaction() TO authenticated;


-- TASK 13. get_certificate

CREATE OR REPLACE FUNCTION internal.get_certificate(IN p_certificate_id TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    dcrpt_enrollee_id INT;
    f_version_id INT;
    f_user_id INT;
    f_enrollment_status boolean;
    certificate_data JSONB;
    student_progress NUMERIC (5,2);

BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['student'])) = FALSE THEN
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    END IF;

    -- decrypt special_id
    BEGIN
        dcrpt_enrollee_id := pgp_sym_decrypt(
            decode(p_certificate_id, 'base64'),
            get_secret_key('view_course')
        )::INT;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Valid Certificate ID is required.'
            USING ERRCODE = 'P0043';
    END;

    SELECT version_id, user_id, enrollment_status INTO f_version_id, f_user_id, f_enrollment_status
    FROM my_courses
    WHERE enrollee_id = dcrpt_enrollee_id;

    IF f_enrollment_status IS FALSE THEN
        RAISE EXCEPTION '⚠️ You can’t request a certificate for this course because you’re not currently enrolled or you’ve dropped this course. Please enroll again to become eligible for a certificate.'
            USING ERRCODE = 'P0065';
    end if;

    IF get_progress(f_user_id, f_version_id) >= 99.99 THEN
        SELECT
            jsonb_build_object(
                'id', substring(encode(digest(mc.enrollee_id::text || 'ctupia_salt','sha256'),'base64') from 1 for 8),
                'name', CONCAT(u.fname,' ', COALESCE(u.mname, ''), ' ', u.lname)::text,
                'course', c.crs_title,
                'completion_date', (
                    SELECT created_at::date
                    FROM course_activity
                    WHERE sender_id = f_user_id
                    AND version_id = f_version_id
                    AND (metadata ->> 'course_completion_rate')::numeric >= 99.99 LIMIT 1
                    )
            ) INTO certificate_data
        FROM my_courses mc
        INNER JOIN internal.users u on u.user_id = mc.user_id
        INNER JOIN prospectus_course pc on pc.pc_id = mc.version_id
        INNER JOIN internal.course c on c.crs_id = pc.crs_id
        WHERE enrollee_id = dcrpt_enrollee_id;

        RETURN certificate_data;

    ELSE
        RAISE EXCEPTION 'Almost there! Complete the course to unlock your certificate.'
            USING ERRCODE = 'P0065';
    end if;


END;
$$; -- NEW
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION internal.get_certificate(IN p_certificate_id TEXT) FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION internal.get_certificate(IN p_certificate_id TEXT) TO authenticated;


-- TASK 14. get_completed_lessons

CREATE OR REPLACE FUNCTION internal.get_completed_lessons(
    IN p_user_id INT,
    IN p_version_id INT
)
RETURNS INT[]
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    completed_lessons INT[];
BEGIN
    -- Only run main query if key exists and confirm the user role
    IF (
        (SELECT check_user_role(ARRAY['faculty', 'dean', 'admin', 'student'])) = TRUE
        AND internal.get_secret_key('get_progress') IS NOT NULL
    ) THEN

        WITH all_progress AS (
            SELECT DISTINCT ON (cm1.material_id)
                l1.lesson_id,
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
                AND scp1.user_id = p_user_id
            WHERE cv1.version_id = p_version_id
              AND cm1.video_duration IS NOT NULL

            UNION ALL

            SELECT DISTINCT ON (a2.ass_id)
                l2.lesson_id,
                CASE
                    WHEN sap2.sap_id IS NULL THEN 'not started'
--                     WHEN sap2.sap_id IS NOT NULL AND sap2.completed_at IS NULL THEN 'pending'
--                     WHEN sap2.sap_id IS NOT NULL AND sap2.completed_at IS NOT NULL THEN 'finished'
                    WHEN sap2.sap_id IS NOT NULL THEN 'finished'
                END AS progress3
            FROM internal.course_version cv2
            INNER JOIN internal.lesson l2 ON cv2.version_id = l2.version_id
            INNER JOIN internal.assignment a2 ON l2.lesson_id = a2.lesson_id
            LEFT JOIN internal.student_ass_progress sap2
                ON a2.ass_id = sap2.ass_id
                AND sap2.user_id = p_user_id
            WHERE cv2.version_id = p_version_id

            UNION ALL

            SELECT DISTINCT ON (t3.test_id)
                l3.lesson_id,
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
                AND str3.user_id = p_user_id
            WHERE cv3.version_id = p_version_id
        )
        SELECT ARRAY_AGG(lesson_id ORDER BY lesson_id)
        INTO completed_lessons
        FROM (
            SELECT lesson_id
            FROM all_progress
            GROUP BY lesson_id
            HAVING BOOL_AND(progress3 = 'finished')
        ) AS finished_lessons;

        -- Return empty array if no completed lessons
        RETURN COALESCE(completed_lessons, '{}');

    ELSE
        RETURN '{}';
    END IF;
END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION internal.get_completed_lessons(INT, INT) FROM PUBLIC;
-- ✅ Grant to trusted internal roles
GRANT EXECUTE ON FUNCTION internal.get_completed_lessons(INT, INT)
TO authenticated;


-- TASK 15. CLAIM POINTS FOR ACCOMPLISHING WATCHING VIDEO, ASSIGNMENT, EXAM [HALTED]

