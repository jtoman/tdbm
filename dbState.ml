type status = [ 
| `InUse
| `Open
| `Fresh
]
type tid' = int
type (+'a,'b) tid = tid' constraint 'b = [< `Setup | `Return ] constraint 'a = [< status ]
type 'status db_state = 
  | InUse of ([`InUse],'status) tid
  | Open of ([`Open ],'status) tid
  | Fresh of ([`Open | `Fresh],'status) tid
type db_candidate = [`Setup] db_state
type to_return = [`Return] db_state

let string_of_status = function 
  | `InUse -> "INUSE"
  | `Open -> "OPEN"
  | `Fresh -> "FRESH"

module type AdminInterface = sig
   type admin_conn
   val add_host : admin_conn -> string -> unit
   val list_hosts : admin_conn -> string list
   val add_db : admin_conn -> string -> string -> unit
   val enter_maintainence : admin_conn -> string -> string -> unit
   val leave_maintainence : admin_conn -> string -> string -> unit
   val dump : admin_conn -> db_status
end

module type StateBackend = sig
  type config
  type t
  type token
  type host
  module Admin : AdminInterface with admin_conn := t
  type candidate = (db_candidate * host * string)
  val string_of_token : token -> string
  val get_user : t -> ([`InUse],_) tid -> string
  val get_candidate_db : t -> candidate option
  val mark_ready : t -> (_,[`Setup]) tid -> int -> token
  val connect : config -> t
  val load_db : t -> string -> to_return
  val release : t -> ([ `InUse ],[`Return]) tid -> unit
  val assign_user : t -> host -> ([< `Fresh | `Open],[`Setup]) tid -> string
  val get_hostname : t -> host -> string
  val config_of_map : Config.config_map -> config
  val destroy : t -> unit
end

module type DbAccess = sig
  type db_tid = int
  val of_db : db_tid -> string -> 'a db_state
  val unwrap_tid : (_,_) tid -> db_tid
end

module type BackendFunctor= functor(DBA : DbAccess) -> StateBackend

module Make(BF: BackendFunctor) = BF(struct
  type db_tid = int
  let of_db tid = function
    | "INUSE" -> InUse tid
    | "OPEN" -> Open tid
    | "FRESH" -> Fresh tid
    | state -> invalid_arg (state ^ " is not a valid state")
  let unwrap_tid tid = tid
end)
