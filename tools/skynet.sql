
SET FOREIGN_KEY_CHECKS = 0;

-- 账号表
CREATE TABLE IF NOT EXISTS `tbl_account` (
  `uid` varchar(64) NOT NULL COMMENT '用户id',
  `account` varchar(64) NOT NULL COMMENT '账号',
  `region` int(16) NOT NULL COMMENT '大区',
  `create_time` DATETIME NOT NULL COMMENT '创建时间',
  `login_time` DATETIME NOT NULL COMMENT '登陆时间',
  PRIMARY KEY (`uid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- 角色表
CREATE TABLE IF NOT EXISTS `tbl_role` (
  `uid` varchar(64) NOT NULL COMMENT '用户id',
  `uuid` bigint(64)  unsigned NOT NULL COMMENT '唯一id',
  `name` varchar(64) NOT NULL COMMENT '角色名称',
  `sex` tinyint(1) unsigned NOT NULL COMMENT '性别',
  `job` tinyint(4) unsigned NOT NULL COMMENT '职业',
  `level` int(8) unsigned NOT NULL COMMENT '等级',
  `create_time` DATETIME NOT NULL COMMENT '创建时间',
  `login_time` DATETIME NOT NULL COMMENT '登陆时间',
  `map_id` int(32) unsigned NOT NULL COMMENT '所在地图',
  `x` float(32,0) NOT NULL COMMENT '坐标x',
  `y` float(32,0) NOT NULL COMMENT '坐标y',
  `z` float(32,0) NOT NULL COMMENT '坐标z',
  `data` mediumtext NOT NULL COMMENT '数据',
  PRIMARY KEY (`uuid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
