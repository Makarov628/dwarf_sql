SELECT
    d.dwarf_id,
    d.name,
    d.age,
    d.profession,
    JSON_QUERY(
        '{' +
        '"skill_ids":' + ISNULL((
            SELECT
                '[' + STRING_AGG(CAST(ds.skill_id AS NVARCHAR(MAX)), ',') + ']'
            FROM DWARF_SKILLS ds
            WHERE ds.dwarf_id = d.dwarf_id
        ), '[]') + ',' +

        '"assignment_ids":' + ISNULL((
            SELECT
                '[' + STRING_AGG(CAST(da.assignment_id AS NVARCHAR(MAX)), ',') + ']'
            FROM DWARF_ASSIGNMENTS da
            WHERE da.dwarf_id = d.dwarf_id
        ), '[]') + ',' +

        '"squad_ids":' + ISNULL((
            SELECT
                '[' + STRING_AGG(CAST(sm.squad_id AS NVARCHAR(MAX)), ',') + ']'
            FROM SQUAD_MEMBERS sm
            WHERE sm.dwarf_id = d.dwarf_id
        ), '[]') + ',' +

        '"equipment_ids":' + ISNULL((
            SELECT
                '[' + STRING_AGG(CAST(de.equipment_id AS NVARCHAR(MAX)), ',') + ']'
            FROM DWARF_EQUIPMENT de
            WHERE de.dwarf_id = d.dwarf_id
        ), '[]') +
        '}'
    ) AS related_entities
FROM
    DWARVES d
FOR JSON PATH, INCLUDE_NULL_VALUES;
