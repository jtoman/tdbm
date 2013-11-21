type status = [ 
| `InUse
| `Open
| `Fresh
]
type (+'a,'b) tid constraint 'b = [< `Setup | `Return ] constraint 'a = [< status ]
type 'status db_state = private
                        | InUse of ([`InUse],'status) tid
                        | Open of ([`Open ],'status) tid
                        | Fresh of ([`Open | `Fresh],'status) tid
type transition_state
type db_candidate = [`Setup] db_state
type transitions = [`InUse | `Setup | `Open ]
type to_return = [`Return] db_state
val string_of_status : status -> string
val of_string : string -> string -> 'a db_state
val to_string : transition_state -> (string * string)
val change_state : (_,_) tid -> transitions -> transition_state
val string_of_status : status -> string
