USE Dwarfs;
GO

SELECT 
    d.*
FROM Dwarves AS d
LEFT JOIN Squads AS s on d.squad_id = s.squad_id
WHERE d.profession = 'miner' and s.squad_id IS NULL