# Author: LIAO, JUSTIN
# Course: CS5200
# Term: FALL2022
# date 03Dec2022


# this function will check and see if the new set exists within the author's current set of sets
# if it exists, nothing happens, else it gets added and the author_sets is updated
check_authorship <- function(aid, new_set) {
  new_set = new_set[order(unlist(new_set))]
  #print(new_set)
  num_of_sets = length(author_sets[[aid]])
  
  if (num_of_sets < 1) {
    author_sets[[aid]] = list(new_set)
    author_sets <<- author_sets
  }
  else {
    is_new_entry = TRUE
    for (i in 1:num_of_sets) {
      #
      #print(author_sets[[aid]][[i]])
      #print(identical(author_sets[[aid]][[i]], new_set))
      if (identical(author_sets[[aid]][[i]], new_set)) {
        is_new_entry = FALSE
        break
      }
    }
    if (is_new_entry) {
      author_sets[[aid]][[length(author_sets[[aid]]) + 1]] =new_set
      author_sets <<- author_sets
    }
  }
}

# Load necessary data from Part 1 SQLite database

library(RSQLite)
fpath = ""
dbfile = "pubmed_articles.sqlite"
dbcon <- dbConnect(RSQLite::SQLite(), paste0(fpath, dbfile))

# Getting aid, name, and # of articles written

command = "SELECT al.aid, a.first_name || \" \" || a.last_name as name,  COUNT(*) as 'Total Number of Articles'
            FROM author_list al 
            JOIN authors a ON a.aid = al.aid
            GROUP BY al.aid
  "
incomplete_summary = dbGetQuery(dbcon, command)

# get the max number of participating authors for an article
total_authors = dbGetQuery(dbcon, "SELECT COUNT(*) FROM AUTHORS")[[1]]
total_authors


#create a data structure that holds the complete set of authorship lists
# index = author id
# value is set of authors that the author i partipcated in 
# i.e. if current author id = 1 -> a possible set of sets would be [(1, 2, 3), (1, 100)] here order matters
#author_sets <- rep(NA, total_authors)
author_sets <- vector("list", total_authors)


# get main data to process
command = "SELECT al.aid, a.first_name || \" \" || a.last_name as name,  COUNT(*) as 'Total Number of Articles'
            FROM author_list al 
            JOIN authors a ON a.aid = al.aid
            GROUP BY al.aid"

fact_table_df = dbGetQuery(dbcon, command)
fact_table_df

# query to get the denormalized table 
command = "SELECT al.aid, a.first_name || \" \" || a.last_name as name,  al.pmid, al1.aid as aid2
            FROM author_list al 
            JOIN authors a ON a.aid = al.aid
            FULL OUTER JOIN author_list al1 ON al.pmid = al1.pmid"

data = dbGetQuery(dbcon, command)
data
n = nrow(data)

cur_author = 1
cur_pmid = 1

authors = list()
articles = list()

for (i in 1: n) {

  if (cur_author != data$aid[i] ){
    #print(authors)
    check_authorship(cur_author, authors)
    cur_author = data$aid[i]
    cur_pmid = data$pmid[i]
    authors = list(data$aid2[i])
  }
  else {
    authors = append(authors, data$aid2[i])
  }
  
}

# vectorized count to see how many unique sets for each author
count = unlist(lapply(author_sets, length))
summary = data.frame(aid = incomplete_summary$aid, name = incomplete_summary$name, total_number_authorships = incomplete_summary$`Total Number of Articles`, total_unique_groups = count)

# 1. Library (must be installed prior to loading
library(RMySQL)     ### MySQL

# 2. Settings
db_user <- 'root'
db_password <- 'Ch0uuF@n2022'
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

command = "CREATE TABLE authorship_star (
  aid INTEGER PRIMARY KEY,
  name TEXT NOT NULL, 
  total_number_authorships INTEGER NOT NULL,
  total_unique_groups INTEGER NOT NULL
)"

dbExecute(MySQL_dbcon, command)



dbWriteTable(MySQL_dbcon, 'authorship_star', summary, append = TRUE, row.names = FALSE)

############## Question 4


# create a view in SQLite db to query
command = "CREATE VIEW IF NOT EXISTS myView
            AS 

            SELECT jt.journal_title, p.year, p.month, a.pmid
              FROM journals j
              JOIN journal_titles jt ON j.jtid=jt.jtid
              JOIN pubdates p ON j.pdid = p.pdid
              LEFT JOIN articles a ON j.jid = a.jid
              ORDER BY jt.journal_title;"
dbExecute(dbcon, command)

# find the min and max years to bound the possible counts
max_year = dbGetQuery(dbcon, "SELECT MAX(year) FROM myView")[[1]]
min_year = dbGetQuery(dbcon, "SELECT MIN(year) FROM myView")[[1]]

# character vectors to build str of columns
year = c()
qrt = c()
mnth = c()

# populate the vectors
for (i in min_year:max_year) {
  year = c(year, paste0("Y",i))
  for (j in 1:12) {
    mnth = c(mnth, paste0("Y", i, "M", j))
  }
  for (j in 1:4) {
    qrt = c(qrt, paste0("Y", i, "Q", j))
  }
}
#year
#mnth
#qrt

#  all the possible entries of years, year-months and year-qtr within bounded years
entries = c(year, mnth, qrt)
#entries

num_entries = length(entries)
#num_entries

entries_dict = data.frame(entries, index = c(1:num_entries))

#entries_dict
temp_values = rep(0, num_entries + 1)
names(temp_values) = c("journal_name", entries)
#temp_values

# create a df from a list of names and values
journal_summary_df <- data.frame(as.list(temp_values))
#journal_summary_df
# remove the temp values
journal_summary_df = journal_summary_df[-1,]
#journal_summary_df


## start to build df for counts

command = "SELECT * FROM myView"
data = dbGetQuery(dbcon, command)

n = nrow(data)

curr_title = data$journal_title[1]
#curr_title

num_years = max_year - min_year + 1
num_months = 12
num_qrts = 4
data_entry = rep(0, num_entries)
#data_entry

# change to n later
for (i in 1: n) {
  #print(data$journal_title[i])
  if (curr_title !=  data$journal_title[i]) {
    #print(data_entry)
    #print(c(curr_title, data_entry))
    journal_summary_df[nrow(journal_summary_df) + 1,] = c(curr_title, data_entry)
    curr_title = data$journal_title[i]
    data_entry = rep(0, num_entries)
  }
  
  # increment the year
  data_entry[entries_dict$index[entries_dict$entries==paste0("Y", data$year[i])]] = data_entry[entries_dict$index[entries_dict$entries==paste0("Y", data$year[i])]] + 1
  # increment the month
  data_entry[entries_dict$index[entries_dict$entries==paste0("Y", data$year[i], "M", data$month[i])]] = data_entry[entries_dict$index[entries_dict$entries==paste0("Y", data$year[i], "M", data$month[i])]] + 1
  # increment the qrt
  data_entry[entries_dict$index[entries_dict$entries==paste0("Y", data$year[i], "Q", (data$month[i] - 1)%/%3 + 1)]] = data_entry[entries_dict$index[entries_dict$entries==paste0("Y", data$year[i], "Q", (data$month[i] - 1)%/%3 + 1)]] + 1
  
  
  
}
# with logic of for loop 
journal_summary_df[nrow(journal_summary_df) + 1,] = c(curr_title, data_entry)


# convert the dataframe data to numbers
i = c(1:num_entries + 1)
journal_summary_df[ , i] <- apply(journal_summary_df[ , i], 2, function(x) as.numeric(x))
#journal_summary_df

# cleaning up the data before loading onto the star db

n = nrow(journal_summary_df)
for (j in 1: n) {
  for (i in 1:num_years) {
    #print(journal_summary_df[j, 1+i])
    # the total number of articles for year j of entry i
    num_articles_year = journal_summary_df[j, 1+i]
    
    # calculate the indices to grab the range of months for the j year
    start_index_month = 1 + i + (num_years - i) + (i-1) * num_months + 1
    end_index_month = start_index_month + (num_months - 1)
    #print(journal_summary_df[j, start_index_month: end_index_month])
    
    # since the months of journals were calculated using the months, if the months have no entries, then the qtrs alsl have none.
    num_articles_months = sum(journal_summary_df[j, start_index_month: end_index_month])
    if (num_articles_months == 0) {
      journal_summary_df[j, start_index_month] = num_articles_year
    }
    
    start_index_qrt = 1 + i + (num_years - i) + num_years * num_months + (i-1) * num_qrts + 1
    end_index_qrt = start_index_qrt + (num_qrts - 1)
    #print(journal_summary_df[j, start_index_qrt])
    num_articles_qrt = sum(journal_summary_df[j, start_index_qrt:end_index_qrt])
    if (num_articles_qrt == 0) {
      journal_summary_df[j, start_index_qrt] = num_articles_year
    }
    
  }
  
}

# load into the MySQL db
dbWriteTable(MySQL_dbcon, 'journal_summary', journal_summary_df, append = TRUE, row.names = FALSE)
#dbReadTable(MySQL_dbcon, 'journal_summary')

dbDisconnect(dbcon)
dbDisconnect(MySQL_dbcon)
