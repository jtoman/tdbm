type config_map = (string * string) list
let  load_config _  =  [("sql.setup", "setup"); ("sql.reset", "reset"); ("sqlite.db_file", "test_db.sqlite")]
