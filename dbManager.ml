module type TestDatabase = sig
  type t
  val admin_connection : string -> string -> t
  val set_user_credentials : t -> string -> string -> unit
  val kill_connections : t -> string -> unit
  val run_commands : t -> string -> unit
  val load_config : string -> unit
  val disconnect : t -> unit
end

module Make(M : DbState.StateBackend)(T : TestDatabase) = struct
  module CF = Config_file
  let tdb_config = new CF.group
  let setup_file = new CF.list_cp CF.string_wrappers ~group:tdb_config
    ["sql"; "setup" ] [] ""
  let reset_file = new CF.list_cp CF.string_wrappers ~group:tdb_config
    ["sql"; "reset"] [] ""
  type connection_info = {
    hostname: string;
    db_name: string;
    username: string;
    password: string;
    token: string
  }

  let load_config conf_file =
    tdb_config#read ~no_default:true conf_file;
    M.load_config conf_file;
    T.load_config conf_file
    

  let generate_password () = 
    Random.self_init ();
    let random_number = Random.bits () in
    let hash = Digest.string (string_of_int random_number) in
    Digest.to_hex hash

  let read_file_fully s = 
    let in_c = open_in s in
    let file_size = in_channel_length in_c in
    let buffer = String.create file_size in
    (* TODO: better error checking *)
    let _ = really_input in_c buffer 0 file_size in
    close_in in_c;
    buffer

  let reserve lease = 
    let manager = M.connect () in
    match (M.get_candidate_db manager) with
      | None -> None
      | Some (state, host, db_name) ->
          let hostname = M.get_hostname manager host in
          let new_pass = generate_password () in
          let admin_conn = T.admin_connection hostname db_name in
          let username = match state with
            | DbState.InUse tid -> M.get_user manager tid 
            | DbState.Open tid -> M.assign_user manager host tid
            | DbState.Fresh tid -> 
                M.assign_user manager host tid in
          T.set_user_credentials admin_conn username new_pass;
          (match state with 
            | DbState.InUse _ -> T.kill_connections admin_conn username
            | DbState.Open _ | DbState.Fresh _ -> ());
          let cmd_files = match state with
            | DbState.InUse _  | DbState.Open _ -> reset_file#get 
            | DbState.Fresh _ -> setup_file#get in
          let tid = match state with
            | DbState.Fresh tid -> (tid :> [`InUse | `Open | `Fresh] DbState.tid)
            | DbState.InUse tid -> (tid :> [`InUse | `Open | `Fresh] DbState.tid)
            | DbState.Open tid -> (tid :> [`InUse | `Open | `Fresh] DbState.tid) in
          let () = 
            let rec run_sql = function
              | [] -> ()
              | h::t -> 
                  T.run_commands admin_conn h; run_sql t
            in run_sql cmd_files
          in
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
  let release token = 
    let manager = M.connect () in
    M.release manager token;
    M.destroy manager
end
