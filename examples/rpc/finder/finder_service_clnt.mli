(************************************************************
 * WARNING!
 *
 * This file is generated by ocamlrpcgen from the source file
 * finder_service.x
 *
 ************************************************************)
module Finder : sig
  module V1 : sig
    open Finder_service_aux
    val create_client :
            ?esys:Unixqueue.event_system ->
            ?program_number:Rtypes.uint4 -> 
            ?version_number:Rtypes.uint4 -> 
            Rpc_client.connector ->
            Rpc.protocol ->
            Rpc_client.t
    val create_portmapped_client :
            ?esys:Unixqueue.event_system ->
            ?program_number:Rtypes.uint4 -> 
            ?version_number:Rtypes.uint4 -> 
            string ->
            Rpc.protocol ->
            Rpc_client.t
    val create_client2 :
            ?esys:Unixqueue.event_system ->
            ?program_number:Rtypes.uint4 -> 
            ?version_number:Rtypes.uint4 -> 
            Rpc_client.mode2 ->
            Rpc_client.t
    val ping : Rpc_client.t -> t_Finder'V1'ping'arg -> t_Finder'V1'ping'res
    val ping'async :
            Rpc_client.t ->
            t_Finder'V1'ping'arg ->
            ((unit -> t_Finder'V1'ping'res) -> unit) ->
            unit
    val find : Rpc_client.t -> t_Finder'V1'find'arg -> t_Finder'V1'find'res
    val find'async :
            Rpc_client.t ->
            t_Finder'V1'find'arg ->
            ((unit -> t_Finder'V1'find'res) -> unit) ->
            unit
    val shutdown :
            Rpc_client.t ->
            t_Finder'V1'shutdown'arg ->
            t_Finder'V1'shutdown'res
    val shutdown'async :
            Rpc_client.t ->
            t_Finder'V1'shutdown'arg ->
            ((unit -> t_Finder'V1'shutdown'res) -> unit) ->
            unit
    
  end
  
end


