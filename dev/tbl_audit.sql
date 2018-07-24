-- --------------------------------------------------------------------
-- MySQL Audit Trigger
-- Copyright (c) 2014 Du T. Dang. MIT License
-- https://github.com/hotmit/mysql-sp-audit
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
