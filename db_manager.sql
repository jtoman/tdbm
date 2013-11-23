CREATE TABLE db_hosts(
   id INTEGER PRIMARY KEY AUTOINCREMENT,
   host_name TEXT UNIQUE
);


CREATE TABLE db_state(id INTEGER PRIMARY KEY AUTOINCREMENT,
       db_host INTEGER,
       db_name TEXT,
       -- ONE OF 'INUSE', 'SETUP', 'OPEN', 'FRESH', 'MAINT'
       state TEXT,
       expiry INTEGER,
	   token TEXT,
       FOREIGN KEY (db_host) REFERENCES db_hosts(id)
);

CREATE TABLE db_credentials(
       id INTEGER PRIMARY KEY AUTOINCREMENT,
       db_id INTEGER,
       db_host INTEGER NOT NULL,
       username TEXT,
       FOREIGN KEY (db_id) REFERENCES db_state(id),
       FOREIGN KEY (db_host) REFERENCES db_hosts(id)
);
