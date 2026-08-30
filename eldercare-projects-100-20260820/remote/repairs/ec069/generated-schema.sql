-- Deployment-generated schema for ec069 (BiSHeHelper/springboot553 lineage).
-- The upstream repository contains entity classes but no database SQL.
-- Columns below are derived from src/main/java/com/entity/*Entity.java.

CREATE TABLE IF NOT EXISTS `chat` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `userid` bigint DEFAULT NULL,
  `adminid` bigint DEFAULT NULL,
  `ask` longtext,
  `reply` longtext,
  `isreply` int DEFAULT 0,
  `addtime` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `config` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `name` varchar(255) DEFAULT NULL,
  `value` longtext,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `feiyongshoujiao` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `jiaofeidanhao` varchar(255) DEFAULT NULL,
  `jiaofeimingcheng` varchar(255) DEFAULT NULL,
  `jiaofeileixing` varchar(255) DEFAULT NULL,
  `jiaofeijine` int DEFAULT NULL,
  `jiaofeineirong` longtext,
  `xinxibeizhu` longtext,
  `laorenxingming` varchar(255) DEFAULT NULL,
  `xingbie` varchar(255) DEFAULT NULL,
  `lianxidianhua` varchar(255) DEFAULT NULL,
  `ispay` varchar(255) DEFAULT '未支付',
  `addtime` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `forum` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `title` varchar(255) DEFAULT NULL,
  `content` longtext,
  `parentid` bigint DEFAULT NULL,
  `userid` bigint DEFAULT NULL,
  `username` varchar(255) DEFAULT NULL,
  `isdone` varchar(255) DEFAULT NULL,
  `addtime` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `jiankangxinxi` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `laorenxingming` varchar(255) DEFAULT NULL,
  `xingbie` varchar(255) DEFAULT NULL,
  `nianling` int DEFAULT NULL,
  `huanbingshi` longtext,
  `shengao` varchar(255) DEFAULT NULL,
  `tizhong` varchar(255) DEFAULT NULL,
  `xinlv` varchar(255) DEFAULT NULL,
  `xueya` varchar(255) DEFAULT NULL,
  `shentizhibiao` longtext,
  `jiankangfenxi` longtext,
  `faburiqi` datetime DEFAULT NULL,
  `addtime` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `jiankongxinxi` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `jiankongmingcheng` varchar(255) DEFAULT NULL,
  `jiankongfengmian` longtext,
  `jiankongshipin` longtext,
  `jiankongshijian` datetime DEFAULT NULL,
  `jiankongshuoming` longtext,
  `addtime` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `laorenxinxi` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `laorenxingming` varchar(255) NOT NULL,
  `mima` varchar(255) NOT NULL,
  `xingbie` varchar(255) DEFAULT NULL,
  `zhaopian` longtext,
  `nianling` int DEFAULT NULL,
  `huanbingshi` longtext,
  `shenfenzheng` varchar(255) DEFAULT NULL,
  `lianxiren` varchar(255) DEFAULT NULL,
  `lianxidianhua` varchar(255) DEFAULT NULL,
  `jiatingzhuzhi` longtext,
  `addtime` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_laorenxinxi_name` (`laorenxingming`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `news` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `title` varchar(255) NOT NULL,
  `introduction` longtext,
  `picture` longtext,
  `content` longtext,
  `addtime` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `token` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `userid` bigint NOT NULL,
  `username` varchar(255) NOT NULL,
  `tablename` varchar(255) DEFAULT NULL,
  `role` varchar(255) DEFAULT NULL,
  `token` varchar(512) NOT NULL,
  `expiratedtime` datetime NOT NULL,
  `addtime` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_token_value` (`token`(191))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `users` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `username` varchar(255) NOT NULL,
  `password` varchar(255) NOT NULL,
  `role` varchar(255) DEFAULT '管理员',
  `addtime` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_users_username` (`username`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO `config` (`name`, `value`)
SELECT 'homeName', '智慧养老管理系统'
WHERE NOT EXISTS (SELECT 1 FROM `config` WHERE `name` = 'homeName');

INSERT INTO `news` (`title`, `introduction`, `content`)
SELECT '系统部署完成', '用于部署验收的演示公告', '该数据由部署流程生成。'
WHERE NOT EXISTS (SELECT 1 FROM `news` WHERE `title` = '系统部署完成');
