type status = [ 
| `InUse
| `Open
| `Fresh
]
let string_of_status = function
  | `InUse -> "INUSE"
  | `Open -> "OPEN"
  | `Fresh -> "FRESH"
type tid' = int
type (+'a,'b) tid = tid' constraint 'b = [< `Setup | `Return ] constraint 'a = [< status ]
type 'status db_state = 
  | InUse of ([`InUse],'status) tid
  | Open of ([`Open ],'status) tid
  | Fresh of ([`Open | `Fresh],'status) tid
type db_candidate = [`Setup] db_state
type to_return = [`Return] db_state

let of_string id state = 
  let tid = int_of_string id in
  match state with
    | "INUSE" -> InUse tid
    | "OPEN" -> Open tid
    | "FRESH" -> Fresh tid
    | _ -> invalid_arg (state ^ " is not a valid state")
        
type bare_tid = tid'
type transitions = [`InUse | `Setup | `Open ]
type transition_state = (bare_tid * transitions)
let change_state tid new_state = (tid, new_state)
let to_string (bare_tid, s) =  
  let s_tid = string_of_int bare_tid in
  let state_string = match s with 
    | `InUse -> "INUSE"
    | `Open  -> "OPEN"
    | `Setup -> "SETUP" in
  (s_tid, state_string)
