exception SqliteException of Sqlite3.Rc.t

module Dbal = struct
  module SRC = Sqlite3.Rc
  module D = Sqlite3.Data

  let bind_index stmt i d = 
    match Sqlite3.bind stmt i d with 
      | SRC.OK -> ()
      | rc -> raise (SqliteException rc)

  let bind_params stmt p_list = 
    let rec loop i = function
      | [] -> ()
      | h::t -> bind_index stmt i h; loop (succ i) t
    in
    loop 1 p_list

  let map_rows conn ?(params=[]) sql (f : Sqlite3.Data.t array -> 'a)  = 
    let stmt = Sqlite3.prepare conn sql in
    bind_params stmt params;
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
  
  let map_object conn ?(params=[]) sql f =
    match (map_rows conn ~params:params sql f) with
      | o::[] -> o
      | [] -> raise Not_found
      |  _ -> failwith "more than one result row returned"

  let map_null_object conn ?(params=[]) sql f = 
    match (map_rows conn ~params:params sql f) with
      | [] -> None
      | [o] -> Some o
      | _ -> failwith "number of returned objects is neither 1 or 0"
          
  let db_exec conn ?params sql  = 
    match params with 
      | Some p_list -> 
          let stmt = Sqlite3.prepare conn sql in
          bind_params stmt p_list;
          let rec loop () = 
            let rc = Sqlite3.step stmt in
            match rc with
              | SRC.BUSY -> loop ()
              | SRC.DONE -> ()
              | SRC.ROW -> failwith "Data unexpectedly returned by query"
              | _ -> raise (SqliteException rc)
          in
          loop ()
      | None -> ignore (Sqlite3.exec conn sql)

  let extract_int = function
    | D.INT i -> Int64.to_int i
    | e -> failwith ("Unexpected type " ^ (D.to_string_debug e))
  let extract_string = function
    | D.TEXT s -> s
    | e -> failwith "Unexpected type " ^ (D.to_string_debug e)
end

let int_param i = Sqlite3.Data.INT (Int64.of_int i)

module SqliteBackendF(DBA : DbState.DbAccess) = struct
  type config = string
  type t = Sqlite3.db
  type token = string
  type host = int
  type candidate = (DbState.db_candidate * host * string)

  module Admin = struct

     let add_db_sql = 
       "INSERT INTO db_state(db_host, db_name, state) VALUES(?,?,?)"


     let get_host_id_sql = "SELECT id FROM db_hosts WHERE host_name = ?";;
     let get_host_id conn hostname = 
       Dbal.map_object conn ~params:[ 
         Sqlite3.Data.TEXT hostname 
       ] get_host_id_sql (fun s -> Dbal.extract_int s.(0))

     let add_db conn host database = 
       let host = get_host_id conn host in
       Dbal.db_exec conn ~params:[
         (int_param host);
         (Sqlite3.Data.TEXT database);
         (Sqlite3.Data.TEXT (DBA.string_of_status `Fresh))
       ] add_db_sql

     let add_host_sql = "INSERT INTO db_hosts(host_name) VALUES(?)"
     let add_host conn host = 
       Dbal.db_exec conn ~params:[ Sqlite3.Data.TEXT host ] add_host_sql

     let add_user_sql = "INSERT INTO db_credentials (db_host, username) VALUES (?,?)"

     let add_user conn hostname username = 
       let host_id = get_host_id conn hostname in
       Dbal.db_exec conn ~params:[ (int_param host_id); (Sqlite3.Data.TEXT username) ] add_user_sql

     let enter_maint_sql = "UPDATE db_state SET state = ? WHERE db_name = ? AND db_host in (SELECT id FROM db_hosts WHERE host_name = ?)"
     let enter_maintainence conn host db = 
       let host_id = get_host_id conn host in
       Dbal.db_exec conn ~params:[
         (Sqlite3.Data.TEXT (DBA.string_of_status `Maintainence));
         (Sqlite3.Data.TEXT db);
         (int_param host_id)
       ] enter_maint_sql

     let leave_maint_sql = "UPDATE db_state SET state = ? WHERE db_name = ? AND state = ? AND db_host in (SELECT id FROM db_hosts WHERE host_name = ?)"

     let leave_maintainence conn host db new_state = 
       let host_id = get_host_id conn host in
       Dbal.db_exec conn ~params:[
         (Sqlite3.Data.TEXT (DBA.string_of_status new_state));
         (Sqlite3.Data.TEXT db);
         (Sqlite3.Data.TEXT (DBA.string_of_status `Maintainence));
         (int_param host_id)
       ] leave_maint_sql
  end


  let connect db_file = Sqlite3.db_open db_file

  let find_sql = Printf.sprintf "SELECT * FROM (SELECT id, db_host, db_name, state FROM db_state WHERE state = '%s' OR state = '%s' UNION SELECT id, db_host, db_name, state FROM db_state WHERE state = '%s' AND expiry < ?) LIMIT 1"
    (DBA.string_of_status `Open)
    (DBA.string_of_status `Fresh)
    (DBA.string_of_status `InUse)

  let update_state_sql = "UPDATE db_state SET state = ? WHERE id = ?";;

  let db_state_mapper = fun s ->
    let i_tid = Dbal.extract_int s.(0) in
    let host = Dbal.extract_int s.(1) in
    let db_name = Dbal.extract_string s.(2) in
    let s_state = Dbal.extract_string s.(3) in
    let state = DBA.of_db i_tid s_state in
    (i_tid, state, host, db_name)

  let get_candidate_db conn = 
    let ex = Dbal.db_exec conn in
    let mno = Dbal.map_null_object conn in
    ex "BEGIN IMMEDIATE TRANSACTION";
    let curr_time = (int_of_float (Unix.time ())) in
    let cd_opt = mno ~params:[ int_param curr_time ] find_sql db_state_mapper in
    match cd_opt with
      | None -> 
          ex "ROLLBACK"; 
          None
      | Some (i_tid,state,host,db_name) -> 
          ex ~params:[
            (Sqlite3.Data.TEXT "SETUP");
            (int_param i_tid)
          ] update_state_sql;
          ex "COMMIT";
          Some (state, host, db_name);;
  
  let get_user_sql = "SELECT id, username FROM db_credentials WHERE db_id = ?"

  let user_mapper s = 
    Dbal.extract_string s.(1)

  let get_user conn tid = 
    let user_opt = Dbal.map_null_object conn ~params:[ int_param (DBA.unwrap_tid tid) ] get_user_sql user_mapper in
    match user_opt with
      | None -> raise Not_found
      | Some u -> u

  let assign_user_sql = "UPDATE db_credentials SET db_id = ? WHERE db_host = ? AND db_id IS NULL LIMIT 1"

  let assign_user conn host tid = 
    let ex = Dbal.db_exec conn in
    ex "BEGIN IMMEDIATE TRANSACTION";
    ex ~params:[
      (int_param (DBA.unwrap_tid tid));
      (int_param host)
    ] assign_user_sql;
    ex "COMMIT";
    get_user conn tid

  let get_hostname_sql = "SELECT host_name FROM db_hosts WHERE id = ?"
    
  let get_hostname conn host = 
    let hostname_opt = Dbal.map_null_object conn ~params:[
      int_param host
    ] get_hostname_sql (fun s -> Dbal.extract_string s.(0)) in
    match hostname_opt with
      | None -> raise Not_found
      | Some hostname -> hostname;;


  let generate_token t expire_time = 
    let to_hash = Printf.sprintf "BRAWNDO@%d@%d" t expire_time in
    let hash = Digest.string to_hash in
    Digest.to_hex hash

  let mark_ready_sql = Printf.sprintf "UPDATE db_state SET state = '%s', expiry = ?, token = ? WHERE id = ?" (DBA.string_of_status `InUse)

  let mark_ready conn t expiry = 
    let tid = DBA.unwrap_tid t in
    let expire_time = (int_of_float (Unix.time ())) + expiry in
    let token = generate_token tid expire_time in
    Dbal.db_exec conn ~params:[
      (int_param expire_time);
      (Sqlite3.Data.TEXT token);
      (int_param tid)
    ] mark_ready_sql;
    token

  let reset_state_sql = "UPDATE db_state SET state = 'OPEN', expiry = NULL, token = null WHERE id = ?"
  let release_user_sql = "UPDATE db_credentials SET db_id = NULL WHERE db_id = ?"

  let release conn token =
    let ex = Dbal.db_exec conn in
    ex "BEGIN RESERVED TRANSACTION";
    let tid' = Dbal.map_null_object conn ~params:[Sqlite3.Data.TEXT token] "SELECT id FROM db_state WHERE token = ?" (fun s -> Dbal.extract_int s.(0)) in
    match tid' with
      | None -> ()
      | Some tid -> 
          let p = [ int_param tid ] in
          ex ~params:p reset_state_sql;
          ex ~params:p release_user_sql;
          ex "COMMIT"
      
      
  let destroy conn = 
    ignore (Sqlite3.db_close conn)
      
  let config_of_map m = 
    LibConfig.get_scalar m LibConfig.string_value "sqlite.db_file"

  let string_of_token t = t
end
