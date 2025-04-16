#!/usr/bin/perl
use warnings;
use strict;
use DBI;
use CGI;
use LWP::Simple;
#Store the output of the web page (html and all) in content
## Two URLS we are interested in:
## http://www.ssa.gov/work/Ticket/ticket_info.html
## and
## http://www.ssa.gov/work/ServiceProviders/StateTicketTracker.html
my $page = get("http://www.ssa.gov/work/ServiceProviders/StateTicketTracker.html");
my $employment_networks = get("http://www.ssa.gov/work/Ticket/ticket_info.html"); 
if (!defined $vocational_rehab)
{
    #If an error occurs then $vocational_rehab will not be defined.
    print "Error: Get failed. Couldn't access: http://www.ssa.gov/work/ServiceProviders/StateTicketTracker.html";
    exit;
}
if (!defined $employment_networks)
{
    #If an error occurs then $vocational_rehab will not be defined.
    print "Error: Get failed. Couldn't access: http://www.ssa.gov/work/Ticket/ticket_info.html";
    exit;
}
### extract the date ###

$vocational_rehab =~ /Updated ([\w]+\s[\d]+,\s[\d]+)</;
my $vocational_rehab_date = $1;
$employment_networks =~ /Updated ([\w]+\s[\d]+,\s[\d]+)</;
my $employment_networks_date = $1;

### Extract the voc data
my @array;
### grab everything after the <div align=center> and make it a value in an array
@array = split ( "<div align=\"center\">", $vocational_rehab );

my @vocational_rehab_array;
my $store = 0;
foreach my $element ( @array ) {
	## foreach value erase everything </div> and beyond leaving just the value
	$element =~ s/<\/div>(.|\s)*//;
	
	## Get rid of the <b> and </b> too
	$element =~ s/<b>//;
	$element =~ s/<\/b>//;
	
	## Get rid of all values in the array up to the first in the table: AK
	
	if ( $element eq 'AK' ) {
		$store = 1;
	}
	if ( $store == 1 ) {
		push @vocational_rehab_array, $element;
	}
	
 }

### Extract the net data
### grab everything after the <div align=center> and make it a value in an array
my @array_2 = split ( "<div align=\"center\">", $employment_networks );
$store = 0;
my @employment_networks_array;
foreach my $element ( @array_2 ) {
	## foreach value erase everything </div> and beyond leaving just the value
	$element =~ s/<\/div>(.|\s)*//;
	
	## Get rid of the <b> and </b> too
	$element =~ s/<b>//;
	$element =~ s/<\/b>//;
	
	## Get rid of all values in the array up to the first in the table: AK
	
	if ( $element eq 'AK' ) {
		$store = 1;
	}
	if ( $store eq 1 ) {
		push @employment_networks_array, $element;
	}
	
 }


## Connect to the Database
my ($dbh, $sth, @row);
$dbh = DBI -> connect('dbi:mysql:pascen:pascenter.org:3306','pascen','wvaav+ha') || die "Error opening database";

## Test to see if anything has been entered for the date
$sth = $dbh -> prepare ("SELECT max(id), date_voc FROM ticket_to_work GROUP BY id;") || die "Couldn't select record : $DBI::errstr";
$sth -> execute () || die "Couldn't execute : $DBI::errstr";;
my $voc_rehab_add = 'yes';
while (@row = $sth -> fetchrow_array()){
	if ( "$row[1]" eq "$vocational_rehab_date" ) {
		$voc_rehab_add = 'no';
	}
}

## add the values
my $i = 0;
if ( "$voc_rehab_add" eq 'yes' ) {
	print "Values added to the database.";
	foreach ( @vocational_rehab_array ) {
	
	if ( $i >= @employment_networks_array ) {
				next;
		}
		my $state_voc = $vocational_rehab_array[$i];
		my $state_net = $employment_networks_array[$i];
		my $tickets_issued = $vocational_rehab_array[$i+1];
		my $employment_networks_awards_cumulative = $employment_networks_array[$i+2];
		my $ticket_assignments_to_employment_networks = $employment_networks_array[$i+3];
		my $state_vocational_rehabilitation_agencies = $vocational_rehab_array[$i+2];
		my $ticket_assignments_to_vocational_rehabilitation_agencies = $vocational_rehab_array[$i+3];
		
		$dbh -> do ("INSERT INTO ticket_to_work ( date_net,
						date_voc,
						date_added,
						state_net,
						state_voc,
						tickets_issued,
						employment_networks_awards_cumulative,
						ticket_assignments_to_employment_networks,
						state_vocational_rehabilitation_agencies,
						ticket_assignments_to_vocational_rehabilitation_agencies
						)
						VALUES
						('$employment_networks_date',
						'$vocational_rehab_date',
						CURDATE(),
						'$state_net',
						'$state_voc',
						'$tickets_issued',
						'$employment_networks_awards_cumulative',
						'$ticket_assignments_to_employment_networks',
						'$state_vocational_rehabilitation_agencies',
						'$ticket_assignments_to_vocational_rehabilitation_agencies'
						);")
						|| die "Couldn't insert record";

	$i = $i + 4;
	}
}