-- create table to store  the programs available to show publicly

CREATE TABLE public.displayed_programs
(
    id        UUID PRIMARY KEY,
    name      TEXT NOT NULL UNIQUE,
    wallpaper TEXT,
    about     TEXT NOT NULL,
    reviews   TEXT NOT NULL,
    rating    TEXT NOT NULL,
    metadata  JSONB NOT NULL
);


CREATE OR REPLACE FUNCTION internal.get_prospectus_data_for_public(IN p_prospectus_id INT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    dcrpt_prospectus_id int := p_prospectus_id;
    head JSONB;
    classification_ids INT[];
    class INT;
    prospectus JSONB := '[]'::jsonb;
    entry_requirements TEXT[];
    summary JSONB;
BEGIN

    -- get the college
            -- get the program name
            SELECT
                jsonb_build_object(
                    'college', cao.cao_name,
                    'program', CASE
                                WHEN s2.specialization IS NULL THEN
                                    CONCAT(p2.prog_name, ', ', p2.prog_abbr)
                                ELSE
                                    CONCAT(p2.prog_name, ' major in ', s2.specialization, ', ',
                                           p2.prog_abbr, ' - ', s2.special_abbr)
                                END::TEXT
                ) INTO head
            FROM prospectus p
            INNER JOIN internal.specialization s2 on p.special_id = s2.special_id
            INNER JOIN internal.program p2 on p2.prog_id = s2.prog_id
            INNER JOIN internal.college_and_office cao on cao.cao_id = s2.cao_id
            WHERE p.prospectus_id = dcrpt_prospectus_id;

            -- get all the classifications
            SELECT COALESCE(array_agg(cu_id), '{}')  -- empty int[] array
            INTO classification_ids
            FROM classification_unit
            WHERE prospectus_id = dcrpt_prospectus_id;


            -- iterate each classification

            FOREACH class IN ARRAY classification_ids LOOP

                prospectus = prospectus || jsonb_build_object(
                                'classification', (SELECT c.classification FROM classification_unit cu INNER JOIN internal.classification c on c.classification_id = cu.classification_id WHERE cu.cu_id = class),
                                'required_units', (SELECT required_units FROM classification_unit WHERE cu_id = class),
                                'courses',
                                (
                                    SELECT
                                        json_agg(
                                            jsonb_build_object(
                                                'course_code', pc2.crs_code,
                                                'course_title', c4.crs_title,
                                                'course_units', c4.units
                                            )
                                        )
                                    FROM prospectus_course pc2
                                    INNER JOIN internal.course c4 on c4.crs_id = pc2.crs_id
                                    WHERE pc2.cu_id = class
                                )
                            );

            END LOOP;

            entry_requirements := (
                                        SELECT s.entry_reqs
                                        FROM prospectus p
                                            INNER JOIN internal.specialization s on p.special_id = s.special_id
                                        WHERE p.prospectus_id = dcrpt_prospectus_id
                                );

            summary := jsonb_build_object(
                    'total_units', (SELECT SUM(required_units) FROM classification_unit WHERE prospectus_id = dcrpt_prospectus_id),
                    'summary', (
                            SELECT
                                json_agg(
                                    jsonb_build_object(
                                        'classification', c3.classification,
                                        'units', u.required_units
                                    )
                                )
                            FROM classification_unit u
                            INNER JOIN internal.classification c3 on c3.classification_id = u.classification_id
                            WHERE u.prospectus_id = dcrpt_prospectus_id
                        )
                );

            RETURN jsonb_build_object(
                'head', coalesce(head, '[]'::jsonb),
                'body', coalesce(prospectus, '[]'::jsonb),
                'entry_requirements', '[]'::jsonb,
                'summary_of_credit_units_to_graduate', coalesce(summary, '[]'::jsonb)
            );

END;
$$;
REVOKE ALL ON FUNCTION internal.get_prospectus_data_for_public(IN p_prospectus_id INT) FROM PUBLIC;
REVOKE ALL ON FUNCTION internal.get_prospectus_data_for_public(IN p_prospectus_id INT) FROM anon;
REVOKE ALL ON FUNCTION internal.get_prospectus_data_for_public(IN p_prospectus_id INT) FROM authenticated;
REVOKE ALL ON FUNCTION internal.get_prospectus_data_for_public(IN p_prospectus_id INT) FROM service_role;
GRANT EXECUTE ON FUNCTION internal.get_prospectus_data_for_public(IN p_prospectus_id INT) TO postgres;


CREATE OR REPLACE PROCEDURE internal.update_displayed_programs()
SET search_path = internal
AS $$
BEGIN

    INSERT INTO public.displayed_programs (id, name, wallpaper, about, reviews, rating, metadata)
    SELECT DISTINCT ON (s.special_id)
        -- 1.) ID (encrypted)
        (
            substring(
                encode(digest(s.special_id::text, 'sha256'), 'hex')
                FROM 1 FOR 32
            )::uuid
        ) AS special_public_id,


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
        END::TEXT,

        -- METADATA
        (
            SELECT DISTINCT ON (sx.special_id)
                jsonb_build_object(
                'prospectus_data', COALESCE(get_prospectus_data_for_public(
                                            (
                                                SELECT prospectus_id
                                                FROM prospectus
                                                WHERE special_id = sx.special_id
                                                AND is_deleted IS FALSE
                                                ORDER BY date_created DESC
                                                LIMIT 1
                                                )
                                            ), jsonb_build_object(
                                                'head', '[]'::jsonb,
                                                'body', '[]'::jsonb,
                                                'entry_requirements', '[]'::jsonb,
                                                'summary_of_credit_units_to_graduate', '[]'::jsonb
                                            )
                ),
                'program_name', CASE
                                    WHEN sx.specialization IS NULL THEN
                                        CONCAT(px.prog_name, ', ', px.prog_abbr)
                                    ELSE
                                        CONCAT(px.prog_name, ' major in ', sx.specialization, ', ', px.prog_abbr, ' - ', sx.special_abbr)
                                END::TEXT,
                'wallpaper',    ox.name::text,
                'about',   coalesce(sx.about, 'about this program..'),
                'reviews',  CASE
                                WHEN COUNT(mcx.review) > 1 THEN COUNT(mcx.review)::text ELSE COALESCE(COUNT(mcx.review),0)::text
                            END,
                'rating',   CASE
                                WHEN COUNT(mcx.rating) FILTER (WHERE mcx.rating IS NOT NULL) >= 5
                                    THEN ROUND(AVG(mcx.rating)::numeric, 1)::text
                                ELSE '0'
                            END::TEXT,
                'learning_level', 'All Levels',
                'number_of_courses',    (
                                            SELECT COALESCE(COUNT(pc2y.pc_id), 0)
                                            FROM prospectus_course pc2y
                                            LEFT JOIN internal.prospectus p3y on p3y.prospectus_id = pc2y.prospectus_id
                                            WHERE p3y.prospectus_id = (
                                                SELECT prospectus_id
                                                FROM prospectus
                                                WHERE special_id = sx.special_id
                                                AND is_deleted IS FALSE
                                                ORDER BY date_created DESC
                                                LIMIT 1
                                                )
                                        )::TEXT,
                'faculties', COALESCE((
                        WITH fac AS(
                            SELECT
                                CONCAT(uz.fname, ' ', COALESCE(uz.mname, ''), ' ', uz.lname)::text as name,
                                (SELECT concat(COALESCE(COUNT(cvf1.version_id), 0), ' course(s)')
                                            FROM course_version_faculty cvf1
                                            INNER JOIN internal.course_version c on c.version_id = cvf1.version_id
                                            WHERE cvf1.user_id = uz.user_id
                                                AND c.is_ready IS TRUE
                                                AND c.apvd_rvwd_by IS NOT NULL) as courses,
                                (SELECT concat(COALESCE(COUNT(DISTINCT mc1.user_id), 0), ' student(s)')
                                            FROM my_courses mc1
                                            INNER JOIN internal.course_version_faculty cvf2 on mc1.version_id = cvf2.version_id
                                            INNER JOIN internal.course_version c2 on c2.version_id = cvf2.version_id
                                            WHERE cvf2.user_id = uz.user_id
                                                AND c2.is_ready IS TRUE
                                                AND c2.apvd_rvwd_by IS NOT NULL) as students
                            FROM prospectus_course pcz
                            INNER JOIN internal.course_version cvz on pcz.pc_id = cvz.version_id
                                INNER JOIN internal.course_version_faculty cvfz on cvz.version_id = cvfz.version_id
                                    INNER JOIN internal.users uz on uz.user_id = cvfz.user_id
                            WHERE pcz.prospectus_id = (SELECT prospectus_id FROM prospectus WHERE special_id = sx.special_id AND is_deleted IS FALSE ORDER BY date_created DESC LIMIT 1)
                            group by uz.user_id, uz.fname, uz.mname, uz.lname
                        )
                        SELECT
                            jsonb_agg(
                                jsonb_build_object(
                                        'avatar', null,
                                        'faculty_name', fac.name,
                                        'courses', fac.courses,
                                        'students', fac.students
                                )
                            )
                                FROM fac
                        ), '[]'::jsonb),
                        'what_to_learn', ARRAY[
                                                'Collect, clean, sort, evaluate, and visualize data',
                                                'Apply the OSEMN, framework to guide the data analysis process, ' ||
                                                'ensuring a comprehensive and structured approach to deriving actionable insights',
                                                'Use statistical analysis, including hypothesis testing, regression analysis, and more, to make data-driven decisions',
                                                'Develop an understanding of the foundational principles of effective data management and usability of data assets within organizational context'
                                            ],
                        'overview', coalesce(sx.about, 'about this program..'),
                        'skills_to_gain', ARRAY['Data Management', 'Spreadsheet Software', 'Data Collection', 'Data Storytelling', 'Data Analysis'],
                        'tools_to_learn', ARRAY['Data Analysis', 'Python Programming'],
                        'inclusion', ARRAY['Shareable certificate', 'Taught in English', '108 practice exercises']
                    )
                    FROM specialization sx
                    INNER JOIN internal.program px on px.prog_id = sx.prog_id
                    INNER JOIN storage.objects ox on ox.id = sx.wallpaper_id
                    LEFT JOIN internal.prospectus p2x on sx.special_id = p2x.special_id
                        LEFT JOIN internal.prospectus_course pcx on p2x.prospectus_id = pcx.prospectus_id
                            LEFT JOIN internal.course_version cvx on pcx.pc_id = cvx.version_id
                                LEFT JOIN internal.my_courses mcx on cvx.version_id = mcx.version_id
                    WHERE sx.special_id = s.special_id
                    group by sx.special_id, px.prog_name, px.prog_abbr,  ox.name, mcx.version_id
        )
        FROM specialization s
            INNER JOIN storage.objects o on o.id = s.wallpaper_id
            INNER JOIN internal.program p on p.prog_id = s.prog_id
            LEFT JOIN internal.prospectus p2 on s.special_id = p2.special_id
                LEFT JOIN internal.prospectus_course pc on p2.prospectus_id = pc.prospectus_id
                    LEFT JOIN internal.course_version cv on pc.pc_id = cv.version_id
                        LEFT JOIN internal.my_courses mc on cv.version_id = mc.version_id
            WHERE s.is_deleted IS FALSE
            group by s.special_id, p.prog_name, p.prog_abbr, o.name
            ON CONFLICT (id) DO UPDATE
                SET
                    name = EXCLUDED.name,
                    wallpaper = EXCLUDED.wallpaper,
                    about = EXCLUDED.about,
                    reviews = EXCLUDED.reviews,
                    rating = EXCLUDED.rating,
                    metadata = EXCLUDED.metadata;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
REVOKE ALL ON PROCEDURE internal.update_displayed_programs() FROM PUBLIC;
REVOKE ALL ON PROCEDURE internal.update_displayed_programs() FROM anon;
REVOKE ALL ON PROCEDURE internal.update_displayed_programs() FROM authenticated;
REVOKE ALL ON PROCEDURE internal.update_displayed_programs() FROM service_role;
GRANT EXECUTE ON PROCEDURE internal.update_displayed_programs() TO postgres;

SELECT cron.schedule(
    'update_displayed_programs_job',    -- job name
    '*/5 * * * *',                      -- every 5 minutes
    $$CALL internal.update_displayed_programs();$$
);

SELECT *
FROM cron.job_run_details
ORDER BY runid DESC
LIMIT 20;


-- create a function for public

CREATE OR REPLACE FUNCTION public.explore_displayed_programs()
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
    result := (
            SELECT
                jsonb_agg(
                    jsonb_build_object(
                    'id', dp.id,
                    'name', dp.name,
                    'wallpaper', dp.wallpaper,
                    'about', dp.about,
                    'reviews', dp.reviews,
                    'rating', dp.rating,
                    'metadata', dp.metadata
                    )
                )
            FROM public.displayed_programs dp
        );

    RETURN jsonb_build_object(
                'status', 'success',
                'message', result
            );

END;
$$;

