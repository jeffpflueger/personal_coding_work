#!usr/bin/perl -w
# use strict;

### mideast.pl is a script to check the email messages from mideastwire and webpages from LinkTV's mosiac and from them
### extract information and pack it into a database where it is then displayed by various PHP scripts.
### mideast.pl is Copyright Jeff Pflueger.


use DBI;
use Net::POP3;
use Email::MIME;
use Date::Calc qw(Decode_Date_US);
use XML::RSS::Parser;
use FileHandle;
use LWP::Simple;

## Connect to the Database
my ($dbh, $sth, @row);
$dbh = DBI -> connect('dbi:mysql:dahrjamail:localhost','mideastwire','fred12h') || die "Error opening database";
			
## Get the MideastWire
$pop3 = Net::POP3->new("dahrjamailiraq.com");
if ($pop3->login("mideast\@dahrjamailiraq.com", "Eek3Ab8g") ) {
      	my $msgnums = $pop3->list; # hashref of msgnum => size
	foreach my $msgnum (keys %$msgnums) {
      		my $return_path = "";
      		my $date = "";
      		my $subject = "";
      		my $sender_ip = "";
      		my $from = "";
      		my $header = "";
      		my $verify = "";
       	 	my $msg = $pop3->get($msgnum);
       	 	my $message;
        	foreach my $item ( @$msg ) {
        		$message .= $item;
        	}
		my $parsed = Email::MIME->new($message);
		my $decoded = $parsed->body;
	
       		if ( $message =~ /Date:(.*?2005)/ ) {
        	 $date = $1;
       		}
       		if ( $message =~ /^Return\-path:\s(<.*?>)\n/ ) {
	        $return_path = $1;
       		}
       		if ( $message =~ /Subject:\s(.*?)\n/ ) {
	        $subject = $1;
       		}
       		if ( $message =~ /Received\: from host\.cleartag\.com [\(\[]209\.239\.35\.104[\)\]]/s ) {
		$verify = "yes";
       		}
       	
       		if ( $message =~ /From:\s(.*?)\n/ ) {
	  	      $from = $1;
       		}
	
       	
		if ( 	
			( $verify eq "yes" ) and
      			( $from eq "\"Mideastwire.com\" <info\@mideastwire.com>" ) and
	       		( $subject eq "Your Daily Briefing" )
		) {
       		
     		
			while ( $decoded =~ /MIDEASTWIRE\.COM DAILY IRAQ MONITOR - (.{0,200}?\<div class="brief".*?)\<table/sg ) {
       				my $brief = $1;
       				my $entry_date;
       				my $entry_date_text;
       				### remove beginning bit and extract the date
       				if ( $brief =~ /(^.*?200[0-9])\<.{0,200}?\<div class="brief"/s ) {
       					$entry_date_text = $1;
       				}
       				
       				### convert the date to something meaningful to mySQL
       				my ($year,$month,$day);
       				if ( ($year,$month,$day) = Decode_Date_US($entry_date_text) ) {
       					$entry_date = "$year-$month-$day";
       				}
       				$brief =~ s/^.{0,200}?(\<div class="brief">)/$1/s;
			
				## Test to see if anything has been entered for the date
				$sth = $dbh -> prepare ("SELECT entry_date_text FROM mideastwire GROUP BY id;") || die "Couldn't select record : $DBI::errstr";
				$sth -> execute () || die "Couldn't execute : $DBI::errstr";;
				my $add = 'yes';
				while (@row = $sth -> fetchrow_array()){
				if ( exists ( $row[0] ) ){
					if ( "$row[0]" eq "$entry_date_text" ) {
						$add = 'no';
					}
				}
				}
				
				## add the values
			
				if ( "$add" eq 'yes' ) {
					$brief = $dbh -> quote ( "$brief");
					
					my $query = "INSERT INTO mideastwire
						( date,
						entry_date,
						entry_date_text,
						brief
						)
						VALUES
						( CURDATE(),
						'$entry_date',
						'$entry_date_text',
						$brief
						)";

					$dbh -> do ( "$query" )
					|| die "Couldn't insert - $query";
			
				
				}

       			}
       			
      
       		
     		}
      	
#       	 $pop3->delete($msgnum);
      
      }
$pop3->quit() ;

}


## Get the Mosaic RSS feed
## some important URLs
# transcripts: http://www.linktv.org/mosaic/streamsArchive/summaryPrint.php4?code=20060308S&filetype=txt
# rss:  http://www.linktv.org/cgi/database/mosaic_rss.xml
# the quicktime movie:
# fatty: http://www.archive.org/download/Mosaic20060309/Mosaic20060309_256kb.mov
# small guy: http://www.archive.org/download/Mosaic20060309/Mosaic20060309_64kb.mov

my $rss = get("http://www.linktv.org/cgi/database/mosaic_rss.xml");

#save the rss file
open RSS , ">/home/httpd/vhosts/dahrjamailiraq.com/mosaic_rss.txt" or die "Can't open file: /home/httpd/vhosts/dahrjamailiraq.com/mosaic_rss.txt to write to.";
print RSS $rss;

#parse the goodies
my $feed;
my $p = XML::RSS::Parser -> new;
# my $fh = FileHandle -> new('/home/httpd/vhosts/dahrjamailiraq.com/mosaic_rss.txt');
$feed = $p -> parse_file ('/home/httpd/vhosts/dahrjamailiraq.com/mosaic_rss.txt');

# output some values 
my $feed_title = $feed -> query('/channel/title');
print $feed_title->text_content;
exit;
print "\n\n$feed";
exit;
my $count = $feed -> item_count;

# print " ($count)\n";

foreach my $i ( $feed->query('//item') ) { 
	my $title = $i->query('title');
	print '  '.$title->text_content;
	print "\n";
	
	my $description = $i->query('description');
	print '  '.$description->text_content;
	print "\n";
	
	my $link = $i->query('link');
	print '  '.$link->text_content;
	print "\n";
	print "\n";
	
 }


exit;
