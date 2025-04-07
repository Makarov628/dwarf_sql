USE Dwarfs;
GO

SELECT d.dwarf_id,
    d.name as dwarf_name,
    d.age,
    d.profession,
    s.squad_id,
    s.name as squad_name,
    s.mission
FROM Dwarves AS d
    INNER JOIN Squads AS s ON d.squad_id = s.squad_id;