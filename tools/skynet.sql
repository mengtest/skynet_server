
SET FOREIGN_KEY_CHECKS = 0;

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
  `name` varchar(64) NOT NULL COMMENT '角色名称',
  `sex` tinyint(1) unsigned NOT NULL COMMENT '性别',
  `data` mediumtext NOT NULL COMMENT '数据',
  PRIMARY KEY (`uuid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
