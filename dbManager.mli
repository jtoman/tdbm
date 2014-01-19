module type TestDatabase = sig
  type t
  val admin_connection : string -> string -> t
  val set_user_credentials : t -> string -> string -> unit
  val kill_connections : t -> string -> unit
  val run_commands : t -> string -> unit
  val load_config : string -> unit
  val disconnect : t -> unit
end

module Make(M : DbState.StateBackend)(T : TestDatabase) : sig
  type connection_info = {
    hostname: string;
    db_name: string;
    username: string;
    password: string;
    token: string
  }
  val load_config : string -> unit
  val reserve : int -> connection_info option
  val release : string -> unit
end
