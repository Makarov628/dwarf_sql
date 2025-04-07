USE Dwarfs;
GO

SELECT 
    ISNULL(s.squad_id, -1) AS squad_id
    ,ISNULL(s.name, 'No Squad') AS squad_name
    ,COUNT(d.dwarf_id) AS dwarf_count
FROM Dwarves AS d
LEFT JOIN Squads AS s ON d.squad_id = s.squad_id
GROUP BY s.squad_id, s.name