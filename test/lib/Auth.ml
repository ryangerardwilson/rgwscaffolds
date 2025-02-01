 
(* lib/Auth.ml *)

open Cohttp
open Cohttp_lwt_unix
open Lwt.Infix
open Str

open Session

type user = {
  username: string;
  password: string;
  display_name: string;
}

let valid_users = [
  { username = "admin"; password = "secret";   display_name = "Admin" };
  { username = "bob";   password = "bob123";   display_name = "Bob"   };
  { username = "alice"; password = "alice123"; display_name = "Alice" };
]

let parse_post_body body_str =
  let parts = Str.split (Str.regexp_string "&") body_str in
  List.map (fun part ->
      match Str.bounded_split (Str.regexp_string "=") part 2 with
      | [k; v] -> (k, v)
      | _ -> ("", "")
    ) parts

(* A small helper to parse sessionid from a cookie. *)
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

(* /login *)
let handle_login _conn req body =
  match Request.meth req with
  | `GET ->
      Renderer.server_side_render "login.html" []
  | `POST ->
      Cohttp_lwt.Body.to_string body >>= fun body_str ->
      let form_data = parse_post_body body_str in
      let username_submitted = List.assoc_opt "username" form_data |> Option.value ~default:"" in
      let password_submitted = List.assoc_opt "password" form_data |> Option.value ~default:"" in

      let maybe_user =
        List.find_opt
          (fun u -> u.username = username_submitted && u.password = password_submitted)
          valid_users
      in
      (match maybe_user with
      | Some user ->
          let session_id = create_session ~username:user.display_name in
          let headers = Header.add (Header.init ()) "Set-Cookie" ("sessionid=" ^ session_id) in
          (* Redirect to /dashboard on successful login *)
          Server.respond_redirect ~headers ~uri:(Uri.of_string "/dashboard") ()
      | None ->
          let body = "<h2>Login Failed</h2><p>Invalid credentials.</p><p><a href=\"/login\">Try again</a></p>" in
          Server.respond_string ~status:`OK ~body ())
  | _ ->
      Server.respond_string ~status:`Method_not_allowed ~body:"Method not allowed" ()

(* /logout *)
let handle_logout _conn req _body =
  (* Check cookie for a valid sessionid, then destroy the session. *)
  let cookie_header = Cohttp.Header.get (Request.headers req) "cookie" in
  (match cookie_header with
   | None -> ()
   | Some cookie_str ->
       (match get_session_id_from_cookie cookie_str with
        | None -> ()
        | Some session_id -> destroy_session session_id
       )
  );
  (* Finally, redirect to landing page *)
  Server.respond_redirect ~uri:(Uri.of_string "/") ()
