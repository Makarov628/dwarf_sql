WITH -- 1. Общие показатели атак и защиты
attack_stats AS (
  SELECT COUNT(*) AS total_recorded_attacks,
    COUNT(DISTINCT creature_id) AS unique_attackers,
    CAST(
      SUM(
        CASE
          WHEN casualties = 0 THEN 1
          ELSE 0
        END
      ) * 100.0 / NULLIF(COUNT(*), 0) AS DECIMAL(5, 2)
    ) AS overall_defense_success_rate
  FROM creature_attacks
),
-- 2. Эффективность защитных сооружений
defense_structure_effectiveness AS (
  SELECT ds.structure_id,
    ds.type AS defense_type,
    COUNT(DISTINCT ca.attack_id) AS attacks_defended,
    SUM(
      CASE
        WHEN ca.outcome = 'Repelled' THEN 1
        ELSE 0
      END
    ) AS successful_defenses,
    AVG(ca.enemy_casualties) AS avg_enemy_casualties,
    ds.quality
  FROM defense_structures ds
    LEFT JOIN creature_attacks ca ON CHARINDEX(
      CAST(ds.structure_id AS VARCHAR(10)),
      ca.defense_structures_used
    ) > 0
  GROUP BY ds.structure_id,
    ds.type,
    ds.quality
),
-- 3. Уязвимость зон
zone_vulnerability AS (
  SELECT l.location_id,
    l.name AS zone_name,
    COUNT(DISTINCT ca.attack_id) AS total_attacks,
    SUM(
      CASE
        WHEN ca.outcome = 'Breached' THEN 1
        ELSE 0
      END
    ) AS breaches,
    l.fortification_level,
    COUNT(DISTINCT ds.structure_id) AS defense_structures,
    MIN(ms.response_time_to_zone) AS min_response_time,
    l.access_points
  FROM locations l
    LEFT JOIN creature_attacks ca ON ca.location_id = l.location_id
    LEFT JOIN defense_structures ds ON ds.location_id = l.location_id
    LEFT JOIN military_stations ms ON ms.coverage_zone_id = l.location_id
  GROUP BY l.location_id,
    l.name,
    l.fortification_level,
    l.access_points
),
-- 4. Готовность войск
military_readiness AS (
  SELECT s.squad_id,
    s.name AS squad_name,
    CAST(
      mem.current_members * 100.0 / NULLIF(mem.total_members, 0) AS DECIMAL(5, 2)
    ) AS readiness_score,
    mem.current_members,
    AVG(ds.level) AS avg_combat_skill,
    CAST(
      SUM(
        CASE
          WHEN sb.outcome IN ('Repelled', 'Partial Breach') THEN 1
          ELSE 0
        END
      ) * 100.0 / NULLIF(COUNT(sb.report_id), 0) AS DECIMAL(5, 2)
    ) AS combat_effectiveness
  FROM military_squads s
    JOIN (
      SELECT squad_id,
        COUNT(*) AS total_members,
        SUM(
          CASE
            WHEN exit_date IS NULL THEN 1
            ELSE 0
          END
        ) AS current_members
      FROM squad_members
      GROUP BY squad_id
    ) mem ON mem.squad_id = s.squad_id
    JOIN squad_members sm ON sm.squad_id = s.squad_id
    JOIN dwarf_skills ds ON ds.dwarf_id = sm.dwarf_id
    AND ds.skill_type = 'Combat'
    JOIN squad_battles sb ON sb.squad_id = s.squad_id
  GROUP BY s.squad_id,
    s.name,
    mem.current_members,
    mem.total_members
),
-- 5. Эволюция обороны по годам
security_evolution AS (
  SELECT DATEPART(YEAR, ca.date) AS [year],
    COUNT(*) AS total_attacks,
    CAST(
      SUM(
        CASE
          WHEN ca.casualties = 0 THEN 1
          ELSE 0
        END
      ) * 100.0 / NULLIF(COUNT(*), 0) AS DECIMAL(5, 2)
    ) AS defense_success_rate,
    LAG(
      CAST(
        SUM(
          CASE
            WHEN ca.casualties = 0 THEN 1
            ELSE 0
          END
        ) * 100.0 / NULLIF(COUNT(*), 0) AS DECIMAL(5, 2)
      )
    ) OVER (
      ORDER BY DATEPART(YEAR, ca.date)
    ) AS previous_year_success_rate
  FROM creature_attacks ca
  GROUP BY DATEPART(YEAR, ca.date)
)
SELECT ats.total_recorded_attacks,
  ats.unique_attackers,
  ats.overall_defense_success_rate,
  -- Active Threats
  (
    SELECT c.type AS creature_type,
      AVG(ct.danger_level) AS threat_level,
      MAX(cs.date) AS last_sighting_date,
      AVG(ct.distance_to_fortress) AS territory_proximity,
      COUNT(DISTINCT cs.sighting_id) AS estimated_numbers,
      (
        SELECT STRING_AGG(CAST(c2.creature_id AS VARCHAR), ',')
        FROM creatures c2
        WHERE c2.type = c.type
          AND c2.active = 1
      ) AS creature_ids
    FROM creatures c
      JOIN creature_sightings cs ON cs.creature_id = c.creature_id
      JOIN creature_territories ct ON ct.creature_id = c.creature_id
    WHERE cs.date > DATEADD(DAY, -90, GETDATE())
      AND c.active = 1
    GROUP BY c.type FOR JSON PATH
  ) AS active_threats,
  -- Vulnerability Analysis
  (
    SELECT zv.location_id AS zone_id,
      zv.zone_name,
      ROUND(
        (
          zv.breaches * 1.0 / NULLIF(zv.total_attacks, 0) * 0.4
        ) + ((5 - zv.fortification_level) * 0.2) + (zv.access_points * 0.1) + (
          (120 - COALESCE(zv.min_response_time, 120)) / 120 * 0.1
        ) + ((3 - COALESCE(zv.defense_structures, 0)) * 0.2),
        2
      ) AS vulnerability_score,
      zv.breaches AS historical_breaches,
      zv.fortification_level,
      zv.access_points,
      (
        SELECT ds.structure_id
        FROM defense_structures ds
        WHERE ds.location_id = zv.location_id FOR JSON PATH
      ) AS defense_coverage_structures,
      (
        SELECT mcz.squad_id,
          mcz.response_time_to_zone AS response_time
        FROM military_coverage_zones mcz
        WHERE mcz.zone_id = zv.location_id FOR JSON PATH
      ) AS defense_coverage_squads
    FROM zone_vulnerability zv
    ORDER BY vulnerability_score DESC FOR JSON PATH
  ) AS vulnerability_analysis,
  -- Defense Effectiveness
  (
    SELECT dse.defense_type,
      ROUND(
        SUM(dse.successful_defenses) * 1.0 / NULLIF(SUM(dse.attacks_defended), 0) * 100,
        2
      ) AS effectiveness_rate,
      ROUND(AVG(dse.avg_enemy_casualties), 2) AS avg_enemy_casualties,
      (
        SELECT ds2.structure_id
        FROM defense_structures ds2
        WHERE ds2.type = dse.defense_type FOR JSON PATH
      ) AS structure_ids
    FROM defense_structure_effectiveness dse
    GROUP BY dse.defense_type
    ORDER BY effectiveness_rate DESC FOR JSON PATH
  ) AS defense_effectiveness,
  -- Military Readiness Assessment
  (
    SELECT mr.squad_id,
      mr.squad_name,
      mr.readiness_score,
      mr.current_members,
      mr.avg_combat_skill,
      mr.combat_effectiveness,
      (
        SELECT mcz2.zone_id,
          mcz2.response_time_to_zone AS response_time
        FROM military_coverage_zones mcz2
        WHERE mcz2.squad_id = mr.squad_id FOR JSON PATH
      ) AS response_coverage
    FROM military_readiness mr
    ORDER BY mr.readiness_score DESC FOR JSON PATH
  ) AS military_readiness_assessment,
  -- Security Evolution
  (
    SELECT se.[year],
      se.total_attacks,
      se.defense_success_rate,
      se.previous_year_success_rate
    FROM security_evolution se
    ORDER BY se.[year] FOR JSON PATH
  ) AS security_evolution
FROM attack_stats ats;