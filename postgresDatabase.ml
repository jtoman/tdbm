type config = {
  admin_user : string;
  admin_pass : string;
  port : int;
  user_role: string
}

module CF = Config_file
let psql_options = new CF.group
let admin_user = new CF.string_cp ~group:psql_options ["psql"; "user"] "" ""
let admin_password = new CF.string_cp ~group:psql_options ["psql"; "pass"] "" ""  
let port = new CF.int_cp ~group:psql_options [ "psql"; "port" ] ~-1 ""
let user_roles = new CF.list_cp CF.string_wrappers ~group:psql_options [ "psql"; "roles" ] [] ""

let load_config conf_file = 
  psql_options#read ~no_default:true conf_file

type t = Postgresql.connection

let admin_connection host database = 
  let conn = new Postgresql.connection ~host:host ~dbname:database ~user:admin_user#get ~password:admin_password#get ~port:(string_of_int (port#get)) () in
  conn#set_notice_processor (fun _ -> ());
  conn

let set_user_pass_sql = format_of_string "ALTER ROLE %s WITH PASSWORD '%s'"
let grant_sql = format_of_string "GRANT %s TO %s";;

let set_user_credentials (conn : Postgresql.connection) username pass  = 
  let (escaped_password : string) = (conn#escape_string pass) in
  let (set_sql : string) = Printf.sprintf set_user_pass_sql username escaped_password in
  ignore (conn#exec ~expect:[Postgresql.Command_ok] set_sql);
  let rec loop = function
    | [] -> ()
    | h::t -> begin
      let role_sql = Printf.sprintf grant_sql h username in
      ignore (conn#exec ~expect:[Postgresql.Command_ok] role_sql);
      loop t
    end
  in
  loop (user_roles#get)

let kill_connection_sql = "SELECT pg_terminate_backend(procpid) FROM pg_stat_activity WHERE usename = $1";;

let kill_connections (conn : Postgresql.connection) user = 
  (* TODO: verify that this returns all true values *)
  ignore (conn#exec ~expect:[Postgresql.Tuples_ok]
            ~params:[| user |] kill_connection_sql)

let read_file_fully f_name = 
  let f_chan = Core.In_channel.create f_name in
  let f_cont  = Core.In_channel.input_all f_chan in
  Core.In_channel.close f_chan;
  f_cont

let run_commands (conn : Postgresql.connection) command_file = 
  try 
    let command = read_file_fully command_file in
    ignore (conn#exec ~expect:[ Postgresql.Tuples_ok; Postgresql.Command_ok ] command)
  with Postgresql.Error e -> failwith (Postgresql.string_of_error e)

let disconnect (conn : Postgresql.connection) = 
  conn#finish;;
