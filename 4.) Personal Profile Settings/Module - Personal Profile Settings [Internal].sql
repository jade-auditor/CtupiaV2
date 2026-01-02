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

-- TASK 1._ My Notifications

CREATE OR REPLACE FUNCTION internal.my_notifications()
RETURNS TABLE(id text, avatar text, message text, "time" text, status boolean)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
BEGIN
    IF (
        (SELECT check_user_role(ARRAY['admin', 'student', 'dean', 'faculty'])) = TRUE AND
        internal.get_secret_key('my_notifications') IS NOT NULL
    ) THEN

        RETURN QUERY
        SELECT
            -- 1.) id
            encode(
                pgp_sym_encrypt(ca.activity_id::TEXT, internal.get_secret_key('my_notifications')),
                'base64'
            )::TEXT,

            -- 2.) avatar path
            av.name::TEXT,

            -- 3.) message
            ca.message,

            -- 4.) time (human-readable)
            CASE
                WHEN EXTRACT(EPOCH FROM (NOW() - ca.created_at)) < 60 THEN
                    'just now'
                WHEN EXTRACT(EPOCH FROM (NOW() - ca.created_at)) < 3600 THEN
                    FLOOR(EXTRACT(EPOCH FROM (NOW() - ca.created_at)) / 60)::INT || 'm ago'
                WHEN EXTRACT(EPOCH FROM (NOW() - ca.created_at)) < 86400 THEN
                    FLOOR(EXTRACT(EPOCH FROM (NOW() - ca.created_at)) / 3600)::INT || 'h ago'
                WHEN EXTRACT(EPOCH FROM (NOW() - ca.created_at)) < 604800 THEN
                    FLOOR(EXTRACT(EPOCH FROM (NOW() - ca.created_at)) / 86400)::INT || 'd ago'
                ELSE
                    TO_CHAR(ca.created_at, 'Mon DD, YYYY')  -- fallback to actual date
            END AS time,

            -- 5.) Highlight status
            CASE
                WHEN ca.is_read IS FALSE THEN TRUE
                ELSE FALSE
            END as status

        FROM course_activity ca
        LEFT JOIN internal.users u ON u.user_id = ca.recipient_id
        INNER JOIN storage.objects av ON av.id = u.profile_id
        WHERE u.auth_id = auth.uid()
        ORDER BY ca.created_at DESC;

        UPDATE course_activity SET is_read = TRUE WHERE recipient_id = (SELECT user_id FROM users WHERE auth_id = auth.uid());

    ELSE
        RETURN QUERY
        SELECT NULL::TEXT, NULL::TEXT, NULL::TEXT, NULL::TEXT, NULL::TEXT
        WHERE FALSE;
    END IF;
END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION internal.my_notifications() FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION internal.my_notifications() TO authenticated;



-- TASK 2._ Update Phone

CREATE OR REPLACE PROCEDURE internal.update_phone(IN p_new_phone character varying)
SET search_path = internal, auth
AS $$
DECLARE
BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['admin', 'student', 'dean', 'faculty'])) IS  FALSE THEN
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    end if;

    IF internal.e_164_format_check(p_new_phone) is FALSE THEN
        RAISE EXCEPTION 'Invalid phone number. Please follow correct format.'
            USING ERRCODE = 'P0018';
    end if;

    UPDATE users
    SET
        phone = COALESCE(p_new_phone, phone)
    WHERE auth_id = auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
REVOKE ALL ON PROCEDURE internal.update_phone(IN p_new_phone character varying) FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE internal.update_phone(IN p_new_phone character varying) TO authenticated;


-- TASK 2._ Update Bio

CREATE OR REPLACE PROCEDURE internal.update_bio(IN p_new_bio text)
SET search_path = internal, auth
AS $$
DECLARE
BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['admin', 'student', 'dean', 'faculty'])) IS  FALSE THEN
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    end if;

    UPDATE users
    SET
        bio = COALESCE(p_new_bio, phone)
    WHERE auth_id = auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
REVOKE ALL ON PROCEDURE internal.update_bio(IN p_new_bio text) FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE internal.update_bio(IN p_new_bio text) TO authenticated;



-- TASK 3._ Update Avatar

CREATE OR REPLACE PROCEDURE internal.update_avatar(IN p_profile_upload uuid)
SET search_path = internal, auth
AS $$
DECLARE
    last_profile_id UUID;
    rows_updated INT := 0;
    new_profile_id UUID;
BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['admin', 'student', 'dean', 'faculty'])) IS  FALSE THEN
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    end if;

    -- CHECK IF THE PROFILE UPLOADED
    SELECT id INTO new_profile_id
    FROM STORAGE.OBJECTS
    WHERE bucket_id = 'profile-photo'
    AND  name like CONCAT(p_profile_upload ,'%')
    and owner = auth.uid();

    IF new_profile_id IS NULL THEN
        RAISE EXCEPTION 'This uploaded profile doesn''t exists'
            USING ERRCODE = 'P0043';
    end if;

    -- CHECK FOR EXISTING PROFILE
    SELECT o.id INTO last_profile_id
    FROM users u
    INNER JOIN storage.objects o ON o.id = u.profile_id AND o.owner = u.auth_id
    WHERE u.auth_id = auth.uid();

    IF last_profile_id IS NULL THEN -- IF THERE AIN'T THEN REPLACE
        UPDATE users SET profile_id = new_profile_id WHERE auth_id = auth.uid();

    ELSE -- ELSE REMOVE LAST PROFILE

        -- reset to default
        DELETE FROM storage.objects
        WHERE owner = auth.uid()
          AND bucket_id = 'profile-photo'
          AND id <> new_profile_id;


        GET DIAGNOSTICS rows_updated = ROW_COUNT;

        IF rows_updated > 0 THEN
            UPDATE users SET profile_id = new_profile_id WHERE auth_id = auth.uid();
        end if;

    end if;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
REVOKE ALL ON PROCEDURE internal.update_avatar(IN p_profile_upload uuid) FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE internal.update_avatar(IN p_profile_upload uuid) TO authenticated;


-- TASK 4._ Update Sensitive Info

CREATE OR REPLACE PROCEDURE internal.update_sensitive_info(IN p_new_fname text, IN p_new_mname text, IN p_new_lname text, IN p_new_birth date)
SET search_path = internal, auth
AS $$
DECLARE
    f_user_id INT;
BEGIN
    -- confirm user role
    IF (SELECT check_user_role(ARRAY['admin', 'student', 'dean', 'faculty'])) IS  FALSE THEN
        RAISE EXCEPTION 'Something went wrong.'
            USING ERRCODE = 'P0010';
    end if;

    IF (select change_attempt from internal.users where auth_id = auth.uid()) IS TRUE THEN
        RAISE EXCEPTION 'You have already attempted to change your information. Please contact the administrator to submit another request.'
        USING ERRCODE = 'P0019';
    ELSE
        UPDATE users
        SET
            fname = COALESCE(p_new_fname, fname),
            mname = COALESCE(p_new_mname, mname),
            lname = COALESCE(p_new_lname, lname),
            birth_date = COALESCE(p_new_birth, birth_date),
            change_attempt = TRUE
        WHERE auth_id = auth.uid();

    end if;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
REVOKE ALL ON PROCEDURE internal.update_sensitive_info(IN p_new_fname text, IN p_new_mname text, IN p_new_lname text, IN p_new_birth date) FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE internal.update_sensitive_info(IN p_new_fname text, IN p_new_mname text, IN p_new_lname text, IN p_new_birth date) TO authenticated;




