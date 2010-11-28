(* $Id$ *)

(** Unified engines for stream I/O *)

type in_buffer
type out_buffer
  (** Buffers that can be attached to a [device] to get buffered I/O *)

type in_device =
    [ `Polldescr of Netsys.fd_style * Unix.file_descr * Unixqueue.event_system
    | `Multiplex of Uq_engines.multiplex_controller
    | `Async_in of Uq_engines.async_in_channel * Unixqueue.event_system
    | `Buffer_in of in_buffer
    ]
  (** Currently supported devices for input:
       - [`Polldescr(st,fd,esys)]: The [poll] system call is used with file
         descriptor [fd] to wait for incoming data. The
         event system [esys] is the underlying event queue. This works
         well for pipes, sockets etc. but not for normal files. The
         style [st] can be obtained from [fd] via
         {!Netsys.get_fd_style}.
       - [`Multiplex mplex]: The multiplex controller [mplex] is
         used as device. 
       - [`Buffer buf]: Data comes from the buffer [buf] (which in turn
         is connected with a second device)
   *)

type out_device =
    [ `Polldescr of Netsys.fd_style * Unix.file_descr * Unixqueue.event_system
    | `Multiplex of Uq_engines.multiplex_controller
    | `Async_out of Uq_engines.async_out_channel * Unixqueue.event_system
    | `Buffer_out of out_buffer
    ]
  (** Currently supported devices for output:
       - [`Polldescr(fd,esys)]: The [poll] system call is used with file
         descriptor [fd] to wait until data can be output. The
         event system [esys] is the underlying event queue. This works
         well for pipes, sockets etc. but not for normal files.
       - [`Multiplex mplex]: The multiplex controller [mplex] is
         used as device. 
       - [`Buffer buf]: Data is written to the buffer [buf] (which in turn
         is connected with a second device)
   *)

type in_bdevice =
    [ `Buffer_in of in_buffer ]
  (** Devices with look-ahead *)

type string_like =
    [ `String of string
    | `Memory of Netsys_mem.memory
    ]
  (** The user can pass data buffers that base either on strings or on
      bigarrays of char (memory). Note that [`Memory] is not supported
      for all devices or device configurations.
   *)

val device_supports_memory : [ in_device | out_device ] -> bool
  (** Returns whether [`Memory] buffers are supported *)

(** {2 Input} *)

val input_e : [< in_device ] -> string_like -> int -> int -> 
                int Uq_engines.engine
 (** [let e = input_e d s pos len]: Reads data from [d] and puts it into
     the string [s] starting at [pos] and with maximum length [len].
     When data is available, the engine [e] transitions to [`Done n]
     where [n] is the number of actually read bytes.

     If [len>0] and no bytes can be read because the end is reached, the engine
     transitions to [`Error End_of_file].
  *)

val really_input_e : [< in_device ] -> string_like -> int -> int ->
                        unit Uq_engines.engine
 (** [let e = input_e d s pos len]: Reads data from [d] and puts it into
     the string [s] starting at [pos] and with length [len].
     Exactly [len] bytes are read, and when done, 
     the engine [e] transitions to [`Done ()].

     If the end of the file is reached before [len] bytes are read,
     the engine transitions to [`Error End_of_file].
  *)

val input_line_e : in_bdevice -> string Uq_engines.engine
  (** [let e = input_line_e d]: Reads the next line from [d] and transitions
      to [`Done line] when done. Note that this is only supported for a
      buffered device!

      If the end of the file is already reached when this function is 
      called, the engine transitions to [`Error End_of_file].
   *)

(** {2 Output} *)

val output_e : [< out_device ] -> string_like -> int -> int ->
                 int Uq_engines.engine
  (** [let e = output_e d s pos len]: Outputs data to [d] and takes it
      from the string [s] starting at [pos] and with maximum length
      [len]. When data is written, the engine [e] transitions to [`Done n]
      where [n] is the number of actually written bytes.
  *)

val really_output_e : [< out_device ] -> string_like -> int -> int ->
                        unit Uq_engines.engine
  (** [let e = really_output_e d s pos len]: Outputs data to [d] and takes it
      from the string [s] starting at [pos] and with length
      [len]. When all data is written, the engine [e] transitions to
      [`Done ()].
  *)

val output_string_e : [< out_device ] -> string -> unit Uq_engines.engine
  (** [let e = output_string_e d s]: Outputs the string [s] to [d],
      and transitions to [`Done()] when done.
   *)

val output_memory_e : [< out_device ] -> Netsys_mem.memory -> 
                         unit Uq_engines.engine
  (** [let e = output_string_e d m]: Outputs the bigarray [m] to [d],
      and transitions to [`Done()] when done.
   *)

val output_netbuffer_e : [< out_device ] -> Netbuffer.t -> 
                            unit Uq_engines.engine
  (** [let e = output_string_e d b]: Outputs the contents of [b] to [d],
      and transitions to [`Done()] when done.
   *)

val write_eof_e : [< out_device ] -> bool Uq_engines.engine
  (** [let e = write_eof_e d]: For devices supporting half-open connections,
      this engine writes the EOF marker and transitions to 
      [`Done true]. For other devices nothing happens, and the engine
      transitions to [`Done false]. (The only way to signal EOF is
      to shut down the device, see below.)

      Note that the effect of [write_eof_e] cannot be buffered. Because
      of this, the [io_buffer] flushes all data first (i.e. [write_eof_e]
      implies the effect of [flush_e]).
   *)

val copy_e : ?len:int -> [< in_device ] -> [< out_device ] -> 
                int64 Uq_engines.engine
  (** [let e = copy_e d_in d_out]: Copies data from [d_in] to [d_out],
      and transitions to [`Done n] when all data is copied (where
      [n] are the number of copied bytes).
      By default, [d_in] is read until end of file. If [len] is passed,
      at most this number of bytes are copied.
   *)

val flush_e : [< out_device ] -> unit Uq_engines.engine
  (** [let e = flush_e d]: If [d] has an internal buffer, all data is
      written out to [d]. If there is no such buffer, this is a no-op.
      When done, the engine transitions to [`Done()].
   *)


(** {2 Shutdown} *)

(** The shutdown is the last part of the protocol. Although it is
    often done autonomously by the kernel, this interface supports
    user-implemented shutdowns (e.g. for SSL).

    The shutdown can be skipped, and the device can be inactivated
    immediately. For some devices, the other side of the I/O stream
    will then see an error, though.

    The shutdown is always for both the input and the output circuit
    of the device.
 *)

val shutdown_e : ?linger:float -> [< in_device | out_device ] -> 
                    unit Uq_engines.engine
  (** Performs a regular shutdown of the device. The [linger] argument
      may be used to configure a non-default linger timeout.
      The engine transitions to [`Done()] when done.

      The shutdown also releases the OS resources (closes the descriptor
      etc.), but only if successful.

      Note that the effect of [shutdown_e] cannot be buffered. Because
      of this, the [io_buffer] flushes all data first (i.e. [shutdown_e]
      implies the effect of [flush_e]). Input data available in the 
      buffer can still be read after the shutdown.
      
   *)

val inactivate : [< in_device | out_device ] -> unit
  (** Releases the OS resources immediately. This is the right thing to do
      when aborting the communication, or for cleanup after an I/O error.
      It is wrong to inactivate after a successful shutdown, because the
      shutdown already includes the inactivation.
   *)

(** {2 Buffers} *)

val create_in_buffer : [< in_device ] -> in_buffer
  (** Provides a buffered version of the [in_device] *)

val in_buffer_length : in_buffer -> int
  (** The length *)

val in_buffer_blit : in_buffer -> int -> string_like -> int -> int -> unit
  (** Blit to a string or memory buffer *)

val in_buffer_fill_e : in_buffer -> bool Uq_engines.engine
  (** Requests that the buffer is filled more than currently, and
      transitions to [`Done eof] when there is more data, or the
      EOF is reached (eof=true). 
   *)

val create_out_buffer : max:int option -> [< out_device ] -> out_buffer
  (** Provides a buffered version of the [out_device]. The argument
      [max] is the maximum number of bytes to buffer. This can also be
      set to [None] meaning no limit.
   *)