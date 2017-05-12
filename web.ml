module H = Dom_html

let position {Lexing.pos_fname; pos_lnum; pos_cnum; pos_bol} =
  let file = pos_fname in
  let line = pos_lnum in
  let character = pos_cnum - pos_bol in
  (file, line, character)

let parse_report_loc parse_fun str =
  let lexbuf = Lexing.from_string str in
  try `Success (Parse.parse parse_fun lexbuf)
  with Parse.Error err ->
    begin match err with
      | Parse.Lexing (invalid_input, err_pos) ->
         let (_, line, char) = Parse.position err_pos in
         `Error (line, "Lexing Error: line " ^
                       string_of_int line ^ ", character " ^
                       string_of_int char ^ ".")
      | Parse.Parsing (message, start_pos, end_pos) ->
        let _, start_line, start_character = position start_pos in
        let _, curr_line, curr_character = position end_pos in
        let open Printf in
        let lines =
          if curr_line = start_line
          then sprintf "line %d" curr_line
          else sprintf "lines %d-%d" start_line curr_line in
        let characters =
          if curr_line = start_line
          then sprintf "characters %d-%d" start_character curr_character
          else sprintf "character %d" start_character in
        let buf = Buffer.create 10 in
        bprintf buf "Parsing error %s, %s:\n"
          lines characters;
        begin match message with
          | None -> ()
          | Some error_message ->
            bprintf buf "\n%s\n" error_message
        end;
        `Error (start_line, Buffer.contents buf)
    end

let simple = {|
(lam (x : int).x + 4) 5
|}

let omega = {|
(lam(f : * -> *).(f (f : * -> * => * )))
((lam(f : * -> *).(f (f : * -> * => * ))) : ( * -> * ) -> * => * -> * )
|}

let factorial_f = Ftal.(F.show_exp (F.EApp (dummy_loc, Examples.factorial_f, [F.EInt (dummy_loc, 3)])))

let set_error ln m =
  let _ = Js.Unsafe.((coerce global)##seterror (Js.number_of_float (float_of_int ln)) (Js.string m)) in
  ()
let clear_errors _ =
  let _ = Js.Unsafe.((coerce global)##clearerrors) in
  ()

let hide_machine _ =
  H.((getElementById "machine")##setAttribute (Js.string "hidden") (Js.string "on"))
let show_machine _ =
  H.((getElementById "machine")##removeAttribute (Js.string "hidden"))
let set_text i t =
  let _ = Js.Unsafe.((coerce global)##settext (Js.string i) (Js.string t)) in
  ()
let set_editor t =
  let open Js in
  clear_errors ();
  hide_machine ();
  let _ = Unsafe.((coerce (global##.codemirror))##setValue (string t)) in
  ()
let ehandle s =
  H.handler (fun _ -> set_editor s; Js._false)
let get_editor _ =
  Js.Unsafe.((coerce (global##.codemirror))##getValue)
let set_click i h =
  H.((getElementById i)##.onclick := h);
  ()

let _ =
  let hist = ref ((Ftal.F.EUnit Ftal.dummy_loc, ([],[],[])), []) in
  let refresh _ =
    let ((e, (h,r,s)), past) = !hist in
    let _ = match Ftal.F.decomp e with
      | None ->
        H.((getElementById "next")##setAttribute (Js.string "disabled") (Js.string "on"));
        H.((getElementById "many")##setAttribute (Js.string "disabled") (Js.string "on"));
        let _ = set_text "context" (Ftal.F.show_exp e) in
        let _ = set_text "focus" "" in
        ()
      | Some (c, f) ->
        H.((getElementById "next")##removeAttribute (Js.string "disabled"));
        H.((getElementById "many")##removeAttribute (Js.string "disabled"));
        let _ = set_text "context" (Ftal.F.show_context c) in
        let _ = set_text "focus" (Ftal.F.show_ft f) in
        ()
    in
    let _ = set_text "pc" (string_of_int (List.length past)) in
    (* let _ = set_text "heap" (Ftal.T A L.show_heapm h) in (* TODO: name store*) *)
    ()
  in
  let next' _ =
    let ((e,m), rest) = !hist in
    let (nm,ne) = Ftal.F.step (m, e) in
    if e = ne && m = nm
    then ()
    else hist := ((ne,nm), (e,m)::rest)
  in
  let load _ =
    let open H in
    let _ =
      let s = Js.to_string (get_editor ()) in
      Ftal.(FTAL.(
          try
            match parse_report_loc Parse.f_expression_eof s with
            | `Success e -> begin
                let _ = tc default_context (FC e) in
                hist := ((e, ([],[],[])), []);
                refresh ();
                clear_errors ();
                show_machine ();
                Js.Opt.return Js._false
              end
            | `Error (line, msg) ->
              begin
                set_error line msg;
                Js.Opt.return Js._false
              end
          with TypeError (t,l) ->
            begin
              set_error l.line ("Type Error: " ^ t);
              hide_machine ();
              Js.Opt.return Js._false
            end
        )) in Js._false
  in
  let next _ =
    next' ();
    refresh ();
    Js._false
  in
  let prev _ =
    begin match !hist with
      | (_, []) -> ()
      | (_, x::xs) -> hist := (x,xs); refresh ()
    end; Js._false
  in
  let many _ =
    let rec repeat f = function | 0 -> () | n -> f (); repeat f (n-1) in
    repeat next' 100;
    refresh ();
    Js._false
  in
  set_click "load" (H.handler load);
  set_click "next" (H.handler next);
  set_click "prev" (H.handler prev);
  set_click "many" (H.handler many);
  hide_machine ();
  set_click "simple" (ehandle simple);
  set_click "omega" (ehandle omega);
  set_editor simple;
  ()
