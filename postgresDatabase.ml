type config = {
  admin_user : string;
  admin_pass : string;
  port : int;
  user_role: string
}

type t = (config * Postgresql.connection)

let admin_connection conf host database = 
  let conn = new Postgresql.connection ~host:host ~dbname:database ~user:conf.admin_user ~password:conf.admin_pass ~port:(string_of_int conf.port) () in
  conn#set_notice_processor (fun _ -> ());
  (conf,conn)

let set_user_pass_sql = format_of_string "ALTER ROLE %s WITH PASSWORD '%s'"
let grant_sql = format_of_string "GRANT %s TO %s";;

let set_user_credentials (conf,(conn : Postgresql.connection)) username pass  = 
  let (escaped_password : string) = (conn#escape_string pass) in
  let (set_sql : string) = Printf.sprintf set_user_pass_sql username escaped_password in
  ignore (conn#exec ~expect:[Postgresql.Command_ok] set_sql);
  let role_sql = Printf.sprintf grant_sql conf.user_role username in
  ignore (conn#exec ~expect:[Postgresql.Command_ok] role_sql)

let kill_connection_sql = "SELECT pg_terminate_backend(procpid) FROM pg_stat_activity WHERE usename = $1";;

let kill_connections (conf,(conn : Postgresql.connection)) user = 
  (* TODO: verify that this returns all true values *)
  ignore (conn#exec ~expect:[Postgresql.Tuples_ok]
            ~params:[| user |] kill_connection_sql)

let run_commands (conf,(conn : Postgresql.connection)) command = 
  try 
    ignore (conn#exec ~expect:[Postgresql.Tuples_ok; Postgresql.Command_ok; Postgresql.Copy_in ] command)
  with Postgresql.Error e -> failwith (Postgresql.string_of_error e)

let config_of_map config_map = 
  let root = LibConfig.get_group config_map "psql" in
  if not (LibConfig.validate root (`Group [
    ("user", `String);
    ("pass", `String);
    ("role", `String)
  ])) then
    failwith "Bad configuration"
  else
    {
      port = 5432;
      admin_user = LibConfig.get_scalar root ~path:"user" LibConfig.string_value;
      admin_pass = LibConfig.get_scalar root ~path:"pass" LibConfig.string_value;
      user_role = LibConfig.get_scalar root ~path:"role" LibConfig.string_value
    }

let disconnect (conf,(conn : Postgresql.connection)) = 
  conn#finish;;
