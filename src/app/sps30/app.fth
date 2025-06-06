\ Load file for application-specific Forth extensions

fl ../../lib/misc.fth
fl ../../lib/dl.fth
fl ../../lib/random.fth
fl ../../lib/ilog2.fth
fl ../../lib/tek.fth

warning @ warning off
: bye standalone?  if  restart  then  bye  ;
warning !

: .commit  ( -- )  'version cscount type  ;

: .built  ( -- )  'build-date cscount type  ;

: banner  ( -- )
   cr ." CForth built " .built
   ."  from " .commit
   cr
;

\ m-emit is defined in textend.c
alias m-key  key
alias m-init noop

: m-avail?  ( -- false | char true )
   key?  if  key true exit  then
   false
;

: ms>ticks  ( ms -- ticks )
   esp-clk-cpu-freq  case
      #240000000 of  exit  endof
      #80000000  of        endof
      drop #1 lshift dup
   endcase
   #3 /
;

: system-time>f ( us seconds -- ) ( f: -- us )
   s" s>d d>f f# 1.0e6 f*  s>d d>f  f+ "  evaluate
; immediate

: usf@ ( f: -- us )
   s" 0. sp@ get-system-time! system-time>f" evaluate  ; immediate

: ms@  ( -- ms ) f# 1.0e-3 usf@ f* f>d d>s  ;

alias get-msecs ms@

: fus  ( f: us - )
   usf@  f+  begin
      fdup  usf@  f- f# 1.0e8 f>
   while   #100000000 us
   repeat
   usf@  f- f>d d>s abs us
;

: ms   ( ms -- )   s>d d>f f# 1.0e3 f* fus ;

fl wifi.fth

fl ../esp8266/xmifce.fth
fl ../../lib/crc16.fth
fl ../../lib/xmodem.fth
also modem
: rx  ( -- )  pad  unused pad here - -  (receive)  #100 ms  ;
previous

fl files.fth
fl server.fth
fl tasking_rtos.fth        \ Preemptive multitasking

fl tools/extra.fth
fl tools/table_sort.fth
fl tools/timezones.fth
fl tools/timediff.fth      \ Time calculations
fl tools/webcontrols.fth   \ Extra tags in ROM
fl tools/svg_plotter.fth
fl tools/rcvfile.fth
fl tools/wsping.fth
fl tools/schedule-tool.fth \ Daily schedule
fl ../sps30/sps30.fth      \ For sps30_web.fth


: interrupt?  ( -- flag )
   ." Type a key within 2 seconds to interact" cr
   #20 0  do  #100 ms  key?  if  key drop  true unloop exit  then   loop
   false
;

: load-startup-file  ( -- ior )   " start" ['] included catch   ;

: app ( - ) \ Sometimes SPIFFS or a wifi connection causes an error. A reboot solves that.
   banner  hex  interrupt? 0=  if
      s" start" file-exist?  if
         load-startup-file  if
            ." Reading SPIFFS. " cr interrupt? 0=  if
               reboot
            then
         then
      then
   then
   quit
;

cr  bold .( ******* App: sps30 ******* )  norm cr cr
alias id: \

" app.dic" save
