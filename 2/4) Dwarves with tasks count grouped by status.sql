SELECT
	dwarf_id
	,d.name
	,ISNULL(t.status, '-') AS status
	,COUNT(t.task_id) AS task_count
FROM Dwarves AS d
LEFT JOIN Tasks t ON t.assigned_to = d.dwarf_id
GROUP BY dwarf_id, d.name, t.status
ORDER BY d.name, t.status