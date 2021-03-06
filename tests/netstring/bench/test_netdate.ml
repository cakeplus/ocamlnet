#use "topfind";;
#require "netstring";;

open Netdate
open Printf
;;

let success = ref false
let testnr = ref 0


let expect_pass name f =
  printf "Test %s: %!" name;
  success := true;
  testnr := 1;
  try 
    let () = f() in
    if !success then
      printf "Passed\n%!"
    else
      printf "Failed\n%!"
  with
    | exn -> 
	printf "Exception (n=%d): %s\n%!" !testnr (Printexc.to_string exn)


let expect_equal ~printer x y =
  if x <> y then (
    printf "\nexpect_equal %d fails: %S <> %S\n" 
      !testnr (printer x) (printer y);
    success := false
  );
  incr testnr



let print_date d =
  sprintf "{y=%d,m=%d,d=%d,H=%d,M=%d,S=%d,n=%d,z=%d,wd=%d}"
          d.year d.month d.day
          d.hour d.minute d.second d.nanos
          (d.zone/60) d.week_day
;;

let equal_str   = expect_equal ~printer:(fun s -> s);;
let equal_date  = expect_equal ~printer:print_date;;
let equal_float = expect_equal ~printer:string_of_float;;
let equal_int   = expect_equal ~printer:string_of_int;;
let equal_int_pair = expect_equal ~printer:(fun (x,y) -> sprintf "(%d,%d)" x y);;

let t = 1000000000.0;;
let t_date =
    { year  =  2001;  month    =  9;  day    = 09;
      hour  =    01;  minute   = 46;  second = 40; nanos = 0;
      zone  =  0*60;  week_day =  0;
    }
;;


let mk y m d = 
  { year=y; month=m; day=d; 
    hour=0; minute=0; second=0; nanos = 0; 
    zone=60; week_day=(-1)
  };;

expect_pass "epoch conversions"
begin fun () ->

  equal_date   t_date   (create t);
  equal_float  t        (since_epoch t_date);

end;;

expect_pass "RFC 822/1123 date parsing"
begin fun () ->

(*  - 2 digit year no longer supported
  equal_date
    { year  =  2000;  month    =  7;  day    = 13;
      hour  =    21;  minute   = 30;  second =  7;
      zone  =  5*60;  week_day =  4;
    }
    (parse "Thu, 13 Jul 00 21:30:07 +0500");
 *)

  equal_date
    { year  =  2000;  month    =  7;  day    = 13;
      hour  =    21;  minute   = 30;  second =  7; nanos = 0;
      zone  =  5*60;  week_day =  4;
    }
    (parse "Thu, 13 Jul 2000 21:30:07 +0500");
end;;

expect_pass "RFC 850/1036 date parsing"
begin fun () ->

  equal_date
    { year  =  2001;  month    =  9;  day    =  9;
      hour  =     1;  minute   = 46;  second = 40; nanos = 0;
      zone  =  0*60;  week_day =  0;
    }
    (parse "Sunday, 09-Sep-01 01:46:40 GMT");

end;;

expect_pass "ANSI C's asctime parsing"
begin fun () ->
  equal_date
    { year  =  2000;  month    =  7;  day    = 13;
      hour  =    21;  minute   = 30;  second =  7; nanos = 0;
      zone  =     0;  week_day =  4;
    }
    (parse "Thu Jul 13 21:30:07 2000");
end;;

expect_pass "RFC 3339 date parsing"
  begin fun () ->
    equal_date
      { year = 1985;  month = 4; day = 12;
	hour = 23;    minute=20; second=50; nanos = 520_000_000;
	zone = 0; week_day = (-1)
      }
      (parse "1985-04-12T23:20:50.52Z");
     equal_date
      { year = 1996;  month =12; day = 19;
	hour = 16;    minute=39; second=57; nanos = 0;
	zone = -480; week_day = (-1)
      }
      (parse "1996-12-19T16:39:57-08:00");
     equal_date
      { year = 1937;  month =1; day = 1;
	hour = 12;    minute=0; second=27; nanos = 870_000_000;
	zone = 20; week_day = (-1)
      }
      (parse "1937-01-01T12:00:27.87+00:20")
 end;;

expect_pass "Miscellaneous date parsing"
begin fun () ->

  equal_date
    { year  =  2000;  month    =  7;  day    = 13;
      hour  =    10;  minute   = 35;  second = 4; nanos = 0;
      zone  =     0;  week_day = -1;
    }
    (parse "13 Jul 2000 10:35:04 AM");

  equal_date
    { year  =  2000;  month    =  7;  day    = 13;
      hour  =    22;  minute   = 35;  second = 4; nanos = 0;
      zone  =     0;  week_day = -1;
    }
    (parse "13 Jul 2000 10:35:04 PM");

  equal_date
    { year  =  2000;  month    =  7;  day    = 13;
      hour  =    22;  minute   = 35;  second = 4; nanos = 0;
      zone  = -7*60;  week_day = -1;
    }
    (parse "13 Jul 2000 10:35:04 PM MST");


  equal_float
    t
    (parse_epoch "Sunday, 09-Sep-01 01:46:40 +0000");

end;;

(* - no longer supported 
expect_pass "three digit years"
begin fun () ->
  equal_date
    { year  =  2000;  month    =  7;  day    = 13;
      hour  =    21;  minute   = 30;  second =  7;
      zone  =  5*60;  week_day =  4;
    }
    (parse "Thu, 13 Jul 100 21:30:07 +0500");

  equal_date
    { year  =  2070;  month    =  7;  day    = 13;
      hour  =    21;  minute   = 30;  second =  7;
      zone  =  5*60;  week_day =  4;
    }
    (parse "Thu, 13 Jul 170 21:30:07 +0500");
   
end;;
 *)

expect_pass "date formatting"
begin fun () ->

  equal_str "Sunday"                     (format "%A" t_date);
  equal_str "Sun"                        (format "%a" t_date);
  equal_str "September"                  (format "%B" t_date);
  equal_str "Sep"                        (format "%b" t_date);
  equal_str "20"                         (format "%C" t_date);
  equal_str "Sun Sep  9 01:46:40 2001"   (format "%c" t_date);
  equal_str "09/09/01"                   (format "%D" t_date);
  equal_str "09"                         (format "%d" t_date);
  equal_str " 9"                         (format "%e" t_date);
  equal_str "01"                         (format "%H" t_date);
  equal_str "Sep"                        (format "%h" t_date);
  equal_str "01"                         (format "%I" t_date);
  equal_str "252"                        (format "%j" t_date);
  equal_str " 1"                         (format "%k" t_date);
  equal_str " 1"                         (format "%l" t_date);
  equal_str "46"                         (format "%M" t_date);
  equal_str "09"                         (format "%m" t_date);
  equal_str "\n"                         (format "%n" t_date);
  equal_str "AM"                         (format "%p" t_date);
  equal_str "am"                         (format "%P" t_date);
  equal_str "01:46"                      (format "%R" t_date);
  equal_str "01:46:40 AM"                (format "%r" t_date);
  equal_str "40"                         (format "%S" t_date);
  equal_str "01:46:40"                   (format "%T" t_date);
  equal_str "\t"                         (format "%t" t_date);
  equal_str "36"                         (format "%U" t_date);
  equal_str "7"                          (format "%u" t_date);
  equal_str "0"                          (format "%w" t_date);
  equal_str "01:46:40"                   (format "%X" t_date);
  equal_str "09/09/01"                   (format "%x" t_date);
  equal_str "2001"                       (format "%Y" t_date);
  equal_str "01"                         (format "%y" t_date);
  equal_str "+0000"                      (format "%z" t_date);
  equal_str "+00:00"                     (format "%:z" t_date);
  equal_str "%"                          (format "%%" t_date);

end;;

expect_pass "date construction"
begin fun () ->

  equal_str
    "Sun, 09 Sep 2001 01:46:40 +0000"
    (mk_mail_date t);
  equal_str
    "Sunday, 09-Sep-01 01:46:40 +0000"
    (mk_usenet_date t);
  equal_str
    "2001-09-09T01:46:40+00:00"
    (mk_internet_date t);

end;;

expect_pass "week numbering"
begin fun () ->
  let wp = iso8601_week_pair in
  equal_int_pair (wp (mk 1980 1 1)) (1,1980);
  equal_int_pair (wp (mk 1981 1 1)) (1,1981);
  equal_int_pair (wp (mk 1982 1 1)) (53,1981);
  equal_int_pair (wp (mk 1983 1 1)) (52,1982);
  equal_int_pair (wp (mk 1984 1 1)) (52,1983);
  equal_int_pair (wp (mk 1985 1 1)) (1,1985);
  equal_int_pair (wp (mk 1986 1 1)) (1,1986);
  equal_int_pair (wp (mk 1987 1 1)) (1,1987);
  equal_int_pair (wp (mk 1988 1 1)) (53,1987);
  equal_int_pair (wp (mk 1989 1 1)) (52,1988);

  equal_int_pair (wp (mk 1980 1 10)) (2,1980);
  equal_int_pair (wp (mk 1981 1 10)) (2,1981);
  equal_int_pair (wp (mk 1982 1 10)) (1,1982);
  equal_int_pair (wp (mk 1983 1 10)) (2,1983);
  equal_int_pair (wp (mk 1984 1 10)) (2,1984);
  equal_int_pair (wp (mk 1985 1 10)) (2,1985);
  equal_int_pair (wp (mk 1986 1 10)) (2,1986);
  equal_int_pair (wp (mk 1987 1 10)) (2,1987);
  equal_int_pair (wp (mk 1988 1 10)) (1,1988);
  equal_int_pair (wp (mk 1989 1 10)) (2,1989);

  equal_int_pair (wp (mk 1980 12 20)) (51,1980);
  equal_int_pair (wp (mk 1981 12 20)) (51,1981);
  equal_int_pair (wp (mk 1982 12 20)) (51,1982);
  equal_int_pair (wp (mk 1983 12 20)) (51,1983);
  equal_int_pair (wp (mk 1984 12 20)) (51,1984);
  equal_int_pair (wp (mk 1985 12 20)) (51,1985);
  equal_int_pair (wp (mk 1986 12 20)) (51,1986);
  equal_int_pair (wp (mk 1987 12 20)) (51,1987);
  equal_int_pair (wp (mk 1988 12 20)) (51,1988);
  equal_int_pair (wp (mk 1989 12 20)) (51,1989);

  equal_int_pair (wp (mk 1980 12 31)) (1,1981);
  equal_int_pair (wp (mk 1981 12 31)) (53,1981);
  equal_int_pair (wp (mk 1982 12 31)) (52,1982);
  equal_int_pair (wp (mk 1983 12 31)) (52,1983);
  equal_int_pair (wp (mk 1984 12 31)) (1,1985);
  equal_int_pair (wp (mk 1985 12 31)) (1,1986);
  equal_int_pair (wp (mk 1986 12 31)) (1,1987);
  equal_int_pair (wp (mk 1987 12 31)) (53,1987);
  equal_int_pair (wp (mk 1988 12 31)) (52,1988);
  equal_int_pair (wp (mk 1989 12 31)) (52,1989);

end ;;
