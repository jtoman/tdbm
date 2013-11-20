type config = string
type t
exception SqliteException of Sqlite3.Rc.t
val get_user : t -> DbManager.Tid.t -> string
val get_candidate_db : t -> DbManager.test_db option
val mark_ready : t -> DbManager.Tid.t -> int -> unit
val connect : config -> t
val release : t -> DbManager.Tid.t -> unit
val assign_user : t -> int -> DbManager.Tid.t -> string
val get_hostname : t -> int -> string
val config_of_map : (string * string) list -> config
val destroy : t -> unit
