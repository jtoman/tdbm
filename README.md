Summary
---

TDBM (Test Database Manager) is a service for managing spinning up a
test database for use in unit tests. It exposes a dead-simple
web-interace for fetching connection information for a newly setup
test database. The basic workflow is as follows:

1. Client asks for a test database for a specified time.
2. TDBM consults its internal list of test databases and finds an
  available test database.
3. TDBM runs user specified SQL to ensure that the test database is
  ready to be used in a unit test.
4. When the client is done running tests, the test database is returned
  to TDBM

How it works
---

TDBM tracks the state of several different designated test databases
across (potentailly) several different servers. A test database can be
in one of three states:
Open
: The test database is available and has been initially setup. Will
require resetting before use by another test process
Fresh
: The test database is available but has not been initially setup
(e.g. the necessary schemas do not even exist). A completely blank
slate
In Use
: The test database is currently being lent out to a test process.

Each request for a test database is associated with a lease
time. After a test database has been assigned to a test process the
test process has exclusive rights to use the database in the time
period of the lease. Any test database that is In Use without an
expired lease is ineligible for lease to another test process.

To service a request for a new test database TDBM attempts to find an
Open or Fresh database to lease to the requester. However, in the
event no Fresh or Open databases are available an In Use database
for which the lease has expired will be forcibly returned to control
of TDBM and assigned to the lesee.

TDBM will then run one of two sets of user defined SQL. For Fresh
databases this SQL is responsible for setting up the test database
from scratch (hereafter called the "setup sql"). For an Open or In Use
database, a separate set of SQL is run that is responsible for
resetting the database to a fresh data (hereafter called the "reset
sql"). It is likely that returning a database to a fresh state will
take significantly less time than starting again from scratch but for
simplicity's sake the "reset sql" can simply wipe out the database and
start over.

After the appropriate set of SQL has run the user credentials are set
up on the prepared test database and the connection information is
returned to the client along with a token which is used to return the
test database later.

Usage
---

Before running any tests a test process makes a GET request to the
path `/reserve`. reserve expects exactly one GET parameter *lease* which
specifies in seconds how long the lease on the test database should
be. For example:
```
tdbm.mydoman.com/reserve?lease=300
```

If there is an available test database the connection information
will be returned in a JSON object formatted as follows:

* connection:
  * host
  * user
  * db_name
  * password
  * token

After the test process completes the client can (and should) return
the test database back to the pool of available servers. This is done
by passing the token returned in the call to reserve as a get
parameter named "token" to the /release path. For example:
```
    tdbm.mydomain.com/release?token=ee435e2115613687dfd132cfb2f7923d
```

Limitations
---

TDBM currently only supports PostgreSQL test databases. In addition,
Sqlite is currently the only option for the backend that tracks the
test database state. Further, the TDBM can only manage databases for
one type of project; you cannot have TDBM run different SQL for
different test scenarios. As desire or time dictates more backends can
be added later.

Requirements
---

TDBM requires the following components:

* Postgresql
* Sqlite3
* Yojson
* Config_file
* Ocamlnet
* Jane Street's Core >= 108.07.01

In addition, TDBM exposes its web interface via FCGI. You will need a
web server that is capable of invoking FCGI programs. Currently the
FCGI executable expects to communicate with the server via
stdin. Therefore at current TDBM *cannot* be used with servers such as
NGINX which expect to communicate with FCGI processes over a pipe
(this is due to the current FCGI's process very single threaded
nature). This will likely change in future versions.

Building and Installation
---

In the top level of the source directory (the same folder as this
file) issue the command:
```
ocamlbuild -use-ocamlfind fcgi_interface.native
```

The resulting executable is a standalone executable which can be
placed wherever it can be used by your web server. You must still
provide some key configuration.

Running and Configuration
---

The FCGI process reads its configuration value from a file, the
location of which must be provided as the environment variable
`$TDBM_CONFIG` to the FCGI process.

The configuration file format is the format used by the [Config_file
library](http://config-file.forge.ocamlcore.org/ocamldoc/Config_file.html).

It has the following fields (all required):

* `sqlite`
  * `db_file` _string_ : The absolute path of the sqlite file used to
    track the test database state
* `psql`
  * `user` _string_ : An administrative user. This user must be an admin on all
    hosts in all databases known to TDBM
  * `pass` _string_ : The password for the admin user. This password must be
    consistent across all hosts known to TDBM
  * `roles` _string list_ : A list of roles to assign to a test user
    as part of the credential setup process
  * `port` _int_ : The port on which the administrative user should
    connect to test database instances
* `sql`
  * `setup` _string list_ : A list of absolute path names to the sql
    files to be run as part of the setup process. The commands in
    these files will be run in the order that the files appear in this
    list
  * `reset` _string list_ : A list of absolute path names to the sql
    files to be run as a part of the reset process. The commands in
    these files will be in the order that the files appear in this
    list
