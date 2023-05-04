ReadMe
================

AUTHOR: JUSTIN LIAO  

EMAIL: JGLIAO248@GMAIL.COM

This notebook contains Practicum I that implements a relational database
for FAA data set regarding bird strikes onto aircrafts. The database is
created using a TurnKey container
(<https://www.turnkeylinux.org/database>) on a Proxmox hypervisor that
implements MySQL. For this implementation of the database, the SSL was
turned off in the database settings.

The contents of this `md` file is written in a r notebook (RMD format)
and exported into `md`. The contents of this file goes through
connecting to a database, creating the tables, processing data from a
`.csv` file, populating the data into the tables with stored procedures,
and querying the data.

# Setting up R Notebook Environment

## Connect to MySQL database

``` r
# 1. Library (must be installed prior to loading
library(RMySQL)     ### MySQL
```

    ## Loading required package: DBI

``` r
# 2. Settings
db_user <- 'remote'
# use more secured password
db_password <- 'sqlP@$$$'
db_name <- 'BirdStrikeDB'

# replace with localhost or another local IP
db_host <- '192.168.1.179' 
db_port <- 3306 # always this port unless you change it during installation

# 3. Connect to DB
dbcon <-  dbConnect(MySQL(), user = db_user, password = db_password,
                 dbname = db_name, host = db_host, port = db_port)


# allow for local file edits
command = "set global local_infile=true;"
dbExecute(dbcon, command)
```

    ## [1] 0

## Load data from csv file into r dataframe

``` r
df = read.csv("BirdStrikesData-V2.csv", stringsAsFactors = FALSE)
```

## Reset Database

``` r
# need to turn off to delete easily
command = "SET FOREIGN_KEY_CHECKS = 0;"

dbExecute(dbcon, command)
```

    ## [1] 0

``` r
command = "SET GLOBAL log_bin_trust_function_creators = 1;"
dbExecute(dbcon, command)
```

    ## [1] 0

``` r
tables = dbGetQuery(dbcon, "SHOW TABLES")$Tables_in_BirdStrikeDB
if (length(tables) != 0) {
  print("Tables found deleting...")
  for (i in 1:length(tables)) {
    print(paste0("Dropping table: ", tables[i]))
    dbExecute(dbcon, paste0("DROP TABLE IF EXISTS ", tables[i], ";"))
  }
} else {
  print("There were no tables to delete")
}
```

    ## [1] "Tables found deleting..."
    ## [1] "Dropping table: aircraftTypes"
    ## [1] "Dropping table: aircrafts"
    ## [1] "Dropping table: airlines"
    ## [1] "Dropping table: airports"
    ## [1] "Dropping table: conditions"
    ## [1] "Dropping table: flightPhases"
    ## [1] "Dropping table: incidents"
    ## [1] "Dropping table: states"

``` r
#turn back on to enforce foreign keys
command = "SET FOREIGN_KEY_CHECKS = 1;"

dbExecute(dbcon, command)
```

    ## [1] 0

``` r
rm(tables)
```

# Part 1: Database Schema Definition

## airports table

The airport table is created with the following format: airports(aid,
airportName, airportCode, state). The data indicates that there are
sometimes no name for airports because it appears that helicopter pads
might not have a name and/or located at an airport. Therefore, there is
a chance that the airport is UNKNOWN but the state in which it is
located is known. Therefore, the decision was made to clearly identify
any possible combination of UNKNOWN airport with a KNOWN state
(i.e. UNKNOWN - MA is distinct from UNKNOWN - CT).

### states

Before the airports table is constructed, the states table must be made.
The state is a VARCHAR type primary key that holds the state’s full name
(i.e. MASSACHUSETTS INSTEAD OF MA)

``` r
command = "DROP TABLE IF EXISTS states;"
dbExecute(dbcon, command)
```

    ## [1] 0

``` r
command = "
          CREATE TABLE states (
            state VARCHAR(256) PRIMARY KEY
          );
          "
dbExecute(dbcon, command)
```

    ## [1] 0

## Constructing the airports table

airports(aid, airportName, airportCode, state). aid is a synthetic
primary key, airportName and state are the airport name and state from
the data file. The airport code should be the airport’s international
code, e.g., BOS for Boston or LGA for LaGuardia. However, you may leave
it empty for this database – it is for future expansion.

The airports table is linked to the states table (look up table). A
UNIQUE constraint is used for the airportCode because no two airports
should have the same code. Null is allowed for this attribute because
some locations might not have an airport code. A UNIQUE constraint is
used for the pair values of airportName and state because there should
be a distinct difference between two airports.

``` r
command = "DROP TABLE IF EXISTS airports;;"
dbExecute(dbcon, command)
```

    ## [1] 0

``` r
command = "
          CREATE TABLE airports (
            aid INTEGER PRIMARY KEY AUTO_INCREMENT,
            airportName VARCHAR(256) NOT NULL,
            state VARCHAR(256) NOT NULL,
            airportCode VARCHAR(256) UNIQUE,
            
            UNIQUE(airportName, state), 
            FOREIGN KEY (state) REFERENCES states(state)
          );
          "
dbExecute(dbcon, command)
```

    ## [1] 0

## conditions table

Create a lookup table conditions(cid, condition, explanation) and link
this lookup table to the incidents table with the conditions foreign
key. This table contains the value of all conditions, e.g., ‘Overcast’.
Leave the explanation column empty (future expansion).

``` r
command = "DROP TABLE IF EXISTS conditions;"
dbExecute(dbcon, command)
```

    ## [1] 0

Though assignment calls for ‘condition’ as a column name, ‘cond’ must be
used because ‘condition’ is a reserved word. Each entry in this table
should be unique because a the primary key must be unique per condition
and no explanation should be explaining two conditions.

``` r
command = "
          CREATE TABLE conditions (
            cid INTEGER PRIMARY KEY AUTO_INCREMENT,
            cond VARCHAR(256) NOT NULL,
            explanation VARCHAR(256),
            UNIQUE(cid, cond, explanation)
          );
          "
dbExecute(dbcon, command)
```

    ## [1] 0

## Harmonize flightphases

### Harmonizing dictionary and data frame.

A dictionary is created so that when the incidents table is made, a
simple reference to this dictionary should convert the raw data to the
harmonized data. The data frame is craeted to load the table.

``` r
unique(df$flight_phase)
```

    ## [1] "Climb"        "Landing Roll" "Approach"     "Take-off run" "Descent"     
    ## [6] ""             "Taxi"         "Parked"

``` r
# create a dictionary to harmonize dataframe

flight_phase_dict = c()
flight_phase_dict["CLIMB"] <- "INFLIGHT"
flight_phase_dict["LANDING ROLL"] <- "LANDING"
flight_phase_dict["APPROACH"] <- "LANDING"
flight_phase_dict["TAKE-OFF RUN"] <- "TAKEOFF"
flight_phase_dict["DESCENT"] <- "LANDING"
flight_phase_dict["TAXI"] <- "TAKEOFF"
flight_phase_dict["PARKED"] <- "LANDING"
flight_phase_dict[""] <- "UNKNOWN"

unique(flight_phase_dict)
```

    ## [1] "INFLIGHT" "LANDING"  "TAKEOFF"  "UNKNOWN"

``` r
flight_phase_df = data.frame("fpid" = unique(flight_phase_dict))
flight_phase_df
```

    ##       fpid
    ## 1 INFLIGHT
    ## 2  LANDING
    ## 3  TAKEOFF
    ## 4  UNKNOWN

``` r
command = "DROP TABLE IF EXISTS flightPhases;"
dbExecute(dbcon, command)
```

    ## [1] 0

``` r
command = "
          CREATE TABLE flightPhases (
            fpid VARCHAR(256) PRIMARY KEY
          );
          "
dbExecute(dbcon, command)
```

    ## [1] 0

## 1.G: Remove all flight incidents pertaining to military

This step is completed here so that when data is processed later it
won’t include any military info.

``` r
# remove military related data
df = df[which(toupper(df$airline) != "MILITARY"),]
```

## Aircraft Types

There appears to be two different types of aircrafts: airplane and
hellicopter. Null values in the original dataset is a hellicopter

### Create aircraft_type_df

This dataframe is used as the primary source of data for the
aircraftTypes table in the database. This dataframe will also be used to
translate the text to acid PK.

``` r
# find unique values
original_aircraft_type = unique(df$aircraft)
# linking empty strings to HELLICOPTER
aircraftType = toupper(c(original_aircraft_type[1], "hellicopter"))

actid = c(1:length(original_aircraft_type))
aircraft_type_key_df = data.frame(actid, aircraftType, original_aircraft_type)

rm(original_aircraft_type, aircraftType, actid)

head(aircraft_type_key_df)
```

    ##   actid aircraftType original_aircraft_type
    ## 1     1     AIRPLANE               Airplane
    ## 2     2  HELLICOPTER

### creating aircraftTypes table

``` r
command = "DROP TABLE IF EXISTS aircraftTypes;"
dbExecute(dbcon, command)
```

    ## [1] 0

``` r
command = "
          CREATE TABLE aircraftTypes (
            actid INTEGER PRIMARY KEY AUTO_INCREMENT,
            aircraftType VARCHAR(256) UNIQUE NOT NULL
          );
          "
dbExecute(dbcon, command)
```

    ## [1] 0

### Populate aircraftTypes table

``` r
dbWriteTable(dbcon, 'aircraftTypes', aircraft_type_key_df[,1:2], append = TRUE, row.names = FALSE)
```

    ## [1] TRUE

``` r
#dbReadTable(dbcon, "aircraftTypes")
```

### aircrafts

There are several model types that were repeated in the csv file. This
data was abstracted out to a lookup table with the model names of the
aircrafts. This table will give each combination of aircraft type and
model a unique artificial number. The aircraft type is either airplane
or helicopter.

``` r
command = "DROP TABLE IF EXISTS aircrafts;"
dbExecute(dbcon, command)
```

    ## [1] 0

``` r
command = "
          CREATE TABLE aircrafts (
            acid INTEGER PRIMARY KEY AUTO_INCREMENT,
            actid INTEGER NOT NULL,
            model TEXT NOT NULL,
            FOREIGN KEY (actid) REFERENCES aircraftTypes (actid),
            UNIQUE(acid, actid)
          );
          "
dbExecute(dbcon, command)
```

    ## [1] 0

## airlines

Airlines are stored as a lookup table with the artificial primary key as
the the alid and a unique varchar storing the airline names.

``` r
command = "DROP TABLE IF EXISTS airlines;"
dbExecute(dbcon, command)
```

    ## [1] 0

``` r
command = "
          CREATE TABLE airlines (
            alid INTEGER PRIMARY KEY AUTO_INCREMENT,
            airline VARCHAR(256) UNIQUE NOT NULL
          );
          "
dbExecute(dbcon, command)
```

    ## [1] 0

## incidents table

The incidents table must be made after the definition of the supporting
schema because this table references their unique identifiers for
several attributes.

incidents(rid, date, origin, airline, aircraft, flightPhase, altitude,
conditions, warning). For warning, MySQL does not explicitly support
booleans. Therefore, tiny int is used where 0 is false and 1 is true.

``` r
command = "DROP TABLE IF EXISTS incidents;"
dbExecute(dbcon, command)
```

    ## [1] 0

There are several foreign keys that this table references. The airports,
airlines, aircrafts, and conditions are referenced with the respective
unique artificial primary key identifiers. The flightphase is a unique
varchar. Almost all the attributes are default not null with the
exception of flight altitude which is default 0. For airports, airlines,
aircrafts, and conditions, if the data is unknown, then it is set to
their respective id representing ‘UNKNOWN’. Altitude ia allowed to be
negative because there are some airports/airfields where the altitude is
lower than the reference sea level.

``` r
command = "
          CREATE TABLE incidents (
            rid INTEGER PRIMARY KEY AUTO_INCREMENT,
            dates DATE NOT NULL,
            origin INTEGER NOT NULL,
            airline INTEGER NOT NULL,
            aircraft INTEGER NOT NULL, 
            flightPhase VARCHAR(256) DEFAULT \"UNKNOWN\", 
            altitude INTEGER DEFAULT 0, 
            conditions INTEGER NOT NULL, 
            warning TINYINT NOT NULL,
            
            FOREIGN KEY (origin) REFERENCES airports(aid),
            FOREIGN KEY (airline) REFERENCES airlines(alid),
            FOREIGN KEY (aircraft) REFERENCES aircrafts(acid),
            FOREIGN KEY (conditions) REFERENCES conditions(cid),
            FOREIGN KEY (flightPhase) REFERENCES flightPhases(fpid)
          );
          "

dbExecute(dbcon, command)
```

    ## [1] 0

### Creating trigger

This trigger is used upon insertion of new data into the incident table.
Check value must be either 0 or 1. Check flightPhase makes sure that the
entered phase is one of the harmonized option. If the given is not one
of the 4 values, “UNKNOWN” is given.

``` sql
DROP TRIGGER IF EXISTS newIncident
```

``` sql
CREATE TRIGGER newIncident
  BEFORE INSERT ON incidents
  FOR EACH ROW
  BEGIN
      /* check warning values */
      IF NEW.warning >= 1 THEN
        SET NEW.warning = 1;
      ELSEIF NEW.warning < 1 THEN
        SET NEW.warning = 0;
      END IF;
      
      /* check flightPhase values */
      if (EXISTS(SELECT * FROM flightPhases WHERE fpid = UPPER(NEW.flightPhase))) = 1 THEN
        SET NEW.flightPhase = UPPER(NEW.flightPhase);
      ELSE
        SET NEW.flightPhase = "UNKNOWN";
      END IF;
      
      
  END;
```

# Part 2: Loading data.

## Aircraft Model

In the dataset, it describes the vehicle that the pilot is operating as
a type of aircraft and a model. Therefore, information regarding the
vehical will be stored as some sort of aircraft id, the type of
aircraft, and the model name. \### Models Dataframe The dataframe is
used to populate the MySQL dataframe and translate necessary
information.

``` r
# find the unique models of aircrafts
models <- unique(df$model)
# unique ids
aircraftID <- c(1:length(models))
# build model df before adjusting contents
model_df = data.frame(aircraft = df$aircraft, model = df$model) 
# remove duplicates
model_df <- model_df[!duplicated(model_df[ , c("model")]), ] 
# refer aircraft to aircraft id
model_df <- data.frame(acid = aircraftID, actid = aircraft_type_key_df$actid[match(model_df$aircraft, aircraft_type_key_df$original_aircraft_type)], model = model_df$model)


# check if empty model name exists
which(model_df$model == "")
```

    ## integer(0)

``` r
# check if empty model name exists
which(toupper(model_df$model) == "UNKNOWN" | model_df$model == "NA" | model_df$model == "N/A" | is.null(model_df$model))
```

    ## integer(0)

``` r
model_df
```

    ##     acid actid                model
    ## 1      1     1            B-737-400
    ## 2      2     1                MD-80
    ## 3      3     1                C-500
    ## 4      4     1         CL-RJ100/200
    ## 5      5     1                A-300
    ## 6      6     1           LEARJET-25
    ## 7      7     1                A-320
    ## 8      8     1              DC-9-30
    ## 9      9     1                A-330
    ## 10    10     1          FOKKER F100
    ## 11    11     1                C-421
    ## 12    12     1                C-560
    ## 13    13     1            B-737-200
    ## 14    14     1              DC-9-50
    ## 15    15     1                B-737
    ## 16    16     1            B-737-300
    ## 17    17     1             SAAB-340
    ## 18    18     1                MD-82
    ## 19    19     1           HAWKER 800
    ## 20    20     1   FOKKER F28 MK 1000
    ## 21    21     1            B-757-200
    ## 22    22     1              EMB-135
    ## 23    23     1              DC-9-40
    ## 24    24     1            B-727-200
    ## 25    25     1             DC-10-30
    ## 26    26     1              DC-9-10
    ## 27    27     1              EMB-145
    ## 28    28     1          B-747-1/200
    ## 29    29     1                 DC-9
    ## 30    30     1            B-737-500
    ## 31    31     1            B-737-700
    ## 32    32     1            B-747-400
    ## 33    33     1         BE-58  BARON
    ## 34    34     1            B-767-300
    ## 35    35     1                DC-10
    ## 36    36     1         PA-31 NAVAJO
    ## 37    37     1                B-727
    ## 38    38     1                C-172
    ## 39    39     1         BA-31 JETSTR
    ## 40    40     1           LEARJET-35
    ## 41    41     1                MD-88
    ## 42    42     1              BE-1900
    ## 43    43     1             IAI-1124
    ## 44    44     1           LEARJET-31
    ## 45    45     1                C-402
    ## 46    46     1           SHORTS SC7
    ## 47    47     1            B-737-800
    ## 48    48     1                A-319
    ## 49    49     1          CITATION II
    ## 50    50     1               ATR-72
    ## 51    51     1         DA-20 FALCON
    ## 52    52     1          BE-400 BJET
    ## 53    53     1              DA-2000
    ## 54    54     1    HAWKER-SDLY HS125
    ## 55    55     1                B-767
    ## 56    56     1          HAWKER 1000
    ## 57    57     1                PA-28
    ## 58    58     1      BE-23 SUNDOWNER
    ## 59    59     2             BELL-206
    ## 60    60     1          DHC8 DASH 8
    ## 61    61     1          BE-90  KING
    ## 62    62     1            B-767-200
    ## 63    63     1               BA-146
    ## 64    64     1         GULFAERO III
    ## 65    65     1          BE-300 KING
    ## 66    66     1                  MU2
    ## 67    67     1              DORNIER
    ## 68    68     1          BE-200 KING
    ## 69    69     1         BA-41 JETSTR
    ## 70    70     1                A-310
    ## 71    71     1              EMB-110
    ## 72    72     1            B-767-400
    ## 73    73     1         DA-10 FALCON
    ## 74    74     1                C-208
    ## 75    75     1              EMB-120
    ## 76    76     1   PA-31T CHEYENNE II
    ## 77    77     1         DA-50 FALCON
    ## 78    78     1         RKWLTRBO 690
    ## 79    79     1          DORNIER 328
    ## 80    80     1           LEARJET-60
    ## 81    81     1            B-777-200
    ## 82    82     1         RKWL SABRLNR
    ## 83    83     1           CL-601/604
    ## 84    84     1           AVRO RJ 85
    ## 85    85     1           SHORTS 360
    ## 86    86     1              DC-8-70
    ## 87    87     1         PILATUS PC12
    ## 88    88     1               CL-600
    ## 89    89     1               DA-900
    ## 90    90     1                MD-83
    ## 91    91     1           LEARJET-45
    ## 92    92     1          GULFAERO IV
    ## 93    93     1           CITATION X
    ## 94    94     1       LOCKHEED C-130
    ## 95    95     1             IAI 1126
    ## 96    96     1            B-717-200
    ## 97    97     1                C-650
    ## 98    98     1         C-210 CENTUR
    ## 99    99     1   SA227 AC METRO III
    ## 100  100     1          RKWL SHRIKE
    ## 101  101     1  PA-30 TWIN COMANCHE
    ## 102  102     1        LOCKHEED 1329
    ## 103  103     1         C-182 SKYLAN
    ## 104  104     1                C-150
    ## 105  105     1                MD-11
    ## 106  106     1                C-152
    ## 107  107     1                C-310
    ## 108  108     1                B-747
    ## 109  109     1      FAIRCHILD SA227
    ## 110  110     1                A-340
    ## 111  111     1            B-727-100
    ## 112  112     1              DC-8-63
    ## 113  113     1      PA-31T CHEYENNE
    ## 114  114     1       PA-24 COMANCHE
    ## 115  115     1           LEARJET-55
    ## 116  116     1         MOONEY-20B/C
    ## 117  117     1         GLOBAL EXPRS
    ## 118  118     1         AYRES THRUSH
    ## 119  119     1                PA-32
    ## 120  120     1         DORNIER 328J
    ## 121  121     1            PA-23-250
    ## 122  122     1                BE-35
    ## 123  123     1             MD-90-30
    ## 124  124     1       PA-44 SEMINOLE
    ## 125  125     1         C-441 CONQUE
    ## 126  126     1             DC-10-10
    ## 127  127     1                BE-36
    ## 128  128     1               ATR-42
    ## 129  129     1         PA-34 SENECA
    ## 130  130     1         GULFSTRM 200
    ## 131  131     1               MU-300
    ## 132  132     1          BE-100 KING
    ## 133  133     1       BE-76  DUCHESS
    ## 134  134     1         BELLANCA CMP
    ## 135  135     1                C-414
    ## 136  136     1             CL-RJ700
    ## 137  137     1         BE-55  BARON
    ## 138  138     1          GULFSTRM II
    ## 139  139     1           SHORTS 330
    ## 140  140     1                B-757
    ## 141  141     1            B-757-300
    ## 142  142     1            B-737-900
    ## 143  143     1                G-159
    ## 144  144     1                C-550
    ## 145  145     1          CITATIONJET
    ## 146  146     1            MERLIN IV
    ## 147  147     1          LOCKHEED P3
    ## 148  148     1           BE-60 DUKE
    ## 149  149     1          CONVAIR 640
    ## 150  150     1                C-337
    ## 151  151     1           SABRLNR-65
    ## 152  152     1         PARTENAVIA68
    ## 153  153     1                A-321
    ## 154  154     1                A-318
    ## 155  155     1              EMB-170
    ## 156  156     1         IAI ASTRA JT
    ## 157  157     1                C-425
    ## 158  158     1            FOKKER 70
    ## 159  159     1                 DC-8
    ## 160  160     1                 DHC6
    ## 161  161     1                BE-99
    ## 162  162     1             CL-RJ900
    ## 163  163     1         C-185 SKYWAG
    ## 164  164     1              EMB-190
    ## 165  165     1                PITTS
    ## 166  166     1              CRJ-440
    ## 167  167     1         CITATION EXL
    ## 168  168     1                C-177
    ## 169  169     1                C-404
    ## 170  170     1             CITATION
    ## 171  171     1       CHALLENGER 300
    ## 172  172     2            AEROS 350
    ## 173  173     1                C-340
    ## 174  174     1           DIAMOND 42
    ## 175  175     1           IAI GALAXY
    ## 176  176     1         MISC - OTHER
    ## 177  177     1      CIRRUS SR 20/22
    ## 178  178     1         PA-46 MALIBU
    ## 179  179     1          CESSNA UNKN
    ## 180  180     1                C-320
    ## 181  181     1           BA-125-800
    ## 182  182     1      CAP AVION MUDRY
    ## 183  183     1            B-777-300
    ## 184  184     1           MOONEY-20J
    ## 185  185     1 CITATION MUSTANG 510
    ## 186  186     1        DA-200 FALCON
    ## 187  187     1         PIAGGIO P180
    ## 188  188     1                C-680
    ## 189  189     1                 DC-6
    ## 190  190     1                MD-87
    ## 191  191     1          DORNIER 228
    ## 192  192     1           BA-125-700
    ## 193  193     1           LEARJET-36
    ## 194  194     1          RKWL AC-680
    ## 195  195     1    CHAMPION CITABRIA
    ## 196  196     1           CASA C-212
    ## 197  197     1           HAWKER 900
    ## 198  198     1         GULFSTREAM V
    ## 199  199     1       B-747-8 SERIES
    ## 200  200     1         C-207 SKYWAG
    ## 201  201     1               BD-700
    ## 202  202     1          BE-65 QUEEN
    ## 203  203     1            PA-31-350
    ## 204  204     2          AEROS SA365
    ## 205  205     1            B-787-800
    ## 206  206     1         SOCATA TB-20
    ## 207  207     1         DA FALCON 7X
    ## 208  208     1         RAYTHEON 390
    ## 209  209     2               EC-135
    ## 210  210     1                HU-25
    ## 211  211     1                T-38A
    ## 212  212     1            HOMEBUILT
    ## 213  213     1           LEARJET-24
    ## 214  214     1                 AA-5
    ## 215  215     1           MOONEY M20
    ## 216  216     1   FOKKER F28 MK 4000
    ## 217  217     1               L-1011
    ## 218  218     1         VOLPARE BE18
    ## 219  219     1              DC-8-61
    ## 220  220     1         BELLANCA CIT
    ## 221  221     1             SA226 TC
    ## 222  222     1              GRUMMAN
    ## 223  223     1           MOONEY-20K
    ## 224  224     1         GRUMAMER AA5
    ## 225  225     1                BE-18
    ## 226  226     1                 DC-3
    ## 227  227     1         C-206 STATIO
    ## 228  228     1                BE-95
    ## 229  229     1             BELLANCA
    ## 230  230     1                BE-33
    ## 231  231     2           AGUSTA 109
    ## 232  232     1           MERLIN III
    ## 233  233     1          GRUMMAN GA7
    ## 234  234     1          MOONEY UNKN
    ## 235  235     1           BA-146-300
    ## 236  236     2         ROBINSON R22
    ## 237  237     1           DIAMOND 20
    ## 238  238     2           HUGHES 500
    ## 239  239     2               HH-60J
    ## 240  240     1         PA-23 APACHE
    ## 241  241     1       BE-77  SKIPPER
    ## 242  242     1            C-120/140
    ## 243  243     1          SABRLNR-80A
    ## 244  244     2        SIKORSKY S-70
    ## 245  245     1        PA-22 TP/COLT
    ## 246  246     1         LOCKHEED 382
    ## 247  247     1             EMB UNKN
    ## 248  248     1         RKWL CMDR114
    ## 249  249     1        SOCATA TBM700
    ## 250  250     1            PA-60 601
    ## 251  251     1             CANADAIR
    ## 252  252     1           FOKKER F27
    ## 253  253     1       PA-38 TOMAHAWK
    ## 254  254     2            MBB BK117
    ## 255  255     1            EXTRA 300
    ## 256  256     1            B-747-300
    ## 257  257     2        SIKORSKY S-76
    ## 258  258     1          AEROS SN601
    ## 259  259     1                 AA-1
    ## 260  260     1            PA-60 600
    ## 261  261     1          GRUMMAN G73
    ## 262  262     1                PA-42
    ## 263  263     1           DIAMOND 40
    ## 264  264     1                C-180
    ## 265  265     1         C-406 CARAVA
    ## 266  266     1           BA-146-200
    ## 267  267     1                C-195
    ## 268  268     1                PA-12
    ## 269  269     1               CL-215
    ## 270  270     1            AERONCA 7
    ## 271  271     1            B-737-100
    ## 272  272     1          DHC7 DASH 7
    ## 273  273     1          CHAMP 8KCAB
    ## 274  274     1            SAAB 2000
    ## 275  275     1       GIPPSLAND GA-8
    ## 276  276     1    AMD ALARUS CH2000
    ## 277  277     1         LAKE LA4-200
    ## 278  278     1                AG-5B
    ## 279  279     1     LANCAIR COLUMBIA
    ## 280  280     2         ROBINSON R44
    ## 281  281     2            AEROS 355
    ## 282  282     1         SOCATA TB-10
    ## 283  283     2               EC-130
    ## 284  284     2             BELL-407
    ## 285  285     1         G-164 AG CAT
    ## 286  286     1             ERCO 415
    ## 287  287     2          HUGHES 269A
    ## 288  288     1          ECLIPSE 500
    ## 289  289     1           SOCATA TB9
    ## 290  290     1          CONVAIR 340
    ## 291  291     1      PA-18 SUPER CUB
    ## 292  292     1         CESSNA LC-41
    ## 293  293     1    SA227 DC METRO 23
    ## 294  294     1    HELIO COURIER 800
    ## 295  295     1                C-305
    ## 296  296     2        AGUSTA AW 139
    ## 297  297     1         BN-2A ISLAND
    ## 298  298     2             BELL-430
    ## 299  299     1            MAULE M-7
    ## 300  300     1  GRUMMAN S-2 TRACKER
    ## 301  301     2                HH-65
    ## 302  302     2             BELL-412
    ## 303  303     2           BELL-205A1
    ## 304  304     2        SIKORSKY S-92
    ## 305  305     1               HC-130
    ## 306  306     1                T-38N
    ## 307  307     1               AT 301
    ## 308  308     1           PIPERSPORT
    ## 309  309     2               MD-900
    ## 310  310     1          DHC2 BEAVER
    ## 311  311     1                B-707
    ## 312  312     1                C-401
    ## 313  313     1                 T-38
    ## 314  314     1            B-737-600
    ## 315  315     1          HAWKER 4000
    ## 316  316     1             MD-90-10
    ## 317  317     1                A-380
    ## 318  318     1                BE-19
    ## 319  319     1         LEARJET UNKN
    ## 320  320     1       A-23 MUSKATEER
    ## 321  321     1         LOCKHEED P3A
    ## 322  322     1              CRJ-900
    ## 323  323     2           HUGHES 369
    ## 324  324     1        BELLANCA 1730
    ## 325  325     1                 GROB
    ## 326  326     1                C-303
    ## 327  327     1   FLIGHT DESIGN CTSW
    ## 328  328     1             CL-RJ705
    ## 329  329     1         PA-25 PAWNEE
    ## 330  330     2    EUROCOPTER BK 117
    ## 331  331     1              EMB 500
    ## 332  332     1         LIBERTY XL-2
    ## 333  333     2               EC-120
    ## 334  334     1               F/A-18
    ## 335  335     2             BELL-212
    ## 336  336     1                DA-40

### Populate aircrafts table

``` r
dbWriteTable(dbcon, 'aircrafts', model_df, append = TRUE, row.names = FALSE)
```

    ## [1] TRUE

``` r
#dbReadTable(dbcon, "aircrafts")
```

## states

``` r
state = toupper(unique(df$origin))

state = state[state != "N/A"]
state = c("UNKNOWN", state)
state_df = data.frame(state)
#state_df
```

``` r
dbWriteTable(dbcon, 'states', state_df, append = TRUE, row.names = FALSE)
```

    ## [1] TRUE

``` r
#dbReadTable(dbcon, "states")
```

## airports

``` r
# find all unique values
airports_df = unique(df[, c("airport", "origin")])

# find all values of empty data
airports_df[airports_df == ""] <- "UNKNOWN"
airports_df[airports_df == "N/A"] <- "UNKNOWN"
airports_df[is.null(airports_df)] <- "UNKNOWN"


airports_df = data.frame(aid =  c(1:nrow(airports_df)), airportName = toupper(airports_df$airport), state = toupper(airports_df$origin))
airports_df["airportCode"] <- NA

# check for unique unknowns

#airports_df[which(airports_df$airport == "UNKNOWN"), ]

airports_df
```

    ##       aid                                   airportName
    ## 1       1                                  LAGUARDIA NY
    ## 2       2                   DALLAS/FORT WORTH INTL ARPT
    ## 3       3                             LAKEFRONT AIRPORT
    ## 4       4                           SEATTLE-TACOMA INTL
    ## 5       5                                  NORFOLK INTL
    ## 6       6                           GUAYAQUIL/S BOLIVAR
    ## 7       7                             NEW CASTLE COUNTY
    ## 8       8                   WASHINGTON DULLES INTL ARPT
    ## 9       9                                  ATLANTA INTL
    ## 10     10                  ORLANDO SANFORD INTL AIRPORT
    
    ##                          state airportCode
    ## 1                     NEW YORK          NA
    ## 2                        TEXAS          NA
    ## 3                    LOUISIANA          NA
    ## 4                   WASHINGTON          NA
    ## 5                     VIRGINIA          NA
    ## 6                      UNKNOWN          NA
    ## 7                     DELAWARE          NA
    ## 8                           DC          NA
    ## 9                      GEORGIA          NA
    ## 10                     FLORIDA          NA
   

``` r
dbWriteTable(dbcon, 'airports', airports_df, append = TRUE, row.names = FALSE)
```

    ## [1] TRUE

``` r
#dbReadTable(dbcon, "airports")
```

## airlines

Create the dataframe that holds all the unique airlines in the data set.
“BUSINESS” is considered its own airline. “UNKNOWN” is already in the
dataset

``` r
# cleaning of special characters
df$airline = gsub("[^[:alnum:] ]", "", df$airline)

# change all "" into "UNKNOWN"
df$airline[which(df$airline == "")] = "UNKNOWN" 

airline = unique(df$airline)

airline = airline[which(airline != "")]
alid = c(1:(length(unique(airline))))
airlines_df = data.frame(alid, airline)

if (length(airlines_df$airline == "UNKNOWN") > 0) {
  print("UKNOWN exists")
}
```

    ## [1] "UKNOWN exists"

``` r
airlines_df
```

    ##     alid                           airline
    ## 1      1                        US AIRWAYS
    ## 2      2                 AMERICAN AIRLINES
    ## 3      3                          BUSINESS
    ## 4      4                   ALASKA AIRLINES
    ## 5      5                   COMAIR AIRLINES
    ## 6      6                   UNITED AIRLINES
    ## 7      7                   AIRTRAN AIRWAYS
    ## 8      8                     AIRTOURS INTL
    ## 9      9             AMERICA WEST AIRLINES
    ## 10    10            EXECUTIVE JET AVIATION
 

``` r
dbWriteTable(dbcon, 'airlines', airlines_df, append = TRUE, row.names = FALSE)
```

    ## [1] TRUE

``` r
#dbReadTable(dbcon, "airlines")
```

## Conditions

### Creating the conditions_DF

``` r
conditions = unique(df$sky_conditions)
cid = c(1:length(conditions))
print(cid)
```

    ## [1] 1 2 3

``` r
print(conditions)
```

    ## [1] "No Cloud"   "Some Cloud" "Overcast"

``` r
conditions_df <- data.frame(cid = cid, cond = toupper(conditions))
conditions_df["explanation"] <- NA

conditions_df
```

    ##   cid       cond explanation
    ## 1   1   NO CLOUD          NA
    ## 2   2 SOME CLOUD          NA
    ## 3   3   OVERCAST          NA

### Populate conditions table

``` r
dbWriteTable(dbcon, 'conditions', conditions_df, append = TRUE, row.names = FALSE)
```

    ## [1] TRUE

``` r
#dbReadTable(dbcon, "conditions")
```

### Populate flightPhases table

The dataframe was created in Question 1. The data is loaded here.

``` r
dbWriteTable(dbcon, 'flightPhases', flight_phase_df, append = TRUE, row.names = FALSE)
```

    ## [1] TRUE

``` r
#dbReadTable(dbcon, "flightPhases")
```

## Incidents

### Creating incidents data frame

Prior to importing the data into the incidents table, the data must be
cleaned and translated to reflect the unique foreign keys.

``` r
# remove columns not referenced in tables
delete_cols = c("wildlife_struck", "impact", "damage", "remains_collected_flag", "Remarks", "wildlife_size", "species", "heavy_flag")
df_truncated = df[,!(names(df)) %in% delete_cols]
df_truncated
```

    ##         rid aircraft                                       airport
    ## 1    202152 Airplane                                  LAGUARDIA NY
    ## 2    208159 Airplane                   DALLAS/FORT WORTH INTL ARPT
    ## 3    207601 Airplane                             LAKEFRONT AIRPORT
    ## 4    215953 Airplane                           SEATTLE-TACOMA INTL
    ## 5    219878 Airplane                                  NORFOLK INTL
    ## 6    218432 Airplane                           GUAYAQUIL/S BOLIVAR
    ## 7    221697 Airplane                             NEW CASTLE COUNTY
    ## 8    236635 Airplane                   WASHINGTON DULLES INTL ARPT
    ## 9    207369 Airplane                                  ATLANTA INTL
    ## 10   204371 Airplane                  ORLANDO SANFORD INTL AIRPORT
   
    ##                     model     flight_date                          airline
    ## 1               B-737-400 11/23/2000 0:00                       US AIRWAYS
    ## 2                   MD-80  7/25/2001 0:00                AMERICAN AIRLINES
    ## 3                   C-500  9/14/2001 0:00                         BUSINESS
    ## 4               B-737-400   9/5/2002 0:00                  ALASKA AIRLINES
    ## 5            CL-RJ100/200  6/23/2003 0:00                  COMAIR AIRLINES
    ## 6                   A-300  7/24/2003 0:00                AMERICAN AIRLINES
    ## 7              LEARJET-25  8/17/2003 0:00                         BUSINESS
    ## 8                   A-320   3/1/2006 0:00                  UNITED AIRLINES
    ## 9                 DC-9-30   1/6/2000 0:00                  AIRTRAN AIRWAYS
    ## 10                  A-330   1/7/2000 0:00                    AIRTOURS INTL
    
    ##                         origin flight_phase sky_conditions pilot_warned_flag
    ## 1                     New York        Climb       No Cloud                 N
    ## 2                        Texas Landing Roll     Some Cloud                 Y
    ## 3                    Louisiana     Approach       No Cloud                 N
    ## 4                   Washington        Climb     Some Cloud                 Y
    ## 5                     Virginia     Approach       No Cloud                 N
    ## 6                          N/A Take-off run       No Cloud                 N
    ## 7                     Delaware        Climb       No Cloud                 N
    ## 8                           DC     Approach     Some Cloud                 Y
    ## 9                      Georgia Take-off run     Some Cloud                 N
    ## 10                     Florida Landing Roll     Some Cloud                 N
   
    ##      altitude_ft
    ## 1          1,500
    ## 2              0
    ## 3             50
    ## 4             50
    ## 5             50
    ## 6              0
    ## 7            150
    ## 8            100
    ## 9              0
    ## 10             0
   

``` r
# Create the origin vector with the correct foreign key ids
origin <- airports_df$aid[match(c(df_truncated$airport, df_truncated$origin), c(airports_df$airportName, airports_df$state))]
#origin
#origin_test = data.frame(df_truncated$airport, df_truncated$origin, origin)
#origin_test

# Create the aircraft vector with the correct foreign key ids
aircraft <- model_df$acid[match(df_truncated$model, model_df$model)]
#aircraft
#aircraft_test = data.frame(df.original = aircraft_type_key_df$actid[match(df_truncated$aircraft, aircraft_type_key_df$original_aircraft_type)], df_truncated$model, aircraft)
#aircraft_test

# Create the airline vector with the correct foreign key ids
airline <- airlines_df$alid[match(df_truncated$airline, airlines_df$airline)]
#airline_test = data.frame(df_truncated$airline, airline)
#airline_test

# Create the conditions vector with formatting
conditions <- conditions_df$cid[match(toupper(df_truncated$sky_conditions), conditions_df$cond)]


# Create the altitude vector; removed comma separation in string then converting to an integer
altitude <- as.integer(gsub(",", "", df_truncated$altitude_ft))
#altitude

# Create the flightphase vector with the harmonized values
flightphase <- flight_phase_dict[toupper(df_truncated$flight_phase)]

# Create the date vector to only hold month, day, and year of incidents
dates <- as.Date(df_truncated$flight_date, "%m/%d/%Y")

# Create the rid vector
rid <- df_truncated$rid

# created the warn vector by translating "Y" -> 1 and "N" -> 0 as boolean values. 1 and 0 are used because there's no native support for booleans in MySQL
warn <- as.integer(ifelse(toupper(df_truncated$pilot_warned_flag) == "Y", 1, 0))

# combine adjusted vectors into the final truncated version
df_truncated_final <- data.frame(rid, dates, origin, airline, aircraft, flightphase, altitude, conditions, warning = warn)
df_truncated_final
```

    ##          rid      dates origin airline aircraft flightphase altitude conditions
    ## 1     202152 2000-11-23      1       1        1    INFLIGHT     1500          1
    ## 2     208159 2001-07-25      2       2        2     LANDING        0          2
    ## 3     207601 2001-09-14      3       3        3     LANDING       50          1
    ## 4     215953 2002-09-05      4       4        1    INFLIGHT       50          2
    ## 5     219878 2003-06-23      5       5        4     LANDING       50          1
    ## 6     218432 2003-07-24      6       2        5     TAKEOFF        0          1
    ## 7     221697 2003-08-17      7       3        6    INFLIGHT      150          1
    ## 8     236635 2006-03-01      8       6        7     LANDING      100          2
    ## 9     207369 2000-01-06      9       7        8     TAKEOFF        0          2
    ## 10    204371 2000-01-07     10       8        9     LANDING        0          2
   
    ##       warning
    ## 1           0
    ## 2           1
    ## 3           0
    ## 4           1
    ## 5           0
    ## 6           0
    ## 7           0
    ## 8           1
    ## 9           0
    ## 10          0
   

``` r
dbWriteTable(dbcon, 'incidents', df_truncated_final, append = TRUE, row.names = FALSE)
```

    ## [1] TRUE

``` r
# dbReadTable(dbcon, "incidents")
```

# Part 3: Showing tables after loading data

Below are the first 6 rows of the incidents table. The table is
automatically organizing the data based on the primary key rid. The rid
is kept kept an integer because all the rid entries are integers that do
not start with 0. Each entry is a non-null value. The occurence of when
the impact with wildlife happened was recorded as a date-time type that
was a string. This was coerced to a date type as described by the
assigment. The origin and airline are using artificial foreign keys that
link to a specific origin (i.e. an airport with a state) and an airline.
These keys are used instead of the actual names because it is possible
for airports and airlines to change names. By using artificial keys it
is easy to make updates. Aircrafts are stored as artificial integer keys
as well so that more models can easily be added and updated. It can hold
more inforation regarding the models if future expansion is needed. This
key also holds information regarding the type of aircraft such as
helicopter or airplane. The flight phases are harmonized based on
requirements. The altitude is stored as integers because the precision
beyond ft. The default value is 0 because if there is an incident and an
altitude is not recorded but a location is, then it is likely that it is
stationary at an airport. Conditions are stored as 1 of 3 conditions. It
allows room for expansion. Warning is stored as 1 for true and 0 for
false because there is no native support for boolean values on MySQL.

``` r
head(dbReadTable(dbcon, "incidents"))
```

    ##      rid      dates origin airline aircraft flightPhase altitude conditions
    ## 1 200011 2000-04-06     47      18      159     LANDING        0          3
    ## 2 200012 2000-04-10     94      54       42     LANDING        0          3
    ## 3 200022 2000-02-28      2      19       50     LANDING     2000          1
    ## 4 200023 2000-08-25     66       1       16     LANDING     7000          1
    ## 5 200028 2000-03-22    110       6       37     LANDING     3000          1
    ## 6 200029 2000-05-14     59     179       17     LANDING       30          1
    ##   warning
    ## 1       1
    ## 2       1
    ## 3       1
    ## 4       0
    ## 5       1
    ## 6       1

The aircrafts types are stored based to describe the type of aircraft
the different models could signify. Currently there are two types but
this allows for easy expansion and more description if needed in the
future.

``` r
head(dbReadTable(dbcon, "aircraftTypes"))
```

    ##   actid aircraftType
    ## 1     1     AIRPLANE
    ## 2     2  HELLICOPTER

The aircrafts are stored based on the type of aircraft and the model
number. This data set has distinction between helicopter and airplanes.
The aircraft id (acid) can be easily accessed by the incidents table.

``` r
head(dbReadTable(dbcon, "aircrafts"))
```

    ##   acid actid        model
    ## 1    1     1    B-737-400
    ## 2    2     1        MD-80
    ## 3    3     1        C-500
    ## 4    4     1 CL-RJ100/200
    ## 5    5     1        A-300
    ## 6    6     1   LEARJET-25

There are several conditions stored in the table. A cid is used to store
the different types of condition and their names and explanations. The
explanations are blank for expansion later.

``` r
head(dbReadTable(dbcon, "conditions"))
```

    ##   cid       cond explanation
    ## 1   1   NO CLOUD        <NA>
    ## 2   2 SOME CLOUD        <NA>
    ## 3   3   OVERCAST        <NA>

There are currently 4 harmonized definitions for flight phases. The
aircraft can either be taking off, landing, or inflight when it happens.
Otherwise it is unknown.

``` r
head(dbReadTable(dbcon, "flightPhases"))
```

    ##       fpid
    ## 1 INFLIGHT
    ## 2  LANDING
    ## 3  TAKEOFF
    ## 4  UNKNOWN

The states table is stored in this table to have a complete list of
states that are available when entering data regarding the location of
the airport. This table also includes “UNKNOWN” because it is possible
for inflight to be over seas where there are no states or for countries
without a state system.

``` r
head(dbReadTable(dbcon, "states"))
```

    ##              state
    ## 1          ALABAMA
    ## 2           ALASKA
    ## 3          ALBERTA
    ## 4          ARIZONA
    ## 5         ARKANSAS
    ## 6 BRITISH COLUMBIA

The unique airport names and states which they reside. It allows for
airportNames to be unknown but it must have a unique state associated
with it. For instance, it is possible for an unknown airport but be
within MA or another unknown airport within CT. This table lumps all
unknown airports to one state. Each combination of unknown but have a
unique state. The airportCode is kept empty for future expansion. The
aid is used as the primary key to signify a unique name state
combination. It is possible for two airports to share the same name but
not the same state. All airports must have unique codes.

``` r
head(dbReadTable(dbcon, "airports"))
```

    ##   aid                 airportName      state airportCode
    ## 1   1                LAGUARDIA NY   NEW YORK        <NA>
    ## 2   2 DALLAS/FORT WORTH INTL ARPT      TEXAS        <NA>
    ## 3   3           LAKEFRONT AIRPORT  LOUISIANA        <NA>
    ## 4   4         SEATTLE-TACOMA INTL WASHINGTON        <NA>
    ## 5   5                NORFOLK INTL   VIRGINIA        <NA>
    ## 6   6         GUAYAQUIL/S BOLIVAR    UNKNOWN        <NA>

The airlines are stored with an airline id (alid) and an airline name
associated with it. This table is to store specific names of airlines
and link it to a unique name of the airline. If the airline name
changes, when updating this table will suffice.

``` r
head(dbReadTable(dbcon, "airlines"))
```

    ##   alid                     airline
    ## 1  236 ABSA AEROLINHAS BRASILEIRAS
    ## 2   18                     ABX AIR
    ## 3  113                ACM AVIATION
    ## 4  168           ADI SHUTTLE GROUP
    ## 5  165                  AER LINGUS
    ## 6  241                    AERO AIR

# Part 4

Create a SQL query against your database to find the 10 airlines with
the greatest number of incidents.

``` sql
SELECT a.airline, COUNT(*) AS NumOfIncidents
  FROM incidents i
  JOIN airlines a ON i.airline = a.alid
  GROUP BY a.alid
  ORDER BY NumOfIncidents DESC
  LIMIT 10;
```

<div class="knitsql-table">

| airline                 | NumOfIncidents |
|:------------------------|---------------:|
| SOUTHWEST AIRLINES      |           4628 |
| BUSINESS                |           3074 |
| AMERICAN AIRLINES       |           2058 |
| DELTA AIR LINES         |           1349 |
| US AIRWAYS              |           1337 |
| AMERICAN EAGLE AIRLINES |            932 |
| SKYWEST AIRLINES        |            891 |
| JETBLUE AIRWAYS         |            708 |
| UPS AIRLINES            |            590 |
| UNITED AIRLINES         |            506 |

Displaying records 1 - 10

</div>

# Part 5

Create a SQL query against your database to find the flight phase that
had an above average number bird strike incidents (during any flight
phase).

``` sql

WITH s AS (SELECT i.flightPhase, COUNT(*) incidents
  FROM incidents i 
  JOIN flightPhases f ON i.flightPhase = f.fpid
  GROUP BY i.flightPhase)
SELECT s.flightPhase as PhasesWithGreaterThanAVGIncidents
  FROM s
  WHERE s.incidents > (SELECT AVG(s.incidents) FROM s);

  
```

<div class="knitsql-table">

| PhasesWithGreaterThanAVGIncidents |
|:----------------------------------|
| LANDING                           |

1 records

</div>

# Part 6

Create a SQL query against your database to find the number of bird
strike incidents by month (across all years). Include all airlines and
all flights. This query can help answer the question which month,
historically, is the most dangerous for bird strikes.

``` sql
SELECT MONTHNAME(i.dates) month, Count(*) incidents
  FROM incidents i
  GROUP BY month;
  
  
```

<div class="knitsql-table">

| month    | incidents |
|:---------|----------:|
| April    |      1819 |
| August   |      3704 |
| December |      1017 |
| February |       765 |
| January  |       933 |
| July     |      3264 |
| June     |      2070 |
| March    |      1229 |
| May      |      2307 |
| November |      1793 |

Displaying records 1 - 10

</div>

# Part 7

Build a line chart that visualizes the number of bird strikes incidents
per year from 2005 to 2011. Adorn the graph with appropriate axis
labels, titles, legend, data labels, etc.

``` r
command = "SELECT YEAR(i.dates) year, Count(*) incidents
          FROM incidents i
          GROUP BY year
          HAVING 2005 <= year AND year <= 2011
          ORDER BY year;"
summary = dbGetQuery(dbcon, command)
summary
```

    ##   year incidents
    ## 1 2005      1853
    ## 2 2006      2159
    ## 3 2007      2301
    ## 4 2008      2258
    ## 5 2009      3247
    ## 6 2010      3121
    ## 7 2011      2952

``` r
# possible rounding function
roundUp <- function(x, nice=c(1,2,4,5,6,8,10)) {
    if(length(x) != 1) stop("'x' must be of length 1")
    10^floor(log10(x)) * nice[[which(x <= 10^floor(log10(x)) * nice)[[1]]]]
}

# title of graph
title = "FAA Birdstrikes Incidents"

# load x and y values
x = summary$year
y = summary$incidents

# expansion of x 
xlim = c((min(x) - 1),(max(x) + 1))


# create plot and points
plot(x, y, type = "l", lty = 1,  xlab="Year", ylab="Number of Incidents", xlim = xlim, cex = 0.9, main = title)
lines(x, y, type = "p", lty = 1)
text(x-0.1, y-20, pos = 2, labels = y, cex=0.9, offset =0.5)


# Add a legend to the plot
legend("topleft", legend=c("incidents"),
       col=c("black"), lty = 1:2, cex=0.8)
```

![](LIAO.5200.PRACTICUM01_files/figure-gfm/unnamed-chunk-50-1.png)<!-- -->

# Part 8

Create a stored procedure in MySQL (note that if you used SQLite, then
you cannot complete this step) that adds a new incident to the database.
You may decide what you need to pass to the stored procedure to add a
bird strike incident and you must account for there being potentially a
new airport. Note that if you used SQLite rather than the required MySQL
for the practicum, then you cannot complete this question as SQLite does
not support stored procedures.

From the query below, it can been seen that many of the foreign keys
referring to the attributes are using artificial keys. Even columns that
are referring to aritificial keys that have unique values such as
LANDING for flightPhase require specific inputs. Therefore, all the
attributes desides rid, dates, and warning require additional helper
functions that would check and translate the inputted text regarding an
incident into these keys.

The goal is to call a stored procedure called newEntry with the folowing
signature:
`CALL newEntry("HELLICOPTER", "MY airport", "my bike", '10/27/22', 'my airline', 'my state', 'flying', 'NO cloud', "TRUE", 0)`

``` r
command = "SELECT * FROM incidents;"

head(dbGetQuery(dbcon, command))
```

    ##      rid      dates origin airline aircraft flightPhase altitude conditions
    ## 1 200011 2000-04-06     47      18      159     LANDING        0          3
    ## 2 200012 2000-04-10     94      54       42     LANDING        0          3
    ## 3 200022 2000-02-28      2      19       50     LANDING     2000          1
    ## 4 200023 2000-08-25     66       1       16     LANDING     7000          1
    ## 5 200028 2000-03-22    110       6       37     LANDING     3000          1
    ## 6 200029 2000-05-14     59     179       17     LANDING       30          1
    ##   warning
    ## 1       1
    ## 2       1
    ## 3       1
    ## 4       0
    ## 5       1
    ## 6       1

The stored function below translates TRUE and T text entries and returns
a 1 for true and 0 for false.

``` sql
DROP FUNCTION IF EXISTS translateWarning ;
```

``` sql
CREATE FUNCTION translateWarning(in_warning VARCHAR(20))
RETURNS INTEGER


BEGIN
  DECLARE out_warning INTEGER;
  
  If (UPPER(in_warning) = "TRUE" OR UPPER(in_warning) = "T") THEN
      SET out_warning = 1;
    ELSE
      SET out_warning = 0;
  END IF;
  RETURN (out_warning);
END;
```

The stored function below translates entries regarding the flight
conditions. It ensures that only valid conditions are given.

``` sql
DROP FUNCTION IF EXISTS translateCondition ;
```

``` sql
CREATE FUNCTION translateCondition(in_condition VARCHAR(20))
RETURNS INTEGER

BEGIN
  DECLARE out_condition INTEGER;
  
  IF (EXISTS (SELECT * FROM conditions WHERE conditions.cond = in_condition)) THEN
    SELECT conditions.cid into out_condition FROM conditions WHERE conditions.cond = in_condition;

  ELSE
    CALL test('Invalid condition given');
  END if;
  RETURN (out_condition);
END;
```

The stored function below translates the aircraft type and model into a
unique integer identifier from the aircrafts table.

``` sql
DROP FUNCTION IF EXISTS translateAircraft;
```

``` sql
CREATE FUNCTION translateAircraft(in_type VARCHAR(30),in_model VARCHAR(30))
RETURNS INTEGER

BEGIN
  DECLARE out_acid INTEGER;
  DECLARE out_type INTEGER;
  
  DECLARE aircraft_exists BOOLEAN;
  DECLARE type_exists BOOLEAN;
  
  SET in_type = UPPER(in_type);
  SET in_model = UPPER(in_model);
  
  /*Check if type exists*/
  SELECT (EXISTS (SELECT * FROM aircraftTypes WHERE aircraftType = in_type)) into type_exists;
  /*make sure the type exists*/
  IF NOT type_exists THEN
    INSERT INTO aircraftTypes(aircraftType) VALUES (in_type);
  END IF;
  SELECT actid INTO out_type FROM aircraftTypes WHERE aircraftType = in_type;
  /*Check if pair of aircraft type and model exists*/
  SELECT (EXISTS (SELECT * FROM aircrafts WHERE model = in_model AND actid = out_type)) into aircraft_exists;
  /*Make sure the specific pair exists*/
  IF NOT aircraft_exists THEN
    SELECT actid INTO out_type FROM aircraftTypes WHERE aircraftType = in_type;
    INSERT INTO aircrafts (actid, model) VALUES (out_type, in_model);
  END IF;
  
  SELECT acid INTO out_acid FROM aircrafts WHERE aircrafts.model = in_model AND aircrafts.actid = out_type;
  RETURN (out_acid);
END;
  
```

The function below ensures that a valid flightphase is given. If the
given flightphase is not matching the one of the harmonized values, then
“UNKNOWN” is returned.

``` sql
DROP FUNCTION IF EXISTS translateFlightPhase;
```

``` sql
CREATE FUNCTION translateFlightPhase(in_flightPhase VARCHAR(30))
  RETURNS VARCHAR(30)
  
  BEGIN
    DECLARE out_flightPhase VARCHAR(30);
    SET in_flightPhase = UPPER(in_flightPhase);
    
    IF (EXISTS (SELECT * FROM flightPhases WHERE fpid = in_flightPhase)) THEN
      SET out_flightPhase = in_flightPhase;
    ELSE
      SET out_flightPhase = "UNKNOWN";
    END IF;
    RETURN (out_flightPhase);
  END;

    
```

The function below translate the given airline name to the respective
airline id. If the airline does not exist, then the airline is added to
the airline table.

``` sql
DROP FUNCTION IF EXISTS translateAirline
```

``` sql
CREATE FUNCTION translateAirline(in_airline VARCHAR(30))
  RETURNS INTEGER
  
  BEGIN
    DECLARE out_alid INTEGER;
    SET in_airline = UPPER(in_airline);
    
    IF NOT (EXISTS (SELECT * FROM airlines WHERE airline = in_airline)) THEN
      INSERT INTO airlines(airline) VALUES (in_airline);
    END IF;
    SELECT alid INTO out_alid FROM airlines WHERE airline = in_airline;
    RETURN (out_alid);
  END;

    
```

The function below translates the airport name and the state that it
resides in. The table currently allows for airports to share the same
name as long as the state differs from each entry. For instance Logan
International in MA and Logan International in CA are both valid as of
right now. More information is needed regarding airport naming
conventions world wide. This approach was chosen because there are
several unnamed air fields in several different states and it might be
useful to distinguish those. If an airport name or state name does not
exist in the database, they will be added to their respective tables.

``` sql
DROP FUNCTION IF EXISTS translateOrigin;
```

``` sql
CREATE FUNCTION translateOrigin(in_airport VARCHAR(30), in_state  VARCHAR(30))
  RETURNS INTEGER

BEGIN

  DECLARE out_aid INTEGER;
  
  DECLARE state_exists BOOLEAN;
  DECLARE airport_exists BOOLEAN;
  
  SET in_state = UPPER(in_state);
  SET in_airport = UPPER(in_airport);
  
  /*Check if the state exists*/
  SELECT (EXISTS (SELECT * FROM states WHERE state = in_state)) into state_exists;
  /*Check if the specific airport and state exists in airport table*/
  SELECT (EXISTS (SELECT * FROM airports WHERE airportName = in_airport AND state = in_state)) into airport_exists;
  
  /*Entry in airports table does not exist */
  IF NOT airport_exists THEN
    /*make sure the state exists*/
    IF NOT state_exists THEN
      INSERT INTO states (state) VALUES (in_state);
    END IF;
    INSERT INTO airports (airportName, state) VALUES (in_airport, in_state);
  END IF;
  
  SELECT aid INTO out_aid FROM airports WHERE airportName = in_airport AND state = in_state;
  RETURN (out_aid);
END;

    
```

The stored procedure below is the main procedure that automates adding
new entries to the incident table. It utilizes all the translate
functions within the database to input the correct foreign key
references that are needed for each entry. When the correct data types
are given, then the procedure returns the entry as a query.

``` sql
DROP PROCEDURE IF EXISTS newEntry;
```

``` sql
CREATE PROCEDURE newEntry (
  IN in_aircraftType VARCHAR(50), 
  IN in_airportName VARCHAR(50),
  IN in_model VARCHAR(50), 
  IN in_date VARCHAR(50), 
  IN in_airlineName VARCHAR(50),
  IN in_state VARCHAR(50), 
  IN in_flightPhase VARCHAR(50), 
  IN in_condition VARCHAR(50), 
  IN in_warning VARCHAR(50), 
  IN in_altitude INTEGER)
  
BEGIN
  INSERT INTO incidents (dates, origin, airline, aircraft, flightPhase, altitude, conditions, warning) 
  VALUES (STR_TO_DATE(in_date, '%m/%d/%Y'), 
          translateOrigin(in_airportName, in_state),
          translateAirline(in_airlineName),
          translateAircraft(in_aircraftType, in_model), 
          translateFlightPhase(in_flightPhase), 
          in_altitude, 
          translateCondition(in_condition), 
          translateWarning(in_warning));
  SELECT * FROM incidents ORDER BY rid DESC LIMIT 1;

END;
```

Below is calling the procedure from the database in R. The strings must
be given as single quotes surrounding double quotes to retain a string
type when calling a function or procedure within the query. The results
variable in r holds the entry that was just added into the database.

``` r
aircraft_type = '"HELLICOPTER"'
airport_name = '"MY airport"'
model_name = '"my cool model"'
date_today = '"10/27/22"'
airline_name = '"my airline"'
state_name = '"MASSACHUSETTS"'
flightPhase = '"INFLIGHT"'
flying_condition = '"NO CLOUD"'
warned = '"false"'
altitude = 10000

command = paste0("CALL newEntry(", paste(aircraft_type, airport_name, model_name, date_today, airline_name, state_name, flightPhase, flying_condition, warned, altitude, sep = ", "), ");")
command
```

    ## [1] "CALL newEntry(\"HELLICOPTER\", \"MY airport\", \"my cool model\", \"10/27/22\", \"my airline\", \"MASSACHUSETTS\", \"INFLIGHT\", \"NO CLOUD\", \"false\", 10000);"

``` r
res = dbSendQuery(dbcon, command)
data = fetch(res,n=-1)
while(dbMoreResults(dbcon) == TRUE) {
  dbNextResult(dbcon)
}
data
```

    ##      rid      dates origin airline aircraft flightPhase altitude conditions
    ## 1 321910 2022-10-27   1140     291      337    INFLIGHT    10000          1
    ##   warning
    ## 1       0

Shows “MY AIRPORT” was added to the airports table

``` r
command = "SELECT * FROM airports WHERE aid = 1140;"

dbGetQuery(dbcon, command)
```

    ##    aid airportName         state airportCode
    ## 1 1140  MY AIRPORT MASSACHUSETTS        <NA>

Shows “MY AIRLINE” was added to the airports table

``` r
command = "SELECT * FROM airlines WHERE alid = 291;"

dbGetQuery(dbcon, command)
```

    ##   alid    airline
    ## 1  291 MY AIRLINE

Shows “MY AIRLINE” was added to the airports table

``` r
command = "SELECT * FROM aircrafts WHERE acid = 337;"

dbGetQuery(dbcon, command)
```

    ##   acid actid         model
    ## 1  337     2 MY COOL MODEL

``` r
dbDisconnect(dbcon)
```

    ## [1] TRUE
