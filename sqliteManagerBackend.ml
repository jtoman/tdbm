exception SqliteException of Sqlite3.Rc.t

module Dbal = struct
  module SRC = Sqlite3.Rc
  module D = Sqlite3.Data
  let map_rows stmt f = 
    let rec loop accum = 
      let rc = Sqlite3.step stmt in
      match rc with
        | SRC.BUSY -> loop accum
        | SRC.DONE -> List.rev accum
        | SRC.ROW -> let accum' = (f (Sqlite3.row_data stmt))::accum in
                     loop accum'
        | _ -> raise (SqliteException rc)
    in
    loop [];;
  
  let map_object stmt f =
    match (map_rows stmt f) with
      | o::[] -> o
      | [] -> raise Not_found
      |  _ -> failwith "more than one result row returned"

  let map_null_object stmt f = 
    match (map_rows stmt f) with
      | [] -> None
      | [o] -> Some o
      | _ -> failwith "number of returned objects is neither 1 or 0"
          
  let db_exec stmt = 
    let rec loop () = 
      let rc = Sqlite3.step stmt in
      match rc with
        | SRC.BUSY -> loop ()
        | SRC.DONE -> ()
        | SRC.ROW -> failwith "Unexpected data returned"
        | _ -> raise (SqliteException rc)
    in
    loop ()
  let extract_int = function
    | D.INT i -> Int64.to_int i
    | e -> failwith ("Unexpected type " ^ (D.to_string_debug e))
  let extract_string = function
    | D.TEXT s -> s
    | e -> failwith "Unexpected type " ^ (D.to_string_debug e)
  let bind_index stmt i d = 
    match Sqlite3.bind stmt i d with 
      | SRC.OK -> ()
      | rc -> raise (SqliteException rc)
  let bind_named stmt p_name d = 
    let i = Sqlite3.bind_parameter_index stmt p_name in
    bind_index stmt i d
end

module SqliteBackendF(DBA : DbState.DbAccess) = struct
  type config = string
  type t = Sqlite3.db
  type token = string
  type host = int
  type candidate = (DbState.db_candidate * host * string)
      
  let find_sql = Printf.sprintf "SELECT * FROM (SELECT id, db_host, db_name, state FROM db_state WHERE state = %s OR state = %s UNION SELECT id, db_host, db_name, state FROM db_state WHERE state = %s AND expiry < ?) LIMIT 1"
    (DbState.string_of_status `Open)
    (DbState.string_of_status `Fresh)
    (DbState.string_of_status `InUse)

  module Admin = struct
     let add_db_sql = 
       "INSERT INTO db_state(db_host, db_name, state) VALUES(?,?,?)"
     let find_host = "SELECT id FROM db_hosts WHERE host_name = ?";;
     let add_database conn host database = 
       let find_host_stmt = Sqlite3.prepare conn find_host in
       Dbal.bind_index 1 (Sqlite3.Data.TEXT host);
       let host = Dbal.map_object find_host_stmt (fun s -> (Dbal.extract_int s.(0))) in
       let add_db_stmt = Sqlite3.prepare conn add_db_sql in
       Dbal.bind_index add_db_stmt 1 (int_param host);
       Dbal.bind_index add_db_stmt 2 (Sqlite3.Data.TEXT database);
       Dbal.bind_index add_db_stmt 3 (Sqlite3.Data.TEXT (DbState.string_of_status `Fresh));
       Dbal.db_exec add_db_stmt
     let add_host_sql = "INSERT INTO db_hosts(host_name) VALUES(?)"
     let add_host conn host = 
       let add_host_stmt = Sqlite3.conn add_host_sql in
       Dbal.bind_index add_host_stmt 1 (Sqlite3.Data.TEXT host);
       Dbal.db_exec add_host_stmt
     let enter_maint_sql = "UPDATE db_state SET state = ? WHERE db_name = ? AND db_host in (SELECT id FROM db_hosts WHERE host_name = ?)"
     let enter_maintainence conn host db = 
       let enter_maint_stmt = Sqlite3.prepare conn enter_maint_sql in
       Dbal.bind_index enter_maint_stmt 1 (Sqlite3.Data.TEXT "MAINT");
       Dbal.bind_index enter_maint_stmt 2 (Sqlite3.Data.TEXT db);
       Dbal.bind_index enter_maint_stmt 3 (Sqlite3.Data.TEXT host);
       Dbal.db_exec enter_maint_stmt
     let leave_maint_sql = "UPDATE db_state SET state = ? WHERE db_name = ? AND state = ? AND db_host in (SELECT id FROM db_hosts WHERE host_name = ?)"
     let leave_maintainence conn host db new_state = 
       let leave_maint_stmt = Sqlite3.prepare conn leave_maint_sql in
       Dbal.bind_index leave_maint_stmt 1 (Sqlite3.Data.TEXT (DbAccess.string_of_state new_state));
       Dbal.bind_index leave_maint_stmt 2 (Sqlite3.Data.TEXT db);
       Dbal.bind_index leave_maint_stmt 3 "MAINT");
       Dbal.bind_index leave_maint_stmt 4 (Sqlite3.Data.TEXT host);
       Dbal.db_exec leave_maint_stmt
  end

  let update_state_sql = "UPDATE db_state SET state = ? WHERE id = ?";;
      
  let connect db_file = Sqlite3.db_open db_file
    
  let int_param i = Sqlite3.Data.INT (Int64.of_int i)
    
  let get_candidate_db conn = 
    (ignore (Sqlite3.exec conn "BEGIN IMMEDIATE TRANSACTION"));
    let find_stmt = Sqlite3.prepare conn find_sql in
    let curr_time = (int_of_float (Unix.time ())) in
    Dbal.bind_index find_stmt 1 (int_param curr_time);
    let db_state_mapper = fun s ->
      let i_tid = Dbal.extract_int s.(0) in
      let s_state = Dbal.extract_string s.(1) in
      let state = DBA.of_db i_tid s_state in
      let host = Dbal.extract_int s.(2) in
      let db_name = Dbal.extract_string s.(3) in
      (i_tid, state, host, db_name)
    in
    match (Dbal.map_null_object find_stmt db_state_mapper) with
      | None -> ignore (Sqlite3.exec conn "COMMIT"); None
      | Some (i_tid,state,host,db_name) -> 
          let update_stmt = Sqlite3.prepare conn update_state_sql in
          Dbal.bind_index update_stmt 1 (Sqlite3.Data.TEXT "SETUP");
          Dbal.bind_index update_stmt 2 (int_param i_tid);
          Dbal.db_exec update_stmt;
          ignore (Sqlite3.exec conn "COMMIT");
          Some (state, host, db_name);;
  
  let get_user_sql = "SELECT id, username FROM db_credentials WHERE db_id = ?"

  let user_mapper s = 
    Dbal.extract_string s.(1)

  let get_user conn tid = 
    let get_user_stmt = Sqlite3.prepare conn get_user_sql in
    Dbal.bind_index get_user_stmt 1 (int_param (DBA.unwrap_tid tid));
    match (Dbal.map_null_object get_user_stmt user_mapper) with
      | None -> raise Not_found
      | Some u -> u

  let assign_user_sql = "UPDATE db_credentials SET db_id = ? WHERE db_host = ? AND db_id IS NULL LIMIT 1"
    
  let assign_user conn host tid = 
    ignore (Sqlite3.exec conn "BEGIN IMMEDIATE TRANSACTION");
    let assign_stmt = Sqlite3.prepare conn assign_user_sql in
    begin
      Dbal.bind_index assign_stmt 1 (int_param (DBA.unwrap_tid tid));
      Dbal.bind_index assign_stmt 2 (int_param host);
      Dbal.db_exec assign_stmt;
      ignore (Sqlite3.exec conn "COMMIT");
      get_user conn tid
    end
      
      
  let get_hostname_sql = "SELECT host_name FROM db_hosts WHERE id = ?"
    
  let get_hostname conn host = 
    let get_hostname_stmt = Sqlite3.prepare conn get_hostname_sql in
    (Dbal.bind_index get_hostname_stmt 1 (int_param host));
    match (Dbal.map_null_object get_hostname_stmt (fun s -> Dbal.extract_string s.(0))) with
      | None -> raise Not_found
      | Some h -> h;;

  let mark_ready_sql = "UPDATE db_state SET state = 'INUSE', expiry = ?, token = ? WHERE id = ?";;
  let generate_token t expire_time = 
    let to_hash = Printf.sprintf "BRAWNDO@%d@%d" t expire_time in
    let hash = Digest.string to_hash in
    Digest.to_hex hash

  let mark_ready conn t expiry = 
    let tid = DBA.unwrap_tid t in
    let expire_time = (int_of_float (Unix.time ())) + expiry in
    let token = generate_token tid expire_time in
    let mark_stmt = Sqlite3.prepare conn mark_ready_sql in
    Dbal.bind_index mark_stmt 1 (int_param expiry);
    Dbal.bind_index mark_stmt 2 (Sqlite3.Data.TEXT token);
    Dbal.bind_index mark_stmt 3 (int_param tid);
    Dbal.db_exec mark_stmt;
    token

  let load_sql = "SELECT id, state FROM db_state WHERE token = ?"

  let load_db conn token = 
    let load_stmt = Sqlite3.prepare conn load_sql in
    Dbal.bind_index load_stmt 1 (Sqlite3.Data.TEXT token);
    Dbal.map_object load_stmt (fun s ->
      DBA.of_db (Dbal.extract_int s.(0)) (Dbal.extract_string s.(1))
    )

      
  let release conn t =
    let tid = DBA.unwrap_tid t in
    ignore (Sqlite3.exec conn "BEGIN RESERVED TRANSACTION");
    let release_stmt = Sqlite3.prepare conn "UPDATE db_state SET state = 'OPEN', expiry = NULL, token = null where id = ?" in
    Dbal.bind_index release_stmt 1 (int_param tid);
    Dbal.db_exec release_stmt;
    let release_user_stmt = Sqlite3.prepare conn "UPDATE db_credentials SET db_id = NULL WHERE db_id = ?" in
    Dbal.bind_index release_user_stmt 1 (int_param tid);
    Dbal.db_exec release_user_stmt;
    ignore (Sqlite3.exec conn "COMMIT")
      
      
  let destroy conn = 
    ignore (Sqlite3.db_close conn)
      
  let config_of_map m = 
    List.assoc "sqlite.db_file" m

  let string_of_token t = t
end
