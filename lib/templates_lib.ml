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


(* Our simple routing logic *)
let routes = [
  ("/home", Home.handle_root);
  ("/about", About.handle_about);
]

let route conn req body =
  let uri_path = Uri.path (Request.uri req) in
  match List.find_opt (fun (p, _) -> p = uri_path) routes with
  | Some (_, handler) -> handler conn req body
  | None ->
      Server.respond_string ~status:`Not_found ~body:"Not Found" ()

(* Load environment variables from .env, if present *)
let () = Dotenv.export ()

(* Helper for environment variables *)
let getenv_with_default var default =
  try Sys.getenv var with Not_found -> default

let app_name = getenv_with_default "APP_NAME" "My App"
let port = int_of_string (getenv_with_default "PORT" "8080")

(* Start the server *)
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

let compile_and_run_script = {|
#!/bin/bash

# Step I: Compile each module with consistent flags (packages + includes)
ocamlfind ocamlc -c -thread -package cohttp-lwt-unix,dotenv,str -I utils -I lib utils/Renderer.ml
ocamlfind ocamlc -c -thread -package cohttp-lwt-unix,dotenv,str -I utils -I lib lib/About.ml
ocamlfind ocamlc -c -thread -package cohttp-lwt-unix,dotenv,str -I utils -I lib lib/Home.ml
ocamlfind ocamlc -c -thread -package cohttp-lwt-unix,dotenv,str -I utils -I lib main.ml

# Step II: Link modules into the final executable
ocamlfind ocamlc -thread -package cohttp-lwt-unix,dotenv,str -linkpkg \
  -o app \
  utils/Renderer.cmo lib/About.cmo lib/Home.cmo main.cmo

# Step III: clean up .cmo, .cmi, .out files
find . -type f \( -name "*.cmo" -o -name "*.cmi" -o -name "*.out" \) -exec rm -f {} +

echo "Use the --and_run flag to compile and run the app automatically."

# Step IV: run the app if --and_run is provided
if [[ "$1" == "--and_run" ]]; then
  ./app
fi
|}

