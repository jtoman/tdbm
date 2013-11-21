type config = string
type t
type token = string
type host = int
type candidate = (DbState.db_candidate * host * string)
exception SqliteException of Sqlite3.Rc.t
val string_of_token : token -> string
val get_user : t -> ([`InUse],_) DbState.tid -> string
val get_candidate_db : t -> candidate option
val mark_ready : t -> (_,[`Setup]) DbState.tid -> int -> token
val connect : config -> t
val load_db : string -> DbState.to_return
val release : t -> ([`InUse],[`Return]) DbState.tid -> unit
val assign_user : t -> host -> ([< `Fresh | `Open],[`Setup]) DbState.tid -> string
val get_hostname : t -> host -> string
val config_of_map : DbManager.config_map -> config
val destroy : t -> unit
