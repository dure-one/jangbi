#!/usr/bin/perl 
# ntpdate.pl

# this code will query a ntp server for the local time and display
# it.  it is intended to show how to use a NTP server as a time
# source for a simple network connected device.

# 
# For better clock management see the offical NTP info at:
# http://www.eecis.udel.edu/~ntp/
#

# written by Tim Hogard (thogard@abnormal.com)
# Thu Sep 26 13:35:41 EAST 2002
# this code is in the public domain.
# it can be found here http://www.abnormal.com/~thogard/ntp/

$HOSTNAME=shift;
$HOSTNAME="pool.ntp.org" unless $HOSTNAME ;	# our NTP server
$PORTNO=123;			# NTP is port 123
$MAXLEN=1024;			# check our buffers

use Socket;

#we use the system call to open a UDP socket
socket(SOCKET, PF_INET, SOCK_DGRAM, getprotobyname("udp")) or die "socket: $!";

#convert hostname to ipaddress if needed
$ipaddr   = inet_aton($HOSTNAME);
$portaddr = sockaddr_in($PORTNO, $ipaddr);

# build a message.  Our message is all zeros except for a one in the protocol version field
# $msg in binary is 00 001 000 00000000 ....  or in C msg[]={010,0,0,0,0,0,0,0,0,...}
#it should be a total of 48 bytes long
$MSG="\010"."\0"x47;

#send the data
send(SOCKET, $MSG, 0, $portaddr) == length($MSG)
or die "cannot send to $HOSTNAME($PORTNO): $!";
##print "sent message\n";

$portaddr = recv(SOCKET, $MSG, $MAXLEN, 0)      or die "recv: $!";
##print "got msg\n";
##($portno, $ipaddr) = sockaddr_in($portaddr);
##$host = gethostbyaddr($ipaddr, AF_INET);
##print "$host($portno) said $MSG\n";
##print "$host($portno) said something \n";

#We get 12 long words back in Network order
@l=unpack("N12",$MSG);


##foreach(@l) {
##printf("%08x ",$_);
##print "\n" if($x++%4==3);
##}

#The high word of transmit time is the 10th word we get back
#tmit is the time in seconds not accounting for network delays which should be
#way less than a second if this is a local NTP server
$tmit=$l[10];	# get transmit time
##print "tmit=$tmit\n";

#convert time to unix standard time
#NTP is number of seconds since 0000 UT on 1 January 1900
#unix time is seconds since 0000 UT on 1 January 1970
#There has been a trend to add a 2 leap seconds every 3 years.  Leap
#seconds are only an issue the last second of the month in June and
#December if you don't try to set the clock then it can be ignored but
#this is importaint to people who coordinate times with GPS clock
#sources.

$tmit-= 2208988800;	

#printf("%d\n", $tmit);
#use unix library function to show me the local time (it takes care of
#timezone issues for both north and south of the equator and places that
#do Summer time/ Daylight savings time.

print scalar localtime ($tmit);
print "\n";

#compare to system time
##$t=time();
##print " $t  $tmit ",$t-$tmit,"\n";
