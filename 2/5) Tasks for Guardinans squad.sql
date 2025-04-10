SELECT
	t.*
FROM Tasks AS t
INNER JOIN Dwarves AS d ON t.assigned_to = d.dwarf_id
INNER JOIN Squads AS s ON s.squad_id = d.squad_id
WHERE s.name = 'Guardians'