CREATE TABLE db_host(
   id INTEGER PRIMARY KEY AUTOINCREMENT,
   host_name TEXT UNIQUE
);


CREATE TABLE db_state(id INTEGER PRIMARY KEY AUTOINCREMENT,
       db_host INTEGER,
       db_name TEXT,
       username TEXT NOT NULL,
       -- ONE OF 'INUSE', 'SETUP', 'OPEN', 'FRESH', 'MAINT'
       state TEXT,
       expiry INTEGER,
	   token TEXT,
       FOREIGN KEY (db_host) REFERENCES db_hosts(id),
       UNIQUE (db_host, db_name) ON CONFLICT ABORT,
       UNIQUE (db_host, username) ON CONFLICT ABORT
);
