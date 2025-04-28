WITH -- Базовые данные по мастерским и период производства
base AS (
    SELECT w.workshop_id,
        w.name AS workshop_name,
        w.type AS workshop_type,
        MIN(wp.production_date) AS first_prod,
        MAX(wp.production_date) AS last_prod
    FROM WORKSHOPS w
        LEFT JOIN WORKSHOP_PRODUCTS wp ON wp.workshop_id = w.workshop_id
    GROUP BY w.workshop_id,
        w.name,
        w.type
),
-- Сводка по ремесленникам
craft AS (
    SELECT wc.workshop_id,
        COUNT(DISTINCT wc.dwarf_id) AS num_craftsdwarves,
        STRING_AGG(CAST(wc.dwarf_id AS NVARCHAR(MAX)), ',') AS craftsdwarf_ids_csv
    FROM WORKSHOP_CRAFTSDWARVES wc
    GROUP BY wc.workshop_id
),
-- Производственные показатели
prod AS (
    SELECT wp.workshop_id,
        SUM(wp.quantity) AS total_quantity_produced,
        SUM(wp.quantity * p.value) AS total_production_value,
        STRING_AGG(CAST(wp.product_id AS NVARCHAR(MAX)), ',') AS product_ids_csv
    FROM WORKSHOP_PRODUCTS wp
        JOIN PRODUCTS p ON p.product_id = wp.product_id
    GROUP BY wp.workshop_id
),
-- Потребление материалов
materials AS (
    SELECT wm.workshop_id,
        SUM(
            CASE
                WHEN wm.is_input = 1 THEN wm.quantity
                ELSE 0
            END
        ) AS total_input_qty,
        STRING_AGG(CAST(wm.material_id AS NVARCHAR(MAX)), ',') AS material_ids_csv
    FROM WORKSHOP_MATERIALS wm
    GROUP BY wm.workshop_id
),
-- Проекты мастерской
projects_cte AS (
    SELECT p.workshop_id,
        STRING_AGG(CAST(p.project_id AS NVARCHAR(MAX)), ',') AS project_ids_csv
    FROM PROJECTS p
    GROUP BY p.workshop_id
),
-- Дни активности и период работы
util AS (
    SELECT b.workshop_id,
        DATEDIFF(DAY, b.first_prod, b.last_prod) + 1 AS period_days,
        COUNT(DISTINCT CONVERT(date, wp.production_date)) AS active_days
    FROM base b
        LEFT JOIN WORKSHOP_PRODUCTS wp ON wp.workshop_id = b.workshop_id
    GROUP BY b.workshop_id,
        b.first_prod,
        b.last_prod
),
-- Средние навыки ремесленников
skill AS (
    SELECT wc.workshop_id,
        ds.dwarf_id,
        AVG(ds.level) AS avg_skill
    FROM WORKSHOP_CRAFTSDWARVES wc
        JOIN DWARF_SKILLS ds ON ds.dwarf_id = wc.dwarf_id
    GROUP BY wc.workshop_id,
        ds.dwarf_id
),
-- Качество продукции
prod_quality AS (
    SELECT wp.workshop_id,
        p.product_id,
        p.quality
    FROM WORKSHOP_PRODUCTS wp
        JOIN PRODUCTS p ON p.product_id = wp.product_id
),
-- Корреляция навыков и качества
corr AS (
    SELECT s.workshop_id,
        CASE
            WHEN STDEV_SAMP(s.avg_skill) = 0
            OR STDEV_SAMP(p.quality) = 0 THEN NULL
            ELSE COVAR_SAMP(s.avg_skill, p.quality) / (STDEV_SAMP(s.avg_skill) * STDEV_SAMP(p.quality))
        END AS skill_quality_correlation
    FROM skill s
        JOIN prod_quality p ON p.workshop_id = s.workshop_id
    GROUP BY s.workshop_id
)
SELECT b.workshop_id,
    b.workshop_name,
    b.workshop_type,
    c.num_craftsdwarves,
    prod.total_quantity_produced,
    prod.total_production_value,
    -- Производительность в день
    CAST(
        prod.total_quantity_produced * 1.0 / NULLIF(u.period_days, 0) AS DECIMAL(10, 2)
    ) AS daily_production_rate,
    -- Стоимость единицы материала
    CAST(
        prod.total_production_value * 1.0 / NULLIF(materials.total_input_qty, 1) AS DECIMAL(10, 2)
    ) AS value_per_material_unit,
    -- Использование мастерской
    CAST(
        u.active_days * 100.0 / NULLIF(u.period_days, 1) AS DECIMAL(5, 2)
    ) AS workshop_utilization_percent,
    -- Коэффициент конверсии материала
    CAST(
        prod.total_quantity_produced * 1.0 / NULLIF(materials.total_input_qty, 1) AS DECIMAL(10, 2)
    ) AS material_conversion_ratio,
    -- Средний навык ремесленников
    CAST(
        (
            SELECT AVG(avg_skill)
            FROM skill s2
            WHERE s2.workshop_id = b.workshop_id
        ) AS DECIMAL(5, 2)
    ) AS average_craftsdwarf_skill,
    corr.skill_quality_correlation,
    JSON_QUERY(
        '{' + '"craftsdwarf_ids":[' + COALESCE(c.craftsdwarf_ids_csv, '') + '],' + '"product_ids":[' + COALESCE(prod.product_ids_csv, '') + '],' + '"material_ids":[' + COALESCE(materials.material_ids_csv, '') + '],' + '"project_ids":[' + COALESCE(projects_cte.project_ids_csv, '') + ']' + '}'
    ) AS related_entities
FROM base b
    LEFT JOIN craft c ON c.workshop_id = b.workshop_id
    LEFT JOIN prod ON prod.workshop_id = b.workshop_id
    LEFT JOIN materials ON materials.workshop_id = b.workshop_id
    LEFT JOIN projects_cte ON projects_cte.workshop_id = b.workshop_id
    LEFT JOIN util ON util.workshop_id = b.workshop_id
    LEFT JOIN corr ON corr.workshop_id = b.workshop_id FOR JSON PATH,
    INCLUDE_NULL_VALUES;