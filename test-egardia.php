<?php
/*
<! File                 : woonveilig-service.php                            >
<! Project              : Woonveilig                                        >
<! Created by           : Bjorn van den Brule                               >
<! Website              : www.brule.nl                                      >
<! Copyright            : Van den Brule Consultancy 2015                    >
<! Date                 : 17-05-2015                                        >
<! Supporting documents : PHP 5.x                                           >
<! Licentie             : GPL                                               >
<! Description          : This file contains the main entry                 >
<!                                                                          >
<!                                                                          >
<! Edit history                                                             >
<!                                                                          >
<! No           Date            Comments                                by  >
<! -----        --------        ----------------------------------      --- >
<! V1.00        17/05/15        Created, HELLO world !!!!!              abb >
*/



$dd = date('d-m-Y H:m:s');
echo "Woonveilig service, see syslog for messages.\n";

/* Constants */
define("C_ARMED", "Armed");
define("C_DISARMED", "Disarmed");
define("C_HOME", "Home");
define("C_ON", 1);
define("C_OFF", 0);

/* mail setting */
$to = "enrico.roga@adnet-solutions.de";         /* send alarm email to */
$from = "alarm@adnet-solutions.de";        /* email from *?

/* report server settings */
$port = 5085;
$addr = "localhost";

/* vars */
$last_event = 0;
$event = 1; 
$system = C_DISARMED;
$alarm = C_OFF;
$cnt_twenty = 0;
$new_event = false;

/* Syslog init */
/* Tip: tail -f /var/log/syslog | grep Woonveilig */
openlog("Woonveilig", LOG_PID | LOG_PERROR, LOG_LOCAL0);

/* listen on port */
$sock = socket_create_listen($port, 128);
socket_getsockname($sock, $addr, $port);
syslog(LOG_INFO, "Server listening on $addr:$port");

/* main loop */
  while($c = socket_accept($sock)) 
  {
    /* wait for woonveilig system */
    socket_getpeername($c, $raddr, $rport);
    if ($cnt_twenty == 0)
    {
      syslog(LOG_INFO, "Received connection from $raddr:$rport"); 
    }
    // read buffer  
    $buf = socket_read($c, 4192, PHP_BINARY_READ); 

    if (false === $buf)
    {
      $err =  socket_strerror(socket_last_error($c));
      syslog(LOG_WARNING, "socket_read() failed: reason: $err");
    }  // fi
    else 
    {
      /* The Woonveilig alarm system gives 20 times the following message [0258BF 1834010003408A0] */
      /* where 0258BF is the number from the Woonveilig system */
      /* where 1834010003408A0 is a event code from a configured alarm device */

      $d = date("Y-m-d H:i:s");
      $rec_event = explode (" ", urldecode($buf));
      socket_write($c, "[OK]\n", 6);
      $event = str_replace("]", "", $rec_event[1]);

      $cnt_twenty++; 
      if ($event == $last_event)
      {
        if ($cnt_twenty == 20) // 20 times still the same value 
        {
          $cnt_twenty = 0;
          $new_event = true;
          $last_event = 0;
        }
      }
      else
      {
        $last_event = $event;
      }
    } // esle

    /* Ok 20 time the same value is received */
    /* then handle event */
    if ($new_event == true)
    {
      $new_event = false; // reset event
      switch ($event) 
      {
        case "18340000003FB9B" : $e = "Remote Control van User 1 : Alarm aan"; $system = C_ARMED; break;
        case "18140000003E999" : $e = "Remote Control van User 1 : Alarm uit"; $system = C_DISARMED; break;
        case "18340000007FF9F" : $e = "Remote Control van User 2 : Alarm aan"; $system = C_ARMED; break;
        case "18140000007ED9D" : $e = "Remote Control van User 2 : Alarm uit"; $system = C_DISARMED; break;
        case "1834010003408A0" : $e = "Webpaneel : Alarm aan"; $system = C_ARMED; break;
        case "18140100034F69E" : $e = "Webpaneel : Alarm uit"; $system = C_DISARMED; break;
        case "1834560003449AA" : $e = "Webpaneel : Alarm home"; $system = C_HOME; break;
        case "18160200000029A" : $e = "Alarm systeem in rust : $system "; break;
        case "1834070000123A0" : $e = "Keypad : Alarm aan"; $system = C_ARMED; break;
        case "18140700001119E" : $e = "Keypad : Alarm uit"; $system = C_DISARMED; break;
        case "18113100001EA98" : $e = "Alarm voordeur na delay"; $alarm = C_ON; break;
        case "181139000011AA0" : $e = "Alarm voordeur"; $alarm = C_ON; break;
        case "18113000001E497" : $e = "Alarm voordeur"; $alarm = C_ON; break;
        case "181139000051EA4" : $e = "Alarm raan"; $alarm = C_ON; break;
        case "18113000005E89B" : $e = "Alarm achterdeur"; $alarm = C_ON; break;
        case "181139000041DA3" : $e = "Alarm raam 1 hoog "; $alarm = C_ON;  break;
        case "18113000004E79A" : $e = "Alarm sensor berging 1"; $alarm = C_ON;  break;
        case "181139000041DA3" : $e = "Alarm sensor berging 2"; $alarm = C_ON; break;
        case "181139000061FA5" : $e = "Alarm sensor dakraam"; $alarm = C_ON;  break;
        case "18113000006E99C" : $e = "Alarm sensor dakraam"; $alarm = C_ON;  break;
        default:
           $e =  "unbekanntes event : $event"; 
      } // switch

      syslog(LOG_INFO, "[Event] [$e] ist aufgetreten"); 
      if ($alarm == C_ON)
      {
        // mail($to, "[Alarm opgetreden]", " [$d] [$e] is opgetreden\n", "From:$from" );
        $alarm = C_OFF;
        $system = C_ARMED;
      } // fi alarm
      else
      {
        if ($event != "18160200000029A")  // de rust melding is niet nodig die verschijnt om het halve uur
        {
          // mail($to, "[Event opgetreden]", " [$d] [$e] is opgetreden\n", "From:$from" );
          $e =  ""; 
        }
      } // else alarm
    } // fi new_event 
  } // while
  socket_close($sock);
  closelog();
?> 

