/* $Id$
 * ----------------------------------------------------------------------
 */

#include "netsys_c.h"

#ifdef HAVE_POSIX_SHM
#include <sys/types.h>
#include <sys/mman.h>
#endif

#ifdef HAVE_POSIX_FADVISE
#include <sys/types.h>
#include <sys/fcntl.h>
#endif

#ifdef HAVE_POLL
#include <sys/poll.h>
#endif

#ifdef HAVE_PTHREAD
#include <pthread.h>
#endif

#ifdef HAVE_MMAP
#include <sys/types.h>
#include <sys/mman.h>
#if !defined(MAP_ANON) && defined(MAP_ANONYMOUS)
#define MAP_ANON MAP_ANONYMOUS
#endif
#endif


CAMLprim value netsys_int64_of_file_descr(value fd) {
#ifdef _WIN32
    switch (Descr_kind_val(fd)) {
    case KIND_HANDLE:
	return copy_int64((long) (Handle_val(fd)));
    case KIND_SOCKET:
	return copy_int64((long) (Socket_val(fd)));
    }
    return copy_int64(0);
#else
    return copy_int64(Long_val(fd));
#endif
}

/**********************************************************************/
/* OS recognition                                                     */
/**********************************************************************/

CAMLprim value netsys_is_darwin(value dummy) {
#if defined(__darwin__) || defined(__DARWIN__) || defined(__APPLE__)
    return Val_bool(1);
#else
    return Val_bool(0);
#endif
}

/**********************************************************************/
/* Standard POSIX stuff                                               */
/**********************************************************************/

CAMLprim value netsys_unix_error_of_code(value n) {
    int e;
    e = Int_val(n);
#ifdef _WIN32
    win32_maperr(e);
    e = errno;
#endif
    return(unix_error_of_code(e));
}


CAMLprim value netsys__exit (value n) {
#ifdef HAVE__EXIT
    _exit(Int_val(n));
    return Val_int(0);
#else
    invalid_argument("Netsys._exit not available");
#endif
}


CAMLprim value netsys_sysconf_open_max (value unit) {
#ifdef HAVE_SYSCONF
    return Val_long(sysconf(_SC_OPEN_MAX));
#else
    invalid_argument("Netsys.sysconf_open_max not available");
#endif
}


CAMLprim value netsys_getpgid (value pid) {
#ifdef HAVE_POSIX_PROCESS_GROUPS
    int pgid;

    pgid = getpgid(Int_val(pid));
    if (pgid == -1) uerror("getpgid", Nothing);
    return Val_int(pgid);
#else
    invalid_argument("Netsys.getpgid not available");
#endif
}


CAMLprim value netsys_setpgid (value pid, value pgid) {
#ifdef HAVE_POSIX_PROCESS_GROUPS
    int r;

    r = setpgid(Int_val(pid), Int_val(pgid));
    if (r == -1) uerror("setpgid", Nothing);
    return Val_int(0);
#else
    invalid_argument("Netsys.setpgid not available");
#endif
}


CAMLprim value netsys_tcgetpgrp (value fd) {
#ifdef HAVE_POSIX_TTY
    int pgid;

    pgid = tcgetpgrp(Int_val(fd));
    if (pgid == -1) uerror("tcgetpgrp", Nothing);
    return Val_int(pgid);
#else
    invalid_argument("Netsys.tcgetpgrp not available");
#endif
}


CAMLprim value netsys_tcsetpgrp (value fd, value pgid) {
#ifdef HAVE_POSIX_TTY
    int r;
    
    r = tcsetpgrp(Int_val(fd), Int_val(pgid));
    if (r == -1) uerror("tcsetpgrp", Nothing);
    return Val_int(0);
#else
    invalid_argument("Netsys.tcsetpgrp not available");
#endif
}


CAMLprim value netsys_ctermid (value unit) {
#ifdef HAVE_POSIX_TTY
    char *s;
    s = NULL;
    return copy_string(ctermid(s));
    /* ctermid is always successful; however it can return an empty string */
#else
    invalid_argument("Netsys.ctermid not available");
#endif
}


CAMLprim value netsys_ttyname (value fd) {
#ifdef HAVE_POSIX_TTY
    char *s;

    s = ttyname(Int_val(fd));
    if ( s == NULL ) uerror("ttyname", Nothing);
    return copy_string(s);
#else
    invalid_argument("Netsys.ttyname not available");
#endif
}


CAMLprim value netsys_getsid (value pid) {
#ifdef HAVE_POSIX_PROCESS_SESSIONS
    int sid;

    sid = getsid(Int_val(pid));
    if ( sid == -1 )  uerror("getsid", Nothing);
    return Val_int(sid);
#else
    invalid_argument("Netsys.getsid not available");
#endif
}


CAMLprim value netsys_setreuid(value ruid, value euid) {
#ifdef HAVE_POSIX_UID
    int r;

    r = setreuid(Int_val(ruid), Int_val(euid));
    if (r == -1) uerror("setreuid", Nothing);
    return Val_int(0);
#else
    invalid_argument("Netsys.setreuid not available");
#endif
}


CAMLprim value netsys_setregid(value rgid, value egid) {
#ifdef HAVE_POSIX_UID
    int r;

    r = setregid(Int_val(rgid), Int_val(egid));
    if (r == -1) uerror("setregid", Nothing);
    return Val_int(0);
#else
    invalid_argument("Netsys.setregid not available");
#endif
}


CAMLprim value netsys_fsync(value fd) {
#ifdef HAVE_FSYNC
    int r;
    r = fsync(Int_val(fd));
    if (r == -1) 
	uerror("fsync", Nothing);
    return Val_unit;
#else
    invalid_argument("Netsys.fsync not available");
#endif
}


CAMLprim value netsys_fdatasync(value fd) {
#ifdef HAVE_FDATASYNC
    int r;
    r = fdatasync(Int_val(fd));
    if (r == -1) 
	uerror("fdatasync", Nothing);
    return Val_unit;
#else
    invalid_argument("Netsys.fdatasync not available");
#endif
}

/**********************************************************************/
/* poll interface                                                     */
/**********************************************************************/

CAMLprim value netsys_pollfd_size (value dummy) {
#ifdef HAVE_POLL
    return Val_int(sizeof(struct pollfd));
#else
    return Val_int(0);
#endif
}


#ifdef HAVE_POLL
static struct custom_operations poll_mem_ops = {
    "",
    custom_finalize_default,
    custom_compare_default,
    custom_hash_default,
    custom_serialize_default,
    custom_deserialize_default
};

#define Poll_mem_val(v) ((struct pollfd **) (Data_custom_val(v)))

static value alloc_poll_mem(int n) {
    struct pollfd *p;
    value r;
    p = caml_stat_alloc(n * sizeof(struct pollfd));
    r = caml_alloc_custom(&poll_mem_ops, sizeof(p), n, 100000);
    *(Poll_mem_val(r)) = p;
    return r;
};
#endif


CAMLprim value netsys_mk_poll_mem(value n) {
#ifdef HAVE_POLL
    value s;
    struct pollfd p;
    int k;
    p.fd = 0;
    p.events = 0;
    p.revents = 0;
    s = alloc_poll_mem(n);
    for (k=0; k<n; k++) {
	(*(Poll_mem_val(s)))[k] = p;
    };
    return s;
#else
    invalid_argument("netsys_mk_poll_mem");
#endif
}


CAMLprim value netsys_set_poll_mem(value s, value k, value fd, value ev, value rev) {
#ifdef HAVE_POLL
    struct pollfd p;
    p.fd = Int_val(fd);
    p.events = Int_val(ev);
    p.revents = Int_val(rev);
    (*(Poll_mem_val(s)))[Int_val(k)] = p;
    return Val_unit;
#else
    invalid_argument("netsys_set_poll_mem");
#endif

}


CAMLprim value netsys_get_poll_mem(value s, value k) {
#ifdef HAVE_POLL
    struct pollfd p;
    value triple;
    p = (*(Poll_mem_val(s)))[Int_val(k)];
    triple = caml_alloc_tuple(3);
    Store_field(triple, 0, Val_int(p.fd));
    Store_field(triple, 1, Val_int(p.events));
    Store_field(triple, 2, Val_int(p.revents));
    return triple;
#else
    invalid_argument("netsys_get_poll_mem");
#endif
}


CAMLprim value netsys_blit_poll_mem(value s1, value k1, value s2, value k2, value l) {
#ifdef HAVE_POLL
    struct pollfd *p1;
    struct pollfd *p2;
    p1 = *(Poll_mem_val(s1));
    p2 = *(Poll_mem_val(s2));
    memmove(p2 + Int_val(k2), p1 + Int_val(k1), l*sizeof(struct pollfd));
    return Val_unit;
#else
    invalid_argument("netsys_blit_poll_mem");
#endif
};


CAMLprim value netsys_poll_constants(value dummy) {
    value r;
    r = caml_alloc_tuple(6);
    Store_field(r, 0, Val_int(CONST_POLLIN));
    Store_field(r, 1, Val_int(CONST_POLLPRI));
    Store_field(r, 2, Val_int(CONST_POLLOUT));
    Store_field(r, 3, Val_int(CONST_POLLERR));
    Store_field(r, 4, Val_int(CONST_POLLHUP));
    Store_field(r, 5, Val_int(CONST_POLLNVAL));
    return r;
}


CAMLprim value netsys_poll(value s, value nv, value tv) {
#ifdef HAVE_POLL
    struct pollfd *p;
    int n;
    long tmo, r;

    p = (*(Poll_mem_val(s)));
    n = Int_val(nv);
    tmo = Long_val(tv);
    
    enter_blocking_section();
    r = poll(p, n, tmo);
    leave_blocking_section();

    if (r == -1) uerror("poll", Nothing);
    
    return Val_int(r);
#else
     invalid_argument("netsys_poll");
#endif
}

/**********************************************************************/
/* spawn                                                              */
/**********************************************************************/

static void empty_signal_handler(int sig) {}

typedef union {
    char buffer[256];
    struct {
	int   b_errno;
	char  b_function[64];
    } decoded;
} marshalled_error;


#define MAIN_ERROR(e,f) { uerror_errno = e; uerror_function = f; goto main_exit; }
#define SUB_ERROR(e,f) { uerror_errno = e; uerror_function = f; goto sub_error; }



/* Note: In the following function we can assume that we are not on Win32.
   Hence, file descriptors are simply ints.
*/

CAMLprim value netsys_spawn_nat(value v_chdir,
				value v_pg,
				value v_fd_actions,
				value v_sig_actions,
				value v_env,
				value v_cmd,
				value v_args) {
#ifdef HAVE_FORK_EXEC
    int   uerror_errno;
    char *uerror_function;
    value return_value;

    int code;
    sigset_t mask;
    sigset_t save_mask;
    int   cleanup_mask;

    int ctrl_pipe[2];
    int cleanup_pipe0;
    int cleanup_pipe1;

    int cleanup_bsection;

    pid_t pid;
    char **sub_argv;
    char **sub_env;
    int cleanup_sub_argv;
    int cleanup_sub_env;;

    marshalled_error me;
    ssize_t n;

    char *ttyname;
    int   ttyfd;

    struct sigaction sigact;
    int signr;

    value v_sig_actions_l;
    value v_sig_actions_hd;

    value v_fd_actions_l;
    value v_fd_actions_hd;
    value v_fd_actions_0;

    int j, k, l;
    int fd1, fd2, fd1_flags;

    uerror_errno = 0;
    cleanup_mask = 0;
    cleanup_pipe0 = 0;
    cleanup_pipe1 = 0;
    cleanup_bsection = 0;
    cleanup_sub_argv = 0;
    cleanup_sub_env = 0;

    sub_argv = NULL;
    sub_env = NULL;
    return_value = Val_int(0);
    uerror_function = "<uninit>";

    /* First thing is that we have to block all signals. In a multi-threaded
       program this is only done for the thread calling us, otherwise for the
       whole process. [fork] will reset all pending signals, so we can be
       sure the subprocess won't get any signals until we perform the
       signal actions in the subprocess.

       In the calling process, the mask is reset below at [exit].
    */
    code = sigfillset(&mask);
    if (code == -1) unix_error(EINVAL, "netsys_spawn/sigfillset [000]", 
			       Nothing);
#ifdef HAVE_PTHREAD
    code = pthread_sigmask(SIG_SETMASK, &mask, &save_mask);
    if (code != 0) unix_error(code, "netsys_spawn/pthread_sigmask [001]", 
			      Nothing);
#else
#ifdef HAVE_POSIX_SIGNALS
    code = sigprocmask(SIG_SETMASK, &mask, &save_mask);
    if (code == -1) uerror("netsys_spawn/sigprocmask [002]", Nothing);
#endif
#endif

    /* From now on, we don't jump out with uerror, but leave via "exit" 
       below.
    */
    cleanup_mask = 1;

    /* Create the control pipe for reporting errors. */
    code = pipe(ctrl_pipe);
    if (code == -1) MAIN_ERROR(errno, "netsys_spawn/pipe [010]");
    cleanup_pipe0 = 1;
    cleanup_pipe1 = 1;

    /* Prepare sub_argv and sub_env: */
    sub_argv = malloc((Wosize_val(v_args) + 1) * sizeof(char *));
    if (sub_argv == NULL) MAIN_ERROR(ENOMEM, "netsys_spawn/malloc [020]");
    for (k = 0; k < Wosize_val(v_args); k++) {
	sub_argv[k] = String_val(Field(v_args, k));
    }
    sub_argv[ Wosize_val(v_args)] = NULL;
    cleanup_sub_argv = 1;

    sub_env = malloc((Wosize_val(v_env) + 1) * sizeof(char *));
    if (sub_env == NULL) MAIN_ERROR(ENOMEM, "netsys_spawn/malloc [021]");
    for (k = 0; k < Wosize_val(v_env); k++) {
	sub_env[k] = String_val(Field(v_env, k));
    }
    sub_env[ Wosize_val(v_env)] = NULL;
    cleanup_sub_env = 1;

    /* Because fork() can be slow we allow here that other threads can run */
    /* caml_enter_blocking_section();
       cleanup_bsection = 1;
       -- TODO: check this more carefully before enabling it
    */

    /* Fork the process. */
    pid = fork();
    if (pid == (pid_t) -1) 
	MAIN_ERROR(errno, "netsys_spawn/fork [031]");
    if (pid != (pid_t) 0)
	goto main_process;

/*sub_process:*/
    /* The start of the sub process. */
    pid = getpid();

    /* Close the read side of the control pipe. Set the close-on-exec flag
       for the write side.
     */
    code = close(ctrl_pipe[0]);
    if (code == -1) SUB_ERROR(errno, "netsys_spawn/close [100]");
    code = fcntl(ctrl_pipe[1], F_SETFD, FD_CLOEXEC);
    if (code == -1) SUB_ERROR(errno, "netsys_spawn/fcntl [101]");

    /* If required, change the working directory */
    if (Is_block(v_chdir)) {
	switch(Tag_val(v_chdir)) {
	case 0:  /* Wd_chdir */
	    code = chdir(String_val(Field(v_chdir, 0)));
	    if (code == -1) SUB_ERROR(errno, "netsys_spawn/chdir [110]");
	    break;

	case 1:  /* Wd_fchdir */
	    code = fchdir(Int_val(Field(v_chdir, 1)));
	    if (code == -1) SUB_ERROR(errno, "netsys_spawn/fchdir [111]");
	    break;

	default:
	    SUB_ERROR(EINVAL, "netsys_spawn/assert_chdir [112]");
	}
    }

    /* If required, create/join the process group */
    if (Is_block(v_pg)) {
	/* Must be Pg_join_group */
#ifdef HAVE_POSIX_PROCESS_GROUPS
	code = setpgid(0, Int_val(Field(v_pg, 0)));
	if (code == -1) SUB_ERROR(errno, "netsys_spawn/setpgid [120]");
#endif	
    }
    else {
	switch (Int_val(v_pg)) {
	case 0: /* Pg_keep */
	    break;
	case 1: /* Pg_new_bg_group */
#ifdef HAVE_POSIX_PROCESS_GROUPS
	    code = setpgid(0, 0);
	    if (code == -1) SUB_ERROR(errno, "netsys_spawn/setpgid [130]");
#endif	
	    break;
	case 2: /* Pg_new_fg_group */
#ifdef HAVE_POSIX_TTY
	    code = setpgid(0, 0);
	    if (code == -1) SUB_ERROR(errno, "netsys_spawn/setpgid [140]");
	    ttyname = ctermid(NULL);   /* no error code defined! */
	    ttyfd = open(ttyname, O_RDWR);
	    if (ttyfd == -1) SUB_ERROR(errno, "netsys_spawn/open [141]");
	    /* tcsetpgrp may send a SIGTTOU signal to this process. We want
               to hide this signal, so we set this signal to be ignored.
               We do this by setting an empty signal handler. On exec,
               the SIGTTOU signal will be reset to the default action in
               this case - which is ok because the set of pending signals
               is also cleared.
	    */
	    sigact.sa_sigaction = NULL;
	    sigact.sa_handler = &empty_signal_handler;
	    sigact.sa_flags = 0;
	    code = sigemptyset(&(sigact.sa_mask));
	    if (code == -1) SUB_ERROR(EINVAL, "netsys_spawn/sigemptyset [142]");
	    code = sigaction(SIGTTOU, &sigact, NULL);
	    if (code == -1) SUB_ERROR(errno, "netsys_spawn/sigaction [143]");
	    code = tcsetpgrp(ttyfd, pid);
	    if (code == -1) SUB_ERROR(errno, "netsys_spawn/tcsetpgrp [144]");
	    code = close(ttyfd);
	    if (code == -1) SUB_ERROR(errno, "netsys_spawn/close [145]");
#endif
	    break;
	default:
	    SUB_ERROR(EINVAL, "netsys_spawn/assert_pg [160]");
	}
    }

    /* do the signal stuff: */
#ifdef HAVE_POSIX_SIGNALS
    v_sig_actions_l = v_sig_actions;
    while (Is_block(v_sig_actions_l)) {
	v_sig_actions_hd = Field(v_sig_actions_l, 0);
	v_sig_actions_l  = Field(v_sig_actions_l, 1);
	switch(Tag_val(v_sig_actions_hd)) {
	case 0:  /* Sig_default */
	    signr = caml_convert_signal_number
	  	       (Int_val(Field(v_sig_actions_hd,0)));
	    sigact.sa_sigaction = NULL;
	    sigact.sa_handler = SIG_DFL;
	    sigact.sa_flags = 0;
	    code = sigemptyset(&(sigact.sa_mask));
	    if (code == -1) SUB_ERROR(EINVAL, "netsys_spawn/sigemptyset [170]");
	    code = sigaction(signr, &sigact, NULL);
	    if (code == -1) SUB_ERROR(errno, "netsys_spawn/sigaction [171]");
	    break;
	case 1: /* Sig_ignore */
	    signr = caml_convert_signal_number
	  	       (Int_val(Field(v_sig_actions_hd,0)));
	    sigact.sa_sigaction = NULL;
	    sigact.sa_handler = SIG_IGN;
	    sigact.sa_flags = 0;
	    code = sigemptyset(&(sigact.sa_mask));
	    if (code == -1) SUB_ERROR(EINVAL, "netsys_spawn/sigemptyset [180]");
	    code = sigaction(signr, &sigact, NULL);
	    if (code == -1) SUB_ERROR(errno, "netsys_spawn/sigaction [181]");
	    break;
	default:
	    SUB_ERROR(EINVAL, "netsys_spawn/assert_sig [190]");
	}
    };
#endif

    /* do the fd stuff: */
    v_fd_actions_l = v_fd_actions;
    while (Is_block(v_fd_actions_l)) {
	v_fd_actions_hd = Field(v_fd_actions_l, 0);
	v_fd_actions_l  = Field(v_fd_actions_l, 1);
	switch(Tag_val(v_fd_actions_hd)) {
	case 0: /* Fda_close */
	    fd1 = Int_val(Field(v_fd_actions_hd, 0));
	    if (fd1 == ctrl_pipe[1]) 
		SUB_ERROR(EBADF, "netsys_spawn/fda_close [200]");
	    code = close(fd1);
	    if (code == -1) SUB_ERROR(errno, "netsys_spawn/close [201]");
	    break;
	case 1: /* Fda_close_ignore */
	    fd1 = Int_val(Field(v_fd_actions_hd, 0));
	    if (fd1 != ctrl_pipe[1]) {
		code = close(fd1);
		if (code == -1 && errno != EBADF)
		    SUB_ERROR(errno, "netsys_spawn/close [210]");
	    }  
	    /* ignore requests to close the ctrl_pipe, it's closed
	       anyway later 
	    */
	    break;
	case 2:  /* Fda_close_except */
	    v_fd_actions_0 = Field(v_fd_actions_hd, 0);
	    j = Wosize_val(v_fd_actions_0);   /* array length */
	    l = sysconf(_SC_OPEN_MAX);
	    for (k=0; k<l; k++) {
		if (k>=j || !Bool_val(Field(v_fd_actions_0,k))) {
		    if (k != ctrl_pipe[1])
			close(k);   /* ignore any error */
		}
	    }
	    break;
	case 3: /* Fda_dup2 */
	    fd1 = Int_val(Field(v_fd_actions_hd, 0));
	    fd2 = Int_val(Field(v_fd_actions_hd, 1));
	    /* If fd1 is the ctrl_pipe, return EBADF: */
	    if (fd1 == ctrl_pipe[1]) 
		SUB_ERROR(EBADF, "netsys_spawn/fda_dup2 [220]");
	    /* Check that fd1 is valid by reading the fd flags: */
	    code = fcntl(fd1, F_GETFD);
	    if (code == -1) SUB_ERROR(errno, "netsys_spawn/fcntl [221]");
	    fd1_flags = code;
	    /* Be careful when fd2 is the ctrl_pipe: */
	    if (fd2 == ctrl_pipe[1]) {
		code = dup(ctrl_pipe[1]);
		if (code == -1) SUB_ERROR(errno, "netsys_spawn/dup [222]");
		ctrl_pipe[1] = code;
		code = fcntl(ctrl_pipe[1], F_SETFD, FD_CLOEXEC);
		if (code == -1) SUB_ERROR(errno, "netsys_spawn/fcntl [223]");
	    }
	    code = dup2(fd1, fd2);
	    if (code == -1) SUB_ERROR(errno, "netsys_spawn/dup2 [224]");
	    /* The FD_CLOEXEC flag remains off for the duped descriptor */
	    break;
	default:
	    SUB_ERROR(EINVAL, "netsys_spawn/assert_fd [230]");
	};
    };

    /* reset the signal mask: */
#ifdef HAVE_POSIX_SIGNALS
    code = sigprocmask(SIG_SETMASK, &save_mask, NULL);
    if (code == -1) SUB_ERROR(errno, "netsys_spawn/sigprocmask [241]");
#endif

    /* exec the new program: */
    code = execve(String_val(v_cmd),
		  sub_argv,
		  sub_env);
    if (code == -1) SUB_ERROR(errno, "netsys_spawn/execve [290]");

    SUB_ERROR(EINVAL, "netsys_spawn/assert_execve [291]");

 sub_error:
    /* Marshal the error in uerror_errno and uerror_function */
    me.decoded.b_errno = uerror_errno;
    strcpy(me.decoded.b_function, uerror_function);
    
    n = write(ctrl_pipe[1], me.buffer, sizeof(me.buffer));
    /* it doesn't make much sense here to check for write errors */

    _exit(127);
    
 main_process:
    /* Here the main process continues after forking. There's not much to do
       here: We close the write side of the control pipe, so the read side
       can see EOF. We check then whether the read side is just closed
       (meaning no error), or whether there are bytes, the marshalled
       error condition.
    */
    caml_leave_blocking_section();
    cleanup_bsection = 0;

    code = close(ctrl_pipe[1]);
    if (code == -1) {
	uerror_errno = errno;
	uerror_function = "netsys_spawn/close [300]";
	goto main_exit;
    };
    cleanup_pipe1 = 0;   /* it's already closed */

    n = read(ctrl_pipe[0], me.buffer, sizeof(me.buffer));
    if (n == (ssize_t) -1) {
	uerror_errno = errno;
	uerror_function = "netsys_spawn/read [301]";
	goto main_exit;
    };

    if (n == 0) {
	/* hey, we have success! */
	return_value = Val_int(pid);
	goto main_exit;
    }
    
    /* There is an error message in me. Look at it. */
    if (n != (ssize_t) sizeof(me.buffer)) {
	uerror_errno = EINVAL;
	uerror_function = "netsys_spawn/assert_me [302]";
    }

    /* Also don't forget to wait on the child to avoid zombies: */
    code = 1;
    while (code) {
	code = waitpid(pid, NULL, 0);
	code = (code == -1 && errno == EINTR);
    };

    uerror_errno = me.decoded.b_errno;
    uerror_function = me.decoded.b_function;
    /* now exit... */

main_exit:
    /* Policy: If we already have an error to report, and any of the
       cleanup actions also indicates an error, we return the first
       error to the caller.
    */
    
    if (cleanup_bsection)
	caml_leave_blocking_section();

    if (cleanup_mask) {
#ifdef HAVE_PTHREAD
	code = pthread_sigmask(SIG_SETMASK, &save_mask, NULL);
	if (code != 0 && uerror_errno == 0) {
	    uerror_errno = code;
	    uerror_function = "netsys_spawn/pthread_sigmask [400]";
	}
#else
#ifdef HAVE_POSIX_SIGNALS
	code = sigprocmask(SIG_SETMASK, &save_mask, NULL);
	if (code == -1 && uerror_errno == 0) {
	    uerror_errno = errno;
	    uerror_function = "netsys_spawn/sigprocmask [401]";
	}
#endif
#endif
    };

    if (cleanup_pipe0) {
	code = close(ctrl_pipe[0]);
	if (code == -1 && uerror_errno == 0) {
	    uerror_errno = errno;
	    uerror_function = "netsys_spawn/close [410]";
	}
    }

    if (cleanup_pipe1) {
	code = close(ctrl_pipe[1]);
	if (code == -1 && uerror_errno == 0) {
	    uerror_errno = errno;
	    uerror_function = "netsys_spawn/close [411]";
	}
    }

    if (cleanup_sub_argv) {
	free(sub_argv);
    }

    if (cleanup_sub_env) {
	free(sub_env);
    }

    if (uerror_errno != 0)
	unix_error(uerror_errno, uerror_function, Nothing);

    return return_value;
#else
     invalid_argument("netsys_spawn");
#endif
}


CAMLprim value netsys_spawn_byte(value * argv, int argn) 
{
    return netsys_spawn_nat(argv[0], argv[1], argv[2], argv[3],
			    argv[4], argv[5], argv[6]);
}

#undef MAIN_ERROR
#undef SUB_ERROR

/**********************************************************************/
/* Signals+Subprocesses                                               */
/**********************************************************************/

#ifdef HAVE_POSIX_SIGNALS
struct sigchld_atom {
    pid_t pid;          /* 0 means this atom is free */
    pid_t pgid;         /* process group ID if <> 0 */
    int   kill_flag;
    int   terminated;   /* whether terminated or not */
    int   status;       /* if terminated */
    int   ignore;       /* whether this is an ignored process */
    int   pipe_fd;      /* this fd is closed when termination is detected */
    int   kill_sent;    /* scratch variable for kill */
};

static struct sigchld_atom *sigchld_list = NULL;   /* an array of atoms */
static int                  sigchld_list_len = 0;  /* length of array */

#ifdef HAVE_PTHREAD
static pthread_mutex_t      sigchld_mutex = PTHREAD_MUTEX_INITIALIZER;
#endif


/* Our use of pthread + signals is hard at the limit of what POSIX
   allows, in some kind of grey zone. Normally, it is not allowed that
   pthread functions are invoked from signal handlers. However, if one
   reads POSIX carefully, it turns out to be this problem: The pthread
   functions are not reentrant. When a signal handler invokes them, it
   can happen that the signal interrupted the same function before
   (reentrant call). This cannot happen here: We block the signal before
   locking/unlocking the mutex, so it is excluded that the signal handler
   interrupts a running pthread_lock/unlock ACCESSING OUR MUTEX. Of course,
   it can interrupt any other pthread_lock/unlock...

   POSIX: "when a signal interrupts an unsafe function and the
   signal-catching function calls an unsafe function, the behavior is
   undefined."

   So I think it is legal. Not absolutely sure, though. If not, we
   have to switch the implementation. Our problem, however, is that we
   have no means to control which thread blocks SIGCHLD and which
   thread doesn't, so the "text book implementation" is out of reach:
   One thread is set up to get all SIGCHLD signals, and to process these
   sequentially.

   Sketch for a solution:
   - Set up a special thread. It reads endlessly from a pipe, and gets
     from there instructions what to do. This way the thread is notified
     about waitpid tasks. As it runs outside of the signal context,
     there is no problem to set the mutex while accessing the data structure.
   - The signal handler simply writes the PID to the pipe when it gets
     SIGCHLD

   No need to fiddle with signal masks anymore. However, we consume
   2 further file descriptors.

*/

static void sigchld_lock(int block_signal, int master_lock) {
    sigset_t set;
    int code;

    sigemptyset(&set);
    sigaddset(&set, SIGCHLD);

#ifdef HAVE_PTHREAD
    if (block_signal) {
	code = pthread_sigmask(SIG_BLOCK, &set, NULL);
	if (code != 0)
	    uerror("pthread_sigmask", Nothing);
    }
    if (master_lock)
	caml_enter_blocking_section();
    pthread_mutex_lock(&sigchld_mutex);
    if (master_lock)
	caml_leave_blocking_section();
#else
    if (block_signal) {
	code = sigprocmask(SIG_BLOCK, &set, NULL);
	if (code == -1)
	    uerror("sigprocmask", Nothing);
    }
#endif
}


static void sigchld_unlock(int unblock_signal) {
    sigset_t set;
    int code;

    sigemptyset(&set);
    sigaddset(&set, SIGCHLD);

#ifdef HAVE_PTHREAD
    pthread_mutex_unlock(&sigchld_mutex);
    if (unblock_signal) {
	code = pthread_sigmask(SIG_UNBLOCK, &set, NULL);
	if (code != 0)
	    uerror("pthread_sigmask", Nothing);
    }
#else
    if (unblock_signal) {
	code = sigprocmask(SIG_UNBLOCK, &set, NULL);
	if (code == -1)
	    uerror("sigprocmask", Nothing);
    }
#endif
}


static void sigchld_action(int signo, siginfo_t *info, void *ctx) {
    /* This is the sa_sigaction-style signal handler */
    pid_t pid;
    int k;
    struct sigchld_atom *atom;
    int saved_errno;

    saved_errno = errno;

    /* The SIGCHLD signal is blocked in the current thread during the
       execution of this function. However, other threads can also
       try to access sigchld_list in parallel, so we have to protect
       that with a mutex.
    */
    sigchld_lock(0, 0);

    if (info->si_code == CLD_EXITED || info->si_code == CLD_KILLED 
	|| info->si_code == CLD_DUMPED
	) {

	/* Now search for the PID */
	pid = info->si_pid;
	atom = NULL;
	for (k=0; k<sigchld_list_len && atom==NULL; k++) {
	    if (sigchld_list[k].pid == pid) {
		atom = &(sigchld_list[k]);
	    }
	}
	
	if (atom != NULL) {
	    waitpid(pid, &(atom->status), WNOHANG);
	    if (! atom->ignore && ! atom->terminated) {
		close(atom->pipe_fd);
	    }
	    atom->terminated = 1;
	}
    }

    sigchld_unlock(0);

    errno = saved_errno;
}


#endif  /* HAVE_POSIX_SIGNALS */


CAMLprim value netsys_install_sigchld_handler(value dummy) {
#ifdef HAVE_POSIX_SIGNALS
    int code;
    struct sigaction action;
    int k;
    
    sigchld_lock(1, 1);
 
    action.sa_sigaction = sigchld_action;
    sigemptyset(&(action.sa_mask));
    action.sa_flags = SA_SIGINFO | SA_NOCLDSTOP;

    if (sigchld_list == NULL) {
	sigchld_list_len = 100;
	sigchld_list = 
	    (struct sigchld_atom *) malloc(sigchld_list_len * 
					   sizeof(struct sigchld_atom));
	if (sigchld_list == NULL) 
	    failwith("Cannot allocate memory");

	for (k=0; k<sigchld_list_len; k++)
	    sigchld_list[k].pid = 0;
    };

    code = sigaction(SIGCHLD,
		     &action,
		     NULL);
    if (code == -1) {
	code = errno;
	sigchld_unlock(1);
	errno = code;
	uerror("sigaction", Nothing);
    };

    sigchld_unlock(1);

    return Val_unit;
#else
    invalid_argument("Netsys_posix.install_subprocess_handler not available");
#endif
}


CAMLprim value netsys_watch_subprocess(value pid_v, value pgid_v, 
				       value kill_flag_v) {
#ifdef HAVE_POSIX_SIGNALS
    int k, atom_idx;
    struct sigchld_atom *atom;
    int pfd[2];
    value r;
    pid_t pid, pgid;
    int status, code, kill_flag;
    
    if (sigchld_list == NULL)
	failwith("Netsys_posix.watch_subprocess: uninitialized");

    if (pipe(pfd) == -1)
	uerror("pipe", Nothing);

    if (fcntl(pfd[0], F_SETFD, FD_CLOEXEC) == -1) {
	code = errno;
	close(pfd[0]);
	close(pfd[1]);
	errno = code;
	uerror("set_close_on_exec", Nothing);
    };

    if (fcntl(pfd[1], F_SETFD, FD_CLOEXEC) == -1) {
	code = errno;
	close(pfd[0]);
	close(pfd[1]);
	errno = code;
	uerror("set_close_on_exec", Nothing);
    };

    pid = Int_val(pid_v);
    pgid = Int_val(pgid_v);
    kill_flag = Bool_val(kill_flag_v);

    /* First block the signal handler and other threads from concurrent
       accesses:
    */
    sigchld_lock(1, 1);

    /* Search for a free atom: */
    atom=0;
    atom_idx = 0;
    for (k=0; k<sigchld_list_len && atom==NULL; k++) {
	if (sigchld_list[k].pid == 0) {
	    atom = &(sigchld_list[k]);
	    atom_idx = k;
	}
    }

    if (atom == NULL) {
	/* Nothing found. Reallocate. */
	int old_size;

	old_size = sigchld_list_len;
	sigchld_list_len += sigchld_list_len;

	sigchld_list = 
	    (struct sigchld_atom *) realloc( (struct sigchld_atom *)
					     sigchld_list,
					     sigchld_list_len * 
					     sizeof(struct sigchld_atom) );

	if (sigchld_list == NULL) {
	    sigchld_unlock(1);
	    close(pfd[0]);
	    close(pfd[1]);
	    failwith("Cannot allocate memory");
	};

	for (k=old_size; k<sigchld_list_len; k++)
	    sigchld_list[k].pid = 0;

	atom = &(sigchld_list[old_size]);
	atom_idx = old_size;
    };

    /* Try waitpid once. Maybe the process is already terminated! */
    code = waitpid(pid, &status, WNOHANG);

    if (code == -1) {
	code = errno;
	sigchld_unlock(1);
	close(pfd[0]);
	close(pfd[1]);
	errno = code;
	uerror("waitpid", Nothing);
    };

    if (code == 0) {  /* not yet terminated */
	atom->pid = pid;
	atom->pgid = pgid;
	atom->kill_flag = kill_flag;
	atom->terminated = 0;
	atom->status = 0;
	atom->ignore = 0;
	atom->pipe_fd = pfd[1];
    } else {
	close(pfd[1]);
	atom->pid = pid;
	atom->pgid = pgid;
	atom->kill_flag = kill_flag;
	atom->terminated = 1;
	atom->status = status;
	atom->ignore = 0;
	atom->pipe_fd = -1;
    };

    sigchld_unlock(1);

    r = alloc(2,0);
    Field(r,0) = Val_int(pfd[0]);
    Field(r,1) = Val_int(atom_idx);
    
    return r;
#else
    invalid_argument("Netsys_posix.watch_subprocess not available");
#endif
}


CAMLprim value netsys_ignore_subprocess(value atom_idx_v) {
#ifdef HAVE_POSIX_SIGNALS
    int atom_idx;
    struct sigchld_atom *atom;

    atom_idx = Int_val(atom_idx_v);

    sigchld_lock(1, 1);

    atom = &(sigchld_list[atom_idx]);
    if (!atom->ignore && !atom->terminated)
	close(atom->pipe_fd);
    atom->ignore = 1;
    
    sigchld_unlock(1);

    return Val_unit;
#else
    invalid_argument("Netsys_posix.ignore_subprocess not available");
#endif
}


CAMLprim value netsys_forget_subprocess(value atom_idx_v) {
#ifdef HAVE_POSIX_SIGNALS
    int atom_idx;
    struct sigchld_atom *atom;

    sigchld_lock(1, 1);

    atom_idx = Int_val(atom_idx_v);
    atom = &(sigchld_list[atom_idx]);

    atom->pid = 0;
    if (!atom->ignore && !atom->terminated)
	close(atom->pipe_fd);

    sigchld_unlock(1);

    return Val_unit;
#else
    invalid_argument("Netsys_posix.forget_subprocess not available");
#endif
}


#define TAG_WEXITED 0
#define TAG_WSIGNALED 1
#define TAG_WSTOPPED 2


CAMLprim value netsys_get_subprocess_status(value atom_idx_v) {
#ifdef HAVE_POSIX_SIGNALS
    int atom_idx;
    struct sigchld_atom *atom;
    value r, st;

    atom_idx = Int_val(atom_idx_v);

    sigchld_lock(1, 1);

    atom = &(sigchld_list[atom_idx]);

    if (atom->terminated) {
	if (WIFEXITED(atom->status)) {
	    st = alloc_small(1, TAG_WEXITED);
	    Field(st, 0) = Val_int(WEXITSTATUS(atom->status));
	}
	else {
	    st = alloc_small(1, TAG_WSIGNALED);
	    Field(st, 0) = 
		Val_int(caml_rev_convert_signal_number(WTERMSIG(atom->status)));
	};
	r = alloc(1,0);
	Field(r, 0) = st;
    }
    else {
	r = Val_int(0);
    }

    sigchld_unlock(1);

    return r;
#else
    invalid_argument("Netsys_posix.forget_subprocess not available");
#endif
}


CAMLprim value netsys_kill_subprocess(value sig_v, value atom_idx_v) {
#ifdef HAVE_POSIX_SIGNALS
    int atom_idx;
    struct sigchld_atom *atom;
    int sig;

    atom_idx = Int_val(atom_idx_v);
    sig = caml_convert_signal_number(Int_val(sig_v));

    sigchld_lock(1, 1);

    atom = &(sigchld_list[atom_idx]);
    if (!atom->terminated) {
	kill(atom->pid, sig);
    }

    sigchld_unlock(1);

    return Val_unit;

#else
    invalid_argument("Netsys_posix.kill_subprocess not available");
#endif
}


CAMLprim value netsys_killpg_subprocess(value sig_v, value atom_idx_v) {
#ifdef HAVE_POSIX_SIGNALS
    int atom_idx;
    struct sigchld_atom *atom;
    int sig, k;
    pid_t pgid;
    int exists;

    atom_idx = Int_val(atom_idx_v);
    sig = caml_convert_signal_number(Int_val(sig_v));

    sigchld_lock(1, 1);

    atom = &(sigchld_list[atom_idx]);
    pgid = atom->pgid;

    if (pgid > 0) {
	/* Does any process for pgid exist in the watch list? */
	exists = 0;
	for (k=0; k<sigchld_list_len && !exists; k++) {
	    exists=sigchld_list[k].pid != 0 && !sigchld_list[k].terminated;
	}
	if (exists) {
	    kill(-pgid, sig);
	}
    }

    sigchld_unlock(1);

    return Val_unit;

#else
    invalid_argument("Netsys_posix.killpg_subprocess not available");
#endif
}


CAMLprim value netsys_kill_all_subprocesses(value sig_v, value o_flag_v,
					    value ng_flag_v) {
#ifdef HAVE_POSIX_SIGNALS
    int sig;
    int o_flag, ng_flag;
    struct sigchld_atom *atom;
    int k;

    if (sigchld_list == NULL)
	failwith("Netsys_posix.watch_subprocess: uninitialized");

    sig = caml_convert_signal_number(Int_val(sig_v));
    o_flag = Bool_val(o_flag_v);
    ng_flag = Bool_val(ng_flag_v);

    sigchld_lock(1, 1);

    for (k=0; k<sigchld_list_len; k++) {
	atom = &(sigchld_list[k]);
	if (atom->pid != 0 && 
	    !atom->terminated && 
	    (!ng_flag || atom->pgid==0) &&
	    (o_flag || atom->kill_flag)) {
	    
	    kill(atom->pid, sig);
	}
    }

    sigchld_unlock(1);

    return Val_unit;

#else
    invalid_argument("Netsys_posix.kill_all_subprocesses not available");
#endif
}


CAMLprim value netsys_killpg_all_subprocesses(value sig_v, value o_flag_v) {
#ifdef HAVE_POSIX_SIGNALS
    struct sigchld_atom *atom;
    int sig;
    int o_flag;
    int k,j;
    pid_t pgid;

    if (sigchld_list == NULL)
	failwith("Netsys_posix.watch_subprocess: uninitialized");

    sig = caml_convert_signal_number(Int_val(sig_v));
    o_flag = Bool_val(o_flag_v);

    sigchld_lock(1, 1);

    /* delete kill_sent: */
    for (k=0; k<sigchld_list_len; k++) {
	sigchld_list[k].kill_sent = 0;
    };

    /* check processes: */
    for (k=0; k<sigchld_list_len; k++) {
	atom = &(sigchld_list[k]);
	if (atom->pid != 0 && 
	    !atom->terminated && 
	    atom->pgid > 0 &&
	    !atom->kill_sent &&
	    (o_flag || atom->kill_flag)) {
	    
	    pgid = atom->pgid;
	    kill(-pgid, sig);
	    
	    for (j=k+1; j<sigchld_list_len; j++) {
		if (sigchld_list[j].pid != 0 && sigchld_list[j].pgid == pgid)
		    sigchld_list[j].kill_sent = 1;
	    }
	}
    }

    sigchld_unlock(1);

    return Val_unit;

#else
    invalid_argument("Netsys_posix.killpg_all_subprocesses not available");
#endif
}



/**********************************************************************/
/* POSIX fadvise                                                      */
/**********************************************************************/

/* A lately added POSIX function */

CAMLprim value netsys_have_posix_fadvise(value dummy) {
#ifdef HAVE_POSIX_FADVISE
    return Val_bool(1);
#else
    return Val_bool(0);
#endif
}

CAMLprim value netsys_fadvise(value fd, value start, value len, value adv) {
#ifdef HAVE_POSIX_FADVISE
    int adv_int, r;
    long long start_int, len_int;

    adv_int = 0;
    switch (Int_val(adv)) {
    case 0: adv_int = POSIX_FADV_NORMAL; break;
    case 1: adv_int = POSIX_FADV_SEQUENTIAL; break;
    case 2: adv_int = POSIX_FADV_RANDOM; break;
    case 3: adv_int = POSIX_FADV_NOREUSE; break;
    case 4: adv_int = POSIX_FADV_WILLNEED; break;
    case 5: adv_int = POSIX_FADV_DONTNEED; break;
    default: invalid_argument("Netsys.fadvise");
    };

    start_int = Int64_val(start);
    len_int = Int64_val(len);
    r = posix_fadvise64(Int_val(fd), start_int, len_int, adv_int);
    if (r == -1) 
	uerror("posix_fadvise64", Nothing);
    return Val_unit;
#else
    invalid_argument("Netsys.fadvise not available");
#endif
}

/**********************************************************************/
/* POSIX fallocate                                                    */
/**********************************************************************/

/* A lately added POSIX function */

CAMLprim value netsys_have_posix_fallocate(value dummy) {
#ifdef HAVE_POSIX_FALLOCATE
    return Val_bool(1);
#else
    return Val_bool(0);
#endif
}


CAMLprim value netsys_fallocate(value fd, value start, value len) {
#ifdef HAVE_POSIX_FALLOCATE
    int r;
    long long start_int, len_int;
    start_int = Int64_val(start);
    len_int = Int64_val(len);
    r = posix_fallocate64(Int_val(fd), start_int, len_int);
    /* does not set errno! */
    if (r != 0) 
	unix_error(r, "posix_fallocate64", Nothing);
    return Val_unit;
#else
    invalid_argument("Netsys.fallocate not available");
#endif
}

/**********************************************************************/
/* POSIX shared memory                                                */
/**********************************************************************/

/* This is from the POSIX realtime extensions. Not every POSIX-type OS
 * supports it.
 */

CAMLprim value netsys_have_posix_shm(value dummy) {
#ifdef HAVE_POSIX_SHM
    return Val_bool(1);
#else
    return Val_bool(0);
#endif
}

#ifdef HAVE_POSIX_SHM
static int shm_open_flag_table[] = {
    O_RDONLY, O_RDWR, O_CREAT, O_EXCL, O_TRUNC
};
#endif


CAMLprim value netsys_shm_open(value path, value flags, value perm)
{
#ifdef HAVE_POSIX_SHM
    CAMLparam3(path, flags, perm);
    int ret, cv_flags;
    char * p;

    cv_flags = convert_flag_list(flags, shm_open_flag_table);
    p = stat_alloc(string_length(path) + 1);
    strcpy(p, String_val(path));
    ret = shm_open(p, cv_flags, Int_val(perm));
    stat_free(p);
    if (ret == -1) uerror("shm_open", path);
    CAMLreturn (Val_int(ret));
#else
    invalid_argument("Netsys.shm_open not available");
#endif
}


CAMLprim value netsys_shm_unlink(value path)
{
#ifdef HAVE_POSIX_SHM
    int ret;

    ret = shm_unlink(String_val(path));
    if (ret == -1) uerror("shm_unlink", path);
    return Val_unit;
#else
    invalid_argument("Netsys.shm_unlink not available");
#endif
}


/**********************************************************************/
/* Bigarray helpers                                                   */
/**********************************************************************/

CAMLprim value netsys_blit_memory_to_string(value memv,
					    value memoffv,
					    value sv,
					    value soffv,
					    value lenv)
{
    struct caml_bigarray *mem = Bigarray_val(memv);
    char * s = String_val(sv);
    long memoff = Long_val(memoffv);
    long soff = Long_val(soffv);
    long len = Long_val(lenv);

    memmove(s + soff, ((char*) mem->data) + memoff, len);

    return Val_unit;
}


CAMLprim value netsys_blit_string_to_memory(value sv,
					    value soffv,
					    value memv,
					    value memoffv,
					    value lenv)
{
    struct caml_bigarray *mem = Bigarray_val(memv);
    char * s = String_val(sv);
    long memoff = Long_val(memoffv);
    long soff = Long_val(soffv);
    long len = Long_val(lenv);

    memmove(((char*) mem->data) + memoff, s + soff, len);

    return Val_unit;
}


CAMLprim value netsys_memory_address(value memv)
{
    struct caml_bigarray *mem = Bigarray_val(memv);
    return caml_copy_nativeint((intnat) mem->data);
}


CAMLprim value netsys_getpagesize(value dummy)
{
#ifdef HAVE_SYSCONF
    return Val_long(sysconf(_SC_PAGESIZE));
#else
    invalid_argument("Netsys_mem.getpagesize not available");
#endif
}


CAMLprim value netsys_alloc_memory_pages(value addrv, value pv)
{
#if defined(HAVE_MMAP) && defined(HAVE_SYSCONF) && defined(MAP_ANON)
    void *start;
    size_t length;
    long pgsize;
    void *data;
    value r;

    start = (void *) Nativeint_val(addrv);
    if (start == 0) start=NULL;    /* for formal reasons */

    length = Int_val(pv);
    pgsize = sysconf(_SC_PAGESIZE);
    length = ((length - 1) / pgsize + 1) * pgsize;  /* fixup */

    data = mmap(start, length, PROT_READ|PROT_WRITE, 
		MAP_PRIVATE | MAP_ANON, (-1), 0);
    if (data == (void *) -1) uerror("mmap", Nothing);

    r = alloc_bigarray_dims(BIGARRAY_C_LAYOUT | BIGARRAY_UINT8 | 
			    BIGARRAY_MAPPED_FILE,
			    1, data, length);

    return r;
#else
    invalid_argument("Netsys_mem.alloc_memory_pages not available");
#endif
}


CAMLprim value netsys_alloc_aligned_memory(value alignv, value pv)
{
#if defined(HAVE_MEMALIGN)
    size_t align = Long_val(alignv);
    size_t size = Long_val(pv);
    void * addr = NULL;
    int e;
    value r;

    e = posix_memalign(&addr, align, size);
    if (e != 0) unix_error(e, "posix_memalign", Nothing);

    r = alloc_bigarray_dims(BIGARRAY_C_LAYOUT | BIGARRAY_UINT8 | 
			    BIGARRAY_MANAGED,
			    1, addr, size);
    return r;
#else
    invalid_argument("Netsys_mem.alloc_aligned_memory not available");
#endif
}


/* from mmap_unix.c: */
static void ba_unmap_file(void * addr, uintnat len)
{
#if defined(HAVE_MMAP) && defined(HAVE_SYSCONF)
  uintnat page = sysconf(_SC_PAGESIZE);
  uintnat delta = (uintnat) addr % page;
  munmap((void *)((uintnat)addr - delta), len + delta);
#endif
}



CAMLprim value netsys_memory_unmap_file(value memv) 
{
    struct caml_bigarray *b = Bigarray_val(memv);
    if ((b->flags & BIGARRAY_MANAGED_MASK) == BIGARRAY_MAPPED_FILE) {
	if (b->proxy == NULL) {
	    ba_unmap_file(b->data, b->dim[0]);
	    b->data = NULL;
	    b->flags = 
		(b->flags & ~BIGARRAY_MANAGED_MASK) | BIGARRAY_EXTERNAL;
	}
	else if (b->proxy->refcount == 1) {
	    ba_unmap_file(b->proxy->data, b->dim[0]);
	    b->proxy->data = NULL;
	    b->data = NULL;
	    b->flags = 
		(b->flags & ~BIGARRAY_MANAGED_MASK) | BIGARRAY_EXTERNAL;
	}
    }
    return Val_unit;
}


CAMLprim value netsys_as_value(value memv, value offv) 
{
    struct caml_bigarray *b = Bigarray_val(memv);
    return (value) (b->data + Long_val(offv));
}


CAMLprim value netsys_init_string(value memv, value offv, value lenv) 
{
    struct caml_bigarray *b = Bigarray_val(memv);
    long off = Long_val(offv);
    long len = Long_val(lenv);
    value *m;
    char *m_b;
    mlsize_t wosize;
    mlsize_t offset_index;

#ifdef ARCH_SIXTYFOUR
    if (off % 8 != 0)
	invalid_argument("Netsys_mem.init_string");
#else
    if (off % 4 != 0)
	invalid_argument("Netsys_mem.init_string");
#endif

    m = (value *) (((char *) b->data) + off);
    m_b = (char *) m;
    wosize = (len + sizeof (value)) / sizeof (value);  /* >= 1 */
    
    m[0] = /* Make_header (wosize, 0, Caml_black) */
	(value) (((header_t) wosize << 10) + (3 << 8));
    m[wosize] = 0;

    offset_index = Bsize_wsize (wosize) - 1;
    m_b[offset_index + sizeof(value)] = offset_index - len;

    return Val_unit;
}


CAMLprim value netsys_mem_read(value fdv, value memv, value offv, value lenv)
{
    long numbytes;
    void *data;
    int ret;
#ifndef _WIN32
    Begin_root (memv);
    numbytes = Long_val(lenv);
    data = Bigarray_val(memv)->data;
    enter_blocking_section();
    ret = read(Int_val(fdv), data, (int) numbytes);
    leave_blocking_section();
    if (ret == -1) uerror("read", Nothing);
  End_roots();
  return Val_int(ret);
#else
    invalid_argument("Netsys_mem.mem_read not available");
#endif
}


/**********************************************************************/
/* Multicast                                                          */
/**********************************************************************/

static int socket_domain(int fd) {
    /* Return the socket domain, PF_INET or PF_INET6. Fails for non-IP 
       protos.

       fd must be a socket!
    */
    union sock_addr_union addr;
    socklen_t l;

    l = sizeof(addr);
    if (getsockname(fd, &addr.s_gen, &l) == -1) 
        uerror("getsockname", Nothing);

    switch (addr.s_gen.sa_family) {
    case AF_INET:
        return PF_INET;
#ifdef HAS_IPV6
    case AF_INET6:
        return PF_INET6;
#endif
    default:
	invalid_argument("Not an Internet socket");
    }

    return 0;
}


CAMLprim value netsys_mcast_set_loop(value fd, value flag) {
    int t, r, f;

    t = socket_domain(Int_val(fd));
    f = Bool_val(flag);

    r = 0;
    switch (t) {
#ifdef IP_MULTICAST_LOOP
    case PF_INET:
        r = setsockopt(Int_val(fd), 
                       IPPROTO_IP, 
                       IP_MULTICAST_LOOP, 
                       (void *) &f, sizeof(f));
        break;
#endif
#ifdef HAS_IPV6
#ifdef IPV6_MULTICAST_LOOP
    case PF_INET6:
        r = setsockopt(Int_val(fd), 
                       IPPROTO_IPV6, 
                       IPV6_MULTICAST_LOOP, 
                       (void *) &f, sizeof(f));
        break;
#endif
#endif
    default:
	invalid_argument("Netsys.mcast_set_loop");
    };

    if (r == -1)
        uerror("setsockopt",Nothing);

    return Val_unit;
}


CAMLprim value netsys_mcast_set_ttl(value fd, value ttl) {
    int t, r, v;
    int fd_sock;

#ifdef _WIN32
    if (Descr_kind_val(fd) != KIND_SOCKET)
	invalid_argument("Netsys.mcast_set_ttl");
    fd_sock = Socket_val(fd);
#else
    fd_sock = Int_val(fd);
#endif
 
    t = socket_domain(fd_sock);
    v = Int_val(ttl);

    r = 0;
    switch (t) {
#ifdef IP_MULTICAST_TTL
    case PF_INET:
        r = setsockopt(fd_sock, 
                       IPPROTO_IP, 
                       IP_MULTICAST_TTL, 
                       (void *) &v, sizeof(v));
        break;
#endif
#ifdef HAS_IPV6
#ifdef IPV6_MULTICAST_HOPS
    case PF_INET6:
        r = setsockopt(fd_sock, 
                       IPPROTO_IPV6, 
                       IPV6_MULTICAST_HOPS, 
                       (void *) &v, sizeof(v));
        break;
#endif
#endif
    default:
	invalid_argument("Netsys.mcast_set_ttl");
    };

    if (r == -1)
        uerror("setsockopt",Nothing);

    return Val_unit;
}


CAMLprim value netsys_mcast_add_membership(value fd,
					   value group_addr, 
					   value if_addr) {
    int t, r;
    int fd_sock;

#ifdef _WIN32
    if (Descr_kind_val(fd) != KIND_SOCKET)
	invalid_argument("Netsys.mcast_add_membership");
    fd_sock = Socket_val(fd);
#else
    fd_sock = Int_val(fd);
#endif

    t = socket_domain(fd_sock);

    r = 0;
    switch (t) {
#ifdef IP_ADD_MEMBERSHIP
    case PF_INET: {
        struct ip_mreq mreq;
        if (string_length(group_addr) != 4 || string_length(if_addr) != 4 )
            invalid_argument("Netsys.mcast_add_membership: Not an IPV4 address");
        memcpy(&mreq.imr_multiaddr,
               &GET_INET_ADDR(group_addr),
               4);
        memcpy(&mreq.imr_interface,
               &GET_INET_ADDR(if_addr),
               4);
        r = setsockopt(fd_sock, 
                       IPPROTO_IP, 
                       IP_ADD_MEMBERSHIP, 
                       (void *) &mreq, sizeof(mreq));
        break;
    }
#endif
#ifdef HAS_IPV6
#ifdef IPV6_ADD_MEMBERSHIP
    case PF_INET6: {
        struct ipv6_mreq mreq;
        if (string_length(group_addr) != 16 || string_length(if_addr) != 16 )
            invalid_argument("Netsys.mcast_add_membership: Not an IPV6 address");
        memcpy(&mreq.ipv6mr_multiaddr,
               &GET_INET6_ADDR(group_addr),
               16);
        memcpy(&mreq.ipv6mr_interface,
               &GET_INET6_ADDR(if_addr),
               16);
        r = setsockopt(fd_sock, 
                       IPPROTO_IPV6, 
                       IPV6_ADD_MEMBERSHIP, 
                       (void *) &mreq, sizeof(mreq));
        break;
    }
#endif
#endif
    default:
	invalid_argument("Netsys.mcast_add_membership");
    };
    if (r == -1)
        uerror("setsockopt",Nothing);

    return Val_unit;
}


CAMLprim value netsys_mcast_drop_membership(value fd, 
					    value group_addr, 
					    value if_addr) {
    int t, r;
    int fd_sock;

#ifdef _WIN32
    if (Descr_kind_val(fd) != KIND_SOCKET)
	invalid_argument("Netsys.mcast_drop_membership");
    fd_sock = Socket_val(fd);
#else
    fd_sock = Int_val(fd);
#endif

    t = socket_domain(fd_sock);

    r = 0;
    switch (t) {
#ifdef IP_DROP_MEMBERSHIP
    case PF_INET: {
        struct ip_mreq mreq;
        if (string_length(group_addr) != 4 || string_length(if_addr) != 4 )
            invalid_argument("Netsys.mcast_drop_membership: Not an IPV4 address");
        memcpy(&mreq.imr_multiaddr,
               &GET_INET_ADDR(group_addr),
               4);
        memcpy(&mreq.imr_interface,
               &GET_INET_ADDR(if_addr),
               4);
        r = setsockopt(fd_sock,
                       IPPROTO_IP, 
                       IP_DROP_MEMBERSHIP, 
                       (void *) &mreq, sizeof(mreq));
        break;
    }
#endif
#ifdef HAS_IPV6
#ifdef IPV6_DROP_MEMBERSHIP
    case PF_INET6: {
        struct ipv6_mreq mreq;
        if (string_length(group_addr) != 16 || string_length(if_addr) != 16 )
            invalid_argument("Netsys.mcast_drop_membership: Not an IPV6 address");
        memcpy(&mreq.ipv6mr_multiaddr,
               &GET_INET6_ADDR(group_addr),
               16);
        memcpy(&mreq.ipv6mr_interface,
               &GET_INET6_ADDR(if_addr),
               16);
        r = setsockopt(fd_sock,
                       IPPROTO_IPV6, 
                       IPV6_DROP_MEMBERSHIP, 
                       &mreq, sizeof(mreq));
        break;
    }
#endif
#endif
    default:
	invalid_argument("Netsys.mcast_drop_membership");
    };

    if (r == -1)
        uerror("setsockopt",Nothing);

    return Val_unit;
}


/**********************************************************************/
/* I/O priorities (Linux-only)                                        */
/**********************************************************************/

/* Available since kernel 2.6.13 */

/* There is no glibc support for these calls. 
   See http://sourceware.org/bugzilla/show_bug.cgi?id=4464
   for Drepper's opinion about that.
*/

#ifdef __linux__

#if defined(__i386__)
#define __NR_ioprio_set         289
#define __NR_ioprio_get         290
#define ioprio_supported
#elif defined(__ppc__)
#define __NR_ioprio_set         273
#define __NR_ioprio_get         274
#define ioprio_supported
#elif defined(__x86_64__)
#define __NR_ioprio_set         251
#define __NR_ioprio_get         252
#define ioprio_supported
#elif defined(__ia64__)
#define __NR_ioprio_set         1274
#define __NR_ioprio_get         1275
#define ioprio_supported
/* Other architectures unsupported */
#endif

#endif
/* __linux__ */


#ifdef ioprio_supported

static inline int ioprio_set (int which, int who, int ioprio)
{
    return syscall (__NR_ioprio_set, which, who, ioprio);
}

static inline int ioprio_get (int which, int who)
{
        return syscall (__NR_ioprio_get, which, who);
}

enum {
        IOPRIO_CLASS_NONE,
        IOPRIO_CLASS_RT,
        IOPRIO_CLASS_BE,
        IOPRIO_CLASS_IDLE,
};

enum {
        IOPRIO_WHO_PROCESS = 1,
        IOPRIO_WHO_PGRP,
        IOPRIO_WHO_USER,
};

#define IOPRIO_CLASS_SHIFT      13
#define IOPRIO_PRIO_MASK        0xff

#endif
/* ioprio_supported */


CAMLprim value netsys_ioprio_get(value target) {
#ifdef ioprio_supported
    int ioprio;
    int ioprio_class;
    int ioprio_data;
    value result;

    switch (Tag_val(target)) {
    case 0:
	ioprio = ioprio_get(IOPRIO_WHO_PROCESS, Int_val(Field(target, 0)));
	break;
    case 1:
	ioprio = ioprio_get(IOPRIO_WHO_PGRP, Int_val(Field(target, 0)));
	break;
    case 2:
	ioprio = ioprio_get(IOPRIO_WHO_USER, Int_val(Field(target, 0)));
	break;
    default:
	failwith("netsys_ioprio_get: internal error");
    }

    if (ioprio == -1)
	uerror("ioprio_get", Nothing);

    ioprio_class = ioprio >> IOPRIO_CLASS_SHIFT;
    ioprio_data = ioprio & IOPRIO_PRIO_MASK;

    switch (ioprio_class) {
    case IOPRIO_CLASS_NONE:
	result = Val_long(0);
	break;
    case IOPRIO_CLASS_RT:
	result = caml_alloc(1, 0);
	Store_field(result, 0, Val_int(ioprio_data));
	break;
    case IOPRIO_CLASS_BE:
	result = caml_alloc(1, 1);
	Store_field(result, 0, Val_int(ioprio_data));
	break;
    case IOPRIO_CLASS_IDLE:
	result = Val_long(1);
	break;
    default:
	failwith("netsys_ioprio_get: Unexpected result");
    }
    
    return result;

#else
    /* not ioprio_supported: */
    unix_error(ENOSYS, "ioprio_get", Nothing);
#endif
    /* ioprio_supported */
}


CAMLprim value netsys_ioprio_set(value target, value ioprio_arg) {
#ifdef ioprio_supported
    int ioprio;
    int ioprio_class;
    int ioprio_data;
    int sysres;

    if (Is_block(ioprio_arg)) {
	switch (Tag_val(ioprio_arg)) {
	case 0:
	    ioprio_class = IOPRIO_CLASS_RT;
	    ioprio_data = Int_val(Field(ioprio_arg, 0));
	    break;
	case 1:
	    ioprio_class = IOPRIO_CLASS_BE;
	    ioprio_data = Int_val(Field(ioprio_arg, 0));
	    break;
	default:
	    failwith("netsys_ioprio_set: internal error");
	}
    } else {
	switch (Long_val(ioprio_arg)) {
	case 0:
	    /* Makes no sense. We behave in the same way as ionice */
	    ioprio_class = IOPRIO_CLASS_BE;
	    ioprio_data = 4;
	    break;
	case 1:
	    ioprio_class = IOPRIO_CLASS_IDLE;
	    ioprio_data = 7;
	    break;
	default:
	    failwith("netsys_ioprio_set: internal error");
	}
    };

    ioprio = (ioprio_class << IOPRIO_CLASS_SHIFT) | (ioprio_data & IOPRIO_PRIO_MASK);

    switch (Tag_val(target)) {
    case 0:
	sysres = ioprio_set(IOPRIO_WHO_PROCESS, Int_val(Field(target, 0)), ioprio);
	break;
    case 1:
	sysres = ioprio_set(IOPRIO_WHO_PGRP, Int_val(Field(target, 0)), ioprio);
	break;
    case 2:
	sysres = ioprio_set(IOPRIO_WHO_USER, Int_val(Field(target, 0)), ioprio);
	break;
    default:
	failwith("netsys_ioprio_set: internal error");
    }

    if (sysres == -1)
	uerror("ioprio_set", Nothing);

    return Val_unit;
#else
    /* not ioprio_supported: */
    unix_error(ENOSYS, "ioprio_set", Nothing);
#endif
    /* ioprio_supported */
}
