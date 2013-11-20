module DummyTestDb : DbManager.TestDatabase = struct
  type config = unit
  type t = unit
  let admin_connection _ _ _ = ()
  let set_user_password _ u p = Printf.printf "Setting password of %s to %s\n" u p
  let kill_connections _ u = Printf.printf "Killing connections of %s\n" u
  let run_commands _ s = Printf.printf "Executing %s\n" s
  let config_of_map _ = ()
  let disconnect _ = ()
end

module Manager = DbManager.Make(SqliteManagerBackend)(PostgresDatabase);;

let m = Manager.init [("sql.setup", "setup"); ("sql.reset", "reset"); ("sqlite.db_file", "test_db.sqlite")] in
match Manager.reserve m 1 with
  | None -> failwith "oops"
  | Some (tid, hostname, db_name, user, password) ->
      Printf.printf "Got %d %s %s %s %s\n" tid hostname db_name user password;
      try 
        
        Manager.release m tid
      with SqliteManagerBackend.SqliteException r -> print_endline (Sqlite3.Rc.to_string r)
