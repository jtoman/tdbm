type status = [ 
  | `InUse
  | `Open
  | `Fresh
  | `Setup
  ]
  type (+'a,'b) tid = int constraint 'b = [< `Setup | `Return ] constraint 'a = [< status ]
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
  let to_generic s = s
  let to_string = function 
    | InUse tid -> (string_of_int tid, "INUSE")
    | Open tid -> (string_of_int tid, "OPEN")
    | Fresh tid -> (string_of_int tid, "FRESH")
  let string_of_status = function
    | `InUse -> "INUSE"
    | `Open -> "OPEN"
    | `Fresh -> "FRESH"
    | `Setup -> "SETUP"
