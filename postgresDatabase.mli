type config

type t

val admin_connection : config -> string -> string -> t
val set_user_password : t -> string -> string -> unit
val kill_connections : t -> string -> unit
val run_commands : t -> string -> unit
val config_of_map : Config.config_map -> config
val disconnect : t -> unit
