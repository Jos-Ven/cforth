To see the air quality in a web browser

For: ~/cforth/src/app/esp32-extra
Needed hardware: A SPS30 and an esp32
The SPS30 should be connected to an extra UART on the ESP32. See sps30.fth

$ git clone https://github.com/MitchBradley/cforth
  Backup your: ~/cforth/src/app/esp32-extra/app.fth
  Copy ~/cforth/src/app/sps30/app.fth   to   ~/cforth/src/app/esp32-extra
$ cd ~/cforth/build/esp32-extra  
$ rm *.*
$ make flash

Upload ../src/app/ntc-web/favicon.ico AND sps30_web.fth to the file system of the ESP32.

Only when you use https://github.com/Jos-Ven/A-smart-home-in-Forth :
  Edit and upload MachineSettings.fth to the file system of the ESP32 IF you are able to 
  handle TcpTime packets. See: ~/cforth/src/app/esp32-extra/tools/timediff.fth
  Disable servers you do not have.

Reboot the ESP32 and compile sps30_web.fth
To auto-run the application hit escape and enter on the Esp32:
s" fl sps30_web.fth" s" start" file-it
Reboot the esp32

When a schedule is used it executes the entry of the current time.

When there is no WiFi connection then the programm puts the esp32 into 
a deep sleep for 30 minutes.
Unless you disable the lines with SleepIfNotConnected in sps30_web.fth


