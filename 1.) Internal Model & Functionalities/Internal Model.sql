-- 0. CREATE A NEW SCHEMA internal
-- CREATE SCHEMA internal; -- hidden in case if you already created the schema beforehand. You may proceed to the next line.
ALTER SCHEMA internal OWNER TO postgres;
REVOKE ALL ON SCHEMA internal FROM public;

-- 1. COLLEGE AND OFFICE
CREATE TABLE internal.college_and_office
(
    cao_id   SERIAL PRIMARY KEY,
    cao_name VARCHAR(255) NOT NULL UNIQUE
);
ALTER TABLE internal.college_and_office
    ENABLE ROW LEVEL SECURITY;


-- 2. DESIGNATION AND ROLE
CREATE TABLE internal.designation_and_role
(
    dar_id   SERIAL PRIMARY KEY,
    dar_name VARCHAR(255) NOT NULL UNIQUE
);
ALTER TABLE internal.designation_and_role
    ENABLE ROW LEVEL SECURITY;


-- 3. PLATFORM
CREATE TABLE internal.platform
(
    platform_id   SERIAL PRIMARY KEY,
    platform_name VARCHAR(255) NOT NULL UNIQUE
);
ALTER TABLE internal.platform
    ENABLE ROW LEVEL SECURITY;


-- 4. PAGE
CREATE TABLE internal.page
(
    page_id     SERIAL          PRIMARY KEY,
    page_name   VARCHAR(255)    NOT NULL,

    -- Foreign Key(s)
    platform_id INT             NOT NULL    REFERENCES internal.platform (platform_id) ON DELETE CASCADE
);
ALTER TABLE internal.page
    ENABLE ROW LEVEL SECURITY;


-- 5. EDUCATIONAL QUALIFICATION

CREATE TABLE internal.educational_qualification (
    eq_id   SERIAL PRIMARY KEY,
    eq_name VARCHAR(50) NOT NULL,
    rate    NUMERIC(10,2) NOT NULL
);
ALTER TABLE internal.educational_qualification
    ENABLE ROW LEVEL SECURITY;


-- 6. DEGREE
CREATE TABLE internal.degree
(
    degree_id SERIAL PRIMARY KEY,
    deg_name  VARCHAR(255) NOT NULL UNIQUE,
    deg_abbr  VARCHAR(50)  NOT NULL,
    post_nom  VARCHAR(50),

    -- Foreign Key(s)
    eq_id     INT          NOT NULL    REFERENCES internal.educational_qualification (eq_id) ON DELETE RESTRICT
);
ALTER TABLE internal.degree
    ENABLE ROW LEVEL SECURITY;


-- 7.1.
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


-- 7.2. ROLE BASED ACCESS CONTROL
CREATE TABLE internal.role_based_access_control
(
    page_id     INT NOT NULL REFERENCES internal.page (page_id) ON DELETE CASCADE,
    dar_id      INT NOT NULL REFERENCES internal.designation_and_role (dar_id) ON DELETE CASCADE,
    is_main     BOOLEAN         NOT NULL    DEFAULT FALSE,

    -- Constraint(s)
    PRIMARY KEY (page_id, dar_id),
    CHECK (internal.check_page_platform(page_id,dar_id) = FALSE)

);
ALTER TABLE internal.role_based_access_control
    ENABLE ROW LEVEL SECURITY;


-- 8. ROLE PRIVILEGES
CREATE TABLE internal.role_privileges
(
    creator_role_id   INT NOT NULL REFERENCES internal.designation_and_role (dar_id) ON DELETE CASCADE,
    creatable_role_id INT NOT NULL REFERENCES internal.designation_and_role (dar_id) ON DELETE CASCADE,

    -- Constraint(s)
    PRIMARY KEY (creator_role_id, creatable_role_id)
);
ALTER TABLE internal.role_privileges
    ENABLE ROW LEVEL SECURITY;


-- 9. FACULTY
CREATE TABLE internal.faculty
(
    faculty_id    SERIAL PRIMARY KEY,
    faculty_title VARCHAR(255) NOT NULL UNIQUE
);
ALTER TABLE internal.faculty
    ENABLE ROW LEVEL SECURITY;


-- 10. SALARY GRADE
CREATE TABLE internal.salary_grade (
    sg_id SERIAL PRIMARY KEY,
    sg_num INT NOT NULL,
    salary_data JSONB NOT NULL
        DEFAULT jsonb_build_object(
            'step1', null,
            'step2', null,
            'step3', null,
            'step4', null,
            'step5', null,
            'step6', null,
            'step7', null,
            'step8', null
        ),
    CONSTRAINT salary_grade_valid CHECK (

        -- JSON must contain exactly 8 keys
        salary_data IS NOT NULL
        AND salary_data ? 'step1'
        AND salary_data ? 'step2'
        AND salary_data ? 'step3'
        AND salary_data ? 'step4'
        AND salary_data ? 'step5'
        AND salary_data ? 'step6'
        AND salary_data ? 'step7'
        AND salary_data ? 'step8'

        -- Each step must be number OR null
        AND jsonb_typeof(salary_data->'step1') IN ('number','null')
        AND jsonb_typeof(salary_data->'step2') IN ('number','null')
        AND jsonb_typeof(salary_data->'step3') IN ('number','null')
        AND jsonb_typeof(salary_data->'step4') IN ('number','null')
        AND jsonb_typeof(salary_data->'step5') IN ('number','null')
        AND jsonb_typeof(salary_data->'step6') IN ('number','null')
        AND jsonb_typeof(salary_data->'step7') IN ('number','null')
        AND jsonb_typeof(salary_data->'step8') IN ('number','null')
    )
);
ALTER TABLE internal.salary_grade
    ENABLE ROW LEVEL SECURITY;


-- 11.1.
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

-- 11.2. FACULTY RANK
CREATE TABLE internal.faculty_rank
(
    rank_id           SERIAL PRIMARY KEY,
    rank_level        INTEGER        NOT NULL CHECK (rank_level BETWEEN 0 AND 12),
    descr             TEXT,

    -- Foreign Key(s)
    faculty_id        INT            NOT NULL REFERENCES internal.faculty (faculty_id) ON DELETE CASCADE,
    sg_id             INT            REFERENCES internal.salary_grade (sg_id) ON DELETE RESTRICT,

    -- Constraint(s)
    UNIQUE (faculty_id, rank_level),
    FOREIGN KEY (faculty_id) REFERENCES internal.faculty (faculty_id) ON DELETE CASCADE,
    CONSTRAINT rank_range_check CHECK (
        (internal.faculty_check(faculty_id) = 'Instructor' AND rank_level BETWEEN 1 AND 7) OR
        (internal.faculty_check(faculty_id) = 'Assistant Prof.' AND rank_level BETWEEN 1 AND 7) OR
        (internal.faculty_check(faculty_id) = 'Associate Prof.' AND rank_level BETWEEN 1 AND 7) OR
        (internal.faculty_check(faculty_id) = 'Professor' AND rank_level BETWEEN 1 AND 12) OR
        (internal.faculty_check(faculty_id) = 'Univ. Professor' AND rank_level = 0)
        )
);
ALTER TABLE internal.faculty_rank
    ENABLE ROW LEVEL SECURITY;

-- 11.3.
CREATE OR REPLACE FUNCTION internal.check_faculty_rank_exclusivity()
    RETURNS TRIGGER AS
$$
BEGIN
    -- Case 1: Trying to insert rank_level = 0 but 1–4 exists
    IF NEW.rank_level = 0 THEN
        IF EXISTS (SELECT 1
                   FROM internal.faculty_rank
                   WHERE faculty_id = NEW.faculty_id
                     AND rank_level BETWEEN 1 AND 12) THEN
            RAISE EXCEPTION 'Cannot insert rank_level = 0 when other ranks 1-12 exist for this faculty';
        END IF;

        -- Case 2: Trying to insert rank_level 1–4 but 0 exists
    ELSIF NEW.rank_level BETWEEN 1 AND 12 THEN
        IF EXISTS (SELECT 1
                   FROM internal.faculty_rank
                   WHERE faculty_id = NEW.faculty_id
                     AND rank_level = 0) THEN
            RAISE EXCEPTION 'Cannot insert rank_level 1-12 when rank_level = 0 already exists for this faculty';
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_faculty_rank_exclusivity
    BEFORE INSERT OR UPDATE
    ON internal.faculty_rank
    FOR EACH ROW
EXECUTE FUNCTION internal.check_faculty_rank_exclusivity();



-- 12.1
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


-- 12.2
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

-- 12.3
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

-- 12.4
CREATE OR REPLACE FUNCTION internal.role_check(p_dar_id integer)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
BEGIN
    RETURN (SELECT dar_name from designation_and_role where dar_id = p_dar_id);
END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION internal.role_check(p_dar_id integer) FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION internal.role_check(p_dar_id integer)TO authenticated;

-- 12.5
CREATE OR REPLACE FUNCTION internal.existing_dean_check(p_cao_id integer, p_dean_id integer)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
BEGIN
    RETURN EXISTS (SELECT 1 FROM users WHERE dar_id = 2 AND cao_id = p_cao_id AND user_id != p_dean_id AND is_active IS TRUE);
END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION internal.existing_dean_check(p_cao_id integer, p_dean_id integer) FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION internal.existing_dean_check(p_cao_id integer, p_dean_id integer) TO authenticated;

-- 12.6
CREATE OR REPLACE FUNCTION internal.valid_creator(p_creator_user_id integer, p_target_role_id integer)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    f_role_id INT;
BEGIN
    SELECT dar_id INTO f_role_id
    FROM users
    WHERE user_id = p_creator_user_id;

    RETURN EXISTS (
    SELECT 1 FROM role_privileges
    WHERE creator_role_id= f_role_id AND creatable_role_id = p_target_role_id);
END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION internal.valid_creator(p_creator_user_id integer, p_target_role_id integer) FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION internal.valid_creator(p_creator_user_id integer, p_target_role_id integer) TO authenticated;


-- 12.7. USER
CREATE TABLE internal.users
(
    user_id        SERIAL PRIMARY KEY,
    lname          VARCHAR(100) NOT NULL,
    mname          VARCHAR(100),
    fname          VARCHAR(100) NOT NULL,
    birth_date     DATE         NOT NULL,
    date_added     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    is_active      BOOLEAN      NOT NULL DEFAULT TRUE,
    change_attempt BOOLEAN      NOT NULL DEFAULT FALSE,
    phone          VARCHAR(16)  UNIQUE CHECK (phone IS NULL OR internal.e_164_format_check(phone)),
    bio            TEXT,
    metadata       JSONB        DEFAULT '{}'::jsonb,

    -- Foreign Key(s)
    auth_id        uuid         NOT NULL REFERENCES auth.users (id) ON DELETE RESTRICT ,
    profile_id     uuid         NOT NULL DEFAULT internal.get_random_profile_uuid() REFERENCES storage.objects (id) ON DELETE SET DEFAULT,
    degree_id      INT REFERENCES internal.degree (degree_id) ON DELETE RESTRICT,
    dar_id         INT          NOT NULL REFERENCES internal.designation_and_role (dar_id) ON DELETE RESTRICT,
    cao_id         INT REFERENCES internal.college_and_office (cao_id) ON DELETE RESTRICT,                   -- COLLEGE AND OFFICES (OPTIONAL)
    rank_id        INT REFERENCES internal.faculty_rank (rank_id) ON DELETE RESTRICT,                        -- FACULTY RANK (OPTIONAL)
    created_by     INT DEFAULT internal.get_user_id() CHECK (created_by != user_id) REFERENCES internal.users (user_id) ON DELETE RESTRICT, -- CREATED BY (OPTIONAL FOR ADMIN)

    -- Constraint(s)
    CONSTRAINT user_requirement CHECK (
        (
            internal.role_check(dar_id) = 'admin'
            AND cao_id IS NULL
            AND rank_id IS NULL

        )
        OR (
            internal.role_check(dar_id) = 'dean'
            AND cao_id IS NOT NULL
            AND rank_id IS NULL
            AND created_by IS NOT NULL
            AND ((is_active IS FALSE) OR (is_active IS TRUE AND internal.existing_dean_check(cao_id, user_id) IS FALSE))
        )
        OR (
            internal.role_check(dar_id) = 'faculty'
            AND cao_id IS NOT NULL
            AND rank_id IS NOT NULL
            AND created_by IS NOT NULL
        )
        OR (
            internal.role_check(dar_id) = 'student'
            AND rank_id IS NULL
            AND created_by IS NOT NULL
        )
    ),
    CONSTRAINT creator_privilege_check CHECK (
        created_by IS NULL OR
        created_by IS NOT NULL AND internal.valid_creator(created_by, dar_id))
);
ALTER TABLE internal.users
    ENABLE ROW LEVEL SECURITY;


-- 13. PROGRAM
CREATE TABLE internal.program
(
    prog_id   SERIAL PRIMARY KEY,
    prog_name VARCHAR(255) NOT NULL UNIQUE,
    prog_abbr VARCHAR(50)  NOT NULL,
    status    BOOLEAN      NOT NULL DEFAULT TRUE
);
ALTER TABLE internal.program
    ENABLE ROW LEVEL SECURITY;


-- 14. CERTIFICATION
CREATE TABLE internal.certification
(
    certification_id SERIAL PRIMARY KEY,
    certification    VARCHAR(255) NOT NULL UNIQUE
);
ALTER TABLE internal.certification
    ENABLE ROW LEVEL SECURITY;



-- 15.1
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

-- 15.2
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

-- 15.3
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


-- 15.4. SPECIALIZATION
CREATE TABLE internal.specialization
(
    special_id       SERIAL PRIMARY KEY,
    specialization   VARCHAR(255),
    special_abbr     VARCHAR(50),
    date_created     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    about            TEXT,
    entry_reqs       TEXT[] NOT NULL DEFAULT '{}',
    status           BOOLEAN      NOT NULL DEFAULT TRUE,
    is_deleted       BOOLEAN      NOT NULL DEFAULT FALSE,

    -- Foreign Key(s)
    prog_id          INT          NOT NULL REFERENCES internal.program (prog_id) ON DELETE CASCADE,
    created_by       INT          NOT NULL DEFAULT internal.get_user_id() CHECK (internal.user_role_identifier(created_by) = 'admin') REFERENCES internal.users (user_id) ON DELETE RESTRICT,
    cao_id           INT          NOT NULL REFERENCES internal.college_and_office (cao_id) ON DELETE CASCADE,
    wallpaper_id UUID NOT NULL DEFAULT internal.get_random_course_wallpaper_uuid() REFERENCES storage.objects (id) ON DELETE SET DEFAULT,

    -- Constraint(s)
    CONSTRAINT specialization_value_check CHECK ( (specialization IS NULL AND special_abbr IS NULL) OR
                                                  (specialization IS NOT NULL AND special_abbr IS NOT NULL)),
    CONSTRAINT gen_program_check CHECK (internal.duplicate_general_program(prog_id) = FALSE)
);
ALTER TABLE internal.specialization
    ENABLE ROW LEVEL SECURITY;


-- 16. PROG_SPEC_CERTIFICATION
CREATE TABLE internal.PROG_SPEC_CERTIFICATION
(
    special_id          INT NOT NULL REFERENCES internal.specialization (special_id) ON DELETE CASCADE,
    certification_id    INT NOT NULL REFERENCES internal.certification (certification_id) ON DELETE RESTRICT,
    PRIMARY KEY (special_id, certification_id)
);
ALTER TABLE internal.PROG_SPEC_CERTIFICATION
    ENABLE ROW LEVEL SECURITY;


-- 17.1 PROSPECTUS
CREATE TABLE internal.prospectus
(
    prospectus_id    SERIAL PRIMARY KEY,
    prospectus_code  TEXT UNIQUE NOT NULL,
    date_created     TIMESTAMP NOT NULL DEFAULT NOW(),
    is_deleted       BOOLEAN      NOT NULL DEFAULT FALSE,
    year             INT NOT NULL,

    -- Foreign Key(s)
    created_by       INT       NOT NULL DEFAULT internal.get_user_id() CHECK (internal.user_role_identifier(created_by) = 'admin') REFERENCES internal.users (user_id) ON DELETE RESTRICT,
    special_id       INT       NOT NULL REFERENCES internal.specialization (special_id) ON DELETE RESTRICT
);
ALTER TABLE internal.prospectus
    ENABLE ROW LEVEL SECURITY;

-- 17.2
CREATE OR REPLACE FUNCTION internal.generate_prospectus_code()
RETURNS TRIGGER
SET search_path = internal, extensions
AS $$
DECLARE
    prog_name TEXT;
BEGIN
    prog_name := (SELECT CONCAT(p.prog_abbr, CASE WHEN s.special_abbr is NOT NULL THEN CONCAT('-',s.special_abbr) ELSE '' END)
                  FROM internal.specialization s
                      INNER JOIN internal.program p on s.prog_id = p.prog_id
                  WHERE special_id = NEW.special_id);
    NEW.prospectus_code :=
        prog_name ||
        TO_CHAR(NOW(), 'YYYY') ||
        substr(md5(random()::text), 1, 6);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_generate_prospectus_code
BEFORE INSERT ON INTERNAL.prospectus
FOR EACH ROW
EXECUTE FUNCTION internal.generate_prospectus_code();





-- 18. COURSE
CREATE TABLE internal.COURSE
(
    CRS_ID           SERIAL PRIMARY KEY,
    CRS_TITLE        VARCHAR(255)  NOT NULL UNIQUE,
    UNITS            NUMERIC(4, 2) NOT NULL,
    DATE_CREATED     TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    STATUS           BOOLEAN   NOT NULL DEFAULT TRUE,

    -- Foreign Key(s)
    CREATED_BY       INTEGER       NOT NULL DEFAULT internal.get_user_id() CHECK (internal.user_role_identifier(created_by) = 'admin') REFERENCES internal.users (user_id) ON DELETE RESTRICT
);
ALTER TABLE internal.COURSE
    ENABLE ROW LEVEL SECURITY;


-- 19. COURSE_CERTIFICATION
CREATE TABLE internal.COURSE_CERTIFICATION
(
    CRS_ID           INTEGER NOT NULL REFERENCES internal.COURSE (CRS_ID) ON DELETE CASCADE,
    CERTIFICATION_ID INTEGER NOT NULL REFERENCES internal.CERTIFICATION (CERTIFICATION_ID) ON DELETE RESTRICT,

    PRIMARY KEY (CRS_ID, CERTIFICATION_ID)
);
ALTER TABLE internal.COURSE_CERTIFICATION
    ENABLE ROW LEVEL SECURITY;



-- 20. CLASSIFICATION
CREATE TABLE internal.CLASSIFICATION
(
    CLASSIFICATION_ID SERIAL PRIMARY KEY,
    CLASSIFICATION    VARCHAR(100) NOT NULL UNIQUE
);
ALTER TABLE internal.CLASSIFICATION
    ENABLE ROW LEVEL SECURITY;


-- 21. YEAR
CREATE TABLE internal.year (
        year_id SERIAL PRIMARY KEY,
        year INTEGER NOT NULL UNIQUE
    );
ALTER TABLE internal.year
    ENABLE ROW LEVEL SECURITY;


-- 22. TERM TYPE
CREATE TABLE internal.term_type
(
    ttype_id  SERIAL PRIMARY KEY,
    type_name VARCHAR(50) NOT NULL UNIQUE -- e.g., 'Semester', 'Trimester'
);
ALTER TABLE internal.term_type
    ENABLE ROW LEVEL SECURITY;


-- 23. SEMESTER
CREATE TABLE internal.semester
(
    sem_id      SERIAL PRIMARY KEY,
    sem_num     INT                   NOT NULL,        -- e.g., 1, 2, 3
    sem_name    VARCHAR(50)           NOT NULL unique, -- e.g., '1st Semester'
    is_optional BOOLEAN DEFAULT FALSE NOT NULL,        -- ✅ True for Summer, etc.

    -- Foreign Key(s)
    ttype_id    INT                   NOT NULL REFERENCES internal.term_type (ttype_id) ON DELETE CASCADE,

    -- Constraint(s)
    CONSTRAINT composite_unique_semester UNIQUE (sem_num, ttype_id)     -- ensures clean ordering per system
);
ALTER TABLE internal.SEMESTER
    ENABLE ROW LEVEL SECURITY;


-- 24.1
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

-- 24.2. PROSPECTUS SEMESTER
CREATE TABLE internal.PROSPECTUS_SEMESTER
(
    PROSEM_ID     SERIAL PRIMARY KEY,
    DURATION      DATERANGE NOT NULL,
    YEAR_ID          INTEGER NOT NULL REFERENCES internal.YEAR (year_id) ON DELETE RESTRICT,

    -- Foreign Key(s)
    SEM_ID        INTEGER   NOT NULL REFERENCES internal.SEMESTER (SEM_ID) ON DELETE RESTRICT,
    PROSPECTUS_ID INTEGER   NOT NULL REFERENCES internal.PROSPECTUS (PROSPECTUS_ID) ON DELETE RESTRICT,

    -- Constraint(s)
    CONSTRAINT composite_unique_prospectus_semester UNIQUE (SEM_ID, PROSPECTUS_ID, YEAR_ID),
    CONSTRAINT term_type_rules CHECK ( internal.ident_term_type(SEM_ID,SEM_ID) IS TRUE)
);
ALTER TABLE internal.PROSPECTUS_SEMESTER
    ENABLE ROW LEVEL SECURITY;

ALTER TABLE internal.prospectus_semester
ADD CONSTRAINT no_overlapping_semesters
EXCLUDE USING gist (
    prospectus_id WITH =,
    duration WITH &&
);




-- 25. CLASSIFICATION UNIT
CREATE TABLE internal.CLASSIFICATION_UNIT
(
    CU_ID             SERIAL PRIMARY KEY,
    REQUIRED_UNITS    NUMERIC(4, 2) NOT NULL,

    -- Foreign Key(s)
    PROSPECTUS_ID     INTEGER       NOT NULL REFERENCES internal.PROSPECTUS (PROSPECTUS_ID) ON DELETE RESTRICT,
    CLASSIFICATION_ID INTEGER       NOT NULL REFERENCES internal.CLASSIFICATION (CLASSIFICATION_ID) ON DELETE RESTRICT,

    -- Constraint(s)
    UNIQUE (PROSPECTUS_ID, CLASSIFICATION_ID)
);
ALTER TABLE internal.CLASSIFICATION_UNIT
    ENABLE ROW LEVEL SECURITY;


-- 26. PROSPECTUS COURSE
CREATE TABLE internal.PROSPECTUS_COURSE
(
    PC_ID         SERIAL PRIMARY KEY,
    crs_code      VARCHAR(50) NOT NULL UNIQUE,

    -- Foreign Key(s)
    PROSEM_ID     INTEGER REFERENCES internal.PROSPECTUS_SEMESTER (PROSEM_ID),
    PROSPECTUS_ID INTEGER NOT NULL REFERENCES internal.PROSPECTUS (PROSPECTUS_ID) ON DELETE RESTRICT,
    CRS_ID        INTEGER NOT NULL REFERENCES internal.COURSE (CRS_ID) ON DELETE RESTRICT,
    CU_ID         INTEGER NOT NULL REFERENCES internal.CLASSIFICATION_UNIT (CU_ID) ON DELETE RESTRICT,

    -- Constraint(s)
    CONSTRAINT composite_unique_prospectus_course UNIQUE (PROSPECTUS_ID, CRS_ID, crs_code)
);
ALTER TABLE internal.PROSPECTUS_COURSE
    ENABLE ROW LEVEL SECURITY;


--27. LEARNING LEVEL
CREATE TABLE internal.learning_level
(
    ll_id SERIAL PRIMARY KEY,
    level VARCHAR(100) NOT NULL UNIQUE
);
ALTER TABLE internal.learning_level
    ENABLE ROW LEVEL SECURITY;



-- 28. COURSE VERSION
CREATE TABLE internal.course_version
(
    version_id   INTEGER     NOT NULL REFERENCES internal.PROSPECTUS_COURSE (PC_ID) ON DELETE RESTRICT,
    version_date timestamp   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    about        TEXT,
--     likes        INTEGER     NOT NULL DEFAULT 0,
    status       BOOLEAN     NOT NULL DEFAULT TRUE,
--     fee          NUMERIC(10, 2),
    is_ready     BOOLEAN NOT NULL DEFAULT FALSE,

    -- Foreign Key(s)
    syllabus_id  UUID REFERENCES storage.objects (id) ON DELETE RESTRICT,
    wallpaper_id UUID        NOT NULL DEFAULT internal.get_random_course_wallpaper_uuid() REFERENCES storage.objects (id) ON DELETE SET DEFAULT,
    created_by   INTEGER     NOT NULL DEFAULT internal.get_user_id()
        CHECK (
            (internal.user_role_identifier(created_by) = 'dean') or
            (internal.user_role_identifier(created_by) = 'admin'))   REFERENCES internal.users (user_id) ON DELETE RESTRICT,
    apvd_rvwd_by INTEGER
        CHECK (
            (internal.user_role_identifier(apvd_rvwd_by) is  null) or
            (internal.user_role_identifier(apvd_rvwd_by) = 'dean') or
            (internal.user_role_identifier(apvd_rvwd_by) = 'admin')) REFERENCES internal.users (user_id) ON DELETE RESTRICT,
    ll_id       INT REFERENCES internal.learning_level (ll_id) ON DELETE RESTRICT,
    feedback    TEXT,


    -- Constraint(s)
    CONSTRAINT creator_approval_check check ( created_by =  apvd_rvwd_by),
    PRIMARY KEY (version_id)
);
ALTER TABLE internal.course_version
    ENABLE ROW LEVEL SECURITY;


-- 29. DAY
CREATE TABLE internal.day (
    day_id SERIAL PRIMARY KEY,
    day_name VARCHAR(20) NOT NULL UNIQUE,
    day_abbr VARCHAR(2) NOT NULL UNIQUE
);
ALTER TABLE internal.day
    ENABLE ROW LEVEL SECURITY;


-- 30. COURSE_SCHEDULE
CREATE TYPE internal.timerange AS RANGE (
    subtype = time
);
CREATE TABLE internal.course_schedule (
    day_id          INT         NOT NULL REFERENCES internal.day (day_id) ON DELETE RESTRICT,
    version_id      INT         NOT NULL REFERENCES internal.course_version (version_id) ON DELETE CASCADE,
    time            internal.timerange   NOT NULL,

    PRIMARY KEY (day_id, version_id)
);
ALTER TABLE internal.course_schedule
    ENABLE ROW LEVEL SECURITY;


-- 3. COURSE VERSION FACULTY
CREATE TABLE internal.course_version_faculty
(
    version_id INTEGER   NOT NULL REFERENCES internal.course_version (version_id) ON DELETE CASCADE,
    user_id    INTEGER   NOT NULL CHECK ( internal.user_role_identifier(user_id) = 'faculty' ) REFERENCES internal.users (user_id) ON DELETE RESTRICT,
    asgnd_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    asgnd_by   INTEGER   NOT NULL DEFAULT internal.get_user_id()
        CHECK ( (internal.user_role_identifier(asgnd_by) = 'dean') or
                (internal.user_role_identifier(asgnd_by) = 'admin') ) REFERENCES internal.users (user_id) ON DELETE RESTRICT,

    CONSTRAINT course_version_faculty_pkey PRIMARY KEY (version_id, user_id)
);
ALTER TABLE internal.course_version_faculty
    ENABLE ROW LEVEL SECURITY;



-- 32. MY COURSES
CREATE TABLE internal.my_courses
(
    enrollee_id             SERIAL PRIMARY KEY,
    user_id                 INTEGER   NOT NULL CHECK (internal.user_role_identifier(user_id) = 'student') REFERENCES internal.users (user_id)                  ON DELETE CASCADE,
    version_id              INTEGER   NOT NULL REFERENCES internal.course_version (version_id)      ON DELETE RESTRICT,
    enrld_date              TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    is_liked                BOOLEAN   NOT NULL DEFAULT FALSE,
    rating                  INTEGER   CHECK (rating BETWEEN 1 AND 5),
    review                  TEXT,
    review_timestamp        TIMESTAMP,
    enrollment_status       BOOLEAN NOT NULL DEFAULT TRUE, -- [TRUE] ENROLLED [FALSE] DROPPED
    compre_tentative_date   TIMESTAMPTZ,
    confirmed_at            TIMESTAMPTZ,

    -- Foreign Key(s)
    cor                     UUID REFERENCES storage.objects (id)                                ON DELETE RESTRICT,
    proof_of_credit         UUID REFERENCES storage.objects (id)                                ON DELETE RESTRICT,
    official_list           UUID REFERENCES storage.objects (id)                                ON DELETE RESTRICT,
    enrld_by                INTEGER   NOT NULL DEFAULT internal.get_user_id() REFERENCES internal.users (user_id) ON DELETE RESTRICT,

    -- Constraint(s)
    CONSTRAINT unique_enrollee UNIQUE (user_id, version_id),
    CONSTRAINT enroll_requirement CHECK (
    (
        ((internal.user_role_identifier(enrld_by) = 'dean') or (internal.user_role_identifier(enrld_by) = 'admin'))
        AND (
            (CASE WHEN cor IS NOT NULL THEN 1 ELSE 0 END) +
            (CASE WHEN proof_of_credit IS NOT NULL THEN 1 ELSE 0 END) +
            (CASE WHEN official_list IS NOT NULL THEN 1 ELSE 0 END)
        ) = 1
    )
    OR
    (
        internal.user_role_identifier(enrld_by) = 'faculty'
        AND proof_of_credit IS NULL
        AND cor IS NOT NULL
    )
                                        ),
    CONSTRAINT review_rating_consistency CHECK (
    (review IS NULL AND review_timestamp IS NULL)
    OR (review IS NOT NULL AND rating BETWEEN 1 AND 5 AND review_timestamp IS NOT NULL)
    OR (review IS NULL AND rating BETWEEN 1 AND 5 AND review_timestamp IS NOT NULL)
)

);
ALTER TABLE internal.my_courses
    ENABLE ROW LEVEL SECURITY;


-- 32. HOW MANY PEOPLE LIKED OR DISLIKED THEIR REVIEW
CREATE TYPE internal.review_reaction AS ENUM ('like', 'dislike');

CREATE TABLE internal.review_likes (
    enrollee_id   INTEGER NOT NULL REFERENCES internal.my_courses(enrollee_id) ON DELETE CASCADE,
    user_liker_id INTEGER NOT NULL CHECK (internal.user_role_identifier(user_liker_id) = 'student') REFERENCES internal.users (user_id),
    reaction      internal.review_reaction NOT NULL,
    primary key (enrollee_id, user_liker_id)
);


-- 34. course activity
CREATE TABLE internal.course_activity (
    activity_id BIGSERIAL PRIMARY KEY,

    sender_id INT REFERENCES internal.users(user_id) ON DELETE SET NULL,   -- who triggered it
    recipient_id INT REFERENCES internal.users(user_id) ON DELETE CASCADE, -- who will receive it

    version_id INT REFERENCES internal.course_version(version_id) ON DELETE CASCADE,  -- context (course)
    type TEXT NOT NULL,                 -- e.g. 'assignment_submitted', 'grade_released', 'video_progress'
    message TEXT,              -- readable message for the UI
    -- link TEXT,                          -- optional (where it redirects in your app)
    metadata JSONB DEFAULT '{}'::jsonb CHECK ((metadata IS NULL) or (metadata IS NOT NULL AND metadata ? 'visibility')), -- extra info (score, title, etc.)

    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP NOT NULL DEFAULT now(),
    CHECK (
        message IS NULL OR (
        message IS NOT NULL
        AND (
          metadata ? 'visibility'
          AND metadata->'visibility' @> '["notification"]'::jsonb
        )
      )
    )
);


-- 35. LESSON
CREATE TABLE internal.LESSON
(
    lesson_id       SERIAL PRIMARY KEY,
    lesson_num      INT NOT NULL,
    lesson_name     TEXT NOT NULL,
    lesson_descr    TEXT,
    version_id      INTEGER NOT NULL REFERENCES internal.course_version (version_id) ON DELETE CASCADE,

    CONSTRAINT unique_lesson UNIQUE (version_id, lesson_name),
    CONSTRAINT unique_lesson_num UNIQUE (version_id, lesson_num)

);
ALTER TABLE internal.LESSON
    ENABLE ROW LEVEL SECURITY;


-- 36.1
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

-- 36.2 COURSE MATERIAL
CREATE TABLE internal.course_material
(
    material_id     SERIAL PRIMARY KEY,
    link            TEXT,
    material_name   TEXT NOT NULL,
    video_duration  INTERVAL,
    created_at      TIMESTAMP NOT NULL DEFAULT now(),

    -- Foreign Key(s)
    material        UUID    REFERENCES storage.objects (id) ON DELETE RESTRICT,
--     origin_id       INTEGER REFERENCES users (user_id) ON DELETE RESTRICT,
    lesson_id       INTEGER NOT NULL REFERENCES internal.lesson (lesson_id) ON DELETE CASCADE,
    user_id         INTEGER NOT NULL DEFAULT internal.get_user_id() CHECK ( internal.user_role_identifier(user_id) = 'faculty' ) REFERENCES internal.users (user_id) ON DELETE RESTRICT,

    -- Constraint(s)
    CONSTRAINT material_type_check CHECK (
        (link IS NOT NULL AND material IS NULL) OR
        (link IS NULL AND material IS NOT NULL)
        ),
    CONSTRAINT course_material_name_lesson_uniq
    UNIQUE (material_name, lesson_id),
    CONSTRAINT check_material CHECK ( (internal.identify_video_material(material) IS TRUE AND video_duration IS NOT NULL) OR
                                      (internal.identify_video_material(material) IS FALSE AND video_duration IS NULL))
);
ALTER TABLE internal.course_material
    ENABLE ROW LEVEL SECURITY;


-- 37. STUDENT CM PROGRESS
CREATE TABLE internal.student_cm_progress
(
    material_id         INTEGER NOT NULL REFERENCES internal.course_material (material_id) ON DELETE CASCADE,
    user_id             INTEGER NOT NULL DEFAULT internal.get_user_id() REFERENCES internal.users (user_id) ON DELETE CASCADE,
    start_date          TIMESTAMP NOT NULL DEFAULT NOW(),
    finished_date       TIMESTAMP,
    last_record_time    INTERVAL NOT NULL,
    status              BOOLEAN NOT NULL DEFAULT FALSE, -- TRUE CLAIMED / FALSE CLAIMABLE


    -- Constraint(s)
    PRIMARY KEY (material_id, user_id)
);
ALTER TABLE internal.student_cm_progress
    ENABLE ROW LEVEL SECURITY;

-- 37.2
CREATE OR REPLACE FUNCTION internal.set_finished_date_if_complete()
RETURNS TRIGGER
SET search_path = internal
AS $$
DECLARE
    vid_duration INTERVAL;
    act_version_id INT;
    act_sender INT;
    act_recipient INT;
    msg TEXT;
BEGIN
    -- get the duration from course_material
    SELECT video_duration
    INTO vid_duration
    FROM course_material
    WHERE material_id = NEW.material_id;

    -- check if progress exceeded or matched video duration
    IF NEW.last_record_time >= vid_duration THEN
        NEW.finished_date := COALESCE(NEW.finished_date, NOW());


        act_version_id := (SELECT l2.version_id FROM course_material cm INNER JOIN internal.lesson l2 on l2.lesson_id = cm.lesson_id WHERE cm.material_id = NEW.material_id);
        act_sender := (SELECT user_id FROM users WHERE auth_id = auth.uid());
        act_recipient := (SELECT user_id FROM course_version_faculty WHERE version_id = act_version_id );
        msg := format(
            'Great news! %s just finished watching %s from your course %s.',
            (SELECT CONCAT(lname, ', ', fname, ' ', COALESCE(mname, '')) FROM users WHERE auth_id = auth.uid()),
            (SELECT material_name FROM course_material WHERE material_id = NEW.material_id),
            (SELECT c.crs_title FROM prospectus_course pc INNER JOIN internal.course c ON c.crs_id = pc.crs_id WHERE pc.pc_id = act_version_id)
        );

        INSERT INTO course_activity (sender_id, recipient_id,  version_id, type, metadata, message)
                            VALUES (
                                act_sender,
                                act_recipient,
                                act_version_id,
                                'video-watched',
                                jsonb_build_object(
                                    'visibility', jsonb_build_array('analytics','notification'),
                                    'material_id', NEW.material_id,
                                    'progress', 'completed',
                                    'duration_watched', vid_duration,
                                    'percentage_completed', 100
                                ),
                                msg
                            );
    END IF;


    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_set_finished_date
BEFORE INSERT OR UPDATE OF last_record_time ON internal.student_cm_progress
FOR EACH ROW
EXECUTE FUNCTION internal.set_finished_date_if_complete();



-- 38. ASSESSMENT TYPE
CREATE TABLE internal.assessment_type
(
    asmt_type_id    SERIAL PRIMARY KEY,
    asmt_name       VARCHAR(255) NOT NULL UNIQUE,
    asmt_descr      TEXT
);
ALTER TABLE internal.assessment_type
    ENABLE ROW LEVEL SECURITY;


-- 39. COURSE ASSESSMENT
CREATE TABLE internal.course_assessment
(
    ca_id               SERIAL PRIMARY KEY,
    weight              INT           NOT NULL DEFAULT 1 CHECK (weight BETWEEN 0 AND 100),
    custom_asmt   VARCHAR(50),

    -- Foreign Key(s)
    asmt_type_id        INTEGER       REFERENCES internal.assessment_type (asmt_type_id) ON DELETE RESTRICT,
    version_id          INTEGER       NOT NULL REFERENCES internal.course_version (version_id) ON DELETE CASCADE,

    -- Constraint(s)
    CONSTRAINT unique_assessment UNIQUE (version_id, asmt_type_id),
    CONSTRAINT unique_custom_assessment UNIQUE (version_id, custom_asmt),
    CONSTRAINT assessment_requirement check ( (custom_asmt IS NOT NULL AND asmt_type_id IS NULL) or (custom_asmt IS NULL AND asmt_type_id IS NOT NULL) )
);
ALTER TABLE internal.course_assessment
    ENABLE ROW LEVEL SECURITY;


-- 40. ASSIGNMENT
CREATE TABLE internal.assignment
(
    ass_id          SERIAL PRIMARY KEY,
    ass_title       VARCHAR(255)   NOT NULL,
    total_points    INTEGER        NOT NULL DEFAULT 1 CHECK (total_points BETWEEN 1 AND 100),
    descr           TEXT           NOT NULL,
    relative_offset INTERVAL,
    ca_id           INTEGER        NOT NULL REFERENCES internal.course_assessment (ca_id)   ON DELETE CASCADE,
    lesson_id       INTEGER        NOT NULL REFERENCES internal.lesson (lesson_id) ON DELETE CASCADE,
    created_by      INTEGER        NOT NULL DEFAULT internal.get_user_id() CHECK ( internal.user_role_identifier(created_by) = 'faculty' ) REFERENCES internal.users (user_id) ON DELETE RESTRICT,
    constraint unique_assignment UNIQUE (lesson_id, ass_title)
);
ALTER TABLE internal.assignment
    ENABLE ROW LEVEL SECURITY;



-- 41. ATTACHMENT
CREATE TABLE internal.attachment
(
    attachment_id   SERIAL PRIMARY KEY,
    file_id         UUID    NOT NULL REFERENCES storage.objects (id) ON DELETE RESTRICT,
    ass_id          INTEGER NOT NULL REFERENCES internal.assignment (ass_id) ON DELETE CASCADE
);
ALTER TABLE internal.attachment
    ENABLE ROW LEVEL SECURITY;



-- 42. TEST
CREATE TABLE internal.test
(
    test_id    SERIAL PRIMARY KEY,
    test_title VARCHAR(255) NOT NULL,
    descr      TEXT         NOT NULL,
    time_limit INTERVAL    NOT NULL,
    allowed_attempts INTEGER NOT NULL DEFAULT 1,

    -- Constraint(s)
    ca_id      INTEGER      NOT NULL REFERENCES internal.course_assessment (ca_id)   ON DELETE CASCADE,
    lesson_id  INTEGER      NOT NULL REFERENCES internal.lesson (lesson_id) ON DELETE CASCADE ,
    created_id INTEGER      NOT NULL DEFAULT internal.get_user_id() CHECK ( internal.user_role_identifier(created_id) = 'faculty' ) REFERENCES internal.users (user_id) ON DELETE RESTRICT,

    constraint unique_test UNIQUE (lesson_id, test_title),
    CONSTRAINT time_limit_requirement CHECK (time_limit >= '5 min'::interval)
);
ALTER TABLE internal.test
    ENABLE ROW LEVEL SECURITY;





-- 43. ANSWER TYPE
CREATE TABLE internal.answer_type
(
    anst_id     SERIAL PRIMARY KEY,
    answer_type VARCHAR(100) NOT NULL UNIQUE
);
ALTER TABLE internal.answer_type
    ENABLE ROW LEVEL SECURITY;


-- 44. QUESTION
CREATE TABLE internal.question
(
    question_id  SERIAL PRIMARY KEY,
    question     TEXT    NOT NULL,
    total_points INTEGER NOT NULL DEFAULT 1 CHECK (total_points BETWEEN 0 AND 100),

    -- Foreign Key(s)
    test_id      INTEGER NOT NULL REFERENCES internal.test (test_id)          ON DELETE CASCADE,
    anst_id      INTEGER NOT NULL REFERENCES internal.answer_type (anst_id)   ON DELETE RESTRICT
);
ALTER TABLE internal.question
    ENABLE ROW LEVEL SECURITY;


-- 45.1
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


-- 45.2 ANSWER KEY
CREATE TABLE internal.answer_key
(
    key_id      SERIAL PRIMARY KEY,
    text_key    TEXT,
    tof_key     BOOLEAN,
    is_correct  BOOLEAN NOT NULL DEFAULT FALSE,
    required_items INT,
    enum_keys TEXT[],


    -- Foreign Key(s)
    question_id INTEGER NOT NULL REFERENCES internal.question (question_id)  ON DELETE CASCADE,


    -- Constraint(s)
    CONSTRAINT answer_key_requirement CHECK (

            -- MULTIPLE CHOICE
            (
                internal.answer_type_identifier(question_id) = 'multiple choice'
                AND text_key IS NOT NULL
                AND tof_key IS NULL
                AND required_items IS NULL
                AND (enum_keys IS NULL OR enum_keys = '{}')
            )

            OR

            -- TRUE / FALSE
            (
                internal.answer_type_identifier(question_id) = 'true/false'
                AND text_key IS NULL
                AND tof_key IS NOT NULL
                AND required_items IS NULL
                AND (enum_keys IS NULL OR enum_keys = '{}')
            )

            OR

            -- IDENTIFICATION
            (
                internal.answer_type_identifier(question_id) = 'identification'
                AND text_key IS NOT NULL
                AND tof_key IS NULL
                AND required_items IS NULL
                AND (enum_keys IS NULL OR enum_keys = '{}')
            )

            OR

            -- ENUMERATION
            (
                internal.answer_type_identifier(question_id) = 'enumeration'
                AND text_key IS NULL
                AND tof_key IS NULL
                AND required_items IS NOT NULL
                AND enum_keys IS NOT NULL
                AND array_length(enum_keys, 1) >= 1
            )

            OR

            -- ESSAY
            (
                internal.answer_type_identifier(question_id) = 'essay'
                AND text_key IS NULL
                AND tof_key IS NULL
                AND required_items IS NULL
                AND (enum_keys IS NULL OR enum_keys = '{}')
            )
    )
);
ALTER TABLE internal.answer_key
    ENABLE ROW LEVEL SECURITY;

-- 45.3
CREATE OR REPLACE FUNCTION internal.prevent_duplicate_answer_key()
RETURNS TRIGGER
SET SEARCH_PATH = internal
AS $$
BEGIN
    -- Only enforce for non-multiple-choice and non-enumeration types
    IF internal.answer_type_identifier(NEW.question_id) NOT IN ('multiple choice') THEN

        -- Check if another answer_key already exists for this question
        IF EXISTS (
            SELECT 1
            FROM answer_key ak
            WHERE ak.question_id = NEW.question_id
        ) THEN
            RAISE EXCEPTION
                'Duplicate answer key not allowed for question_id % (type: %)',
                NEW.question_id,
                internal.answer_type_identifier(NEW.question_id)
                USING ERRCODE = 'P0035';
        END IF;

    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_prevent_duplicate_answer_key
BEFORE INSERT ON internal.answer_key
FOR EACH ROW
EXECUTE FUNCTION internal.prevent_duplicate_answer_key();

-- 45.4
CREATE OR REPLACE FUNCTION internal.prevent_question_id_update()
RETURNS TRIGGER
SET search_path = internal
AS $$
BEGIN
    IF NEW.question_id IS DISTINCT FROM OLD.question_id THEN
        RAISE EXCEPTION
            'Updating question_id is not allowed (key_id = %, old_question_id = %, new_question_id = %)',
            OLD.key_id, OLD.question_id, NEW.question_id
            USING ERRCODE = 'P0036';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_prevent_question_id_update
BEFORE UPDATE OF question_id ON internal.answer_key
FOR EACH ROW
EXECUTE FUNCTION internal.prevent_question_id_update();


-- 46.1 TEST RECORD
CREATE TABLE internal.STUDENT_TEST_RECORD
(
    ut_id           SERIAL PRIMARY KEY,
    created_at      TIMESTAMP  NOT NULL DEFAULT now(),
    completed_at    TIMESTAMP,
    ctupia_xp       INT NOT NULL CHECK (ctupia_xp >= 0),
    status          BOOLEAN NOT NULL DEFAULT FALSE, -- TRUE CLAIMED / FALSE CLAIMABLE

    -- Foreign key(s)
    test_id      INTEGER    NOT NULL REFERENCES internal.test (test_id) ON DELETE RESTRICT,
    user_id      INTEGER    NOT NULL DEFAULT internal.get_user_id() CHECK ( internal.user_role_identifier(user_id) = 'student' ) REFERENCES internal.users (user_id) ON DELETE RESTRICT
);
ALTER TABLE internal.STUDENT_TEST_RECORD
    ENABLE ROW LEVEL SECURITY;

-- 46.2
CREATE OR REPLACE FUNCTION internal.enforce_attempt_limit()
RETURNS TRIGGER
Set search_path = internal
AS $$
DECLARE
    allowed_attempts INT;
    current_attempts INT;
BEGIN
    -- Get allowed attempts for this test
    SELECT t.allowed_attempts
    INTO allowed_attempts
    FROM test t
    WHERE t.test_id = NEW.test_id;

    -- Count current attempts by this user for this test
    SELECT COUNT(*)
    INTO current_attempts
    FROM student_test_record str
    WHERE str.user_id = NEW.user_id
      AND str.test_id = NEW.test_id;

    -- Block if limit reached
    IF current_attempts >= allowed_attempts THEN
        RAISE EXCEPTION 'User % has reached maximum attempts (% allowed) for test %',
            NEW.user_id, allowed_attempts, NEW.test_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_attempt_check
BEFORE INSERT ON internal.student_test_record
FOR EACH ROW
EXECUTE FUNCTION internal.enforce_attempt_limit();


-- 46.3
CREATE OR REPLACE FUNCTION internal.prevent_multiple_open_tests()
RETURNS TRIGGER
SET search_path  = internal
AS $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM student_test_record
        WHERE user_id = NEW.user_id
          AND completed_at IS NULL
    ) THEN
        RAISE EXCEPTION 'You currently have an open/pending test/exam somewhere. Please close it first or wait till it closes.'
            USING ERRCODE = 'P0047';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_prevent_multiple_open_tests
BEFORE INSERT ON internal.student_test_record
FOR EACH ROW
EXECUTE FUNCTION internal.prevent_multiple_open_tests();

-- 46.4
CREATE OR REPLACE FUNCTION internal.roll_assignment_chest_xp()
RETURNS TRIGGER
SET SEARCH_PATH = internal
AS $$
DECLARE
    reward_low INT := 10;
    reward_high INT := 100;
BEGIN
    -- Look up the chest linked to the assignment [CURRENTLY NOT IMPLEMENTED]
--     SELECT lower(reward_range), upper(reward_range)
--     INTO reward_low, reward_high
--     FROM chest_rewards c
--     JOIN assignment a ON a.chest_id = c.chest_id
--     WHERE a.ass_id = NEW.ass_id;

    -- Roll random XP between low and high
    NEW.ctupia_xp := floor(random() * (reward_high - reward_low) + reward_low);

    -- Ensure xp is non-negative just in case
    IF NEW.ctupia_xp < 0 THEN
        NEW.ctupia_xp := 0;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER assign_assignment_xp
BEFORE INSERT ON internal.STUDENT_TEST_RECORD
FOR EACH ROW
EXECUTE FUNCTION internal.roll_assignment_chest_xp();

-- 46.5
CREATE OR REPLACE FUNCTION internal.prevent_xp_update()
RETURNS TRIGGER
SET search_path = internal
AS $$
BEGIN
    IF NEW.ctupia_xp <> OLD.ctupia_xp THEN
        RAISE EXCEPTION 'Ctupia XP gained from a Random Loot Chest is immutable and cannot be changed';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER prevent_assignment_xp_update
BEFORE UPDATE ON internal.STUDENT_TEST_RECORD
FOR EACH ROW
EXECUTE FUNCTION internal.prevent_xp_update();



-- 47.1
CREATE OR REPLACE FUNCTION internal.answer_type_identifier2(p_question_id integer)
RETURNS text
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
REVOKE ALL ON FUNCTION internal.answer_type_identifier2(p_question_id integer) FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION internal.answer_type_identifier2(p_question_id integer) TO authenticated;

-- 47.2
CREATE OR REPLACE FUNCTION internal.test_owner_identifier(p_target_faculty_id integer, p_ut_id integer)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = internal
AS $$
DECLARE
    faculty_owner_id INT;
BEGIN
    SELECT t.created_id INTO faculty_owner_id
    FROM student_test_record ut
    INNER JOIN test t ON ut.test_id = t.test_id
    WHERE ut.ut_id = p_ut_id;

    RETURN faculty_owner_id = p_target_faculty_id;
END;
$$;
-- 🚫 Revoke public access
REVOKE ALL ON FUNCTION internal.test_owner_identifier(p_target_faculty_id integer, p_ut_id integer)FROM PUBLIC;
-- ✅ Grant only to trusted internal role
GRANT EXECUTE ON FUNCTION internal.test_owner_identifier(p_target_faculty_id integer, p_ut_id integer) TO authenticated;



-- 47.3 USER ANSWER
CREATE TABLE internal.student_answer
(
    sta_id                  SERIAL PRIMARY KEY,
    answer_time             TIMESTAMP NOT NULL       DEFAULT CURRENT_TIMESTAMP,
    is_reconsidered_by      INTEGER                  REFERENCES internal.users (user_id) ON DELETE RESTRICT,
    tof_ans                 BOOLEAN,                 -- True or False
    text_ans                TEXT,                    -- Essay, Identification, Enumeration
    essay_given_points      INT,                     -- points given for essays
    enum_ans               TEXT[],                     -- points given for essays


    -- Foreign Key(s)
    key_id                  INTEGER   NOT NULL REFERENCES internal.answer_key (key_id) ON DELETE RESTRICT,                 -- Multiple choice
    ut_id                   INTEGER   NOT NULL REFERENCES internal.STUDENT_TEST_RECORD (ut_id) ON DELETE CASCADE,

    -- Constraint(s)
    CONSTRAINT student_answer_requirement CHECK (

        /* MULTIPLE CHOICE */
        (
            internal.answer_type_identifier2(key_id) = 'multiple choice'
            AND tof_ans IS NULL
            AND text_ans IS NULL
            AND essay_given_points IS NULL
            AND (enum_ans IS NULL OR enum_ans = '{}')
        )

        OR

        /* TRUE / FALSE */
        (
            internal.answer_type_identifier2(key_id) = 'true/false'
            AND tof_ans IS NOT NULL
            AND text_ans IS NULL
            AND essay_given_points IS NULL
            AND (enum_ans IS NULL OR enum_ans = '{}')
        )

        OR

        /* IDENTIFICATION */
        (
            internal.answer_type_identifier2(key_id) = 'identification'
            AND tof_ans IS NULL
            AND text_ans IS NOT NULL
            AND essay_given_points IS NULL
            AND (enum_ans IS NULL OR enum_ans = '{}')
        )

        OR

        /* ENUMERATION (student picks multiple answers) */
        (
            internal.answer_type_identifier2(key_id) = 'enumeration'
            AND tof_ans IS NULL
            AND text_ans IS NULL
            AND essay_given_points IS NULL
            AND enum_ans IS NOT NULL
        )

        OR

        /* ESSAY */
        (
            internal.answer_type_identifier2(key_id) = 'essay'
            AND tof_ans IS NULL
            AND text_ans IS NOT NULL
            AND (enum_ans IS NULL OR enum_ans = '{}')
        )
    ),
    CONSTRAINT check_test_owner            CHECK ( internal.test_owner_identifier(is_reconsidered_by, ut_id))
);
ALTER TABLE internal.student_answer
    ENABLE ROW LEVEL SECURITY;


-- 47.4
CREATE OR REPLACE FUNCTION internal.enforce_no_duplicate_answers()
RETURNS TRIGGER
SET SEARCH_PATH = internal
AS $$
DECLARE
    v_question_id INT;
BEGIN
    -- find the question linked to the answer key
    SELECT question_id
    INTO v_question_id
    FROM answer_key
    WHERE key_id = NEW.key_id;

    IF EXISTS (
        SELECT 1
        FROM student_answer sa
        INNER JOIN answer_key ak ON ak.key_id = sa.key_id
        WHERE ak.question_id = v_question_id
            AND sa.ut_id = NEW.ut_id
    ) THEN
        RAISE EXCEPTION
            'Duplicate answer detected: user test % already answered question %',
            NEW.ut_id, v_question_id;
    END IF;

--     -- if not enumeration, check for duplicate answers
--     IF answer_type_identifier2(NEW.key_id) != 'enumeration' THEN
--         IF EXISTS (
--             SELECT 1
--             FROM student_answer sa
--             INNER JOIN answer_key ak ON ak.key_id = sa.key_id
--             WHERE ak.question_id = v_question_id
--               AND sa.ut_id = NEW.ut_id
--         ) THEN
--             RAISE EXCEPTION
--                 'Duplicate answer detected: user test % already answered question %',
--                 NEW.ut_id, v_question_id;
--         END IF;
--     END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_check_duplicate_user_answer
BEFORE INSERT ON internal.student_answer
FOR EACH ROW
EXECUTE FUNCTION internal.enforce_no_duplicate_answers();


-- 47.5
CREATE OR REPLACE FUNCTION internal.entry_validity_check()
RETURNS TRIGGER
set search_path  = internal
AS $$
DECLARE
    v_test_id INT;
BEGIN
    -- Run check only for INSERTs or updates to relevant student columns
    IF TG_OP = 'INSERT'
       OR (TG_OP = 'UPDATE' AND (
            (NEW.text_ans IS DISTINCT FROM OLD.text_ans) OR
            (NEW.tof_ans IS DISTINCT FROM OLD.tof_ans) OR
            (NEW.key_id IS DISTINCT FROM OLD.key_id) OR
            (NEW.ut_id IS DISTINCT FROM OLD.ut_id) OR
            (NEW.answer_time IS DISTINCT FROM OLD.answer_time) OR
            (NEW.enum_ans IS DISTINCT FROM OLD.enum_ans)

        ))
    THEN

        -- find the test id based on the ut_id
        SELECT test_id
        INTO v_test_id
        FROM student_test_record
        WHERE ut_id = NEW.ut_id
          AND user_id = (SELECT user_id FROM users WHERE auth_id = auth.uid());

        -- check if this test is still open
        IF NOT EXISTS (
            SELECT 1
            FROM student_test_record
            WHERE ut_id = NEW.ut_id
              AND user_id = (SELECT user_id FROM users WHERE auth_id = auth.uid())
              AND completed_at IS NULL
        ) THEN
            RAISE EXCEPTION 'Entry invalid. This test/exam already closed.'
                USING ERRCODE = 'P0049';
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_entry_validity_check
BEFORE INSERT OR UPDATE ON internal.student_answer
FOR EACH ROW
EXECUTE FUNCTION internal.entry_validity_check();




-- 48.1 ASSIGNMENT RECORD
CREATE TABLE internal.student_ass_progress
(
    sap_id          SERIAL PRIMARY KEY ,
    ass_id          INTEGER   NOT NULL REFERENCES internal.assignment (ass_id) ON DELETE RESTRICT,
    user_id         INTEGER   NOT NULL DEFAULT internal.get_user_id() CHECK ( internal.user_role_identifier(user_id) = 'student' ) REFERENCES internal.users (user_id) ON DELETE RESTRICT,
    completed_at    TIMESTAMP,
    ctupia_xp       INT NOT NULL CHECK (ctupia_xp >= 0),
    eval_points     INT CHECK (eval_points BETWEEN 0 AND 100),
    date_unlocked   TIMESTAMPTZ DEFAULT NOW(),
    status          BOOLEAN NOT NULL DEFAULT FALSE, -- TRUE CLAIMED / FALSE CLAIMABLE

    -- Constraint(s)
    CONSTRAINT one_assgmnt_one_student UNIQUE  (ass_id, user_id)
);
ALTER TABLE internal.student_ass_progress
    ENABLE ROW LEVEL SECURITY;

-- 48.2
CREATE TRIGGER assign_assignment_xp
BEFORE INSERT ON internal.student_ass_progress
FOR EACH ROW
EXECUTE FUNCTION internal.roll_assignment_chest_xp();

-- 48.3
CREATE TRIGGER prevent_assignment_xp_update
BEFORE UPDATE ON internal.student_ass_progress
FOR EACH ROW
EXECUTE FUNCTION internal.prevent_xp_update();








-- 49. TIER SYSTEM

CREATE TABLE internal.point_tiers (
    tier_id         SERIAL PRIMARY KEY,
    tier_name       TEXT        NOT NULL UNIQUE,           -- Common, Uncommon, Rare...
    duration_range  int4range   NOT NULL,        -- store in minutes
    base_points     INTEGER     NOT NULL,
    created_at      TIMESTAMP NOT NULL DEFAULT NOW()
);
ALTER TABLE internal.point_tiers
    ENABLE ROW LEVEL SECURITY;


-- 50.)
CREATE TABLE internal.student_ass_attachment (
    saa_id SERIAL PRIMARY KEY,
    sap_id INTEGER NOT NULL REFERENCES internal.student_ass_progress (sap_id) ON DELETE CASCADE,
    file_id UUID REFERENCES storage.objects (id) ON DELETE RESTRICT,
    url TEXT CHECK (url ~ '^https?://'),

    CONSTRAINT attachment_type CHECK (
        (file_id IS NOT NULL AND url IS NULL) OR
        (file_id IS NULL AND url IS NOT NULL))
);
ALTER TABLE internal.student_ass_attachment
    ENABLE ROW LEVEL SECURITY;




























----------------------------------------- architecture related tables --------------------------------------------------

-- ERROR LOG TABLE FOR EASY DEBUGGING
CREATE TABLE internal.error_log (
    log_id          SERIAL PRIMARY KEY,
    code            TEXT  NOT NULL     UNIQUE,
    error_type      TEXT  NOT NULL,                             -- e.g., unique_violation, check_violation
    error_msg       TEXT  NOT NULL,                             -- SQLERRM or custom message
    function_name   TEXT  NOT NULL,                             -- e.g., 'secure_create_user'
    context         JSONB NOT NULL,                             -- Input payload or debug data
    severity        TEXT  NOT NULL     DEFAULT 'error',         -- error / warn / info
    auth_id         UUID,                                       -- user auth id
    client_ip       TEXT,                                       --optional
    logged_at       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
ALTER TABLE internal.error_log
    ENABLE ROW LEVEL SECURITY;

-- code: Unique reference (e.g., "USR-4fa82c") shown to client
-- error_type: e.g., 'unique_violation', 'check_violation'
-- context: optional debug payload (jsonb)
-- function_name: where it occurred


-- TABLE FOR SECRET KEYS
CREATE TABLE internal.secret_key (
    key_id      SERIAL PRIMARY KEY,
    func_name   VARCHAR(50) NOT NULL UNIQUE,
    secret_key  TEXT
);
ALTER TABLE internal.secret_key
    ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION internal.generate_secret_key()
RETURNS TEXT AS $$
BEGIN
    -- 32-character hex secret (128-bit entropy)
    RETURN encode(gen_random_bytes(32), 'hex');
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION internal.auto_generate_secret_key()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.secret_key IS NULL THEN
        NEW.secret_key := internal.generate_secret_key();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_generate_secret_key
BEFORE INSERT ON internal.secret_key
FOR EACH ROW
EXECUTE FUNCTION internal.auto_generate_secret_key();






------------------------------------------------------------------------------------------------------------------------
-- REVOKE access to pg_proc
REVOKE SELECT ON pg_proc FROM PUBLIC;
-- Only give access to trusted roles (E.G. like admin_user or internal_ops).












