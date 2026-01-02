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

-- TASK 1._ Admin Dashboard

CREATE OR REPLACE FUNCTION internal.admin_dashboard()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    cards JSONB;
    weekly_logins JSONB;
    role_distro JSONB;
BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['admin'])) = FALSE THEN
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    END IF;

    SELECT
        jsonb_build_object(
            'total_users', COUNT(u.*),
            'active_users', COUNT(u.*) FILTER ( WHERE u.is_active IS TRUE ),
            'inactive_users', COUNT(u.*) FILTER ( WHERE u.is_active IS FALSE AND a.banned_until IS NOT NULL),
            'suspended_users', COUNT(u.*) FILTER ( WHERE u.is_active IS TRUE AND a.banned_until IS NOT NULL),
            'new_users', COUNT(u.*) FILTER ( WHERE date_trunc('month', u.date_added) = date_trunc('month', CURRENT_DATE) )
    ) INTO cards
    FROM users u
    LEFT JOIN auth.users a ON a.id = U.auth_id;

    WITH t as (
        SELECT date_trunc ('week', created_at)::date AS week,
               COUNT(*) AS total_logins
        FROM course_activity
        WHERE type = 'login-trail'
        GROUP BY 1
        ORDER BY week DESC
    )
    SELECT json_agg(
            jsonb_build_object(
                'week', t.week,
                'total_logins', t.total_logins
            ) ORDER BY week DESC
    ) INTO weekly_logins
    FROM t;

    WITH t as (
        SELECT
            d.dar_name as role,
            COUNT(u.*) as total_users,
            ROUND((COUNT(u.*) * 100.0 / SUM(COUNT(u.*)) over ()), 2) as percentage
        FROM designation_and_role d
        INNER JOIN internal.users u on d.dar_id = u.dar_id
        group by d.dar_name
    )
    SELECT json_agg(
            jsonb_build_object(
                'role', t.role,
                'total_logins', t.total_users,
                'percentage', t.percentage
            )
    ) INTO role_distro
    FROM t;

    RETURN jsonb_build_object(
        'cards', coalesce(cards, '[]'::jsonb),
        'weekly_logins', coalesce(weekly_logins, '[]'::jsonb),
        'role_distribution', coalesce(role_distro, '[]'::jsonb)
    );

END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION internal.admin_dashboard() FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION internal.admin_dashboard() TO authenticated;



-- TASK 2._ Dean Dashboard


CREATE OR REPLACE FUNCTION internal.dean_dashboard()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    f_cao_id INT;
    f_dean_id INT;
    card_a JSONB;
    card_b JSONB;
    card_c JSONB;
    enrollment_trend JSONB;
    top_10_popular_courses_by_enroll_count JSONB;
    top_10_popular_programs_by_enroll_count JSONB;
    top_10_most_engaged_courses JSONB;
BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['dean'])) = FALSE THEN
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    END IF;

    -- GET DEAN ID AND COLLEGE
    SELECT
        user_id,
        cao_id
    INTO f_dean_id, f_cao_id
    FROM users
    WHERE auth_id = auth.uid();

    WITH c as (
        SELECT
            COUNT(u.*) FILTER ( WHERE d.dar_name = 'faculty' ) as faculty,
            COUNT(u.*) FILTER ( WHERE d.dar_name = 'student' ) as student,
            COUNT(u.*) FILTER ( WHERE date_trunc('month', u.date_added) = date_trunc('month', CURRENT_DATE) AND created_by = f_dean_id) as new_users
        FROM users u
        INNER JOIN internal.designation_and_role d on d.dar_id = u.dar_id
        WHERE u.is_active = TRUE AND cao_id = f_cao_id
    )
    SELECT
        jsonb_build_object(
            'faculty', c.faculty,
            'student', c.student,
            'new_users_this_month', c.new_users
        ) INTO card_a
    FROM c;

    WITH c as (
        SELECT
            COUNT(*) as programs
        FROM specialization
        WHERE is_deleted IS FALSE AND cao_id = f_cao_id
    )
    SELECT
        jsonb_build_object(
            'programs', c.programs
    ) INTO card_b
    FROM c;

    WITH c as (
        SELECT
            COUNT(pc.*) FILTER ( WHERE cv.is_ready IS TRUE AND cv.apvd_rvwd_by IS NOT NULL AND now()::date <@ ps.duration ) as active_courses,
            COUNT(pc.*) FILTER ( WHERE cv.is_ready IS TRUE AND cv.apvd_rvwd_by IS NULL AND (now()::date < lower(ps.duration) or now()::date <@ ps.duration)) as pending_courses
        FROM prospectus_course pc
        LEFT JOIN internal.course_version cv on pc.pc_id = cv.version_id
        inner join internal.prospectus_semester ps on ps.prosem_id = pc.prosem_id
        INNER JOIN internal.prospectus p on p.prospectus_id = pc.prospectus_id
        INNER JOIN internal.specialization s on p.special_id = s.special_id
        WHERE s.is_deleted IS FALSE
          AND p.is_deleted IS FALSE
          AND s.cao_id = f_cao_id
    )
    SELECT
        jsonb_build_object(
            'active_courses', active_courses,
            'pending_courses', pending_courses
    ) INTO card_c
    FROM c;


    WITH c as (
        SELECT year,
               COUNT(*) AS total_enrollments,
               COUNT(*) FILTER (WHERE dar_name = 'dean') AS by_dean,
               COUNT(*) FILTER (WHERE dar_name = 'faculty') AS by_faculty
        FROM (
            SELECT
                EXTRACT(YEAR FROM mc.enrld_date)::int AS year,
                dar.dar_name
            FROM my_courses mc
            INNER JOIN internal.users u2 ON u2.user_id = mc.enrld_by
            INNER JOIN internal.designation_and_role dar ON dar.dar_id = u2.dar_id
            INNER JOIN internal.prospectus_course pc ON pc.pc_id = mc.version_id
            INNER JOIN internal.prospectus p2 ON p2.prospectus_id = pc.prospectus_id
            INNER JOIN internal.specialization s2 ON p2.special_id = s2.special_id
            WHERE s2.cao_id = f_cao_id
        ) sub
        GROUP BY year
        ORDER BY year
    )
    SELECT json_agg(
               jsonb_build_object(
                   'total_enrollments', c.total_enrollments,
                   'by_dean', c.by_dean,
                   'by_faculty', c.by_faculty
               ) ORDER BY c.year
           ) INTO enrollment_trend
    FROM c;

    WITH c as (
        SELECT
            c2.crs_title as course,
            COUNT(mc.user_id) AS total_enrollments
        FROM my_courses mc
        INNER JOIN internal.prospectus_course pc ON pc.pc_id = mc.version_id
        INNER JOIN internal.course c2 on c2.crs_id = pc.crs_id
        INNER JOIN internal.prospectus p2 ON p2.prospectus_id = pc.prospectus_id
        INNER JOIN internal.specialization s2 ON p2.special_id = s2.special_id
        WHERE s2.cao_id = f_cao_id
        GROUP BY mc.version_id, c2.crs_title
        ORDER BY total_enrollments DESC
        LIMIT 10  -- top 10 courses
    )
    SELECT json_agg(
           jsonb_build_object(
                'course', c.course,
                'total_enrollments', c.total_enrollments
           )
        ) INTO top_10_popular_courses_by_enroll_count
    FROM c;

    WITH c as (
        SELECT
            CASE
                WHEN s2.specialization IS NULL THEN
                    CONCAT(p3.prog_name, ', ', p3.prog_abbr)
                ELSE
                    CONCAT(p3.prog_name, ' major in ', s2.specialization, ', ',
                        p3.prog_abbr, ' - ', s2.special_abbr)
            END::TEXT AS program,
            COUNT(m.user_id) AS total_enrollments
        FROM specialization s2
        INNER JOIN internal.program p3 on p3.prog_id = s2.prog_id
        LEFT JOIN internal.prospectus p2 ON p2.special_id = s2.special_id
        LEFT JOIN internal.prospectus_course pc ON pc.prospectus_id = p2.prospectus_id
        LEFT JOIN internal.course_version v on pc.pc_id = v.version_id
        LEFT JOIN internal.my_courses m on v.version_id = m.version_id
        WHERE s2.cao_id = f_cao_id
        GROUP BY p3.prog_name, s2.specialization, p3.prog_abbr, s2.special_abbr
        ORDER BY total_enrollments DESC
        LIMIT 10  -- top 10 courses
    )
    SELECT json_agg(
           jsonb_build_object(
                'program', c.program,
                'total_enrollments', c.total_enrollments
           )
        ) INTO top_10_popular_programs_by_enroll_count
    FROM c;

--     WITH c as (
--         SELECT
--             c3.crs_title as course,
--             mc.user_id as student,
--             mc.version_id as version_id,
--             get_progress(mc.user_id, mc.version_id) as progress
--         FROM my_courses mc
--         INNER JOIN internal.course_version cv2 on cv2.version_id = mc.version_id
--         INNER JOIN internal.prospectus_course pc2 ON pc2.pc_id = cv2.version_id
--             INNER JOIN internal.course c3 on pc2.crs_id = c3.crs_id
--             INNER JOIN internal.prospectus p4 on p4.prospectus_id = pc2.prospectus_id
--                 INNER JOIN internal.specialization s3 on p4.special_id = s3.special_id
--         WHERE s3.cao_id = 1
--         AND p4.is_deleted IS FALSE
--         AND s3.is_deleted IS FALSE
--     )
--     SELECT json_agg(
--            jsonb_build_object(
--             'course', c.course,
--             'student', c.student,
--             'version_id', c.version_id,
--             'progress', c.progress
--            )
--         ) INTO top_10_least_engaged_courses
--     FROM c;

    WITH c AS (
        SELECT
            pc.pc_id,
            c2.crs_title AS course,
            COUNT(mc.user_id) AS total_enrollments,
            COUNT(mc.user_id) FILTER (WHERE get_progress(mc.user_id, pc.pc_id) = 100)::float
                / COUNT(mc.user_id) * 100 AS completion_rate
        FROM my_courses mc
            INNER JOIN internal.prospectus_course pc ON pc.pc_id = mc.version_id
            INNER JOIN internal.course c2 ON c2.crs_id = pc.crs_id
            INNER JOIN internal.prospectus p2 ON p2.prospectus_id = pc.prospectus_id
            INNER JOIN internal.specialization s2 ON p2.special_id = s2.special_id
        WHERE s2.cao_id = f_cao_id
        GROUP BY pc.pc_id, c2.crs_title
        ORDER BY completion_rate DESC
        LIMIT 10
    )
    SELECT json_agg(
            jsonb_build_object(
                'course', c.course,
                'total_enrollments', c.total_enrollments,
                'completion_rate', c.completion_rate
           )
        ) INTO top_10_most_engaged_courses
    FROM c;



    RETURN jsonb_build_object(
        'card_a', coalesce(card_a, '[]'::jsonb),
        'card_b', coalesce(card_b, '[]'::jsonb),
        'card_c', coalesce(card_c, '[]'::jsonb),
        'enrollment_trends', coalesce(enrollment_trend, '[]'::jsonb),
        'top_10_popular_programs_by_enroll_count', coalesce(top_10_popular_programs_by_enroll_count, '[]'::jsonb),
        'top_10_popular_courses_by_enroll_count', coalesce(top_10_popular_courses_by_enroll_count, '[]'::jsonb),
        'top_10_most_engaged_courses', coalesce(top_10_most_engaged_courses, '[]'::jsonb)
    );

END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION internal.dean_dashboard() FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION internal.dean_dashboard() TO authenticated;




-- TASK 3._ Faculty Dashboard

CREATE OR REPLACE FUNCTION internal.faculty_dashboard()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    f_faculty_id INT;
    active_courses INT;
    total_students_handled JSONB;
    student_performance_metric JSONB;
    grades_distro JSONB;
    per_course_metrics JSONB;
BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['faculty'])) = FALSE THEN
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    END IF;

    -- GET FACULTY ID
    SELECT
        user_id
    INTO f_faculty_id
    FROM users
    WHERE auth_id = auth.uid();

    SELECT
        COUNT(*) INTO active_courses
    FROM course_version_faculty cvf
    INNER JOIN internal.course_version cv on cv.version_id = cvf.version_id
    INNER JOIN internal.prospectus_course pc on pc.pc_id = cv.version_id
    INNER JOIN internal.prospectus_semester ps on ps.prosem_id = pc.prosem_id
    WHERE now()::date <@ ps.duration AND cv.is_ready IS TRUE AND cv.apvd_rvwd_by IS NOT NULL
    AND cvf.user_id = f_faculty_id;

    WITH t AS (
        SELECT
            COUNT(*) FILTER ( WHERE now()::date > lower(ps.duration) ) as total_students,
            COUNT(*) FILTER ( WHERE mc.enrollment_status IS TRUE
                                        AND get_progress(mc.user_id, mc.version_id) = 100.00
                                        AND get_grade(mc.user_id, mc.version_id) <= 3.0) AS passed,
            count(*) FILTER ( WHERE mc.enrollment_status IS TRUE
                                        AND get_progress(mc.user_id, mc.version_id) = 100.00
                                        AND get_grade(mc.user_id, mc.version_id) > 3.0 ) AS failed,
            count(*) FILTER ( WHERE mc.enrollment_status IS TRUE
                                        AND get_progress(mc.user_id, mc.version_id) < 100.00
                                        AND now()::date <= upper(ps.duration) + INTERVAL '1 year' ) AS in_progress,
            count(*) FILTER ( WHERE mc.enrollment_status IS FALSE ) as dropped
        FROM course_version_faculty cvf
        INNER JOIN internal.course_version cv on cv.version_id = cvf.version_id
        LEFT JOIN internal.my_courses mc on mc.version_id = cv.version_id
        INNER JOIN internal.prospectus_course pc on pc.pc_id = cv.version_id
        INNER JOIN internal.prospectus_semester ps on ps.prosem_id = pc.prosem_id
        WHERE now()::date >= lower(ps.duration) AND cv.is_ready IS TRUE AND cv.apvd_rvwd_by IS NOT NULL
        AND cvf.user_id = f_faculty_id
    )
    SELECT jsonb_build_object(
        'total_students', t.total_students,
        'total_passed', jsonb_build_object(
            'count', t.passed,
            'percentage', coalesce(ROUND(((t.passed::float / NULLIF(t.total_students, 0)) * 100)::numeric, 2), 0.0)
        ),
        'total_failed', jsonb_build_object(
            'count', t.failed,
            'percentage', coalesce(ROUND(((t.failed::float / NULLIF(t.total_students, 0)) * 100)::numeric, 2), 0.0)
        ),
        'total_in_progress', jsonb_build_object(
            'count', t.in_progress,
            'percentage', coalesce(ROUND(((t.in_progress::float / NULLIF(t.total_students, 0)) * 100)::numeric, 2), 0.0)
        ),
        'total_dropped', jsonb_build_object(
            'count', t.dropped,
            'percentage', coalesce(ROUND(((t.dropped::float / NULLIF(t.total_students, 0)) * 100)::numeric, 2), 0.0)
        )

    ) INTO total_students_handled
    FROM t;


    WITH t AS (
        SELECT
            (COUNT(*) FILTER (WHERE get_progress(mc.user_id, mc.version_id) = 100)::float
                 / NULLIF(COUNT(*), 0) * 100)::NUMERIC(5,2) AS avg_completion_rate,
            (COUNT(*) FILTER (WHERE get_progress(mc.user_id, mc.version_id) = 100
                              AND get_grade(mc.user_id, mc.version_id) <= 3.0)::float
                 / NULLIF(COUNT(*), 0) * 100)::NUMERIC(5,2) AS avg_passing_rate,
            AVG(get_grade(mc.user_id, mc.version_id))::NUMERIC(2,1) AS avg_grade
        FROM my_courses mc
        INNER JOIN internal.course_version c ON c.version_id = mc.version_id
        LEFT JOIN internal.course_version_faculty f ON c.version_id = f.version_id
        WHERE f.user_id = f_faculty_id
    )
    SELECT jsonb_build_object(
               'avg_completion_rate', COALESCE(t.avg_completion_rate, 0),
               'avg_passing_rate', COALESCE(t.avg_passing_rate, 0),
               'avg_grade', COALESCE(t.avg_grade, 0)
           )
    INTO student_performance_metric
    FROM t;


    WITH t as (
        SELECT
            CASE
                WHEN get_grade(mc.user_id, mc.version_id) <= 1.25 THEN 'Excellent'
                WHEN get_grade(mc.user_id, mc.version_id) <= 1.75 THEN 'Very Good'
                WHEN get_grade(mc.user_id, mc.version_id) <= 2.25 THEN 'Good'
                WHEN get_grade(mc.user_id, mc.version_id) <= 2.75 THEN 'Fair'
                WHEN get_grade(mc.user_id, mc.version_id) = 3.00 THEN 'Passed'
                WHEN get_grade(mc.user_id, mc.version_id) > 3.00 THEN 'Failed'
            END AS grade_bracket,
            ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS percentage
        FROM my_courses mc
        INNER JOIN internal.course_version_faculty cvf2 on mc.version_id = cvf2.version_id
        WHERE cvf2.user_id = f_faculty_id
        GROUP BY grade_bracket
        ORDER BY grade_bracket
    )
    SELECT json_agg(
           jsonb_build_object(
                'grade_bracket', t.grade_bracket,
                'percentage', t.percentage
           )
        ) INTO grades_distro
    FROM t;

    WITH course_stats AS (
        SELECT
            c.crs_title AS course,
            pc.pc_id,
            COUNT(mc.user_id) AS total_students,

            -- Average completion rate per course
            ((COUNT(*) FILTER (
                WHERE get_progress(mc.user_id, mc.version_id) = 100
            )::numeric / NULLIF(COUNT(*), 0)) * 100)::numeric(5,2) AS avg_completion_rate,

            -- Average passing rate per course (completed + passed)
            ((COUNT(*) FILTER (
                WHERE get_progress(mc.user_id, mc.version_id) = 100
                  AND get_grade(mc.user_id, mc.version_id) <= 3.0
            )::numeric / NULLIF(COUNT(*), 0)) * 100)::numeric(5,2) AS avg_passing_rate,

            -- Average grade per course
            AVG(get_grade(mc.user_id, mc.version_id))::numeric(4,2) AS avg_grade

        FROM my_courses mc
        INNER JOIN internal.course_version_faculty cvf
            ON cvf.version_id = mc.version_id
        INNER JOIN internal.course_version v
            ON v.version_id = mc.version_id
        INNER JOIN internal.prospectus_course pc
            ON pc.pc_id = v.version_id
        INNER JOIN internal.course c
            ON c.crs_id = pc.crs_id

        WHERE cvf.user_id = f_faculty_id  -- faculty ID passed in or derived earlier

        GROUP BY c.crs_title, pc.pc_id
    )
    SELECT json_agg(
        jsonb_build_object(
            'course', course,
            'avg_completion_rate', avg_completion_rate,
            'avg_passing_rate', avg_passing_rate,
            'avg_grade', avg_grade
        )
        ORDER BY avg_completion_rate DESC
    ) INTO per_course_metrics
    FROM course_stats;






    RETURN jsonb_build_object(
        'active_courses', COALESCE(active_courses, 0),
        'total_students_handled_pie_chart', COALESCE(total_students_handled, '[]'::jsonb),
        'student_performance_metric', COALESCE(student_performance_metric, '[]'::jsonb),
        'grade_distribution', jsonb_build_object(
            'legend', ARRAY[
                'Excellent (1.00-1.25)',
                'Very Good (1.50-1.75)',
                'Good (2.00-2.25)',
                'Fair (2.50-2.75)',
                'Passed (3.00)',
                'Failed (3.10-5.00)'
            ]::text[],
            'grades', COALESCE(grades_distro, '[]'::jsonb)
        ),
        'per_course_metrics', COALESCE(per_course_metrics, '[]'::jsonb)
    );


END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION internal.faculty_dashboard() FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION internal.faculty_dashboard() TO authenticated;



