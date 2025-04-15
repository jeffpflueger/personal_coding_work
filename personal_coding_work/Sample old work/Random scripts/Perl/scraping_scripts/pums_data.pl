#!usr/bin/perl -w
# use strict;



use FileHandle;
use LWP::Simple;
use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
my $zip = Archive::Zip->new();


## get the .zip file for each state
my @states = (
"AL",
"AK",
"AS",
"AZ",
"AR",
"CA",
"CO",
"CT",
"DE",
"DC",
"FM",
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
mkdir ("c:/pums" , 0777) || warn "Cannot mkdir $html_path $!\n";
mkdir ("c:/pums/zipped" , 0777) || warn "Cannot mkdir $html_path $!\n";
mkdir ("c:/pums/unzipped" , 0777) || warn "Cannot mkdir $html_path $!\n";
foreach my $state ( $states ) {
	# filenaming convention: http://www2.census.gov/acs/downloads/pums/2006/" + format + "_" + type + state + ".zip
	my $filename = "ss06p" . $state . ".zip";
	my $url = "http://www2.census.gov/acs/downloads/pums/2006/" . $filename;
	print "Loading: $url \n";
	my $file = get("$url");
	warn "Couldn't get $url \n " unless defined $file;
	
	#save the file
	
	my $zip_save_path = "c:/pums/zipped";
	my $unzip_save_path = "c:/pums/unzipped";
	my $zip_file = $zip_save_path . $filename;
	my $unzip_file = $unzip_save_path . $filename;
	
	print "Saving: $zip_file \n";
	open INDEX_PAGE , ">$zip_file" or die "Can't open file: $filename to write to. $!";
	print INDEX_PAGE $file;
	close (INDEX_PAGE);
	
	#unzip the file
	print "Unzipping: $zip_file \n";
	my $zip = Archive::Zip->new();
	   unless ( $zip->read( $zip_file ) == AZ_OK ) {
	       die 'read error';
   	}
   	#save the zip file
   	print "Saving Unzipped File: $unzip_file \n";
   	open INDEX_PAGE , ">$unzip_file" or die "Can't open file: $filename to write to. $!";
	print INDEX_PAGE $file;
	close (INDEX_PAGE);
}
	



exit;
