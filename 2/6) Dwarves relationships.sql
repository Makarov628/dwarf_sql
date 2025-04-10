SELECT
	d.name
	,r.relationship
	,dr.name
FROM Dwarves AS d
INNER JOIN Relationships AS r ON r.dwarf_id = d.dwarf_id
INNER JOIN Dwarves as dr on dr.dwarf_id = r.related_to
UNION ALL
SELECT
	 d.name
	,r.relationship
	,dr.name
FROM Dwarves AS d
INNER JOIN Relationships AS r ON r.related_to = d.dwarf_id
INNER JOIN Dwarves as dr on dr.dwarf_id = r.dwarf_id
ORDER BY d.name, dr.name