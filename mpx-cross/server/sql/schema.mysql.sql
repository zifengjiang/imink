-- 说明：基于 SplatDatabase 仓库中的表集合（account/imageMap/i18n/schedule/coop/battle/vsTeam/coopPlayerResult/coopWaveResult/coopEnemyResult/weapon/player）设计的 MySQL 本地开发版结构
CREATE DATABASE IF NOT EXISTS imink DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
USE imink;

CREATE TABLE IF NOT EXISTS account (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  username VARCHAR(64) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  nsa_id VARCHAR(128),
  sp3_principal_id VARCHAR(128),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS schedule (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  account_id BIGINT,
  mode VARCHAR(64),
  rule VARCHAR(64),
  stage_a VARCHAR(128),
  stage_b VARCHAR(128),
  start_time DATETIME,
  end_time DATETIME,
  FOREIGN KEY (account_id) REFERENCES account(id)
);

CREATE TABLE IF NOT EXISTS battle (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  account_id BIGINT,
  rule VARCHAR(64),
  result VARCHAR(16),
  ko TINYINT,
  score INT,
  played_at DATETIME,
  FOREIGN KEY (account_id) REFERENCES account(id)
);

CREATE TABLE IF NOT EXISTS coop (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  account_id BIGINT,
  stage VARCHAR(128),
  danger_rate DECIMAL(5,2),
  clear_waves INT,
  played_at DATETIME,
  FOREIGN KEY (account_id) REFERENCES account(id)
);

CREATE TABLE IF NOT EXISTS imageMap (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  image_key VARCHAR(128),
  image_url TEXT
);

CREATE TABLE IF NOT EXISTS i18n (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  lang VARCHAR(16),
  i18n_key VARCHAR(128),
  i18n_value TEXT
);

CREATE TABLE IF NOT EXISTS vsTeam (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  battle_id BIGINT,
  team_name VARCHAR(64),
  paint_point INT,
  is_my_team TINYINT,
  FOREIGN KEY (battle_id) REFERENCES battle(id)
);

CREATE TABLE IF NOT EXISTS coopPlayerResult (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  coop_id BIGINT,
  player_name VARCHAR(64),
  golden_egg INT,
  power_egg INT,
  rescue_count INT,
  rescued_count INT,
  FOREIGN KEY (coop_id) REFERENCES coop(id)
);

CREATE TABLE IF NOT EXISTS coopWaveResult (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  coop_id BIGINT,
  wave_no INT,
  quota_num INT,
  delivered_num INT,
  is_clear TINYINT,
  FOREIGN KEY (coop_id) REFERENCES coop(id)
);

CREATE TABLE IF NOT EXISTS coopEnemyResult (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  coop_id BIGINT,
  enemy_name VARCHAR(64),
  team_defeat_count INT,
  defeated_count INT,
  FOREIGN KEY (coop_id) REFERENCES coop(id)
);

CREATE TABLE IF NOT EXISTS weapon (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  owner_type VARCHAR(16),
  owner_id BIGINT,
  weapon_id VARCHAR(64),
  weapon_name VARCHAR(128)
);

CREATE TABLE IF NOT EXISTS player (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  account_id BIGINT,
  vs_team_id BIGINT,
  coop_player_result_id BIGINT,
  player_name VARCHAR(64),
  name_id VARCHAR(32),
  kill_num INT,
  death_num INT,
  assist_num INT,
  special_num INT,
  FOREIGN KEY (account_id) REFERENCES account(id),
  FOREIGN KEY (vs_team_id) REFERENCES vsTeam(id),
  FOREIGN KEY (coop_player_result_id) REFERENCES coopPlayerResult(id)
);
