
-- -------------------------------------------------------------------- 
-- MySQL Audit Trigger 
-- Copyright (c) 2014 Du T. Dang. MIT License 
-- https://github.com/hotmit/mysql-sp-audit 
-- Version: v1.0
-- Build Date: Tue, 24 Jul 2018 10:55:29 GMT
-- --------------------------------------------------------------------

-- --------------------------------------------------------------------
-- MySQL Audit Trigger
-- --------------------------------------------------------------------

DROP TABLE IF EXISTS `audit`;

CREATE TABLE `audit` (
  `audit_id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `user` varchar(255) DEFAULT NULL,
  `table_name` varchar(255) DEFAULT NULL,
  `pk1` varchar(255) DEFAULT NULL,
  `pk2` varchar(255) DEFAULT NULL,
  `action` varchar(6) DEFAULT NULL COMMENT 'Values: insert|update|delete',
  `timestamp` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`audit_id`),
  KEY `pk_index` (`table_name`,`pk1`,`pk2`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `audit_meta`;

CREATE TABLE `audit_meta` (
  `audit_meta_id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `audit_id` bigint(20) unsigned NOT NULL,
  `col_name` varchar(255) NOT NULL,
  `old_value` longtext DEFAULT NULL,
  `new_value` longtext DEFAULT NULL,
  PRIMARY KEY (`audit_meta_id`),
  KEY `audit_meta_index` (`audit_id`,`col_name`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8;

-- --------------------------------------------------------------------
-- MySQL Audit Trigger
-- --------------------------------------------------------------------
DROP PROCEDURE IF EXISTS `sp_generate_audit`;

CREATE PROCEDURE `sp_generate_audit` (IN audit_schema_name VARCHAR(255), IN audit_table_name VARCHAR(255), OUT script LONGTEXT, OUT errors LONGTEXT)
main_block: BEGIN

    DECLARE trg_insert, trg_update, trg_delete, out_errors LONGTEXT;
    DECLARE stmt, header, insertHeader LONGTEXT;
    DECLARE at_id1, at_id2 LONGTEXT;
    DECLARE c INTEGER;

    -- Default max length of GROUP_CONCAT IS 1024
    SET SESSION group_concat_max_len = 100000;

    SET out_errors := '';

    -- Check to see if the specified table exists
    SET c := (SELECT COUNT(*) FROM information_schema.tables
            WHERE BINARY TABLE_SCHEMA = BINARY audit_schema_name
                AND BINARY table_name = BINARY audit_table_name);
    IF c <> 1 THEN
        SET out_errors := CONCAT( out_errors, '\n', 'The table you specified `', audit_schema_name, '`.`', audit_table_name, '` does not exists.' );
        LEAVE main_block;
    END IF;


    -- Check audit and meta table exists
    SET c := (SELECT COUNT(*) FROM information_schema.tables
            WHERE BINARY TABLE_SCHEMA = BINARY audit_schema_name
                AND (BINARY table_name = BINARY 'audit' OR BINARY table_name = BINARY 'audit_meta') );
    IF c <> 2 THEN
        SET out_errors := CONCAT( out_errors, '\n', 'Audit table structure do not exists, please check or run the audit setup script again.' );
    END IF;


    -- Check triggers exists
    SET c := ( SELECT GROUP_CONCAT( TRIGGER_NAME SEPARATOR ', ') FROM information_schema.triggers
            WHERE BINARY EVENT_OBJECT_SCHEMA = BINARY audit_schema_name
                AND BINARY EVENT_OBJECT_TABLE = BINARY audit_table_name
                AND BINARY ACTION_TIMING = BINARY 'AFTER' AND BINARY TRIGGER_NAME NOT LIKE BINARY CONCAT('', audit_table_name, '_%') GROUP BY EVENT_OBJECT_TABLE );
    IF c IS NOT NULL AND LENGTH(c) > 0 THEN
        SET out_errors := CONCAT( out_errors, '\n', 'MySQL 5 only supports one trigger per insert/update/delete action. Currently there are these triggers (', c, ') already assigned to `', audit_schema_name, '`.`', audit_table_name, '`. You must remove them before the audit trigger can be applied' );
    END IF;

    -- Get the first primary key
    SET at_id1 := (SELECT COLUMN_NAME FROM information_schema.columns
            WHERE BINARY TABLE_SCHEMA = BINARY audit_schema_name
                AND BINARY table_name = BINARY audit_table_name
            AND column_key = 'PRI' LIMIT 1);

    -- Get the second primary key
    SET at_id2 := (SELECT COLUMN_NAME FROM information_schema.columns
            WHERE BINARY TABLE_SCHEMA = BINARY audit_schema_name
                AND BINARY table_name = BINARY audit_table_name
            AND column_key = 'PRI' LIMIT 1,1);

    -- Check at least one id exists
    IF at_id1 IS NULL AND at_id2 IS NULL THEN
        SET out_errors := CONCAT( out_errors, '\n', 'The table you specified `', audit_schema_name, '`.`', audit_table_name, '` does not have any primary key.' );
    END IF;



    SET header := CONCAT(
        '-- --------------------------------------------------------------------\n',
        '-- MySQL Audit Trigger\n',
        '',
        '',
        '-- --------------------------------------------------------------------\n\n'
    );


    SET trg_insert := CONCAT( 'DROP TRIGGER IF EXISTS `', audit_schema_name, '`.`', audit_table_name, '_AINS`;\n',
                        'CREATE TRIGGER `', audit_schema_name, '`.`', audit_table_name, '_AINS` AFTER INSERT ON `', audit_schema_name, '`.`', audit_table_name, '` FOR EACH ROW \nBEGIN\n', header );
    SET trg_update := CONCAT( 'DROP TRIGGER IF EXISTS `', audit_schema_name, '`.`', audit_table_name, '_AUPD`;\n',
                        'CREATE TRIGGER `', audit_schema_name, '`.`', audit_table_name, '_AUPD` AFTER UPDATE ON `', audit_schema_name, '`.`', audit_table_name, '` FOR EACH ROW \nBEGIN\n', header );
    SET trg_delete := CONCAT( 'DROP TRIGGER IF EXISTS `', audit_schema_name, '`.`', audit_table_name, '_ADEL`;\n',
                        'CREATE TRIGGER `', audit_schema_name, '`.`', audit_table_name, '_ADEL` AFTER DELETE ON `', audit_schema_name, '`.`', audit_table_name, '` FOR EACH ROW \nBEGIN\n', header );

    SET stmt := 'DECLARE audit_last_inserted_id BIGINT(20);\n\n';
    SET trg_insert := CONCAT( trg_insert, stmt );
    SET trg_update := CONCAT( trg_update, stmt );
    SET trg_delete := CONCAT( trg_delete, stmt );


    -- ----------------------------------------------------------
    -- [ Create Insert Statement Into Audit & Audit Meta Tables ]
    -- ----------------------------------------------------------

    SET stmt := CONCAT( 'INSERT IGNORE INTO `', audit_schema_name, '`.audit (user, table_name, pk1, ', CASE WHEN at_id2 IS NULL THEN '' ELSE 'pk2, ' END , 'action)  VALUE ( IFNULL( @audit_user, USER() ), ',
        '''', audit_table_name, ''', ', 'NEW.`', at_id1, '`, ', IFNULL( CONCAT('NEW.`', at_id2, '`, ') , '') );

    SET trg_insert := CONCAT( trg_insert, stmt, '''INSERT''); \n\n');

    SET stmt := CONCAT( 'INSERT IGNORE INTO `', audit_schema_name, '`.audit (user, table_name, pk1, ', CASE WHEN at_id2 IS NULL THEN '' ELSE 'pk2, ' END , 'action)  VALUE ( IFNULL( @audit_user, USER() ), ',
        '''', audit_table_name, ''', ', 'OLD.`', at_id1, '`, ', IFNULL( CONCAT('OLD.`', at_id2, '`, ') , '') );

    SET trg_update := CONCAT( trg_update, stmt, '''UPDATE''); \n\n' );
    SET trg_delete := CONCAT( trg_delete, stmt, '''DELETE''); \n\n' );


    SET stmt := 'SET audit_last_inserted_id = LAST_INSERT_ID();\n';
    SET trg_insert := CONCAT( trg_insert, stmt );
    SET trg_update := CONCAT( trg_update, stmt );
    SET trg_delete := CONCAT( trg_delete, stmt );

    SET insertHeader := CONCAT( 'INSERT IGNORE INTO `', audit_schema_name, '`.audit_meta (audit_id, col_name, old_value, new_value) VALUES \n' );
    -- SET trg_insert := CONCAT( trg_insert, '\n', insertHeader );
    -- SET trg_update := CONCAT( trg_update, '\n', stmt );
    SET trg_delete := CONCAT( trg_delete, '\n', insertHeader );

    SET stmt := ( SELECT GROUP_CONCAT('IF ISNULL(NEW.`', COLUMN_NAME, '`) = 0 THEN \n',
                                      '    ', insertHeader,
                                      '    (audit_last_inserted_id, ''', COLUMN_NAME, ''', NULL, ',
                        CASE WHEN INSTR( '|binary|varbinary|tinyblob|blob|mediumblob|longblob|', LOWER(DATA_TYPE) ) <> 0 THEN
                            '''[UNSUPPORTED BINARY DATATYPE]'''
                        ELSE
                            CONCAT('NEW.`', COLUMN_NAME, '`')
                        END,
                        ');\n',
                        'END IF;\n'
                    SEPARATOR '\n')
                    FROM information_schema.columns
                        WHERE BINARY TABLE_SCHEMA = BINARY audit_schema_name
                            AND BINARY TABLE_NAME = BINARY audit_table_name );

    SET stmt := CONCAT( TRIM( TRAILING ',' FROM stmt ), '\nEND;' );
    SET trg_insert := CONCAT( trg_insert, stmt );



    SET stmt := ( SELECT GROUP_CONCAT('IF (OLD.`', COLUMN_NAME, '` != NEW.`', COLUMN_NAME, '`) THEN \n',
                                      '    ', insertHeader,
                                      '    (audit_last_inserted_id, ''', COLUMN_NAME, ''', ',
                        CASE WHEN INSTR( '|binary|varbinary|tinyblob|blob|mediumblob|longblob|', LOWER(DATA_TYPE) ) <> 0 THEN
                            '''[SAME]'''
                        ELSE
                            CONCAT('OLD.`', COLUMN_NAME, '`')
                        END,
                        ', ',
                        CASE WHEN INSTR( '|binary|varbinary|tinyblob|blob|mediumblob|longblob|', LOWER(DATA_TYPE) ) <> 0 THEN
                            CONCAT('CASE WHEN BINARY OLD.`', COLUMN_NAME, '` <=> BINARY NEW.`', COLUMN_NAME, '` THEN ''[SAME]'' ELSE ''[CHANGED]'' END')
                        ELSE
                            CONCAT('NEW.`', COLUMN_NAME, '`')
                        END,
                        ');\n',
                        'END IF;\n'
                        SEPARATOR '\n')
                    FROM information_schema.columns
                        WHERE BINARY TABLE_SCHEMA = BINARY audit_schema_name
                            AND BINARY TABLE_NAME = BINARY audit_table_name );

    SET stmt := CONCAT( TRIM( TRAILING ',' FROM stmt ), '\nEND;' );
    SET trg_update := CONCAT( trg_update, stmt );



    SET stmt := ( SELECT GROUP_CONCAT('   (audit_last_inserted_id, ''', COLUMN_NAME, ''', ',
                        CASE WHEN INSTR( '|binary|varbinary|tinyblob|blob|mediumblob|longblob|', LOWER(DATA_TYPE) ) <> 0 THEN
                            '''[UNSUPPORTED BINARY DATATYPE]'''
                        ELSE
                            CONCAT('OLD.`', COLUMN_NAME, '`')
                        END,
                        ', NULL ),'
                    SEPARATOR '\n')
                    FROM information_schema.columns
                        WHERE BINARY TABLE_SCHEMA = BINARY audit_schema_name
                            AND BINARY TABLE_NAME = BINARY audit_table_name );


    SET stmt := CONCAT( TRIM( TRAILING ',' FROM stmt ), ';\n\nEND;' );
    SET trg_delete := CONCAT( trg_delete, stmt );


    SET stmt = CONCAT(
        '-- ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^\n',
        '-- --------------------------------------------------------------------\n',
        '-- Audit Script For `',audit_schema_name, '`.`', audit_table_name, '`\n',
        '-- Date Generated: ', NOW(), '\n',
        '-- Generated By: ', CURRENT_USER(), '\n',
        '-- BEGIN\n',
        '-- --------------------------------------------------------------------\n\n'
        '\n\n-- [ `',audit_schema_name, '`.`', audit_table_name, '` After Insert Trigger Code ]\n',
        '-- -----------------------------------------------------------\n',
        trg_insert,
        '\n\n-- [ `',audit_schema_name, '`.`', audit_table_name, '` After Update Trigger Code ]\n',
        '-- -----------------------------------------------------------\n',
        trg_update,
        '\n\n-- [ `',audit_schema_name, '`.`', audit_table_name, '` After Delete Trigger Code ]\n',
        '-- -----------------------------------------------------------\n',
        trg_delete,
        '\n\n',
        '-- --------------------------------------------------------------------\n',
        '-- END\n',
        '-- Audit Script For `',audit_schema_name, '`.`', audit_table_name, '`\n',
        '-- --------------------------------------------------------------------\n\n'
        );

    SET script := stmt;
    SET errors := out_errors;
END;

-- --------------------------------------------------------------------
-- MySQL Audit Trigger
-- --------------------------------------------------------------------

DROP PROCEDURE IF EXISTS `sp_generate_batch_audit`;

CREATE PROCEDURE `sp_generate_batch_audit` (IN audit_schema_name VARCHAR(255), IN audit_table_names VARCHAR(255), OUT out_script LONGTEXT, OUT out_error_msgs LONGTEXT)
main_block: BEGIN

    DECLARE s, e, scripts, error_msgs LONGTEXT;
    DECLARE audit_table_name VARCHAR(255);
    DECLARE done INT DEFAULT FALSE;
    DECLARE cursor_table_list CURSOR FOR SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES
        WHERE BINARY TABLE_TYPE = BINARY 'BASE TABLE'
            AND BINARY TABLE_SCHEMA = BINARY audit_schema_name
            AND LOCATE( BINARY CONCAT(TABLE_NAME, ','), BINARY CONCAT(audit_table_names, ',') ) > 0;

    DECLARE CONTINUE HANDLER
        FOR NOT FOUND SET done = TRUE;

    SET scripts := '';
    SET error_msgs := '';

    OPEN cursor_table_list;

    cur_loop: LOOP
        FETCH cursor_table_list INTO audit_table_name;

        IF done THEN
            LEAVE cur_loop;
        END IF;

        CALL sp_generate_audit(audit_schema_name, audit_table_name, s, e);

        SET scripts := CONCAT( scripts, '\n\n', IFNULL(s, '') );
        SET error_msgs := CONCAT( error_msgs, '\n\n', IFNULL(e, '') );

    END LOOP;

    CLOSE cursor_table_list;

    SET out_script := scripts;
    SET out_error_msgs := error_msgs;
END;

-- --------------------------------------------------------------------
-- MySQL Audit Trigger
-- --------------------------------------------------------------------
DROP PROCEDURE IF EXISTS `sp_generate_remove_audit`;

CREATE PROCEDURE `sp_generate_remove_audit` (IN audit_schema_name VARCHAR(255), IN audit_table_name VARCHAR(255), OUT script LONGTEXT)
main_block: BEGIN

    SET script := CONCAT(
        '-- ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^\n',
        '-- --------------------------------------------------------------------\n',
        '-- Audit Removal Script For `',audit_schema_name, '`.`', audit_table_name, '` \n',
        '-- Date Generated: ', NOW(), '\n',
        '-- Generated By: ', CURRENT_USER(), '\n',
        '-- BEGIN\n',
        '-- --------------------------------------------------------------------\n\n',
        'DROP TRIGGER IF EXISTS `', audit_schema_name, '`.`', audit_table_name, '_AINS`;\n',
        'DROP TRIGGER IF EXISTS `', audit_schema_name, '`.`', audit_table_name, '_AUPD`;\n',
        'DROP TRIGGER IF EXISTS `', audit_schema_name, '`.`', audit_table_name, '_ADEL`;\n',

        '\n\n',
        '-- --------------------------------------------------------------------\n',
        '-- END\n',
        '-- Audit Removal Script For `',audit_schema_name, '`.`', audit_table_name, '`\n',
        '-- --------------------------------------------------------------------\n\n'
    );

END;

-- --------------------------------------------------------------------
-- MySQL Audit Trigger
-- --------------------------------------------------------------------

DROP PROCEDURE IF EXISTS `sp_generate_batch_remove_audit`;

CREATE PROCEDURE `sp_generate_batch_remove_audit` (IN audit_schema_name VARCHAR(255), IN audit_table_names VARCHAR(255), OUT out_script LONGTEXT)
main_block: BEGIN

    DECLARE s, scripts LONGTEXT;
    DECLARE audit_table_name VARCHAR(255);
    DECLARE done INT DEFAULT FALSE;
    DECLARE cursor_table_list CURSOR FOR SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES
        WHERE BINARY TABLE_TYPE = BINARY 'BASE TABLE'
            AND BINARY TABLE_SCHEMA = BINARY audit_schema_name
            AND LOCATE( BINARY CONCAT(TABLE_NAME, ','), BINARY CONCAT(audit_table_names, ',') ) > 0;

    DECLARE CONTINUE HANDLER
        FOR NOT FOUND SET done = TRUE;

    SET scripts := '';

    OPEN cursor_table_list;

    cur_loop: LOOP
        FETCH cursor_table_list INTO audit_table_name;

        IF done THEN
            LEAVE cur_loop;
        END IF;

        CALL sp_generate_remove_audit(audit_schema_name, audit_table_name, s);

        SET scripts := CONCAT( scripts, '\n\n', IFNULL(s, '') );

    END LOOP;

    CLOSE cursor_table_list;

    SET out_script := scripts;
END;