module StateBackend = DbState.Make(SqliteManagerBackend.SqliteBackendF)
module Manager = DbManager.Make(StateBackend)(PostgresDatabase)

let load_manager (cgi : Netcgi_fcgi.cgi) = 
  let conf = Config.load_config (Sys.getenv "TDBM_CONFIG") in
  let to_ret = Manager.init conf in
  to_ret

let respond ?(status=`Ok) (cgi : Netcgi_fcgi.cgi) json = 
  let resp = Yojson.Basic.to_string json in
  let len = String.length resp in
  cgi#set_header ~status:status ~content_length:len ~content_type:"application/json" ();
  cgi#out_channel#output_string resp;
  cgi#out_channel#commit_work ();
  cgi#out_channel#flush ()

let handle_release (cgi : Netcgi_fcgi.cgi) = 
  if not (cgi#argument_exists "token") then
    respond ~status:`Bad_request cgi (`Assoc [
      ("success",`Bool false);
      ("message",`String "Missing token")
    ])
  else
    let manager = load_manager cgi in
    let token = cgi#argument_value "token" in
    Manager.release manager token;
    respond cgi (`Assoc [
      ("success", `Bool true);
      ("message", `String "ok")
    ])


let handle_reserve (cgi : Netcgi_fcgi.cgi) =
  if not (cgi#argument_exists "lease") then
    respond ~status:`Bad_request cgi (`Assoc [
      ("success", `Bool false);
      ("message", `String "Missing lease parameter")
    ])
  else
    begin
      let manager = load_manager cgi in
      let lease = int_of_string (cgi#argument_value "lease") in
      match (Manager.reserve manager lease) with
        | None -> respond cgi (`Assoc [ ("connection", `Null) ])
        | Some cinfo -> 
            let message = (`Assoc [
              ("connection", `Assoc [
                ("host", `String cinfo.Manager.hostname);
                ("user", `String cinfo.Manager.username);
                ("db_name", `String cinfo.Manager.db_name);
                ("password", `String cinfo.Manager.password);
                ("token", `String cinfo.Manager.token)
              ])
            ]) in
            respond cgi message
    end
;;

Netcgi_fcgi.run (fun cgi ->
  let path = cgi#environment#cgi_path_info in
  if path = "/reserve" then
    handle_reserve cgi
  else if path = "/release" then
    handle_release cgi
  else
    cgi#set_header ~status:`Not_found ()
)
