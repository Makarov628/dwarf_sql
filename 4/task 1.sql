/* ----------------------------------------------
   базовые сведения об экспедициях
---------------------------------------------- */
WITH base AS (
    SELECT
        e.expedition_id,
        e.destination,
        e.status,
        e.departure_date,
        e.return_date
    FROM EXPEDITIONS e
    WHERE e.status = N'Completed'
),

/* ----------------------------------------------
   сводка по участникам
---------------------------------------------- */
members AS (
    SELECT
        em.expedition_id,
        COUNT(*)                     AS total_members,
        SUM(CASE WHEN em.survived=1
                 THEN 1 ELSE 0 END)  AS survived_members,
        STRING_AGG(CAST(em.dwarf_id AS NVARCHAR(MAX)), ',') AS member_ids_csv
    FROM EXPEDITION_MEMBERS em
    GROUP BY em.expedition_id
),

/* ----------------------------------------------
   сводка по артефактам
---------------------------------------------- */
arts AS (
    SELECT
        a.expedition_id,
        COALESCE(SUM(a.value),0)     AS artifacts_value,
        STRING_AGG(CAST(a.artifact_id AS NVARCHAR(MAX)), ',') AS artifact_ids_csv
    FROM EXPEDITION_ARTIFACTS a
    GROUP BY a.expedition_id
),

/* ----------------------------------------------
   сводка по посещённым локациям
---------------------------------------------- */
sites AS (
    SELECT
        s.expedition_id,
        COUNT(*)                     AS discovered_sites,
        STRING_AGG(CAST(s.site_id AS NVARCHAR(MAX)), ',') AS site_ids_csv
    FROM EXPEDITION_SITES s
    GROUP BY s.expedition_id
),

/* ----------------------------------------------
   встречи с существами
---------------------------------------------- */
enc AS (
    SELECT
        ec.expedition_id,
        COUNT(*)                                        AS encounters_total,
        SUM(CASE WHEN ec.outcome IN (N'Success',N'Victory')
                 THEN 1 ELSE 0 END)                     AS encounters_success
    FROM EXPEDITION_CREATURES ec
    GROUP BY ec.expedition_id
),

/* ----------------------------------------------
   прирост опыта участников
   (сумма experience_after - experience_before)
---------------------------------------------- */
skill_gain AS (
    SELECT
        ds.dwarf_id,
        MIN(CASE WHEN ds.date <= b.departure_date
                 THEN ds.experience END) AS exp_before,
        MAX(CASE WHEN ds.date >= b.return_date
                 THEN ds.experience END) AS exp_after
    FROM DWARF_SKILLS ds
    JOIN EXPEDITION_MEMBERS em  ON em.dwarf_id = ds.dwarf_id
    JOIN base             b   ON b.expedition_id = em.expedition_id
    GROUP BY ds.dwarf_id, em.expedition_id
),
skill_by_exp AS (
    SELECT
        em.expedition_id,
        SUM(COALESCE(sg.exp_after,0) - COALESCE(sg.exp_before,0)) AS skill_improvement
    FROM EXPEDITION_MEMBERS em
    LEFT JOIN skill_gain sg
           ON sg.dwarf_id = em.dwarf_id
    GROUP BY em.expedition_id
)


SELECT
    b.expedition_id,
    b.destination,
    b.status,

    CAST(m.survived_members * 100.0 / NULLIF(m.total_members,0) AS DECIMAL(5,2))
		AS survival_rate,

    a.artifacts_value,

    COALESCE(s.discovered_sites,0)
		AS discovered_sites,

    CAST(enc.encounters_success * 100.0 / NULLIF(enc.encounters_total,0) AS DECIMAL(5,2))
		AS encounter_success_rate,

    COALESCE(g.skill_improvement,0)
		AS skill_improvement,

    DATEDIFF(DAY, b.departure_date, b.return_date)
		AS expedition_duration,

    CAST(0.30 * (m.survived_members * 1.0 / NULLIF(m.total_members,1)) +

		 0.25 * (a.artifacts_value  * 1.0 /
                 NULLIF((SELECT MAX(artifacts_value) FROM arts),1)) +

		 0.15 * (enc.encounters_success * 1.0 / NULLIF(enc.encounters_total,1)) +

		 0.10 * (COALESCE(s.discovered_sites,0) * 1.0 /
                 NULLIF((SELECT MAX(discovered_sites) FROM sites),1)) +

		 0.10 * (COALESCE(g.skill_improvement,0) * 1.0 /
                 NULLIF((SELECT MAX(skill_improvement) FROM skill_by_exp),1)) +

		 0.10 * (1.0 - DATEDIFF(DAY, b.departure_date, b.return_date) * 1.0 /
                 NULLIF((SELECT MAX(DATEDIFF(DAY, departure_date, return_date)) FROM base),1))
        AS DECIMAL(5,2)) AS overall_success_score,

    /* --- JSON с ID --- */
    JSON_QUERY('{' +
        '"member_ids":['   + COALESCE(m.member_ids_csv  ,'') + '],' +
        '"artifact_ids":[' + COALESCE(a.artifact_ids_csv,'') + '],' +
        '"site_ids":['     + COALESCE(s.site_ids_csv    ,'') + ']' +
    '}') AS related_entities

FROM        base              b
LEFT JOIN   members           m   ON m.expedition_id = b.expedition_id
LEFT JOIN   arts              a   ON a.expedition_id = b.expedition_id
LEFT JOIN   sites             s   ON s.expedition_id = b.expedition_id
LEFT JOIN   enc               enc ON enc.expedition_id = b.expedition_id
LEFT JOIN   skill_by_exp      g   ON g.expedition_id = b.expedition_id
ORDER BY    overall_success_score DESC;
