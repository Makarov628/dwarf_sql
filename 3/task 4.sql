SELECT
    s.squad_id,
    s.name,
    s.formation_type,
    s.leader_id,
    JSON_QUERY(
        '{' +
        '"member_ids":' + ISNULL((
            SELECT
                '[' + STRING_AGG(CAST(sm.dwarf_id AS NVARCHAR(MAX)), ',') + ']'
            FROM SQUAD_MEMBERS sm
            WHERE sm.squad_id = s.squad_id
        ), '[]') + ',' +

        '"equipment_ids":' + ISNULL((
            SELECT
                '[' + STRING_AGG(CAST(se.equipment_id AS NVARCHAR(MAX)), ',') + ']'
            FROM SQUAD_EQUIPMENT se
            WHERE se.squad_id = s.squad_id
        ), '[]') + ',' +

        '"operation_ids":' + ISNULL((
            SELECT
                '[' + STRING_AGG(CAST(so.operation_id AS NVARCHAR(MAX)), ',') + ']'
            FROM SQUAD_OPERATIONS so
            WHERE so.squad_id = s.squad_id
        ), '[]') + ',' +

        '"training_schedule_ids":' + ISNULL((
            SELECT
                '[' + STRING_AGG(CAST(st.schedule_id AS NVARCHAR(MAX)), ',') + ']'
            FROM SQUAD_TRAINING st
            WHERE st.squad_id = s.squad_id
        ), '[]') + ',' +

        '"battle_report_ids":' + ISNULL((
            SELECT
                '[' + STRING_AGG(CAST(sb.report_id AS NVARCHAR(MAX)), ',') + ']'
            FROM SQUAD_BATTLES sb
            WHERE sb.squad_id = s.squad_id
        ), '[]') +
        '}'
    ) AS related_entities
FROM
    MILITARY_SQUADS s
FOR JSON PATH, INCLUDE_NULL_VALUES;
