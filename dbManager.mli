module Tid : sig
  type t = int
  val of_string : string -> t
  val to_string : t -> string
end

module DBState : sig
  type t = private InUse
           | Open
           | Fresh
  val of_string : string -> t
  val to_string : t -> string
end

type test_db =  (Tid.t * DBState.t * int * string)

type config_map = (string * string) list

module type ManagerBackend = sig
  type config
  type t
  val get_user : t -> Tid.t -> string
  val get_candidate_db : t -> test_db option
  val mark_ready : t -> Tid.t -> int -> unit
  val connect : config -> t
  val release : t -> Tid.t -> unit
  val assign_user : t -> int -> Tid.t -> string
  val get_hostname : t -> int -> string
  val config_of_map : config_map -> config
  val destroy : t -> unit
end

module type TestDatabase = sig
  type config
  type t
  val admin_connection : config -> string -> string -> t
  val set_user_password : t -> string -> string -> unit
  val kill_connections : t -> string -> unit
  val run_commands : t -> string -> unit
  val config_of_map : config_map -> config
  val disconnect : t -> unit
end

module Make(M : ManagerBackend)(T : TestDatabase) : sig
  type config
  val init : config_map -> config
  val reserve : config -> int -> (Tid.t * string * string * string * string) option
  val release : config -> Tid.t -> unit
end
