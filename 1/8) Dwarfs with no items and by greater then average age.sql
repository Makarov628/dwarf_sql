USE Dwarfs;
GO

SELECT 
    d.dwarf_id,
    d.name
FROM Dwarves AS d
LEFT JOIN Items AS i ON d.dwarf_id = i.owner_id
GROUP BY d.dwarf_id, d.name, d.age
HAVING d.age > (SELECT AVG(age) FROM Dwarves) AND COUNT(i.item_id) = 0