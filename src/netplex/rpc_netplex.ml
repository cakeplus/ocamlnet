(* $Id$ *)

let rpc_factory 
      ~configure
      ?(socket_config = fun _ -> Rpc_server.default_socket_config)
      ?(hooks = fun _ -> new Netplex_kit.empty_processor_hooks())
      ?(supported_ptypes = [ `Multi_processing; `Multi_threading ])
      ~name
      ~setup
      () =

  let pmap_register sockserv progs_and_versions port =
    List.iter
      (fun (_, fds) ->
	 Array.iter
	   (fun fd ->
	      match Unix.getsockname fd with
		| Unix.ADDR_INET(_,p) ->
		    ( match !port with
			| None -> port := Some p;
			| Some p' ->
			    if p <> p' then
			      failwith ("Cannot register RPC service in the portmapper when it listens to several ports")
		    )
		| _ -> ()
	   )
	   fds
      )
      sockserv#sockets;
    match !port with
      | None -> ()
      | Some p ->
	  let pmap = Rpc_portmapper.create_inet "localhost" in
	  List.iter
	    (fun (prog_nr, vers_nr) ->
	       ( match Rpc_portmapper.getport pmap prog_nr vers_nr Rpc.Tcp with
		   | 0 -> ()
		   | p' ->
		       let _ =
			 Rpc_portmapper.unset pmap prog_nr vers_nr Rpc.Tcp p' in
		       ()
	       );
	       ignore(Rpc_portmapper.set pmap prog_nr vers_nr Rpc.Tcp p)
	    )
	    progs_and_versions;
	  Rpc_portmapper.shut_down pmap
  in

  let pmap_unregister sockserv progs_and_versions port =
    match !port with
      | None -> ()
      | Some p ->
	  let pmap = Rpc_portmapper.create_inet "localhost" in
	  List.iter
	    (fun (prog_nr, vers_nr) ->
	       ignore(Rpc_portmapper.unset pmap prog_nr vers_nr Rpc.Tcp p);
	    )
	    progs_and_versions;
	  Rpc_portmapper.shut_down pmap;
  in

  ( object(self)
      method name = name
      method create_processor ctrl_cfg cf addr =
	let use_portmapper =
	  try
	    cf # bool_param (cf # resolve_parameter addr "portmapper") 
	  with Not_found -> false in
	let custom_cfg = configure cf addr in
	let sconf = socket_config custom_cfg in

	(* Find out the bindings by creating a fake server: *)
	let progs_and_versions =
	  let esys = Unixqueue.create_unix_event_system () in
	  let (fd0, fd1) = Unix.socketpair Unix.PF_UNIX Unix.SOCK_STREAM 0 in
	  Unix.close fd1;
	  let srv = Rpc_server.create2 (`Socket_endpoint(Rpc.Tcp,fd0)) esys in
	  setup srv custom_cfg;
	  Unix.close fd0;
	  let progs = Rpc_server.bound_programs srv in
	  List.map
	    (fun prog ->
	       (Rpc_program.program_number prog,
		Rpc_program.version_number prog)
	    )
	    progs
	in

	let port = ref None in
	let srv_list = ref [] in

	( object(self)
	    inherit Netplex_kit.processor_base (hooks custom_cfg) as super

	    method post_add_hook sockserv =
	      if use_portmapper then 
		pmap_register sockserv progs_and_versions port;
	      super # post_add_hook sockserv

	    method post_rm_hook sockserv =
	      if use_portmapper then 
		pmap_unregister sockserv progs_and_versions port;
	      super # post_add_hook sockserv

	    method shutdown () =
	      List.iter
		(fun srv ->
		   Rpc_server.stop_server 
		     ~graceful:true
		     srv)
		!srv_list;
	      srv_list := [];
	      super # shutdown()
		

	    method process ~when_done container fd proto =
	      let esys = container # event_system in
	      let mplex_eng = sconf # multiplexing 
		~close_inactive_descr:true Rpc.Tcp fd esys in
	      Uq_engines.when_state
		~is_done:(fun mplex ->
			    let srv = 
			      Rpc_server.create2 
				(`Multiplexer_endpoint mplex) esys in
			    srv_list := srv :: !srv_list;
			    Rpc_server.set_exception_handler srv
			      (fun err ->
				 container # log
				   `Crit
				   ("RPC server caught exception: " ^ 
				      Printexc.to_string err));
			    Rpc_server.set_onclose_action 
			      srv (fun _ ->
				     srv_list :=
				       List.filter
					 (fun srv' -> srv' != srv)
					 !srv_list;
				     let g = Unixqueue.new_group esys in
				     Unixqueue.once esys g 0.0 when_done);
			    setup srv custom_cfg)
		~is_error:(fun err ->
			     container # log `Crit 
			       ("Cannot create RPC multiplexer: " ^ 
				  Printexc.to_string err)
			  )
		mplex_eng

	    method supported_ptypes = 
	      supported_ptypes

	  end
	)
    end
  )
;;
