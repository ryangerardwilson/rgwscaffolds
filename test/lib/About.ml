
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
