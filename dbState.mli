type tid
type db_state = private
                | InUse of tid
                | Open of tid
                | Fresh of tid

(* state, hostname, database name, user name *)
type candidate = (db_state * string * string * string)

module type AdminInterface = sig
   type admin_conn
   val add_host : admin_conn -> string -> unit
   val add_db : admin_conn -> ?stat:[ `Fresh | `Open ] -> string -> string -> string -> unit
   val enter_maintainence : admin_conn -> string -> string -> unit
   val leave_maintainence : admin_conn -> string -> string -> [`Fresh | `Open ] -> unit
end

module type StateBackend = sig
  type t
  type token

  module Admin : AdminInterface with type admin_conn := t
  val string_of_token : token -> string
  val get_candidate_db : t -> candidate option
  val mark_ready : t ->  tid -> int -> token
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

(** A backend takes a module that provides the mapping to/from the db
    representation to the abstract tid and db_state types. This is done
    so that types of tid and db_state can only be constructed/deconstructed
    by the state backend. The manager can only interact with the highly abstract
    db_state and tid types.
*)
module type BackendFunctor = functor(DBA : DbAccess) -> StateBackend

(**
   This functor takes a backend functor and provides it 
   with the implementation mapping the db representation to
   the db_state thus yielding a complete state backend.
*)
module Make(BF: BackendFunctor) : StateBackend



