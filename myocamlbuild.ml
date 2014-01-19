open Ocamlbuild_plugin
open Command

let _ = dispatch begin function
  | After_rules ->
      flag [ "link"; "threads" ]
        (S[A"-thread"]);
      flag [ "compile"; "ocaml"; "threads" ]
        (S[A"-thread"])
  | _ -> ()
end
