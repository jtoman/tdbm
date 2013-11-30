module StateBackend = DbState.Make(SqliteManagerBackend.SqliteBackendF)
module Manager = DbManager.Make(StateBackend)(PostgresDatabase)

let config = Config.load_config "/home/john/hacking/tdbm/tdbm.cfg";;

let manager = Manager.init config in
match Sys.argv.(1) with
  | "reserve" -> 
      let conn_info = Manager.reserve manager (int_of_string Sys.argv.(2)) in
      (match conn_info with
        | None -> print_endline "No available databases"
        | Some dbi -> Printf.printf "h: %s\ndb: %s\nu: %s\np: %s\ntoken: %s\n"
            dbi.Manager.hostname
          dbi.Manager.db_name
          dbi.Manager.username
          dbi.Manager.password
          dbi.Manager.token)
        
  | "release" -> Manager.release manager Sys.argv.(2)
  | _ -> failwith ("Unknown command " ^ Sys.argv.(1))
