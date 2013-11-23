module StateBackend = DbState.Make(SqliteManagerBackend.SqliteBackendF)
module Manager = DbManager.Make(StateBackend)(PostgresDatabase);;

let m = Manager.init [("sql.setup", "setup"); ("sql.reset", "reset"); ("sqlite.db_file", "test_db.sqlite")] in
match Manager.reserve m 1 with
  | None -> failwith "oops"
  | Some (tid, hostname, db_name, user, password) ->
      Printf.printf "Got %d %s %s %s %s\n" tid hostname db_name user password;
      try 
        
        Manager.release m tid
      with SqliteManagerBackend.SqliteException r -> print_endline (Sqlite3.Rc.to_string r)
