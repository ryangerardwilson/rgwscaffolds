 
(* File: lib/Session.ml *)

open Base64  (* or “open B64” if your library uses that module name *)

(* Force session_store to have type (string, string) Hashtbl.t list *)
let session_store : (string, string) Hashtbl.t = Hashtbl.create 16

let generate_session_id () =
  (* Make sure to seed Random once (e.g., in main.ml) or call Random.self_init () here *)
  let rand_bytes = Bytes.create 16 in
  for i = 0 to 15 do
    Bytes.set rand_bytes i (char_of_int (Random.int 256))
  done;
  (* If your library doesn’t have encode_exn, then use encode or whichever function is provided *)
  Base64.encode_exn (Bytes.to_string rand_bytes)

let create_session ~username =
  let session_id = generate_session_id () in
  Hashtbl.replace session_store session_id username;
  session_id

let get_username_for_session session_id =
  Hashtbl.find_opt session_store session_id

let destroy_session session_id =
  Hashtbl.remove session_store session_id
