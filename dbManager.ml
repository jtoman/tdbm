type config_map = (string * string) list

module type ManagerBackend = sig
  type config
  type t
  type token
  type host

  type candidate = (DbState.db_candidate * host * string)
  val string_of_token : token -> string
  val get_user : t -> ([`InUse],_) DbState.tid -> string
  val get_candidate_db : t -> candidate option
  val mark_ready : t -> (_,[`Setup]) DbState.tid -> int -> token
  val connect : config -> t
  val load_db : string -> DbState.to_return
  val release : t -> ([ `InUse ],[`Return]) DbState.tid -> unit
  val assign_user : t -> host -> ([< `Fresh |  `Open],[`Setup]) DbState.tid -> string
  val get_hostname : t -> host -> string
  val config_of_map : config_map -> config
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
  type connection_info = {
    hostname: string;
    db_name: string;
    username: string;
    password: string;
    token: string
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
      | Some (state, host, db_name) ->
          let hostname = M.get_hostname manager host in
          let new_pass = "foobar" in
          let admin_conn = T.admin_connection conf.tdb_config hostname db_name in
          let username = match state with
            | DbState.InUse tid -> M.get_user manager tid 
            | DbState.Open tid -> M.assign_user manager host tid
            | DbState.Fresh tid -> 
                M.assign_user manager host tid in
          T.set_user_password admin_conn username new_pass;
          (match state with 
            | DbState.InUse _ -> T.kill_connections admin_conn username
            | DbState.Open _ | DbState.Fresh _ -> ());
          let cmd_file = match state with
            | DbState.InUse _  | DbState.Open _ -> conf.reset_file 
            | DbState.Fresh _ -> conf.setup_file in
          let tid = match state with
            | DbState.Fresh tid -> (tid :> ([`InUse | `Open | `Fresh],[`Setup]) DbState.tid)
            | DbState.InUse tid -> (tid :> ([`InUse | `Open | `Fresh],[`Setup]) DbState.tid)
            | DbState.Open tid -> (tid :> ([`InUse | `Open | `Fresh],[`Setup]) DbState.tid) in
          let cmd_sql = read_file_fully cmd_file in
          T.run_commands admin_conn cmd_sql;
          let token = M.mark_ready manager tid lease in
          T.disconnect admin_conn;
          M.destroy manager;
          Some {
            hostname = hostname;
            db_name = db_name;
            username = username;
            password = new_pass;
            token = (M.string_of_token token)
          }
  let release conf token = 
    let manager = M.connect conf.mdb_config in
    let db = M.load_db token in
    (match db with
      | DbState.InUse tid -> M.release manager tid
      | _ -> M.destroy manager; failwith "Token database was not reserved");
    M.destroy manager
  let init conf_map = 
    {
      tdb_config = T.config_of_map conf_map;
      mdb_config = M.config_of_map conf_map;
      setup_file = List.assoc "sql.setup" conf_map;
      reset_file = List.assoc "sql.reset" conf_map
    }
end
