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
-- 1. Manage Programs---------------------------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION internal.view_all_programs()
RETURNS TABLE(
    id TEXT, -- 1
    name TEXT, -- 2
    rating TEXT, -- 3
    likes TEXT, -- 4
    college TEXT, -- 5
    certifications TEXT[], -- 6
    date TEXT, -- 7
    status TEXT, -- 8
    created_by TEXT -- 9
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
BEGIN

    -- Only run main query if key exists and confirm the user role
    IF (
        (SELECT check_user_role(ARRAY['admin','dean'])) = TRUE AND
        internal.get_secret_key('view_all_programs') IS NOT NULL) THEN
        RETURN QUERY
        SELECT
            -- 1.) ID (encrypted)
            encode(
                pgp_sym_encrypt(s.special_id::TEXT, internal.get_secret_key('view_all_programs')),
                'base64'
            )::TEXT,

            -- 2.) Program/Specialization name
            CASE
                WHEN s.specialization IS NULL THEN
                    CONCAT(prg.prog_name, ', ', prg.prog_abbr)
                ELSE
                    CONCAT(prg.prog_name, ' major in ', s.specialization, ', ',
                           prg.prog_abbr, ' - ', s.special_abbr)
            END::TEXT,

            -- 3.) Rating
            CASE
                WHEN COUNT(mc.rating) FILTER (WHERE mc.rating IS NOT NULL) >= 5
                THEN ROUND(AVG(mc.rating)::numeric, 1)::text
                ELSE '0'
            END::TEXT,


            -- 4.) Likes (only TRUE)
            CASE
                WHEN COUNT(*) FILTER (WHERE mc.is_liked IS TRUE) = 0
                    THEN '0'
                ELSE COUNT(*) FILTER (WHERE mc.is_liked IS TRUE)::TEXT
            END::TEXT,

            -- 5.) College/Office name
            c.cao_name::TEXT,


            -- 6.) Certification Types

            COALESCE(
                (
                    SELECT ARRAY_AGG(c2.certification::TEXT)::TEXT[]
                    FROM prog_spec_certification ppc
                    INNER JOIN internal.certification c2 on ppc.certification_id = c2.certification_id
                    WHERE ppc.special_id = s.special_id
                    ),
                ARRAY[]::TEXT[]
            ) AS certifications,



            -- 7.) Date created
            TO_CHAR(s.date_created, 'MM/DD/YYYY')::TEXT,

            -- 8.) Status
            CASE
                WHEN s.status IS TRUE THEN 'Active'
                ELSE 'Inactive'
            END::TEXT,

            -- 9.) Created by user
            CONCAT(u.lname, ', ', u.fname, ' ', COALESCE(u.mname, ''))::TEXT AS created_by

        FROM specialization s
        INNER JOIN program prg ON s.prog_id = prg.prog_id
        INNER JOIN college_and_office c ON s.cao_id = c.cao_id
        INNER JOIN users u ON u.user_id = s.created_by
        LEFT JOIN prospectus pros ON pros.special_id = s.special_id
        LEFT JOIN prospectus_course pc ON pc.prospectus_id = pros.prospectus_id
        LEFT JOIN course_version cv ON cv.version_id = pc.pc_id
        LEFT JOIN my_courses mc ON mc.version_id = cv.version_id
        WHERE s.is_deleted IS FALSE AND (
                                           (SELECT cao_id FROM users WHERE auth_id = auth.uid()) IS NULL
                                           OR c.cao_id = (SELECT cao_id FROM users WHERE auth_id = auth.uid())
                                          )
        GROUP BY s.special_id, prg.prog_name, s.specialization, prg.prog_abbr,
                 s.special_abbr, c.cao_name, s.date_created, s.status,
                 u.lname, u.fname, u.mname
        ORDER BY prg.prog_name, s.specialization, prg.prog_abbr,s.special_abbr;
    ELSE
        -- No secret key, return empty result set
        RETURN QUERY
        SELECT NULL::TEXT, NULL::TEXT, NULL::TEXT, NULL::TEXT,
               NULL::TEXT, NULL::TEXT[], NULL::TEXT, NULL::TEXT, NULL::TEXT
        WHERE FALSE;
    END IF;
END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION internal.view_all_programs() FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION internal.view_all_programs() TO authenticated;

--- 1.1.2 SELECT & VIEW PROGRAM

CREATE OR REPLACE FUNCTION internal.select_program(IN p_special_id TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    dcrpt_special_id INT;
BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['admin'])) = FALSE THEN
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    END IF;

    -- decrypt special_id
    dcrpt_special_id := pgp_sym_decrypt(
        decode(p_special_id, 'base64'),
        get_secret_key('view_all_programs')
    )::INT;

    RETURN (SELECT
        jsonb_build_object(
            'p_special_id', encode(
                                pgp_sym_encrypt(s.special_id::TEXT, internal.get_secret_key('select_program')),
                                'base64'
                            )::TEXT,
            'p_cao', cao.cao_name,
            'p_exs_mprog', CONCAT(p.prog_name, ', ', p.prog_abbr),
            'p_special_name', s.specialization,
            'p_special_abbr', s.special_abbr,
            'p_about', s.about,
            'p_entry_requirements', s.entry_reqs,
            'p_certifications', (
                SELECT array_agg(c.certification)
                FROM prog_spec_certification psc
                    INNER JOIN internal.certification c on c.certification_id = psc.certification_id
                WHERE psc.special_id = s.special_id
            )
        )
    FROM specialization s
    inner join internal.program p on p.prog_id = s.prog_id
    inner join internal.college_and_office cao on cao.cao_id = s.cao_id
    WHERE s.special_id = dcrpt_special_id);

END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION internal.select_program(IN p_special_id TEXT) FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION internal.select_program(IN p_special_id TEXT) TO authenticated;


--- 1.2 Create a Program

CREATE OR REPLACE PROCEDURE internal.create_program(
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
SET search_path = internal
AS $$
DECLARE
    dcrpt_cao_id INT;
    dcrpt_prog_id INT;
    dcrpt_certification_id INT;
    fetched_program_id INT := NULL;
    fetched_special_id INT := NULL;
    cert_id TEXT;
    fetched_college TEXT;
BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['admin'])) = FALSE THEN
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    END IF;

    -- decrypt CAO ID
    BEGIN
        dcrpt_cao_id := pgp_sym_decrypt(
            decode(p_cao_id, 'base64'),
            get_secret_key('get_college_office')
        )::INT;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Valid College/Office ID is required.'
            USING ERRCODE = 'P0043';
    END;

    IF p_exs_mprog_id IS NOT NULL THEN
        BEGIN
            dcrpt_prog_id := pgp_sym_decrypt(
                decode(p_exs_mprog_id, 'base64'),
                get_secret_key('get_main_programs')
            )::INT;
        EXCEPTION
            WHEN OTHERS THEN
                RAISE EXCEPTION 'Valid Main/Primary Program ID is required.'
                USING ERRCODE = 'P0043';
        END;



        -- CHECKS IF THIS IS A GENERAL PROGRAM AND DOESN'T ALLOW MAJORS
        IF internal.duplicate_general_program(dcrpt_prog_id) IS TRUE THEN
            RAISE EXCEPTION 'This main or primary program is a general program and is not permitted to have majors or specializations.'
            USING ERRCODE = 'P0020';
        end if;
    END IF;


    -- PARAMETER CHECK FOR MAIN PROGRAM
    IF p_exs_mprog_id IS NULL THEN
        IF p_prog_name IS NULL THEN
            RAISE EXCEPTION 'Program name is required when no existing main program is selected.'
                USING ERRCODE = 'P0020';
        END IF;
        IF p_prog_abbr IS NULL THEN
            RAISE EXCEPTION 'Program abbreviation is required when no existing main program is selected.'
                USING ERRCODE = 'P0020';
        END IF;
    ELSE
        IF p_prog_name IS NOT NULL THEN
            RAISE EXCEPTION 'Do not provide both a program name and an existing main program. Choose one.'
                USING ERRCODE = 'P0021';
        END IF;
        IF p_prog_abbr IS NOT NULL THEN
            RAISE EXCEPTION 'Do not provide both a program abbreviation and an existing main program. Choose one.'
                USING ERRCODE = 'P0021';
        END IF;


    END IF;

    -- PARAMETER CHECK FOR SPECIALIZATION/MAJOR
    IF p_special_name IS NULL AND p_special_abbr IS NOT NULL THEN
        RAISE EXCEPTION 'Field specialization name is required.'
                USING ERRCODE = 'P0022';
    ELSIF p_special_name IS NOT NULL AND p_special_abbr IS NULL THEN
        RAISE EXCEPTION 'Field specialization abbreviation is required.'
                USING ERRCODE = 'P0022';
    END IF;

    -- CHECK IF REQUIREMENTS ARE PRESENT
    IF p_entry_requirements IS NULL OR  COALESCE(array_length(p_entry_requirements, 1), 0) = 0 THEN
        RAISE EXCEPTION 'Field Entry Requirements is required.'
                USING ERRCODE = 'P0022';
    end if;



    IF trim(p_about) = '' OR trim(p_about) = ' ' THEN
        p_about := NULL;
    end if;

    -- check if program name already exist
    IF EXISTS(SELECT 1
              FROM internal.program
              WHERE prog_name = trim(p_prog_name) AND prog_abbr = trim(p_prog_abbr)
        ) THEN
        RAISE EXCEPTION 'This Primary Program already exist.'
                USING ERRCODE = 'P0023';
    end if;

    -- check if specialization already exist
    IF EXISTS (
        SELECT 1
        FROM internal.specialization s
        INNER JOIN internal.college_and_office c ON c.cao_id = s.cao_id
        WHERE s.specialization = trim(p_special_name)
          AND s.special_abbr = trim(p_special_abbr)
          AND s.prog_id = dcrpt_prog_id
          AND s.is_deleted IS FALSE
    ) THEN
        SELECT c.cao_name
        INTO fetched_college
        FROM internal.specialization s
        INNER JOIN internal.college_and_office c ON c.cao_id = s.cao_id
        WHERE s.specialization = trim(p_special_name)
          AND s.special_abbr = trim(p_special_abbr)
        LIMIT 1;

        RAISE EXCEPTION 'This Program already exists in the college: %', fetched_college
            USING ERRCODE = 'P0024';
    END IF;


    -- insert program and get id
    IF p_exs_mprog_id IS NULL THEN
        INSERT INTO program (prog_name, prog_abbr)
        VALUES (p_prog_name, p_prog_abbr)
        RETURNING prog_id INTO fetched_program_id;
    end if;

    -- insert to specialization
    INSERT INTO specialization (specialization, special_abbr,cao_id, prog_id, about, entry_reqs)
        VALUES (p_special_name, p_special_abbr, dcrpt_cao_id, COALESCE(fetched_program_id, dcrpt_prog_id), TRIM(p_about), coalesce(p_entry_requirements, '{}'))
        RETURNING special_id INTO fetched_special_id;

    -- loop through certification IDs if provided
    IF p_certification_ids IS NOT NULL AND array_length(p_certification_ids, 1) > 0 THEN
        FOREACH cert_id IN ARRAY p_certification_ids LOOP
            BEGIN
                dcrpt_certification_id := pgp_sym_decrypt(
                    decode(cert_id, 'base64'),
                    get_secret_key('get_certification_types')
                )::INT;
            EXCEPTION
                WHEN OTHERS THEN
                    RAISE EXCEPTION 'Valid Certification ID is required.'
                    USING ERRCODE = 'P0043';
            END;

            INSERT INTO prog_spec_certification (special_id, certification_id)
            VALUES (fetched_special_id, dcrpt_certification_id);
        END LOOP;
    END IF;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
REVOKE ALL ON PROCEDURE internal.create_program(
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
GRANT EXECUTE ON PROCEDURE internal.create_program(
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

CREATE OR REPLACE FUNCTION internal.get_certification_types()
RETURNS TABLE(id TEXT, name TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['admin'])) = FALSE THEN
        RETURN;
    end if;

    IF internal.get_secret_key('get_certification_types') IS NOT NULL THEN
        RETURN QUERY
            SELECT
                encode(
                    pgp_sym_encrypt(certification_id::TEXT, internal.get_secret_key('get_certification_types')),'base64')::TEXT,
                certification::TEXT
            FROM internal.certification;
    ELSE
        -- Return a dummy empty row (or use RETURN QUERY with WHERE false)
        RETURN QUERY
        SELECT NULL::TEXT, NULL::TEXT
        WHERE FALSE;
    END IF;
END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION internal.get_certification_types() FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION internal.get_certification_types() TO authenticated;


----- 1.2.2 Get all main programs for dropdown

CREATE OR REPLACE FUNCTION internal.get_main_programs()
RETURNS TABLE(id TEXT, name TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['admin'])) = FALSE THEN
        RETURN;
    end if;

    IF internal.get_secret_key('get_main_programs') IS NOT NULL THEN
        RETURN QUERY
            SELECT
                encode(
                    pgp_sym_encrypt(prog_id::TEXT, internal.get_secret_key('get_main_programs')),'base64')::TEXT,
                CONCAT(prog_name, ', ',program.prog_abbr)::text
            FROM internal.program;
    ELSE
        -- Return a dummy empty row (or use RETURN QUERY with WHERE false)
        RETURN QUERY
        SELECT NULL::TEXT, NULL::TEXT
        WHERE FALSE;
    END IF;
END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION internal.get_main_programs() FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION internal.get_main_programs() TO authenticated;

--//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

--- 1.3 Update Program

CREATE OR REPLACE PROCEDURE internal.update_program(
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
SET search_path = internal
AS $$
DECLARE
    dcrpt_special_id INT;
    dcrpt_cao_id INT;
    dcrpt_prog_id INT;
    dcrpt_certification_id INT;

    fetched_program_id INT := NULL;
    fetched_special_id INT := NULL;
    cert_id TEXT;
    fetched_college TEXT;
BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['admin'])) = FALSE THEN
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    END IF;

    -- decrypt CAO ID
    IF p_cao_id IS NOT NULL THEN
        dcrpt_cao_id := pgp_sym_decrypt(
            decode(p_cao_id, 'base64'),
            get_secret_key('get_college_office')
        )::INT;
    END IF;

    -- decrypt special_id
    dcrpt_special_id := pgp_sym_decrypt(
        decode(p_special_id, 'base64'),
        get_secret_key('view_all_programs')
    )::INT;

    -- decrypt existing main program
    IF p_exs_mprog_id IS NOT NULL THEN
        -- decrypt the exsitng main program id
        dcrpt_prog_id := pgp_sym_decrypt(
            decode(p_exs_mprog_id, 'base64'),
            get_secret_key('get_main_programs'))::INT;
    END IF;

    -- PARAMETER CHECK FOR MAIN PROGRAM
    IF p_prog_name IS NOT NULL AND p_prog_abbr IS NULL THEN
        RAISE EXCEPTION 'Field "Program abbreviation" is required.'
                USING ERRCODE = 'P0025';
    ELSIF p_prog_name IS NULL AND p_prog_abbr IS NOT NULL THEN
        RAISE EXCEPTION 'Field "Program name" is required.'
                USING ERRCODE = 'P0026';
    ELSIF p_prog_name IS NOT NULL AND p_prog_abbr IS NOT NULL THEN
        IF p_exs_mprog_id IS NOT NULL THEN
            RAISE EXCEPTION 'Do not provide both a program name and an existing main program. Choose one.'
                USING ERRCODE = 'P0021';
        END IF;
    end if;

    -- PARAMETER CHECK FOR SPECIALIZATION/MAJOR
    IF p_special_name IS NULL AND p_special_abbr IS NOT NULL THEN
        RAISE EXCEPTION 'Field specialization name is required.'
                USING ERRCODE = 'P0022';
    ELSIF p_special_name IS NOT NULL AND p_special_abbr IS NULL THEN
        RAISE EXCEPTION 'Field specialization abbreviation is required.'
                USING ERRCODE = 'P0022';
    END IF;

    IF trim(p_about) = '' OR trim(p_about) = ' ' THEN
        p_about := NULL;
    end if;

    -- CHECK IF REQUIREMENTS ARE PRESENT
    IF p_entry_requirements IS NULL OR  COALESCE(array_length(p_entry_requirements, 1), 0) = 0 THEN
        RAISE EXCEPTION 'Field Entry Requirements is required.'
                USING ERRCODE = 'P0022';
    end if;

        -- check if program name already exist
    IF EXISTS(SELECT 1
              FROM internal.program
              WHERE prog_name = trim(p_prog_name) AND prog_abbr = trim(p_prog_abbr)
        ) THEN
        RAISE EXCEPTION 'This Primary Program already exist.'
                USING ERRCODE = 'P0023';
    end if;

    -- check if specialization already exist
    IF EXISTS (
        SELECT 1
        FROM internal.specialization s
        INNER JOIN internal.college_and_office c ON c.cao_id = s.cao_id
        WHERE s.specialization = trim(p_special_name)
          AND s.special_abbr = trim(p_special_abbr)
          AND s.prog_id = dcrpt_prog_id
    ) THEN
        SELECT c.cao_name
        INTO fetched_college
        FROM internal.specialization s
        INNER JOIN internal.college_and_office c ON c.cao_id = s.cao_id
        WHERE s.specialization = trim(p_special_name)
          AND s.special_abbr = trim(p_special_abbr)
        AND s.prog_id = dcrpt_prog_id
        LIMIT 1;

        RAISE EXCEPTION 'This Program already exists in the college: %', fetched_college
            USING ERRCODE = 'P0024';
    END IF;


    -- insert NEW program and get id
    IF p_prog_name IS NOT NULL THEN
        INSERT INTO program (prog_name, prog_abbr)
        VALUES (p_prog_name, p_prog_abbr)
        RETURNING prog_id INTO fetched_program_id;
    end if;


    UPDATE specialization s
    SET prog_id = COALESCE(fetched_program_id, dcrpt_prog_id, prog_id),
        specialization = COALESCE(p_special_name, specialization),
        special_abbr = COALESCE(p_special_abbr, special_abbr),
        cao_id = COALESCE(dcrpt_cao_id, cao_id),
        about = COALESCE(p_about, about),
        entry_reqs = COALESCE(p_entry_requirements, entry_reqs)
    WHERE special_id = dcrpt_special_id;

    -- loop through certification IDs if provided
    IF p_certification_ids IS NOT NULL AND array_length(p_certification_ids, 1) > 0 THEN
        DELETE FROM prog_spec_certification
        WHERE special_id = dcrpt_special_id;

        FOREACH cert_id IN ARRAY p_certification_ids LOOP
            dcrpt_certification_id := pgp_sym_decrypt(
                decode(cert_id, 'base64'),
                get_secret_key('get_certification_types')
            )::INT;

            INSERT INTO prog_spec_certification (special_id, certification_id)
            VALUES (dcrpt_special_id, dcrpt_certification_id);
        END LOOP;
    END IF;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
REVOKE ALL ON PROCEDURE internal.update_program(
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
GRANT EXECUTE ON PROCEDURE internal.update_program(
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

--//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

--- 1.4 Delete Program

CREATE OR REPLACE PROCEDURE internal.delete_program(
    IN p_special_id TEXT
)
SET search_path = internal
AS $$
DECLARE
    dcrpt_special_id INT;
BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['admin'])) = FALSE THEN
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    END IF;

    -- decrypt special_id
    dcrpt_special_id := pgp_sym_decrypt(
        decode(p_special_id, 'base64'),
        get_secret_key('view_all_programs')
    )::INT;

    UPDATE specialization
    SET is_deleted = TRUE
    WHERE special_id = dcrpt_special_id;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
REVOKE ALL ON PROCEDURE internal.delete_program(IN p_special_id TEXT) FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE internal.delete_program(IN p_special_id TEXT) TO authenticated;

--//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////





------------------------------------------------------------------------------------------------------------------------
-- 2. Manage Prospectus ------------------------------------------------------------------------------------------------


--- 2.1 View all Prospectus

CREATE OR REPLACE FUNCTION internal.view_all_prospectus(IN p_special_id TEXT)
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
    dcrpt_special_id INT;
BEGIN

    -- Only run main query if key exists and confirm the user role
    IF (
        (SELECT check_user_role(ARRAY['admin', 'dean'])) = TRUE AND
        internal.get_secret_key('view_all_prospectus') IS NOT NULL) THEN

        -- decrypt special_id
        dcrpt_special_id := pgp_sym_decrypt(
            decode(p_special_id, 'base64'),
            get_secret_key('view_all_programs')
        )::INT;

        RETURN QUERY
        SELECT
            -- ID (encrypted)
            encode(
                pgp_sym_encrypt(pros.prospectus_id::TEXT, internal.get_secret_key('view_all_prospectus')),
                'base64'
            )::TEXT,

            -- Prospectus code
            pros.prospectus_code::TEXT,

            -- Date created
            TO_CHAR(pros.date_created, 'MM/DD/YYYY'),

            -- Created by user
            CONCAT(u.lname, ', ', u.fname, ' ', COALESCE(u.mname, '')),

            -- Effective period
            pros.year::TEXT


        FROM prospectus pros
        INNER JOIN specialization s ON s.special_id = pros.special_id
        INNER JOIN program prg ON s.prog_id = prg.prog_id
        INNER JOIN users u ON u.user_id = pros.created_by
        INNER JOIN internal.college_and_office cao on s.cao_id = cao.cao_id
        WHERE pros.is_deleted IS FALSE
          AND s.is_deleted = FALSE
          AND pros.special_id = dcrpt_special_id
          AND (
                (SELECT cao_id FROM users WHERE auth_id = auth.uid()) IS NULL
                OR cao.cao_id = (SELECT cao_id FROM users WHERE auth_id = auth.uid())
                AND (
                                           (SELECT cao_id FROM users WHERE auth_id = auth.uid()) IS NULL
                                           OR cao.cao_id = (SELECT cao_id FROM users WHERE auth_id = auth.uid())
                                          ))
        ORDER BY pros.date_created DESC;
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
REVOKE ALL ON FUNCTION internal.view_all_prospectus(IN p_special_id TEXT) FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION internal.view_all_prospectus(IN p_special_id TEXT) TO authenticated;

--//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

--- 2.2 Delete Prospectus

CREATE OR REPLACE PROCEDURE internal.delete_prospectus(
    IN p_prospectus_id TEXT
)
SET search_path = internal
AS $$
DECLARE
    dcrpt_prospectus_id INT;
BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['admin'])) = FALSE THEN
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    END IF;

    -- decrypt special_id
    dcrpt_prospectus_id := pgp_sym_decrypt(
        decode(p_prospectus_id, 'base64'),
        get_secret_key('view_all_prospectus')
    )::INT;

    UPDATE prospectus
    SET is_deleted = TRUE
    WHERE  prospectus_id = dcrpt_prospectus_id;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
REVOKE ALL ON PROCEDURE internal.delete_prospectus(IN p_prospectus_id TEXT) FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE internal.delete_prospectus(IN p_prospectus_id TEXT) TO authenticated;



--//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

--- 2.3  Create Prospectus

CREATE OR REPLACE PROCEDURE internal.create_prospectus(
    IN p_special_id TEXT,
    IN p_year INTEGER,
    IN p_semesters_and_duration JSONB,
    IN p_classifications_and_units JSONB,
    IN p_courses_and_classification_units JSONB
)
SET search_path = internal
AS $$
DECLARE
    dcrpt_special_id INT;
    returned_prospectus_id INT;
    sem RECORD;
    class RECORD;
    crs RECORD;

    last_sem_id INT := null;
    last_year_id INT := null;
    last_class_id INT := null;
    last_crs_id INT := NULL;
    last_code text := NULL;

    dcrpt_sem_id INT;
    dcrpt_year_id INT;
    dcrpt_classif_id INT;
    dcrpt_crs_id INT;

    fetched_cu_id INT;
    fetched_crs_title text;
    fetched_classif text;
    a_ttype INT;
    b_ttype INT;

    classification_count int := 0;
    curr_class TEXT;

    seen_codes TEXT[] := '{}';  -- stores course codes processed so far
BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['admin'])) = FALSE THEN
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    END IF;

    -- decrypt special ID
    BEGIN
        dcrpt_special_id := pgp_sym_decrypt(
            decode(p_special_id, 'base64'),
            get_secret_key('view_all_programs')
        )::INT;
    EXCEPTION
        WHEN OTHERS THEN
        RAISE EXCEPTION 'Valid "Program ID" is required.'
            USING ERRCODE = 'P0035';
    END;


    -- Step 1. Create the Prospectus
    INSERT INTO prospectus (special_id, year) -- it is underlined yellow because of prospectus code which is already autogenerated by a trigger
    VALUES (dcrpt_special_id, p_year)
    RETURNING prospectus_id INTO returned_prospectus_id;

    -- Step 2. Structure/Prepare the Semesters -- OPTIONAL

    IF p_semesters_and_duration IS NOT NULL THEN
        FOR sem IN
            SELECT sem_id,
                   period::daterange,
                   year_id
            FROM jsonb_to_recordset(p_semesters_and_duration)
                 AS x(sem_id TEXT, period TEXT, year_id TEXT)
        LOOP
            -- Decrypt semester and year IDs
            BEGIN
                dcrpt_sem_id := pgp_sym_decrypt(
                    decode(sem.sem_id, 'base64'),
                    get_secret_key('get_semesters')
                )::INT;
            EXCEPTION
                WHEN OTHERS THEN
                    RAISE EXCEPTION 'Valid "Semester ID" is required.'
                        USING ERRCODE = 'P0035';
            END;

            BEGIN
                dcrpt_year_id := pgp_sym_decrypt(
                    decode(sem.year_id, 'base64'),
                    get_secret_key('get_years')
                )::INT;
            EXCEPTION
                WHEN OTHERS THEN
                    RAISE EXCEPTION 'Valid "Year ID" is required.'
                        USING ERRCODE = 'P0035';
            END;

            -- Check for duplicates
            IF last_sem_id = dcrpt_sem_id AND last_year_id = dcrpt_year_id THEN
                RAISE EXCEPTION 'A prospectus cannot contain duplicate years & semesters. Please review it again.'
                    USING ERRCODE = 'P0029';
            END IF;
            last_sem_id := dcrpt_sem_id;
            last_year_id := dcrpt_year_id;

            -- ✅ Check overlap with existing rows
            IF EXISTS (
                SELECT 1
                FROM prospectus_semester ps
                WHERE ps.prospectus_id = returned_prospectus_id
                  AND ps.year_id = dcrpt_year_id
                  AND ps.duration && sem.period
            ) THEN
                RAISE EXCEPTION 'Semester duration % overlaps with an existing semesters in this prospectus. Please review it again.', sem.period
                    USING ERRCODE = 'P0027';
            END IF;

            -- ✅ Ensure same term type
            SELECT s.ttype_id
            INTO a_ttype
            FROM semester s
            JOIN prospectus_semester p ON s.sem_id = p.sem_id
            WHERE p.prospectus_id = returned_prospectus_id
            LIMIT 1;

            SELECT ttype_id
            INTO b_ttype
            FROM semester
            WHERE sem_id = dcrpt_sem_id
            LIMIT 1;

            IF (a_ttype IS NOT NULL) AND (a_ttype != b_ttype) THEN
                RAISE EXCEPTION 'The semesters entered does not belong to the same term type group. Please review it again.'
                    USING ERRCODE = 'P0028';
            END IF;

            -- 🆕 Step 1: Check for jumping terms
            PERFORM 1
            FROM semester s
            WHERE s.ttype_id = b_ttype
              AND s.sem_num < (SELECT sem_num FROM semester WHERE sem_id = dcrpt_sem_id)
              AND NOT EXISTS (
                  SELECT 1
                  FROM prospectus_semester ps
                  WHERE ps.prospectus_id = returned_prospectus_id
                    AND ps.sem_id = s.sem_id
              );
            IF FOUND THEN
                RAISE EXCEPTION 'Cannot add this semester yet: previous semester(s) of the same term type are missing.'
                    USING ERRCODE = 'P0028';
            END IF;

            -- 🆕 Step 2: Check for jumping years
            PERFORM 1
            FROM year y
            WHERE y.year < (SELECT year FROM year WHERE year_id = dcrpt_year_id)
              AND NOT EXISTS (
                  SELECT 1
                  FROM prospectus_semester ps
                  WHERE ps.prospectus_id = returned_prospectus_id
                    AND ps.year_id = y.year_id
              );
            IF FOUND THEN
                RAISE EXCEPTION 'Cannot add this semester yet: previous academic year(s) are missing.'
                    USING ERRCODE = 'P0028';
            END IF;

            -- ✅ All checks passed → insert
            INSERT INTO prospectus_semester (duration, sem_id, prospectus_id, year_id)
            VALUES (sem.period, dcrpt_sem_id, returned_prospectus_id, dcrpt_year_id);

        END LOOP;
    END IF;

    -- Step 3. Structure and set up required units for each classification
    FOR class IN
    SELECT classification_id,
           req_units::NUMERIC(4, 2)
    FROM jsonb_to_recordset(p_classifications_and_units)
         AS x(classification_id TEXT, req_units NUMERIC(4, 2))
    LOOP
        -- decrypt the classification id
        BEGIN
            dcrpt_classif_id := pgp_sym_decrypt(
                decode(class.classification_id, 'base64'),
                get_secret_key('get_classifications')
            )::INT;
        EXCEPTION
            WHEN OTHERS THEN
            RAISE EXCEPTION 'Valid "Classification ID" is required.'
                USING ERRCODE = 'P0035';
        END;

        -- check if units is negative and max the value
        IF class.req_units < 0.0 OR class.req_units > 100 THEN
            RAISE EXCEPTION 'Invalid req_units value: %. Must be from 0 to 100.', class.req_units
                USING ERRCODE = 'P0035';
        END IF;

        -- check for duplicate classifications
        IF last_class_id = dcrpt_classif_id THEN
            RAISE EXCEPTION 'A prospectus cannot contain duplicate classifications. Please review it again.'
                USING ERRCODE = 'P0030';
        end if;
        last_class_id := dcrpt_classif_id;

        -- COUNT CLASSIFICATION
        classification_count := classification_count + 1;

        -- begin insert
        INSERT INTO classification_unit (REQUIRED_UNITS, CLASSIFICATION_ID, PROSPECTUS_ID)
        VALUES (class.req_units, dcrpt_classif_id, returned_prospectus_id);
    END LOOP;

--     -- check if all classifications is required [deprecated]
--     IF classification_count != 4 THEN
--         RAISE EXCEPTION 'All classification should be present.'
--                 USING ERRCODE = 'P0030';
--     end if;

    -- Step 4. Structure courses
    FOR crs IN
    SELECT crs_id,
           crs_code,
           classification_id
    FROM jsonb_to_recordset(p_courses_and_classification_units)
         AS x(crs_id TEXT, crs_code TEXT, classification_id TEXT)
    LOOP

        -- decrypt the classification id
        BEGIN
            dcrpt_classif_id := pgp_sym_decrypt(
                decode(crs.classification_id, 'base64'),
                get_secret_key('get_classifications')
            )::INT;
        EXCEPTION
            WHEN OTHERS THEN
            RAISE EXCEPTION 'Valid "Classification ID" is required.'
                USING ERRCODE = 'P0035';
        END;

        -- decrypt the course id
        BEGIN
            dcrpt_crs_id := pgp_sym_decrypt(
                decode(crs.crs_id, 'base64'),
                get_secret_key('get_courses')
            )::INT;
        EXCEPTION
            WHEN OTHERS THEN
            RAISE EXCEPTION 'Valid "Course ID" is required.'
                USING ERRCODE = 'P0035';
        END;

        IF EXISTS (
            SELECT 1
            FROM prospectus_course
            WHERE crs_code = crs.crs_code
        ) THEN
            RAISE EXCEPTION 'This Course/MIS Code is already used for "%"',
                (SELECT c.crs_title
                 FROM prospectus_course pc
                     INNER JOIN internal.course c on c.crs_id = pc.crs_id
                 WHERE pc.crs_code = crs.crs_code LIMIT 1)
                    USING ERRCODE = 'P0031';
        end if;

        -- CHECK IF ALL CLASSIFICATIONS ARE PRESENT
        SELECT classification INTO curr_class FROM classification WHERE classification_id = dcrpt_crs_id;


        -- ✅ Check if current code already appeared in this payload
        IF crs.crs_code = ANY(seen_codes) THEN
            RAISE EXCEPTION
                'Duplicate Course/MIS code "%" detected within the newly added courses. Please review them again.',
                crs.crs_code
                USING ERRCODE = 'P0031';
        END IF;

        -- ✅ Remember this code for later comparisons
        seen_codes := array_append(seen_codes, crs.crs_code);


        -- FETCH THE CU_ID FROM CLASSIFICATION_UNIT BASED ON CLASSIFICATION_ID
        SELECT cu_id INTO fetched_cu_id
        FROM classification_unit
        WHERE classification_id = dcrpt_classif_id AND prospectus_id = returned_prospectus_id
        limit 1;

        IF fetched_cu_id IS NULL THEN
            SELECT crs_title INTO fetched_crs_title
            FROM course
            WHERE crs_id = dcrpt_crs_id LIMIT 1;

            SELECT classification INTO fetched_classif
            FROM classification
            WHERE classification_id = dcrpt_classif_id LIMIT 1;

            RAISE EXCEPTION
                'Course "%" cannot be assigned to classification "%" because it is not defined in this Prospectus.',
                fetched_crs_title,
                fetched_classif
                USING ERRCODE = 'P0032';
        end if;

        -- begin insert
        INSERT INTO internal.prospectus_course (prospectus_id, crs_id, cu_id, CRS_CODE)
        VALUES (returned_prospectus_id, dcrpt_crs_id, fetched_cu_id, crs.crs_code);
    END LOOP;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
REVOKE ALL ON PROCEDURE internal.create_prospectus(
    IN p_special_id TEXT,
    IN p_year INTEGER,
    IN p_semesters_and_duration JSONB,
    IN p_classifications_and_units JSONB,
    IN p_courses_and_classification_units JSONB
) FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE internal.create_prospectus(
    IN p_special_id TEXT,
    IN p_year INTEGER,
    IN p_semesters_and_duration JSONB,
    IN p_classifications_and_units JSONB,
    IN p_courses_and_classification_units JSONB
) TO authenticated;

---- 2.3.1 Get all semesters

CREATE OR REPLACE FUNCTION internal.get_semesters()
RETURNS TABLE(id TEXT, name TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal, extensions
AS $$
BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['admin','dean'])) = FALSE THEN
        RETURN;
    end if;

    IF internal.get_secret_key('get_semesters') IS NOT NULL THEN
        RETURN QUERY
            SELECT
                encode(
                    pgp_sym_encrypt(sem_id::TEXT, internal.get_secret_key('get_semesters')),'base64')::TEXT,

                -- Semester Title/Name
                sem_name::text

            FROM internal.semester;
    ELSE
        -- Return a dummy empty row (or use RETURN QUERY with WHERE false)
        RETURN QUERY
        SELECT NULL::TEXT, NULL::TEXT
        WHERE FALSE;
    END IF;
END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION internal.get_semesters() FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION internal.get_semesters() TO authenticated;

---- 2.3.2 Get all classifications

CREATE OR REPLACE FUNCTION internal.get_classifications() -- ari ko human
RETURNS TABLE(id TEXT, name TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['admin'])) = FALSE THEN
        RETURN;
    end if;

    IF internal.get_secret_key('get_classifications') IS NOT NULL THEN
        RETURN QUERY
            SELECT
                encode(
                    pgp_sym_encrypt(classification_id::TEXT, internal.get_secret_key('get_classifications')),'base64')::TEXT,

                -- Semester Title/Name
                classification::text

            FROM internal.classification;
    ELSE
        -- Return a dummy empty row (or use RETURN QUERY with WHERE false)
        RETURN QUERY
        SELECT NULL::TEXT, NULL::TEXT
        WHERE FALSE;
    END IF;
END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION internal.get_classifications() FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION internal.get_classifications() TO authenticated;

---- 2.3.3 Get all courses

CREATE OR REPLACE FUNCTION internal.get_courses()
RETURNS TABLE(id TEXT, name TEXT, unit TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['admin'])) = FALSE THEN
        RETURN QUERY
        SELECT NULL::TEXT, NULL::TEXT, NULL::TEXT
        WHERE FALSE;  -- ensures empty result but same structure
    END IF;

    IF internal.get_secret_key('get_courses') IS NOT NULL THEN
        RETURN QUERY
            SELECT
                encode(
                    pgp_sym_encrypt(crs_id::TEXT, internal.get_secret_key('get_courses')),'base64')::TEXT,

                -- cOURSE title
                crs_title::text,

                -- units
                units::TEXT

            FROM internal.course
            order by crs_title;
    ELSE
        -- Return a dummy empty row (or use RETURN QUERY with WHERE false)
        RETURN QUERY
        SELECT NULL::TEXT, NULL::TEXT, NULL::TEXT
        WHERE FALSE;
    END IF;
END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION internal.get_courses() FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION internal.get_courses() TO authenticated;


---- 2.3.4 Get all YEARS

CREATE OR REPLACE FUNCTION internal.get_years()
RETURNS TABLE(id TEXT, name TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal, extensions
AS $$
BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['admin','dean'])) = FALSE THEN
        RETURN;
    end if;

    IF internal.get_secret_key('get_years') IS NOT NULL THEN
        RETURN QUERY
            SELECT
                encode(
                    pgp_sym_encrypt(year_id::TEXT, internal.get_secret_key('get_years')),'base64')::TEXT,

                -- Semester Title/Name
                year::text

            FROM internal.year;
    ELSE
        -- Return a dummy empty row (or use RETURN QUERY with WHERE false)
        RETURN QUERY
        SELECT NULL::TEXT, NULL::TEXT
        WHERE FALSE;
    END IF;
END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION internal.get_years() FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION internal.get_years() TO authenticated;



---- 2.3.5 Schedule Term for Prospectus (Dean)




--//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


--- 2.4  Update Prospectus


---- 2.4.1 Update the Effective Period

CREATE OR REPLACE PROCEDURE internal.update_pps_year(
    IN p_prospectus_id TEXT,
    IN p_new_year INTEGER
)
SET search_path = internal
AS $$
DECLARE
    dcrpt_prospectus_id INT;
BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['admin'])) = FALSE THEN
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    END IF;

    -- parameter check
    IF p_prospectus_id IS NULL THEN
        RAISE EXCEPTION 'Something went wrong. APS-idx2025.'
            USING ERRCODE = 'P0035';
    ELSIF p_new_year IS NULL OR p_new_year <= 1910 THEN
        RAISE EXCEPTION 'Field "Year" is required or could be invalid and should be at least 1911'
            USING ERRCODE = 'P0035';
    END IF;

    -- decrypt special ID
    dcrpt_prospectus_id := pgp_sym_decrypt(
        decode(p_prospectus_id, 'base64'),
        get_secret_key('view_all_prospectus')
    )::INT;


    -- Step 1. Begin Update Prospectus
    UPDATE prospectus
    SET year = p_new_year
    WHERE prospectus_id = dcrpt_prospectus_id;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
REVOKE ALL ON PROCEDURE internal.update_pps_year(
    IN p_prospectus_id TEXT,
    IN p_new_year INTEGER
) FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE internal.update_pps_year(
    IN p_prospectus_id TEXT,
    IN p_new_year INTEGER
) TO authenticated;

------------------------------------------------------------------------------------------------------------------------

----- 2.4.2 View prospectus's Semester

CREATE OR REPLACE FUNCTION internal.view_pps_semesters(IN p_prospectus_id TEXT)
RETURNS TABLE(id TEXT, name TEXT, year TEXT, duration TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    dcrpt_prospectus_id int;
BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['admin', 'dean'])) = FALSE THEN
        RETURN QUERY
        SELECT NULL::TEXT, NULL::TEXT, NULL::TEXT, NULL::TEXT
        WHERE FALSE;  -- ensures empty result but same structure
    END IF;

    -- decrypt prospectus ID
    dcrpt_prospectus_id := pgp_sym_decrypt(
        decode(p_prospectus_id, 'base64'),
        get_secret_key('view_all_prospectus')
    )::INT;


    IF internal.get_secret_key('view_pps_semesters') IS NOT NULL THEN
        RETURN QUERY
            SELECT
                encode(
                    pgp_sym_encrypt(ps.prosem_id::TEXT, internal.get_secret_key('view_pps_semesters')),'base64')::TEXT,

                -- Semester name
                s.sem_name::text,

                -- Year
                CONCAT('Year ', y.year),

                -- duration
                to_char(lower(ps.duration), 'Mon DD, YYYY') || ' - ' ||
                to_char(upper(ps.duration), 'Mon DD, YYYY')

            FROM internal.prospectus_semester ps
            INNER JOIN internal.semester s on s.sem_id = ps.sem_id
            INNER JOIN internal.year y on y.year_id = ps.year_id
            where ps.prospectus_id = dcrpt_prospectus_id
            order by y.year, s.sem_num;
    ELSE
        -- Return a dummy empty row (or use RETURN QUERY with WHERE false)
        RETURN QUERY
        SELECT NULL::TEXT, NULL::TEXT, NULL::TEXT, NULL::TEXT
        WHERE FALSE;
    END IF;
END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION internal.view_pps_semesters(IN p_prospectus_id TEXT) FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION internal.view_pps_semesters(IN p_prospectus_id TEXT) TO authenticated;


----- 2.4.2.1 Update Prospectus's Semester

CREATE OR REPLACE PROCEDURE internal.update_pps_semester(
    IN p_pps_sem_id TEXT,
    IN p_new_starting DATE,
    IN p_new_ending DATE,
    IN p_new_sem_year_id JSONB -- incase they wanna change the semester of this row (optional)
)
SET search_path = internal
AS $$
DECLARE
    dcrpt_prosem_id INT;
    dcrpt_sem_id INT := NULL;
    dcrpt_year_id INT := NULL;


    f_sem_nums INT[];
    f_term_id INT;
    f_curr_sem_num INT;

BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['admin', 'dean'])) = FALSE THEN
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    END IF;

    -- parameter check
    IF p_pps_sem_id IS NULL THEN
        RAISE EXCEPTION 'Something went wrong. APS-idx2025.'
            USING ERRCODE = 'P0035';
    ELSIF p_new_starting IS NULL THEN
        RAISE EXCEPTION 'Field "New starting date" is required.'
            USING ERRCODE = 'P0035';
    ELSIF p_new_ending IS NULL THEN
        RAISE EXCEPTION 'Field "New ending date" is required.'
            USING ERRCODE = 'P0035';
    END IF;

    dcrpt_prosem_id := pgp_sym_decrypt(
        decode(p_pps_sem_id, 'base64'),
        get_secret_key('view_pps_semesters')
    )::INT;


    IF p_new_sem_year_id IS NOT NULL THEN

        dcrpt_sem_id := pgp_sym_decrypt(
            decode((p_new_sem_year_id ->> 'sem_id')::text, 'base64'),
            get_secret_key('get_semesters')
        )::INT;

        dcrpt_year_id := pgp_sym_decrypt(
            decode((p_new_sem_year_id ->> 'year_id')::text, 'base64'),
            get_secret_key('get_years')
        )::INT;

        -- scan for duplication
        IF EXISTS(SELECT 1
                  FROM prospectus_semester
                  WHERE sem_id = dcrpt_sem_id
                    AND year_id = dcrpt_year_id
                    AND prospectus_id = (SELECT prospectus_id FROM prospectus_semester WHERE prosem_id = dcrpt_prosem_id)
                    ) THEN
            RAISE EXCEPTION 'A prospectus cannot contain duplicate years and semesters. Please review it again.'
                USING ERRCODE = 'P0029';
        end if;

        -- get the term type of the semester id to make sure every semester has the same term type
        IF NOT EXISTS(SELECT 1
                  FROM prospectus_semester ps
                  INNER JOIN internal.semester s on s.sem_id = ps.sem_id
                  WHERE ps.prosem_id = dcrpt_prosem_id AND s.ttype_id = (SELECT ttype_id from semester where sem_id = dcrpt_sem_id)) THEN
            RAISE EXCEPTION 'The semester entered does not belong to the same term type group. Please review it again.'
                USING ERRCODE = 'P0028';
        end if;

        -- Step 1: get current term info
        SELECT ttype_id, sem_num
        INTO f_term_id, f_curr_sem_num
        FROM semester
        WHERE sem_id = dcrpt_sem_id;

        -- Step 2: get all previous semester numbers of the same term type
        SELECT array_agg(sem_num)
        INTO f_sem_nums
        FROM semester
        WHERE sem_num < f_curr_sem_num
          AND ttype_id = f_term_id;

        -- Step 3: check that all those sem_nums exist in prospectus_semester
        IF f_sem_nums IS NOT NULL THEN
            IF EXISTS (
                SELECT 1
                FROM semester s
                WHERE s.sem_num = ANY(f_sem_nums)
                  AND s.ttype_id = f_term_id
                  AND NOT EXISTS (
                      SELECT 1
                      FROM prospectus_semester ps
                      WHERE ps.sem_id = s.sem_id
                        AND ps.prospectus_id = (SELECT prospectus_id FROM prospectus_semester WHERE prosem_id = dcrpt_prosem_id)
                  )
            ) THEN
                RAISE EXCEPTION
                    'Cannot proceed: some previous terms are missing from this prospectus.'
                    USING ERRCODE = 'P0028';
            END IF;
        END IF;

        -- Step 4: Prevent skipping years
        DECLARE
            f_curr_year_num INT;
            f_missing_years INT;
        BEGIN
            -- Get the current year's numeric order
            SELECT year INTO f_curr_year_num
            FROM year
            WHERE year_id = dcrpt_year_id;

            -- Only check if not the first year
            IF f_curr_year_num > 1 THEN
                -- Check if all previous years exist in this prospectus
                SELECT COUNT(*) INTO f_missing_years
                FROM year y
                WHERE y.year < f_curr_year_num
                  AND NOT EXISTS (
                      SELECT 1
                      FROM prospectus_semester ps
                      WHERE ps.prospectus_id = (SELECT prospectus_id FROM prospectus_semester WHERE prosem_id = dcrpt_prosem_id)
                        AND ps.year_id = y.year_id
                  );

                IF f_missing_years > 0 THEN
                    RAISE EXCEPTION
                        'Cannot proceed: previous academic years are missing from this prospectus.'
                        USING ERRCODE = 'P0028';
                END IF;
            END IF;
        END;

    end if;


    -- ✅ Check overlap with existing rows
    IF EXISTS (
        SELECT 1
        FROM prospectus_semester ps
        WHERE ps.prospectus_id = (SELECT prospectus_id FROM prospectus_semester WHERE prosem_id = dcrpt_prosem_id)
            AND ps.year_id = (SELECT year_id FROM prospectus_semester WHERE prosem_id = dcrpt_prosem_id)
            AND ps.duration && daterange(p_new_starting, p_new_ending) -- overlap operator
            AND prosem_id != dcrpt_prosem_id
    ) THEN
        RAISE EXCEPTION 'Semester duration % - % overlaps with an existing semester(s) in this prospectus. Please review it again.', p_new_starting, p_new_ending
            USING ERRCODE = 'P0027';
    END IF;

    -- check daterange validity
    IF p_new_starting >= p_new_ending THEN
        RAISE EXCEPTION 'New Starting period can''t be greater or later than New Ending period.'
            USING ERRCODE = 'P0034';
    end if;

    -- Step 4: perform update
    UPDATE prospectus_semester
    SET duration = daterange(p_new_starting, p_new_ending),
        sem_id = COALESCE(dcrpt_sem_id, sem_id),
        year_id = COALESCE(dcrpt_year_id, year_id)
    WHERE prosem_id = dcrpt_prosem_id;


END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
REVOKE ALL ON PROCEDURE internal.update_pps_semester(
    IN p_pps_sem_id TEXT,
    IN p_new_starting DATE,
    IN p_new_ending DATE,
    IN p_new_sem_year_id JSONB
) FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE internal.update_pps_semester(
    IN p_pps_sem_id TEXT,
    IN p_new_starting DATE,
    IN p_new_ending DATE,
    IN p_new_sem_year_id JSONB
) TO authenticated;

----- 2.4.2.2 Add Prospectus's Semester

CREATE OR REPLACE PROCEDURE internal.add_pps_semester(
    IN p_prospectus_id TEXT,
    IN p_sem_id TEXT,
    IN p_year_id TEXT,
    IN p_starting DATE,
    IN p_ending DATE
)
SET search_path = internal
AS $$
DECLARE
    dcrpt_prospectus_id INT;
    dcrpt_sem_id INT := NULL;
    dcrpt_year_id INT := NULL;

    f_sem_nums INT[];
    f_term_id INT;
    f_curr_sem_num INT;
BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['admin', 'dean'])) = FALSE THEN
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    END IF;

    -- parameter check
    IF p_prospectus_id IS NULL THEN
        RAISE EXCEPTION 'Field "Prospectus ID" is required.'
            USING ERRCODE = 'P0035';
    ELSIF p_sem_id IS NULL THEN
        RAISE EXCEPTION 'Field "Semester" is required.'
            USING ERRCODE = 'P0035';
    ELSIF p_year_id IS NULL THEN
        RAISE EXCEPTION 'Field "Year" is required.'
            USING ERRCODE = 'P0035';
    ELSIF p_starting IS NULL THEN
        RAISE EXCEPTION 'Field "Starting date" is required.'
            USING ERRCODE = 'P0035';
    ELSIF p_ending IS NULL THEN
        RAISE EXCEPTION 'Field "Ending date" is required.'
            USING ERRCODE = 'P0035';
    END IF;

    -- decrypt IDs
    BEGIN
        dcrpt_prospectus_id := pgp_sym_decrypt(
            decode(p_prospectus_id, 'base64'),
            get_secret_key('view_all_prospectus')
        )::INT;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Valid Prospectus ID is required.'
                USING ERRCODE = 'P0035';
    END;

    BEGIN
        dcrpt_sem_id := pgp_sym_decrypt(
            decode(p_sem_id, 'base64'),
            get_secret_key('get_semesters')
        )::INT;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Valid Semester ID is required.'
                USING ERRCODE = 'P0035';
    END;

    BEGIN
        dcrpt_year_id := pgp_sym_decrypt(
            decode(p_year_id, 'base64'),
            get_secret_key('get_years')
        )::INT;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Valid Year ID is required.'
                USING ERRCODE = 'P0035';
    END;

    -- scan for duplication
    IF EXISTS (
        SELECT 1
        FROM prospectus_semester
        WHERE sem_id = dcrpt_sem_id
          AND year_id = dcrpt_year_id
          AND prospectus_id = dcrpt_prospectus_id
    ) THEN
        RAISE EXCEPTION 'A prospectus cannot contain duplicate years & semesters "%". Please review it again.',
            (SELECT sem_name FROM semester WHERE sem_id = dcrpt_sem_id)
            USING ERRCODE = 'P0029';
    END IF;

    -- get the term type of the semester id to make sure every semester has the same term type
    IF EXISTS (
        SELECT 1 FROM prospectus_semester WHERE prospectus_id = dcrpt_prospectus_id
    ) THEN
        IF NOT EXISTS (
            SELECT 1
            FROM prospectus_semester ps
            INNER JOIN internal.semester s ON s.sem_id = ps.sem_id
            WHERE prospectus_id = dcrpt_prospectus_id
              AND s.ttype_id = (SELECT ttype_id FROM semester WHERE semester.sem_id = dcrpt_sem_id)
        ) THEN
            RAISE EXCEPTION 'The semester entered does not belong to the same term type group. Please review it again.'
                USING ERRCODE = 'P0028';
        END IF;
    END IF;

    -- ✅ Check overlap with existing rows
    IF EXISTS (
        SELECT 1
        FROM prospectus_semester ps
        WHERE ps.prospectus_id = dcrpt_prospectus_id
          AND ps.duration && daterange(p_starting, p_ending)
    ) THEN
        RAISE EXCEPTION 'Semester duration % - % overlaps with an existing semesters in this prospectus. Please review it again.', p_starting, p_ending
            USING ERRCODE = 'P0027';
    END IF;

    -- check daterange validity
    IF p_starting >= p_ending THEN
        RAISE EXCEPTION 'Starting period can''t be greater or later than Ending period.'
            USING ERRCODE = 'P0034';
    END IF;

    -- Step 1: get current term info
    SELECT ttype_id, sem_num
    INTO f_term_id, f_curr_sem_num
    FROM semester
    WHERE sem_id = dcrpt_sem_id;

    -- Step 2: get all previous semester numbers of the same term type
    SELECT array_agg(sem_num)
    INTO f_sem_nums
    FROM semester
    WHERE sem_num < f_curr_sem_num
      AND ttype_id = f_term_id;

    -- Step 3: check that all those sem_nums exist in prospectus_semester
    IF f_sem_nums IS NOT NULL THEN
        IF EXISTS (
            SELECT 1
            FROM semester s
            WHERE s.sem_num = ANY(f_sem_nums)
              AND s.ttype_id = f_term_id
              AND NOT EXISTS (
                  SELECT 1
                  FROM prospectus_semester ps
                  WHERE ps.sem_id = s.sem_id
                    AND ps.prospectus_id = dcrpt_prospectus_id
              )
        ) THEN
            RAISE EXCEPTION
                'Cannot proceed: some previous terms are missing from this prospectus.'
                USING ERRCODE = 'P0034';
        END IF;
    END IF;

    -- 🆕 Step 4: Check for jumping years
    IF EXISTS (
        SELECT 1
        FROM year y
        WHERE y.year < (SELECT year FROM year WHERE year_id = dcrpt_year_id)
          AND NOT EXISTS (
              SELECT 1
              FROM prospectus_semester ps
              WHERE ps.prospectus_id = dcrpt_prospectus_id
                AND ps.year_id = y.year_id
          )
    ) THEN
        RAISE EXCEPTION 'Cannot proceed: some previous academic years are missing from this prospectus.'
            USING ERRCODE = 'P0034';
    END IF;

    -- ✅ Insert once all checks are passed
    INSERT INTO prospectus_semester (duration, sem_id, prospectus_id, year_id)
    VALUES (daterange(p_starting, p_ending), dcrpt_sem_id, dcrpt_prospectus_id, dcrpt_year_id);

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
REVOKE ALL ON PROCEDURE internal.add_pps_semester(
    IN p_prospectus_id TEXT,
    IN p_sem_id TEXT,
    IN p_year_id TEXT,
    IN p_starting DATE,
    IN p_ending DATE
) FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE internal.add_pps_semester(
    IN p_prospectus_id TEXT,
    IN p_sem_id TEXT,
    IN p_year_id TEXT,
    IN p_starting DATE,
    IN p_ending DATE
) TO authenticated;

----- 2.4.2.3 Delete Prospectus's Semester

CREATE OR REPLACE PROCEDURE internal.delete_pps_semester(
    IN p_pps_sem_id TEXT
)
SET search_path = internal
AS $$
DECLARE
    dcrpt_prosem_id INT;
BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['admin', 'dean'])) = FALSE THEN
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    END IF;

    dcrpt_prosem_id := pgp_sym_decrypt(
            decode(p_pps_sem_id, 'base64'),
            get_secret_key('view_pps_semesters')
    )::INT;

    IF EXISTS(SELECT 1
              FROM prospectus_course
              WHERE prosem_id = dcrpt_prosem_id) THEN
        RAISE EXCEPTION 'This prospectus semester cannot be deleted because courses are currently assigned to it.
                            Please remove the assigned courses before proceeding.'
            USING ERRCODE = 'P0036';
    end if;

    DELETE FROM prospectus_semester WHERE prosem_id = dcrpt_prosem_id;


END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
REVOKE ALL ON PROCEDURE internal.delete_pps_semester(IN p_pps_sem_id TEXT) FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE internal.delete_pps_semester(IN p_pps_sem_id TEXT) TO authenticated;

------------------------------------------------------------------------------------------------------------------------

----- 2.4.3 View prospectus's Classifications

CREATE OR REPLACE FUNCTION internal.view_pps_classifications(IN p_prospectus_id TEXT)
RETURNS TABLE(id TEXT, name TEXT, units TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    dcrpt_prospectus_id int;
BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['admin'])) = FALSE THEN
        RETURN QUERY
        SELECT NULL::TEXT, NULL::TEXT, NULL::TEXT
        WHERE FALSE;  -- ensures empty result but same structure
    END IF;

    -- decrypt prospectus ID
    dcrpt_prospectus_id := pgp_sym_decrypt(
        decode(p_prospectus_id, 'base64'),
        get_secret_key('view_all_prospectus')
    )::INT;


    IF internal.get_secret_key('view_pps_classifications') IS NOT NULL THEN
        RETURN QUERY
            SELECT
                encode(
                    pgp_sym_encrypt(cu.cu_id::TEXT, internal.get_secret_key('view_pps_classifications')),'base64')::TEXT,

                -- Classification name
                c.classification::text,

                -- Required Units
                cu.required_units::TEXT

            FROM internal.classification_unit cu
            INNER JOIN internal.classification c on c.classification_id = cu.classification_id
            where cu.prospectus_id = dcrpt_prospectus_id
            order by c.classification;
    ELSE
        -- Return a dummy empty row (or use RETURN QUERY with WHERE false)
        RETURN QUERY
        SELECT NULL::TEXT, NULL::TEXT, NULL::TEXT
        WHERE FALSE;
    END IF;
END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION internal.view_pps_classifications(IN p_prospectus_id TEXT) FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION internal.view_pps_classifications(IN p_prospectus_id TEXT) TO authenticated;


----- 2.4.3.1 Update Prospectus's Classifications and corresponding required units

CREATE OR REPLACE PROCEDURE internal.update_pps_classification(
    IN p_pps_cu_id TEXT,
    IN p_new_unit NUMERIC(4,2),
    IN p_new_class_id TEXT
)
SET search_path = internal
AS $$
DECLARE
    dcrpt_cu_id INT := NULL;
    dcrpt_classification_id INT := NULL;
BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['admin'])) = FALSE THEN
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    END IF;

    dcrpt_cu_id := pgp_sym_decrypt(
        decode(p_pps_cu_id, 'base64'),
        get_secret_key('view_pps_classifications')
    )::INT;

    -- parameter check
    IF p_pps_cu_id IS NULL THEN
        RAISE EXCEPTION 'Something went wrong. APS-idx2025.'
            USING ERRCODE = 'P0035';
    ELSIF p_new_unit IS NULL THEN
        RAISE EXCEPTION 'Field "New units" is required.'
            USING ERRCODE = 'P0035';
    END IF;

    if p_new_class_id is not null then
        dcrpt_classification_id := pgp_sym_decrypt(
            decode(p_new_class_id, 'base64'),
            get_secret_key('get_classifications')
        )::INT;
    end if;

--     RAISE EXCEPTION 'Youre trying to update to "%, %"', (dcrpt_classification_id),(select classification
--                                                       from classification
--                                                       WHERE classification_id = dcrpt_classification_id)
--             USING ERRCODE = 'P0035';

    -- check for duplicate classification
    IF EXISTS(SELECT 1
              FROM classification_unit
              WHERE classification_id = dcrpt_classification_id
                AND cu_id != dcrpt_cu_id
                AND prospectus_id = (SELECT prospectus_id
                                     FROM internal.classification_unit WHERE cu_id = dcrpt_cu_id)
              ) THEN
        RAISE EXCEPTION 'A prospectus cannot contain duplicate classifications. Please review it again.'
            USING ERRCODE = 'P0030';
    end if;

    UPDATE classification_unit
    SET required_units = COALESCE(p_new_unit, required_units),
        classification_id = COALESCE(dcrpt_classification_id, classification_id)
    WHERE cu_id = dcrpt_cu_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
REVOKE ALL ON PROCEDURE internal.update_pps_classification(
    IN p_pps_cu_id TEXT,
    IN p_new_unit NUMERIC(4,2),
    IN p_new_class_id TEXT
) FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE internal.update_pps_classification(
    IN p_pps_cu_id TEXT,
    IN p_new_unit NUMERIC(4,2),
    IN p_new_class_id TEXT
) TO authenticated;


----- 2.4.3.2 Add Prospectus's Classifications and corresponding required units

CREATE OR REPLACE PROCEDURE internal.add_pps_classification(
    IN p_prospectus_id TEXT,
    IN p_class_id TEXT,
    IN p_units NUMERIC(4,2)
)
SET search_path = internal
AS $$
DECLARE
    dcrpt_prospectus_id INT := NULL;
    dcrpt_classification_id INT := NULL;
BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['admin'])) = FALSE THEN
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    END IF;

    -- parameter check
    IF p_prospectus_id IS NULL THEN
        RAISE EXCEPTION 'Something went wrong. APS-idx2025.'
            USING ERRCODE = 'P0035';
    ELSIF p_class_id IS NULL THEN
        RAISE EXCEPTION 'Field "Classification" is required.'
            USING ERRCODE = 'P0035';
    ELSIF p_units IS NULL THEN
        RAISE EXCEPTION 'Field "units" is required.'
            USING ERRCODE = 'P0035';
    END IF;

    dcrpt_prospectus_id := pgp_sym_decrypt(
            decode(p_prospectus_id, 'base64'),
            get_secret_key('view_all_prospectus')
    )::INT;

    dcrpt_classification_id := pgp_sym_decrypt(
            decode(p_class_id, 'base64'),
            get_secret_key('get_classifications')
    )::INT;

    -- check for duplicate classification
    IF EXISTS(SELECT 1
              FROM classification_unit
              WHERE classification_id = dcrpt_classification_id
                AND prospectus_id = dcrpt_prospectus_id) THEN
        RAISE EXCEPTION 'A prospectus cannot contain duplicate classifications "%". Please review it again.',
            (SELECT classification::TEXT FROM classification WHERE classification_id = dcrpt_prospectus_id)
            USING ERRCODE = 'P0030';
    end if;

    INSERT INTO classification_unit (required_units, prospectus_id, classification_id)
    VALUES (p_units, dcrpt_prospectus_id, dcrpt_classification_id);

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
REVOKE ALL ON PROCEDURE internal.add_pps_classification(
    IN p_prospectus_id TEXT,
    IN p_class_id TEXT,
    IN p_units NUMERIC(4,2)
) FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE internal.add_pps_classification(
    IN p_prospectus_id TEXT,
    IN p_class_id TEXT,
    IN p_units NUMERIC(4,2)
) TO authenticated;

----- 2.4.3.3 Delete Prospectus's Classfication

CREATE OR REPLACE PROCEDURE internal.delete_pps_classification(
    IN p_pps_cu_id TEXT
)
SET search_path = internal
AS $$
DECLARE
    dcrpt_cu_id INT;
BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['admin'])) = FALSE THEN
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    END IF;

    dcrpt_cu_id := pgp_sym_decrypt(
            decode(p_pps_cu_id, 'base64'),
            get_secret_key('view_pps_classifications')
    )::INT;

    IF EXISTS(SELECT 1
              FROM prospectus_course
              WHERE cu_id = dcrpt_cu_id) THEN
        RAISE EXCEPTION 'This prospectus classification cannot be deleted because courses are currently classified to it.
                            Please remove the classified courses before proceeding.'
            USING ERRCODE = 'P0036';
    end if;

    DELETE FROM classification_unit WHERE cu_id = dcrpt_cu_id;


END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
REVOKE ALL ON PROCEDURE internal.delete_pps_classification(IN p_pps_cu_id TEXT) FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE internal.delete_pps_classification(IN p_pps_cu_id TEXT) TO authenticated;


------------------------------------------------------------------------------------------------------------------------

----- 2.4.4 View prospectus's Courses

CREATE OR REPLACE FUNCTION internal.view_pps_courses(IN p_prospectus_id TEXT)
RETURNS TABLE(id TEXT, code TEXT, name TEXT, classification TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    dcrpt_prospectus_id int;
BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['admin'])) = FALSE THEN
        RETURN QUERY
        SELECT NULL::TEXT, NULL::TEXT, NULL::TEXT, NULL::TEXT
        WHERE FALSE;  -- ensures empty result but same structure
    END IF;

    -- decrypt prospectus ID
    dcrpt_prospectus_id := pgp_sym_decrypt(
        decode(p_prospectus_id, 'base64'),
        get_secret_key('view_all_prospectus')
    )::INT;


    IF internal.get_secret_key('view_pps_courses') IS NOT NULL THEN
        RETURN QUERY
            SELECT
                encode(
                    pgp_sym_encrypt(pc.pc_id::TEXT, internal.get_secret_key('view_pps_courses')),'base64')::TEXT,

                -- Course code
                pc.crs_code::text,

                -- Course name
                c2.crs_title::text,

                -- Classification
                c.classification::TEXT

            FROM internal.prospectus_course pc
            INNER JOIN internal.classification_unit cu on cu.cu_id = pc.cu_id
            INNER JOIN internal.classification c on c.classification_id = cu.classification_id
            INNER JOIN internal.course c2 on c2.crs_id = pc.crs_id
            where pc.prospectus_id = dcrpt_prospectus_id
            order by c.classification;
    ELSE
        -- Return a dummy empty row (or use RETURN QUERY with WHERE false)
        RETURN QUERY
        SELECT NULL::TEXT, NULL::TEXT, NULL::TEXT, NULL::TEXT
        WHERE FALSE;
    END IF;
END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION internal.view_pps_courses(IN p_prospectus_id TEXT) FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION internal.view_pps_courses(IN p_prospectus_id TEXT) TO authenticated;

----- 2.4.4.1 Update Prospectus's Courses

CREATE OR REPLACE PROCEDURE internal.update_pps_course(
    IN p_pps_pc_id TEXT,
    IN p_new_class_id TEXT,
    IN p_new_crs_code TEXT
)
SET search_path = internal
AS $$
DECLARE
    dcrpt_pc_id INT := NULL;
    dcrpt_classification_id INT := NULL;
BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['admin'])) = FALSE THEN
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    END IF;

    -- parameter check
    IF p_pps_pc_id IS NULL THEN
        RAISE EXCEPTION 'Something went wrong. APS-idx2025.'
            USING ERRCODE = 'P0035';
    ELSIF p_new_class_id IS NULL THEN
        RAISE EXCEPTION 'Field "New Classification" is required.'
            USING ERRCODE = 'P0035';
    END IF;

    BEGIN
        dcrpt_pc_id := pgp_sym_decrypt(
            decode(p_pps_pc_id, 'base64'),
            get_secret_key('view_pps_courses')
        )::INT;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Valid "Prospectus Course ID" is required.'
                USING ERRCODE = 'P0035';
    END;

    IF p_new_class_id IS NOT NULL THEN
        BEGIN
            dcrpt_classification_id := pgp_sym_decrypt(
                    decode(p_new_class_id, 'base64'),
                    get_secret_key('get_classifications')
            )::INT;
        EXCEPTION
            WHEN OTHERS THEN
                RAISE EXCEPTION 'Valid "Classification ID" is required.'
                USING ERRCODE = 'P0035';
        END;
    END IF;


    IF EXISTS( -- IF THE CLASSIFICATION THEYRE TRYING TO CHANGE TO WAS SET OR STRUCTURED ALREADY
        SELECT cu_id
             from classification_unit
             where classification_id = dcrpt_classification_id
             and prospectus_id = (
                 SELECT prospectus_id
                 FROM prospectus_course
                 WHERE pc_id = dcrpt_pc_id
                 )
    ) THEN

        IF EXISTS(
            SELECT 1
            FROM prospectus_course
            where crs_code = trim(p_new_crs_code)
              and pc_id != dcrpt_pc_id
            and prospectus_id = (select prospectus_id from internal.prospectus_course where pc_id = dcrpt_pc_id)
        )THEN
            RAISE EXCEPTION 'This Course/MIS Code is already in use.'
            USING ERRCODE = 'P0035';
        ELSE
            UPDATE prospectus_course
            SET cu_id = COALESCE(
                    (SELECT cu_id
                     from classification_unit
                     where classification_id = dcrpt_classification_id
                     and prospectus_id = (
                         SELECT prospectus_id
                         FROM prospectus_course
                         WHERE pc_id = dcrpt_pc_id
                         )),
                    cu_id),
                crs_code = COALESCE(trim(p_new_crs_code), crs_code)
            WHERE pc_id = dcrpt_pc_id;

        end if;

    ELSE
        -- IF THE CLASSIFICATION THEYRE TRYING TO CHANGE TO ISNT STRUCTURED THEN THEY HAVETO STRUCTURE IT FIRST.
        RAISE EXCEPTION 'The selected classification is not yet structured for this prospectus. Please structure the classification before making changes.'
        USING ERRCODE = 'P0035';
    end if;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
REVOKE ALL ON PROCEDURE internal.update_pps_course(
    IN p_pps_pc_id TEXT,
    IN p_new_class_id TEXT,
    IN p_new_crs_code TEXT
)FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE internal.update_pps_course(
    IN p_pps_pc_id TEXT,
    IN p_new_class_id TEXT,
    IN p_new_crs_code TEXT
) TO authenticated;

----- 2.4.4.2 Add Prospectus's Course

CREATE OR REPLACE PROCEDURE internal.add_pps_course(
    IN p_prospectus_id TEXT,
    IN p_crs_id TEXT,
    IN p_class_id TEXT,
    IN p_crs_code TEXT
)
SET search_path = internal
AS $$
DECLARE
    dcrpt_prospectus_id INT := NULL;
    dcrpt_crs_id INT := NULL;
    dcrpt_classif_id INT := NULL;
    fetched_cu_id INT;
    fetched_crs_title TEXT;
    fetched_classif TEXT;
BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['admin'])) = FALSE THEN
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    END IF;

    -- parameter check
    IF p_prospectus_id IS NULL THEN
        RAISE EXCEPTION 'Something went wrong. APS-idx2025.'
            USING ERRCODE = 'P0035';
    ELSIF p_crs_id IS NULL THEN
        RAISE EXCEPTION 'Field "Course" is required.'
            USING ERRCODE = 'P0035';
    ELSIF p_class_id IS NULL THEN
        RAISE EXCEPTION 'Field "Classification" is required.'
            USING ERRCODE = 'P0035';
    END IF;

    BEGIN
        dcrpt_prospectus_id := pgp_sym_decrypt(
                decode(p_prospectus_id, 'base64'),
                get_secret_key('view_all_prospectus')
        )::INT;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Valid "Prospectus ID" is required.'
                USING ERRCODE = 'P0035';
    END;

    -- decrypt the classification id
    BEGIN
        dcrpt_classif_id := pgp_sym_decrypt(
            decode(p_class_id, 'base64'),
            get_secret_key('get_classifications')
        )::INT;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Valid "Classification ID" is required.'
                USING ERRCODE = 'P0035';
    END;

    -- decrypt the course id
    BEGIN
        dcrpt_crs_id := pgp_sym_decrypt(
            decode(p_crs_id, 'base64'),
            get_secret_key('get_courses')
        )::INT;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Valid "Course ID" is required.'
                USING ERRCODE = 'P0035';
    END;

    -- check duplicate course code
    IF EXISTS (
        SELECT 1
        FROM prospectus_course
        WHERE crs_code = trim(p_crs_code)
    ) THEN
        RAISE EXCEPTION 'This Course/MIS Code is already used for "%"',
            (SELECT c.crs_title
                FROM prospectus_course pc
                INNER JOIN internal.course c on c.crs_id = pc.crs_id
                WHERE pc.crs_code = trim(p_crs_code) LIMIT 1)
                    USING ERRCODE = 'P0031';
    end if;

    -- check for duplicate course
    IF EXISTS(SELECT 1
              FROM prospectus_course
              WHERE crs_id = dcrpt_crs_id
                AND crs_code = trim(p_crs_code)
                AND prospectus_id = dcrpt_prospectus_id) THEN
        RAISE EXCEPTION 'A prospectus cannot contain duplicate courses. Please review it again.'
            USING ERRCODE = 'P0031';
    end if;

    -- FETCH THE CU_ID FROM CLASSIFICATION_UNIT BASED ON CLASSIFICATION_ID
    SELECT cu_id INTO fetched_cu_id
    FROM classification_unit
    WHERE classification_id = dcrpt_classif_id AND prospectus_id = dcrpt_prospectus_id
    limit 1;


    IF fetched_cu_id IS NULL THEN
        SELECT crs_title INTO fetched_crs_title
        FROM course
        WHERE crs_id = dcrpt_crs_id LIMIT 1;

        SELECT classification INTO fetched_classif
        FROM classification
        WHERE classification_id = dcrpt_classif_id LIMIT 1;

        RAISE EXCEPTION
            'Course "%" cannot be assigned to classification "%" because it is not defined in this Prospectus.',
            fetched_crs_title,
            fetched_classif
            USING ERRCODE = 'P0032';
    end if;

    insert into prospectus_course (prospectus_id, crs_id, cu_id, crs_code)
    values (dcrpt_prospectus_id, dcrpt_crs_id, fetched_cu_id,trim(p_crs_code));

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
REVOKE ALL ON PROCEDURE internal.add_pps_course(
    IN p_prospectus_id TEXT,
    IN p_crs_id TEXT,
    IN p_class_id TEXT,
    IN p_crs_code TEXT
) FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE internal.add_pps_course(
    IN p_prospectus_id TEXT,
    IN p_crs_id TEXT,
    IN p_class_id TEXT,
    IN p_crs_code TEXT
) TO authenticated;

----- 2.4.4.3 Delete Prospectus's Course

CREATE OR REPLACE PROCEDURE internal.delete_pps_course(
    IN p_pps_pc_id TEXT
)
SET search_path = internal
AS $$
DECLARE
    dcrpt_pc_id INT;
BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['admin'])) = FALSE THEN
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    END IF;

    dcrpt_pc_id := pgp_sym_decrypt(
            decode(p_pps_pc_id, 'base64'),
            get_secret_key('view_pps_courses')
    )::INT;

    -- CHECK IF THIS COURSE ALREADY HAS A SCHEDULING
    IF EXISTS(
        select 1
        FROM course_version cv
            INNER JOIN internal.prospectus_course pc on pc.pc_id = cv.version_id
            INNER JOIN internal.course_schedule cs on cv.version_id = cs.version_id
        WHERE pc.pc_id= dcrpt_pc_id
    ) THEN
        RAISE EXCEPTION
        'This course cannot be removed, as the scheduling process for this course has already been initiated by the dean.'
            USING ERRCODE = 'P0036';
    end if;

    DELETE FROM prospectus_course WHERE pc_id = dcrpt_pc_id;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
REVOKE ALL ON PROCEDURE internal.delete_pps_course(IN p_pps_pc_id TEXT) FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE internal.delete_pps_course(IN p_pps_pc_id TEXT) TO authenticated;

------------------------------------------------------------------------------------------------------------------------




--//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


-- 3. Manage Courses


--- 3.1 Create course

CREATE OR REPLACE PROCEDURE internal.create_course(
    IN p_course_title TEXT,
    IN p_units NUMERIC(4,2),
    IN p_certification_ids TEXT[]
)
SET search_path = internal
AS $$
DECLARE
    dcrpt_cert_id INT;
    cert_id TEXT;
    fetched_crs_id INT;
BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['admin'])) = FALSE THEN
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    END IF;

    -- lets check first if this course already exists
    IF EXISTS (SELECT 1 FROM COURSE WHERE crs_title = TRIM(p_course_title)) THEN
        RAISE EXCEPTION 'This course already exist.'
            USING ERRCODE = 'P0033';
    end if;

    -- BEGIN INSERT OF COURSE
    INSERT INTO COURSE (crs_title, units)
    VALUES (trim(p_course_title), p_units)
    RETURNING crs_id INTO fetched_crs_id;

    -- loop through certification IDs if provided
    IF p_certification_ids IS NOT NULL AND array_length(p_certification_ids, 1) > 0 THEN
        FOREACH cert_id IN ARRAY p_certification_ids LOOP
            dcrpt_cert_id := pgp_sym_decrypt(
                decode(cert_id, 'base64'),
                get_secret_key('get_certification_types')
            )::INT;

            INSERT INTO course_certification (crs_id, certification_id)
            VALUES (fetched_crs_id, dcrpt_cert_id);
        END LOOP;
    END IF;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
REVOKE ALL ON PROCEDURE internal.create_course(
    IN p_course_title TEXT,
    IN p_units NUMERIC(4,2),
    IN p_certification_ids TEXT[]
) FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE internal.create_course(
    IN p_course_title TEXT,
    IN p_units NUMERIC(4,2),
    IN p_certification_ids TEXT[]
) TO authenticated;


-- ///////        from here onwards it is the dean's job to make a scheduling for the courses in a prospectus)     //////

--- 3.2 View all Courses in the Prospectus

CREATE OR REPLACE FUNCTION internal.select_prospectus(IN p_prospectus_id TEXT)
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
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    dcrpt_prospectus_id int;
BEGIN
    -- decrypt prospectus ID
    dcrpt_prospectus_id := pgp_sym_decrypt(
        decode(p_prospectus_id, 'base64'),
        get_secret_key('view_all_prospectus')
    )::INT;

    IF (internal.get_secret_key('select_prospectus') IS NOT NULL) and
       ((SELECT check_user_role(ARRAY['admin', 'dean'])) = TRUE) THEN
        RETURN QUERY
            SELECT
                encode(
                    pgp_sym_encrypt(pc.pc_id::TEXT, internal.get_secret_key('select_prospectus')), 'base64'
                )::TEXT,

                -- Course Code
                pc.crs_code::TEXT,

                -- Room
                COALESCE(r.room_code::TEXT, 'No Room Assigned'),

                -- Course name
                c2.crs_title::TEXT,

                -- Units
                c2.units::TEXT,

                -- Classification
                c.classification::TEXT,

                -- Term
                COALESCE(s.sem_name::TEXT, 'Not Assigned'),

                -- term duration
                CASE
                    WHEN ps.duration is not null then
                        to_char(lower(ps.duration), 'Mon DD, YYYY') || ' - ' ||
                        to_char(upper(ps.duration), 'Mon DD, YYYY')
                    else 'Not Assigned'
                END,

                    -- 📌 Aggregated Schedule (formatted timerange)
                COALESCE(
                    (
                        SELECT string_agg(
                            d.day_abbr,
                            '' ORDER BY d.day_id, lower(cs.time)
                        )
                        FROM internal.course_schedule cs
                        JOIN internal.day d ON d.day_id = cs.day_id
                        WHERE cs.version_id = cv.version_id
                    ),
                    'Not Scheduled'
                )::TEXT,

                -- Days grouped by identical time ranges
                COALESCE(
                    (
                        SELECT string_agg(
                             time_range,
                            ' / ' ORDER BY min_day_id, time_range
                        )
                        FROM (
                            SELECT
                                string_agg(d.day_abbr, '' ORDER BY d.day_id) AS day_group,
                                to_char(lower(cs.time), 'HH12:MIam') || ' - ' || to_char(upper(cs.time), 'HH12:MIam') AS time_range,
                                min(d.day_id) AS min_day_id
                            FROM internal.course_schedule cs
                            JOIN internal.day d ON d.day_id = cs.day_id
                            WHERE cs.version_id = cv.version_id
                            GROUP BY cs.time
                        ) grouped
                    ),
                    'Not Scheduled'
                )::TEXT,


                -- Faculty
                CASE
                    WHEN fac.user_id is null then 'No Faculty Assigned'
                    ELSE CONCAT(fac.lname, ', ', fac.fname, ' ', COALESCE(fac.mname, ''))
                END,

                -- Status
                CASE
                    WHEN (
                            COALESCE((SELECT COALESCE(COUNT(lesson_id), 0) FROM lesson where version_id = cv.version_id),0) = 0
                            AND COALESCE((SELECT COALESCE(COUNT(ca_id), 0) FROM course_assessment where version_id = cv.version_id),0) = 0
                         ) AND cv.is_ready IS FALSE AND cv.apvd_rvwd_by IS NULL THEN 'Not Started'
                    WHEN (
                            COALESCE((SELECT COALESCE(COUNT(lesson_id), 0) FROM lesson where version_id = cv.version_id),0) > 0
                            OR COALESCE((SELECT COALESCE(COUNT(ca_id), 0) FROM course_assessment where version_id = cv.version_id),0) > 0
                         ) AND cv.is_ready IS FALSE AND cv.apvd_rvwd_by IS NULL THEN 'Drafting'
                    WHEN cv.is_ready IS FALSE AND cv.apvd_rvwd_by IS NULL AND cv.feedback IS NOT NULL THEN 'Disapproved'
                    WHEN cv.is_ready IS TRUE AND cv.apvd_rvwd_by IS NULL THEN 'Pending Approval'
                    WHEN cv.is_ready IS TRUE AND cv.apvd_rvwd_by IS NOT NULL THEN 'Published'
                    ELSE 'Not Scheduled'
                END

            FROM internal.prospectus_course pc
            INNER JOIN internal.classification_unit cu ON cu.cu_id = pc.cu_id
            INNER JOIN internal.classification c ON c.classification_id = cu.classification_id
            INNER JOIN internal.course c2 ON c2.crs_id = pc.crs_id
            LEFT JOIN internal.prospectus_semester ps ON ps.prosem_id = pc.prosem_id
            LEFT JOIN internal.semester s ON ps.sem_id = s.sem_id
            LEFT JOIN internal.course_version cv ON pc.pc_id = cv.version_id
            LEFT JOIN internal.course_version_faculty cvf ON cvf.version_id = cv.version_id
            LEFT JOIN internal.users fac ON fac.user_id = cvf.user_id
            LEFT JOIN internal.room r ON r.room_id = (
                SELECT cs.room_id
                FROM internal.course_schedule cs
                WHERE cs.version_id = cv.version_id
                LIMIT 1
            )
            WHERE pc.prospectus_id = dcrpt_prospectus_id
            ORDER BY ps.duration DESC, pc.pc_id,
                CASE c.classification
                    WHEN 'Foundation Course' THEN 1
                    WHEN 'Major Course' THEN 2
                    WHEN 'Cognates/Electives' THEN 3
                    WHEN 'Research Design & Writing' THEN 4
                    ELSE 5
                END,
                s.sem_name;
    ELSE
        -- Return a dummy empty row (or use RETURN QUERY with WHERE false)
        RETURN QUERY
        SELECT NULL::TEXT, NULL::TEXT, NULL::TEXT, NULL::TEXT, NULL::TEXT, NULL::TEXT, NULL::TEXT, NULL::TEXT, NULL::TEXT, NULL::TEXT,
               NULL::TEXT, NULL::TEXT
        WHERE FALSE;
    END IF;
END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION internal.select_prospectus(IN p_prospectus_id TEXT) FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION internal.select_prospectus(IN p_prospectus_id TEXT) TO authenticated;







--- 3.3 create a scheduling //a prospectus course cant have a scheduling if it isnt assigned to any semester yet

CREATE OR REPLACE FUNCTION internal.create_schedule(
    IN p_pc_id TEXT,
    IN p_prosem_id TEXT,
    IN p_room_id TEXT,
    IN p_schedule JSONB,
    IN p_faculty TEXT[] -- optional
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    dcrpt_faculty_id INT;
    faculty TEXT;
    msg TEXT;

    overall_current_salary NUMERIC(12,2) := NULL;
    faculty_salary NUMERIC(12,2) := NULL;
BEGIN

    -- confirm user role
    IF (SELECT check_user_role(ARRAY['admin', 'dean'])) = FALSE THEN
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    END IF;

    -- parameter check
    IF p_pc_id IS NULL THEN
        RAISE EXCEPTION 'Field "Prospectus ID" is required.'
            USING ERRCODE = 'P0035';
    ELSIF p_schedule IS NULL OR p_schedule = '{}'::jsonb OR p_schedule = '[]'::jsonb THEN
        RAISE EXCEPTION 'Field "Schedule" is required.'
            USING ERRCODE = 'P0035';
    END IF;

    IF p_faculty IS NOT NULL AND array_length(p_faculty, 1) > 0 THEN

        FOREACH faculty IN ARRAY p_faculty[1:1] LOOP -- [1:1] because we only need to iterate once cause 1 faculty is allowed in the moment

            begin
                dcrpt_faculty_id := pgp_sym_decrypt(
                    decode(faculty, 'base64'),
                    get_secret_key('get_faculties')
                )::INT;
            EXCEPTION
                WHEN OTHERS THEN
                RAISE EXCEPTION 'Valid "Faculty ID" is required.'
                    USING ERRCODE = 'P0035';
            END;

            -- check if faculty is still eligible to handle a load

            -- faculty eq_rate multiplied by the undergrad load
            SELECT
                (((((u.metadata ->> 'undergrad_load')::int) * eq.rate) * 4) + (f.rate * 4)),
                (sg.salary_data ->> 'step1')::numeric(12,2)
            INTO overall_current_salary, faculty_salary
            FROM users u
                INNER JOIN internal.degree d on d.degree_id = u.degree_id
                    INNER JOIN internal.educational_qualification eq on eq.eq_id = d.eq_id
                INNER JOIN internal.faculty_rank f on f.rank_id = u.rank_id
                    INNER JOIN internal.salary_grade sg on sg.sg_id = f.sg_id
            WHERE user_id = dcrpt_faculty_id;


            IF overall_current_salary >= (faculty_salary * 0.75) THEN
                msg := format(
                    'This faculty member''s current salary (%s) has already reached or exceeded the 75%% threshold of the faculty salary (%s). ' ||
                    'Assigning this additional load will push their compensation beyond the recommended limit. ' ||
                    'Do you still want to proceed?',
                    to_char(overall_current_salary, 'FM999999999.00'),
                    to_char(faculty_salary * 0.75, 'FM999999999.00')
                );
            ELSE
                msg := format(
                    'This faculty member''s current salary (%s) is still below the 75%% threshold of the faculty salary (%s). ' ||
                    'You may proceed with the assignment. ' ||
                    'Do you want to continue?',
                    to_char(overall_current_salary, 'FM999999999.00'),
                    to_char(faculty_salary * 0.75, 'FM999999999.00')
                );
            END IF;

        END LOOP;

    ELSE

        msg := 'Do you want to proceed with creating this schedule?';

    END IF;

    RETURN jsonb_build_object(
                    'response_id', encode(
                                        pgp_sym_encrypt(
                                            jsonb_build_object(
                                                'p_pc_id', p_pc_id,
                                                'p_prosem_id', p_prosem_id,
                                                'p_room_id', p_room_id,
                                                'p_schedule', p_schedule,
                                                'p_faculty', coalesce(p_faculty, null),
                                                'expires_at', (now() + interval '5 minutes')  -- set expiry window here
                                            )::text,
                                            internal.get_secret_key('create_schedule')
                                        ),
                                        'base64'
                                    )::text,
                    'response_message', msg
                );

END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION internal.create_schedule(
    IN p_pc_id TEXT,
    IN p_prosem_id TEXT,
    IN p_room_id TEXT,
    IN p_schedule JSONB,
    IN p_faculty TEXT[] -- optional
) FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION internal.create_schedule(
    IN p_pc_id TEXT,
    IN p_prosem_id TEXT,
    IN p_room_id TEXT,
    IN p_schedule JSONB,
    IN p_faculty TEXT[] -- optional
) TO authenticated;

--- 3.3 confirm create scheduling

CREATE OR REPLACE PROCEDURE internal.confirm_create_schedule(IN p_response_id TEXT)
SET search_path = internal
AS $$
DECLARE
    -- native parameter names
    p_pc_id TEXT;
    p_prosem_id TEXT;
    p_room_id TEXT;
    p_schedule JSONB;
    p_faculty TEXT[]; -- optional

    request_payload JSONB;

    dcrpt_version_id INT := NULL;
    dcrpt_prosem_id INT;
    dcrpt_room_id INT;
    sched RECORD;
    dcrpt_day_id INT;
    scanned_days INT[] := '{}';
    dcrpt_faculty_id INT;
    faculty TEXT;
    load_count INT;
    load_capacity INT;

    f_asgnd_date TIMESTAMP;
    act_sender INT;
    act_recipient INT;
    act_version_id INT;
    msg TEXT;
BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['admin', 'dean'])) = FALSE THEN
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    END IF;

    -- decode payload
    BEGIN
        request_payload = (pgp_sym_decrypt(
                    decode(p_response_id, 'base64'),
                    internal.get_secret_key('create_schedule')
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

    -- native parameters assignment
    p_pc_id := (request_payload->>'p_pc_id')::text;
    p_prosem_id := (request_payload->>'p_prosem_id')::text;
    p_room_id := (request_payload->>'p_room_id')::text;
    p_schedule := request_payload->'p_schedule'; -- JSONB

    IF NOT (request_payload ? 'p_faculty') THEN
    -- key does NOT exist
    p_faculty := NULL;

    ELSIF jsonb_typeof(request_payload->'p_faculty') = 'null' THEN
        -- key exists but value IS JSON null
        p_faculty := NULL;

    ELSIF jsonb_typeof(request_payload->'p_faculty') = 'array' THEN
        -- extract array elements
        p_faculty := ARRAY(
            SELECT jsonb_array_elements_text(request_payload->'p_faculty')
        );

    ELSE
        -- key exists but value is not array or null → treat as NULL or error
        p_faculty := NULL;
    END IF;







    -- parameter check
    IF p_pc_id IS NULL THEN
        RAISE EXCEPTION 'Field "Prospectus ID" is required.'
            USING ERRCODE = 'P0035';
    ELSIF p_schedule IS NULL OR p_schedule = '{}'::jsonb OR p_schedule = '[]'::jsonb THEN
        RAISE EXCEPTION 'Field "Schedule" is required.'
            USING ERRCODE = 'P0035';
    END IF;

    BEGIN
        dcrpt_version_id := pgp_sym_decrypt(
                decode(p_pc_id, 'base64'),
                get_secret_key('select_prospectus')
        )::INT;
    EXCEPTION
        WHEN OTHERS THEN
        RAISE EXCEPTION 'Valid "Prospectus Course ID" is required.'
            USING ERRCODE = 'P0035';
    END;

    BEGIN
        dcrpt_prosem_id := pgp_sym_decrypt(
                decode(p_prosem_id, 'base64'),
                get_secret_key('view_pps_semesters')
        )::INT;
    EXCEPTION
        WHEN OTHERS THEN
        RAISE EXCEPTION 'Valid "Prospectus Semester ID" is required.'
            USING ERRCODE = 'P0035';
    END;

--     BEGIN
--         dcrpt_room_id := pgp_sym_decrypt(
--                 decode(p_room_id, 'base64'),
--                 get_secret_key('get_rooms')
--         )::INT;
--     EXCEPTION
--         WHEN OTHERS THEN
--         RAISE EXCEPTION 'Valid "Room ID" is required.'
--             USING ERRCODE = 'P0035';
--     END;

    IF EXISTS (SELECT 1 FROM course_version WHERE version_id = dcrpt_version_id ) THEN
            RAISE EXCEPTION 'This Course already has a schedule.'
                USING ERRCODE = 'P0042';
    end if;

    -- ASSIGN IT TO A SEMESTER FIRSt
    UPDATE prospectus_course
        SET prosem_id = dcrpt_prosem_id
    WHERE pc_id = dcrpt_version_id;

    -- INSERT COURSE VERSION
    INSERT INTO course_version (version_id)
    VALUES (dcrpt_version_id);

    FOR sched IN
    SELECT day,
           start_time,
           end_time
    FROM jsonb_to_recordset(p_schedule)
         AS x(day TEXT, start_time TEXT, end_time TEXT)
    LOOP
        -- decrypt the classification id
        BEGIN
            dcrpt_day_id := pgp_sym_decrypt(
                decode(sched.day, 'base64'),
                get_secret_key('get_days')
            )::INT;
        EXCEPTION
            WHEN OTHERS THEN
            RAISE EXCEPTION 'Valid "Day ID" is required.'
                USING ERRCODE = 'P0035';
        END;

        -- ✅ Prevent duplicate days
        IF NOT (dcrpt_day_id = ANY(scanned_days)) THEN
            scanned_days := array_append(scanned_days, dcrpt_day_id);
        ELSE
            RAISE EXCEPTION 'Duplicate schedule isn''t allowed. Please review it again.'
                USING ERRCODE = 'P0037';
        END IF;

                -- ✅ Validate and normalize times
        BEGIN
            IF sched.start_time IS NULL OR sched.end_time IS NULL THEN
                RAISE EXCEPTION 'Start and end time must not be empty.'
                    USING ERRCODE = 'P0034';
            END IF;

            -- Trim and cast safely
            sched.start_time := trim(sched.start_time);
            sched.end_time := trim(sched.end_time);

            IF sched.end_time::time <= sched.start_time::time THEN
                RAISE EXCEPTION 'End time (%) cannot be earlier or equal to start time (%). Please review it again.',
                                sched.end_time, sched.start_time
                    USING ERRCODE = 'P0034';
            END IF;
        EXCEPTION
            WHEN invalid_text_representation THEN
                RAISE EXCEPTION 'Invalid time format detected. Use HH:MI (24-hour format).'
                    USING ERRCODE = 'P0034';
        END;


--         -- ✅ Cast to TIME for comparison
--         IF sched.end_time::time <= sched.start_time::time THEN
--             RAISE EXCEPTION 'End time (%) cannot be earlier or equal to start time (%). Please review it again.',
--                             sched.end_time, sched.start_time
--                 USING ERRCODE = 'P0034';
--         END IF;

        -- ✅ Insert schedule (using timerange with time values)
        INSERT INTO course_schedule (day_id, version_id, room_id, time)
        VALUES (
          dcrpt_day_id,
          dcrpt_version_id,
          null,
          format('[%s,%s)', (sched.start_time)::time, (sched.end_time)::time)::internal.timerange
        );

    END LOOP;

    -- ASSIGN THE CORRESPONDING FACULTY
    -- as of this moment in front end we will only allow one faculty for one course
    IF p_faculty IS NOT NULL AND array_length(p_faculty, 1) > 0 THEN

        FOREACH faculty IN ARRAY p_faculty[1:1] LOOP -- [1:1] because we only need to iterate once cause 1 faculty is allowed in the moment
            begin
                dcrpt_faculty_id := pgp_sym_decrypt(
                    decode(faculty, 'base64'),
                    get_secret_key('get_faculties')
                )::INT;
            EXCEPTION
                WHEN OTHERS THEN
                RAISE EXCEPTION 'Valid "Faculty ID" is required.'
                    USING ERRCODE = 'P0035';
            END;


--             -- check if faculty is still eligible to handle A LOAD
--             SELECT coalesce(sum(c.units), 0) INTO load_count
--             FROM internal.course_version_faculty cvf
--                 INNER JOIN internal.course_version cv on cv.version_id = cvf.version_id
--                     INNER JOIN internal.prospectus_course pc on pc.pc_id = cv.version_id
--                         INNER JOIN internal.prospectus_semester ps on ps.prosem_id = pc.prosem_id
--                             INNER JOIN internal.course c ON c.crs_id = pc.crs_id
--             WHERE cvf.user_id = dcrpt_faculty_id
--             AND (now()::date <= lower(ps.duration) OR now()::date <@ ps.duration); -- only active/eligible ones
--
--             select fr.teaching_load INTO load_capacity
--             FROM users u
--                 inner join internal.faculty_rank fr on u.rank_id = fr.rank_id
--             where user_id = dcrpt_faculty_id;
--
--             IF load_count >= load_capacity THEN
--                 RAISE EXCEPTION 'Faculty teaching load exceeds capacity: currently assigned % units, but maximum allowed is % units.', load_count, load_capacity
--                 USING ERRCODE = 'P0038';
--             END IF;

            -- see if there's a conflict of schedule the faculty currently handles
            IF EXISTS (
                SELECT 1
                FROM course_schedule cs
                inner join internal.course_version v on v.version_id = cs.version_id
                    inner join internal.course_version_faculty f on v.version_id = f.version_id
                inner join internal.prospectus_course pc2 on pc2.pc_id = v.version_id
                    left join internal.prospectus_semester s on s.prosem_id = pc2.prosem_id
                WHERE f.user_id = dcrpt_faculty_id
                  AND cs.day_id = dcrpt_day_id
                  AND cs.time && format('[%s,%s)', (sched.start_time)::time, (sched.end_time)::time)::internal.timerange -- overlap operator
                  AND s.prosem_id = dcrpt_prosem_id
            ) THEN
                RAISE EXCEPTION 'This "%, % % - %" is in conflict with another course the faculty currently assigned to. Please review it again',
                    (SELECT c.crs_title FROM prospectus_course pc inner join course c on c.crs_id = pc.crs_id where pc.pc_id = dcrpt_version_id),
                    (SELECT day_name FROM DAY WHERE day_id = dcrpt_day_id),
                    sched.start_time, sched.end_time
                    USING ERRCODE = 'P0027';
            END IF;

            --
            INSERT INTO course_version_faculty (version_id, user_id)
            VALUES (dcrpt_version_id, dcrpt_faculty_id)
            returning asgnd_date into f_asgnd_date;

            IF f_asgnd_date IS NOT NULL THEN
                act_version_id := dcrpt_version_id;
                act_sender := (SELECT user_id FROM users WHERE auth_id = auth.uid());
                act_recipient := dcrpt_faculty_id;
                msg := format(
                    'A new Course "%s" has been assigned to you by %s. Please check your My Assigned Courses',
                    (SELECT c.crs_title FROM prospectus_course pc INNER JOIN internal.course c ON c.crs_id = pc.crs_id WHERE pc.pc_id = act_version_id),
                    (SELECT CONCAT(lname, ', ', fname, ' ', COALESCE(mname, '')) FROM users WHERE auth_id = auth.uid())
                );

                INSERT INTO course_activity (sender_id, recipient_id, version_id, type, metadata, message)
                    VALUES (
                        act_sender,
                        act_recipient,
                        act_version_id,
                        'start-exam',
                        jsonb_build_object(
                            'visibility', jsonb_build_array('analytics', 'notification'),
                            'pc_id', act_version_id
                        ),
                    msg
                    );
            end if;

        END LOOP;

    END IF;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
REVOKE ALL ON PROCEDURE internal.confirm_create_schedule(IN p_response_id TEXT) FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE internal.confirm_create_schedule(IN p_response_id TEXT) TO authenticated;



--- 3.3.1 get faculties (will be used in assigning faculty in a course)

CREATE OR REPLACE FUNCTION internal.get_faculties()
RETURNS TABLE(id TEXT, name TEXT, current_load TEXT, maximum_load TEXT, email TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    dcrpt_prospectus_id int;
BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['admin', 'dean'])) = FALSE THEN
        RETURN QUERY
        SELECT NULL::TEXT, NULL::TEXT, NULL::TEXT, NULL::TEXT, NULL::TEXT
        WHERE FALSE;  -- ensures empty result but same structure
    END IF;

    IF internal.get_secret_key('get_faculties') IS NOT NULL THEN
        RETURN QUERY
            SELECT
                encode(
                    pgp_sym_encrypt(u.user_id::TEXT, internal.get_secret_key('get_faculties')),'base64')::TEXT,
                -- Faculty name
                CASE
                    WHEN u.mname is null or u.mname = '' then
                        concat(u.lname, ', ',u.fname)
                    ELSE concat(u.lname, ', ',u.fname, ' ',u.mname)
                END as fac_name,

                -- CURRENT LOAD
                concat(COALESCE(sum(c.units) filter ( where  now()::date <= lower(ps.duration) OR now()::date <@ ps.duration), 0), ' units'),

                -- MAXIMUM LOAD
                null,
                -- EMAIL
                a.email::TEXT
            FROM internal.users u
                LEFT JOIN internal.course_version_faculty cvf on u.user_id = cvf.user_id
                    LEFT JOIN internal.course_version cv on cv.version_id = cvf.version_id
                        LEFT JOIN internal.prospectus_course pc on pc.pc_id = cv.version_id
                            LEFT JOIN internal.prospectus_semester ps on ps.prosem_id = pc.prosem_id
                                LEFT JOIN internal.course c ON c.crs_id = pc.crs_id
                INNER JOIN auth.users a on a.id = u.auth_id
                    INNER JOIN internal.faculty_rank fr ON fr.rank_id = u.rank_id
            group by u.user_id, a.email
            order by fac_name;
    ELSE
        -- Return a dummy empty row (or use RETURN QUERY with WHERE false)
        RETURN QUERY
        SELECT NULL::TEXT, NULL::TEXT, NULL::TEXT, NULL::TEXT, NULL::TEXT
        WHERE FALSE;
    END IF;
END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION internal.get_faculties() FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION internal.get_faculties() TO authenticated;


--- 3.3.2 get Days for the scheduling

CREATE OR REPLACE FUNCTION internal.get_days()
RETURNS TABLE(id TEXT, name TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['admin', 'dean'])) = FALSE THEN
        RETURN QUERY
        SELECT NULL::TEXT, NULL::TEXT
        WHERE FALSE;  -- ensures empty result but same structure
    END IF;

    IF internal.get_secret_key('get_days') IS NOT NULL THEN
        RETURN QUERY
            SELECT DISTINCT
                encode(
                    pgp_sym_encrypt(day_id::TEXT, internal.get_secret_key('get_days')),'base64')::TEXT,

                -- Day name
                day_name::text

            FROM day;
    ELSE
        -- Return a dummy empty row (or use RETURN QUERY with WHERE false)
        RETURN QUERY
        SELECT NULL::TEXT, NULL::TEXT
        WHERE FALSE;
    END IF;
END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION internal.get_days() FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION internal.get_days() TO authenticated;


--- 3.3.2 get rooms

CREATE OR REPLACE FUNCTION internal.get_rooms()
RETURNS TABLE(id TEXT, name TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['admin', 'dean'])) = FALSE THEN
        RETURN QUERY
        SELECT NULL::TEXT, NULL::TEXT
        WHERE FALSE;  -- ensures empty result but same structure
    END IF;

    IF internal.get_secret_key('get_rooms') IS NOT NULL THEN
        RETURN QUERY
            SELECT DISTINCT
                encode(
                    pgp_sym_encrypt(room_id::TEXT, internal.get_secret_key('get_rooms')),'base64')::TEXT,

                -- Day name
                room_code::text

            FROM room order by  room_code;
    ELSE
        -- Return a dummy empty row (or use RETURN QUERY with WHERE false)
        RETURN QUERY
        SELECT NULL::TEXT, NULL::TEXT
        WHERE FALSE;
    END IF;
END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION internal.get_rooms() FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION internal.get_rooms() TO authenticated;


--- 3.3.3 Create Room

CREATE OR REPLACE PROCEDURE internal.create_room(IN p_room_code TEXT)
SET search_path = internal
AS $$
BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['dean'])) = FALSE THEN
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    END IF;

    -- parameter check
    IF p_room_code IS NULL THEN
        RAISE EXCEPTION 'Field "Room code" is required.'
            USING ERRCODE = 'P0035';
    END IF;

    IF EXISTS(
        SELECT 1 FROM room where room_code = trim(p_room_code)
    ) THEN
        RAISE EXCEPTION 'Room code already exist.'
            USING ERRCODE = 'P0035';
    end if;

    INSERT INTO room (room_code) VALUES (TRIM(p_room_code));

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
REVOKE ALL ON PROCEDURE internal.create_room(IN p_room_code TEXT) FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE internal.create_room(IN p_room_code TEXT) TO authenticated;


--- 3.3.4 Update Schedule

CREATE OR REPLACE FUNCTION internal.update_schedule(
    IN p_pc_id TEXT,
    IN p_prosem_id TEXT,
    IN p_room_id TEXT,
    IN p_schedule JSONB,
    IN p_faculty TEXT[] -- optional
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    dcrpt_faculty_id INT;
    faculty TEXT;
    overall_current_salary NUMERIC(12,2) := NULL;
    faculty_salary NUMERIC(12,2) := NULL;

    msg TEXT;
BEGIN

    -- confirm user role
    IF (SELECT check_user_role(ARRAY['admin', 'dean'])) = FALSE THEN
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    END IF;

    -- parameter check
    IF p_pc_id IS NULL THEN
        RAISE EXCEPTION 'Field "Prospectus ID" is required.'
            USING ERRCODE = 'P0035';
    ELSIF p_schedule IS NULL OR p_schedule = '{}'::jsonb OR p_schedule = '[]'::jsonb THEN
        RAISE EXCEPTION 'Field "Schedule" is required.'
            USING ERRCODE = 'P0035';
    END IF;

    IF p_faculty IS NOT NULL AND array_length(p_faculty, 1) > 0 THEN

        FOREACH faculty IN ARRAY p_faculty[1:1] LOOP -- [1:1] because we only need to iterate once cause 1 faculty is allowed in the moment

            begin
                dcrpt_faculty_id := pgp_sym_decrypt(
                    decode(faculty, 'base64'),
                    get_secret_key('get_faculties')
                )::INT;
            EXCEPTION
                WHEN OTHERS THEN
                RAISE EXCEPTION 'Valid "Faculty ID" is required.'
                    USING ERRCODE = 'P0035';
            END;

            -- check if faculty is still eligible to handle a load

            -- faculty eq_rate multiplied by the undergrad load
            SELECT
                (((((u.metadata ->> 'undergrad_load')::int) * eq.rate) * 4) + (f.rate * 4)),
                (sg.salary_data ->> 'step1')::numeric(12,2)
            INTO overall_current_salary, faculty_salary
            FROM users u
                INNER JOIN internal.degree d on d.degree_id = u.degree_id
                    INNER JOIN internal.educational_qualification eq on eq.eq_id = d.eq_id
                INNER JOIN internal.faculty_rank f on f.rank_id = u.rank_id
                    INNER JOIN internal.salary_grade sg on sg.sg_id = f.sg_id
            WHERE user_id = dcrpt_faculty_id;


            IF overall_current_salary >= (faculty_salary * 0.75) THEN
                msg := format(
                    'This faculty member''s current salary (%s) has already reached or exceeded the 75%% threshold of the faculty salary (%s). ' ||
                    'Assigning this additional load will push their compensation beyond the recommended limit. ' ||
                    'Do you still want to proceed?',
                    to_char(overall_current_salary, 'FM999999999.00'),
                    to_char(faculty_salary * 0.75, 'FM999999999.00')
                );
            ELSE
                msg := format(
                    'This faculty member''s current salary (%s) is still below the 75%% threshold of the faculty salary (%s). ' ||
                    'You may proceed with the assignment. ' ||
                    'Do you want to continue?',
                    to_char(overall_current_salary, 'FM999999999.00'),
                    to_char(faculty_salary * 0.75, 'FM999999999.00')
                );
            END IF;

        END LOOP;

    ELSE
        msg := 'Are you sure you want to reschedule this course?';

    END IF;

    RETURN jsonb_build_object(
                    'response_id', encode(
                                        pgp_sym_encrypt(
                                            jsonb_build_object(
                                                'p_pc_id', p_pc_id,
                                                'p_prosem_id', p_prosem_id,
                                                'p_room_id', p_room_id,
                                                'p_schedule', p_schedule,
                                                'p_faculty', p_faculty,
                                                'expires_at', (now() + interval '5 minutes')  -- set expiry window here
                                            )::text,
                                            internal.get_secret_key('update_schedule')
                                        ),
                                        'base64'
                                    )::text,
                    'response_message', msg
                );

END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION internal.update_schedule(
    IN p_pc_id TEXT,
    IN p_prosem_id TEXT,
    IN p_room_id TEXT,
    IN p_schedule JSONB,
    IN p_faculty TEXT[] -- optional
) FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION internal.update_schedule(
    IN p_pc_id TEXT,
    IN p_prosem_id TEXT,
    IN p_room_id TEXT,
    IN p_schedule JSONB,
    IN p_faculty TEXT[] -- optional
) TO authenticated;


--- 3.3.4.2 Confirm Update Schedule

CREATE OR REPLACE PROCEDURE internal.confirm_update_schedule( IN p_response_id TEXT)
SET search_path = internal
AS $$
DECLARE
    -- native parameter names
    p_pc_id TEXT;
    p_prosem_id TEXT;
    p_room_id TEXT;
    p_schedule JSONB;
    p_faculty TEXT[]; -- optional

    request_payload JSONB;

    dcrpt_version_id INT := NULL;
    dcrpt_prosem_id INT;
    dcrpt_room_id INT;
    sched RECORD;
    dcrpt_day_id INT;
    scanned_days INT[] := '{}';
    dcrpt_faculty_id INT;
    faculty TEXT;
    load_count INT;
    load_capacity INT;

    curr_syllabus_id INT;
    curr_wallpaper_id INT;

    f_asgnd_date TIMESTAMP;
    act_sender INT;
    act_recipient INT;
    act_version_id INT;
    msg TEXT;
BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['admin', 'dean'])) = FALSE THEN
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    END IF;

    -- decode payload
    BEGIN
        request_payload = (pgp_sym_decrypt(
                    decode(p_response_id, 'base64'),
                    internal.get_secret_key('update_schedule')
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

    -- native parameters assignment
    p_pc_id := (request_payload->>'p_pc_id')::text;
    p_prosem_id := (request_payload->>'p_prosem_id')::text;
    p_room_id := (request_payload->>'p_room_id')::text;
    p_schedule := request_payload->'p_schedule'; -- JSONB
    IF NOT (request_payload ? 'p_faculty') THEN
    -- key does NOT exist
    p_faculty := NULL;

    ELSIF jsonb_typeof(request_payload->'p_faculty') = 'null' THEN
        -- key exists but value IS JSON null
        p_faculty := NULL;

    ELSIF jsonb_typeof(request_payload->'p_faculty') = 'array' THEN
        -- extract array elements
        p_faculty := ARRAY(
            SELECT jsonb_array_elements_text(request_payload->'p_faculty')
        );

    ELSE
        -- key exists but value is not array or null → treat as NULL or error
        p_faculty := NULL;
    END IF;

    -- parameter check
    IF p_pc_id IS NULL THEN
        RAISE EXCEPTION 'Field "Prospectus ID" is required.'
            USING ERRCODE = 'P0035';
    ELSIF p_schedule IS NULL OR p_schedule = '{}'::jsonb OR p_schedule = '[]'::jsonb THEN
        RAISE EXCEPTION 'Field "Schedule" is required.'
            USING ERRCODE = 'P0035';
    END IF;

    BEGIN
        dcrpt_version_id := pgp_sym_decrypt(
                decode(p_pc_id, 'base64'),
                get_secret_key('select_prospectus')
        )::INT;
    EXCEPTION
        WHEN OTHERS THEN
        RAISE EXCEPTION 'Valid "Prospectus Course ID" is required.'
            USING ERRCODE = 'P0035';
    END;

    BEGIN
        dcrpt_prosem_id := pgp_sym_decrypt(
                decode(p_prosem_id, 'base64'),
                get_secret_key('view_pps_semesters')
        )::INT;
    EXCEPTION
        WHEN OTHERS THEN
        RAISE EXCEPTION 'Valid "Prospectus Semester ID" is required.'
            USING ERRCODE = 'P0035';
    END;

--     BEGIN
--         dcrpt_room_id := pgp_sym_decrypt(
--                 decode(p_room_id, 'base64'),
--                 get_secret_key('get_rooms')
--         )::INT;
--     EXCEPTION
--         WHEN OTHERS THEN
--         RAISE EXCEPTION 'Valid "Room ID" is required.'
--             USING ERRCODE = 'P0035';
--     END;

    -- investigate and prompt the messgae

    -- ASSIGN IT TO A SEMESTER FIRSt
    UPDATE prospectus_course
        SET prosem_id = dcrpt_prosem_id
    WHERE pc_id = dcrpt_version_id;

    -- DELETE EXISTING SCHEDULE
    DELETE FROM course_schedule WHERE version_id = dcrpt_version_id;

    -- DELETE EXISTING FACULTY
    DELETE FROM course_version_faculty WHERE version_id = dcrpt_version_id;

    FOR sched IN
    SELECT day,
           start_time,
           end_time
    FROM jsonb_to_recordset(p_schedule)
         AS x(day TEXT, start_time TEXT, end_time TEXT)
    LOOP
        -- decrypt the classification id
        BEGIN
            dcrpt_day_id := pgp_sym_decrypt(
                decode(sched.day, 'base64'),
                get_secret_key('get_days')
            )::INT;
        EXCEPTION
            WHEN OTHERS THEN
            RAISE EXCEPTION 'Valid "Day ID" is required.'
                USING ERRCODE = 'P0035';
        END;

        -- ✅ Prevent duplicate days
        IF NOT (dcrpt_day_id = ANY(scanned_days)) THEN
            scanned_days := array_append(scanned_days, dcrpt_day_id);
        ELSE
            RAISE EXCEPTION 'Duplicate schedule isn''t allowed. Please review it again.'
                USING ERRCODE = 'P0037';
        END IF;

                -- ✅ Validate and normalize times
        BEGIN
            IF sched.start_time IS NULL OR sched.end_time IS NULL THEN
                RAISE EXCEPTION 'Start and end time must not be empty.'
                    USING ERRCODE = 'P0034';
            END IF;

            -- Trim and cast safely
            sched.start_time := trim(sched.start_time);
            sched.end_time := trim(sched.end_time);

            IF sched.end_time::time <= sched.start_time::time THEN
                RAISE EXCEPTION 'End time (%) cannot be earlier or equal to start time (%). Please review it again.',
                                sched.end_time, sched.start_time
                    USING ERRCODE = 'P0034';
            END IF;
        EXCEPTION
            WHEN invalid_text_representation THEN
                RAISE EXCEPTION 'Invalid time format detected. Use HH:MI (24-hour format).'
                    USING ERRCODE = 'P0034';
        END;


--         -- ✅ Cast to TIME for comparison
--         IF sched.end_time::time <= sched.start_time::time THEN
--             RAISE EXCEPTION 'End time (%) cannot be earlier or equal to start time (%). Please review it again.',
--                             sched.end_time, sched.start_time
--                 USING ERRCODE = 'P0034';
--         END IF;

        -- ✅ Update schedule (using timerange with time values)
        INSERT INTO course_schedule (day_id, version_id, room_id, time)
        VALUES (
          dcrpt_day_id,
          dcrpt_version_id,
          null,
          format('[%s,%s)', (sched.start_time)::time, (sched.end_time)::time)::internal.timerange
        );

    END LOOP;


    -- ASSIGN THE CORRESPONDING FACULTY
    -- as of this moment in front end we will only allow one faculty for one course
    IF p_faculty IS NOT NULL AND array_length(p_faculty, 1) > 0 THEN

        FOREACH faculty IN ARRAY p_faculty[1:1] LOOP -- [1:1] because we only need to iterate once cause 1 faculty is allowed in the moment
            begin
                dcrpt_faculty_id := pgp_sym_decrypt(
                    decode(faculty, 'base64'),
                    get_secret_key('get_faculties')
                )::INT;
            EXCEPTION
                WHEN OTHERS THEN
                RAISE EXCEPTION 'Valid "Faculty ID" is required.'
                    USING ERRCODE = 'P0035';
            END;

            -- see if there's a conflict of schedule the faculty currently handles
            IF EXISTS (
                SELECT 1
                FROM course_schedule cs
                inner join internal.course_version v on v.version_id = cs.version_id
                    inner join internal.course_version_faculty f on v.version_id = f.version_id
                    inner join internal.prospectus_course pc2 on pc2.pc_id = v.version_id
                        left join internal.prospectus_semester s on s.prosem_id = pc2.prosem_id
                WHERE f.user_id = dcrpt_faculty_id
                  AND cs.day_id = dcrpt_day_id
                  AND cs.time && format('[%s,%s)', (sched.start_time)::time, (sched.end_time)::time)::internal.timerange -- overlap operator
                  AND s.prosem_id = dcrpt_prosem_id
                  AND cs.version_id != dcrpt_version_id
            ) THEN
                RAISE EXCEPTION 'This "%, % % - %" is in conflict with another course the faculty currently assigned to. Please review it again',
                    (SELECT c.crs_title FROM prospectus_course pc inner join course c on c.crs_id = pc.crs_id where pc.pc_id = dcrpt_version_id),
                    (SELECT day_name FROM DAY WHERE day_id = dcrpt_day_id),
                    sched.start_time, sched.end_time
                    USING ERRCODE = 'P0027';
--                 RAISE EXCEPTION '%',
--                     (
--                         SELECT
--                             jsonb_agg(
--                                 jsonb_build_object(
--                                     'user_id', f.user_id,
--                                     'day_id', cs.day_id,
--                                     'time', cs.time,
--                                     'prosem_id', s.prosem_id
--                                 )
--                             )
--                         FROM course_schedule cs
--                         inner join internal.course_version v on v.version_id = cs.version_id
--                             inner join internal.course_version_faculty f on v.version_id = f.version_id
--                             inner join internal.prospectus_course pc2 on pc2.pc_id = v.version_id
--                                 left join internal.prospectus_semester s on s.prosem_id = pc2.prosem_id
--                         WHERE f.user_id = dcrpt_faculty_id
--                           AND cs.day_id = dcrpt_day_id
--                           AND cs.time && format('[%s,%s)', (sched.start_time)::time, (sched.end_time)::time)::internal.timerange -- overlap operator
--                           AND s.prosem_id = dcrpt_prosem_id
--                         )
--                     USING ERRCODE = 'P0027';
            END IF;

            -- wipe out current draft data & student data
            --- 1. student data
            DELETE
            FROM student_cm_progress
            WHERE material_id IN ( SELECT cm.material_id
                                   FROM course_material cm
                                   INNER JOIN internal.lesson l on l.lesson_id = cm.lesson_id
                                   WHERE l.version_id = dcrpt_version_id);

            DELETE
            FROM student_ass_progress
            WHERE ass_id IN ( SELECT a.ass_id
                                   FROM assignment a
                                   INNER JOIN internal.lesson l on l.lesson_id = a.lesson_id
                                   WHERE l.version_id = dcrpt_version_id);

            DELETE
            FROM student_test_record
            WHERE test_id IN ( SELECT t.test_id
                                   FROM test t
                                   INNER JOIN internal.lesson l on l.lesson_id = t.lesson_id
                                   WHERE l.version_id = dcrpt_version_id);

            DELETE FROM lesson WHERE version_id = dcrpt_version_id;
            DELETE FROM course_assessment WHERE version_id = dcrpt_version_id;

            DELETE FROM course_activity WHERE version_id = dcrpt_version_id;
            DELETE FROM review_likes WHERE enrollee_id IN ( SELECT mc.enrollee_id
                                                            FROM my_courses mc
                                                            WHERE version_id = dcrpt_version_id);
            UPDATE my_courses SET rating = NULL, review = NULL, review_timestamp = NULL WHERE version_id = dcrpt_version_id;

            UPDATE course_version
            SET about = null,
                is_ready = false,
                apvd_rvwd_by = null
            WHERE version_id = dcrpt_version_id;

            -- SYLLABUS AND WALLPAPER ISN'T WIPED OUT IN THIS MOMENT

            -- BEGIN REASSIGNMENT


            INSERT INTO course_version_faculty (version_id, user_id)
            VALUES (dcrpt_version_id, dcrpt_faculty_id)
            returning asgnd_date into f_asgnd_date;

            UPDATE course_version_faculty
                SET user_id = dcrpt_faculty_id
            WHERE version_id = dcrpt_version_id;

            IF f_asgnd_date IS NOT NULL THEN
                act_version_id := dcrpt_version_id;
                act_sender := (SELECT user_id FROM users WHERE auth_id = auth.uid());
                act_recipient := dcrpt_faculty_id;
                msg := format(
                    'A new Course "%s" has been assigned to you by %s. Please check your My Assigned Courses',
                    (SELECT c.crs_title FROM prospectus_course pc INNER JOIN internal.course c ON c.crs_id = pc.crs_id WHERE pc.pc_id = act_version_id),
                    (SELECT CONCAT(lname, ', ', fname, ' ', COALESCE(mname, '')) FROM users WHERE auth_id = auth.uid())
                );

                INSERT INTO course_activity (sender_id, recipient_id, version_id, type, metadata, message)
                    VALUES (
                        act_sender,
                        act_recipient,
                        act_version_id,
                        'start-exam',
                        jsonb_build_object(
                            'visibility', jsonb_build_array('analytics', 'notification'),
                            'pc_id', act_version_id
                        ),
                    msg
                    );
            end if;

        END LOOP;

    END IF;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
REVOKE ALL ON PROCEDURE internal.confirm_update_schedule( IN p_response_id TEXT) FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE internal.confirm_update_schedule( IN p_response_id TEXT) TO authenticated;


--- 3.4.1 Enrollment -  Bulk enrollment of students for regulars

CREATE OR REPLACE PROCEDURE internal.bulk_enrollment_regular(
    IN p_course_ids TEXT[],
    IN p_student_list JSONB,
    IN p_official_list_file_id UUID
)
SET search_path = internal
AS $$
DECLARE
    ncrpt_pc_id TEXT;
    dcrpt_pc_id INT;

    f_pc_ids INT[];
    v_version_id INT;
    student RECORD;
    to_raise BOOLEAN := FALSE;
    email_list TEXT:= E'Enrollment ran into a problem. Please check the following email(s) as they do not exist: \n\n';
    count int := 1;
    f_object_id UUID := null;
    v_student_id INT;

    v_sem_range daterange;

    f_enrollee_id INT;
    act_sender INT;
    act_recipient INT;
    act_version_id INT;
    msg TEXT;
BEGIN

    -- confirm user role
    IF (SELECT check_user_role(ARRAY['dean'])) = FALSE THEN
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    END IF;

    -- parameter check
    IF p_student_list IS NULL OR p_student_list = '{}'::jsonb OR p_student_list = '[]'::jsonb THEN
        RAISE EXCEPTION 'Field "Student list" is required.'
            USING ERRCODE = 'P0035';
    END IF;

    -- LOCATE FILE
    select id into f_object_id
    FROM storage.objects
    where bucket_id = 'enrollment-docs'
    AND name like concat('official_list/', p_official_list_file_id ,'%')
    and owner = auth.uid();

    if f_object_id is null then
        RAISE EXCEPTION 'Uploaded official class list file is missing or doesn''t exist'
            USING ERRCODE = 'P0041';
    end if;

    -- GET ALL COURSES and decrypt
    IF p_course_ids IS NOT NULL OR array_length(p_course_ids, 1) != 0 THEN
        FOREACH ncrpt_pc_id IN ARRAY p_course_ids LOOP
            BEGIN
                dcrpt_pc_id := pgp_sym_decrypt(
                        decode(ncrpt_pc_id, 'base64'),
                        get_secret_key('select_prospectus')
                )::INT;
            EXCEPTION
                WHEN OTHERS THEN
                    RAISE EXCEPTION 'Valid "Course Id" is required.'
                        USING ERRCODE = 'P1000';
            END;

            IF NOT EXISTS(
                SELECT 1 FROM course_version WHERE version_id = dcrpt_pc_id
            )THEN
                RAISE EXCEPTION 'Enrollment could not proceed: This course % doesn''t exist or haven''t been scheduled yet.',
                    ( SELECT c2.crs_title
                      FROM prospectus_course pc
                         inner join internal.course c2 on c2.crs_id = pc.crs_id
                      WHERE pc.pc_id = dcrpt_pc_id
                    )
                        USING ERRCODE = 'P0055';
            end if;

            -- Append the decrypted course ID to the array
            f_pc_ids := array_append(f_pc_ids, dcrpt_pc_id);

        END LOOP;
    ELSE
        RAISE EXCEPTION 'Field "Course Id''s" is required.'
            USING ERRCODE = 'P0035';
    END IF;

    -- BEGIN ITERATING EACH COURSE WITH SCHEDULE
    IF f_pc_ids IS NOT NULL OR array_length(f_pc_ids, 1) > 0 THEN
        FOREACH v_version_id IN ARRAY f_pc_ids LOOP
            FOR student IN
            SELECT email
            FROM jsonb_to_recordset(p_student_list)
                AS x(email TEXT)
            LOOP
                --- getting the students user_id thru email
                SELECT u.user_id INTO v_student_id
                FROM users u
                inner join auth.users a on u.auth_id = a.id
                inner join internal.designation_and_role d on u.dar_id = d.dar_id
                WHERE a.email = student.email and d.dar_name = 'student';


                -- begin enrolling in every courses available
                if v_student_id is not null then

                    -- enroll the student
                    INSERT INTO my_courses (user_id, version_id, official_list)
                    VALUES (v_student_id, v_version_id, f_object_id)
                    ON CONFLICT DO NOTHING -- avoid duplicate enrollments
                    RETURNING enrollee_id INTO f_enrollee_id;

                else
                    to_raise := TRUE;
                    email_list := CONCAT(email_list, count::TEXT, ') ', student.email, E'\n');
                    count := count + 1;
                end if;

                IF f_enrollee_id IS NOT NULL THEN
                    act_version_id := v_version_id;
                    act_sender := (SELECT user_id FROM users WHERE auth_id = auth.uid());
                    act_recipient := v_student_id;

                    SELECT ps.duration INTO v_sem_range
                    FROM prospectus_course pc
                    INNER JOIN internal.prospectus_semester ps ON ps.prosem_id = pc.prosem_id
                    WHERE pc.pc_id = act_version_id;

                    IF now()::date <@ v_sem_range THEN
                        msg := format(
                        'Congratulations! You’re now enrolled in %s. Get ready to start learning and explore new ideas!',
                        (SELECT c.crs_title FROM prospectus_course pc INNER JOIN internal.course c ON c.crs_id = pc.crs_id WHERE pc.pc_id = act_version_id)
                    );
                    ELSE
                        msg := format(
                          '🎉 You’re now enrolled in %s! The course isn’t open yet — it will be available on %s. Stay tuned!',
                          (SELECT c.crs_title FROM prospectus_course pc INNER JOIN internal.course c ON c.crs_id = pc.crs_id WHERE pc.pc_id = act_version_id),
                          to_char(lower(v_sem_range), 'Month DD, YYYY')
                        );
                    END IF;

                    INSERT INTO course_activity (sender_id, recipient_id, version_id, type, metadata, message)
                        VALUES (
                            act_sender,
                            act_recipient,
                            act_version_id,
                            'regular-enrollment',
                            jsonb_build_object(
                                'visibility', jsonb_build_array('analytics', 'notification'),
                                'pc_id', act_version_id
                            ),
                        msg
                        );
                end if;
            END LOOP;
        END LOOP;
    ELSE
        RAISE EXCEPTION 'Enrollment could not proceed: the chosen prospectus has no schedule assigned. Please schedule courses before retrying.'
            USING ERRCODE = 'P0055';
    END IF;

    if to_raise is true then
        RAISE EXCEPTION '%', email_list
            USING ERRCODE = 'P0014';
    end if;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
REVOKE ALL ON PROCEDURE internal.bulk_enrollment_regular(
    IN p_course_ids TEXT[],
    IN p_student_list JSONB,
    IN p_official_list_file_id UUID
) FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE internal.bulk_enrollment_regular(
    IN p_course_ids TEXT[],
    IN p_student_list JSONB,
    IN p_official_list_file_id UUID
) TO authenticated;

--- 3.4.2 Enrollment -   Single Enrollment for irregular/Transferee using Proof of Credit

CREATE OR REPLACE PROCEDURE internal.transferee_enrollment(
    IN p_student_email TEXT,
    IN p_course_ids TEXT[],
    IN p_proof_of_credit_file_id UUID
)
SET search_path = internal
AS $$
DECLARE
    ncrpt_pc_id TEXT;
    dcrpt_pc_id INT;
    f_object_id UUID := null;
    f_user_id INT;
    v_sem_range daterange;

    f_enrollee_id INT;
    act_sender INT;
    act_recipient INT;
    act_version_id INT;
    msg TEXT;
BEGIN

    -- confirm user role
    IF (SELECT check_user_role(ARRAY['dean'])) = FALSE THEN
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    END IF;

    -- check ig this student account exists
    SELECT u2.user_id INTO f_user_id
    FROM users u2
    INNER JOIN auth.users a on u2.auth_id = a.id
    WHERE a.email = trim(p_student_email);

    IF f_user_id IS NULL THEN
        RAISE EXCEPTION 'This student doesn''t exist.'
            USING ERRCODE = 'P0014';
    end if;

    -- LOCATE FILE
    select id into f_object_id
    FROM storage.objects
    where bucket_id = 'enrollment-docs'
    AND name like concat('poc/', p_proof_of_credit_file_id ,'%')
    and owner = auth.uid();

    if f_object_id is null then
        RAISE EXCEPTION 'Uploaded Proof of credit file is missing or doesn''t exist'
            USING ERRCODE = 'P0041';
    end if;

    IF p_course_ids IS NOT NULL OR array_length(p_course_ids, 1) != 0 THEN
        FOREACH ncrpt_pc_id IN ARRAY p_course_ids LOOP
            BEGIN
                dcrpt_pc_id := pgp_sym_decrypt(
                        decode(ncrpt_pc_id, 'base64'),
                        get_secret_key('select_prospectus')
                )::INT;
            EXCEPTION
                WHEN OTHERS THEN
                    RAISE EXCEPTION 'Valid "Course Id" is required.'
                        USING ERRCODE = 'P1000';
            END;

            IF NOT EXISTS(
                SELECT 1 FROM course_version WHERE version_id = dcrpt_pc_id
            )THEN
                RAISE EXCEPTION 'Enrollment could not proceed: This course doesn''t exist or haven''t been scheduled yet.'
                        USING ERRCODE = 'P0055';
            end if;

            IF EXISTS(
                SELECT 1
                FROM my_courses
                inner join internal.users u on u.user_id = my_courses.user_id
                inner join auth.users a on a.id = u.auth_id
                WHERE a.email = p_student_email AND version_id = dcrpt_pc_id
            )THEN
                RAISE EXCEPTION 'Student "%" is already enrolled in this course', p_student_email
                        USING ERRCODE = 'P0056';
            end if;

            INSERT INTO my_courses (user_id, version_id, proof_of_credit)
            VALUES (f_user_id, dcrpt_pc_id, f_object_id)
            ON CONFLICT DO NOTHING
            RETURNING enrollee_id INTO f_enrollee_id; -- avoid duplicate enrollments


            IF f_enrollee_id IS NOT NULL THEN
                    act_version_id := dcrpt_pc_id;
                    act_sender := (SELECT user_id FROM users WHERE auth_id = auth.uid());
                    act_recipient := f_user_id;

                    SELECT ps.duration INTO v_sem_range
                    FROM prospectus_course pc
                    INNER JOIN internal.prospectus_semester ps ON ps.prosem_id = pc.prosem_id
                    WHERE pc.pc_id = act_version_id;

                    IF now()::date <@ v_sem_range THEN
                        msg := format(
                        'Congratulations! You’re now enrolled in %s. Get ready to start learning and explore new ideas!',
                        (SELECT c.crs_title FROM prospectus_course pc INNER JOIN internal.course c ON c.crs_id = pc.crs_id WHERE pc.pc_id = act_version_id)
                    );
                    ELSE
                        msg := format(
                          '🎉 You’re now enrolled in %s! The course isn’t open yet — it will be available on %s. Stay tuned!',
                          (SELECT c.crs_title FROM prospectus_course pc INNER JOIN internal.course c ON c.crs_id = pc.crs_id WHERE pc.pc_id = act_version_id),
                          to_char(lower(v_sem_range), 'Month DD, YYYY')
                        );
                    END IF;

                    INSERT INTO course_activity (sender_id, recipient_id, version_id, type, metadata, message)
                        VALUES (
                            act_sender,
                            act_recipient,
                            act_version_id,
                            'transferee-enrollment',
                            jsonb_build_object(
                                'visibility', jsonb_build_array('analytics', 'notification'),
                                'pc_id', act_version_id
                            ),
                        msg
                        );
            end if;

        END LOOP;
    ELSE
        RAISE EXCEPTION 'Field "Course Id''s" is required.'
            USING ERRCODE = 'P0035';
    END IF;


END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
REVOKE ALL ON PROCEDURE internal.transferee_enrollment(
    IN p_student_email TEXT,
    IN p_course_ids TEXT[],
    IN p_proof_of_credit_file_id UUID
) FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE internal.transferee_enrollment(
    IN p_student_email TEXT,
    IN p_course_ids TEXT[],
    IN p_proof_of_credit_file_id UUID
) TO authenticated;




--- 3.5 View enrolled students

CREATE OR REPLACE FUNCTION internal.view_enrolled_students(IN p_version_id TEXT)
RETURNS TABLE(
    id TEXT,
    name TEXT,
    email TEXT,
    enrollment_status TEXT,
    learning_progress TEXT -- soon
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    dcrpt_version_id int;
BEGIN
    -- decrypt prospectus ID
    dcrpt_version_id := pgp_sym_decrypt(
        decode(p_version_id, 'base64'),
        get_secret_key('select_prospectus')
    )::INT;

    IF (internal.get_secret_key('view_enrolled_students') IS NOT NULL) and
       ((SELECT check_user_role(ARRAY['admin', 'dean'])) = TRUE) THEN
        RETURN QUERY
            SELECT DISTINCT
                encode(
                    pgp_sym_encrypt(u.user_id::TEXT, internal.get_secret_key('view_enrolled_students')),'base64')::TEXT,

                -- Student name
                concat(u.lname, ', ', u.fname, ' ',coalesce(u.mname, '')),

                -- email
                a.email::text,

                -- enrollment status
                CASE
                    WHEN mc.enrollment_status is FALSE THEN 'Dropped/Withdrawn'
                    WHEN mc.enrollment_status IS TRUE AND coalesce(COUNT(ca.activity_id),0) < 1
                        then 'Enrolled'
                    WHEN mc.enrollment_status IS TRUE AND coalesce(COUNT(ca.activity_id),0) >= 1
                        then 'In Progress'
                   -- "Incomplete" tag will be available soon
                    -- when enrollment status is true and semester is already over and its not yet been a year since
                   -- "Failed" when semester is already over and its been more than a year
                END,
                -- learning progress
                'Available soon'


            FROM internal.my_courses mc
            inner join internal.users u on u.user_id = mc.user_id
            inner join auth.users a on a.id = u.auth_id
            left join internal.course_activity ca on ca.version_id = mc.version_id
            WHERE mc.version_id  = dcrpt_version_id
            group by u.user_id, u.lname, u.fname, u.mname, a.email, mc.enrollment_status;
    ELSE
        -- Return a dummy empty row (or use RETURN QUERY with WHERE false)
        RETURN QUERY
        SELECT NULL::TEXT, NULL::TEXT, NULL::TEXT, NULL::TEXT, NULL::TEXT
        WHERE FALSE;
    END IF;
END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION internal.view_enrolled_students(IN p_version_id TEXT) FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION internal.view_enrolled_students(IN p_version_id TEXT) TO authenticated;



-- 4.) DOWNLOAD PROSPECTUS

CREATE OR REPLACE FUNCTION internal.get_prospectus_data(IN p_prospectus_id TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    dcrpt_prospectus_id int;
    head JSONB;
    classification_ids INT[];
    class INT;
    prospectus JSONB := '[]'::jsonb;
    entry_requirements TEXT[];
    summary JSONB;
BEGIN


    BEGIN
        dcrpt_prospectus_id := pgp_sym_decrypt(
            decode(p_prospectus_id, 'base64'),
            get_secret_key('view_all_prospectus')
        )::INT;
    EXCEPTION
        WHEN OTHERS THEN
            BEGIN
                dcrpt_prospectus_id := pgp_sym_decrypt(
                    decode(p_prospectus_id, 'base64'),
                    get_secret_key('view_program')
                )::INT;
            EXCEPTION
                WHEN OTHERS THEN
                    RAISE EXCEPTION 'Valid Prospectus ID is required.'
                        USING ERRCODE = 'P0035';
            END;
    END;

    IF (internal.get_secret_key('get_prospectus_data') IS NOT NULL) and
       ((SELECT check_user_role(ARRAY['admin', 'dean', 'student', 'faculty'])) = TRUE) THEN

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
            SELECT array_agg(cu_id) INTO classification_ids FROM classification_unit WHERE prospectus_id = dcrpt_prospectus_id;

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
                'entry_requirements', coalesce(entry_requirements, '{}'::text[]),
                'summary_of_credit_units_to_graduate', coalesce(summary, '[]'::jsonb)
            );



        -- classification ---------- maximum units
        -- course code
        -- course name
        -- course units

        -- total credits units
    ELSE
        RETURN jsonb_build_object(
                    'head', coalesce(null, '[]'::jsonb),
                    'body', coalesce(null, '[]'::jsonb),
                    'entry_requirements', coalesce(entry_requirements, '[]'::jsonb),
                    'summary_of_credit_units_to_graduate', coalesce(summary, '[]'::jsonb)
                );
    END IF;

END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION internal.get_prospectus_data(IN p_prospectus_id TEXT) FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION internal.get_prospectus_data(IN p_prospectus_id TEXT) TO authenticated;



-- 5.) APPROVE COURSE

CREATE OR REPLACE PROCEDURE internal.approve_course( IN p_pc_id TEXT)
SET search_path = internal
AS $$
DECLARE
    dcrpt_version_id INT := NULL;

    rows_updated INT := NULL;
    act_sender INT;
    act_recipient INT;
    act_version_id INT;
    msg TEXT;
BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['dean'])) = FALSE THEN
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    END IF;


    BEGIN
        dcrpt_version_id := pgp_sym_decrypt(
                decode(p_pc_id, 'base64'),
                get_secret_key('select_prospectus')
        )::INT;
    EXCEPTION
        WHEN OTHERS THEN
        RAISE EXCEPTION 'Valid "Prospectus Course ID" is required.'
            USING ERRCODE = 'P0035';
    END;

    IF EXISTS (SELECT 1 FROM course_version WHERE version_id = dcrpt_version_id) THEN
        IF EXISTS (SELECT 1 FROM course_version WHERE version_id = dcrpt_version_id AND is_ready IS TRUE) THEN
            IF EXISTS (SELECT 1 FROM course_version WHERE version_id = dcrpt_version_id AND is_ready IS TRUE AND apvd_rvwd_by IS NULL) THEN

                UPDATE course_version
                SET apvd_rvwd_by = (SELECT user_id FROM users WHERE auth_id = auth.uid()),
                    feedback = NULL
                WHERE version_id = dcrpt_version_id;

                GET DIAGNOSTICS rows_updated = ROW_COUNT;

                IF rows_updated > 0 THEN

                    act_version_id := dcrpt_version_id;
                    act_sender := (SELECT user_id FROM users WHERE auth_id = auth.uid());
                    act_recipient := (SELECT user_id FROM course_version_faculty WHERE version_id = act_version_id);
                    msg := format(
                        'Congratulations! Your course %s has been approved and is now live for students to enroll in. Thank you for your contribution!',
                        (SELECT c.crs_title FROM prospectus_course pc INNER JOIN internal.course c ON c.crs_id = pc.crs_id WHERE pc.pc_id = act_version_id)
                    );

                    INSERT INTO course_activity (sender_id, recipient_id, version_id, type, metadata, message)
                        VALUES (
                            act_sender,
                            act_recipient,
                            act_version_id,
                            'approve-course',
                            jsonb_build_object(
                                'visibility', jsonb_build_array('analytics', 'notification'),
                                'pc_id', act_version_id
                            ),
                        msg
                        );
                end if;
            ELSE
                RAISE EXCEPTION 'This Course is already approved and published.'
                    USING ERRCODE = 'P0057';
            end if;
        ELSE
            RAISE EXCEPTION 'This Course is not yet ready for review.'
                USING ERRCODE = 'P0058';
        end if;
    ELSE
        RAISE EXCEPTION 'This Course doesn''t exists.'
                USING ERRCODE = 'P0054';
    end if;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
REVOKE ALL ON PROCEDURE internal.approve_course(IN p_pc_id TEXT) FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE internal.approve_course(IN p_pc_id TEXT) TO authenticated;

-- 5.1) Disapprove Course

CREATE OR REPLACE PROCEDURE internal.disapprove_course( IN p_pc_id TEXT, IN p_feedback TEXT)
SET search_path = internal
AS $$
DECLARE
    dcrpt_version_id INT := NULL;

    rows_updated INT := NULL;
    act_sender INT;
    act_recipient INT;
    act_version_id INT;
    msg TEXT;
BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['dean'])) = FALSE THEN
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    END IF;


    BEGIN
        dcrpt_version_id := pgp_sym_decrypt(
                decode(p_pc_id, 'base64'),
                get_secret_key('select_prospectus')
        )::INT;
    EXCEPTION
        WHEN OTHERS THEN
        RAISE EXCEPTION 'Valid "Prospectus Course ID" is required.'
            USING ERRCODE = 'P0035';
    END;

    IF EXISTS (SELECT 1 FROM course_version WHERE version_id = dcrpt_version_id) THEN
        IF EXISTS (SELECT 1 FROM course_version WHERE version_id = dcrpt_version_id AND is_ready IS TRUE) THEN
            IF EXISTS (SELECT 1 FROM course_version WHERE version_id = dcrpt_version_id AND is_ready IS TRUE AND apvd_rvwd_by IS NULL) THEN

                UPDATE course_version
                SET apvd_rvwd_by = NULL,
                    is_ready = FALSE,
                    feedback = trim(p_feedback)
                WHERE version_id = dcrpt_version_id;

                GET DIAGNOSTICS rows_updated = ROW_COUNT;

                IF rows_updated > 0 THEN

                    act_version_id := dcrpt_version_id;
                    act_sender := (SELECT user_id FROM users WHERE auth_id = auth.uid());
                    act_recipient := (SELECT user_id FROM course_version_faculty WHERE version_id = act_version_id);
                    msg := format(
                        'Your course "%s" needs a few revisions before it can be approved. Check the feedback, make the updates, and resubmit when ready!',
                        (SELECT c.crs_title FROM prospectus_course pc INNER JOIN internal.course c ON c.crs_id = pc.crs_id WHERE pc.pc_id = act_version_id)
                    );

                    INSERT INTO course_activity (sender_id, recipient_id, version_id, type, metadata, message)
                        VALUES (
                            act_sender,
                            act_recipient,
                            act_version_id,
                            'disapprove-course',
                            jsonb_build_object(
                                'visibility', jsonb_build_array('analytics', 'notification'),
                                'pc_id', act_version_id
                            ),
                        msg
                        );
                end if;
            ELSE
                RAISE EXCEPTION 'This Course is already approved and published.'
                    USING ERRCODE = 'P0057';
            end if;
        ELSE
            RAISE EXCEPTION 'This Course is not yet ready for review.'
                USING ERRCODE = 'P0058';
        end if;
    ELSE
        RAISE EXCEPTION 'This Course doesn''t exists.'
                USING ERRCODE = 'P0054';
    end if;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
REVOKE ALL ON PROCEDURE internal.disapprove_course( IN p_pc_id TEXT, IN p_feedback TEXT) FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE internal.disapprove_course( IN p_pc_id TEXT, IN p_feedback TEXT) TO authenticated;











































