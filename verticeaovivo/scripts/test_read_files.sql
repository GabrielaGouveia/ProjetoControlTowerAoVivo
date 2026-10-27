SELECT arquivo, count(*) 
FROM read_files('/Volumes/lakehouse_vertice/bronze/raw/excel/', format => 'excel', headerRows => 1, inferColumnTypes => false)
GROUP BY arquivo;

