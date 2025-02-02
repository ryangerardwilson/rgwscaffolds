
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
