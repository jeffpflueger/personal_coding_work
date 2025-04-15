#!/usr/bin/perl
use warnings;
use strict;
use DBI;
use CGI;
use LWP::Simple;

my $url = "http://www.aaaa.org/EWEB/DynamicPage.aspx?Site=4A_new&WebKey=d9c95573-dbb2-46fd-a8d2-f508994f42d9&adr_state=-All-&cst_org_name_dn=&cst_member_flag=&action=add&redirect=no&FromSearchControl=Yes";
my $base_url = "http://www.aaaa.org/EWEB/";
my $suburl;
my $page = get("$url");

if (!defined $page )
{
    #If an error occurs then $vocational_rehab will not be defined.
    print "Error: Get failed. Couldn't access: $url";
    exit;
}

### Extract the data
my @array = split /\n/, $page;
my @sub_pages_array;
### grab everything after the <div align=center> and make it a value in an array
foreach my $line ( @array ) {
	if ( $line =~ /\<TD valign=top nowrap\>\<p\>\<A href="(.*?)"\>/ ) {
	        $suburl = $1;
	       	push @sub_pages_array, $suburl;
	}

}

my $subpage;
my $subpageurl;
my $title;
my $website;
my $address_1;
my $address_2;
my $city_state;
my @city_state;
my $city;
my $state;
my $zip;
my $phone;
my $fax;

my $count;

### get the csv file ready

my $file = "aaaa_list.csv";
my $file_text;
unlink ( $file );
open FILE , ">$file" or die "Can't open file: $file to write to. $!";
$file_text .= "\"agency\",\"address_1\",\"address_2\",\"city\",\"state\",\"zip\",\"phone\",\"fax\",\"website\"\n";

foreach my $item ( @sub_pages_array ) {
	$count = $count + 1;
	# if ( $count > 100 ) {
	#	last;
	# }
	print "$count of " . @sub_pages_array . "\n";
	$subpageurl = $base_url . $item;
	## replace the &amp with &
	$subpageurl =~ s/&amp;/&/g;

	$subpage = get("$subpageurl");
	if (!defined $subpage )
	{
	    #If an error occurs then $vocational_rehab will not be defined.
	    print "Error: Get failed. Couldn't access: $subpageurl";
	}

	# print "$subpage";
	print "$subpageurl\n";

	## company title ##
	if ( $subpage =~ /\<TD class=text_m\>\<BR\>\<STRONG\>(.*?)\<\/STRONG\>\<BR\>\<BR\>\<\/TD\>\<\/TR\>/ ) {
		        $title = $1;
		        print "$title\n";
	}
	## website
	if ( $subpage =~ /\<P\>\<A href="(.*?)"\>http/ ) {
			$website = $1;;
			print "$website\n";
	}
	
	## address1
	if ( $subpage =~ /\<P\>([^\<]*?)\<\/P\>\<\/TD\>\<\/TR\>/ ) {
			$address_1 = $1;
			print "$address_1\n";
	}
	
	## address2
	$address_2 = "";
	if ( $subpage =~ /\<P\>([^\<]*?)\<\/P\>\<\/TD\>\<\/TR\>[\s\r\n]*?\<SCRIPT\>/ ) {
			$address_2 = $1;
			print "$address_2\n";
	}
	
	## city, state
	if ( $subpage =~ /if\(space\("(.*?)"\)\) document\.write\(', '\);/ ) {
			$city_state = $1;
			$city_state =~ s/\"//g;
			@city_state = split (/,/,$city_state);
			$state = pop (@city_state);
			$city = pop (@city_state);
			print "$city" . ", " . "$state\n";
	}
	
	## zip
		if ( $subpage =~ /if\(not_empty\("([0-9\-]*?)"\)/ ) {
				$zip = $1;
				$zip =~ s/\"//;
				print "$zip\n";
	}
	
	## phone
	if ( $subpage =~ /Phone:\<\/STRONG\> (.*?)\<\/P\>/ ) {
			$phone = $1;
			print "$phone\n";
	}
	## fax
	if ( $subpage =~ /Fax: \<\/STRONG\>(.*?)\<\/P\>/ ) {
			$fax = $1;
			print "$fax\n";
	}
	print "\n\n";
	$file_text .= "\"$title\",\"$address_1\",\"$address_2\",\"$city\",\"$state\",\"$zip\",\"$phone\",\"$fax\",\"$website\"\n"; 
	
	


}

print FILE $file_text;

		

close (FILE);

