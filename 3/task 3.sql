SELECT
    w.workshop_id,
    w.name,
    w.type,
    w.quality,
    JSON_QUERY(
        '{' +
        '"craftsdwarf_ids":' + ISNULL((
            SELECT
                '[' + STRING_AGG(CAST(wc.dwarf_id AS NVARCHAR(MAX)), ',') + ']'
            FROM WORKSHOP_CRAFTSDWARVES wc
            WHERE wc.workshop_id = w.workshop_id
        ), '[]') + ',' +

        '"project_ids":' + ISNULL((
            SELECT
                '[' + STRING_AGG(CAST(p.project_id AS NVARCHAR(MAX)), ',') + ']'
            FROM PROJECTS p
            WHERE p.workshop_id = w.workshop_id
        ), '[]') + ',' +

        '"input_material_ids":' + ISNULL((
            SELECT
                '[' + STRING_AGG(CAST(wm.material_id AS NVARCHAR(MAX)), ',') + ']'
            FROM WORKSHOP_MATERIALS wm
            WHERE wm.workshop_id = w.workshop_id AND wm.is_input = 1
        ), '[]') + ',' +

        '"output_product_ids":' + ISNULL((
            SELECT
                '[' + STRING_AGG(CAST(wp.product_id AS NVARCHAR(MAX)), ',') + ']'
            FROM WORKSHOP_PRODUCTS wp
            WHERE wp.workshop_id = w.workshop_id
        ), '[]') +
        '}'
    ) AS related_entities
FROM
    WORKSHOPS w
FOR JSON PATH, INCLUDE_NULL_VALUES;
