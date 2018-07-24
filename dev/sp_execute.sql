TRUNCATE `audit_dev`.`audit`;
TRUNCATE `audit_dev`.`audit_meta`;


CALL `audit_dev`.`sp_generate_audit`('audit_dev', 'test_data', @script, @errors);
SELECT @script, @errors;


CALL `audit_dev`.`sp_generate_audit`('audit_dev', 'multi_key', @script, @errors);
SELECT @script, @errors;


CALL `audit_dev`.`sp_generate_batch_audit`('audit_dev', 'test_data,multi_key', @script, @errors);
SELECT @script, @errors;


CALL `audit_dev`.`sp_generate_remove_audit`('audit_dev', 'test_data', @script);
SELECT @script;

CALL `audit_dev`.`sp_generate_batch_remove_audit`('audit_dev', 'test_data,multi_key', @script);
SELECT @script;




















