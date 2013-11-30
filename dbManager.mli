module type TestDatabase = sig
  type config
  type t
  val admin_connection : config -> string -> string -> t
  val set_user_credentials : t -> string -> string -> unit
  val kill_connections : t -> string -> unit
  val run_commands : t -> string -> unit
  val config_of_map : Config.config_map -> config
  val disconnect : t -> unit
end

module Make(M : DbState.StateBackend)(T : TestDatabase) : sig
  type config
  type connection_info = {
    hostname: string;
    db_name: string;
    username: string;
    password: string;
    token: string
  }
  val init : Config.config_map -> config
  val reserve : config -> int -> connection_info option
  val release : config -> string -> unit
end
