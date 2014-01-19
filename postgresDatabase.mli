type t

val admin_connection : string -> string -> t
val set_user_credentials : t -> string -> string -> unit
val kill_connections : t -> string -> unit
val run_commands : t -> string -> unit
val load_config : string -> unit
val disconnect : t -> unit
