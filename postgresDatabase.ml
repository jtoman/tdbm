type config = {
  admin_user : string;
  admin_pass : string;
  port : int;
}

type t = Postgresql.connection

let admin_connection conf host database = 
  new Postgresql.connection ~host:host ~dbname:database ~user:conf.admin_user ~password:conf.admin_pass ~port:(string_of_int conf.port) ();;

let set_user_pass_sql = format_of_string "ALTER ROLE %s SET PASSWORD '%s'";;

let set_user_password (conn : t) username pass  = 
  let (escaped_password : string) = (conn#escape_string pass) in
  let (set_sql : string) = Printf.sprintf set_user_pass_sql username escaped_password in
  ignore (conn#exec ~expect:[Postgresql.Command_ok; Postgresql.Tuples_ok] set_sql)

let kill_connection_sql = "SELECT pg_terminate_backend(procpid) FROM pg_stat_activity WHERE usename = $1";;

let kill_connections (conn : t) user = 
  (* TODO: verify that this returns all true values *)
  ignore (conn#exec ~expect:[Postgresql.Tuples_ok]
            ~params:[| user |] kill_connection_sql)

let run_commands (conn : t) command = 
  ignore (conn#exec ~expect:[Postgresql.Tuples_ok; Postgresql.Command_ok; Postgresql.Copy_in ] command);;

let config_of_map config_map = 
  {
    port = 5432;
    admin_user = List.assoc "psql.user" config_map;
    admin_pass = List.assoc "psql.pass" config_map
  }

let disconnect (conn : t) = 
  conn#finish;;
