
SELECT
    f.fortress_id,
    f.name,
    f.location,
    f.founded_year,
    f.depth,
    f.population,
    JSON_QUERY(
        '{' +
        '"dwarf_ids":' + ISNULL(
            (
                SELECT
                    '[' + STRING_AGG(CAST(d.dwarf_id AS NVARCHAR(MAX)), ',') + ']'
                FROM DWARVES d
                WHERE d.fortress_id = f.fortress_id
            ), '[]'
        ) + ',' +

        '"resource_ids":' + ISNULL(
            (
                SELECT
                    '[' + STRING_AGG(CAST(fr.resource_id AS NVARCHAR(MAX)), ',') + ']'
                FROM FORTRESS_RESOURCES fr
                WHERE fr.fortress_id = f.fortress_id
            ), '[]'
        ) + ',' +

        '"workshop_ids":' + ISNULL(
            (
                SELECT
                    '[' + STRING_AGG(CAST(w.workshop_id AS NVARCHAR(MAX)), ',') + ']'
                FROM WORKSHOPS w
                WHERE w.fortress_id = f.fortress_id
            ), '[]'
        ) + ',' +

        '"squad_ids":' + ISNULL(
            (
                SELECT
                    '[' + STRING_AGG(CAST(s.squad_id AS NVARCHAR(MAX)), ',') + ']'
                FROM MILITARY_SQUADS s
                WHERE s.fortress_id = f.fortress_id
            ), '[]'
        ) +
        '}'
    ) AS related_entities
FROM
    FORTRESSES f
FOR JSON PATH, INCLUDE_NULL_VALUES;