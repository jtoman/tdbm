type tid = int
type db_state = 
  | InUse of tid
  | Open of tid
  | Fresh of tid

type candidate = (db_state * string * string * string)

module type AdminInterface = sig
   type admin_conn
   val add_host : admin_conn -> string -> unit
   val add_db : admin_conn -> ?stat:[`Fresh | `Open ] -> string -> string -> string -> unit
   val enter_maintainence : admin_conn -> string -> string -> unit
   val leave_maintainence : admin_conn -> string -> string -> [`Fresh | `Open ] -> unit
end

module type StateBackend = sig
  type t
  type token

  module Admin : AdminInterface with type admin_conn := t

  val string_of_token : token -> string
  val get_candidate_db : t -> candidate option
  val mark_ready : t -> tid -> int -> token
  val connect : unit -> t
  val release : t -> string -> unit
  val load_config : string -> unit
  val destroy : t -> unit
end

module type DbAccess = sig
  type db_tid = int
  val of_db : db_tid -> string -> db_state
  val unwrap_tid : tid -> db_tid
  type status = [
  | `Maintainence
  | `Setup
  | `InUse
  | `Open
  | `Fresh
  ]
  val string_of_status : [< status ] -> string
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
  type status = [
  | `Maintainence
  | `Setup
  | `InUse
  | `Open
  | `Fresh
  ]
  let string_of_status = function
    | `Maintainence -> "MAINT"
    | `Setup -> "SETUP"
    | `InUse -> "INUSE"
    | `Open -> "OPEN"
    | `Fresh -> "FRESH"
end)
