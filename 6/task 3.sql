WITH -- Базовые данные по отрядам
base AS (
    SELECT s.squad_id,
        s.name AS squad_name,
        s.formation_type,
        l.name AS leader_name
    FROM MILITARY_SQUADS s
        LEFT JOIN DWARVES l ON l.dwarf_id = s.leader_id
),
-- Сводка по сражениям
battles AS (
    SELECT sb.squad_id,
        COUNT(*) AS total_battles,
        SUM(
            CASE
                WHEN sb.outcome IN (N'Victory', 'Success') THEN 1
                ELSE 0
            END
        ) AS victories,
        SUM(sb.casualties) AS total_casualties,
        SUM(sb.enemy_casualties) AS total_enemy_casualties,
        MIN(sb.date) AS first_battle,
        MAX(sb.date) AS last_battle,
        STRING_AGG(CAST(sb.report_id AS NVARCHAR(MAX)), ',') AS battle_report_ids_csv
    FROM SQUAD_BATTLES sb
    GROUP BY sb.squad_id
),
-- Сводка по составу отряда
members AS (
    SELECT sm.squad_id,
        COUNT(DISTINCT sm.dwarf_id) AS total_members_ever,
        SUM(
            CASE
                WHEN sm.exit_date IS NULL THEN 1
                ELSE 0
            END
        ) AS current_members,
        STRING_AGG(CAST(sm.dwarf_id AS NVARCHAR(MAX)), ',') AS member_ids_csv
    FROM SQUAD_MEMBERS sm
    GROUP BY sm.squad_id
),
-- Качество экипировки
equipment AS (
    SELECT se.squad_id,
        AVG(eq.quality) AS avg_equipment_quality,
        STRING_AGG(CAST(se.equipment_id AS NVARCHAR(MAX)), ',') AS equipment_ids_csv
    FROM SQUAD_EQUIPMENT se
        JOIN EQUIPMENT eq ON eq.equipment_id = se.equipment_id
    GROUP BY se.squad_id
),
-- История тренировок
training AS (
    SELECT st.squad_id,
        COUNT(*) AS total_training_sessions,
        AVG(st.effectiveness) AS avg_training_effectiveness,
        STRING_AGG(CAST(st.schedule_id AS NVARCHAR(MAX)), ',') AS training_ids_csv
    FROM SQUAD_TRAINING st
    GROUP BY st.squad_id
),
-- Корреляция тренировок и побед
corr AS (
    SELECT t.squad_id,
        CASE
            WHEN STDEV_SAMP(t.effectiveness) = 0
            OR STDEV_SAMP(b.victory_flag) = 0 THEN NULL
            ELSE COVAR_SAMP(t.effectiveness, b.victory_flag) / (
                STDEV_SAMP(t.effectiveness) * STDEV_SAMP(b.victory_flag)
            )
        END AS training_battle_correlation
    FROM (
            SELECT squad_id,
                effectiveness
            FROM SQUAD_TRAINING
        ) t
        JOIN (
            SELECT squad_id,
                CASE
                    WHEN outcome IN (N'Victory', 'Success') THEN 1
                    ELSE 0
                END AS victory_flag
            FROM SQUAD_BATTLES
        ) b ON b.squad_id = t.squad_id
    GROUP BY t.squad_id
),
-- Прирост навыков участников
skill_gain AS (
    SELECT se.squad_id,
        ds.dwarf_id,
        MIN(
            CASE
                WHEN ds.date <= bat.first_battle THEN ds.experience
            END
        ) AS exp_before,
        MAX(
            CASE
                WHEN ds.date >= bat.last_battle THEN ds.experience
            END
        ) AS exp_after
    FROM DWARF_SKILLS ds
        JOIN SQUAD_MEMBERS se ON se.dwarf_id = ds.dwarf_id
        JOIN battles bat ON bat.squad_id = se.squad_id
    GROUP BY se.squad_id,
        ds.dwarf_id
),
skill_summary AS (
    SELECT squad_id,
        AVG(ISNULL(exp_after, 0) - ISNULL(exp_before, 0)) AS avg_combat_skill_improvement
    FROM skill_gain
    GROUP BY squad_id
)
SELECT bse.squad_id,
    bse.squad_name,
    bse.formation_type,
    bse.leader_name,
    bat.total_battles,
    bat.victories,
    CAST(
        bat.victories * 100.0 / NULLIF(bat.total_battles, 0) AS DECIMAL(5, 2)
    ) AS victory_percentage,
    CAST(
        bat.total_casualties * 100.0 / NULLIF(
            (
                bat.total_casualties + bat.total_enemy_casualties
            ),
            0
        ) AS DECIMAL(5, 2)
    ) AS casualty_rate,
    CAST(
        bat.total_enemy_casualties * 1.0 / NULLIF(bat.total_casualties, 1) AS DECIMAL(5, 2)
    ) AS casualty_exchange_ratio,
    mem.current_members,
    mem.total_members_ever,
    CAST(
        mem.current_members * 100.0 / NULLIF(mem.total_members_ever, 0) AS DECIMAL(5, 2)
    ) AS retention_rate,
    eq.avg_equipment_quality,
    tr.total_training_sessions,
    tr.avg_training_effectiveness,
    corr.training_battle_correlation,
    sk.avg_combat_skill_improvement,
    CAST(
        0.20 * (
            bat.victories * 1.0 / NULLIF(bat.total_battles, 1)
        ) + 0.15 * (
            1 - (
                bat.total_casualties * 1.0 / NULLIF(
                    (
                        bat.total_casualties + bat.total_enemy_casualties
                    ),
                    1
                )
            )
        ) + 0.10 * (
            mem.current_members * 1.0 / NULLIF(mem.total_members_ever, 1)
        ) + 0.10 * (eq.avg_equipment_quality / 5.0) + 0.15 * tr.avg_training_effectiveness + 0.15 * (
            sk.avg_combat_skill_improvement / NULLIF(MAX(sk.avg_combat_skill_improvement) OVER (), 1)
        ) + 0.15 * corr.training_battle_correlation AS DECIMAL(5, 3)
    ) AS overall_effectiveness_score,
    JSON_QUERY(
        '{' + '"member_ids":[' + ISNULL(mem.member_ids_csv, '') + '],' + '"equipment_ids":[' + ISNULL(eq.equipment_ids_csv, '') + '],' + '"battle_report_ids":[' + ISNULL(bat.battle_report_ids_csv, '') + '],' + '"training_ids":[' + ISNULL(tr.training_ids_csv, '') + ']' + '}'
    ) AS related_entities
FROM base bse
    LEFT JOIN battles bat ON bat.squad_id = bse.squad_id
    LEFT JOIN members mem ON mem.squad_id = bse.squad_id
    LEFT JOIN equipment eq ON eq.squad_id = bse.squad_id
    LEFT JOIN training tr ON tr.squad_id = bse.squad_id
    LEFT JOIN corr ON corr.squad_id = bse.squad_id
    LEFT JOIN skill_summary sk ON sk.squad_id = bse.squad_id FOR JSON PATH,
    INCLUDE_NULL_VALUES;