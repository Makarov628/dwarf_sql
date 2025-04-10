SELECT
	dwarf_id,
	d.name,
	age,
	profession
FROM Dwarves AS d
INNER JOIN Items AS i ON i.owner_id = d.dwarf_id
WHERE i.type = 'weapon'