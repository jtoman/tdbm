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
       FOREIGN KEY (db_host) REFERENCES db_hosts(id),
       UNIQUE (db_host, db_name) ON CONFLICT ABORT
);

CREATE TABLE db_user(
       id INTEGER PRIMARY KEY AUTOINCREMENT,
       db_host INTEGER NOT NULL,
       username TEXT,
       FOREIGN KEY (db_host) REFERENCES db_hosts(id),
       UNIQUE (db_host, username) ON CONFLICT ABORT
);

CREATE TABLE user_assignment(
  user_id INTEGER NOT NULL,
  db_id INTEGER NOT NULL,
  FOREIGN KEY (db_id) REFERENCES db_state(id),
  FOREIGN KEY (user_id) REFERENCES db_user(id),
  UNIQUE (db_id),
  UNIQUE (user_id)
);
