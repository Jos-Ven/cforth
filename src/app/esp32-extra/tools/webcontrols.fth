marker -webcontrols.fth  cr lastacf .name #19 to-column .( 23-02-2025 ) \ By J.v.d.Ven

\ 18-11-2024 removed "border-radius:" from table, th and td
\ 02-02-2025 Added: <hr>  <hrWH> sendstk

needs /circular    extra.fth

cell user xt-htmlpage \ MUST contain the XT that builds the web-page in the buffer at htmlpage$
                       \ ALL buttons must be evaluted before a new page is sent!

HIDDEN DEFINITIONS

4 value ./stack

0 value (depth)

: LogStackTop { adr-str -- }
   depth  0<
        if     clear s"   STK: Underflow." adr-str +place
        else   s"   STK:" adr-str +place   (depth) dup 0=
              if   drop s" Empty." adr-str +place
              else s" (" adr-str +place (.) adr-str +place s" ) " adr-str +place
                   depth ./stack min  dup 0
                   ?do  dup  i - pick (.) adr-str +place
                   s"  "  adr-str +place
                  loop drop
              then
        then ;

:  LogFStackTop  { adr-str -- }
    s"  FP:" adr-str +place
    fdepth 0<
      if    s" Underflow." adr-str +place
      else  fdepth  0=
          if    s" Empty." adr-str +place
          else  s" (" adr-str +place fdepth (.) adr-str +place s" ) " adr-str +place
                fdepth 4 min dup 0
                ?do  dup i - 1- fpick fstring adr-str +place
                     s"  " adr-str +place
                loop drop
          then
      then ;

: (SendStk) ( server# xt - )
   depth 2 - to (depth) (depth) 0<
     if    clear  ." Stack underflow. "
     else  s" \\ " LogLine$  place   ip"     LogLine$ +place
           s" :"   LogLine$ +place   >name$  LogLine$  +place
           >r  LogLine$  LogStackTop  LogLine$ LogFStackTop
           LogLine$ count r> sendtcp
     then ;


FORTH DEFINITIONS ALSO HIDDEN

: SendStk ( - )  \ For definitions in RAM
   lastacf postpone literal  postpone (SendStk) ; immediate

\ SendStk needs init-HtmlPage first. Then:
\ : test  4 5 f# 1.2  f# 1.5  f# 1.6  201 SendStk ;  test
\ If segment 192.168.0 is active then 192.168.0.201 will receive the stacks
\ like: \\ 192.168.0.232:test   STK: 4 5   FP: 1.20 1.50 1.60

PREVIOUS

0 value /recv
: .get     ( - )  req-buf  /recv  type ;
: set-page ( xt - ) xt-htmlpage ! ;

VOCABULARY TCP/IP   VOCABULARY HTML

: +a ( - ) only forth also html also tcp/ip ;

HTML DEFINITIONS

: +1html	( char -- )  sp@ 1 +html drop ;
: +crlf 	( -- )       crlf$ +html ;
: .html		( n -- )     (.) +html ;
: <html5>	( -- ) +HTML| <!DOCTYPE html>| ; \ html5
: .HtmlBl	( -- ) +HTML|  | ;
: >|            ( -- ) +HTML| >| ;
: <body>	( -- ) +HTML| <body>| ;
: </body>	( -- ) +HTML| </body>| ;
: <br>		( -- ) +HTML| <br>| ;
: <center>	( -- ) +HTML| <center>| ;
: </center>	( -- ) +HTML| </center>| ;
: <div		( attribtxt cnt -- ) +HTML| <div | +html  +html| >| ;
: </div>	( -- ) +HTML| </center>| ;
: <fieldset>	( -- ) +HTML| <fieldset>|  ;
: </fieldset>	( -- ) +HTML| </fieldset>| ;
: </font>	( -- ) +HTML| </font>| ;
: <form>	( -- ) +html| <form>| ;
: </form>	( -- ) +html| </form>| ;
: <FormAction>	( actiontxt cnt -- ) +html| <form action="| +html  [char] " +1html ;
: <h2>		( -- ) +HTML| <h2>| ;
: </h2>		( -- ) +HTML| </h2>| ;
: <h3>		( -- ) +HTML| <h3>| ;
: </h3>		( -- ) +HTML| </h3>| ;
: <h4>		( -- ) +HTML| <h4>| ;
: <head>	( -- ) +HTML| <head>|  ;
: </head>	( -- ) +HTML| </head>| ;
: </h4>		( -- ) +HTML| </h4>| ;
: <html>	( -- ) +HTML| <html>| ;
: </html>	( -- ) +HTML| </html>| ;
: <legend>	( -- ) +HTML| <legend>|  ;
: </legend>	( -- ) +HTML| </legend>| ;
: <p>		( -- ) +HTML| <p>| ;
: </p>		( -- ) +HTML| </p>| ;
: <strong>	( -- ) +HTML| <strong>| ;
: </strong>	( -- ) +HTML| </strong>| ;
: <svg>		( -- ) +HTML| <svg>| ;
: </svg>	( -- ) +HTML| </svg>| ;
: <td>		( -- ) +HTML| <td>| ;
: <tdL>		( -- ) +HTML| <td valign="center" style="text-align:left;">| ;
: <tdR>		( -- ) +HTML| <td valign="center" style="text-align:right;">| ;
: </td>		( -- ) +HTML| </td>|  ;
: <tr>		( -- ) +HTML| <tr>|   ;
: </tr>		( -- ) +HTML| </tr>|  ;
: </table>	( -- ) +HTML| </table>| ;

: .HtmlSpace	( -- ) +HTML| &nbsp;| ;
: .forth-driven	( -- ) +HTML| <em>Cforth&nbsp;driven<em>| ;

: .HtmlSpaces	( n - )
    abs dup 2 <
      if    drop .HtmlBl
      else  0
            ?do .HtmlSpace
            loop
      then ;

: ms>Html	( ms - )
    #1000 /mod #60 /mod #60 /mod #24 /mod
    .Html  bl swap ##$ +html
    [char] : swap ##$ +html
    [char] : swap ##$ +html
    drop ;

: +Hfile	( filename cnt - )              \ Adding a file to HtmlPage$
    2dup file-exist?
      if    HtmlPage$ /HtmlPage +file
      else  cr type ."  not found."
      then ;

: favicon	( - )  HtmlPage$ off  s" favicon.ico"  +Hfile ;
: SignedDouble	( n - sign dabs ) s>d tuck dabs ;
: h6#		( sign d - )      base @ >r hex  # # # # # #  r> base !  ;
: (H6.)		( n - 6hex cnt )  SignedDouble <#  h6# rot sign #>  ;
: .HtmlZeros	( n - )           0 ?do +HTML| 0| loop ;
: "."		( n - "n" cnt )   SignedDouble <# hold"bl  #s  rot sign  hold" #> ;
: ".%"		( n - "n%" cnt )  SignedDouble <# hold"bl  [char] % hold  #s  rot sign  hold" #> ;
: ".px"		( n - "npx" cnt ) SignedDouble <# [char] x hold [char] p hold #s  rot sign #> ;

: (u.r)Html	( u w -- adr cnt )
    0 swap >r (d.) r> over - 0 max .HtmlZeros  pad place pad count  ;

: 4w.intHtml	( n - )       4 (u.r)Html +html ;

: "#h."		( n - "#6hexnum"$ cnt ) \ format for a color. Eg: Blue="#0000FF"
    SignedDouble <# hold"bl h6# rot sign  [char] # hold  hold" #> ;

: (h.)		( n -- hexnum$ cnt )
    SignedDouble <#  base @ >r hex #s  r> base !  rot sign  #> ;


: <hr>        ( color size -- )
   +HTML| <hr size=|  "." +html
   +HTML| width="100%" color=| "#h." +html >| ;

: <hrWH>      ( color w h -- )
   +HTML| <hr size=|  "." +html
   +HTML| width=| "." +html   +HTML| px" color=| "#h." +html >| ;

: <FontSizeColor> ( pxSize RgbColor - )
   +HTML| <font color=| "#h." +html
   +HTML| style="font-size:| .Html +HTML| px" >| ;

: <<FontSizeColor>> ( pxSize RgbColor string cnt - )
   tmp$ place <FontSizeColor>  tmp$  count +html </font> ;

: <#td		( #HtmlCells - )
      +HTML| <td colspan= | dup "." +html
      +HTML| width=| #100 swap / 1 max ".%" +html ;  \ NOTE: No closing > here !

: <#tdC>	( n - )  <#td +HTML| align="center"> | ;
: <#tdL>    ( n - )      <#td +HTML| style="text-align:left"> | ;
: <#tdR>    ( n - )      <#td +HTML| style="text-align:right"> | ;

: NoName> ( - ) +HTML|  name="nn"> | ;

\ Default CSS button as defined in btn at header_styles

\ <Btn starts a css-button. The content of the value is used as keyword in Forth.
\ The value name 'nn' needed in the browser is ignored in Forth.
: <Btn    ( btnCmd cnt - ) +html| <button type="submit" NAME="nn" VALUE="| +html  [char] " +1html ;
: Btn>    ( btntxt cnt - ) +html  +html| </button>| ;
: <CssButton> ( btntxt cnt btnCmd cnt - )  <Btn  +html| " class="btn">|  Btn> ;

: <CssBlueButton> ( btntxt cnt btnCmd cnt - )
   <Btn +html| " class="btn" style="background-color:#A0A0FF">| Btn> ;

: <CssBlue|GrayButton> ( btntxt cnt btnCmd cnt colorflag - )
      if   <CssBlueButton>
      else <CssButton>
      then ;

: <SmallButton>   ( btntxt cnt cmd cnt - ) \ For a small CSS button
     <Btn
      +html| "  style="padding: 1px 10px; font-size: 16px";  class="btn">|
     Btn> ;

: <empty-cell>       ( - ) <td> .HtmlSpace </td> ;
: <empty-table-line> ( - ) <tr> <empty-cell> </tr> ;

: <select  ( name cnt size  - )
   +crlf -rot +HTML| <SELECT NAME="| +HTML
    +HTML| " SIZE=| "." 1- +HTML >| ;

: </select> +crlf +HTML| </SELECT>| ;

: Upc-BlankDashes ( adr cnt - )
   over dup c@ upc swap c! \ Uppercase 1st char
   s" -" BlankStrings ;    \ Remove dashes


\ : <<option>> ( text cnt index DropDownDefault - )
\ : .<<option>> ( adr cnt index chosen - )  over = <<option>> ;

: <option> ( text cnt index chosen - )
   +crlf +HTML| <OPTION |
      if  +HTML| SELECTED |
      then
    +HTML| VALUE=| "." 1- +HTML >|   +HTML  +HTML| </option> | ;


: <<option-cap>>  ( adr cnt index chosen - )
   over =
   +crlf +HTML| <OPTION |
      if  +HTML| SELECTED |
      then
    +HTML| VALUE=| "." 1- +HTML >|
    htmlpage$ lcount + over 2>r +HTML
    2r> Upc-BlankDashes
   +HTML| </option> | ;

: <<TopLink>>	( LinkAdr cnt text cnt - )
   +HTML| <a target="_top" href="|  2swap +HTML +HTML| ">|
   +HTML +HTML| </a> | ;

: #DataValues ( n scale - )
   +HTML| <div class=".data_listcontainer">|
   +HTML| <datalist id="values"> |
   swap 0 ?do  +HTML| <option value="|   dup i  * .html
          +HTML| "></option>|
   loop  drop
   +HTML| </datalist></div>| ;

: start-html-header	( -- )
  HtmlPage$ off
   s" HTTP/1.1 200"            +html_line
   s" Content-Type: text/html; charset=utf-8" +html_line
   s" Cache-Control: no-cache" +html_line
   s" Connection: close"       +html_line
   s" X-Content-Type-Options: nosniff" +html_line
   crlf$ +html  +HTML| <!DOCTYPE html><html lang="en">|
   <head>
   +HTML| <meta charset="utf-8">| ;


: Html-title-header  ( adr cnt - )
   +html| <title>|
   s" -" tmp$ lplace ip" #10 /string tmp$ +lplace
    s" - " tmp$ +lplace tmp$ +lplace  tmp$ lcount +html  +html| </title>| ;

: header-options ( - )
   +HTML| <meta name="viewport" content="width=device-width, initial-scale=1">|
   +html| <link rel="shortcut icon" href="/favicon.ico" type="image/x-icon">| ;

: header-styles ( - )
   +HTML| <style> #svgelem{ position: relative; left: 2%; } |
   s" fieldset { border:2px solid green;} svg|a:link, svg|a:visited {  cursor: pointer; } " +html
   +HTML| .btn { |             \ The properties are overwritable in the html page
     +HTML| position: relative; |
     +HTML| border: 0; |
     +HTML| padding: 5px 1px; |
     +HTML| text-align: center; |
     +HTML| border-radius: 12px;
     +HTML| font-size: 16px; |
     +HTML| width: 80px; |

     +HTML| background-color: #e7e7e7; |
     +HTML| box-shadow: 0px 1px 2px rgba(0, 0, 0, 0.5); |
     +HTML| cursor: pointer; } |

   +HTML| .btn:active { |
     +HTML| top: 2px; |
     +HTML| left: 1px; |
     +HTML| box-shadow: none; } |

   +HTML| .vertslidecontainer [type="range"][orient="vertical"] { |
     +HTML| height: 200px; |
     +HTML| width: 70px; |
     +HTML| cursor: pointer; |
     +HTML| writing-mode: bt-lr; |
     +HTML| appearance: slider-vertical; } |

   +HTML| .data_listcontainer { |
     +HTML| display: flex; |
     +HTML| flex-direction: column; } |

   +HTML| td { |
     +HTML| text-align:center; } |  ;

: end-header ( - )
   +HTML| </style> </head> | ;

: html-header  ( title cnt - )
  start-html-header  Html-title-header
  header-options header-styles end-header ;


: MsgPage  ( msg$ cnt -- )
   dup cell+ allocate drop dup >r lplace
   s" Update " html-header
   +HTML| <body>|     \ LeftTopStart
   +HTML| <br><center>|
   r@ lcount +HTML
   +HTML| <center></body> </html>|
   r> free drop ;


TCP/IP DEFINITIONS


alias get            noop
alias HTTP/1.1       noop
alias NoReply-HTTP   noop
alias nn             noop
alias order  order
alias words  words
alias reboot reboot
alias +a     +a

: \\ ( - )  .get postpone \ ;

ALSO HTML

: /favicon.ico	( - ) favicon ; \ loads favicon at htmlpage$

FORTH DEFINITIONS ALSO HTML

: trim-stack	( ...?   - )
    sp@ sp0 @ u<  cr ." Stack "
      if     .s ." TRIMMED."
      else   ." UNDERFLOW."
      then
    sp0 @ sp! cr ;

variable depth-target

: save-stack	( ...ToBeSaved - )
   s" depth-target off  begin depth while >r 1 depth-target +! repeat "
   evaluate ; immediate

: restore-stack	( - ...saved )
   s"  begin depth-target @ while  r> -1 depth-target +! repeat "
   evaluate ; immediate

: cut-line	( adrBuf lenBuf -- adr len ) 2dup $0d scan nip - ;

: .catch-error ( adr len - ) \ The line after the separators are removed.
    .date .time  ."  Order: " order  \ Words must be defined in the TCP/IP dictionary !
    cr ." ******* Request aborted! ******* " cr
    s" 404 error" html-header              \ Put the error on the html-page

    +html| <body bgcolor="#FEFFE6"><font size="4" face="Segoe UI" color="#000000" >|
           <br> <br> s" /home" s" Home"        <<TopLink>>
    +html| <br> <br> Page not found, error 404 at: | +html
    +html| </font></body></html>|  ;

: evaluate_cleaned ( adr len - res-catch )
  #255 min evaluate
  xt-htmlpage @ dup 0<>
    if    catch 0<>
            if     ." At web page: "
                   xt-htmlpage @  >name$ 2dup type cr .catch-error
            then
    else  drop
    then  ;

\ evaluating_tcp/ip looks after stack mismatches and syntax errors
: evaluating_tcp/ip { adr len -- }
     save-stack               \ Save/empty the stack here
     adr len ['] evaluate_cleaned catch 0<>
       if     adr len .catch-error 0 to len \ Show undefined words
       then
    sp@ sp0 @ <>
        if   cr adr len type trim-stack   \ The stack should be empty without trimming it
        then
    restore-stack     \ Restore the previous state
 ;

: remove_seperator ( adr len character - )
   >r begin  r@ scan dup 0<> \ Character found?
      while  bl 2 pick c!    \ Replace the involved character by a space
             1 /string       \ Retry the remainder in adr' len'
      repeat
   r> 3drop ;

: remove_seperators  ( adr len - )
  2dup [char] ? remove_seperator
  2dup [char] = remove_seperator
       [char] & remove_seperator ;

: see-request ( adrRequest lenRequest -- )
   cr bold .date .time norm
   cr ." Request: " 2dup type
   cut-line  \ Extract the line with GET
   2dup remove_seperators
   dup #128 < if cr then ."  Evaluate: " 2dup type cr
   evaluating_tcp/ip     SendHtmlPage
   ." Html-page: " xt-htmlpage @  dup 0<>
     if  .name
     else   drop ." na"
     then  cr
   20 0 do [char] - emit loop cr


xt-htmlpage off ;

: (handle-request) ( adrRequest lenRequest -- )
   cut-line  \ Extract the line with GET
   2dup remove_seperators
   evaluating_tcp/ip
   SendHtmlPage xt-htmlpage off ;

defer handle-request   ' (handle-request) is handle-request

$fff  constant SOL_SOCKET
$80   constant SO_LINGER
$1006 constant SO_RCVTIMEO
$1005 constant SO_SNDTIMEO

: SetSolOpt	( tcp-sock optval p2 p1 size - )
   >r pad 2! r> pad rot SOL_SOCKET 4 roll setsockopt drop ;

\ Set SO_LINGER so lwip-close does not discard any pending data
: linger-tcp ( handle - ) SO_LINGER 1 sp@ [ 2 cells ] literal SetSolOpt ;

: recv 		( sock -- length|-1 )
   dup >r SO_RCVTIMEO #200 1 [ 2 cells ] literal SetSolOpt
   req-buf /req-buf r> lwip-read ;


defer req-buf-in    ' noop is req-buf-in

: http-responder ( sock - )
   htmlpage$ off dup to lsock recv dup 0>
     if   req-buf-in  req-buf swap dup to /recv handle-request
     else drop
     then
   lsock lwip-close ;

PREVIOUS PREVIOUS FORTH DEFINITIONS


\ \s
