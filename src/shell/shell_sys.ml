(* $Id: shell_sys.ml 50 2004-10-03 17:06:28Z gerd $
 * ----------------------------------------------------------------------
 *
 *)

let safe_close fd =
  (* Try to close, but don't fail if the descriptor is bad *)
  try
    Unix.close fd
  with
      Unix.Unix_error(Unix.EBADF,_,_) -> ()
;;

(*** environments ***)

(* The following functions assume that environments are typically small
 * such that optimized code to access them is normally not necessary.
 * I mean they are rather inefficient...
 *)

type environment = string array ref;;

let create_env () = ref [| |];;

let copy_env e =
  ref
    (Array.map
       String.copy
       !e
    )
;;

let set_env e a =
  let a' = Array.map String.copy a in
  e := a'
;;

let get_env e =
  ! (copy_env e)
;;

let iter_env ~f e =
  Array.iter
    f
    !e
;;

let iter_env_vars ~f e =
  let dest_var s =
    let k = String.index s '=' in
    (String.sub s 0 k, String.sub s (k+1) (String.length s - k - 1))
  in
  Array.iter
    (fun s ->
       try
	 let v, x = dest_var s in
	 f v x
       with
	   Not_found -> ()
    )
    !e
;;

let set_env_var e v x =
  begin try
    ignore(String.index v '=');
    invalid_arg "Shell_sys.set_env_var"
  with
      Not_found -> ();
  end;
  try
    let k = ref 0 in
    iter_env_vars
      (fun v' x' ->
	 if v' = v then begin
	   !e.(!k) <- v ^ "=" ^ x;
	   raise Exit
	 end
	 else
	   incr k
      )
      e;
    e := Array.append !e [| v ^ "=" ^ x |]
  with
      Exit -> ()
;;

let get_env_var e v =
  let x = ref "" in
  try
    iter_env_vars
      (fun v' x' ->
	 if v' = v then begin
	   x := x';
	   raise Exit
	 end
      )
      e;
    raise Not_found
  with
      Exit -> !x
;;

let current_env () =
  ref (Unix.environment())
;;





(*** commands, command groups, processes and process groups ***)

exception Fatal_error of exn;;

let () =
  Netexn.register_printer
    (Fatal_error Not_found)
    (fun e ->
       match e with
	 | Fatal_error e' ->
	     "Shell_sys.Fatal_error(" ^ Netexn.to_string e' ^ ")"
	 | _ ->
	     assert false
    )

type command =
    { mutable c_cmdname     : string;
      mutable c_arguments   : string array;
      mutable c_directory   : string option;
      mutable c_environment : environment;
      mutable c_descriptors : Unix.file_descr list;
      mutable c_assignments : (Unix.file_descr * Unix.file_descr) list;
      mutable c_filename    : string;
    }
;;

let command
      ?cmdname
      ?(arguments = [||])
      ?chdir
      ?(environment = current_env())
      ?(descriptors = [ Unix.stdin; Unix.stdout; Unix.stderr ])
      ?(assignments = [])
      ~filename
      () =
  let cmdname' =
    match cmdname with
	None      -> if String.contains filename '/' then
	               filename
  	             else
		       "./" ^ filename
      | Some name -> name
  in
  { c_cmdname = cmdname';
    c_arguments = arguments;
    c_directory = chdir;
    c_environment = environment;
    c_descriptors = descriptors;
    c_assignments = assignments;
    c_filename = filename;
  }
;;

let get_cmdname     c = c.c_cmdname     ;;
let get_arguments   c = c.c_arguments   ;;
let get_chdir       c = c.c_directory   ;;
let get_environment c = c.c_environment ;;
let get_descriptors c = c.c_descriptors ;;
let get_assignments c = c.c_assignments ;;
let get_filename    c = c.c_filename    ;;

let set_cmdname     c x = c.c_cmdname     <- x ;;
let set_arguments   c x = c.c_arguments   <- x ;;
let set_chdir       c x = c.c_directory   <- x ;;
let set_environment c x = c.c_environment <- x ;;
let set_descriptors c x = c.c_descriptors <- x ;;
let set_assignments c x = c.c_assignments <- x ;;
let set_filename    c x = c.c_filename    <- x ;;

let copy_command c =
  { c_cmdname     = String.copy c.c_cmdname;
    c_arguments   = Array.map String.copy c.c_arguments;
    c_directory   = c.c_directory;
    c_environment = copy_env c.c_environment;
    c_descriptors = c.c_descriptors;
    c_assignments = c.c_assignments;
    c_filename    = String.copy c.c_filename;
  }
;;

let is_executable_file name =
  try
    Unix.access name [ Unix.X_OK ];
    true
  with
      Unix.Unix_error(_,_,_) -> false
;;

let is_executable c = is_executable_file c.c_filename;;

let split_path s =
  (* move to shell_misc.ml ? *)
  let rec split_at j k =
    if k >= String.length s then
      let u = String.sub s j (k-j) in
      [u]
    else
      if s.[k] = ':' then
	let u = String.sub s j (k-j) in
	u :: split_at (k+1) (k+1)
      else
	split_at j (k+1)
  in
  let l = split_at 0 0 in
  List.filter (fun s -> s <> "") l
;;

exception Executable_not_found of string;;

let lookup_executable
      ?(path = split_path (try Unix.getenv "PATH" with Not_found -> ""))
      name =
  if String.contains name '/' then begin
    if is_executable_file name then
      name
    else
      raise (Executable_not_found name)
  end
  else begin
    let foundname = ref "" in
    try
      List.iter
	(fun loc ->
	   let candidate = Filename.concat loc name in
	   if is_executable_file candidate then begin
	     foundname := candidate;
	     raise Exit
	   end
	)
	path;
      raise (Executable_not_found name)
    with
	Exit -> !foundname
  end
;;

type group_action =
    New_bg_group
  | New_fg_group
  | Join_group of int
  | Current_group
;;


type process =
    { p_command : command;
      p_id : int;
      mutable p_status : Unix.process_status option;
        (* None means: process is still running *)
      mutable p_abandoned : bool;
        (* true means: the SIGCHLD handler will watch the process, "wait"
	 * is no longer possible
	 *)
    }
;;

let dummy_process =
  { p_command = command "XXX" ();
    p_id = 0;
    p_status = Some (Unix.WEXITED 0);
    p_abandoned = false;
  }
;;


let command_of_process p = p.p_command;;

let all_signals =
  [ Sys.sigabrt;
    Sys.sigalrm;
    Sys.sigfpe;
    Sys.sighup;
    Sys.sigill;
    Sys.sigint;
    (* Sys.sigkill; -- not modifiable *)
    Sys.sigpipe;
    Sys.sigquit;
    Sys.sigsegv;
    Sys.sigterm;
    Sys.sigusr1;
    Sys.sigusr2;
    Sys.sigchld;
    Sys.sigcont;
    (* Sys.sigstop; -- not modifiable *)
    Sys.sigtstp;
    Sys.sigttin;
    Sys.sigttou;
    Sys.sigvtalrm;
    Sys.sigprof; ];;


let posix_run
      ?(group = Current_group)
      ?(pipe_assignments = [])
      c =

  (* This [run] implementation bases on [Netsys_posix.spawn] *)
  
  let args = Array.append [| c.c_cmdname |] c.c_arguments in

  (* Signals:
   * - Keyboard signals SIGINT, SIGQUIT: the subprocess should inherit the
   *   current setting (ignore or terminate).
   * - SIGCHLD: this must be reset to default otherwise the subprocess will
   *   be confused ("wait" would not work as expected)
   * - other signals: it is good practice also to reset them to default
   *)

  let sig_actions =
    List.flatten
      (List.map
	 (fun signo ->
	    if signo = Sys.sigint || signo = Sys.sigquit then
	      [ ]  
		(* keep them as-is. If a handler exists, it will be reset
		   to the default action by [exec]
		 *)
	    else
	      [ Netsys_posix.Sig_default signo ]
	 )
	 all_signals
      ) in

  (* Descriptor assignments. We have to translate the parallel
     pipe_assigmnents into a list of [dup2] operations. Also, we have
     to check which descriptors are kept open at all
   *)

  let pipe_assignments =
    List.map
      (fun (from_fd, to_fd) -> (ref from_fd, to_fd))
                           (* such that from_fd can be altered *)
      pipe_assignments
  in

  (* Collect the descriptors that must not be closed by [exec] (final view): *)
  let open_descr_ht = Hashtbl.create 50 in

  List.iter
    (fun (from_fd, to_fd) ->
       Hashtbl.replace open_descr_ht to_fd ())
    pipe_assignments;
  List.iter
    (fun (from_fd, to_fd) ->
       Hashtbl.remove  open_descr_ht from_fd;
       Hashtbl.replace open_descr_ht to_fd ())
    c.c_assignments;
  List.iter
    (fun fd ->
       Hashtbl.replace open_descr_ht fd ())
    c.c_descriptors;

  (* In this table we track the use of descriptors (dup2 tracking).
     At this point, this table must contain the fd's that will be used
     later, either as a source fd in a dup2, or it ends in [c_descriptors].
     In the algorithm below, temp_descr_ht is then updated by each dup2.
   *)
  let temp_descr_ht = Hashtbl.create 50 in

  Hashtbl.iter       (* starting point: the fd's that remain finally open *)
    (fun fd _ -> Hashtbl.replace temp_descr_ht fd ())
    open_descr_ht;
  List.iter          (* go backward: first the c_assignments *)
    (fun (from_fd, to_fd) -> 
       Hashtbl.remove  temp_descr_ht to_fd;
       Hashtbl.replace temp_descr_ht from_fd ())
    (List.rev c.c_assignments);
  List.iter
    (fun (from_fd, to_fd) -> 
       Hashtbl.remove  temp_descr_ht to_fd;
    )
    pipe_assignments;
  List.iter
    (fun (from_fd, to_fd) -> 
       Hashtbl.replace temp_descr_ht to_fd ();
    )
    pipe_assignments;

  (* Here we manage additional descriptors that are required for emulating
     parallel assignment by sequential dup2's:
   *)
  let next_fd = ref 3 in
  let rec new_descriptor() =
    let fd = Netsys_posix.file_descr_of_int !next_fd in
    if (Hashtbl.mem temp_descr_ht fd) then (
      incr next_fd;
      new_descriptor();
    ) else (
      Hashtbl.add temp_descr_ht fd ();
      fd
    ) in
  let alloc_descriptor fd =
    Hashtbl.replace temp_descr_ht fd () in
  let rel_descriptor fd =
    if Hashtbl.mem temp_descr_ht fd then (
      Hashtbl.remove temp_descr_ht fd;
      let ifd = Netsys_posix.int_of_file_descr fd in
      if ifd < !next_fd then next_fd := ifd
    ) in
  
  (* These are all destination fd's of [dup2]. *)
  let dest_descr_ht = Hashtbl.create 50 in

  let fd_actions = ref [] in    (* actions in reverse order *)

  (* Do first pipe_assignments. These are _parallel_ assignments, i.e.
   * if (fd1, fd2) and (fd2, fd3) are in the list, the first assginment
   * fd1 -> fd2 must not overwrite fd2, because the second assignment
   * fd2 -> fd3 refers to the original fd2.
   *)
  let rec assign_parallel fdlist =
    match fdlist with
      | (from_fd, to_fd) :: fdlist' ->
	  (* If to_fd occurs on the left side in fdlist', we must be
           * careful, and rename this descriptor.
	   *)
	  if !from_fd <> to_fd then (
	    if List.exists (fun (fd1,fd2) -> !fd1=to_fd) fdlist' then (
	      let new_fd = new_descriptor() in
	      List.iter
		(fun (fd1, fd2) -> if !fd1 = to_fd then fd1 := new_fd)
		fdlist';
	      fd_actions := 
		(Netsys_posix.Fda_dup2(to_fd, new_fd)) :: !fd_actions;
	      Hashtbl.replace dest_descr_ht new_fd ();
	    );
	    fd_actions := 
	      (Netsys_posix.Fda_dup2(!from_fd, to_fd)) :: !fd_actions;
	    alloc_descriptor to_fd;
	    rel_descriptor !from_fd;
	    Hashtbl.replace dest_descr_ht to_fd ();
	  );
	  assign_parallel fdlist'
      | [] ->
	  ()
  in
  assign_parallel pipe_assignments;

  (* Also perform c.c_assignments; however this can be done in a
   * sequential way.
   *)
  List.iter
    (fun (from_fd, to_fd) ->
       if from_fd <> to_fd then (
	 fd_actions := 
	   (Netsys_posix.Fda_dup2(from_fd, to_fd)) :: !fd_actions;
	 alloc_descriptor to_fd;
	 rel_descriptor from_fd;
	 Hashtbl.replace dest_descr_ht to_fd ();
       )
    )
    c.c_assignments;

  (* Close the descriptors that are not shared with this process: *)
  let max_open_ht = ref 2 in
  Hashtbl.iter
    (fun fd _ ->
       let ifd = Netsys_posix.int_of_file_descr fd in
       if ifd > !max_open_ht then max_open_ht := ifd
    )
    open_descr_ht;
  let keep_open = Array.create (!max_open_ht+1) false in
  Hashtbl.iter
    (fun fd _ ->
       let ifd = Netsys_posix.int_of_file_descr fd in
       keep_open.(ifd) <- true
    )
    open_descr_ht;
  fd_actions :=
    (Netsys_posix.Fda_close_except keep_open) :: !fd_actions;

  (* Clear the close-on-exec flag for the shared descriptors. There
     is no Fda_clear_close_on_exec, so we have to get this effect by
     using dup2 (i.e. dup2(fd, tmp_fd); dup2(tmp_fd, fd); close(tmp_fd) ).
     Note that dup2(fd,fd) is not sufficient (POSIX does not mention
     that the close-on-exec flag is cleared in this case).
   *)
  let clear_fd = new_descriptor() in
  Hashtbl.iter
    (fun fd _ ->
       if not (Hashtbl.mem dest_descr_ht fd) then
	 fd_actions := 
	   [ Netsys_posix.Fda_close clear_fd;   (* rev order! *)
	     Netsys_posix.Fda_dup2(clear_fd, fd);
	     Netsys_posix.Fda_dup2(fd, clear_fd)
	   ] @ !fd_actions;
    )
    open_descr_ht;

  let pg =
    match group with
      | Current_group -> Netsys_posix.Pg_keep
      | New_bg_group  -> Netsys_posix.Pg_new_bg_group
      | Join_group g  -> Netsys_posix.Pg_join_group g
      | New_fg_group  -> Netsys_posix.Pg_new_fg_group in

  let chdir =
    match c.c_directory with
      | None   -> Netsys_posix.Wd_keep
      | Some d -> Netsys_posix.Wd_chdir d in

  (* Now spawn the new process: *)
  let pid =
    Netsys_posix.spawn
      ~chdir
      ~pg
      ~fd_actions:(List.rev !fd_actions)
      ~sig_actions
      ~env:!(c.c_environment)
      c.c_filename
      args in

  { p_command = c;
    p_id = pid;
    p_status = None;
    p_abandoned = false;
  }
;;


let run = posix_run;;
(* Right now no Win32 implementation available *)


let process_id p = p.p_id;;

let status p =
  match p.p_status with
      None -> raise Not_found
    | Some s -> s
;;

type process_event =
    File_read of Unix.file_descr
  | File_write of Unix.file_descr
  | File_except of Unix.file_descr
  | Process_event of process
  | Signal
;;

exception Loop;;

let wait
      ?(wnohang = false)
      ?(wuntraced = false)
      ?(restart = false)
      ?(check_interval = 0.1)
      ?(read = [])
      ?(write = [])
      ?(except = [])
      pl0 =

  let pl =
    List.filter (fun p -> p.p_status = None) pl0 in
  (* Only processes we not yet have waited for are relevant *)

  let select_emulation = lazy (
    let pset = Netsys_pollset_generic.standard_pollset() in
    Netsys_pollset_generic.select_emulation pset
  ) in

  if List.exists (fun p -> p.p_abandoned) pl then
    failwith "Shell_sys.wait: cannot wait for abandoned processes";

  let one_process =
    match pl with [ _ ] -> true | _ -> false in

  let rec wait_until_process_event() =
    (* Note: Do not use this function if wnohang *)
    let flags =
      if wuntraced then [ Unix.WUNTRACED ] else [] in
    match pl with
	[ p ] ->
	  begin try
	    let _, status = Unix.waitpid flags p.p_id in
	    p.p_status <- Some status;
	    [ Process_event p ]
	  with
	      Unix.Unix_error(Unix.EINTR,_,_) as ex ->
		if restart
		then wait_until_process_event()
		else raise ex
	  end
      | _ ->
	  assert false
  in

  let check_process_events() =
    let flags =
      if wuntraced then [ Unix.WUNTRACED; Unix.WNOHANG ] else [ Unix.WNOHANG ] in
    List.flatten
      (List.map
	 (fun p ->
	    let pid, status = Unix.waitpid flags p.p_id in
	    if pid = p.p_id then begin
	      p.p_status <- Some status;
	      [ Process_event p ]
	    end
	    else []
	 )
	 pl
      )
  in

  let rec wait_until_event () =
    if read = [] && write = [] && except = [] && one_process && not wnohang then
      wait_until_process_event()
    else
      try
	let pl_ev = check_process_events () in
	if pl_ev <> [] then
	  pl_ev
	else
	  let timeout =
	    if wnohang then 0.0 else check_interval in
	  let indicate_read, indicate_write, indicate_except =
	    (Lazy.force select_emulation) read write except timeout in
	  if indicate_read = [] && indicate_write = [] && indicate_except = []
	     && not wnohang
	  then
	    raise Loop        (* make sure this is tail-recursive! *)
	  else
	    (List.map (fun fd -> File_read fd) indicate_read) @
	    (List.map (fun fd -> File_write fd) indicate_write) @
	    (List.map (fun fd -> File_except fd) indicate_except)
      with
	  Loop ->
	    wait_until_event()
	| Unix.Unix_error(Unix.EINTR,_,_) as ex ->
	    if restart then
	      wait_until_event()
	    else
	      raise ex
  in

  if read = [] && write = [] && except = [] && pl = [] then
    []
  else
    wait_until_event()
;;


let call c =
  let p = run c in
  let ev = wait ~restart:true [ p ] in
  match ev with
      [ Process_event p' ] ->
	assert(p == p');
	p
    | _ ->
	assert false
;;


let kill ?(signal = Sys.sigterm) p =
  Unix.kill p.p_id signal
;;



type system_handler =
    { sys_register :
        ?wuntraced:bool ->
	?check_interval:float ->
	?read:(Unix.file_descr list) ->
	?write:(Unix.file_descr list) ->
        ?except:(Unix.file_descr list) ->
	process list ->
        (process_event list -> unit) ->
	  unit;

      sys_wait :
	unit -> unit;
    }

exception Exit_event_loop

let register_callback (current_waiter : (unit -> unit) ref)
                      ?wuntraced ?check_interval ?read ?write ?except pl cb =
  current_waiter :=
    (fun () ->
       try
	 let el = wait
		    ?wuntraced ~restart:false ?check_interval ?read ?write
		    ?except pl in
	 if el = [] then begin
	   let old_waiter = !current_waiter in
	   cb [];
	   if old_waiter == !current_waiter then raise Exit_event_loop;
	 end
	 else
	   cb el
       with
	   Unix.Unix_error(Unix.EINTR,_,_) ->
	     cb [ Signal ]
    )
;;


let do_event_loop (current_waiter : (unit -> unit) ref) () =
  try
    while true do
      !current_waiter()
    done
  with
      Exit_event_loop -> ()
;;


let standard_system_handler() =
  let current_waiter = ref (fun () -> ()) in
  { sys_register = register_callback current_waiter;
    sys_wait = do_event_loop current_waiter;
  }
;;


(*** command and process groups ***)

type pipeline =
    { pl_src_command : command;
      pl_dest_command : command;
      pl_src_descr : Unix.file_descr;
      pl_dest_descr : Unix.file_descr;
      pl_bidirectional : bool;
    }
;;

type pipehandler =
    { ph_command : command;
      ph_descr : Unix.file_descr;
      ph_handler : (Unix.file_descr -> bool);
    }
;;

type job =
    { mutable cg_commands : command list;
      mutable cg_pipelines : pipeline list;
      mutable cg_producers : pipehandler list;
      mutable cg_consumers : pipehandler list;
    }
;;


let new_job () =
  { cg_commands = [];
    cg_pipelines = [];
    cg_producers = [];
    cg_consumers = [];
  }
;;


let add_command c cg =
  if List.memq c cg.cg_commands then
    failwith "Shell_sys.add_command: Cannot add the same command twice; use copy_command to add a copy";
  cg.cg_commands <- c :: cg.cg_commands;
  ()
;;


let add_pipeline
      ?(bidirectional = false)
      ?(src_descr = Unix.stdout)
      ?(dest_descr = Unix.stdin)
      ~src
      ~dest
      cg =

  if not (List.memq src cg.cg_commands) then
    failwith "Shell_sys.add_pipeline: the ~src command is not member of the command group";
  if not (List.memq dest cg.cg_commands) then
    failwith "Shell_sys.add_pipeline: the ~dest command is not member of the command group";
  let pl =
    { pl_src_command   = src;
      pl_dest_command  = dest;
      pl_src_descr     = src_descr;
      pl_dest_descr    = dest_descr;
      pl_bidirectional = bidirectional;
    }
  in

  cg.cg_pipelines <- pl :: cg.cg_pipelines
;;


let add_producer
      ?(descr = Unix.stdin)
      ~producer
      c
      cg =

  if not (List.memq c cg.cg_commands) then
    failwith "Shell_sys.add_producer: the passed command is not member of the command group";

  let ph =
    { ph_command = c;
      ph_descr   = descr;
      ph_handler = producer
    }
  in

  cg.cg_producers <- ph :: cg.cg_producers
;;


let add_consumer
      ?(descr = Unix.stdout)
      ~consumer
      c
      cg =

  if not (List.memq c cg.cg_commands) then
    failwith "Shell_sys.add_consumer: the passed command is not member of the command group";

  let ph =
    { ph_command = c;
      ph_descr   = descr;
      ph_handler = consumer
    }
  in

  cg.cg_consumers <- ph :: cg.cg_consumers
;;


let from_string
      ?(pos = 0)
      ?len
      ?(epipe = fun () -> ())
      s =
  if pos < 0 || pos > String.length s then
    invalid_arg "Shell_sys.from_string";
  let max_pos =
    match len with
	None   -> String.length s
      | Some l ->
	  if l < 0 then invalid_arg "Shell_sys.from_string";
	  pos + l
  in
  if max_pos > String.length s then invalid_arg "Shell_sys.from_string";
  (* ==> Take material from positions pos to max_pos-1 from s *)

  let current_pos = ref pos in

  function fd ->
    let m = max_pos - !current_pos in
    let n =
      if m > 0 then begin
	try
	  Unix.write fd s (!current_pos) m
	with
	    Unix.Unix_error(Unix.EPIPE,_,_) ->
	      epipe();
	      m            (* forces that the descriptor will be closed *)
	  | Unix.Unix_error((Unix.EAGAIN | Unix.EWOULDBLOCK),_,_) ->
	      (* maybe somebody has set non-blocking mode for fd *)
	      0
	  (* We do not catch EINTR - the calling "wait_group" routine
	   * arranges that already
	   *)
      end
      else
	0 in
    current_pos := !current_pos + n;
    if !current_pos = max_pos then begin
      Unix.close fd;
      false
    end
    else
      true
;;


let from_stream
      ?(epipe = fun () -> ())
      s =
  let current_el  = ref None in
  let current_pos = ref 0 in

  function fd ->
    (* If necessary, try to get the next stream element: *)
    begin match !current_el with
	None ->
	  begin try
	    let x = Stream.next s in
	    current_el := Some x;
	    current_pos := 0;
	  with
	      Stream.Failure ->
		()
	  end
      | _ ->
	  ()
    end;
    (* (Continue to) write the current stream element: *)
    match !current_el with
	None ->
	  Unix.close fd;
	  false
      | Some x ->
	  let m = String.length x - !current_pos in
	  let n =
	    try
	      Unix.write fd x (!current_pos) m
	    with
		Unix.Unix_error(Unix.EPIPE,_,_) ->
		  epipe();
		  m            (* forces that the descriptor will be closed *)
	      | Unix.Unix_error((Unix.EAGAIN | Unix.EWOULDBLOCK),_,_) ->
		  (* maybe somebody has set non-blocking mode for fd *)
		  0
              (* We do not catch EINTR - the calling "wait_group" routine
	       * arranges that already
	       *)
	  in
	  current_pos := !current_pos + n;
	  if !current_pos = String.length x then current_el := None;
	  true
;;


let to_buffer b =
  let m = 4096 in
  let s = String.create m in

  let next fd =
    let n =
      try
	let n = Unix.read fd s 0 m in
	if n = 0 then -1 else n
      with
	| Unix.Unix_error((Unix.EAGAIN | Unix.EWOULDBLOCK),_,_) ->
	    (* maybe somebody has set non-blocking mode for fd *)
	    0
    in
    if n < 0 then begin
      (* EOF *)
      Unix.close fd;
      false
    end
    else begin
      Buffer.add_substring b s 0 n;
      true
    end
  in
  next
;;


exception No_Unix_process_group;;

type group_mode = Same_as_caller | Foreground | Background
;;

type job_status =
    Job_running
  | Job_partially_running
  | Job_ok
  | Job_error
  | Job_abandoned
;;

type job_instance =
    { pg_id : int;
      pg_cg : job;
      pg_processes : process list;
      pg_mode : group_mode;
      pg_forward_signals : bool;
      mutable pg_fd_producer_alist : (Unix.file_descr * pipehandler) list;
      mutable pg_fd_consumer_alist : (Unix.file_descr * pipehandler) list;
      mutable pg_pending : process_event list;
      mutable pg_status : job_status;
      mutable pg_exception : exn;
    }
;;

let current_jobs = ref [];;
  (* Jobs that have not yet finished
   * Invariant: For all jobs in current_job the status is either
   * Job_running or Job_partially_running.
   *)

let omtp = !Netsys_oothr.provider

let mutex_jobs = omtp # create_mutex()
  (* For multi-threaded programs: lock/unlock the mutex for current_jobs *)
  (* NOTE: Although here is some code for multi-threaded programs, this
   * does not mean it works
   *)

let with_current_jobs f =
  mutex_jobs # lock();
  ( try
      f()
    with
	any ->
	  mutex_jobs # unlock();
	  raise any
  );
  mutex_jobs # unlock()
;;


let abandoned_job_processes = ref [| dummy_process |];;
  (* Processes of jobs that have been abandoned, but not yet waited for *)

  (* Note multi-threaded programs: There is no mutex for this variable,
   * because it is accessed from a signal handler, and pthread functions
   * have undefined behaviour when called from signal handlers. So we
   * have to protect it by other means: Every access has to be atomic,
   * i.e. the OCaml runtime must not check on pending signals during the
   * access. The current OCaml implementation performs these checks when
   * functions are called (except inlined functions), so we have to make
   * that sure.
   *)


type safe_fd =
    FD of Unix.file_descr
  | FD_closed

let mk_fd fd = ref(FD fd);;

let dest_fd safe_fd =
  match !safe_fd with
      FD fd ->
	fd
    | FD_closed ->
	failwith "Descriptor is closed"
;;

let close_fd safe_fd =
  match !safe_fd with
      FD fd ->
	Unix.close fd;
	safe_fd := FD_closed;
    | FD_closed ->
	()
;;


exception Pass_exn of exn;;

let run_job
      ?(mode = Same_as_caller)
      ?(forward_signals = true)
      cg =

  if cg.cg_commands = [] then
    invalid_arg "Shell_sys.run_job: No commands to start";

  (* Global stores: *)

  let pipe_descriptors = ref [] in
    (* The pipeline descriptor pairs created so far *)

  let producer_descriptors = ref [] in
  let consumer_descriptors = ref [] in

  let processes = ref [] in
  let leader = ref None in


  let build_interprocess_pipelines() =
    (* Basically, for every pipeline found in cg a new Unix pipeline is created.
     * However, there are cases where the same Unix pipeline can be reused for
     * several cg.cg_pipelines:
     * - If pipelines read from the same descriptor of the same command
     * - If pipelines write to the same descriptor of the same command
     * This makes it possible that a pipeline may have several readers/writers.
     *)
    List.iter
      (fun pipe ->
	 (* Is there already a pipeline in pipe_descriptors for the same command
	  * and the same descriptor?
	  *)
	 let other_src =
	   try
	     let _, (other_out_end, other_in_end) =
	       List.find (fun (p, _) ->
			    (p.pl_src_command == pipe.pl_src_command) &&
			    (p.pl_src_descr == pipe.pl_src_descr))
	                 !pipe_descriptors
	     in
	     Some (other_out_end, other_in_end)
	   with Not_found -> None
	 in
	 let other_dest =
	   try
	     let _, (other_out_end, other_in_end) =
	       List.find (fun (p, _) ->
			    (p.pl_dest_command == pipe.pl_dest_command) &&
			    (p.pl_dest_descr == pipe.pl_dest_descr))
	                 !pipe_descriptors
	     in
	     Some (other_out_end, other_in_end)
	   with Not_found -> None
	 in
	 (* Check now src/dest cross comparison. For simple pipelines this is an
	  * error. For bidirectional pipelines it would be possible to make it
	  * working; however, it is not worth the effort.
	  *)
	 if List.exists (fun (p, _) ->
			   ((p.pl_src_command == pipe.pl_dest_command) &&
			    (p.pl_src_descr = pipe.pl_dest_descr)) ||
			   ((p.pl_dest_command == pipe.pl_src_command) &&
			    (p.pl_dest_descr = pipe.pl_src_descr)))
	                !pipe_descriptors
	 then
	   failwith "Shell_sys.run_group: Pipeline construction not possible or too ambitious";

         (* Distinguish between the various cases: *)

	 match other_src, other_dest with
	     None, None ->
	       (* Create a new pipeline: *)
	       let out_end, in_end =
		 if pipe.pl_bidirectional then
		   Unix.socketpair Unix.PF_UNIX Unix.SOCK_STREAM 0
		 else
		   Unix.pipe()
	       in
	       pipe_descriptors :=
	         (pipe, (mk_fd out_end, mk_fd in_end)) :: !pipe_descriptors
	   | Some (out_end, in_end), None ->
	       pipe_descriptors :=
	         (pipe, (out_end, in_end)) :: !pipe_descriptors
	   | None, Some (out_end, in_end) ->
	       pipe_descriptors :=
	         (pipe, (out_end, in_end)) :: !pipe_descriptors
	   | _ ->
	       (* case Some, Some: the same pipeline exists twice. We can drop
		* the second.
		*)
	       ()
      )
      cg.cg_pipelines
  in

  let close_interprocess_pipelines() =
    (* Close both ends of the (interprocess) pipeline *)
    List.iter
      (fun (_, (out_end, in_end)) ->
	 close_fd out_end;
	 close_fd in_end
      )
      !pipe_descriptors;
  in

  let check_ph is_producer ph =
    (* Is there already a pipeline in producer_descriptors for the
     * same command and the same descriptor? Or in pipeline_descriptors?
     * This case cannot be handled and causes an error.
     *)
    let name = if is_producer then "producer" else "consumer" in
    let op   = if is_producer then "write to" else "read from" in
    if
      List.exists
	(fun (ph',_) ->
	   (ph'.ph_command == ph.ph_command) &&
	   (ph'.ph_descr = ph.ph_descr))
	!producer_descriptors ||
      List.exists
	(fun (ph',_) ->
	   (ph'.ph_command == ph.ph_command) &&
	   (ph'.ph_descr = ph.ph_descr))
	!consumer_descriptors
    then
      failwith ("Shell_sys.run_job: A " ^ name ^
		" cannot " ^ op ^
		" a descriptor which is already bound to another producer/consumer");

    if
      List.exists
	(fun (pl',_) ->
	   (pl'.pl_src_command == ph.ph_command &&
            pl'.pl_src_descr = ph.ph_descr) ||
	   (pl'.pl_dest_command == ph.ph_command &&
            pl'.pl_dest_descr = ph.ph_descr))
	!pipe_descriptors
    then
      failwith ("Shell_sys.run_job: A " ^ name ^
		" cannot " ^ op ^
		" a descriptor which is already bound to an interprocess pipeline");
  in

  let build_producer_descriptors() =
    (* For every producer create a new pipeline *)
    List.iter
      (fun ph ->
	 check_ph true ph;
	 let out_end, in_end = Unix.pipe() in
	 Unix.set_nonblock in_end;
	 producer_descriptors :=
	   (ph, (mk_fd out_end, mk_fd in_end)) :: !producer_descriptors;
      )
      cg.cg_producers
  in

  let build_consumer_descriptors() =
    (* For every consumer create a new pipeline *)
    List.iter
      (fun ph ->
	 check_ph false ph;
	 let out_end, in_end = Unix.pipe() in
	 Unix.set_nonblock out_end;
	 consumer_descriptors :=
	   (ph, (mk_fd out_end, mk_fd in_end)) :: !consumer_descriptors;
      )
      cg.cg_consumers
  in

  let close_producer_descriptors ~fully =
    (* not fully: close the output side of the pipelines only.
     * fully: close both sides of the pipelines
     *)
    List.iter
      (fun (ph,(out_end, in_end)) ->
	 close_fd out_end;
	 if fully then close_fd in_end;
      )
      !producer_descriptors;
  in

  let close_consumer_descriptors ~fully =
    (* not fully: close the input side of the pipelines only.
     * fully: close both sides of the pipelines
     *)
    List.iter
      (fun (ph,(out_end, in_end)) ->
	 close_fd in_end;
	 if fully then close_fd out_end;
      )
      !consumer_descriptors;
  in

  let start_processes() =
    let group_behaviour =
      ref (match mode with
	       Same_as_caller -> Current_group
	     | Foreground     -> New_fg_group
	     | Background     -> New_bg_group) in

    (* Note: the following iteration is performed in the reverse direction as
     * the commands have been added. This means that the last added command
     * will be started first, and will be the process group leader.
     *)

    List.iter
      (fun c ->

         (* Is there a pipeline reading from this command? *)

         (* Note: multiple reading pipelines for the same descriptor are
	  * supported although such a construction is quite problematic as it
	  * is undefined which pipeline gets which packet of data
	  *)

	 let rd_assignments =
	   let pipes =
	     List.find_all
	       (fun pl' -> pl'.pl_src_command == c)
	       cg.cg_pipelines in
	   let consumers =
	     List.find_all
	       (fun ph -> ph.ph_command == c)
	       cg.cg_consumers in

	   List.map
	     (fun pipe ->
		let (out_end, in_end) = List.assq pipe !pipe_descriptors in
		(dest_fd in_end, pipe.pl_src_descr)
	     )
	     pipes
	   @
	   List.map
	     (fun ph ->
		let (out_end, in_end) = List.assq ph !consumer_descriptors in
		(dest_fd in_end, ph.ph_descr)
	     )
	     consumers
	 in

         (* Is there a pipeline writing to this command? *)

	 let wr_assignments =
	   let pipes =
	     List.find_all
	       (fun pl' -> pl'.pl_dest_command == c)
	       cg.cg_pipelines in
	   let producers =
	     List.find_all
	       (fun ph -> ph.ph_command == c)
	       cg.cg_producers in

	   List.map
	     (fun pipe ->
		let (out_end, in_end) = List.assq pipe !pipe_descriptors in
		(dest_fd out_end, pipe.pl_dest_descr)
	     )
	     pipes
	   @
	   List.map
	     (fun ph ->
		let (out_end, in_end) = List.assq ph !producer_descriptors in
		(dest_fd out_end, ph.ph_descr)
	     )
	     producers
	 in

         (* Note: It is essential that ~pipe_assignments are performed in a
	  * parallel way, because it is possible that assignment pairs exist
	  * (in_end, pl.pl_src_descr) and (out_end, pl.pl_dest_descr) with
	  * pl.pl_src_descr = out_end.
	  *)

	 let p =
	   run
	     ~group: !group_behaviour
	     ~pipe_assignments: (rd_assignments @ wr_assignments)
	     c
	 in

	 processes := p :: !processes;
	 if !leader = None then leader := Some p;

	 if !group_behaviour = New_fg_group || !group_behaviour = New_bg_group
	 then
	   group_behaviour := Join_group (process_id p)
      )
      cg.cg_commands
  in

  try
    (* Start the new process group: *)

    let fd_producer_alist = ref [] in
    let fd_consumer_alist = ref [] in

    build_interprocess_pipelines();
    build_producer_descriptors();
    build_consumer_descriptors();
    start_processes();
    close_interprocess_pipelines();
    pipe_descriptors := [];
    close_producer_descriptors ~fully:false;
    fd_producer_alist := List.map
                           (fun (ph, (_, in_end)) -> (dest_fd in_end, ph))
                           !producer_descriptors;
    producer_descriptors := [];
    close_consumer_descriptors ~fully:false;
    fd_consumer_alist := List.map
                           (fun (ph, (out_end, _)) -> (dest_fd out_end, ph))
                           !consumer_descriptors;
    consumer_descriptors := [];

    (* Store the new process group: *)

    let g =
      { pg_id = if mode = Same_as_caller then (-1)
                else (match !leader with
	 		  Some p -> process_id p
			| None -> assert false);
	pg_cg = cg;
	pg_processes = !processes;
	pg_mode = mode;
	pg_forward_signals = forward_signals;
	pg_fd_producer_alist = !fd_producer_alist;
	pg_fd_consumer_alist = !fd_consumer_alist;
	pg_pending = [];
	pg_status = Job_running;
	pg_exception = Not_found;
      }
    in

    with_current_jobs (fun () -> current_jobs := g :: !current_jobs);

    (* Return g as result *)

    g

  with
    | ex ->
	(* If another error happens while it is tried to recover from the
	 * first error, a Fatal_error is raised.
	 *)
	try
	  (* Close all interprocess pipelines (if not already done) *)
	  close_interprocess_pipelines();
	  pipe_descriptors := [];
	  (* Close all producer/consumer pipelines fully *)
	  close_producer_descriptors ~fully:true;
	  close_consumer_descriptors ~fully:true;
	  producer_descriptors := [];
	  consumer_descriptors := [];
	  (* If there is at least one process, return a partial result *)
	  if !processes <> [] then begin
	    let g =
	      { pg_id = if mode = Same_as_caller then (-1)
                        else (match !leader with
	 			  Some p -> process_id p
				| None -> assert false);
		pg_cg = cg;
		pg_processes = !processes;
		pg_mode = mode;
		pg_forward_signals = forward_signals;
		pg_fd_producer_alist = [];
		pg_fd_consumer_alist = [];
		pg_pending = [];
		pg_status = Job_partially_running;
		pg_exception = ex;
	      }
	    in
	    with_current_jobs (fun () -> current_jobs := g :: !current_jobs);
	    g
	  end
	  else
	    (* Raise ex again *)
	    raise (Pass_exn ex)
	with
	  | Pass_exn ex ->
	      raise ex
	  | (Fatal_error ex') as ex ->
	      raise ex
	  | ex' ->
	      raise (Fatal_error ex')
;;


let processes pg = pg.pg_processes;;

let process_group_leader pg =
  try
    List.find (fun p -> process_id p = pg.pg_id) pg.pg_processes
  with
      Not_found -> raise No_Unix_process_group
;;

let process_group_id pg =
  if pg.pg_id >= 0 then pg.pg_id else raise No_Unix_process_group
;;

let process_group_expects_signals pg =
  pg.pg_mode = Background && pg.pg_forward_signals
;;

let job_status pg = pg.pg_status;;


let close_job_descriptors pg =
  (* Close the pipeline descriptors used for producers and consumers.
   * These alists only contain the descriptors that are still open,
   * so we can simply close them.
   *)
  List.iter
    (fun (fd,_) -> Unix.close fd)
    pg.pg_fd_consumer_alist;
  pg.pg_fd_consumer_alist <- [];
  List.iter
    (fun (fd,_) -> Unix.close fd)
    pg.pg_fd_producer_alist;
  pg.pg_fd_producer_alist <- []
;;


let register_job sys pg =

  let read_list () =
    (* Check the list of consumers, and extract the list of file descriptors
     * we are reading from.
     *)
    List.map fst pg.pg_fd_consumer_alist
  in

  let write_list () =
    (* Check the list of producers, and extract the list of file descriptors
     * we want to write to
     *)
    List.map fst pg.pg_fd_producer_alist
  in

  let rec restartable f x =
    if true (* restart *) then   (* TODO *)
      (* Currently, we catch EINTR always. This is not wrong, but it would be
       * better to generate Signal events instead.
       *)
      try
	f x
      with
	  Unix.Unix_error(Unix.EINTR,_,_) ->
	    restartable f x
    else
      f x
  in

  let handle_event e =
    (* may fail because of an exception in one of the called handlers! *)
    match e with
	File_except _ ->
	  assert false
      | Process_event _ ->
	  ()
      | File_read fd ->
	  (* Find the consumer reading from this fd *)
	  let consumer =
	    try List.assoc fd pg.pg_fd_consumer_alist
	    with Not_found -> assert false
	  in
	  let result = restartable consumer.ph_handler fd in
	  if not result then begin
	    (* remove the consumer from the list of consumers *)
	    pg.pg_fd_consumer_alist <- List.remove_assoc
	                                 fd
	                                 pg.pg_fd_consumer_alist
	  end
      | File_write fd ->
	  (* Find the producer writing to this fd *)
	  let producer =
	    try List.assoc fd pg.pg_fd_producer_alist
	    with Not_found -> assert false
	  in
	  let result = restartable producer.ph_handler fd in
	  if not result then begin
	    (* remove the producer from the list of producers *)
	    pg.pg_fd_producer_alist <- List.remove_assoc
	                                 fd
	                                 pg.pg_fd_producer_alist
	  end
      | Signal -> ()
  in

  let rec callback events =
    if events = [] then begin
      (* This is the last callback! *)
      (* All processes have finished. *)
      let successful =
	List.for_all
	  (fun p ->
	     try status p = Unix.WEXITED 0 with Not_found -> assert false)
	  pg.pg_processes
      in
      let new_status = if successful then Job_ok else Job_error in
      pg.pg_status <- new_status;

      with_current_jobs
	(fun () ->
	   current_jobs := List.filter (fun ji -> ji != pg) !current_jobs);

      close_job_descriptors pg;

      (* Because we do not call sys.sys_register here, the event loop will
       * be terminated.
       *)
    end
    else begin
      (* Handle events *)
      pg.pg_pending <- pg.pg_pending @ events;
      while pg.pg_pending <> [] do
	match pg.pg_pending with
	    e :: elist' ->
	      handle_event e;           (* may raise arbitrary exception *)
	      pg.pg_pending <- elist';
	      (* CHECK: maybe it is better to first remove [e] from the list
	       * of pending events. The current solution means that the
	       * event handler will be called again with the same event
	       * if an exception is raised. (However, Equeue does the same.)
	       *)
	  | _ ->
	      assert false
      done;
      (* Register new handler: *)
      register()
    end

  and register () =
    let rd_list = read_list() in
    let wr_list = write_list() in
    sys.sys_register ~read:rd_list ~write:wr_list pg.pg_processes callback
  in

  match pg.pg_status with
      Job_ok | Job_error | Job_abandoned ->
	(* Register a do-nothing handler: *)
	sys.sys_register [] (fun _ -> ());
    | _ ->
	register()
;;


let finish_job ?(sys = standard_system_handler()) pg =
  register_job sys pg;
  sys.sys_wait()
;;


let iter_job_instances
      ~f =
  with_current_jobs
    (fun () -> List.iter f !current_jobs)
;;

let kill_process_group
      ?(signal = Sys.sigterm)
      pg =
  if pg.pg_mode = Same_as_caller then
    raise No_Unix_process_group;
  Unix.kill (- pg.pg_id) signal
;;

let kill_processes
      ?(signal = Sys.sigterm)
      pg =
  if pg.pg_status = Job_running || pg.pg_status = Job_partially_running ||
     pg.pg_status = Job_abandoned
  then begin
    List.iter
      (fun p ->
	 try
	   ignore(status p)
	 with
	     Not_found ->
	       (* The process has not yet terminated *)
	       try
		 kill ~signal:signal p
	       with
		   Unix.Unix_error(Unix.ESRCH,_,_) ->
		     (* The process does not exist *)
		     ()
      )
      pg.pg_processes;
  end
;;

let abandon_job ?(signal = Sys.sigterm) pg =

  if pg.pg_status = Job_running || pg.pg_status = Job_partially_running
  then begin

    List.iter
      (fun p -> p.p_abandoned <- true)
      pg.pg_processes;

    pg.pg_status <- Job_abandoned;

    with_current_jobs
      (fun () ->
	 current_jobs := List.filter (fun ji -> ji != pg) !current_jobs;
	 let k = ref 0 in
	 List.iter
	   (fun p ->
	      let n = Array.length !abandoned_job_processes in
	      while !k < n &&
		    !abandoned_job_processes.( !k ).p_status = None
	      do
		incr k
	      done;
	      if !k < n then begin
		!abandoned_job_processes.( !k ) <- p;
		incr k
	      end
	      else begin
		let new_array = Array.create (2*n) dummy_process in
		Array.blit !abandoned_job_processes 0 new_array 0 n;
		new_array.( n ) <- p;
		abandoned_job_processes := new_array
	      end
	   )
	   pg.pg_processes
      );

    begin try
      kill_process_group ~signal:signal pg
    with
	No_Unix_process_group ->
	  kill_processes ~signal:signal pg
      | Unix.Unix_error(Unix.ESRCH,_,_) ->
	  (* No such process *)
	  ()
    end;

    close_job_descriptors pg;

    (* No "wait" for the processes of the abandoned job! If there is a
     * SIGCHLD handler, it will look after the processes moved to
     * abandoned_job_processes.
     *)

    Unix.kill (Unix.getpid()) (Sys.sigchld);
    (* Force a SIGCHLD such that the abandoned processes will be checked
     * in near future.
     *)
  end
;;

let call_job
      ?mode
      ?forward_signals
      ?(onerror = fun ji -> abandon_job ji)
      j =
  let ji = run_job ?mode:mode ?forward_signals:forward_signals j in
  if job_status ji = Job_partially_running then begin
    onerror ji;
    raise ji.pg_exception;
  end;
  finish_job ji;
  ji
;;


let watch_for_zombies () =
  (* This is _relatively_ safe regarding race conditions with
   * the "wait" function (see above) which also modifies the components
   * of process records. However, it is assumed that abandoned processes
   * will no longer be waited for.
   *)
  Array.iter
    (fun p ->
       if p.p_status = None then begin
	 let pid,status = Unix.waitpid [ Unix.WNOHANG ] p.p_id in
	 if pid = p.p_id then
	   p.p_status <- Some status
       end
    )
    !abandoned_job_processes;
  (* Note MT: In this loop, the array ref may change (harmless), and the
   * array cells may be replaced by different ones (but only if
   * p_status <> None), so nothing bad can happen.
   *)
;;


let mutex_reconf = omtp # create_mutex()
  (* For multi-threaded programs: lock/unlock the mutex while reconfiguring *)

let with_reconf f =
  mutex_reconf # lock();
  ( try
      f()
    with
	any ->
	  mutex_reconf # unlock();
	  raise any
  );
  mutex_reconf # unlock()
;;


let handlers_installed   = ref false;;
let want_sigint_handler  = ref true;;
let want_sigquit_handler = ref true;;
let want_sigterm_handler = ref true;;
let want_sighup_handler  = ref true;;
let want_sigchld_handler = ref true;;
let want_at_exit_handler = ref true;;


exception Already_installed;;

let configure_job_handlers
      ?(catch_sigint  = true)
      ?(catch_sigquit = true)
      ?(catch_sigterm = true)
      ?(catch_sighup  = true)
      ?(catch_sigchld = true)
      ?(at_exit       = true)
      () =
  with_reconf
    (fun () ->
       if !handlers_installed then
	 failwith "Shell_sys.configure_job_handlers: The handlers are already installed and can no longer be configured";

       want_sigint_handler  := catch_sigint;
       want_sigquit_handler := catch_sigquit;
       want_sigterm_handler := catch_sigterm;
       want_sighup_handler  := catch_sighup;
       want_sigchld_handler := catch_sigchld;
       want_at_exit_handler := at_exit;
       ()
    )
;;


let install_job_handlers () =
  let install signo h =
    Netsys_signal.register_handler
      ~library:"shell"
      ~name:"Shell_sys forwarding to child processes"
      ~keep_default:(signo <> Sys.sigchld)
      ~signal:signo
      ~callback:h
      ()
  in

  let forward_signal always signo =
    iter_job_instances
      (fun pg ->
	 if always || process_group_expects_signals pg then begin
	   try kill_process_group ~signal:signo pg
	   with
	       No_Unix_process_group ->
		 kill_processes ~signal:signo pg
	     | Unix.Unix_error(Unix.ESRCH,_,_) ->
		 (* No such process *)
		 ()
	 end
      )
  in

  let watch_for_zombies _ =
    watch_for_zombies()
  in

  with_reconf
    (fun () ->
       if !handlers_installed then raise Already_installed;

       (* The first argument of forward_signal is 'false' only for keyboard
	* signals. The other signals should be always forwarded.
	*)
       if !want_sigint_handler  then install Sys.sigint  (forward_signal false);
       if !want_sigquit_handler then install Sys.sigquit (forward_signal false);
       if !want_sigterm_handler then install Sys.sigterm (forward_signal true);
       if !want_sighup_handler  then install Sys.sighup  (forward_signal true);
       if !want_sigchld_handler then install Sys.sigchld watch_for_zombies;

       if !want_at_exit_handler then
	 at_exit (fun () -> forward_signal true Sys.sigterm);

       ()
    )
;;
