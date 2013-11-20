CREATE TABLE db_hosts(
   id INTEGER PRIMARY KEY AUTOINCREMENT,
   host_name TEXT UNIQUE
);


CREATE TABLE db_state(id INTEGER PRIMARY KEY AUTOINCREMENT,
       -- this should really be de-normalized
       db_host INTEGER,
       db_name TEXT,
       -- ONE OF 'INUSE', 'SETUP', 'OPEN', 'FRESH'
       state TEXT,
       expiry INTEGER,
       FOREIGN KEY (db_host) REFERENCES db_hosts(id)
);

CREATE TABLE db_credentials(
       id INTEGER PRIMARY KEY AUTOINCREMENT,
       db_id INTEGER,
       db_host INTEGER NOT NULL,
       username TEXT,
       -- we should have a reference to the (as yet uncreated) host table here
       FOREIGN KEY (db_id) REFERENCES db_state(id),
       FOREIGN KEY (db_host) REFERENCES db_hosts(id)
);

INSERT INTO db_hosts(host_name) VALUES ('ocelot');
INSERT INTO db_credentials(db_host, username) VALUES (1,'admin');
INSERT INTO db_state(db_host, db_name, state) VALUES (1, 'testdb1', 'FRESH');
INSERT INTO db_state(db_host, db_name, state) VALUES (1, 'testdb2', 'FRESH');
