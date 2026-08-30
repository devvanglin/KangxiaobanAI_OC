-- Minimal deployment bootstrap for template projects whose upstream source
-- contains entity classes but no SQL dump.  Columns are taken from
-- DictionaryEntity, UsersEntity and TokenEntity.

CREATE TABLE IF NOT EXISTS `dictionary` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `dic_code` varchar(200) DEFAULT NULL,
  `dic_name` varchar(200) DEFAULT NULL,
  `code_index` int DEFAULT NULL,
  `index_name` varchar(200) DEFAULT NULL,
  `super_id` int DEFAULT NULL,
  `beizhu` varchar(200) DEFAULT NULL,
  `create_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `users` (
  `id` int NOT NULL AUTO_INCREMENT,
  `username` varchar(200) NOT NULL,
  `password` varchar(200) NOT NULL,
  `role` varchar(200) DEFAULT '管理员',
  `addtime` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_users_username` (`username`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `token` (
  `id` int NOT NULL AUTO_INCREMENT,
  `userid` int NOT NULL,
  `username` varchar(200) NOT NULL,
  `tablename` varchar(200) DEFAULT NULL,
  `role` varchar(200) DEFAULT NULL,
  `token` varchar(512) NOT NULL,
  `expiratedtime` timestamp NOT NULL,
  `addtime` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
