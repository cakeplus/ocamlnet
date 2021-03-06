(************************************************************
 * WARNING!
 *
 * This file is generated by ocamlrpcgen from the source file
 * finder_service.x
 *
 ************************************************************)

(* Type definitions *)

type longstring = 
      string
and location_enum = 
      Rtypes.int4
and location = 
      [ | `not_found | `found of (longstring) ]
and t_Finder'V1'ping'arg = 
      unit
and t_Finder'V1'ping'res = 
      unit
and t_Finder'V1'find'arg = 
      longstring
and t_Finder'V1'find'res = 
      location
and t_Finder'V1'lastquery'arg = 
      unit
and t_Finder'V1'lastquery'res = 
      longstring
and t_Finder'V1'shutdown'arg = 
      unit
and t_Finder'V1'shutdown'res = 
      unit
;;

(* Constant definitions *)

val not_found : Rtypes.int4;;
val found : Rtypes.int4;;

(* Conversion functions *)

val _to_longstring : Xdr.xdr_value -> longstring;;
val _of_longstring : longstring -> Xdr.xdr_value;;
val _to_location_enum : Xdr.xdr_value -> location_enum;;
val _of_location_enum : location_enum -> Xdr.xdr_value;;
val _to_location : Xdr.xdr_value -> location;;
val _of_location : location -> Xdr.xdr_value;;
val _to_Finder'V1'ping'arg : Xdr.xdr_value -> t_Finder'V1'ping'arg;;
val _of_Finder'V1'ping'arg : t_Finder'V1'ping'arg -> Xdr.xdr_value;;
val _to_Finder'V1'ping'res : Xdr.xdr_value -> t_Finder'V1'ping'res;;
val _of_Finder'V1'ping'res : t_Finder'V1'ping'res -> Xdr.xdr_value;;
val _to_Finder'V1'find'arg : Xdr.xdr_value -> t_Finder'V1'find'arg;;
val _of_Finder'V1'find'arg : t_Finder'V1'find'arg -> Xdr.xdr_value;;
val _to_Finder'V1'find'res : Xdr.xdr_value -> t_Finder'V1'find'res;;
val _of_Finder'V1'find'res : t_Finder'V1'find'res -> Xdr.xdr_value;;
val _to_Finder'V1'lastquery'arg : Xdr.xdr_value -> t_Finder'V1'lastquery'arg;;
val _of_Finder'V1'lastquery'arg : t_Finder'V1'lastquery'arg -> Xdr.xdr_value;;
val _to_Finder'V1'lastquery'res : Xdr.xdr_value -> t_Finder'V1'lastquery'res;;
val _of_Finder'V1'lastquery'res : t_Finder'V1'lastquery'res -> Xdr.xdr_value;;
val _to_Finder'V1'shutdown'arg : Xdr.xdr_value -> t_Finder'V1'shutdown'arg;;
val _of_Finder'V1'shutdown'arg : t_Finder'V1'shutdown'arg -> Xdr.xdr_value;;
val _to_Finder'V1'shutdown'res : Xdr.xdr_value -> t_Finder'V1'shutdown'res;;
val _of_Finder'V1'shutdown'res : t_Finder'V1'shutdown'res -> Xdr.xdr_value;;

(* XDR definitions *)

val xdrt_longstring : Xdr.xdr_type_term;;
val xdrt_location_enum : Xdr.xdr_type_term;;
val xdrt_location : Xdr.xdr_type_term;;
val xdrt_Finder'V1'ping'arg : Xdr.xdr_type_term;;
val xdrt_Finder'V1'ping'res : Xdr.xdr_type_term;;
val xdrt_Finder'V1'find'arg : Xdr.xdr_type_term;;
val xdrt_Finder'V1'find'res : Xdr.xdr_type_term;;
val xdrt_Finder'V1'lastquery'arg : Xdr.xdr_type_term;;
val xdrt_Finder'V1'lastquery'res : Xdr.xdr_type_term;;
val xdrt_Finder'V1'shutdown'arg : Xdr.xdr_type_term;;
val xdrt_Finder'V1'shutdown'res : Xdr.xdr_type_term;;

(* Program definitions *)

val program_Finder'V1 : Rpc_program.t;;

