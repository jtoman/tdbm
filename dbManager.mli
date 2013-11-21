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
  val assign_user : t -> host -> ([< `Fresh | `Open],[`Setup]) DbState.tid -> string
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
  val config_of_map : config_map -> config
  val disconnect : t -> unit
end

module Make(M : ManagerBackend)(T : TestDatabase) : sig
  type config
  type connection_info = {
    hostname: string;
    db_name: string;
    username: string;
    password: string;
    token: string
  }
  val init : config_map -> config
  val reserve : config -> int -> connection_info option
  val release : config -> string -> unit
end
