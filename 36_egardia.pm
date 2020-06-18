###############################################################################
#
# A module to receive egardia events 
#
# written 2020 by Enrico Roga / based on module 36_ekey from Matthias Kleine
#
###############################################################################

package main;

use strict;
use warnings; 
use IO::Socket;

#my %selectlist; #to make my compiler happy / that need to go later to atributes
my $EVENTNAMES = {
	"18340000003FB9B" => "Remote Control van User 1 : Alarm aan",
	"18140000003E999" => "Remote Control van User 1 : Alarm uit",
	"18340000007FF9F" => "Remote Control van User 2 : Alarm aan",
	"18140000007ED9D" => "Remote Control van User 2 : Alarm uit",
	"1834010003408A0" => "Webpaneel : Alarm aan",
	"18140100034F69E" => "Webpaneel : Alarm uit",
	"1834560003449AA" => "Webpaneel : Alarm home",
	"18160200000029A" => "Alarm systeem in rust : xxx ",
	"1834070000123A0" => "Keypad : Alarm aan",
	"18140700001119E" => "Keypad : Alarm uit",
	"18113100001EA98" => "Alarm voordeur na delay",
	"181139000011AA0" => "Alarm voordeur",
	"18113000001E497" => "Alarm voordeur",
	"181139000051EA4" => "Alarm raan",
	"18113000005E89B" => "Alarm achterdeur",
	"181139000041DA3" => "Alarm raam 1 hoog ",
	"18113000004E79A" => "Alarm sensor berging 1",
	"181139000041DA3" => "Alarm sensor berging 2",
	"181139000061FA5" => "Alarm sensor dakraam",
	"18113000006E99C" => "Alarm sensor dakraam",
	"18160200000029A" => "de rust melding is niet nodig die verschijnt om het halve uur",
};

sub egardia_Initialize($)
{
	my ($hash) = @_;

	$hash->{DefFn} = "egardia_Define";
	$hash->{UndefFn} = "egardia_Undefine";
	$hash->{ReadFn}  = "egardia_Read";
        $hash->{AttrList} = "egardiaType:GATE01,GATE02 " . $readingFnAttributes;
}

sub egardia_Define($$)
{
	my ($hash, $def) = @_;
	my @args = split("[ \t]+", $def);
	return "Invalid number of arguments: define <name> egardia <port> " if (scalar(@args) < 1);

	my ($name, $type, $port, undef) = @args;
	return undef unless (defined($port));
	return "'\Q$port\E' is invalid (1024 - 65535)" if (($port !~ /^\d+$/) || ($port < 1024) || ($port > 65535));

	my $conn = IO::Socket::INET->new(Proto => 'tcp', LocalPort => $port, ReuseAddr => 1, Listen => 1) or return 'Unable to open connection';
	Log3($name, 2, 'egardia_Define: Opened tcp connection on port ' . $port);

	$hash->{PORT} = $port;
	$hash->{FD} = $conn->fileno();
	$hash->{CONN} = $conn;
	$hash->{OLDEVENTID} = 0;
	$hash->{DUPCOUNTER} = 0;
	$selectlist{$name} = $hash;
        return undef;
}

sub egardia_Undefine($$)
{
	my ($hash, $name) = @_;

	$hash->{CONN}->close();

	return undef;
}

sub egardia_Read($)
{

	my ($hash) = @_;
	my $name = $hash->{NAME};
	my $urldecode = sub { my $str = shift; $str =~ s!\%([A-F0-9]{2})!pack('C',hex($1))!eisg;return($str) };
	my ($buf,$event,$client);
	my $updateNeeded = 0;

	$client = gethostbyaddr($hash->{CONN}->peeraddr(), AF_INET); $client = $hash->{CONN}->peerhost() unless($client);
	$hash->{CONN}->recv($buf, 4192);
	$hash->{CONN}->send("[OK]\n");
	return unless (length($buf));

	(undef,$event) = split(" ",$urldecode->($buf));
	$event =~ s!\]!!g;
	

	Log3($name, 5, "egardia_Read: client=$client,event=$event,buf=" . $buf);
	
	##dont know whether I should do this inside the if statement,
	# but the php code did it outside, so it actually count every event
	# and not only duplicates
	$hash->{DUPCOUNTER}++;
	if($event == $hash->{OLDEVENTID}) {
		if ($hash->{DUPCOUNTER} == 20) {
			$hash->{DUPCOUNTER} = 0;
			$hash->{OLDEVENTID} = 0;
			$updateNeeded = 1;
		}
	} else {
		$updateNeeded = 1;
		$hash->{OLDEVENTID} = $event;
	}
	return unless($updateNeeded);
	readingsBeginUpdate($hash);
	readingsBulkUpdate($hash, "raw", $buf);
	readingsBulkUpdate($hash, "client", $client);
	readingsBulkUpdate($hash, "eventid", $event);
	readingsBulkUpdate($hash, "eventname", $EVENTNAMES->{$event}) if($EVENTNAMES->{$event});
	readingsEndUpdate($hash, 1);
}

1;

=pod
=item device
=item summary egardia TCP receiver

=begin html
<a name="egardia"></a>
<h3>egardia</h3>
<ul>
  This module allows to receive egardia tcp events sent by the hijacked egardia GATE-01<br>
  <br>
  <br>
  <a name="egardiaDefine"></a>
  <b>Define</b>
  <ul>
    <code>define &lt;name&gt; egardia &lt;port&gt; </code><br>
    <br>
    port is required. Possible value range: 1024 to 65535<br>
    <br>
    Examples:
    <ul>
      <code>define myegardia egardia</code>
    </ul>
  </ul>
  <br>
  <a name="egardiaSet"></a>
  <b>Set</b>
  <ul>
    <li>N/A</li>
  </ul>
  <br>
  <a name="egardiaGet"></a>
  <b>Get</b>
  <ul>
    <li>N/A</li>
  </ul>
  <br>
  <a name="egardiaAttr"></a>
  <b>Attributes</b>
  <ul>
    <li>
        <a name="egardiaType"></a><code>egardiaType</code><br>
        Set the type of the used control unit - GATE-01
    </li>
  </ul>
  <br>
  <a name="egardiaEvents"></a>
  <b>Generated events:</b>
  <ul>
     <li>N/A</li>
  </ul>
</ul>
=end html

=cut
