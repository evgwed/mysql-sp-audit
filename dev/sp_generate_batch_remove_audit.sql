-- --------------------------------------------------------------------
-- MySQL Audit Trigger
-- Copyright (c) 2014 Du T. Dang. MIT License
-- https://github.com/hotmit/mysql-sp-audit
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