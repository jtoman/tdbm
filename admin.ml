module StateBackend = DbState.Make(SqliteManagerBackend.SqliteBackendF)

open Core.Std

let conn_wrap f =
  let conn = StateBackend.connect () in
  try
    f conn;
    StateBackend.destroy conn
  with e -> StateBackend.destroy conn; raise e

let add_db config_file state host db user () = 
  StateBackend.load_config config_file;
  conn_wrap (fun conn ->
    StateBackend.Admin.add_db conn ?stat:state host db user
  )
let add_host config_file hostname () =
  StateBackend.load_config config_file;
  conn_wrap (fun conn -> 
    StateBackend.Admin.add_host conn hostname
  )

let enter_maint config_file host db () = 
  StateBackend.load_config config_file;
  conn_wrap (fun conn ->
    StateBackend.Admin.enter_maintainence conn host db
  )

let leave_maintainence config_file host db new_state () =
  StateBackend.load_config config_file;
  conn_wrap (fun conn ->
    StateBackend.Admin.leave_maintainence conn host db new_state
  )
module CS = Command.Spec

let config_param = CS.flag "-config-file" (CS.required CS.string) ~doc:"path The absolute path to the TDBM configuration file"
let db_param = CS.(anon ("database" %: CS.string))
let host_param = CS.(anon ("host" %: CS.string))

let state_arg = Command.Spec.Arg_type.create (function
  | "open" -> `Open
  | "fresh" -> `Fresh
  | e -> failwith ("Invalid option " ^ e ^ ": one of open or fresh")
);;

let add_db_command = 
  Command.basic Command.Spec.(
    empty
    +> config_param
    +> (flag ~doc:"(open|fresh) The (optional) state in which to set the new database" "-state" (optional state_arg))
    +> host_param
    +> db_param
    +> (anon ("user" %: string))
  ) add_db ~summary:"Adds a new test database with the given name on the given host which will be associated with the given user"

let add_host_command = 
  Command.basic Command.Spec.(
    empty
    +> config_param
    +> host_param
  ) add_host ~summary:"Adds a host identified by [host] to be tracked by TDBM"

let enter_maint_command = 
  Command.basic Command.Spec.(
    empty
    +> config_param
    +> host_param
    +> db_param
  ) enter_maint ~summary:"Takes a database into maintainence mode"

let leave_maint_command = 
  Command.basic Command.Spec.(
    empty
    +> config_param
    +> host_param
    +> db_param
    +> (anon ("state" %:state_arg))
  ) leave_maintainence ~summary:"Brings a database out of maintainence mode"

let cmd_group = Command.group ~summary:"Administrative commands for TDBM"
  [ ("add-db", add_db_command);
    ("add-host", add_host_command);
    ("enter-maint", enter_maint_command);
    ("leave-maint", leave_maint_command)
  ];;
Command.run cmd_group;;
