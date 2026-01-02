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

-- 1. Create User's Account

-- 1.1 VIEW ALL ROLES

CREATE OR REPLACE FUNCTION internal.get_roles()
RETURNS TABLE(id TEXT, name TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['admin', 'dean'])) = FALSE THEN
        RETURN;
    end if;

    IF internal.get_secret_key('get_roles') IS NOT NULL THEN
        RETURN QUERY
            select
                encode(
                    pgp_sym_encrypt(dr.dar_id::TEXT, internal.get_secret_key('get_roles')),'base64')::TEXT,
                dr.dar_name::TEXT
            from role_privileges rp
            inner join internal.designation_and_role dr on dr.dar_id = rp.creatable_role_id
            where rp.creator_role_id = (select dar_id
                                          from users u where auth_id = auth.uid());
    ELSE
        -- Return a dummy empty row (or use RETURN QUERY with WHERE false)
        RETURN QUERY
        SELECT NULL::TEXT, NULL::TEXT
        WHERE FALSE;
    END IF;
END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION internal.get_roles() FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION internal.get_roles() TO authenticated;


-- 1.2 VIEW ALL COLLEGES AND OFFICES

CREATE OR REPLACE FUNCTION internal.get_college_office()
RETURNS TABLE(id TEXT, name TEXT)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = internal
AS $$
BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['admin', 'dean'])) = FALSE THEN
        RETURN;
    end if;

    IF internal.get_secret_key('get_college_office') IS NOT NULL THEN
        RETURN QUERY
            SELECT
                encode(pgp_sym_encrypt(cao_id::TEXT, internal.get_secret_key('get_college_office')), 'base64')::TEXT,
                cao_name::TEXT
            FROM internal.college_and_office;
    ELSE
        -- Return a dummy empty row (or use RETURN QUERY with WHERE false)
        RETURN QUERY
        SELECT NULL::TEXT, NULL::TEXT
        WHERE FALSE;
    END IF;
END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION internal.get_college_office() FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION internal.get_college_office() TO authenticated;


-- set clause is implemented starting here
-- 1.3 VIEW ALL FACULTY RANKS

CREATE OR REPLACE FUNCTION internal.get_faculty_ranks()
RETURNS TABLE(id TEXT, name TEXT, salary TEXT, rate TEXT, salary_grade TEXT)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = internal
AS $$
BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['admin', 'dean'])) = FALSE THEN
        RETURN;
    end if;

    IF internal.get_secret_key('get_faculty_ranks') IS NOT NULL THEN
        RETURN QUERY
            select
                encode(pgp_sym_encrypt(fr.rank_id::TEXT, internal.get_secret_key('get_faculty_ranks')),'base64')::TEXT,
                concat(f.faculty_title, ' ',
                                  case
                                      when fr.rank_level = 0 then ''
                                      else fr.rank_level::text
                                  end) as rank,
                fr.salary::text,
                fr.rate::text,
                case when sg.sg_num is null then 'Not Assigned' else sg.sg_num::text end
            FROM faculty_rank fr
                INNER JOIN internal.faculty f on f.faculty_id = fr.faculty_id
                LEFT JOIN internal.salary_grade sg on sg.sg_id = fr.sg_id
            order by rank;
    ELSE
        -- Return a dummy empty row (or use RETURN QUERY with WHERE false)
        RETURN QUERY
        SELECT NULL::TEXT, NULL::TEXT, NULL::TEXT, NULL::TEXT, NULL::TEXT
        WHERE FALSE;
    END IF;
END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION internal.get_faculty_ranks() FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION internal.get_faculty_ranks() TO authenticated;


-- 1.4 CREATE USERS

CREATE OR REPLACE PROCEDURE internal.create_user(
    IN p_lname VARCHAR(255),
    IN p_fname VARCHAR(255),
    IN p_birth_date DATE,
    IN p_email VARCHAR(255),
    IN p_auth_id UUID,
    IN p_dar_id TEXT,
    IN p_mname VARCHAR(255) DEFAULT NULL,
    -- options may vary starting here depending on the role
    IN p_cao_id TEXT DEFAULT NULL,
    IN p_rank_id TEXT DEFAULT NULL,
    IN p_degree_id TEXT DEFAULT NULL,
    IN p_undergrad_load INT DEFAULT NULL
)
SET search_path = internal, auth
AS $$
DECLARE
    dcrpt_dar_id INT := null;
    dcrpt_cao_id INT := null;
    dcrpt_rank_id INT := null;
    dcrpt_degree_id INT := null;

    rows_updated INT := NULL;
    act_sender INT;
    act_recipient INT;
    act_version_id INT;
    msg TEXT;
    f_user_id INT;
BEGIN
    -- confirm user role
    IF (SELECT internal.check_user_role(ARRAY['admin', 'dean'])) = FALSE THEN
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    end if;

    -- check fields
    IF p_lname IS NULL THEN
        RAISE EXCEPTION 'Field "Last name" is required.'
            USING ERRCODE = 'P0010';
    ELSIF p_fname IS NULL THEN
        RAISE EXCEPTION 'Field "First name" is required.'
            USING ERRCODE = 'P0010';
    ELSIF p_birth_date IS NULL THEN
        RAISE EXCEPTION 'Field "Birthdate" is required.'
            USING ERRCODE = 'P0010';
    ELSIF p_email IS NULL THEN
        RAISE EXCEPTION 'Field "Email" is required.'
            USING ERRCODE = 'P0010';
    ELSIF p_auth_id IS NULL THEN
        RAISE EXCEPTION 'Something went wrong. Please contact administration.'
            USING ERRCODE = 'P0010';
    ELSIF p_dar_id IS NULL THEN
        RAISE EXCEPTION 'Field "User role" is required.'
            USING ERRCODE = 'P0010';
    END IF;

    IF (SELECT internal.check_user_role(ARRAY['dean'])) = TRUE THEN

        dcrpt_cao_id := (SELECT cao_id FROM users where auth_id = auth.uid());

    else

        IF p_cao_id IS NOT NULL THEN
            dcrpt_cao_id := pgp_sym_decrypt(decode(p_cao_id,'base64'),get_secret_key('get_college_office'));
        END IF;

    end if;

    -- decrypt ids
    dcrpt_dar_id := pgp_sym_decrypt(decode(p_dar_id,'base64'),get_secret_key('get_roles'));

    IF p_rank_id IS NOT NULL THEN
        dcrpt_rank_id := pgp_sym_decrypt(decode(p_rank_id,'base64'),get_secret_key('get_faculty_ranks'));
    END IF;

    IF p_degree_id IS NOT NULL THEN
        dcrpt_degree_id := pgp_sym_decrypt(decode(p_degree_id,'base64'),get_secret_key('get_degrees'));
    END IF;

    -- check if this user has the privilege to create this type of user
    IF NOT EXISTS(SELECT 1
                FROM role_privileges rp
                inner join users u on rp.creator_role_id = u.dar_id
                where u.auth_id = auth.uid() AND rp.creatable_role_id = dcrpt_dar_id) then
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    end if;

    -- check existing email
    IF EXISTS (
        SELECT 1
        FROM auth.users
        WHERE email = p_email
        AND email_confirmed_at IS NOT NULL
    ) THEN
        RAISE EXCEPTION 'This email already existed. Please use another email.'
            USING ERRCODE = 'P0011';
    END IF;

    -- check existing user by auth_id
    IF EXISTS (
        SELECT 1
        FROM users
        WHERE auth_id = p_auth_id
    ) THEN
        RAISE EXCEPTION 'This user already existed.'
            USING ERRCODE = 'P0011';
    END IF;

    IF internal.role_check(dcrpt_dar_id) = 'admin' THEN

        INSERT INTO users (lname, mname, fname, birth_date, auth_id, dar_id)
        VALUES (p_lname, p_mname, p_fname, p_birth_date,p_auth_id,
                dcrpt_dar_id)
        RETURNING user_id INTO f_user_id;

    ELSIF internal.role_check(dcrpt_dar_id) = 'student' THEN

        IF dcrpt_cao_id IS NULL THEN
                RAISE EXCEPTION 'College or Office should be provided.'
                USING ERRCODE = 'P0012';
        end if;

        INSERT INTO users (lname, mname, fname, birth_date, auth_id, dar_id, cao_id)
            VALUES (p_lname, p_mname, p_fname, p_birth_date,
                    p_auth_id,dcrpt_dar_id, dcrpt_cao_id)
        RETURNING user_id INTO f_user_id;

    ELSIF internal.role_check(dcrpt_dar_id) = 'dean' THEN

        IF dcrpt_cao_id IS NULL THEN
                RAISE EXCEPTION 'College or Office should be provided.'
                USING ERRCODE = 'P0012';
        end if;

        IF EXISTS (SELECT 1
                   FROM users u2
                   INNER JOIN internal.designation_and_role dar on dar.dar_id = u2.dar_id
                   WHERE u2.cao_id = dcrpt_cao_id
                     AND u2.is_active IS TRUE
                     AND dar.dar_name = 'dean') THEN
            RAISE EXCEPTION 'Only one active dean account is permitted for this college or office.'
            USING ERRCODE = 'P0012';
        END IF;

        INSERT INTO users (lname, mname, fname, birth_date, auth_id, dar_id,
                           cao_id
        )
        VALUES (p_lname, p_mname, p_fname, p_birth_date,
                 p_auth_id,dcrpt_dar_id,
                dcrpt_cao_id)
        RETURNING user_id INTO f_user_id;

    ELSIF internal.role_check(dcrpt_dar_id) = 'faculty' THEN

        IF dcrpt_cao_id IS NULL THEN
            RAISE EXCEPTION 'College or Office should be provided.'
            USING ERRCODE = 'P0012';
        ELSIF dcrpt_rank_id IS NULL THEN
            RAISE EXCEPTION 'Faculty rank should be provided.'
            USING ERRCODE = 'P0013';
        ELSIF dcrpt_degree_id IS NULL THEN
            RAISE EXCEPTION 'Degree should be provided.'
            USING ERRCODE = 'P0013';
        ELSIF p_undergrad_load IS NULL THEN
            RAISE EXCEPTION 'Undergrad Load should be provided.'
            USING ERRCODE = 'P0013';
        end if;

        INSERT INTO users (
            lname, mname, fname, birth_date,
            auth_id, dar_id, cao_id, rank_id, degree_id,
            metadata
        )
        VALUES (
            p_lname, p_mname, p_fname, p_birth_date,
            p_auth_id, dcrpt_dar_id,
            dcrpt_cao_id, dcrpt_rank_id, dcrpt_degree_id,
            jsonb_build_object('undergrad_load',p_undergrad_load)
        )
        RETURNING user_id INTO f_user_id;
    end if;

    IF f_user_id IS NOT NULL THEN

        act_sender := (SELECT user_id FROM users WHERE auth_id = auth.uid());
        act_recipient := f_user_id;
        msg := format(
            'Welcome to Ctupia. Your account is now active — explore, connect, and get started.'
        );

        INSERT INTO course_activity (sender_id, recipient_id, version_id, type, metadata, message)
            VALUES (
                act_sender,
                act_recipient,
                act_version_id,
                'create-user',
                jsonb_build_object(
                    'visibility', jsonb_build_array('analytics', 'notification')
                ),
            msg
            );
    end if;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
REVOKE ALL ON PROCEDURE internal.create_user(
    IN p_lname VARCHAR(255),
    IN p_fname VARCHAR(255),
    IN p_birth_date DATE,
    IN p_email VARCHAR(255),
    IN p_auth_id UUID,
    IN p_dar_id TEXT,
    IN p_mname VARCHAR(255),
    -- options may vary starting here depending on the role
    IN p_cao_id TEXT,
    IN p_rank_id TEXT,
    IN p_degree_id TEXT,
    IN p_undergrad_load INT
) FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE internal.create_user(
    IN p_lname VARCHAR(255),
    IN p_fname VARCHAR(255),
    IN p_birth_date DATE,
    IN p_email VARCHAR(255),
    IN p_auth_id UUID,
    IN p_dar_id TEXT,
    IN p_mname VARCHAR(255),
    -- options may vary starting here depending on the role
    IN p_cao_id TEXT,
    IN p_rank_id TEXT,
    IN p_degree_id TEXT,
    IN p_undergrad_load INT
) TO authenticated;



-- 2. View User Accounts

CREATE OR REPLACE FUNCTION internal.get_users()
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
BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['admin', 'dean'])) = FALSE THEN
        RETURN;
    end if;

    IF internal.get_secret_key('get_users') IS NOT NULL THEN
        RETURN QUERY
            SELECT
                encode(pgp_sym_encrypt(u.user_id::TEXT, internal.get_secret_key('get_users')),'base64')::TEXT,
                obj.name::TEXT,
                u.lname::TEXT,
                u.fname::TEXT,
                CASE
                    WHEN u.mname IS NULL THEN ' '
                    ELSE u.mname::TEXT
                END,
                TO_CHAR(u.birth_date, 'MM/DD/YYYY'),
                auth.email::TEXT,
                COALESCE(u.phone, 'N/A')::TEXT,
                CASE
                    WHEN u.bio IS NULL THEN 'N/A'
                    ELSE u.bio::TEXT
                END,

                -- Join Degree
                CASE
                    WHEN u.degree_id IS NULL THEN 'N/A'
                    ELSE concat(
                                deg.deg_name, ', ',
                                deg.deg_abbr
                            )
                END,

                -- Join Faculty Rank
                CASE
                    WHEN u.rank_id IS NULL THEN 'N/A'
                    ELSE concat(f.faculty_title, ' ',
                           CASE
                                WHEN fr.rank_level = 0 THEN ''
                                ELSE fr.rank_level::TEXT
                           END
                         )
                END,

                -- Join College
                COALESCE(cao.cao_name, 'N/A')::TEXT,

                -- Admin related Data
                dar.dar_name::TEXT,

                -- date added
                TO_CHAR(u.date_added, 'MM/DD/YYYY'),

                -- Status
                CASE
                    WHEN auth.confirmed_at IS NULL THEN 'Pending'
                    ELSE concat('Confirmed at ', TO_CHAR(auth.confirmed_at, 'MM/DD/YYYY'))
                END,

                -- created by
                CASE
                    WHEN u.created_by IS NULL THEN ''
                    WHEN cb.fname in ('yang', 'yin') THEN ''
                    ELSE CONCAT(cb.lname, ', ', cb.fname, ' ',COALESCE(cb.mname, ''))
                END

            FROM users u
            LEFT JOIN degree deg ON u.degree_id = deg.degree_id
            LEFT JOIN faculty_rank fr ON u.rank_id = fr.rank_id
            LEFT JOIN faculty f ON fr.faculty_id = f.faculty_id
            LEFT JOIN college_and_office cao ON u.cao_id = cao.cao_id
            LEFT JOIN users cb ON u.created_by = cb.user_id
            LEFT JOIN storage.objects obj ON u.profile_id = obj.id
            INNER JOIN designation_and_role dar on dar.dar_id = u.dar_id
            INNER JOIN auth.users auth on u.auth_id = auth.id AND u.fname not in ('yin', 'yang') AND u.auth_id != auth.uid()
            INNER JOIN role_privileges rp on rp.creatable_role_id = u.dar_id
            inner JOIN users cb2 ON cb2.dar_id = rp.creator_role_id
            WHERE
                u.is_active IS TRUE
                AND cb2.auth_id = auth.uid()
                AND (
                    NOT check_user_role(ARRAY['dean']) -- if not a dean, show all
                    OR (
                        check_user_role(ARRAY['dean'])
                        AND u.cao_id = (SELECT cao_id FROM users WHERE auth_id = auth.uid())
                        AND dar.dar_name IN ('student', 'faculty')
                    )
                )
            ORDER BY
              CASE dar.dar_name
                WHEN 'admin' THEN 1
                WHEN 'dean' THEN 2
                WHEN 'faculty' THEN 3
                WHEN 'student' THEN 4
                ELSE 5
              END,
              u.lname ASC,
              u.fname ASC;
    ELSE
        -- Return a dummy empty row (or use RETURN QUERY with WHERE false)
        RETURN;
    END IF;
END;
$$ SECURITY DEFINER;
REVOKE ALL ON FUNCTION internal.get_users() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION internal.get_users() TO authenticated;



-- 3. Delete User Account

CREATE OR REPLACE PROCEDURE internal.delete_user(
    IN p_user_id TEXT
)
SET search_path = internal
AS $$
DECLARE
    dcrpt_user_id INT;
BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['admin'])) = FALSE THEN
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    end if;

    -- decrypt ids
    BEGIN
        dcrpt_user_id := pgp_sym_decrypt(decode(p_user_id,'base64'),get_secret_key('get_users'));
    EXCEPTION
        WHEN OTHERS THEN
        RAISE EXCEPTION 'Field "Student" is required.'
            USING ERRCODE = 'P0010';
    END;


    -- check if this user has the privilege to delete this type of user
    IF NOT EXISTS(SELECT 1
                FROM role_privileges rp
                inner join users u on rp.creator_role_id = u.dar_id
                INNER JOIN users u2 ON rp.creatable_role_id = u2.dar_id
                where u.auth_id = auth.uid() AND u2.user_id = dcrpt_user_id) then
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    end if;

    -- check USER IF EXIST
    IF EXISTS (
        SELECT 1
        FROM internal.users
        WHERE user_id = dcrpt_user_id
    ) THEN
        UPDATE internal.users
        SET is_active = FALSE
        WHERE user_id = dcrpt_user_id;

        UPDATE auth.users
        SET banned_until = '9999-12-31'
        WHERE email = (SELECT a.email FROM auth.users a INNER JOIN internal.users u ON u.auth_id = a.id WHERE u.user_id = dcrpt_user_id);

    ELSE
        RAISE EXCEPTION 'Something went wrong'
            USING ERRCODE = 'P0014';
    END IF;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
REVOKE ALL ON PROCEDURE internal.delete_user(IN p_user_id TEXT) FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE internal.delete_user(IN p_user_id TEXT) TO authenticated;



-- 4. GET USER'S INFO AFTER LOGGING IN

CREATE OR REPLACE FUNCTION internal.get_user_info(IN p_platform_id INT)
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
BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['admin', 'student', 'dean', 'faculty'])) = FALSE THEN
        RETURN;
    end if;

    -- Validate input first
    IF p_platform_id NOT IN (1, 2) THEN
        RAISE EXCEPTION 'Invalid platform ID: %, must be 1 or 2', p_platform_id
            USING ERRCODE = 'P0016';
    END IF;

    RETURN QUERY
    SELECT DISTINCT
        CASE
            WHEN obj2.bucket_id = 'profile-photo' THEN
                obj2.name::TEXT
            WHEN obj.bucket_id = 'profile-photo' THEN
                obj.name::TEXT
        END,
        dar.dar_name::TEXT,
        u.lname::TEXT,
        u.fname::TEXT,
        u.mname::TEXT,
        TO_CHAR(u.birth_date, 'MM/DD/YYYY') AS birth_date,
        auth.email::TEXT,
        COALESCE(u.phone, 'N/A')::TEXT AS phone,
        u.bio::TEXT,

        -- Join Degree
        CASE
            WHEN u.degree_id IS NULL THEN 'N/A'
            ELSE concat(
                        deg.deg_name, ', ',
                        deg.deg_abbr
                    )
        END as degree,

        -- Join Faculty Rank
        CASE
            WHEN u.rank_id IS NULL THEN 'N/A'
            ELSE concat(f.faculty_title, ' ',
                   CASE
                        WHEN fr.rank_level = 0 THEN ''
                        ELSE fr.rank_level::TEXT
                   END
                 )
        END as faculty_rank,

        -- Join College
        COALESCE(cao.cao_name, 'N/A')::TEXT AS college,

        -- NOTIFICATION
        (select coalesce(count(*),0) from course_activity where recipient_id = u.user_id and is_read is false)::text

    FROM users u
    LEFT JOIN degree deg ON u.degree_id = deg.degree_id
    LEFT JOIN faculty_rank fr ON u.rank_id = fr.rank_id
    LEFT JOIN faculty f ON fr.faculty_id = f.faculty_id
    LEFT JOIN college_and_office cao ON u.cao_id = cao.cao_id
    LEFT JOIN users cb ON u.created_by = cb.user_id
    LEFT JOIN storage.objects obj ON u.profile_id = obj.id
    LEFT JOIN storage.objects obj2 ON u.auth_id = obj2.owner
    INNER JOIN designation_and_role dar on dar.dar_id = u.dar_id
    INNER JOIN internal.role_based_access_control rbac on dar.dar_id = rbac.dar_id
    INNER JOIN internal.page p on p.page_id = rbac.page_id
    INNER JOIN auth.users auth on u.auth_id = auth.id
    WHERE u.auth_id = auth.uid()
      AND p.platform_id = p_platform_id AND u.is_active IS TRUE;
END;
$$ SECURITY DEFINER;
REVOKE ALL ON FUNCTION internal.get_user_info(IN p_platform_id INT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION internal.get_user_info(IN p_platform_id INT) TO authenticated;



-- 5.) UPDATE USER'S ACCOUNT

-- 5.1 GET ALL DEGREES

CREATE OR REPLACE FUNCTION internal.get_degrees()
RETURNS TABLE(id TEXT, name TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['admin', 'dean'])) IS  FALSE THEN
        RETURN;
    end if;

    IF internal.get_secret_key('get_degrees') IS NOT NULL THEN
        RETURN QUERY
            SELECT
                encode(
                    pgp_sym_encrypt(degree_id::TEXT, internal.get_secret_key('get_degrees')),'base64')::TEXT,
                deg_name::TEXT
            FROM internal.degree;
    ELSE
        -- Return a dummy empty row (or use RETURN QUERY with WHERE false)
        RETURN QUERY
        SELECT NULL::TEXT, NULL::TEXT
        WHERE FALSE;
    END IF;
END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION internal.get_degrees() FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION internal.get_degrees() TO authenticated;


-- 5.2 UPDATE USER

CREATE OR REPLACE PROCEDURE internal.update_user(
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
SET search_path = internal, auth
AS $$
DECLARE
    dcrpt_user_id INT := NULL;
    dcrpt_dar_id INT := NULL;
    dcrpt_rank_id INT := NULL;
    dcrpt_cao_id INT := NULL;
    dcrpt_degree_id INT := NULL;
    fetched_role TEXT :=  NULL;
    new_default_profile UUID := NULL;
    fields INT := 0;
BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['admin'])) = FALSE THEN
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    end if;

    -- check parameters there should be atleast 1 to update
    IF p_lname IS NOT NULL THEN
        fields =+ 1;
    ELSIF p_mname IS NOT NULL THEN
        fields =+ 1;
    ELSIF p_fname IS NOT NULL THEN
        fields =+ 1;
    ELSIF p_email IS NOT NULL THEN
        fields =+ 1;
    ELSIF p_birth IS NOT NULL THEN
        fields =+ 1;
    ELSIF p_degree_id IS NOT NULL THEN
        fields =+ 1;
    ELSIF p_college_office_id IS NOT NULL THEN
        fields =+ 1;
    ELSIF p_rank_id IS NOT NULL THEN
        fields =+ 1;
    ELSIF p_role_id IS NOT NULL THEN
        fields =+ 1;
    ELSIF p_account_status IS NOT NULL THEN
        fields =+ 1;
    ELSIF p_default_profile IS NOT NULL THEN
        fields =+ 1;
    ELSIF p_undergrad_load IS NOT NULL THEN
        fields =+ 1;
    END IF;

    IF fields <= 0 THEN
        RAISE EXCEPTION 'There should be atleast 1 field to update. Try again.'
                USING ERRCODE = 'P0017';
    end if;


    -- decrypt ids
    dcrpt_user_id := pgp_sym_decrypt(decode(p_user_id,'base64'), get_secret_key('get_users'));

    IF p_degree_id IS NOT NULL THEN 
        dcrpt_degree_id := pgp_sym_decrypt(decode(p_degree_id,'base64'), get_secret_key('get_degrees'));
    END IF;

    IF p_college_office_id IS NOT NULL THEN
        dcrpt_cao_id := pgp_sym_decrypt(decode(p_college_office_id,'base64'), get_secret_key('get_college_office'));
    END IF;

    IF p_rank_id IS NOT NULL THEN
        dcrpt_rank_id := pgp_sym_decrypt(decode(p_rank_id,'base64'),get_secret_key('get_faculty_ranks'));
    end if;

    IF p_role_id IS NOT NULL THEN
        dcrpt_dar_id := pgp_sym_decrypt(decode(p_role_id,'base64'), get_secret_key('get_roles'));
    end if;


    -- check update requirements based on user's role
    IF p_role_id IS NULL THEN
        -- then we should get the user's role
        fetched_role := user_role_identifier(dcrpt_user_id);
    ELSE
        -- let the desired role be the basis
        fetched_role := role_check(dcrpt_dar_id);
    end if;

    -- check if this user has the privilege to update this type of user
    IF NOT EXISTS(SELECT 1
                FROM role_privileges rp
                inner join users u on rp.creator_role_id = u.dar_id
                INNER JOIN users u2 ON rp.creatable_role_id = u2.dar_id
                where u.auth_id = auth.uid() AND u2.user_id = dcrpt_user_id) then
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    end if;

    -- checking field requirements
    IF fetched_role = 'dean' AND p_college_office_id IS NULL THEN
            RAISE EXCEPTION 'College or Office should be filled.'
                USING ERRCODE = 'P0012';
    ELSIF fetched_role = 'faculty' AND (p_rank_id IS NULL OR p_college_office_id IS NULL) THEN
            RAISE EXCEPTION 'Faculty Rank and College/Office should be filled.'
                USING ERRCODE = 'P0012';
    end if;

    -- check if user_id is valid
    IF NOT EXISTS(
        SELECT 1
        FROM internal.users
        WHERE user_id = dcrpt_user_id
    )THEN
        RAISE EXCEPTION 'Something went wrong'
            USING ERRCODE = 'P0014';
    end if;

    -- check existing email
    IF p_email IS NOT NULL THEN
        IF EXISTS (
            SELECT 1
            FROM auth.users
            WHERE email = p_email
            AND email_confirmed_at IS NOT NULL
        ) THEN
            RAISE EXCEPTION 'This email already existed. Please use another email.'
                USING ERRCODE = 'P0014';
        END IF;
    END IF;

    -- SET NEW DEFAULT PROFILE
    if p_default_profile is true then
        new_default_profile := get_random_profile_uuid();
    ELSE
        new_default_profile := NULL;
    end if;

    -- BEGIN UPDATE THE BASIC REQUIREMENTS
    UPDATE internal.users
    SET lname = coalesce(p_lname, lname),
        mname = coalesce(p_mname, mname),
        fname = coalesce(p_fname, fname),
        birth_date = coalesce(p_birth, birth_date),
        degree_id = coalesce(dcrpt_degree_id, degree_id),
--         is_active = coalesce(p_account_status, is_active),
        profile_id = coalesce(new_default_profile, profile_id)
    WHERE user_id = dcrpt_user_id;


    -- update based on role requirements]
    IF fetched_role = 'admin'THEN
        UPDATE internal.users
        SET dar_id = coalesce(dcrpt_dar_id, dar_id),
            cao_id = NULL,
            rank_id = NULL
        WHERE user_id = dcrpt_user_id;

    ELSIF fetched_role = 'dean'THEN
        UPDATE internal.users
        SET dar_id = coalesce(dcrpt_dar_id, dar_id),
            cao_id = coalesce(dcrpt_cao_id, cao_id),
            rank_id = NULL
        WHERE user_id = dcrpt_user_id;

    ELSIF fetched_role = 'faculty' THEN
        UPDATE internal.users
        SET dar_id = coalesce(dcrpt_dar_id, dar_id),
            cao_id = coalesce(dcrpt_cao_id, cao_id),
            rank_id = coalesce(dcrpt_rank_id, rank_id),
            metadata = jsonb_set(
                            metadata,
                            '{undergrad_load}',
                            to_jsonb(p_undergrad_load),
                            true
                        )
        WHERE user_id = dcrpt_user_id;

    ELSIF fetched_role = 'student' THEN
        UPDATE internal.users
        SET dar_id = coalesce(dcrpt_dar_id, dar_id),
            cao_id = coalesce(dcrpt_cao_id, cao_id),
            rank_id = NULL
        WHERE user_id = dcrpt_user_id;
    end if;

    -- update email on auth.users
    -- warning: user must need to request reset password if their email is changed through here.
    UPDATE auth.users
    SET email  = coalesce(p_email, email)
    WHERE id = (SELECT auth_id FROM internal.users WHERE user_id = dcrpt_user_id);

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
REVOKE ALL ON PROCEDURE internal.update_user(
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
GRANT EXECUTE ON PROCEDURE internal.update_user(
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

CREATE OR REPLACE PROCEDURE internal.login_trail()
SET search_path = internal
AS $$
BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['admin', 'dean', 'faculty', 'student'])) = FALSE THEN
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    end if;

    INSERT INTO course_activity (sender_id, type, metadata) -- yellow because we're omitting the version_id which doesnt have a default value but idk why really this column is nullable
                        VALUES (
                            (SELECT user_id FROM users WHERE auth_id = auth.uid()),
                            'login-trail',
                            jsonb_build_object(
                                'visibility', jsonb_build_array('analytics')
                            )
                        );

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
REVOKE ALL ON PROCEDURE internal.login_trail() FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE internal.login_trail() TO authenticated;
















