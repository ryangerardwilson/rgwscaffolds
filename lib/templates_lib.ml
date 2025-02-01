(* Helper function to check if a given flag is present in Sys.argv *)
let has_flag flag =
  Array.exists ((=) flag) Sys.argv

(* Helper function to write content to a file (overwrite if exists) *)
let write_file filename content =
  let oc = open_out filename in
  output_string oc content;
  close_out oc;
  Printf.printf "Created or updated file: %s\n" filename

(* Helper function to create a directory if it doesn't already exist *)
let ensure_dir path =
  if Sys.file_exists path then
    Printf.printf "Directory '%s' already exists, skipping creation.\n" path
  else begin
    Unix.mkdir path 0o755;
    Printf.printf "Created directory: %s\n" path
  end


let file_env = {|
APP_NAME=xyz
PUBLIC_DIR=dist
PORT=8080
|}

(*
  main.ml is the entry point for your application.
  You can customize how you initialize your server and
  how environment variables are read.
*)
let file_main_ml = {|
open Lwt.Infix
open Cohttp_lwt_unix

let routes = [
  ("/", Landing.handle_landing);
  ("/home", Home.handle_root);
  ("/about", About.handle_about);
  ("/login", Auth.handle_login);
  ("/logout", Auth.handle_logout);
  ("/dashboard", Dashboard.handle_dashboard);
]

let route conn req body =
  let uri_path = Uri.path (Request.uri req) in
  match List.find_opt (fun (p, _) -> p = uri_path) routes with
  | Some (_, handler) -> handler conn req body
  | None ->
      Server.respond_string ~status:`Not_found ~body:"Not Found" ()

let () = Dotenv.export ()

let getenv_with_default var default =
  try Sys.getenv var with Not_found -> default

let app_name = getenv_with_default "APP_NAME" "My App"
let port = int_of_string (getenv_with_default "PORT" "8080")

(* Ensure Random is seeded once *)
let () = Random.self_init ()

let () =
  Printf.printf "Starting %s on port %d\n%!" app_name port;
  let config = Server.make ~callback:route () in
  Lwt_main.run (Server.create ~mode:(`TCP (`Port port)) config)
|}


(*
  Lib.ml is a central place to re-export all modules in the lib/ directory,
  so you can easily reference them as Lib.Home, Lib.About, etc.
*)

(*
  Home.ml in lib/ directory - demonstration route handler for "/home"
*)
let file_home_ml = {|
open Cohttp
open Cohttp_lwt_unix
open Lwt.Infix

let handle_root _conn _req _body =
  (* Define which file (in dist/) to serve and what substitutions to apply *)
  let filename = "home.html" in
  let substitutions = [
    ("{{CUSTOM_VAR}}", "Custom Value 111");
    ("{{ANOTHER_VAR}}", "Another Value 222 ");
  ] in
  Renderer.server_side_render filename substitutions
|}

(*
  About.ml in lib/ directory - demonstration route handler for "/about"
*)
let file_about_ml = {|
open Cohttp
open Cohttp_lwt_unix
open Lwt.Infix

let handle_about (_conn : Cohttp_lwt_unix.Server.conn) (_req : Cohttp.Request.t) (_body : Cohttp_lwt.Body.t) =
  let filename = "about.html" in
  let substitutions = [
    ("{{PAGE_TITLE}}", "About Page 777");
    ("{{ABOUT_CONTENT}}", "This is the about page content. 771");
  ] in
  Renderer.server_side_render filename substitutions
|}

(*
  Auth.ml in the lib/ directory
*)
let file_auth_ml = {| 
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
|}

(*
  Dashboard.ml in the lib/ directory
*)

let file_dashboard_ml = {|
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

|}

(*
  Session.ml in the lib directory
*)

let file_session_ml = {| 
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
|}


let file_landing_ml = {|
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
|}


(*
  In utils/ we place any helper modules. For example, a Renderer that
  loads HTML files and performs placeholder replacements.
*)

let file_renderer_ml = {|
open Cohttp
open Cohttp_lwt_unix
open Lwt.Infix

let server_side_render (filename : string) (substitutions : (string * string) list) : (Cohttp.Response.t * Cohttp_lwt.Body.t) Lwt.t =
  (* Allow user to specify a PUBLIC_DIR via environment variable; defaults to "dist" *)
  let public_dir = Sys.getenv_opt "PUBLIC_DIR" |> Option.value ~default:"dist" in
  let filepath = Filename.concat public_dir filename in

  if Sys.file_exists filepath then
    Lwt_io.(with_file ~mode:Input filepath read) >>= fun content ->
    let replaced_content =
      List.fold_left (fun acc (key, value) ->
        Str.global_replace (Str.regexp_string key) value acc
      ) content substitutions
    in
    Server.respond_string ~status:`OK ~body:replaced_content ()
  else
    Server.respond_string
      ~status:`Not_found
      ~body:"File not found"
      ()
|}

(*
  The dist/ directory will contain static HTML files. You can then
  refer to them in your route handlers. Below are minimal examples.
*)
let file_home_html = {|
<html>
  <head>
    <title>Home Page</title>
  </head>
  <body>
    <h1>{{CUSTOM_VAR}}</h1>
    <p>{{ANOTHER_VAR}}</p>
  </body>
</html>
|}

let file_about_html = {|
<html>
  <head>
    <title>{{PAGE_TITLE}}</title>
  </head>
  <body>
    <h2>About</h2>
    <p>{{ABOUT_CONTENT}}</p>
  </body>
</html>
|}

let file_dashboard_html = {|
<html>
  <head>
    <title>Dashboard</title>
  </head>
  <body>
    <h1>Dashboard</h1>
    <p>Welcome, {{USERNAME}}!</p>
    <p><a href="/">Go back to Landing Page</a></p>
  </body>
</html>
|}

let file_landing_html = {|
<!-- dist/landing.html -->
<html>
  <head>
    <title>Landing Page</title>
  </head>
  <body>
    <h1>Welcome to Our Simple OCaml App</h1>

    <!-- We'll inject either "logged in as..." or nothing here: -->
    <div>{{LOGGED_IN_AS}}</div>

    <!-- We'll also inject the link block (login or dashboard/logout) here: -->
    <div>{{LINK_BLOCK}}</div>
  </body>
</html>
|}

let file_login_html = {|
<html>
  <head>
    <title>Login</title>
  </head>
  <body>
    <h2>Login</h2>
    <form method="POST" action="/login">
      <label>Username:
        <input type="text" name="username"/>
      </label>
      <br/>
      <label>Password:
        <input type="password" name="password"/>
      </label>
      <br/>
      <input type="submit" value="Login"/>
    </form>
  </body>
</html>
|}


let compile_and_run_script = {|
#!/bin/bash

# Step 1: Compile modules
ocamlfind ocamlc -c -thread -package cohttp-lwt-unix,dotenv,str,base64 \
  -I utils -I lib utils/Renderer.ml

ocamlfind ocamlc -c -thread -package cohttp-lwt-unix,dotenv,str,base64 \
  -I utils -I lib lib/Session.ml

ocamlfind ocamlc -c -thread -package cohttp-lwt-unix,dotenv,str,base64 \
  -I utils -I lib lib/Landing.ml

ocamlfind ocamlc -c -thread -package cohttp-lwt-unix,dotenv,str,base64 \
  -I utils -I lib lib/Home.ml

ocamlfind ocamlc -c -thread -package cohttp-lwt-unix,dotenv,str,base64 \
  -I utils -I lib lib/About.ml

ocamlfind ocamlc -c -thread -package cohttp-lwt-unix,dotenv,str,base64 \
  -I utils -I lib lib/Auth.ml

ocamlfind ocamlc -c -thread -package cohttp-lwt-unix,dotenv,str,base64 \
  -I utils -I lib lib/Dashboard.ml

ocamlfind ocamlc -c -thread -package cohttp-lwt-unix,dotenv,str,base64 \
  -I utils -I lib main.ml

# Step 2: Link modules
ocamlfind ocamlc -thread -package cohttp-lwt-unix,dotenv,str,base64 -linkpkg \
  -o app \
  utils/Renderer.cmo \
  lib/Session.cmo \
  lib/Landing.cmo \
  lib/Home.cmo \
  lib/About.cmo \
  lib/Auth.cmo \
  lib/Dashboard.cmo \
  main.cmo

# Step 3: Clean .cmi, .cmo, .out
find . -type f \( -name "*.cmo" -o -name "*.cmi" -o -name "*.out" \) -exec rm -f {} +

echo "Use the --and_run flag to compile and run the app automatically."

# Step 4: Optionally run
if [[ "$1" == "--and_run" ]]; then
  ./app
fi
|}

