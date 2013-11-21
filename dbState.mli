  type status = [ 
  | `InUse
  | `Open
  | `Fresh
  | `Setup
  ]
  type (+'a,'b) tid constraint 'b = [< `Setup | `Return ] constraint 'a = [< status ]
  type 'status db_state = private
           | InUse of ([`InUse],'status) tid
           | Open of ([`Open ],'status) tid
           | Fresh of ([`Open | `Fresh],'status) tid
  type db_candidate = [`Setup] db_state
  type to_return = [`Return] db_state
  val of_string : string -> string -> 'a db_state
  val to_string : (_) db_state -> (string * string)
  val string_of_status : status -> string
