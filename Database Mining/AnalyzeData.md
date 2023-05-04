
```{r}
# 1. Library (must be installed prior to loading
library(RMySQL)     ### MySQL

# 2. Settings
db_user <- 'root'
db_password <- 'Password' # use more secured password
db_name <- 'pubmedStar'

db_host <- 'localhost' 
db_port <- 3306 # always this port unless you change it during installation

# 3. Connect to DB
MySQL_dbcon <-  dbConnect(MySQL(), user = db_user, password = db_password,
                          dbname = db_name, host = db_host, port = db_port)

# allow for local file edits
command = "set global local_infile=true;"
dbExecute(MySQL_dbcon, command)

# suppress warnings from MySQL
command = "SET sql_notes=0;"
dbExecute(MySQL_dbcon, command)
```

In the notebook, use markdown to write a "report" which shows the results of the following analytical queries against your MySQL data warehouse from Part 2 (which might go to some manager as part of a weekly report):

-- Top ten authors with the most publications.
-- Number of articles per journal per year broken down by quarter
```{sql connection=MySQL_dbcon}
SELECT * FROM authorship_star ORDER BY total_number_authorships DESC LIMIT 10
```

```{r}
command = "SELECT `COLUMN_NAME` 
FROM `INFORMATION_SCHEMA`.`COLUMNS` 
WHERE `TABLE_SCHEMA`='pubmedStar' 
    AND `TABLE_NAME`='journal_summary'"
column_names = unname(unlist(dbGetQuery(MySQL_dbcon, command)))


column_names  = column_names[c(grep("Q", column_names))]
column_names_str = paste("journal_name,", column_names[1])
for(i in 2:length(column_names)) {
  column_names_str = paste0(column_names_str, ", ", column_names[i])
}
column_names_str

command = paste("SELECT", column_names_str, "FROM journal_summary")

dbGetQuery(MySQL_dbcon, command)
```

```{r}
select  * from 
```

```{sql connection=MySQL_dbcon}
select * from journal_summary
```

```{r}
dbDisconnect(MySQL_dbcon)
```
