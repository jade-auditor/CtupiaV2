-- 1. COLLEGE AND OFFICE
INSERT INTO internal.college_and_office (cao_name)
VALUES ('College of Education - Graduate Studies');
INSERT INTO internal.college_and_office (cao_name)
VALUES ('College of Engineering - Graduate Studies');


-- 2. DESIGNATION AND ROLE
INSERT INTO internal.designation_and_role (dar_id, dar_name)
VALUES (1,'admin'),
       (2,'dean'),
       (3,'faculty'),
       (4, 'student');


-- 3. PLATFORM
INSERT INTO internal.platform (platform_name)
VALUES ('web'),
       ('mobile');


-- 4. PAGE
INSERT INTO internal.PAGE (PAGE_NAME, PLATFORM_ID)
VALUES ('admin_dashboard',1),
       ('dean_dashboard',1),
       ('faculty_dashboard',1),
       ('student_home_w',1),
       ('student_home_m',2);


-- 5. EDUCATIONAL QUALIFICATION
-- Note: Rates is based on the University/Institution
INSERT INTO internal.educational_qualification (eq_id, eq_name, rate) VALUES (1, 'Certificate/Diploma (Non-Degree)', 50.00);
INSERT INTO internal.educational_qualification (eq_id, eq_name, rate) VALUES (2, 'Associate Degree', 100.00);
INSERT INTO internal.educational_qualification (eq_id, eq_name, rate) VALUES (3, 'Bachelor''s Degree', 200.00);
INSERT INTO internal.educational_qualification (eq_id, eq_name, rate) VALUES (4, 'Master''s Degree', 225.00);
INSERT INTO internal.educational_qualification (eq_id, eq_name, rate) VALUES (5, 'Doctoral Degree', 250.00);


-- 6. DEGREE
INSERT INTO internal.degree (degree_id, deg_name, deg_abbr, post_nom, eq_id) VALUES (39, 'Associate of Arts', 'AA', 'AA', 2);
INSERT INTO internal.degree (degree_id, deg_name, deg_abbr, post_nom, eq_id) VALUES (40, 'Associate of Science', 'AS', 'AS', 2);
INSERT INTO internal.degree (degree_id, deg_name, deg_abbr, post_nom, eq_id) VALUES (1, 'Bachelor of Arts', 'BA', 'BA', 3);
INSERT INTO internal.degree (degree_id, deg_name, deg_abbr, post_nom, eq_id) VALUES (2, 'Bachelor of Science', 'BSc', 'BSc', 3);
INSERT INTO internal.degree (degree_id, deg_name, deg_abbr, post_nom, eq_id) VALUES (3, 'Bachelor of Engineering', 'BEng', 'BEng', 3);
INSERT INTO internal.degree (degree_id, deg_name, deg_abbr, post_nom, eq_id) VALUES (4, 'Bachelor of Fine Arts', 'BFA', 'BFA', 3);
INSERT INTO internal.degree (degree_id, deg_name, deg_abbr, post_nom, eq_id) VALUES (5, 'Bachelor of Business Administration', 'BBA', 'BBA', 3);
INSERT INTO internal.degree (degree_id, deg_name, deg_abbr, post_nom, eq_id) VALUES (6, 'Bachelor of Laws', 'LLB', 'LLB', 3);
INSERT INTO internal.degree (degree_id, deg_name, deg_abbr, post_nom, eq_id) VALUES (7, 'Bachelor of Education', 'BEd', 'BEd', 3);
INSERT INTO internal.degree (degree_id, deg_name, deg_abbr, post_nom, eq_id) VALUES (8, 'Bachelor of Medicine, Bachelor of Surgery', 'MBBS', 'MBBS', 3);
INSERT INTO internal.degree (degree_id, deg_name, deg_abbr, post_nom, eq_id) VALUES (9, 'Bachelor of Dental Surgery', 'BDS', 'BDS', 3);
INSERT INTO internal.degree (degree_id, deg_name, deg_abbr, post_nom, eq_id) VALUES (10, 'Bachelor of Veterinary Medicine', 'BVetMed', 'BVetMed', 3);
INSERT INTO internal.degree (degree_id, deg_name, deg_abbr, post_nom, eq_id) VALUES (11, 'Bachelor of Architecture', 'BArch', 'BArch', 3);
INSERT INTO internal.degree (degree_id, deg_name, deg_abbr, post_nom, eq_id) VALUES (12, 'Bachelor of Computer Science', 'BCompSc', 'BCompSc', 3);
INSERT INTO internal.degree (degree_id, deg_name, deg_abbr, post_nom, eq_id) VALUES (13, 'Bachelor of Information Technology', 'BIT', 'BIT', 3);
INSERT INTO internal.degree (degree_id, deg_name, deg_abbr, post_nom, eq_id) VALUES (14, 'Bachelor of Nursing', 'BN', 'BN', 3);
INSERT INTO internal.degree (degree_id, deg_name, deg_abbr, post_nom, eq_id) VALUES (15, 'Bachelor of Pharmacy', 'BPharm', 'BPharm', 3);
INSERT INTO internal.degree (degree_id, deg_name, deg_abbr, post_nom, eq_id) VALUES (16, 'Bachelor of Social Work', 'BSW', 'BSW', 3);
INSERT INTO internal.degree (degree_id, deg_name, deg_abbr, post_nom, eq_id) VALUES (41, 'Master of Arts', 'MA', 'MA', 4);
INSERT INTO internal.degree (degree_id, deg_name, deg_abbr, post_nom, eq_id) VALUES (42, 'Master of Science', 'MSc', 'MSc', 4);
INSERT INTO internal.degree (degree_id, deg_name, deg_abbr, post_nom, eq_id) VALUES (43, 'Master of Business Administration', 'MBA', 'MBA', 4);
INSERT INTO internal.degree (degree_id, deg_name, deg_abbr, post_nom, eq_id) VALUES (44, 'Master of Education', 'MEd', 'MEd', 4);
INSERT INTO internal.degree (degree_id, deg_name, deg_abbr, post_nom, eq_id) VALUES (45, 'Master of Engineering', 'MEng', 'MEng', 4);
INSERT INTO internal.degree (degree_id, deg_name, deg_abbr, post_nom, eq_id) VALUES (46, 'Master of Fine Arts', 'MFA', 'MFA', 4);
INSERT INTO internal.degree (degree_id, deg_name, deg_abbr, post_nom, eq_id) VALUES (47, 'Master of Public Health', 'MPH', 'MPH', 4);
INSERT INTO internal.degree (degree_id, deg_name, deg_abbr, post_nom, eq_id) VALUES (48, 'Master of Social Work', 'MSW', 'MSW', 4);
INSERT INTO internal.degree (degree_id, deg_name, deg_abbr, post_nom, eq_id) VALUES (49, 'Master of Laws', 'LLM', 'LLM', 4);
INSERT INTO internal.degree (degree_id, deg_name, deg_abbr, post_nom, eq_id) VALUES (50, 'Master of Architecture', 'MArch', 'MArch', 4);
INSERT INTO internal.degree (degree_id, deg_name, deg_abbr, post_nom, eq_id) VALUES (51, 'Master of Computer Science', 'MCompSc', 'MCompSc', 4);
INSERT INTO internal.degree (degree_id, deg_name, deg_abbr, post_nom, eq_id) VALUES (52, 'Master of Information Technology', 'MIT', 'MIT', 4);
INSERT INTO internal.degree (degree_id, deg_name, deg_abbr, post_nom, eq_id) VALUES (53, 'Master of Public Administration', 'MPA', 'MPA', 4);
INSERT INTO internal.degree (degree_id, deg_name, deg_abbr, post_nom, eq_id) VALUES (54, 'Master of Science in Nursing', 'MSN', 'MSN', 4);
INSERT INTO internal.degree (degree_id, deg_name, deg_abbr, post_nom, eq_id) VALUES (55, 'Doctor of Philosophy', 'PhD', 'PhD', 5);
INSERT INTO internal.degree (degree_id, deg_name, deg_abbr, post_nom, eq_id) VALUES (56, 'Doctor of Medicine', 'MD', 'MD', 5);
INSERT INTO internal.degree (degree_id, deg_name, deg_abbr, post_nom, eq_id) VALUES (57, 'Doctor of Dental Surgery', 'DDS', 'DDS', 5);
INSERT INTO internal.degree (degree_id, deg_name, deg_abbr, post_nom, eq_id) VALUES (58, 'Doctor of Veterinary Medicine', 'DVM', 'DVM', 5);
INSERT INTO internal.degree (degree_id, deg_name, deg_abbr, post_nom, eq_id) VALUES (59, 'Doctor of Education', 'EdD', 'EdD', 5);
INSERT INTO internal.degree (degree_id, deg_name, deg_abbr, post_nom, eq_id) VALUES (60, 'Doctor of Juridical Science', 'SJD', 'SJD', 5);
INSERT INTO internal.degree (degree_id, deg_name, deg_abbr, post_nom, eq_id) VALUES (61, 'Doctor of Business Administration', 'DBA', 'DBA', 5);
INSERT INTO internal.degree (degree_id, deg_name, deg_abbr, post_nom, eq_id) VALUES (62, 'Doctor of Public Health', 'DrPH', 'DrPH', 5);
INSERT INTO internal.degree (degree_id, deg_name, deg_abbr, post_nom, eq_id) VALUES (63, 'Doctor of Engineering', 'DEng', 'DEng', 5);
INSERT INTO internal.degree (degree_id, deg_name, deg_abbr, post_nom, eq_id) VALUES (64, 'Doctor of Musical Arts', 'DMA', 'DMA', 5);
INSERT INTO internal.degree (degree_id, deg_name, deg_abbr, post_nom, eq_id) VALUES (65, 'Doctor of Nursing Practice', 'DNP', 'DNP', 5);
INSERT INTO internal.degree (degree_id, deg_name, deg_abbr, post_nom, eq_id) VALUES (66, 'Doctor of Pharmacy', 'PharmD', 'PharmD', 5);
INSERT INTO internal.degree (degree_id, deg_name, deg_abbr, post_nom, eq_id) VALUES (67, 'Doctor of Physical Therapy', 'DPT', 'DPT', 5);
INSERT INTO internal.degree (degree_id, deg_name, deg_abbr, post_nom, eq_id) VALUES (68, 'Doctor of Psychology', 'PsyD', 'PsyD', 5);
INSERT INTO internal.degree (degree_id, deg_name, deg_abbr, post_nom, eq_id) VALUES (69, 'Diploma in Nursing', 'DipN', 'DipN', 1);
INSERT INTO internal.degree (degree_id, deg_name, deg_abbr, post_nom, eq_id) VALUES (70, 'Diploma in Education', 'DipEd', 'DipEd', 1);
INSERT INTO internal.degree (degree_id, deg_name, deg_abbr, post_nom, eq_id) VALUES (71, 'Certificate in Teaching', 'CertT', 'CertT', 1);
INSERT INTO internal.degree (degree_id, deg_name, deg_abbr, post_nom, eq_id) VALUES (72, 'Certificate in Information Technology', 'CertIT', 'CertIT', 1);
INSERT INTO internal.degree (degree_id, deg_name, deg_abbr, post_nom, eq_id) VALUES (73, 'Postgraduate Diploma in Education', 'PGDE', 'PGDE', 1);
INSERT INTO internal.degree (degree_id, deg_name, deg_abbr, post_nom, eq_id) VALUES (74, 'Postgraduate Certificate in Education', 'PGCE', 'PGCE', 1);
INSERT INTO internal.degree (degree_id, deg_name, deg_abbr, post_nom, eq_id) VALUES (75, 'Higher National Diploma', 'HND', 'HND', 1);
INSERT INTO internal.degree (degree_id, deg_name, deg_abbr, post_nom, eq_id) VALUES (76, 'Licentiate in Music', 'LMus', 'LMus', 1);
INSERT INTO internal.degree (degree_id, deg_name, deg_abbr, post_nom, eq_id) VALUES (77, 'Licentiate in Theology', 'LTh', 'LTh', 1);
INSERT INTO internal.degree (degree_id, deg_name, deg_abbr, post_nom, eq_id) VALUES (17, 'Bachelor of Theology', 'BTh', 'BTh', 3);
INSERT INTO internal.degree (degree_id, deg_name, deg_abbr, post_nom, eq_id) VALUES (18, 'Bachelor of Music', 'BM', 'BM', 3);
INSERT INTO internal.degree (degree_id, deg_name, deg_abbr, post_nom, eq_id) VALUES (19, 'Bachelor of Commerce', 'BCom', 'BCom', 3);
INSERT INTO internal.degree (degree_id, deg_name, deg_abbr, post_nom, eq_id) VALUES (20, 'Bachelor of Economics', 'BEc', 'BEc', 3);
INSERT INTO internal.degree (degree_id, deg_name, deg_abbr, post_nom, eq_id) VALUES (21, 'Bachelor of Environmental Science', 'BEnvSc', 'BEnvSc', 3);
INSERT INTO internal.degree (degree_id, deg_name, deg_abbr, post_nom, eq_id) VALUES (22, 'Bachelor of Public Administration', 'BPA', 'BPA', 3);
INSERT INTO internal.degree (degree_id, deg_name, deg_abbr, post_nom, eq_id) VALUES (23, 'Bachelor of Physical Education', 'BPEd', 'BPEd', 3);
INSERT INTO internal.degree (degree_id, deg_name, deg_abbr, post_nom, eq_id) VALUES (24, 'Bachelor of Arts in Communication', 'BAC', 'BAC', 3);
INSERT INTO internal.degree (degree_id, deg_name, deg_abbr, post_nom, eq_id) VALUES (25, 'Bachelor of Fine Arts in Dance', 'BFAD', 'BFAD', 3);
INSERT INTO internal.degree (degree_id, deg_name, deg_abbr, post_nom, eq_id) VALUES (26, 'Bachelor of Industrial Technology', 'BITech', 'BITech', 3);
INSERT INTO internal.degree (degree_id, deg_name, deg_abbr, post_nom, eq_id) VALUES (27, 'Bachelor of Science in Accountancy', 'BSA', 'BSA', 3);
INSERT INTO internal.degree (degree_id, deg_name, deg_abbr, post_nom, eq_id) VALUES (28, 'Bachelor of Science in Civil Engineering', 'BSCE', 'BSCE', 3);
INSERT INTO internal.degree (degree_id, deg_name, deg_abbr, post_nom, eq_id) VALUES (29, 'Bachelor of Science in Electrical Engineering', 'BSEE', 'BSEE', 3);
INSERT INTO internal.degree (degree_id, deg_name, deg_abbr, post_nom, eq_id) VALUES (30, 'Bachelor of Science in Mechanical Engineering', 'BSME', 'BSME', 3);
INSERT INTO internal.degree (degree_id, deg_name, deg_abbr, post_nom, eq_id) VALUES (31, 'Bachelor of Science in Computer Engineering', 'BSCompE', 'BSCompE', 3);
INSERT INTO internal.degree (degree_id, deg_name, deg_abbr, post_nom, eq_id) VALUES (32, 'Bachelor of Science in Information Systems', 'BSIS', 'BSIS', 3);
INSERT INTO internal.degree (degree_id, deg_name, deg_abbr, post_nom, eq_id) VALUES (33, 'Bachelor of Science in Psychology', 'BSPsy', 'BSPsy', 3);
INSERT INTO internal.degree (degree_id, deg_name, deg_abbr, post_nom, eq_id) VALUES (34, 'Bachelor of Science in Biology', 'BSBio', 'BSBio', 3);
INSERT INTO internal.degree (degree_id, deg_name, deg_abbr, post_nom, eq_id) VALUES (35, 'Bachelor of Science in Chemistry', 'BSChem', 'BSChem', 3);
INSERT INTO internal.degree (degree_id, deg_name, deg_abbr, post_nom, eq_id) VALUES (36, 'Bachelor of Science in Mathematics', 'BSMath', 'BSMath', 3);
INSERT INTO internal.degree (degree_id, deg_name, deg_abbr, post_nom, eq_id) VALUES (37, 'Bachelor of Science in Statistics', 'BSStat', 'BSStat', 3);
INSERT INTO internal.degree (degree_id, deg_name, deg_abbr, post_nom, eq_id) VALUES (38, 'Bachelor of Science in Nursing', 'BSN', 'BSN', 3);
INSERT INTO internal.degree (degree_id, deg_name, deg_abbr, post_nom, eq_id) VALUES (78, 'Bachelor of Laws (Honours)', 'LLB (Hons)', 'LLB (Hons)', 3);
INSERT INTO internal.degree (degree_id, deg_name, deg_abbr, post_nom, eq_id) VALUES (79, 'Bachelor of Science in Agriculture', 'BSAgr', 'BSAgr', 3);
INSERT INTO internal.degree (degree_id, deg_name, deg_abbr, post_nom, eq_id) VALUES (80, 'Bachelor of Science in Forestry', 'BSF', 'BSF', 3);
INSERT INTO internal.degree (degree_id, deg_name, deg_abbr, post_nom, eq_id) VALUES (81, 'Bachelor of Science in Geology', 'BSG', 'BSG', 3);
INSERT INTO internal.degree (degree_id, deg_name, deg_abbr, post_nom, eq_id) VALUES (82, 'Bachelor of Science in Marine Biology', 'BSMB', 'BSMB', 3);
INSERT INTO internal.degree (degree_id, deg_name, deg_abbr, post_nom, eq_id) VALUES (83, 'Bachelor of Science in Environmental Engineering', 'BSEnvE', 'BSEnvE', 3);
INSERT INTO internal.degree (degree_id, deg_name, deg_abbr, post_nom, eq_id) VALUES (84, 'Bachelor of Science in Food Technology', 'BSFT', 'BSFT', 3);
INSERT INTO internal.degree (degree_id, deg_name, deg_abbr, post_nom, eq_id) VALUES (85, 'Bachelor of Science in Hospitality Management', 'BSHM', 'BSHM', 3);
INSERT INTO internal.degree (degree_id, deg_name, deg_abbr, post_nom, eq_id) VALUES (86, 'Bachelor of Science in Tourism Management', 'BSTM', 'BSTM', 3);
INSERT INTO internal.degree (degree_id, deg_name, deg_abbr, post_nom, eq_id) VALUES (87, 'Bachelor of Science in Criminology', 'BSCrim', 'BSCrim', 3);
INSERT INTO internal.degree (degree_id, deg_name, deg_abbr, post_nom, eq_id) VALUES (88, 'Bachelor of Science in Occupational Therapy', 'BSOT', 'BSOT', 3);
INSERT INTO internal.degree (degree_id, deg_name, deg_abbr, post_nom, eq_id) VALUES (89, 'Bachelor of Science in Radiologic Technology', 'BSRT', 'BSRT', 3);
INSERT INTO internal.degree (degree_id, deg_name, deg_abbr, post_nom, eq_id) VALUES (90, 'Bachelor of Science in Speech Pathology', 'BSSP', 'BSSP', 3);
INSERT INTO internal.degree (degree_id, deg_name, deg_abbr, post_nom, eq_id) VALUES (91, 'Bachelor of Science in Physical Therapy', 'BSPT', 'BSPT', 3);


-- 7. ROLE BASED ACCESS CONTROL
INSERT INTO internal.role_based_access_control (page_id, dar_id, is_main)
VALUES (1,1,TRUE),
       (2,2,TRUE),
       (3,3,TRUE),
       (4,4,TRUE),
       (5,4,TRUE);


-- 8. ROLE PRIVILEGES
INSERT INTO internal.role_privileges (CREATOR_ROLE_ID, CREATABLE_ROLE_ID)
VALUES (1, 1),
       (1,2),
       (1,3),
       (1,4),
       (2,3),
       (2,4);


-- 9. FACULTY
INSERT INTO internal.faculty (faculty_title)
VALUES
  ('Instructor'),
  ('Assistant Prof.'),
  ('Associate Prof.'),
  ('Professor'),
  ('Univ. Professor');


-- 10. SALARY GRADE
-- Note: This salary grade is based on year 2025. You may update this yourself
INSERT INTO internal.salary_grade (sg_id, sg_num, salary_data) VALUES (1, 1, '{"step1": 14061, "step2": 14164, "step3": 14278, "step4": 14393, "step5": 14509, "step6": 14626, "step7": 14743, "step8": 14862}');
INSERT INTO internal.salary_grade (sg_id, sg_num, salary_data) VALUES (2, 2, '{"step1": 14925, "step2": 15035, "step3": 15148, "step4": 15258, "step5": 15371, "step6": 15548, "step7": 15599, "step8": 15714}');
INSERT INTO internal.salary_grade (sg_id, sg_num, salary_data) VALUES (3, 3, '{"step1": 15852, "step2": 15971, "step3": 16088, "step4": 16208, "step5": 16329, "step6": 16448, "step7": 16571, "step8": 16693}');
INSERT INTO internal.salary_grade (sg_id, sg_num, salary_data) VALUES (4, 4, '{"step1": 16833, "step2": 16696, "step3": 17084, "step4": 17209, "step5": 17337, "step6": 17464, "step7": 17594, "step8": 17724}');
INSERT INTO internal.salary_grade (sg_id, sg_num, salary_data) VALUES (5, 5, '{"step1": 17686, "step2": 18080, "step3": 18133, "step4": 18267, "step5": 18401, "step6": 18538, "step7": 18676, "step8": 18813}');
INSERT INTO internal.salary_grade (sg_id, sg_num, salary_data) VALUES (6, 6, '{"step1": 18957, "step2": 19098, "step3": 19239, "step4": 19388, "step5": 19526, "step6": 19716, "step7": 19701, "step8": 19963}');
INSERT INTO internal.salary_grade (sg_id, sg_num, salary_data) VALUES (7, 7, '{"step1": 20110, "step2": 20258, "step3": 20408, "step4": 20560, "step5": 20711, "step6": 20865, "step7": 21009, "step8": 21175}');
INSERT INTO internal.salary_grade (sg_id, sg_num, salary_data) VALUES (8, 8, '{"step1": 21344, "step2": 21462, "step3": 21639, "step4": 21830, "step5": 21972, "step6": 22144, "step7": 22312, "step8": 22485}');
INSERT INTO internal.salary_grade (sg_id, sg_num, salary_data) VALUES (9, 9, '{"step1": 23226, "step2": 23411, "step3": 23599, "step4": 23783, "step5": 23978, "step6": 24217, "step7": 24364, "step8": 24558}');
INSERT INTO internal.salary_grade (sg_id, sg_num, salary_data) VALUES (10, 10, '{"step1": 25286, "step2": 25308, "step3": 25996, "step4": 26089, "step5": 26212, "step6": 26263, "step7": 26385, "step8": 27050}');
INSERT INTO internal.salary_grade (sg_id, sg_num, salary_data) VALUES (11, 11, '{"step1": 30244, "step2": 30500, "step3": 30597, "step4": 30809, "step5": 31185, "step6": 31486, "step7": 31790, "step8": 32099}');
INSERT INTO internal.salary_grade (sg_id, sg_num, salary_data) VALUES (12, 12, '{"step1": 32425, "step2": 32932, "step3": 33329, "step4": 35369, "step5": 35694, "step6": 37022, "step7": 36534, "step8": 36901}');
INSERT INTO internal.salary_grade (sg_id, sg_num, salary_data) VALUES (13, 13, '{"step1": 34421, "step2": 34733, "step3": 35049, "step4": 35369, "step5": 35694, "step6": 36002, "step7": 36354, "step8": 36691}');
INSERT INTO internal.salary_grade (sg_id, sg_num, salary_data) VALUES (14, 14, '{"step1": 37024, "step2": 37384, "step3": 37749, "step4": 38118, "step5": 38491, "step6": 38869, "step7": 39252, "step8": 39640}');
INSERT INTO internal.salary_grade (sg_id, sg_num, salary_data) VALUES (15, 15, '{"step1": 40208, "step2": 40604, "step3": 41006, "step4": 41413, "step5": 41824, "step6": 42241, "step7": 42662, "step8": 43090}');
INSERT INTO internal.salary_grade (sg_id, sg_num, salary_data) VALUES (16, 16, '{"step1": 43560, "step2": 43996, "step3": 44438, "step4": 44885, "step5": 45338, "step6": 45796, "step7": 46261, "step8": 46730}');
INSERT INTO internal.salary_grade (sg_id, sg_num, salary_data) VALUES (17, 17, '{"step1": 47247, "step2": 47727, "step3": 48143, "step4": 48805, "step5": 49537, "step6": 49930, "step7": 50218, "step8": 50735}');
INSERT INTO internal.salary_grade (sg_id, sg_num, salary_data) VALUES (18, 18, '{"step1": 51304, "step2": 51832, "step3": 52316, "step4": 52907, "step5": 53456, "step6": 54010, "step7": 54725, "step8": 55249}');
INSERT INTO internal.salary_grade (sg_id, sg_num, salary_data) VALUES (19, 19, '{"step1": 56390, "step2": 57165, "step3": 57953, "step4": 58573, "step5": 59567, "step6": 60349, "step7": 61235, "step8": 62098}');
INSERT INTO internal.salary_grade (sg_id, sg_num, salary_data) VALUES (20, 20, '{"step1": 62697, "step2": 63842, "step3": 64732, "step4": 65637, "step5": 66657, "step6": 67479, "step7": 68019, "step8": 69249}');
INSERT INTO internal.salary_grade (sg_id, sg_num, salary_data) VALUES (21, 21, '{"step1": 70013, "step2": 71002, "step3": 72004, "step4": 73023, "step5": 74061, "step6": 75115, "step7": 76191, "step8": 77239}');
INSERT INTO internal.salary_grade (sg_id, sg_num, salary_data) VALUES (22, 22, '{"step1": 78162, "step2": 79277, "step3": 80411, "step4": 81564, "step5": 82735, "step6": 83987, "step7": 85095, "step8": 86243}');
INSERT INTO internal.salary_grade (sg_id, sg_num, salary_data) VALUES (23, 23, '{"step1": 87315, "step2": 88574, "step3": 89855, "step4": 91163, "step5": 92592, "step6": 94043, "step7": 95518, "step8": 96955}');
INSERT INTO internal.salary_grade (sg_id, sg_num, salary_data) VALUES (24, 24, '{"step1": 98895, "step2": 100971, "step3": 101283, "step4": 103871, "step5": 104483, "step6": 106123, "step7": 107739, "step8": 109431}');
INSERT INTO internal.salary_grade (sg_id, sg_num, salary_data) VALUES (25, 25, '{"step1": 111727, "step2": 113476, "step3": 115254, "step4": 117062, "step5": 118899, "step6": 120766, "step7": 122664, "step8": 124591}');
INSERT INTO internal.salary_grade (sg_id, sg_num, salary_data) VALUES (26, 26, '{"step1": 122625, "step2": 124228, "step3": 130238, "step4": 132802, "step5": 134356, "step6": 136465, "step7": 138600, "step8": 140788}');
INSERT INTO internal.salary_grade (sg_id, sg_num, salary_data) VALUES (27, 27, '{"step1": 140469, "step2": 150764, "step3": 155649, "step4": 160927, "step5": 167887, "step6": 173120, "step7": 176083, "step8": 178572}');
INSERT INTO internal.salary_grade (sg_id, sg_num, salary_data) VALUES (28, 28, '{"step1": 160492, "step2": 183332, "step3": 186278, "step4": 189151, "step5": 192131, "step6": 194792, "step7": 197800, "step8": 200998}');
INSERT INTO internal.salary_grade (sg_id, sg_num, salary_data) VALUES (29, 29, '{"step1": 203200, "step2": 204091, "step3": 209558, "step4": 212766, "step5": 216022, "step6": 219434, "step7": 222979, "step8": 226685}');
INSERT INTO internal.salary_grade (sg_id, sg_num, salary_data) VALUES (30, 30, '{"step1": 293191, "step2": 298773, "step3": 304464, "step4": 310119, "step5": 315883, "step6": 321846, "step7": 327895, "step8": 334059}');
INSERT INTO internal.salary_grade (sg_id, sg_num, salary_data) VALUES (31, 31, '{"step1": 347888, "step2": 354743, "step3": 361736, "step4": 368694, "step5": 375969, "step6": 383391, "step7": 390963, "step8": 398686}');
INSERT INTO internal.salary_grade (sg_id, sg_num, salary_data) VALUES (32, 33, '{"step1": 438844, "step2": 451713, "step3": null, "step4": null, "step5": null, "step6": null, "step7": null, "step8": null}');




-- 11. FACULTY RANK
INSERT INTO internal.faculty_rank (rank_id, rank_level, descr, faculty_id, sg_id) VALUES (4, 4, null, 1, null);
INSERT INTO internal.faculty_rank (rank_id, rank_level, descr, faculty_id, sg_id) VALUES (5, 5, null, 1, null);
INSERT INTO internal.faculty_rank (rank_id, rank_level, descr, faculty_id, sg_id) VALUES (6, 6, null, 1, null);
INSERT INTO internal.faculty_rank (rank_id, rank_level, descr, faculty_id, sg_id) VALUES (7, 7, null, 1, null);
INSERT INTO internal.faculty_rank (rank_id, rank_level, descr, faculty_id, sg_id) VALUES (12, 5, null, 2, null);
INSERT INTO internal.faculty_rank (rank_id, rank_level, descr, faculty_id, sg_id) VALUES (13, 6, null, 2, null);
INSERT INTO internal.faculty_rank (rank_id, rank_level, descr, faculty_id, sg_id) VALUES (14, 7, null, 2, null);
INSERT INTO internal.faculty_rank (rank_id, rank_level, descr, faculty_id, sg_id) VALUES (20, 6, null, 3, null);
INSERT INTO internal.faculty_rank (rank_id, rank_level, descr, faculty_id, sg_id) VALUES (21, 7, null, 3, null);
INSERT INTO internal.faculty_rank (rank_id, rank_level, descr, faculty_id, sg_id) VALUES (28, 7, null, 4, null);
INSERT INTO internal.faculty_rank (rank_id, rank_level, descr, faculty_id, sg_id) VALUES (29, 8, null, 4, null);
INSERT INTO internal.faculty_rank (rank_id, rank_level, descr, faculty_id, sg_id) VALUES (30, 9, null, 4, null);
INSERT INTO internal.faculty_rank (rank_id, rank_level, descr, faculty_id, sg_id) VALUES (31, 10, null, 4, null);
INSERT INTO internal.faculty_rank (rank_id, rank_level, descr, faculty_id, sg_id) VALUES (32, 11, null, 4, null);
INSERT INTO internal.faculty_rank (rank_id, rank_level, descr, faculty_id, sg_id) VALUES (33, 12, null, 4, null);
INSERT INTO internal.faculty_rank (rank_id, rank_level, descr, faculty_id, sg_id) VALUES (1, 1, null, 1, 12);
INSERT INTO internal.faculty_rank (rank_id, rank_level, descr, faculty_id, sg_id) VALUES (2, 2, null, 1, 13);
INSERT INTO internal.faculty_rank (rank_id, rank_level, descr, faculty_id, sg_id) VALUES (3, 3, null, 1, 14);
INSERT INTO internal.faculty_rank (rank_id, rank_level, descr, faculty_id, sg_id) VALUES (8, 1, null, 2, 15);
INSERT INTO internal.faculty_rank (rank_id, rank_level, descr, faculty_id, sg_id) VALUES (9, 2, null, 2, 16);
INSERT INTO internal.faculty_rank (rank_id, rank_level, descr, faculty_id, sg_id) VALUES (10, 3, null, 2, 17);
INSERT INTO internal.faculty_rank (rank_id, rank_level, descr, faculty_id, sg_id) VALUES (11, 4, null, 2, 18);
INSERT INTO internal.faculty_rank (rank_id, rank_level, descr, faculty_id, sg_id) VALUES (15, 1, null, 3, 19);
INSERT INTO internal.faculty_rank (rank_id, rank_level, descr, faculty_id, sg_id) VALUES (16, 2, null, 3, 20);
INSERT INTO internal.faculty_rank (rank_id, rank_level, descr, faculty_id, sg_id) VALUES (17, 3, null, 3, 21);
INSERT INTO internal.faculty_rank (rank_id, rank_level, descr, faculty_id, sg_id) VALUES (18, 4, null, 3, 22);
INSERT INTO internal.faculty_rank (rank_id, rank_level, descr, faculty_id, sg_id) VALUES (19, 5, null, 3, 23);
INSERT INTO internal.faculty_rank (rank_id, rank_level, descr, faculty_id, sg_id) VALUES (22, 1, null, 4, 24);
INSERT INTO internal.faculty_rank (rank_id, rank_level, descr, faculty_id, sg_id) VALUES (23, 2, null, 4, 25);
INSERT INTO internal.faculty_rank (rank_id, rank_level, descr, faculty_id, sg_id) VALUES (24, 3, null, 4, 26);
INSERT INTO internal.faculty_rank (rank_id, rank_level, descr, faculty_id, sg_id) VALUES (25, 4, null, 4, 27);
INSERT INTO internal.faculty_rank (rank_id, rank_level, descr, faculty_id, sg_id) VALUES (26, 5, null, 4, 28);
INSERT INTO internal.faculty_rank (rank_id, rank_level, descr, faculty_id, sg_id) VALUES (27, 6, null, 4, 29);
INSERT INTO internal.faculty_rank (rank_id, rank_level, descr, faculty_id, sg_id) VALUES (34, 0, null, 5, 30);


--12. USERS
-- Note: These are accounts you may need to use as admin accounts.
-- You will personally add these accounts with their unique emails. Navigate to Authentication -> Add User -> Create a new user.
-- Copy the uid of the accounts and paste it here as the parameters.
-- If you wish to name these accounts with a real person. You may update this account later
-- Unhide this line of code if you already added users in Supabase Dashboard
-- INSERT INTO internal.users (lname, mname, fname, birth_date, auth_id, dar_id, created_by)
--         VALUES ('Admin1', 'Admin1', 'Admin1', '1980-06-15',
--                 '38b0b333-1077-4429-ae7a-4bc74fa7472b',1, null);


-- 14. CERTIFICATION
INSERT INTO internal.certification (certification_id, certification) VALUES (1, 'Master''s Degree');
INSERT INTO internal.certification (certification_id, certification) VALUES (4, 'Completion Certificate');


-- 20. CLASSIFICATION
INSERT INTO internal.classification (classification_id, classification) VALUES (1, 'Foundation Course');
INSERT INTO internal.classification (classification_id, classification) VALUES (2, 'Major Course');
INSERT INTO internal.classification (classification_id, classification) VALUES (3, 'Cognates/Electives');
INSERT INTO internal.classification (classification_id, classification) VALUES (4, 'Research Design & Writing');


-- 21. YEAR
INSERT INTO internal.year (year_id, year) VALUES (1, 1);
INSERT INTO internal.year (year_id, year) VALUES (2, 2);
INSERT INTO internal.year (year_id, year) VALUES (3, 3);
INSERT INTO internal.year (year_id, year) VALUES (4, 4);
INSERT INTO internal.year (year_id, year) VALUES (5, 5);


-- 22. TERM TYPE
INSERT INTO internal.term_type (ttype_id, type_name) VALUES (1, 'Semester');
INSERT INTO internal.term_type (ttype_id, type_name) VALUES (2, 'Trimester');


-- 23. SEMESTER
INSERT INTO internal.semester (sem_id, sem_num, sem_name, is_optional, ttype_id) VALUES (1, 1, '1st Semester', false, 1);
INSERT INTO internal.semester (sem_id, sem_num, sem_name, is_optional, ttype_id) VALUES (2, 2, '2nd Semester', false, 1);
INSERT INTO internal.semester (sem_id, sem_num, sem_name, is_optional, ttype_id) VALUES (3, 3, 'Summer', true, 1);
INSERT INTO internal.semester (sem_id, sem_num, sem_name, is_optional, ttype_id) VALUES (4, 1, '1st Trimester', false, 2);
INSERT INTO internal.semester (sem_id, sem_num, sem_name, is_optional, ttype_id) VALUES (5, 2, '2nd Trimester', false, 2);
INSERT INTO internal.semester (sem_id, sem_num, sem_name, is_optional, ttype_id) VALUES (6, 3, '3rd Trimester', false, 2);


-- 27.LEARNING LEVEL
INSERT INTO internal.learning_level (ll_id, level) VALUES (1, 'Beginner');
INSERT INTO internal.learning_level (ll_id, level) VALUES (2, 'Elementary');
INSERT INTO internal.learning_level (ll_id, level) VALUES (3, 'Intermediate');
INSERT INTO internal.learning_level (ll_id, level) VALUES (4, 'Advanced');
INSERT INTO internal.learning_level (ll_id, level) VALUES (5, 'Expert');


-- 29. DAY
INSERT INTO internal.day (day_id, day_name, day_abbr) VALUES (1, 'Monday', 'M');
INSERT INTO internal.day (day_id, day_name, day_abbr) VALUES (2, 'Tuesday', 'T');
INSERT INTO internal.day (day_id, day_name, day_abbr) VALUES (3, 'Wednesday', 'W');
INSERT INTO internal.day (day_id, day_name, day_abbr) VALUES (4, 'Thursday', 'Th');
INSERT INTO internal.day (day_id, day_name, day_abbr) VALUES (5, 'Friday', 'F');
INSERT INTO internal.day (day_id, day_name, day_abbr) VALUES (6, 'Saturday', 'S');
INSERT INTO internal.day (day_id, day_name, day_abbr) VALUES (7, 'Sunday', 'Su');


-- 38. ASSESSMENT TYPE
INSERT INTO internal.assessment_type (asmt_type_id, asmt_name, asmt_descr) VALUES (1, 'Formative', 'Low-stakes assessments such as reflections, discussion posts, short essays.');
INSERT INTO internal.assessment_type (asmt_type_id, asmt_name, asmt_descr) VALUES (2, 'Summative', 'Final evaluations like research papers, comprehensive exams, oral defense.');
INSERT INTO internal.assessment_type (asmt_type_id, asmt_name, asmt_descr) VALUES (3, 'Authentic', 'Real-world applications such as case studies, policy briefs, coding prototypes.');
INSERT INTO internal.assessment_type (asmt_type_id, asmt_name, asmt_descr) VALUES (4, 'Portfolio', 'Continuous assessment of research progress or collection of outputs.');
INSERT INTO internal.assessment_type (asmt_type_id, asmt_name, asmt_descr) VALUES (5, 'Peer Review', 'Scholarly critique by peers, group contribution evaluation.');
INSERT INTO internal.assessment_type (asmt_type_id, asmt_name, asmt_descr) VALUES (6, 'Self Assessment', 'Student reflection on their own learning and performance.');


-- 43. ANSWER TYPE
INSERT INTO internal.answer_type (anst_id, answer_type) VALUES (1, 'multiple choice');
INSERT INTO internal.answer_type (anst_id, answer_type) VALUES (2, 'true/false');
INSERT INTO internal.answer_type (anst_id, answer_type) VALUES (3, 'identification');
INSERT INTO internal.answer_type (anst_id, answer_type) VALUES (4, 'enumeration');
INSERT INTO internal.answer_type (anst_id, answer_type) VALUES (5, 'essay');


-- 49. TIER SYSTEM
INSERT INTO internal.point_tiers (tier_id, tier_name, duration_range, base_points, created_at) VALUES (1, 'Common', '[0,10)', 20, '2025-10-20 16:27:03.695028');
INSERT INTO internal.point_tiers (tier_id, tier_name, duration_range, base_points, created_at) VALUES (2, 'Uncommon', '[10,30)', 50, '2025-10-20 16:27:03.695028');
INSERT INTO internal.point_tiers (tier_id, tier_name, duration_range, base_points, created_at) VALUES (3, 'Rare', '[30,60)', 100, '2025-10-20 16:27:03.695028');
INSERT INTO internal.point_tiers (tier_id, tier_name, duration_range, base_points, created_at) VALUES (4, 'Epic', '[60,120)', 180, '2025-10-20 16:27:03.695028');
INSERT INTO internal.point_tiers (tier_id, tier_name, duration_range, base_points, created_at) VALUES (5, 'Legendary', '[120,181)', 250, '2025-10-20 16:27:03.695028');



-- SECRET KEYS
INSERT INTO internal.secret_key (key_id, func_name, secret_key) VALUES (2, 'get_roles', '44ca44594fd694873917da773de74bb481f67210fb18821dfd201d50164b86e6');
INSERT INTO internal.secret_key (key_id, func_name, secret_key) VALUES (3, 'get_college_office', '54bfb4a35590cf5b2341a533546fddebd18a3cd43c429b9d9a14571d9df62825');
INSERT INTO internal.secret_key (key_id, func_name, secret_key) VALUES (4, 'get_faculty_ranks', '0456e0f55a5d290c01803dffc2e04624c1f05fb8aeb9cfcfde54feb527da79fa');
INSERT INTO internal.secret_key (key_id, func_name, secret_key) VALUES (5, 'get_users', 'e5be21574e295a5e328bf9b92e9dd7f35f2f91018444a04444d4ad4ed468ed4e');
INSERT INTO internal.secret_key (key_id, func_name, secret_key) VALUES (7, 'get_degrees', '8dca6ac62434b8589c0c3785176797e6b32456996bc1a9777324c281df6024fa');
INSERT INTO internal.secret_key (key_id, func_name, secret_key) VALUES (9, 'get_certification_types', '7454489c4b6876db0bcb0837a09360e8202b4370387aab4e577182f2ca43c720');
INSERT INTO internal.secret_key (key_id, func_name, secret_key) VALUES (11, 'get_main_programs', 'd90d3db2adbf5f7bc9659f7ddbdd0c8db2d23a720073d797f2cc691884b84f56');
INSERT INTO internal.secret_key (key_id, func_name, secret_key) VALUES (12, 'view_all_programs', '49ad0fbed36e9ffdfd7631a20d9555f05af515fbaa6904bc2b70b7ce96f4bf8b');
INSERT INTO internal.secret_key (key_id, func_name, secret_key) VALUES (13, 'view_all_prospectus', '9f2e3b7e8f6dc18f9fedd839c5d7a937444d18d60e6c54a3c6fb78f33f5099be');
INSERT INTO internal.secret_key (key_id, func_name, secret_key) VALUES (14, 'get_semesters', '3df0dae1b1637674a3efba4ab840b0b5a79d12e6aa2344fc7f7601af3af65fa9');
INSERT INTO internal.secret_key (key_id, func_name, secret_key) VALUES (16, 'get_classifications', 'ff4466a7f7eaede92d1d22456ca3a89a28fe24a43bef385b77ea3d711d2e2928');
INSERT INTO internal.secret_key (key_id, func_name, secret_key) VALUES (17, 'get_courses', '3317865fe3ddb3673da487f9baeb0218cc6edabfd014085c7270ff39b4d89cc3');
INSERT INTO internal.secret_key (key_id, func_name, secret_key) VALUES (19, 'view_pps_semesters', 'cb8bc273023fbcb13b4207ad37081e2a5912ccf50be3aefdce57e7def8098f83');
INSERT INTO internal.secret_key (key_id, func_name, secret_key) VALUES (20, 'view_pps_classifications', '265cb4242a99a01aa6407b3456315871e5d614fc711e1405432796886c726995');
INSERT INTO internal.secret_key (key_id, func_name, secret_key) VALUES (21, 'view_pps_courses', 'e657bb044d4ef76403dc8bcbe6b9634c84ea82432ae07ea448c6cf8c3200e8d3');
INSERT INTO internal.secret_key (key_id, func_name, secret_key) VALUES (23, 'get_days', 'e4c59b04188feeca694aa571bbca0819f351eab685e0fa3a323013b8347e0f10');
INSERT INTO internal.secret_key (key_id, func_name, secret_key) VALUES (24, 'get_faculties', 'ae99e32dd8c274019233cf47b68ba7ba98c3f2a7a3c3e38b13610f09150c972e');
INSERT INTO internal.secret_key (key_id, func_name, secret_key) VALUES (25, 'view_all_scheduling', '00058457ae26b2064f1932c4f3568aeb110926d306ccd3f35fafdc59f50e0149');
INSERT INTO internal.secret_key (key_id, func_name, secret_key) VALUES (22, 'select_prospectus', '8bf6aa583069f13b44b4a558312e485a753763485926b7b3d7e0a2e1c46fb07b');
INSERT INTO internal.secret_key (key_id, func_name, secret_key) VALUES (26, 'get_rooms', '9ba6b6852322ae9b9b33aef670e972f706b9a55148e9e31c1e5cdb96112b0dc3');
INSERT INTO internal.secret_key (key_id, func_name, secret_key) VALUES (27, 'view_enrolled_students', 'c43408b44307825aea8898a04dad68f6d746cd254a11e0e26747e1a3f8446f96');
INSERT INTO internal.secret_key (key_id, func_name, secret_key) VALUES (28, 'my_assigned_courses', '25ceb48807441f6506dd6be264ef69e51e4695958a3addaa33902f1d61041ef2');
INSERT INTO internal.secret_key (key_id, func_name, secret_key) VALUES (31, 'get_assessment_types', 'd2468a9908a6350a8c5368735534e759f0e78e6fed3e60d4e901cbdad5454af6');
INSERT INTO internal.secret_key (key_id, func_name, secret_key) VALUES (32, 'get_lessons', 'a3591b30e92b65f098835070f51d9f1a160dd5ec5895fc97513f1cb4253cb78f');
INSERT INTO internal.secret_key (key_id, func_name, secret_key) VALUES (33, 'get_structured_assessments', '99ae31bd16b93a76f2845e307f8c40c978ad67066b723a690ed912db24b71b23');
INSERT INTO internal.secret_key (key_id, func_name, secret_key) VALUES (34, 'get_answer_types', 'da718f5afc358e6e3b89b018b69e04957f56d3909e25fd572f52e74eaffc7d2d');
INSERT INTO internal.secret_key (key_id, func_name, secret_key) VALUES (35, 'my_learning_programs', 'b45a49b0feea13afcb73207739c5a6f3f62e8fc9beb60f217aeadd56bcd3cda1');
INSERT INTO internal.secret_key (key_id, func_name, secret_key) VALUES (36, 'my_courses', '5ff66e4b2c4fa983223451437133536b2cd9af2a713fe7253394450ce9d1bef1');
INSERT INTO internal.secret_key (key_id, func_name, secret_key) VALUES (37, 'view_course', 'a82f25a1d16d4c7f78a41777903eec70cab38839e432bce763e6995ba5393cc8');
INSERT INTO internal.secret_key (key_id, func_name, secret_key) VALUES (38, 'view_faculty_profile', 'f3a413732cb69c6d970729ec97c4cbf1ef8b5d2a43cb2188c3c8e05e0b944210');
INSERT INTO internal.secret_key (key_id, func_name, secret_key) VALUES (39, 'view_assignment', '875bc085c7af2f42d652dafbc73625682fad46f56adaa46a8fece86d22e65fab');
INSERT INTO internal.secret_key (key_id, func_name, secret_key) VALUES (40, 'attempt_exam', '5f8742e1b438df15229386533403a56894a3c3bbaec44b97706c54b71aeba5c0');
INSERT INTO internal.secret_key (key_id, func_name, secret_key) VALUES (41, 'view_exam', '208c4e265a9a78591e7bb7e9c8e490fe1c70a8375de8d85cebc3ab4d08b2c6da');
INSERT INTO internal.secret_key (key_id, func_name, secret_key) VALUES (42, 'fetch_questions', 'd266688e78fb49dae8e9fa85a12ef3d95fdb185c9ccf508feccb16fc6efd43a4');
INSERT INTO internal.secret_key (key_id, func_name, secret_key) VALUES (43, 'get_prospectus_data', 'd79e21d6feaa8986053bf782fcba45a1a1c6aa0e4822f9c81652abdc1be36ede');
INSERT INTO internal.secret_key (key_id, func_name, secret_key) VALUES (44, 'get_phase1_data', 'bb85ad38142b68a0e071af0391ea99a8c7b3e35d801c0ac8da2a5b50e39e092f');
INSERT INTO internal.secret_key (key_id, func_name, secret_key) VALUES (45, 'get_phase2_data', '91f4082d57318cbf768def81bfef02194262b79f24262b78d56489fa71c8c3be');
INSERT INTO internal.secret_key (key_id, func_name, secret_key) VALUES (46, 'get_phase3_data', '98675eb782616ba3e0437549086ae6bb5b1362b2bab92bcbf70ca2241e065b57');
INSERT INTO internal.secret_key (key_id, func_name, secret_key) VALUES (47, 'get2clone_media', '778cd6acb6ea0a55749564c3bc263e3c3c1f8844641d44bde356942ea80fb200');
INSERT INTO internal.secret_key (key_id, func_name, secret_key) VALUES (48, 'get_phase4_data', '47fb8111f5cb4db804d078e0fc784706642e3a73499e455531ccc33780b0d387');
INSERT INTO internal.secret_key (key_id, func_name, secret_key) VALUES (50, 'get_phase5_data', 'b84ba8ef090f381f6cce843bf9f8f2a64d16608729489bf7d06a6f8c004b3a5e');
INSERT INTO internal.secret_key (key_id, func_name, secret_key) VALUES (52, 'phase1_attempt_remove_lesson', '7200bfae196dda48817135603a2199dac3c27981b9bf58edac1f8a57c73018c8');
INSERT INTO internal.secret_key (key_id, func_name, secret_key) VALUES (53, 'view_enrolled_students2', 'c9737d2beef5140e16f7c39c8726cba7a0f2ddb8d5b56323ee61249b07a9a466');
INSERT INTO internal.secret_key (key_id, func_name, secret_key) VALUES (54, 'phase5_attempt_remove_test', '12a21fba8690737b0073f3577104390f04285f1e2f842df5e979db456249c2e0');
INSERT INTO internal.secret_key (key_id, func_name, secret_key) VALUES (55, 'my_notifications', '326a0f0a726d0accfec188cf1f3118c580b921fc577e96dda7cd0d0f394509aa');
INSERT INTO internal.secret_key (key_id, func_name, secret_key) VALUES (57, 'view_student_assessments', '0c526061b7f9212d4b1c0b0e0f96345e7d3f52d52e01002a34e154825c10df06');
INSERT INTO internal.secret_key (key_id, func_name, secret_key) VALUES (58, 'view_video_progress', 'c02978fb5dcd0cf7d96e2c27fe00da95e8951f5989e49741660b4bfd89af9880');
INSERT INTO internal.secret_key (key_id, func_name, secret_key) VALUES (59, 'view_assignment_progress', '23c3f7b8b98aa1bff4923ca7b093f9ac7b64d88a350a56c1e9abd297977be71b');
INSERT INTO internal.secret_key (key_id, func_name, secret_key) VALUES (60, 'view_student_assignment', '6fb812b69cd94d3b5fca3b295d2f5f99da76528996ed8f6b75ce83ac4e6794ac');
INSERT INTO internal.secret_key (key_id, func_name, secret_key) VALUES (61, 'view_exam_progress', '475ea9f3a7af30d1c5f8abf6b8363607b4570889414697dff4dd9095b95dae81');
INSERT INTO internal.secret_key (key_id, func_name, secret_key) VALUES (62, 'view_student_attempts', '911841fbff943c643da1731d525433688c2d0e3d1ae28f16f9881d628d156428');
INSERT INTO internal.secret_key (key_id, func_name, secret_key) VALUES (63, 'view_students_exam_result', '9352b9d6748a7d323761770a27c2e2d877579741740644a43d1de0311ebccd7d');
INSERT INTO internal.secret_key (key_id, func_name, secret_key) VALUES (64, 'view_leaderboards', 'a6776a8299fe7fe0fbd6bd2faf82e5ff978bb34a5ee93ea885cc77f49786cc42');
INSERT INTO internal.secret_key (key_id, func_name, secret_key) VALUES (65, 'explore_programs', '729360e15771cfb93581dd68c079ca40805b542c92c0e80b12687399a09faa2a');
INSERT INTO internal.secret_key (key_id, func_name, secret_key) VALUES (66, 'view_program', 'a2be9300b0cce112b5d6ea1c14d7e9bf0166e17d08c746112a521beeb05586c7');
INSERT INTO internal.secret_key (key_id, func_name, secret_key) VALUES (67, 'recently_added_courses', '7e29df59645110a696d76f5c06ab0746d988f69a1aed78918268bf66382054e2');
INSERT INTO internal.secret_key (key_id, func_name, secret_key) VALUES (68, 'get_last_course_interaction', 'daad145d0f5fc23be69e1b66539f2e3dc0511755285d0bb74491bddb494f1cde');
INSERT INTO internal.secret_key (key_id, func_name, secret_key) VALUES (70, 'get_grade', '6c05173f172490e9949017d34312cdee8a857048f8fed4380607f8dc0b5a59d8');
INSERT INTO internal.secret_key (key_id, func_name, secret_key) VALUES (71, 'get_progress', '0450f36fab284c9b87611a613a907a14a4d5fa27677a6414519892b956c4ec13');
INSERT INTO internal.secret_key (key_id, func_name, secret_key) VALUES (72, 'get_years', '35fb39168389b819e217de2f0e3989e945cf18c4c6bd072f252d689c2f515831');
INSERT INTO internal.secret_key (key_id, func_name, secret_key) VALUES (73, 'update_schedule', '3eeedafa457739f28b20027d678eb04ad5f7f5df62f792ea0ea4bf384707730a');
INSERT INTO internal.secret_key (key_id, func_name, secret_key) VALUES (75, 'select_program', '1cf48d3caa0111d5540c080f955cf1ae5c7e4c9341085bf70369432e76b971d1');
INSERT INTO internal.secret_key (key_id, func_name, secret_key) VALUES (76, 'create_schedule', '29fdeffaf927332c1ca914dfd9ac7679cad9fa384061ad037649b03ce8181817');
INSERT INTO internal.secret_key (key_id, func_name, secret_key) VALUES (77, 'view_compre_ready_students', '109370de3c379e30a916430479c8eff6373901b094f8a5d7031c6a68e12e5862');
INSERT INTO internal.secret_key (key_id, func_name, secret_key) VALUES (78, 'claim_points', '31fd24cd15d7ed342bce0cdde282a5688b81d4c857a1166f20bdb0490ea22afd');

