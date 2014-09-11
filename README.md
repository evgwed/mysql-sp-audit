## MySQL Audit (mysql-sp-audit)
Using trigger based stored procedure to create audit table. It follows the word press meta data approach to store the changes, so all the data is stores in just two centralized tables.

---
## MySQL Components Requirement 
I put the requirement here so in case you want to run this in a lower version of mysql, you'll know where to change.

* v5.x         Trigger support
* v5.0.10   INFORMATION_SCHEMA.TRIGGERS
* v5.0.32   DROP ... IF EXISTS

---
## Features
* Enable/Disable using a stored procedure
* Allow the table's schema to change, just need to rerun the stored procedure
  * Keep deleted columns data
* All values are stored as LONGTEXT therefore no blob support
* Allow audit table up to 2 keys
  * There will be a branch in the future to support 3 keys
  * Possibly the number of keys can be specify in the setup script :)

## Stored Procedures
* zsp_generate_audit( @audit_schema_name, @audit_table_name )
* zsp_generate_batch_audit ( @audit_schema_name, @audit_tables )
      * Put comma separated list of tables name
* zsp_generate_remove_audit( @audit_schema_name, @audit_table_name )

---
## Conflict
* If you already have a trigger on your table, this is how you resolve it:
	 * Copy the code for your trigger, then remove it 
	 * Run zsp_generate_audit()
	 * Edit the trigger and add the code you copied
	 * It is a bit hacky but less work for me :)

## Table Schema
All names are prefixed with "z" to stay out of the way of your important stuff

#### Audit Table: zaudit

|audit_id  	|user |table_name |pk1  	|pk2  	|action  	|time-stamp  |
|---	|---	|---	|---	|---	|---	|---	|
|Auto-increment, one number for each change  	|User that made the change |The table name |First primary key  	|Second primary key  	|Insert, update or delete  	|Time the changed occurred  	|


#### Informations
```SQL
#Get all the columns detail
SELECT * FROM INFORMATION_SCHEMA.COLUMNS

#Get trigger info
SELECT * FROM INFORMATION_SCHEMA.TRIGGERS

#Combine multiple columns into a string
SELECT 
    GROUP_CONCAT(COLUMN_NAME ORDER BY ORDINAL_POSITION ASC SEPARATOR ', ')
FROM
    INFORMATION_SCHEMA.COLUMNS
WHERE
    TABLE_NAME = 'test_data'
	
```



#### Meta Table: zaudit_meta

|audit_meta_id  	|audit_id  	|col_name  	|old_value  	|new_value  	|
|---	|---	|---	|---	|---	|
|Auto-increment, one row for one value  	|Id from audit table  	|Name of the column  	|Old value  	|New value  	|

## Generated Views

#### View: zvw_audit_\<table_name\>_meta

|audit_id  	|audit_meta_id  	|user |pk1  	|pk2  	|action  	|col_name  	|old_value  	|new_value |time-stamp |
|---	|---	|---	|---	|---	|---	|---	|---	|---	|---	|
|Audit id  	|Meta id  	|User name/ user id |pk1  	|pk2  	|Insert, update or delete  	|Column name |Old value  	|New value |Date time  	|

#### View: zvw_audit_\<table_name\>

|audit_id  	|user |pk1  	|pk2  	|action  	|time-stamp |col1_old  	|col1_new  	|col2_old  	|col2_new|
|---	|---	|---	|---	|---	|---	|---	|---	|---	|---	|
|Audit id  	|User name/id |pk1  	|pk2  	|Insert, update, delete  	|Date time  	|Col1 old value  	|Col1 new value  	|Col2 old value  	|Col2 new value  	|


