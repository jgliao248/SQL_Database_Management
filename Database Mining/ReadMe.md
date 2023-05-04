# SQL-Data-Warehouse

## Description: 
This project contains R scripts used to parse an XML file of publications to perform datamining techniques. 
The project is divided into several parts:

- Load data into a relational database
- Create a star/snowflake schema database
- Explore and Mine Data

This project is used to showcase building a relational database from raw XML data, transfer that data into star schema datavase, and be able to get meaningful insight on the data querying the star schema databse. 

## Load Data into a Relational Database:

For this part of the project, the xml file is contains data regarding publications. This file did not initially have a `dtd` file associated with it that gives the raw data some meta data to start the processing. Therefore, the data was analyzed and the structure is captued in the inline dtd description. 

A noralized relational data schema was created based on the data that was given in the xml file. Afterwards, the data is loaded and processed in data frames. The dataframes were used to popilate the tables in a SQLite database. 

Files: 
- `CreateSQLiteTables.r`: creates the normalized tables
- `LoadingXMLFunctions.r`: contains helper methods for parsing the given xml file
- `LoadXML2DB.r`: loads the data from the xml file to the SQLite database

## Create a star/snowflake schema database:
The purpose of creating a star/snowflake schema is to get more insight on the data contained in a database by strategically removing the normalization from a relational database to link ideas with each other. Though querying can be slower with this type of structure, it is useful to grab complete information easily for a single entity. This is particularly useful for management level individual to use to make quick decisions. 

Files:
- `LoadDataWarehouse.r`: Reads data from the SQLite database and stores it into a MySQL database

## Explore and Mine Data
This portion of the project showcases the power and advantage of a snowflake schema to easily grab aggregated data 

Files:
AnalyzeData.md
