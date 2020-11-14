
SET FOREIGN_KEY_CHECKS = 0;

-- 测试表
CREATE TABLE IF NOT EXISTS `tbl_test` (
  `tinyint` TINYINT,
  `smallint` SMALLINT,
  `mediumint` MEDIUMINT,
  `int` INT,
  `bigint` BIGINT,
  `float` FLOAT,
  `double` DOUBLE,
  `decimal` DECIMAL,
  `date` DATE,
  `time` TIME,
  `year` YEAR,
  `datetime` DATETIME,
  `timestamp` TIMESTAMP,
  `char` CHAR,
  `varchar` VARCHAR(10),
  `tinyblob` TINYBLOB,
  `tinytext` TINYTEXT,
  `blob` BLOB,
  `text` TEXT,
  `mediumblob` MEDIUMBLOB,
  `mediumtext` MEDIUMTEXT,
  `longblob` LONGBLOB,
  `longtext` LONGTEXT,
  `binary` binary,
  `bit` bit
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- 账号表
CREATE TABLE IF NOT EXISTS `tbl_account` (
  `account` varchar(64) NOT NULL COMMENT '账号',
  `region` int(16) NOT NULL COMMENT '大区',
  `create_time` DATETIME NOT NULL COMMENT '创建时间',
  `login_time` DATETIME NOT NULL COMMENT '登陆时间',
  PRIMARY KEY (`account`, `region`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- 角色表
CREATE TABLE IF NOT EXISTS `tbl_role` (
  `uuid` bigint(64)  unsigned NOT NULL COMMENT '唯一id',
  `account` varchar(64) NOT NULL COMMENT '账号',
  `region` int(16) NOT NULL COMMENT '大区',
  `create_time` DATETIME NOT NULL COMMENT '创建时间',
  `login_time` DATETIME NOT NULL COMMENT '登陆时间',
  `data` mediumtext NOT NULL COMMENT '数据',
  PRIMARY KEY (`uuid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
