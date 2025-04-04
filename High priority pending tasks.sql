USE Dwarfs;
GO

SELECT * FROM Tasks 
WHERE status = 'pending' and priority = 3;