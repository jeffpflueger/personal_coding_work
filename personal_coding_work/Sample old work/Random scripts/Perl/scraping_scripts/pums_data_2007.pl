#!usr/bin/perl -w
# use strict;

# script to download all of the 2005, 2006 population/housing and year data

use FileHandle;
use LWP::Simple;
use Archive::Extract;


## get the .zip file for each state
my @states = (
"AL",
"AK",
"AZ",
"AR",
"CA",
"CO",
"CT",
"DE",
"DC",
"FL",
"GA",
"GU",
"HI",
"ID",
"IL",
"IN",
"IA",
"KS",
"KY",
"LA",
"ME",
"MH",
"MD",
"MA",
"MI",
"MN",
"MS",
"MO",
"MT",
"NE",
"NV",
"NH",
"NJ",
"NM",
"NY",
"NC",
"ND",
"MP",
"OH",
"OK",
"OR",
"PW",
"PA",
"PR",
"RI",
"SC",
"SD",
"TN",
"TX",
"UT",
"VT",
"VI",
"VA",
"WA",
"WV",
"WI",
"WY"
);
my @years = ( "2007" );
my @data = ( "p", "h" );
mkdir ("c:/pums/2007/" , 0777) || warn "Cannot mkdir c:/pums/2005 $!\n";
mkdir ("c:/pums/2007/zipped/" , 0777) || warn "Cannot mkdir c:/pums/2006/zipped $!\n";
mkdir ("c:/pums/2007/unzipped/" , 0777) || warn "Cannot mkdir c:/pums/2006/unzipped $!\n";

foreach my $state ( @states ) {
	print "$state\n";
	#iterate for the years
	foreach my $year ( @years ) {
		foreach my $data ( @data ) {
			print "\t$year - $data\n";
	
			$state = lc ($state);
			# old filenaming convention: http://www2.census.gov/acs/downloads/pums/2006/" + format + "_" + type + state + ".zip
			# new filenaming convention: http://www2.census.gov/acs2007_1yr/pums/
			# http://www2.census.gov/acs/downloads/pums/2006/csv_pus.zip
			my $filename = "csv_" . $data . $state . ".zip";
			my $url = "http://www2.census.gov/acs2007_1yr/pums/" . $filename;
			print "\tLoading: $url \n";
			my $file = get("$url");
			if ( !defined $file ) {
				warn "Couldn't get $url \n ";
				next;
			}
	
			#save the file
	
			my $zip_save_path = "c:/pums/" . $year . "/zipped/";
			my $unzip_save_path = "c:/pums/" . $year . "/unzipped/";
			my $zip_file = $zip_save_path . $filename;
	
			print "\tSaving: $zip_file \n";
			open INDEX_PAGE , ">$zip_file" or die "Can't open file: $zip_file to write to. $!";
			binmode(INDEX_PAGE);      # The filehandle is now binary
			print INDEX_PAGE $file;
			close (INDEX_PAGE);
	
			#unzip the file
			print "\tUnzipping to: $unzip_save_path \n\n";
			my $ae = Archive::Extract->new( archive => "$zip_file" );
			### extract to /tmp ###
			my $ok = $ae->extract( to => "$unzip_save_path" ) or warn $ae->error;

		}
	}
}
	



exit;
