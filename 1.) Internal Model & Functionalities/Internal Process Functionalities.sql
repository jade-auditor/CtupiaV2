-- TASK 1._ Check Page Platform

CREATE OR REPLACE FUNCTION internal.check_page_platform(p_page_id integer, p_dar_id integer)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1
        FROM role_based_access_control rbac
        inner join page p on p.page_id = rbac.page_id
        inner join internal.platform p2 on p2.platform_id = p.platform_id
        inner join internal.designation_and_role dar on dar.dar_id = rbac.dar_id
        WHERE rbac.page_id = p_page_id AND rbac.dar_id =  p_dar_id AND p.platform_id = (SELECT platform_id from page where page_id = p_page_id)
    );
END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION internal.check_page_platform(p_page_id integer, p_dar_id integer) FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION internal.check_page_platform(p_page_id integer, p_dar_id integer) TO authenticated;



-- TASK 2._ Check Page Platform

CREATE OR REPLACE FUNCTION internal.faculty_check(p_faculty_id integer)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
BEGIN
    RETURN (SELECT faculty_title from faculty where faculty_id = p_faculty_id);
END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION internal.faculty_check(p_faculty_id integer) FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION internal.faculty_check(p_faculty_id integer) TO authenticated;



-- TASK 3._ Check Phone format

CREATE OR REPLACE FUNCTION internal.e_164_format_check(phone character varying)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
BEGIN
    IF phone ~ '^\+[1-9]\d{7,14}$' THEN
        RETURN TRUE;
    ELSE
        RETURN FALSE;
    END IF;
END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION internal.e_164_format_check(phone character varying) FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION internal.e_164_format_check(phone character varying) TO authenticated;



-- TASK 4._ Fetch Random Avatar UUID

CREATE OR REPLACE FUNCTION internal.get_random_profile_uuid()
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    profile UUID;
BEGIN
    SELECT id INTO profile
    FROM storage.objects
    WHERE bucket_id = 'profile-photo' AND owner IS NULL
    ORDER BY RANDOM()
    LIMIT 1;

    RETURN profile;
END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION internal.get_random_profile_uuid() FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION internal.get_random_profile_uuid() TO authenticated;



-- TASK 5._ Get user ID

CREATE OR REPLACE FUNCTION internal.get_user_id()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    v_user_id INTEGER;
BEGIN
    SELECT user_id INTO v_user_id
    FROM users
    WHERE auth_id = auth.uid();

    RETURN v_user_id;
END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION internal.get_user_id() FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION internal.get_user_id() TO authenticated;



-- TASK 6._ User role identifier

CREATE OR REPLACE FUNCTION internal.user_role_identifier(p_user_id integer)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
BEGIN
    RETURN (SELECT dar_name from internal.designation_and_role where dar_id = (SELECT dar_id FROM internal.users WHERE user_id = p_user_id));
END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION internal.user_role_identifier(p_user_id integer) FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION internal.user_role_identifier(p_user_id integer)TO authenticated;


-- TASK 7._ User role identifier

CREATE OR REPLACE FUNCTION internal.user_role_identifier(p_user_id integer)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
BEGIN
    RETURN (SELECT dar_name from internal.designation_and_role where dar_id = (SELECT dar_id FROM internal.users WHERE user_id = p_user_id));
END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION internal.user_role_identifier(p_user_id integer) FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION internal.user_role_identifier(p_user_id integer)TO authenticated;



-- TASK 8._ Fetch Default Random Course Wallpaper

CREATE OR REPLACE FUNCTION internal.get_random_course_wallpaper_uuid()
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    wallpaper_id UUID;
BEGIN
    SELECT id INTO wallpaper_id
    FROM storage.objects
    WHERE bucket_id = 'course-wallpaper' AND owner IS NULL
    ORDER BY random()
    LIMIT 1;

    RETURN wallpaper_id;
END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION internal.get_random_course_wallpaper_uuid() FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION internal.get_random_course_wallpaper_uuid() TO authenticated;



-- TASK 9._ Detect Duplicate General Programs

CREATE OR REPLACE FUNCTION internal.duplicate_general_program(p_prog_id integer)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    gen_count INT;
BEGIN
    SELECT COUNT(*) INTO gen_count
    FROM specialization
    WHERE prog_id = p_prog_id
      AND specialization IS NULL
      AND special_abbr IS NULL
      AND is_deleted = FALSE;

    -- Return TRUE only if more than one general program exists
    RETURN gen_count > 1;
END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION internal.duplicate_general_program(p_prog_id integer) FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION internal.duplicate_general_program(p_prog_id integer) TO authenticated;



-- TASK 10._ Identify Term Type

CREATE OR REPLACE FUNCTION internal.ident_term_type(p_sem_id integer, p_prospectus_id integer)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    a INT;
    b INT;
BEGIN
    a := (
        SELECT s.ttype_id
        FROM prospectus_semester ps
        INNER JOIN internal.semester s on ps.sem_id = s.sem_id
        WHERE prospectus_id = p_prospectus_id
        LIMIT 1
        );

    b := (
        SELECT ttype_id
        FROM semester
        WHERE sem_id = p_sem_id);

    IF (a IS NOT NULL) AND (a != b) THEN
        RETURN FALSE;
    ELSE
        RETURN TRUE;
    END IF;

END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION internal.ident_term_type(p_sem_id integer, p_prospectus_id integer) FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION internal.ident_term_type(p_sem_id integer, p_prospectus_id integer) TO authenticated;



-- TASK 11._ Identify Course Material

CREATE OR REPLACE FUNCTION internal.identify_video_material(p_material_id uuid)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    path text;
BEGIN
    -- Get object name for this material, scoped to current owner
    SELECT name
    INTO path
    FROM storage.objects
    WHERE id = p_material_id
      AND owner = auth.uid();

    -- If no object found, return FALSE
    IF path IS NULL THEN
        RETURN FALSE;
    END IF;

    -- Case-insensitive check for ".mp4" extension
    IF lower(path) LIKE '%.mp4' THEN
        RETURN TRUE;
    ELSE
        RETURN FALSE;
    END IF;


END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION internal.identify_video_material(p_material_id uuid) FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION internal.identify_video_material(p_material_id uuid) TO authenticated;



-- TASK 12._ Identify Question's Answer Type

CREATE OR REPLACE FUNCTION internal.answer_type_identifier(p_question_id integer)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    aa INT;
    ans_t TEXT;
BEGIN
    SELECT anst_id INTO aa FROM question WHERE question_id = p_question_id;
    SELECT a.answer_type INTO ans_t from answer_type a  where a.anst_id = aa;
    RETURN ans_t;
END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION internal.answer_type_identifier(p_question_id integer) FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION internal.answer_type_identifier(p_question_id integer) TO authenticated;





----------------------------------------- architecture related functions --------------------------------------------------

CREATE OR REPLACE PROCEDURE internal.error_log_entry(
    OUT out_code text,
    IN p_error_type text,
    IN p_error_msg text,
    IN p_function_name text,
    IN p_context jsonb DEFAULT '{}'::jsonb,
    IN p_severity text DEFAULT 'error'::text,
    IN p_client_ip text DEFAULT NULL::text
)
SET search_path TO 'internal', 'public', 'extensions'
AS $$
DECLARE
    prefix TEXT := '';
    letters TEXT := 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    i INT;
    random_suffix TEXT;
    current_auth UUID := auth.uid();
BEGIN
    -- Generate 3-letter prefix
    FOR i IN 1..3 LOOP
        prefix := prefix || substr(letters, floor(random() * 26 + 1)::int, 1);
    END LOOP;

    -- Generate 8-digit hex suffix
    random_suffix := upper(encode(gen_random_bytes(4), 'hex'));

    -- Combine prefix and suffix
    out_code := prefix || '-' || random_suffix;

    -- Insert the error log
    INSERT INTO internal.error_log (
        code,
        error_type,
        error_msg,
        function_name,
        context,
        severity,
        auth_id,
        client_ip
    )
    VALUES (
        out_code,
        p_error_type,
        p_error_msg,
        p_function_name,
        p_context,
        p_severity,
        current_auth,
        p_client_ip
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
REVOKE ALL ON PROCEDURE internal.error_log_entry(
    OUT out_code text,
    IN p_error_type text,
    IN p_error_msg text,
    IN p_function_name text,
    IN p_context jsonb,
    IN p_severity text,
    IN p_client_ip text
) FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE internal.error_log_entry(
    OUT out_code text,
    IN p_error_type text,
    IN p_error_msg text,
    IN p_function_name text,
    IN p_context jsonb,
    IN p_severity text,
    IN p_client_ip text
) TO authenticated;


CREATE OR REPLACE FUNCTION internal.log_error_wrapper(
    p_error_type text,
    p_error_msg text,
    p_function_name text,
    p_context jsonb DEFAULT '{}'::jsonb,
    p_severity text DEFAULT 'error'::text,
    p_client_ip text DEFAULT NULL::text
)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    out_code TEXT;
BEGIN
    CALL internal.error_log_entry(
        p_error_type     := p_error_type,
        p_error_msg      := p_error_msg,
        p_function_name  := p_function_name,
        p_context        := p_context,
        p_severity       := p_severity,
        p_client_ip      := p_client_ip,
        out_code         => out_code
    );

    RETURN out_code;
END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION internal.log_error_wrapper(
    p_error_type text,
    p_error_msg text,
    p_function_name text,
    p_context jsonb,
    p_severity text,
    p_client_ip text
) FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION internal.log_error_wrapper(
    p_error_type text,
    p_error_msg text,
    p_function_name text,
    p_context jsonb,
    p_severity text,
    p_client_ip text
) TO authenticated;


CREATE OR REPLACE FUNCTION internal.check_user_role(role_list character varying[])
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    user_role varchar := null; -- To store the current user's role
BEGIN
    -- Retrieve the current user's role from raw_user_meta_data
    SELECT dar_name INTO user_role
    from internal.designation_and_role
    where dar_id = (SELECT dar_id FROM internal.users WHERE auth_id = auth.uid());

    -- Compare the user's role to the provided role list
    IF user_role = ANY (role_list) THEN
        RETURN true; -- User's role matches one of the provided roles
    ELSE
        RETURN false; -- No match found
    END IF;
END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION internal.check_user_role(role_list character varying[]) FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION internal.check_user_role(role_list character varying[]) TO authenticated;


CREATE OR REPLACE FUNCTION internal.get_secret_key(p_func_name text)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    v_secret_key TEXT;
BEGIN
    -- confirm user role
    IF NOT check_user_role(ARRAY['admin','dean', 'student', 'faculty']) THEN
        RETURN NULL;  -- Explicit NULL if not allowed
    END IF;

    -- Get secret key for the function name
    SELECT sk.secret_key
    INTO v_secret_key
    FROM secret_key sk
    WHERE sk.func_name = p_func_name;

    RETURN v_secret_key;
END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION internal.get_secret_key(p_func_name text) FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION internal.get_secret_key(p_func_name text) TO authenticated;




