# Author: LIAO, JUSTIN
# Course: CS5200
# Term: FALL2022
# date 27Nov2022
# CreateSQLiteTables.r

library(RSQLite)

fpath = ""
dbfile = "pubmed_articles.sqlite"

dbcon <- dbConnect(RSQLite::SQLite(), paste0(fpath, dbfile))



command = "DROP TABLE IF EXISTS affiliations"

dbExecute(dbcon, command)

command = "CREATE TABLE affiliations (
            afid INTEGER PRIMARY KEY AUTOINCREMENT, 
            affiliation TEXT
          )"

dbExecute(dbcon, command)

command = "DROP TABLE IF EXISTS authors"

dbExecute(dbcon, command)

command = "CREATE TABLE authors (
            aid INTEGER PRIMARY KEY AUTOINCREMENT, 
            last_name TEXT, 
            first_name TEXT, 
            initials TEXT, 
            suffix TEXT, 
            collective_name TEXT, 
            afid INTEGER,
            valid INTEGER, 
            FOREIGN KEY(afid) REFERENCES affiliations(afid)
          )"

dbExecute(dbcon, command)

command = "DROP TABLE IF EXISTS languages"

dbExecute(dbcon, command)

command = "CREATE TABLE languages (
            lid INTEGER PRIMARY KEY, 
            language Text
          )"

dbExecute(dbcon, command)

command = "DROP TABLE IF EXISTS ISSNS"

dbExecute(dbcon, command)

command = "CREATE TABLE ISSNS (
            ISSN TEXT PRIMARY KEY, 
            ISSN_type TEXT
          )"

dbExecute(dbcon, command)

command = "DROP TABLE IF EXISTS pubdates"

dbExecute(dbcon, command)

command = "CREATE TABLE pubdates (
            pdid INTEGER PRIMARY KEY AUTOINCREMENT, 
            year INTEGER,
            month INTEGER, 
            day INTEGER, 
            medline_date TEXT,
            season TEXT
          )"

dbExecute(dbcon, command)

command = "DROP TABLE IF EXISTS journal_titles"
dbExecute(dbcon, command)

command = "CREATE TABLE journal_titles (
            jtid INTEGER PRIMARY KEY AUTOINCREMENT,
            journal_title TEXT,
            iso_abbreviation TEXT
          )"
dbExecute(dbcon, command)


command = "DROP TABLE IF EXISTS journals"

dbExecute(dbcon, command)

command = "CREATE TABLE journals (
            jid INTEGER PRIMARY KEY AUTOINCREMENT, 
            ISSN TEXT,
            cmid INTEGER, 
            volume INTEGER, 
            issue INTEGER,
            pdid INTEGER,
            jtid INTEGER,
            FOREIGN KEY(ISSN) REFERENCES ISSNS(ISSN), 
            FOREIGN KEY(pdid) REFERENCES pubdates(pdid), 
            FOREIGN KEY(cmid) REFERENCES cited_mediums(CMID)
            FOREIGN KEY(jtid) REFERENCES journal_titles(jtid)
          )"

dbExecute(dbcon, command)

command = "DROP TABLE IF EXISTS cited_mediums"

dbExecute(dbcon, command)

command = "CREATE TABLE cited_mediums (
            cmid INTEGER PRIMARY KEY AUTOINCREMENT, 
            cited_medium TEXT
          )"

dbExecute(dbcon, command)

command = "DROP TABLE IF EXISTS articles"

dbExecute(dbcon, command)

command = "CREATE TABLE articles (
            pmid INTEGER PRIMARY KEY AUTOINCREMENT, 
            jid INTEGER NOT NULL,
            article_title TEXT, 
            FOREIGN KEY(jid) REFERENCES journals(jid)
          )"

dbExecute(dbcon, command)

command = "DROP TABLE IF EXISTS articles_languages"

dbExecute(dbcon, command)

command = "CREATE TABLE articles_languages (
            pmid INTEGER NOT NULL, 
            lid INTEGER NOT NULL,
            FOREIGN KEY(pmid) REFERENCES articles(pmid), 
            FOREIGN KEY(lid) REFERENCES languages(lid)
          )"

dbExecute(dbcon, command)

command = "DROP TABLE IF EXISTS author_list"

dbExecute(dbcon, command)

command = "CREATE TABLE author_list (
            pmid INTEGER NOT NULL, 
            aid INTEGER NOT NULL,
            complete INTEGER NOT NULL,
            FOREIGN KEY(pmid) REFERENCES articles(pmid), 
            FOREIGN KEY(aid) REFERENCES authors(aid)
          )"

dbExecute(dbcon, command)