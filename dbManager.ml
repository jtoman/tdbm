module Tid = struct
  type t = int
  let of_string = int_of_string
  let to_string = string_of_int
end

module DBState = struct
  type t = InUse
           | Open
           | Fresh
  let of_string = function
    | "INUSE" -> InUse
    | "OPEN" -> Open
    | "FRESH" -> Fresh
    | s -> invalid_arg (s ^ " is not a valid database state")
  let to_string = function
    | InUse -> "INUSE"
    | Open -> "OPEN"
    | Fresh -> "FRESH"
end

type test_db =  (Tid.t * DBState.t * int * string)

type config_map = (string * string) list

module type ManagerBackend = sig
  type config
  type t
  val get_user : t -> Tid.t -> string
  val get_candidate_db : t -> test_db option
  val mark_ready : t -> Tid.t -> int -> unit
  val connect : config -> t
  val release : t -> Tid.t -> unit
  val assign_user : t -> int -> Tid.t -> string
  val get_hostname : t -> int -> string
  (* TODO: someday replace me with a real configuration format *)
  val config_of_map : (string * string) list -> config
  val destroy : t -> unit
end

module type TestDatabase = sig
  type config
  type t
  val admin_connection : config -> string -> string -> t
  val set_user_password : t -> string -> string -> unit
  val kill_connections : t -> string -> unit
  val run_commands : t -> string -> unit
  val config_of_map : (string * string) list -> config
  val disconnect : t -> unit
end

module Make(M : ManagerBackend)(T : TestDatabase) = struct
  type config = {
    tdb_config : T.config;
    mdb_config : M.config;
    setup_file : string;
    reset_file : string
  }
  let read_file_fully s = 
    let in_c = open_in s in
    let file_size = in_channel_length in_c in
    let buffer = String.create file_size in
    let _ = really_input in_c buffer 0 file_size in
    close_in in_c;
    buffer
  let reserve conf lease = 
    let manager = M.connect conf.mdb_config in
    match (M.get_candidate_db manager) with
      | None -> None
      | Some (tid, state, host, db_name) ->
          let hostname = M.get_hostname manager host in
          let new_pass = "foobar" in
          let admin_conn = T.admin_connection conf.tdb_config hostname db_name in
          let username = match state with
            | DBState.InUse -> M.get_user manager tid 
            | _ -> M.assign_user manager host tid in
          T.set_user_password admin_conn username new_pass;
          (match state with 
            | DBState.InUse -> T.kill_connections admin_conn username
            | DBState.Open | DBState.Fresh -> ());
          let cmd_file = match state with
            | DBState.InUse | DBState.Open -> conf.reset_file 
            | DBState.Fresh -> conf.setup_file in
          let cmd_sql = read_file_fully cmd_file in
          T.run_commands admin_conn cmd_sql;
          M.mark_ready manager tid lease;
          T.disconnect admin_conn;
          M.destroy manager;
          Some (tid, hostname, db_name, username, new_pass)
  let release conf tid = 
    let manager = M.connect conf.mdb_config in
    M.release manager tid;
    M.destroy manager
  let init conf_map = 
    {
      tdb_config = T.config_of_map conf_map;
      mdb_config = M.config_of_map conf_map;
      setup_file = List.assoc "sql.setup" conf_map;
      reset_file = List.assoc "sql.reset" conf_map
    }
end
