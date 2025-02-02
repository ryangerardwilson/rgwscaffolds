
(* lib/Landing.ml *)

open Cohttp
open Cohttp_lwt_unix
open Lwt.Infix

open Session  (* so that we can call get_username_for_session *)

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

let handle_landing _conn req _body =
  (* Extract cookie from headers *)
  let cookie_header = Cohttp.Header.get (Request.headers req) "cookie" in
  (* Attempt to find a valid session for the user *)
  let maybe_user =
    match cookie_header with
    | None -> None
    | Some cookie_str ->
        match get_session_id_from_cookie cookie_str with
        | None -> None
        | Some session_id -> get_username_for_session session_id
  in

  (* If the user is logged in, show "Logged in as {username}" *)
  let logged_in_as_html =
    match maybe_user with
    | Some username -> Printf.sprintf "Logged in as %s" username
    | None -> ""
  in

  (* If logged in => "Go to Dashboard" & "Logout", else => "Login/Home/About" *)
  let link_block_html =
    match maybe_user with
    | Some _ ->
      "<p><a href=\"/dashboard\">Go to Dashboard</a> | <a href=\"/logout\">Logout</a></p>"
    | None ->
      "<p><a href=\"/login\">Login</a> | <a href=\"/home\">Home</a> | <a href=\"/about\">About</a></p>"
  in

  let substitutions = [
    ("{{LOGGED_IN_AS}}", logged_in_as_html);
    ("{{LINK_BLOCK}}", link_block_html);
  ] in

  Renderer.server_side_render "landing.html" substitutions
