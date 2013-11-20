type config = string
type t = Sqlite3.db

let find_sql = "SELECT * FROM (SELECT id, db_host, db_name, state FROM db_state WHERE state = 'OPEN' OR state = 'FRESH' UNION SELECT id, db_host, db_name, state FROM db_state WHERE state = 'INUSE' AND expiry < ?) LIMIT 1";;

let reserve_sql = "UPDATE db_state SET state = 'SETUP' WHERE id = :id;";;

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
      | _ -> failwith "number of returned results is not one"
          
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

let connect db_file = Sqlite3.db_open db_file

let int_param i = Sqlite3.Data.INT (Int64.of_int i)

let get_candidate_db conn = 
  (ignore (Sqlite3.exec conn "BEGIN IMMEDIATE TRANSACTION"));
  let find_stmt = Sqlite3.prepare conn find_sql in
  let reserve_stmt = Sqlite3.prepare conn reserve_sql in
  let curr_time = (int_of_float (Unix.time ())) in
  Dbal.bind_index find_stmt 1 (int_param curr_time);
  let db_state_mapper = fun s ->
    ((Dbal.extract_int s.(0)),
     (DbManager.DBState.of_string (Dbal.extract_string s.(3))),
     (Dbal.extract_int s.(1)),
     (Dbal.extract_string s.(2))
    )
  in
  match (Dbal.map_null_object find_stmt db_state_mapper) with
    | None -> ignore (Sqlite3.exec conn "COMMIT"); None
    | Some (id,_,_,_) as s -> 
        Dbal.bind_index reserve_stmt 1 (int_param id);
        Dbal.db_exec reserve_stmt;
        ignore (Sqlite3.exec conn "COMMIT");
        s;;

let get_user_sql = "SELECT id, username FROM db_credentials WHERE db_id = ?"

let user_mapper s = 
  Dbal.extract_string s.(1)

let get_user conn tid = 
  let get_user_stmt = Sqlite3.prepare conn get_user_sql in
  Dbal.bind_index get_user_stmt 1 (int_param tid);
  match (Dbal.map_null_object get_user_stmt user_mapper) with
    | None -> raise Not_found
    | Some u -> u

let assign_user_sql = "UPDATE db_credentials SET db_id = ? WHERE db_host = ? AND db_id IS NULL LIMIT 1"

let assign_user conn host tid = 
  ignore (Sqlite3.exec conn "BEGIN IMMEDIATE TRANSACTION");
  let assign_stmt = Sqlite3.prepare conn assign_user_sql in
  begin
    Dbal.bind_index assign_stmt 1 (int_param tid);
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
    | Some h -> h

let mark_ready_sql = "UPDATE db_state SET state = 'INUSE', expiry = :expiry WHERE id = :id";;

let mark_ready conn t expiry = 
  let mark_stmt = Sqlite3.prepare conn mark_ready_sql in
  Dbal.bind_index mark_stmt 2 (int_param t);
  Dbal.bind_index mark_stmt 1 (int_param expiry);
  Dbal.db_exec mark_stmt

let release conn t =
  ignore (Sqlite3.exec conn "BEGIN RESERVED TRANSACTION");
  let release_stmt = Sqlite3.prepare conn "UPDATE db_state SET state = 'OPEN', expiry = NULL where id = ?" in
  Dbal.bind_index release_stmt 1 (int_param t);
  Dbal.db_exec release_stmt;
  let release_user_stmt = Sqlite3.prepare conn "UPDATE db_credentials SET db_id = NULL WHERE db_id = ?" in
  Dbal.bind_index release_user_stmt 1 (int_param t);
  Dbal.db_exec release_user_stmt;
  ignore (Sqlite3.exec conn "COMMIT")


let destroy conn = 
  ignore (Sqlite3.db_close conn)

let config_of_map m = 
  List.assoc "sqlite.db_file" m
