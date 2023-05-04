# Author: LIAO, JUSTIN
# Course: CS5200
# Term: FALL2022
# date 27Nov2022
# LoadingXMLFunctions.r


# This function takes a column vector data to compare to return a vector of T/F of the same length
compare_data <- function(dataset, data) {
  # need to do this for NA and NaN values
  if (is.na(data) | is.nan(data)) {
    #print(is.na(dataset))
    return (is.na(dataset))
  }
  else {
    #print(dataset == data)
    return(dataset == data)
  }
  
}

# This function processes the author data of the xml file.
# In input data is a list that stores the relevent author data and stores it 
# into the author_df dataframe. It will return the author id from the dataframe
process_author <- function(author_data) {
  #print(author_data)
  filtered_author = author_df[
    compare_data(author_df["last_name"], author_data[1]) &
      compare_data(author_df["first_name"], author_data[2]) &
      compare_data(author_df["initials"], author_data[3]) &
      compare_data(author_df["suffix"], author_data[4]) &
      compare_data(author_df["collective_name"], author_data[5]) &
      compare_data(author_df["afid"], author_data[6]) &
      compare_data(author_df["valid"], author_data[7]),
  ]
  
  # checking if the entry exists to see if it needs to be inputted into the df
  if (!is.null(filtered_author) & length(filtered_author != 0)) {
    #print("matched")
    return (filtered_author[1])
  }
  else {
    #print("does not exist")
    data = c(nrow(author_df) + 1, unlist(author_data))
    #print(data)
    author_df[nrow(author_df) + 1,] = c(data)
    author_df <<- author_df
    return (nrow(author_df))
  }
  print("not right")
}


# This function processes an affiliation node of the parent author node
# Returns the corresponding affiliation id of that author. 
process_affiliation <- function(affiliation_node) {
  
  affiliation = xmlValue(affiliation_node[[1]])
  filtered_affiliation = affiliation_df[compare_data(affiliation_df$affiliation,affiliation),]
  
  if (!is.null(filtered_affiliation) & length(filtered_affiliation != 0)) {
    #return (list(filtered_affiliation[1], affiliation_df))
    return (filtered_affiliation[1])
  }
  else {
    #print("affiliation does not exist")
    data = c(nrow(affiliation_df) + 1, unlist(affiliation))
    #print(data)
    affiliation_df[nrow(affiliation_df) + 1,] = c(data)
    affiliation_df <<- affiliation_df
    return (nrow(affiliation_df))
  }
  print("not right")
}

# this function processes an author_list node in the xml file. 
# this function only appends inputs to the author_list df based on the pmid. 

process_author_list <-function(author_list_node, pmid) {
  m = xmlSize(author_list_node)
  #  loop is based on the size number of children nodes
  for (j in 1:m){
    #print(author_lists[[i]][[j]])
    author_info = xmlChildren(author_list_node[[j]])
    author_data = c(NaN, NaN, NaN, NaN, NaN, NaN, xmlAttrs(author_list_node[[j]])[[1]])
    # last_name, first_name, initials, suffix, collective_name, afid, verified
    for (k in 1:xmlSize(author_info)) {

      element_name = xmlName(author_info[[k]])

      if (element_name == "LastName") {
        author_data[[1]] = xmlValue(author_info[[k]])
      }
      else if (element_name == "ForeName") {
        author_data[[2]] = xmlValue(author_info[[k]])
      }
      else if (element_name == "Initials") {
        author_data[[3]] = xmlValue(author_info[[k]])
      }
      else if (element_name == "Suffix") {
        author_data[[4]] = xmlValue(author_info[[k]])
        #print(xmlValue(author_info[[k]]))
      }
      else if (element_name == "CollectiveName") {
        author_data[[5]] = xmlValue(author_info[[k]])
      }
      else if (element_name == "AffiliationInfo") {
        # need to pass in a node this time
        
        author_data[[6]] = process_affiliation(author_info[[k]])
        #affiliation_df = aff_result[[2]]
      }
      
    }
    author_result = process_author(author_data)
    
    author_list_df[nrow(author_list_df) + 1,] = c(pmid, author_result, xmlAttrs(author_list_node)[[1]])
    author_list_df <<- author_list_df
    
  }
}

## This function processes the ISSN node and inputs it into the issn dataframe
# Does not return any values. ISSN is only unique based on the print and name of the journal
# and not the volume or issue. More information regarding how titles and ISSNs are connected is needed. 
# The ISSN is referenced in the ISSN dataframe with itself and the type of publication. 
# 
process_ISSN <- function(ISSN_node) {
  issn = xmlValue(ISSN_node)
  issn_type = xmlAttrs(ISSN_node)[[1]]
  
  ISSN_df[nrow(ISSN_df) + 1, ] = c(issn, issn_type)
  ISSN_df <<- unique(ISSN_df)
}

# This function returns the appropriate cited_medium type id based on the cited_medium_df.
# Though there are only two types current (print and internet), it allows for expansion in the future if needed. 
# 
process_cited_medium <- function(cited_medium_value) {
  
  filtered_cited_medium = cited_mediums_df$cmid[compare_data(cited_mediums_df$cited_medium, cited_medium_value)]
  
  if (!is.null(filtered_cited_medium) & length(filtered_cited_medium != 0)) {
    return (filtered_cited_medium[1])
  }
  else {
    cited_mediums_df[nrow(cited_mediums_df) + 1,] = c(nrow(cited_mediums_df) + 1, cited_medium_value)
    cited_mediums_df <<- cited_mediums_df
    return (nrow(cited_mediums_df))
    
  }
}

# This function processes the journal issue. Since the jid is the PK that can identify all the attributes of a
# a journal, the data is parsed and placed into a list for later use in the process journal_function. 
# this function returns the of the journal issue data
process_journal_issue <- function(journal_issue_node) {
  m = xmlSize(journal_issue_node)
  journal_issue_data = c(NaN, NaN, NaN, NaN)
  # cmid, volume, issue, pdid

  journal_issue_data[1] <- process_cited_medium(xmlAttrs(journal_issue_node))
  for (j in 1:m) {
    element_name = xmlName(journal_issue_node[[j]])
    if (element_name == "Volume") {
      journal_issue_data[2] = xmlValue(journal_issue_node[[j]])
    }
    else if (element_name == "Issue") {
      journal_issue_data[3] = xmlValue(journal_issue_node[[j]])
    }
    else if (element_name == "PubDate") {
      journal_issue_data[4]  = process_date(journal_issue_node[[j]])
    }
  }
  return (journal_issue_data)
}

# This function processes the publication dates of the journal. Since the 
# dates are not standardized accross journals, all possible forms are considered. 
# this function returns the corresponding pk of the date
process_date <- function(pubdate_node) {
  #print("process date")
  m = xmlSize(pubdate_node)
  date_data = c(NaN, NaN, NaN, NaN, NaN)
  # year, month, day, medline_date, season
  
  for (j in 1:m) {
    element_name = xmlName(pubdate_node[[j]])
    
    if (element_name == "Year") {
      date_data[1] = xmlValue(pubdate_node[[j]])
    }
    else if (element_name == "Month") {
      date_data[2] = xmlValue(pubdate_node[[j]])
    }
    else if (element_name == "Day") {
      date_data[3]  = xmlValue(pubdate_node[[j]])
    }
    else if (element_name == "MedlineDate") {
      date_data[4]  = xmlValue(pubdate_node[[j]])
    }
    else if (element_name == "Season") {
      date_data[5]  = xmlValue(pubdate_node[[j]])
      
    }
  }
  
  # need to filter the dates to find any possible entryes. 
  filtered_df = pubdates_df[
    compare_data(pubdates_df$year, date_data[1]) &
      compare_data(pubdates_df$month, date_data[2]) &
      compare_data(pubdates_df$day, date_data[3]) &
      compare_data(pubdates_df$medline_date, date_data[4]) &
      compare_data(pubdates_df$season, date_data[5]),
  ]
  
  
  # check if it exists already
  if (!is.null(filtered_df) & length(filtered_df != 0)) {
    
    return (filtered_df[1])
  }
  else {
    pubdates_df[nrow(pubdates_df) + 1,] = c(nrow(pubdates_df) + 1, unlist(date_data))
    pubdates_df <<- pubdates_df
    return (nrow(pubdates_df))
    
  }
}

# This function processes journal title and iso names and stores it in the journal_titles_df.
# It returns the unique pk corresponding to it. 
process_journal_names <- function(journal_title, journal_iso) {
  filtered_df = journal_titles_df[
    compare_data(journal_titles_df$journal_title, journal_title) &
      compare_data(journal_titles_df$iso_abbreviation, journal_iso),
  ]
  
  if (!is.null(filtered_df) & length(filtered_df != 0)) {
    return (filtered_df[1])
  }
  else {
    journal_titles_df[nrow(journal_titles_df) + 1,] = c(nrow(journal_titles_df) + 1, journal_title, journal_iso)
    
    journal_titles_df <<- journal_titles_df
    return (nrow(journal_titles_df))
  }
}

# This function proceses the journal_node of the xml file. It will return PK corresponding 
# to the journal from the journal_df. 
process_journal <- function(journal_node) {
  m = xmlSize(journal_node)
  journal_data <<- c(NaN, NaN, NaN, NaN, NaN, NaN)
  # issn, cmid, volume, issue, pdid, jtid
  journal_title = ""
  iso_abbreviation = ""
  # ISSN, cmid, volume, issue, pdid, journal_title, iso_abbreviation
  for (j in 1:m) {
    
    element_name = xmlName(journal_node[[j]])
    #print(element_name)
    if (element_name == "ISSN") {
      #print("process ISSN")
      journal_data[1] = xmlValue(journal_node[[j]]) # load issn
      process_ISSN(journal_node[[j]]) # add issn to issn_df
    }
    else if (element_name == "JournalIssue") {
      #print("process journalIssue")
      data = (process_journal_issue(journal_node[[j]]))
      #print(data)
      journal_data[[2]] = data[[1]]
      journal_data[[3]] = data[[2]]
      journal_data[[4]] = data[[3]]
      journal_data[[5]] = data[[4]]
      
    }
    else if (element_name == "Title") {
      journal_title = xmlValue(journal_node[[j]])
    }
    else if (element_name == "ISOAbbreviation") {
      iso_abbreviation = xmlValue(journal_node[[j]])
    }
  }
  # get jtid -> the id for the journal title
  journal_data[6] = process_journal_names(journal_title, iso_abbreviation)
  
  
  #print(journal_data)
  filtered_df = journal_df[
    compare_data(journal_df$ISSN, journal_data[[1]]) &
      compare_data(journal_df$cmid, journal_data[[2]]) &
      compare_data(journal_df$volume, journal_data[[3]]) &
      compare_data(journal_df$issue, journal_data[[4]]) & 
      compare_data(journal_df$pdid, journal_data[[5]]) &
      compare_data(journal_df$jtid, journal_data[[6]]),
  ] 
  #print(filtered_df)
  if (!is.null(filtered_df) & length(filtered_df != 0)) {
    
    return (filtered_df[1])
  }
  else {
    journal_df[nrow(journal_df) + 1,] = c(nrow(journal_df) + 1, unlist(journal_data))
    #print(cited_mediums_df)
    journal_df <<- journal_df
    return (nrow(journal_df))
  }
}

# This function processes the language node and stores it into the language_df
# and also stores the information regarding an article's pmid and language in the 
# articles_languages_df. Some articles might have two versions within the same 
# journal. 
process_language <- function(language_node, pmid) {
  language = xmlValue(language_node)

  filtered_df = languages_df[compare_data(languages_df$language, language),]

  # store into language_df
  if (!is.null(filtered_df) & length(filtered_df != 0)) {
    #print("should be in here")
    lid =  filtered_df[1,1]
  }
  else {
    languages_df[nrow(languages_df) + 1,] = c(nrow(languages_df) + 1,language)
    #print(cited_mediums_df)
    languages_df <<- languages_df
    lid =  nrow(languages_df)
  }
  
  # store into articles_language_df
  filtered_df = articles_languages_df[
    compare_data(articles_languages_df$lid, lid) &
      compare_data(articles_languages_df$pmid, pmid),
  ]

  if (!is.null(filtered_df) & length(filtered_df != 0)) {
    # does nothing
  }
  else {
    articles_languages_df[nrow(articles_languages_df) + 1,] = c(pmid, lid)
    articles_languages_df <<- articles_languages_df
    
  }
}

# this function processes the article node and extracts all the children nodes
# to store it into the respective data structures. 
process_article <- function(PubmedArticle_node) {
  article_node = PubmedArticle_node[[1]]
  m = xmlSize(article_node)
  article_data <<- c(NaN, NaN, NaN)
  # PMID, JID, article_title
  article_data[[1]] = xmlAttrs(PubmedArticle_node)[[1]]
  
  for (j in 1:m) {
    
    element_name = xmlName(article_node[[j]])
    
    if (element_name == "Journal") {
      article_data[[2]] = process_journal(article_node[[j]])
    }
    else if (element_name == "Language") {
      process_language(article_node[[j]], article_data[[1]])
      
    }
    else if (element_name == "ArticleTitle") {
      article_data[[3]] = xmlValue(article_node[[j]])
    }
    else if (element_name == "AuthorList") {
      process_author_list(article_node[[j]], article_data[[1]])
    }
  }
  
  # Check if it exists already. 
  filtered_df = articles_df[
    compare_data(articles_df$pmid, journal_data[1]) &
      compare_data(articles_df$jid, journal_data[2])&
      compare_data(articles_df$article_title, journal_data[3]),
  ] 

  if (!is.null(filtered_df) & length(filtered_df != 0)) {
    return (filtered_df[1])
  }
  else {
    articles_df[nrow(articles_df) + 1,] = c(unlist(article_data))
    articles_df <<- articles_df
    return (nrow(articles_df))
  }
}
