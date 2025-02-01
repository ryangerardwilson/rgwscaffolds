
open Cohttp
open Cohttp_lwt_unix
open Lwt.Infix

open Session

(* Some cookie parsing again. Ideally factor out to a shared utility. *)
let get_session_id_from_cookie cookie_str =
  let parts = String.split_on_char ';' cookie_str in
  let find_sessionid kv =
    let kv = String.trim kv in
    if String.length kv >= 10 && String.sub kv 0 10 = "sessionid="
    then Some (String.sub kv 10 (String.length kv - 10))
    else None
  in
  List.fold_left
    (fun acc item -> match acc with None -> find_sessionid item | Some _ -> acc)
    None
    parts

let handle_dashboard _conn req _body =
  let headers = Request.headers req in
  let cookie_str = Cohttp.Header.get headers "cookie" in
  match cookie_str with
  | None ->
      Server.respond_string ~status:`Forbidden
        ~body:"No session cookie. Please <a href=\"/login\">log in</a>."
        ()
  | Some cookie ->
      (match get_session_id_from_cookie cookie with
       | None ->
           Server.respond_string ~status:`Forbidden
             ~body:"Missing sessionid in cookie. <a href=\"/login\">Log in</a>"
             ()
       | Some session_id ->
           (match get_username_for_session session_id with
            | None ->
                Server.respond_string ~status:`Forbidden
                  ~body:"Invalid/expired session. <a href=\"/login\">Log in</a>"
                  ()
            | Some username ->
                let filename = "dashboard.html" in
                let substitutions = [("{{USERNAME}}", username)] in
                Renderer.server_side_render filename substitutions))

