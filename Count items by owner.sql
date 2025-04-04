USE Dwarfs;
GO

SELECT 
    d.dwarf_id
    ,d.name
    ,COUNT(i.item_id) AS item_count
FROM Dwarves AS d
INNER JOIN Items AS i ON d.dwarf_id = i.owner_id
GROUP BY d.dwarf_id, d.name