module StateBackend = DbState.Make(SqliteManagerBackend.SqliteBackendF)

let config = [
  ("sqlite.db_file", "db_manager.sqlite");
  ("psql.user", "admin");
  ("psql.pass", "cattlab");
  ("psql.role", "website_isud");
  ("sql.setup", "setup.sql");
  ("sql.reset", "reset.sql")
];;

let admin_conn = StateBackend.connect (StateBackend.config_of_map config) in
match Sys.argv.(1) with
  | "host-add" -> StateBackend.Admin.add_host admin_conn Sys.argv.(2)
  | "db-add" -> StateBackend.Admin.add_db admin_conn Sys.argv.(2) Sys.argv.(3)
  | "user-add" -> StateBackend.Admin.add_user admin_conn Sys.argv.(2) Sys.argv.(3)
  | _ -> failwith ("Unknown command " ^ Sys.argv.(1))
