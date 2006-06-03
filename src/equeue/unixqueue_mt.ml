(* $Id$
 * ----------------------------------------------------------------------
 *
 *)


let create_lock_unlock_pair() =
  let mutex = Mutex.create() in
  let lock() = Mutex.lock mutex in
  let unlock() = Mutex.unlock mutex in
  (lock, unlock)
;;

Unixqueue.init_mt create_lock_unlock_pair;;