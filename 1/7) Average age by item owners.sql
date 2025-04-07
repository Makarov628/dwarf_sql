USE Dwarfs;
GO

SELECT 
    i.type,
    AVG(d.age) AS avg_age
FROM Items i
JOIN Dwarves d ON i.owner_id = d.dwarf_id
GROUP BY i.type;
