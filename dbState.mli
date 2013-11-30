type status_flag = [ 
| `InUse
| `Open
| `Fresh
]
type (+'a,'b) tid constraint 'b = [< `Setup | `InUse ] constraint 'a = [< status_flag ]
type 'status db_state = private
                        | InUse of ([`InUse],'status) tid
                        | Open of ([`Open ],'status) tid
                        | Fresh of ([`Open | `Fresh],'status) tid

type db_candidate = [`Setup] db_state

(*type db_status = (string * db_st) list and
db_st = {
  users: string list;
  databases: (string * [ `Setup | `Maintainence | `InUse of (string * int) | `Open | `Fresh ])
}
    *)
module type AdminInterface = sig
   type admin_conn
   val add_host : admin_conn -> string -> unit
   val add_db : admin_conn -> string -> string -> unit
   val add_user : admin_conn -> string -> string -> unit
   val enter_maintainence : admin_conn -> string -> string -> unit
   val leave_maintainence : admin_conn -> string -> string -> [`Fresh | `Open ] -> unit
(*   val dump : admin_conn -> db_status *)
end

module type StateBackend = sig
  type config
  type t
  type token
  type host

  module Admin : AdminInterface with type admin_conn := t

  type candidate = (db_candidate * host * string)
  val string_of_token : token -> string
  val get_user : t -> ([`InUse],_) tid -> string
  val get_candidate_db : t -> candidate option
  val mark_ready : t -> (_,[`Setup]) tid -> int -> token
  val connect : config -> t
  val release : t -> string -> unit
  val assign_user : t -> host -> ([< `Fresh | `Open],[`Setup]) tid -> string
  val get_hostname : t -> host -> string
  val config_of_map : Config.config_map -> config
  val destroy : t -> unit
end

module type DbAccess = sig
  type db_tid = int
  val of_db : db_tid -> string -> 'a db_state
  val unwrap_tid : (_,_) tid -> db_tid
  type status = [
  | `Maintainence
  | `Setup
  | status_flag
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



