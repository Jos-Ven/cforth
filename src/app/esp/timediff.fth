marker -timediff.fth cr lastacf .name #19 to-column .( 01-08-2023 ) \ By J.v.d.Ven
\ Time calculations.  Time specifications like  ( ss mm uu JD -  ) are in UTC
\ unless otherwise indicated like: ( hhmmTargetLocal -- ) or ( f: UtcTics - ss mm uu dd mm yearLocal )

f# -1 fvalue #diff-tics \ = #utcTicsRpi - ( msEsp / 1000 )
f# -1 fvalue UtcOffset  \ Time zone depended
f# -1 fvalue UtcSunRise
f# -1 fvalue UtcSunSet

f# 86400. fconstant #SecondsOneDay
   #3600   constant #SecondsOneHour

: jd                ( dd mm yyyy -- julian-day )
    >r                            ( dd mm)( r: yyyy)
        #3 -  dup 0< if  #12 +  r> 1- >r  then
        #306 *  #5 +  #10 /  +       ( day)
        r@  #1461 #4 */  +  #1721116 +
           dup #2299169 > if
               #3 +  r@ #100 / -  r@ #400 / +
           then
    r> drop ;

: /_mod           ( dividend divisor -- remainder quotient )
    >r s>d r> fm/mod ;

: /_    ( dividend divisor -- quotient )  /_mod nip ;

: _mod  ( dividend divisor -- remainder )  /_mod drop ;

: gregorian-year-from-fixed  ( fixed-date -- gregorian-year )
    1 -                      ( d0) \ 1 - for gregorian-epoch
    #146097 /_mod            ( d1 n400)
        #400 * swap          ( year d1)
    #36524  /_mod            ( year d2 n100)
        dup >r               ( year d2 n100)( r: n100)
        #100 *  rot + swap   ( year d2)
    #1461   /_mod            ( year d3 n4)
        #4 * rot + swap      ( year d3)
    #365    /_               ( year n1)
        dup >r               ( year n1)( r: n100 n1)
        +                    ( year)
    r> #4 = r> #4 = or not if 1+ then ;

: gregorian-leap-year?  ( gregorian-year -- flag )
    dup    #4 _mod 0=         ( gregorian-year flag)
    over #100 _mod 0= not and
    swap #400 _mod 0= or      ( flag)
    ;

: day-number             ( month day year -- day-of-year )
    >r  swap                        ( day month)( r: year)
        dup >r                            ( r: year month)
            #367 *  #362 -  #12 / +         ( day-of-year)
        r> 2 > if  \  adjust for mar..dec.      ( r: year)
            r@ gregorian-leap-year? if  1-  else  2 - then
        then
    r> drop ;

: fixed-from-gregorian    ( month day year -- fixed-date )
    dup 1- >r                          ( r: previous-year)
    day-number                              ( day-of-year)
    r@   4 /_  +
    r@ #100 /_  -
    r@ #400 /_  +
    r> #365 * + ;

: gregorian-from-fixed      ( fixed-date -- month day year )
    dup gregorian-year-from-fixed >r              ( r: year)
    dup  1 ( jan ) 1 r@ fixed-from-gregorian -   ( date prior-days)
    over 3 ( mar ) 1 r@ fixed-from-gregorian < not if
        r@ gregorian-leap-year? if  1+  else 2 +  then
    then
    #12 *  #373 +  #367 / >r            ( date)( r: year month)
    2r@ 1 rot fixed-from-gregorian - 1+               ( day)
    r> swap r> ( month day year) ;

: @time    ( - f: Utctics|-1 )
    #diff-tics fdup f0>=
       if  get-secs s>f f+
       then ;

: LocalTics-from-UtcTics ( f: UtcTics - LocalTics ) UtcOffset f+ ;
: UtcTics-from-LocalTics ( f: UtcTics - LocalTics ) UtcOffset f- ;

: Jd-from-UtcTics        ( f: UtcTics - fjd )  #SecondsOneDay f/ f# 2440588 f+  ;

: UtcTics-from-Jd&Time  ( ss mm uu JD -  ) ( f: - UtcTics )
   #2440588 - s>f #SecondsOneDay f* #SecondsOneHour * swap #60 * + + s>f f+ ;

: UtcTics-from-Time&Date      ( ss mm uu dd mm year - ) ( f: - UtcTics )
   jd UtcTics-from-Jd&Time  ;

: Time-from-UtcTics      ( f: UtcTics - ) ( - ss mm uu )
   Jd-from-UtcTics -ftrunc #SecondsOneDay f* fround f>s
   #SecondsOneHour /mod swap #60 /mod #60 /mod drop rot ;

: Moment-from-JD          ( F: julian-day-number -- moment )
    f# -1721424.5E0  f+ ;  \ -1721424.5E0 = JD-Start

: Date-from-jd          ( f: fjd - ) ( - dd mm year )
   ftrunc Moment-from-JD f>s  Gregorian-from-Fixed  >r swap r> ;

: week-day ( Julian-day - day )  ftrunc f>s 1+ 7 mod ; \ 0=Sunday

: local-time-now   ( - f: UtcTics )   @time LocalTics-from-UtcTics  ;

: .- ( n - )  (u.) type ." -"   ;

: date-from-utc-time ( F: UtcTics -  dd mm yearLocal )
   LocalTics-from-UtcTics Jd-from-UtcTics Date-from-jd ;

: date-now      ( - dd mm yearLocal )   @time date-from-utc-time ;
: date>jjjjmmdd  ( d m j - jjjjmmdd )   10000 * swap 100 * + + ;

: UtcTics-from-Time-today ( ss mm uu - f: UtcTics  )
   date-now UtcTics-from-Time&Date ;

f# 1e9     fconstant Nanoseconds
f# 86400e0 fconstant #SecondsToDay

: UtcTics-from-hm ( hhmmTodayUTC - ) ( f: - UtcTics )
    #100 /mod 0 -rot date-now  UtcTics-from-Time&Date ;

: #NsTill  ( hhmmTargetLocal -- ) ( F: -- NanosecondsUtc )
  UtcTics-from-hm  UtcTics-from-LocalTics @time f2dup f<
      if   fswap #SecondsToDay f+ fswap \ Next day when the time has past today
      then
   f- Nanoseconds f* ;

: time>mmhh ( - mmhh )  local-time-now time-from-utctics #100 * + nip ;

: .Html-Time-from-UtcTics (  f: UtcTics - )
    fdup f0>=
      if   bl
      else fabs [char] -
      then
    >r Time-from-UtcTics
    r> swap ##$ +html
    2 0 do  [char] : swap ##$ +html  loop ;

: .Time-from-UtcTics (  f: UtcTics - )
    fdup f0>=
      if   bl
      else fabs [char] -
      then
    >r Time-from-UtcTics
    r> swap ##$ type
    2 0 do  [char] : swap ##$ type  loop ;

: .time  ( - )  local-time-now .Time-from-UtcTics ;
: .date  ( - )  date-now  >r swap .-  .-  r> . ;

: Time&Date-from-UtcTics      ( f: UtcTics -  ss mm uu dd mm yearUtc )
   fdup Time-from-UtcTics Jd-from-UtcTics Date-from-jd ;

: Time&DateLocal-from-UtcTics ( f: UtcTics -  ss mm uu dd mm yearLocal )
   LocalTics-from-UtcTics Time&Date-from-UtcTics ;

: Time&Date ( -  ss mm uu dd mm yearLocal )
   local-time-now Time&DateLocal-from-UtcTics ;

0 value time-server$ \ Pointer to the ip address that responds to GetTcpTime

: GetTcpTime ( - ) \ Sends: my-net-id" Ask_time
   HtmlPage$ off
   my-host-id" HtmlPage$ lplace
   s"  Ask_time" HtmlPage$ +lplace
   HtmlPage$ lcount time-server$ TcpWrite  ;

variable GotTime? GotTime? off
0 value start-tic

: SetLocalTime (  UtcTics UtcOffset sunrise sunset - )
   s>f to UtcSunSet   s>f  to UtcSunRise    s>f to UtcOffset
   s>f get-secs s>f f- to #diff-tics true GotTime? ! ;

: set-time-to-0  ( - )
   #1671235201 0 0 0 SetLocalTime  true GotTime? ! cr .time space ;

: AskTime ( - )                            \ Adapt if needed!
   time-server$ 0<>
     if     gettcptime                     \ To get the UTC-time from an RPI
     else   set-time-to-0                  \ See the note.
     then ;

\ Note: set-tcptime-to-0 is used when no local time server is available.
\ When gettcptime is used the time server should respond with a tcp packet like:
\ GET 1671279235 3600 1671259560 1671287340  TcpTime HTTP/1.1
\ That packet is handled by the word TcpTime.
\ See the webserver in sps30_web.fth for an example.
\ To define a time server use:
\ s" 192.168.0.201" dup 1+ allocate drop dup to time-server$ place

: check-time ( - )
   GotTime? @ 3 >
     if    set-time-to-0
     else  GotTime? @  0>=
             if  AskTime  1 GotTime? +!
             then
     then   ;

\ Manual input:

: single? ( n$ cnt -- n ) (number?) 0= if ." Bad number" then d>s  ;

: extract-time ( hhmm[ss]$ cnt - seconds minutes hours )
   dup 6 = -rot 2>r
     if    2r@ 4 /string drop 2 single?
     else  0
     then
   2r@ 2 /string drop 2 single?
   2r> drop 2 single?
    ;

: extract-date ( ddmmyyyy$ cnt - day mnont year )
   2dup 2>r drop 2 single?
   2r@ 2 /string drop 2 single?
   2r> 4 /string drop 4 single? ;

: enter-input  ( length -- string cnt )  pad dup rot accept ;

: enter-date-time ( -- ss mm uu dd mm yearLocal flag )
   cr ."   Date ddmmyyyy: " #8 dup >r enter-input
   dup r> <>  dup 0= s>f
        if   cr ." Date needs 8 positions. Like 21092023. "
        then
   extract-date dup #1970 <
       if   fdrop false s>f cr ." Year must bigger than 1969. "
       then
   >r 2>r   ."   Time hhmm[ss]: " 6 enter-input
   dup #4 < dup 0= s>f
       if cr ." Time needs at least 4 positions. Like 1245. "
       then
   extract-time  2r> r> f>s f>s and ;

: set-time     ( - )
   base @ decimal
   enter-date-time
     if    UtcTics-from-Time&Date f>s
           0 0 0 SetLocalTime  \  UtcOffset sunrise and sunset are ignored.
           cr .date .time
     else  3drop 3drop cr ." Bad Time/date."
     then  space base ! ;
\ \s
