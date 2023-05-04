# Author: LIAO, JUSTIN
# Course: CS5200
# Term: FALL2022
# date 27Nov2022

# create the sqlite tables for use later
source("./CreateSQLiteTables.r")

# import the necessary functions to parse and store xml into dataframes
source("./LoadingXMLFunctions.r")

# create the blank dfs to be filled row by row

## Create blank author_df
author_df <- data.frame(aid = as.numeric(),
                        last_name = as.character(),
                        first_name = as.character(),
                        initials = as.character(),
                        suffix = as.character(),
                        collective_name = as.character(),
                        afid = as.numeric(),
                        valid = as.numeric())
## Create blank affiliation_df
affiliation_df = data.frame(
  afid = as.character(),
  affiliation = as.character()
)

## Create blank author_list_df
author_list_df = data.frame(
  pmid = as.numeric(), 
  aid = as.numeric(), 
  complete = as.numeric())

## Create blank journal_df
journal_df <- data.frame(jid = as.numeric(),
                         ISSN = as.character(),
                         cmid = as.numeric(),
                         volume = as.numeric(),
                         issue = as.numeric(),
                         pdid = as.character(),
                         jtid = as.numeric()
)

## Create ISSN_DF
ISSN_df = data.frame(
  ISSN = as.character(),
  ISSN_type = as.character()
)

## Create cited_mediums_df
cited_mediums_df = data.frame(
  cmid = c(1, 2),
  cited_medium = c("Print", "Internet")
)

## Create PubDates_df
pubdates_df = data.frame(
  pdid = as.numeric(), 
  year = as.character(), 
  month = as.character(),
  day = as.character(), 
  medline_date = as.character(),
  season = as.character()
)

## Make articles_df
articles_df = data.frame(
  pmid = as.numeric(),
  jid = as.numeric(), 
  article_title = as.character()
)

## Make articles_languages_df
articles_languages_df = data.frame(
  pmid = as.numeric(),
  lid = as.numeric()
)

## Make languages_df
languages_df = data.frame(
  lid = as.numeric(), 
  language = as.character()
)

## Make the journal_title_df
journal_titles_df = data.frame(
  jtid = as.numeric(), 
  journal_title = as.character(),
  iso_abbreviation = as.character()
)

# load and parse data
library(XML)

xmlFile <- "./pubmed-tfm-xml/pubmed22n0001-tf.xml"

xmlObj <- xmlParse(xmlFile, validate="T")

xpath = "//PubmedArticle"
articles <- xpathSApply(xmlObj, xpath)
x = xmlSize(articles)

for (i in 1: x) {

  process_article(articles[[i]])
  
}

# Load data into SQLite database
affiliation_df = transform(affiliation_df, afid = as.integer(afid))
#affiliation_df
dbWriteTable(dbcon, 'affiliations', affiliation_df, append = TRUE, row.names = FALSE)
#dbReadTable(dbcon, "affiliations")

articles_df = transform(articles_df, pmid = as.integer(pmid), jid = as.integer(jid))
#articles_df
dbWriteTable(dbcon, 'articles', articles_df, append = TRUE, row.names = FALSE)
#dbReadTable(dbcon, "articles")

articles_languages_df = transform(articles_languages_df, pmid = as.integer(pmid), lid = as.integer(lid))
#articles_languages_df
dbWriteTable(dbcon, 'articles_languages', articles_languages_df, append = TRUE, row.names = FALSE)
#dbReadTable(dbcon, "articles_languages")

author_df = transform(author_df, aid = as.integer(aid), afid = as.integer(afid))
#author_df
dbWriteTable(dbcon, 'authors', author_df, append = TRUE, row.names = FALSE)
#dbReadTable(dbcon, "authors")

author_list_df = transform(author_list_df, pmid = as.integer(pmid), aid = as.integer(aid))
#author_list_df
dbWriteTable(dbcon, 'author_list', author_list_df, append = TRUE, row.names = FALSE)
#dbReadTable(dbcon, "author_list")

# don't need to adjust types
#cited_mediums_df
dbWriteTable(dbcon, 'cited_mediums', cited_mediums_df, append = TRUE, row.names = FALSE)
#dbReadTable(dbcon, "cited_mediums")

# don't need to adjust
#ISSN_df
dbWriteTable(dbcon, 'ISSNS', ISSN_df, append = TRUE, row.names = FALSE)
#dbReadTable(dbcon, "ISSNS")

journal_df = transform(journal_df, jid = as.integer(jid), cmid = as.integer(cmid), volume = as.integer(volume), issue = as.integer(issue), pdid = as.integer(pdid), jtid = as.integer(jtid))
#journal_df
dbWriteTable(dbcon, 'journals', journal_df, append = TRUE, row.names = FALSE)
#dbReadTable(dbcon, "journals")

journal_titles_df = transform(journal_titles_df, jtid = as.integer(jtid))
#journal_titles_df
dbWriteTable(dbcon, 'journal_titles', journal_titles_df, append = TRUE, row.names = FALSE)
#dbReadTable(dbcon, "journal_titles")


languages_df = transform(languages_df, lid = as.integer(lid))
#languages_df
dbWriteTable(dbcon, 'languages', languages_df, append = TRUE, row.names = FALSE)
#dbReadTable(dbcon, "languages")


months = c(
  "Jan" = 1, 
  "01" = 1, 
  "Feb" = 2, 
  "02" = 2,   
  "Mar" = 3, 
  "03" = 3, 
  "Apr" = 4, 
  "04" = 4, 
  "May" = 5, 
  "05" = 5,
  "Jun" = 6, 
  "06" = 6,
  "Jul" = 7, 
  "07" = 7,
  "Aug" = 8, 
  "08" = 8,
  "Sep" = 9, 
  "09" = 9,
  "Oct" = 10, 
  "10" = 10,
  "Nov" = 11, 
  "11" = 11,
  "Dec" = 12, 
  "12" = 12
)


seasons = c(
  "Summer"= 6,
  "Spring"= 3,
  "Winter"= 12,
  "Fall" = 9
)

n = nrow(pubdates_df)
for (i in 1:n) {
  pubdates_df$month[i] = months[pubdates_df$month[i]]
  
  if ("NaN" != (pubdates_df$medline_date[i])){
    pubdates_df$year[i] = as.integer(substr(pubdates_df$medline_date[i], 1, 4))
    pubdates_df$month[i] = months[substr(pubdates_df$medline_date[i], 6, 8)][1]
  }
  
  if ("NaN" != (pubdates_df$season[i])){
    pubdates_df$month[i] = seasons[pubdates_df$season[i]][1]
  }
  
}

pubdates_df = transform(pubdates_df, pdid = as.integer(pdid), year = as.integer(year), month = as.integer(month), day = as.integer(day))
#pubdates_df
dbWriteTable(dbcon, 'pubdates', pubdates_df, append = TRUE, row.names = FALSE)
#dbReadTable(dbcon, "pubdates")

dbExecute(dbcon, "PRAGMA foreign_keys = ON")
dbDisconnect(dbcon)
