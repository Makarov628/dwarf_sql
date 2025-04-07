USE Dwarfs;
GO

SELECT 
    d.profession,
    COUNT(t.task_id) AS unfinished_tasks
FROM Dwarves d
JOIN Tasks t ON d.dwarf_id = t.assigned_to
WHERE t.status IN ('pending', 'in_progress')
GROUP BY d.profession
ORDER BY unfinished_tasks DESC;
