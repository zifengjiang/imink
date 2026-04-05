USE imink;
-- 默认 demo 账户，密码请用后端启动脚本自动创建（避免在 SQL 中写明文）。
INSERT INTO schedule(account_id, mode, rule, stage_a, stage_b, start_time, end_time)
VALUES (1, 'regular', 'Turf War', 'MakoMart', 'Museum d\'Alfonsino', NOW(), DATE_ADD(NOW(), INTERVAL 2 HOUR));

INSERT INTO battle(account_id, rule, result, ko, score, played_at)
VALUES
(1, 'Splat Zones', 'WIN', 1, 100, NOW()),
(1, 'Tower Control', 'LOSE', 0, 47, DATE_SUB(NOW(), INTERVAL 1 DAY));

INSERT INTO coop(account_id, stage, danger_rate, clear_waves, played_at)
VALUES
(1, 'Sockeye Station', 145.0, 3, NOW()),
(1, 'Spawning Grounds', 190.0, 2, DATE_SUB(NOW(), INTERVAL 2 DAY));
