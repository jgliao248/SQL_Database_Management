ReadMe
================

AUTHOR: JUSTIN LIAO  

EMAIL: JGLIAO248@GMAIL.COM

# Description:
This project contains two sub projects to showcase basic database management techniques using R and R studio. 

## Database Creation:
A raw `csv` file of bird strike data on aircrafts was parsed and inserted into a MySQL database server hosted by a Proxmox virtual machine. The sub project contains an `md` file that was exported to show the steps of extracting the data to create a relational database and more complex queries. 

## Database Mining:
This project contains R scripts used to parse an `XML` file of publications to perform datamining techniques. 
The project is divided into several parts:

- Load data into a relational database
- Create a star/snowflake schema database
- Explore and Mine Data

This project is used to showcase building a relational database from raw XML data, transfer that data into star schema datavase, and be able to get meaningful insight on the data querying the star schema databse. 

# Technology
- Proxmox: a hypervisor used to host a TurnKey container that manages a MySQL database. 
- R: primary scripting language to create the databases and parse the raw data into dataframes prior to populating the databases. 
- MySQL: relational database management system with more complex behaviors (stored procedures, stored functions, etc)
- SQLite: relational database management system with less complex behaviors