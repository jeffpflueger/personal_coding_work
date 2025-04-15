#!/usr/bin/perl
use strict;
use CGI;
use DBI;
use Mysql;
use Fcntl qw( :DEFAULT :flock );
use Image::ExifTool;
use Image::Magick;
use File::Find;
use File::Copy::Recursive qw(fcopy rcopy dircopy fmove rmove dirmove);
use File::Copy;
use Getopt::Long;
use Geo::Coordinates::DecimalDegrees;
use Template;
use LWP::Simple;

my $redo_all = undef;
GetOptions ( redo_all => \$redo_all );


##start timer
my $start_time = time();

my ($db_name, $db_user, $db_password );
open_db("dameasy_photomountains", "photomountains", "67passtang" ) || die "Error opening database: $DBI::errstr\n";
	 	
my $change; # registers when something has changed in the ftp_directory, so we know to change the html

## Configuration variables - end all directories with /

## absoute path to user account on server
my $absolute = "/home/photomountains/";
## public html directory within the user account
my $public_html = "public_html/";
## directory within the public html directory where dameasy will put all processed images and pages
my $dameasy_dir = "dameasy/";
## directory within the dameasy directory for the images
my $dameasy_image_dir = "photos/";
## directory within the dameasy directory for the pages
my $dameasy_page_dir = "pages/";
## directory within the dameasy directory for the templates
my $dameasy_template_dir = "templates/";

## absolute path to the ftp directory that DAMeasy will be checking for new and deleted master images
my $ftp_path = $absolute . "de_master_images/";

## absolute path to the directory within your webdirectory where the processed images and pages will reside
my $dameasy_path = $absolute . $public_html . $dameasy_dir;

## absolute path to the directory within your webdirectory where the dameasy pages will reside
my $html_path = $dameasy_path . $dameasy_page_dir;

## path for processed images
my $image_path = $dameasy_path . $dameasy_image_dir;

	## relative path for html page of image
	my $image_doc_path = "/" . $dameasy_dir . $dameasy_image_dir;
	my $html_doc_path = "/" . $dameasy_dir . $dameasy_page_dir;
	
	my $keyword_doc_path = $dameasy_dir . "images_keywords/";
	my $html_keywords_path = $dameasy_path . "images_keywords/";


## template file paths
# my $keyword_template_path = $dameasy_path . $dameasy_template_dir . "keyword_template.html";
my $flash_xml_template_path = $dameasy_path . $dameasy_template_dir . 'images.php';
my $swf_template_path = $dameasy_path . $dameasy_template_dir . 'flash.swf';
# my $preview_template_path = $dameasy_path . $dameasy_template_dir . 'preview_template.html';
# my $index_template_path = $dameasy_path . $dameasy_template_dir . 'index_template.html';
my $flash_template_path = $dameasy_path . $dameasy_template_dir . 'flash_template.html';
my $rss_keyword_path = '/' . $dameasy_dir . $dameasy_template_dir . 'rss_keyword.rss';

# template URL paths
my $domain = "http://photomountains.com";
my $preview_template_path = $domain . "/content/dameasy_preview_template";
my $index_template_path = $domain . "/content/alaska-range-photo-collection";
my $keyword_template_path = $domain . "/content/photo-mountains-keyword-search";

## copyright symbol paths
my $copyright_path =  $dameasy_path . "copyright.png";
my $copyright_big_path = $dameasy_path . "copyright_big.png";




my $rss_folder_path = '/' . $dameasy_dir . $dameasy_template_dir . 'rss_folder.rss';
my $profile_path = '/usr/home/photomountains/perl/sRGB.icm';

## Resize sizes
my $thumb_size = 100;
my $preview_size = 500;
my $comp_size = 800;

## Watermark options
#These items will be printed at the bottom of each image one after another
my $copyright_notice = "(c)Jeff Pflueger";
my $url = "jeffpflueger.com";
my $preview_watermark = 0; # 1 for watermarking, 0 for no watermarking
my $comp_watermark = 1; # 1 for watermarking, 0 for no watermarking

## Open the log file to write to
# open ( LOG, "+<$dameasy_path"."log.txt" ) or die "cannot write to $dameasy_path/log.txt for the log file";


## First see if I am already running. If I am then quit otherwise, write the lock file.

if ( open ( LOCKFILE, "+<$dameasy_path/lock.txt" ) ) {
	print "Lockfile $dameasy_path lock.txt exists. So either the script is already running, or you need to erase the lockfile.\nI'm stopping.";
	exit;
}
open ( LOCKFILE, "+>$dameasy_path/lock.txt" );
print LOCKFILE "locked";

### Recursively go through entire FTP directory and pack results into a database    

#empty the old dameasy_ftp database
$global::dbh -> do ( "DELETE FROM dameasy_ftp" ) || die "Couldn't delete all from dameay : $DBI::errstr";

# if redo_all option, then delete everything in the other databases as well
if ( $redo_all ) {
	print "Redoing all images. Deleting all from the dameasy and dameasy_keywords tables\n";
	$global::dbh -> do ( "DELETE FROM dameasy" ) || die "Couldn't delete all from dameay : $DBI::errstr";
	$global::dbh -> do ( "DELETE FROM dameasy_keywords" ) || die "Couldn't delete all from dameay : $DBI::errstr";
}


find(\&wanted, "$ftp_path");

# copy the ftp directory structure over to the web 
#print "Removing empty directories from the image mirror\n";
finddepth(sub{rmdir},"$image_path");

#print "Removing empty directories from the html mirror\n";
finddepth(sub{rmdir},"$html_path");

#print "Removing empty directories from the ftp_directory\n";
finddepth(sub{rmdir},"$ftp_path");

# need to create the directories to write the images to...
#print "Synching image directory structure with the ftp_directory\n";
system ( "mtree -cdnp $ftp_path | ( cd $image_path ; mtree -U -e -q -n -d > /dev/null )" );

sub wanted {
	
	
	##add each .JPG, .jpg, .TIF , .tif file to the database

	if ( ( $File::Find::name =~ /\.tif$/) or ( $File::Find::name =~ /\.TIF$/) or ($File::Find::name =~ /\.jpg$/) or ($File::Find::name =~ /\.JPG$/) ) {
	
		$global::dbh -> do ( "
			INSERT INTO dameasy_ftp ( ftp_file_path )
			VALUES ( '$File::Find::name' )" ) || die "Couldn't insert record : $DBI::errstr";
	}
	
	
}


### Erase cycle - go through the dameasy database. If there is anything there that is not in the dameasy_ftp database, then delete it, the files, the html and the database entries...

# print "\n**Erase Cycle**\n\n";
my $query = "SELECT ftp_file_path, thumb, preview, comp FROM dameasy ";
my $sth=$global::dbh->prepare ( "$query" ) ||die "$query - failed: $DBI::errstr\n";
$sth -> execute();

my @row;
while ( @row = $sth -> fetchrow_array ){
	my $ftp_file_path  = @row[0];
	my $thumb  = @row[1];
	my $preview  = @row[2];
	my $comp  = @row[3];
	
	# ftp_file_path will be unique....so delete any entry in dameasy table that exists for it
	
	my $query2 = "SELECT id, file_path, file_name, additional_path FROM dameasy_ftp WHERE ftp_file_path LIKE BINARY '$ftp_file_path' ";
	my $sth2 = $global::dbh->prepare ( "$query2" ) ||die "$query2 failed: $DBI::errstr\n";
	$sth2 -> execute();
	if  ( ( $sth2 -> rows ) == 0 ) {
		my ( $id, $file_path, $file_name, $additional_path ) = @row;
		
		# delete entry from database
		print "$ftp_file_path isn't in FTP directory, but is in database, so\n";
		print "\tDeleting from image database\n";
		$global::dbh -> do ( "
			DELETE FROM dameasy WHERE ftp_file_path = '$ftp_file_path' " ) || die "Couldn't delete all from dameay : $DBI::errstr";
		print "\tDeleting from keywords database\n";
		$global::dbh -> do ( "
			DELETE FROM dameasy_keywords WHERE image_id = '$id' " ) || die "Couldn't delete all from dameasy keywords: $DBI::errstr";
				
		# delete files
		print "\tDeleting the image files\n\n";
		unlink ( "$thumb" ) or warn "can't unlink $thumb\n";
		unlink ( "$preview" ) or warn "can't unlink $preview\n";
		#uncomment if you want comps
		#unlink ( "$comp" ) or warn "can't unlink $comp\n";
			
		$change = 1;
	}
	$sth2 -> finish();

}
$sth -> finish();

### Erase cycle - sync the dameasy_keywords database. If there is anything there that is not in the dameasy database, then delete it, the files, the html and the database entries...

my $query = "SELECT DISTINCT image_id FROM dameasy_keywords;";
my $sth=$global::dbh->prepare ( "$query" ) ||die "$query - failed: $DBI::errstr\n";
$sth -> execute();

my @row;
my $did_this;
while ( @row = $sth -> fetchrow_array ){
	my $id  = @row[0];
	$did_this = undef;
	
	# see if the id exists in the dameasy table, if it doesn't, delete any entry in dameasy_keyword table for that id
	
	my $query2 = "SELECT id FROM dameasy WHERE id = '$id'; ";
	my $sth2 = $global::dbh->prepare ( "$query2" ) ||die "$query2 failed: $DBI::errstr\n";
	$sth2 -> execute();
	if  ( ( $sth2 -> rows ) == 0 ) {
		
		# delete entry from database
		
		$global::dbh -> do ( "
			DELETE FROM dameasy_keywords WHERE image_id = '$id' " ) || die "Couldn't delete all from dameasy_keywords : $DBI::errstr";
					
		$change = 1;
		print "\t$id not in the dameasy table. Deleting it from dameasy_keywords\n\n";

	}
	
	
	
	$sth2 -> finish();

}
$sth -> finish();

	

## Add cycle - go through everything in the dameasy_ftp database, and if a file doesn't exist in the dameasy database then add it, resize and make a page and extrat exif info
# print "**Add Cycle**\n\n";
my $query = "SELECT id, ftp_file_path, file_path, file_name, additional_path FROM dameasy_ftp";
$sth = $global::dbh->prepare ( "$query" ) || die "$query failed: $DBI::errstr\n";
$sth -> execute();
my @row;
while ( @row = $sth -> fetchrow_array ) {
	my $ftp_file_path = @row[1];
	# ftp_file_path will be unique....so look for any entry in dameasy table that exists for it. if it isn't there, add it!
	my $query2 = "SELECT id FROM dameasy WHERE ftp_file_path LIKE BINARY '$ftp_file_path' ";
	my $sth2 = $global::dbh->prepare ( "$query2" ) ||die "$query2 failed: $DBI::errstr\n";
	$sth2 -> execute ();
	
	if  ( ( $sth2 -> rows ) == 0 ) {
		# to check on file progress so we don't do something to a file partially uploaded
		my $image = Image::Magick->new;
		my $x = $image->Read("$ftp_file_path");
		if ( $x =~ /325|Read error on strip|365|425/ ) {
				warn "File not finished: Did not add $ftp_file_path : $x\n\n";
				next;
		}
		undef $image;


		
	
		#extract the exif data
		print "$ftp_file_path is in the ftp directory, but not the database, so:\n";
		print "\tExtracting IPTC and EXIF data\n";
		my %exif_data = extract_exif ($ftp_file_path);
		# GPS
		my $gps_latitude_ref = $exif_data{"GPS Latitude Ref"};
		my $gps_latitude = $exif_data{"GPS Latitude"};
		my $gps_longitude_ref = $exif_data{"GPS Longitude Ref"};
		my $gps_longitude = $exif_data{"GPS Longitude"};
		my $gps_altitude_ref = $exif_data{"GPS Altitude Ref"};
		my $gps_altitude = $exif_data{"GPS Altitude"};
				
		my $keywords = $exif_data{"Keywords"};
		if ( $keywords eq '' ) {
			$keywords = $exif_data{"Subject"};
		}
	
		my $copyright = $exif_data{"Copyright Notice"};
		if ( $copyright eq '' ) {
			$copyright = $exif_data{"Rights"};
		}

		my $description = $exif_data{"Description"};
		if ( $description eq '' ) {
			$description = $exif_data{"Image Description"};
		}
		if ( $description eq '' ) {
			$description = $exif_data{"Caption-Abstract"};
		}
	

		my $instructions = $exif_data{"Instructions"};

		my $headline = $exif_data{"Headline"};
	
		if ( $headline eq '' ) {
			$headline = $exif_data{"Title"};
		}
		if ( $headline eq '' ) {
			$headline = $description;
		}
		if ( $headline eq '' ) {
			$headline = $keywords;
		}
		
		if ( $description eq '' ) {
			$description = $headline;
		}

		my $location = $exif_data{"Location"};
		if ( $location eq '' ) {
			$location = $exif_data{"Sub-location"};
			$location = $exif_data{"City"};
		}
	
	
		my $state = $exif_data{"State"};
		if ( $state eq '' ) {
			$state = $exif_data{"Province-State"};
		}
	
		my $country = $exif_data{"Country-Primary Location Name"};


		my $image_size = $exif_data{"Image Size"};

		my $orientation = $exif_data{"Orientation"};
		## extract the degrees to rotate the image
		my $rotate = $orientation;
		$rotate =~ s/\(.*\)//g;  #remove everything in parenthesis like (1)
		$rotate =~ s/[^0-9]//g; #remove everything else but the number of degrees
	

		# Create a new filename

		my $file_name_root = $headline;
		$file_name_root = substr $file_name_root, 0, 100;
		# allow, letters,niumbers, substitute spaces and commas with underscores
		$file_name_root  =~ s/[\s,]/_/g;
		#replace double underscores with single
		$file_name_root  =~ s/__/_/g;
		$file_name_root  =~ s/[^\w_]//g;

		#$description  =~ s/[^\w\s\'!\?:;,-\.]//g;

		# create the "additional path". this is the path below the ftp_path minus the actual filename.
		my $additional_path = $ftp_file_path;
		$additional_path =~ s /$ftp_path//;
		$additional_path =~ s /\/[^\/]+$//;  #remove the old file name from the end
		$additional_path .= "/";

		#extract the original filename
		my $original_file_name = $ftp_file_path;
		$original_file_name =~ /([^\/]+$)/;
		$original_file_name = $1;

		#quote safe it all before putting it in a DB
		my $keywords_not_quoted = $keywords;
		$keywords = $global::dbh->quote($keywords);
		$copyright = $global::dbh->quote($copyright);
		$headline = $global::dbh->quote($headline);
		$description = $global::dbh->quote($description);
		$location = $global::dbh->quote($location);
		$state = $global::dbh->quote($state);
		$country = $global::dbh->quote($country);
		$gps_latitude_ref = $global::dbh->quote($gps_latitude_ref);
		$gps_latitude = $global::dbh->quote($gps_latitude);
		$gps_longitude_ref = $global::dbh->quote($gps_longitude_ref);
		$gps_longitude = $global::dbh->quote($gps_longitude);
		$gps_altitude_ref = $global::dbh->quote($gps_altitude_ref);
		$gps_altitude = $global::dbh->quote($gps_altitude);

		# Pack it into the dameasy database
		my $query = "INSERT INTO dameasy
		(
		date_added,
		ftp_file_path,
		keywords,
		copyright,
		headline,
		description,
		location,
		state,
		country,
		image_size,
		file_name_root,
		additional_path,
		file_name,
		instructions,
		gps_latitude_ref,
		gps_latitude,
		gps_longitude_ref,
		gps_longitude,
		gps_altitude_ref,
		gps_altitude
		)
		VALUES
		(
		NOW(),
		'$ftp_file_path',
		$keywords,
		$copyright,
		$headline,
		$description,
		$location,
		$state,
		$country,
		'$image_size',
		'$file_name_root',
		'$additional_path',
		'$original_file_name',
		'$instructions',
		$gps_latitude_ref,
		$gps_latitude,
		$gps_longitude_ref,
		$gps_longitude,
		$gps_altitude_ref,
		$gps_altitude
		);
		";
		print "\tAdding to database\n";
		my $sth3 =$global::dbh->do ( "$query" ) ||die "$query failed: $DBI::errstr\n";
		
		my $id = $global::dbh -> {mysql_insertid};

		my $thumbnail_file_name = $file_name_root . "_$id" . "_t.jpg";
		my $thumb = $image_path . $additional_path .  $thumbnail_file_name;
		my $preview_file_name = $file_name_root . "_$id" . "_p.jpg";
		my $preview = $image_path . $additional_path . $preview_file_name;

		my $comp_file_name = $file_name_root . "_$id" .  "_p.jpg";
		my $comp = $image_path . $additional_path . $comp_file_name;

		my $http_path = "$html_doc_path" . "$additional_path" . "$file_name_root" . "_" . "$id" . ".html";
		my $thumb_http = "$image_doc_path" . "$additional_path" . "$thumbnail_file_name";
		my $preview_http = "$image_doc_path" . "$additional_path" . "$preview_file_name";

		#insert the file names
		my $query = "UPDATE dameasy SET
		http_path = '$http_path',
		thumb = '$thumb',
		preview = '$preview',
		comp = '$comp',
		thumb_http = '$thumb_http',
		preview_http = '$preview_http'
		WHERE id = '$id';
		";
	
		my $sth4 = $global::dbh->do ( "$query" ) ||die "$query failed: $DBI::errstr\n";
		
		## now pack it into the dameasy_keywords db

		my @keywords_arr = split ( /,\s*/,$keywords_not_quoted );
		my $keyword_single;
		foreach (@keywords_arr) {
			$keyword_single = $global::dbh->quote($_);
			my $query = "INSERT INTO dameasy_keywords
			( image_id, keyword )
			VALUES
			( '$id', $keyword_single );
			";
			my $sth3 = $global::dbh->do ( "$query" ) ||die "$query failed: $DBI::errstr\n";
		}



		#then do the ImageMagick

		imagemagick ( $ftp_file_path, $thumb, $preview, $comp, $rotate, $thumb_size, $preview_size, $comp_size );

		print "\n";

		$change = 1;
		
	
	}
$sth2 -> finish();
	

}
$sth -> finish();

## Now make all the HTML files

## Make Each Image Home page:

## If something has changed, delete ALL of the HTML and save the new HTML

if ( $change == 1 ) {
	print "\n**Saving HTML Pages**\n";
	system ( "rm -r $html_path" ) || warn "can't delete all the directories $!";
	system ( "rm -r $html_keywords_path" ) || warn "can't delete all the directories $!";
	
	#create the directory that you just deleted
	mkdir ("$html_path" , 0777) || die "Cannot mkdir $html_path $!";
	mkdir ("$html_keywords_path" , 0777) || die "Cannot mkdir $html_keywords_path $!";
	print "\tDeleting all HTML files\n";
	print "\tSynching html directory structure with the ftp directory\n";
	system ( "mtree -cdnp $ftp_path | ( cd $html_path ; mtree -U -e -q -n -d > /dev/null )" );
	
	# now that you've deleted everything, copy over the narration, movie.swf and movie.flv for the flash movie
		
		find(\&wanted_again, "$ftp_path");
		
		sub wanted_again {
			
			# if movie.swf, movie.flv, and narration.mp3 are present, then copy them to the html mirror
			
			if ( $File::Find::name =~ /narration\.mp3$/) {
				print "\tCopying from ftp to html directories - " . $File::Find::name . "\n";
				my $narration_path = $File::Find::name;
				$narration_path =~ s/$ftp_path//g;
				$narration_path = $html_path . $narration_path;
				copy( $File::Find::name, $narration_path ) or warn "$! Can't : copy( $File::Find::name, $narration_path )\n";
			} 
			
			if ( $File::Find::name =~ /movie\.swf$/) {
				print "\tCopying from ftp to html directories - " . $File::Find::name . "\n";
				my $movie_path = $File::Find::name;
				$movie_path =~ s/$ftp_path//g;
				$movie_path = $html_path . $movie_path;
				copy( $File::Find::name, $movie_path ) or warn "$! Can't : copy( $File::Find::name, $movie_path )\n";
			}
			
			if ( $File::Find::name =~ /movie\.flv$/) {
				print "\tCopying from ftp to html directories - " . $File::Find::name . "\n";
				my $movie_path = $File::Find::name;
				$movie_path =~ s/$ftp_path//g;
				$movie_path = $html_path . $movie_path;
				copy( $File::Find::name, $movie_path ) or warn "$! Can't : copy( $File::Find::name, $movie_path )\n";
			} 	
			
		}
	

	## now save the html
	
	print "\tSaving html for home pages for each image\n";

	my $query = "SELECT preview, keywords, copyright, headline, file_name_root, id,  description, location, state, country, image_size, additional_path, file_name, instructions, ftp_file_path, gps_latitude_ref,
		gps_latitude, gps_longitude_ref, gps_longitude, gps_altitude_ref, gps_altitude
		FROM dameasy ORDER BY additional_path ASC;";
	my $sth=$global::dbh->prepare ( "$query" ) ||die "$query - failed: $DBI::errstr\n";
	$sth -> execute();

	my @row_refs;
	my @results;
	while ( @row_refs = $sth -> fetchrow_array ){
		push @results, [@row_refs];
	}
	
	for ( my $count = 0; $count < scalar ( @results ); $count++ ) {
		my $row_ref = @results[$count];
		my @row = @{$row_ref};
		
		my $preview = @row[0];
		my $keywords = @row[1];
		my $copyright = @row[2];
		my $headline = @row[3];
		my $file_name_root = @row[4];
		my $id = @row[5];
		my $description = @row[6];
		my $location = @row[7];
		my $state = @row[8];
		my $country = @row[9];
		my $image_size = @row[10];
		my $additional_path = @row[11];
		my $file_name = @row[12];
		my $instructions = @row[13];
		my $ftp_file_path = @row[14];
		my $gps_latitude_ref = @row[15];
		my $gps_latitude = @row[16];
		my $gps_longitude_ref = @row[17];
		my $gps_longitude = @row[18];
		my $gps_altitude_ref = @row[19];
		my $gps_altitude = @row[20];
		
		$ftp_file_path =~ s/\/home\/dameasy\/ftp_images\///g;
	
		$preview = "$image_doc_path" . "$additional_path" . "$file_name_root" . "_" . "$id" . "_p.jpg";
		my $thumbnail ="<img src='" . "$image_doc_path" . "$additional_path" . "$file_name_root" . "_" . "$id" . "_t.jpg" . "'>";
	
		# old file based templates
		#my $preview_template = '';
		#open (PREVIEW_TEMPLATE, "$preview_template_path") or die "Can't open file: $preview_template_path";
		#while (<PREVIEW_TEMPLATE>) {
		#	chomp;
		#	$preview_template .= "$_\n";
		#}
		#close (PREVIEW_TEMPLATE);
		
		# new URL based template
		my $preview_template = get $preview_template_path;
  		die "Couldn't get $preview_template_path" unless defined $preview_template;

		## Create the flash link
		my $flash_link = $html_doc_path . $additional_path . "flash.html";
		
		## Create linked keywords
		my @keys_linked_array = split ( /, /,$keywords );
		my $keys_linked = '';
		for ( @keys_linked_array ) {
			my $keyword = $_;
			my $safe_keyword = CGI::escapeHTML ( $_ );
			$keyword =~ s/\W/_/g;
			my $path = $keyword_doc_path . $keyword . ".html";
			$keys_linked .= "<a href='/$path'>" . $_ . "</a>, ";
		
			# old for link to DRR
			#$keys_linked .= "<a href='http://archive.jeffpflueger.com/search/SearchRemote.aspx?hidSearchMode=Basic&txtKeyword=" . "$_" . "' target='_blank'>" . "$_" . "</a>" . ", ";
		}
		
		## Create GPS
		my $gps = '';
		my $gps_linkns;
		my $gps_linkew;
		my $decimal_degreesew;
		my $decimal_degreesns;
		if ( $gps_latitude != '' ) {
			#latitude
			my $ns = $gps_latitude;
			my $latint = $gps_latitude;
			my $latmin = $gps_latitude;
			my $latsec = $gps_latitude;
			$latint =~ /^([0-9]{1,3})/;
			$latint = $1;
			$ns =~ /(.{1})$/;
			$ns = $1;
			$latmin =~ /([0-9]{1,2})\'/;
			$latmin = $1;
			
			$latsec =~ /([0-9\.]{2,6})\"/;
			$latsec = $1;
			
			$decimal_degreesns = dms2decimal($latint, $latmin, $latsec);
			$gps_linkns = "$decimal_degreesns";
			if ( $ns eq "S" ) {
				$gps_linkns = 0 - $gps_linkns;
			}
			
			#longitude
			my $ew = $gps_longitude;
			my $longint = $gps_longitude;
			my $longmin = $gps_longitude;
			my $longsec = $gps_longitude;
			$longint =~ /^([0-9]{1,3})/;
			$longint = $1;
			$ew =~ /(.{1})$/;
			$ew = $1;
			$longmin =~ /([0-9]{1,2})\'/;
			$longmin = $1;
			$longsec =~ /([0-9\.]{2,6})\"/;
			$longsec = $1;
			$decimal_degreesew = dms2decimal($longint, $longmin, $longsec);
			$gps_linkew = "$decimal_degreesew";
			if ( $ew eq "W" ) {
				$gps_linkew = 0 - $gps_linkew;
			}
			my $gps_link = "http://maps.google.com/maps?q=" . "$gps_linkns" . "," . "$gps_linkew" . "&" . "spn=0.001,0.001&t=k&hl=en";
			$gps = "$gps_latitude <br> $gps_longitude <br>" . int($gps_altitude) . " Meters $gps_altitude_ref<br><a href='$gps_link'>Map This Location</a>";	
		}
			
			
		
		## Create instructions
		$instructions =~ s{(http:[^\s]*)} {<a href="$1">$1</a>}gs;
		
		## Create linked file path and Collection
		my @additional_path_split = split(/\//, $additional_path);
		my $collection = "Collection: ";
		my $additional_path_linked = "<a href='" . $html_doc_path . "index.html'>" . "home/</a><br>";
		my $accumulation;
		my $spacer = '';
		foreach (@additional_path_split) {
			$collection .= $_ . "&nbsp;";
			$spacer .= "";
			$accumulation .= $_ . "/";
			$additional_path_linked .= $spacer . "<a href='" . $html_doc_path . $accumulation . "index.html'>" . $_ . "/</a>";
		}
		$collection =~ s/_/ /g;
		$collection = "<a href='" . $html_doc_path . $additional_path . "index.html'>" . $collection . "</a>"; 
		
		## Create next and previous
		my $previous_number = $count - 1;
		my $next_number = $count + 1;
		my $previous_array_ref = undef;
		my $next_array_ref = undef;
		my $next_string;
		my $previous_string;
		
		if ($count > 0) {
			$previous_array_ref = $results[$previous_number];
			#print "Previous Array: " . $results[$previous_number] . "\n";
		}
		$next_array_ref = $results[$next_number] if ($count < scalar ( @results ) );
		
		my @next_array;
		if ( $next_array_ref ) {
			@next_array = @{$next_array_ref};
			my $next_file_name = $next_array[4];
			my $next_file_id = $next_array[5];
			my $next_additional_path = $next_array[11];
			if ( $next_additional_path eq $additional_path ) {
				my $next_url = "$html_doc_path" . "$next_additional_path" . "$next_file_name" . "_" . "$next_file_id" . ".html";
				$next_string="<a href='" . "$next_url" . "'>Next Image &gt;&gt;&gt;</a>";
			}
			else {
				$next_string="&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;";
			}
		}
		
		my @previous_array;
		if ( $previous_array_ref ) {
			@previous_array = @{$previous_array_ref};
			my $previous_file_name = $previous_array[4];
			my $previous_file_id = $previous_array[5];
			my $previous_additional_path = $previous_array[11];
			if ( $previous_additional_path eq $additional_path ) {
				my $previous_url = "$html_doc_path" . "$previous_additional_path" . "$previous_file_name" . "_" . "$previous_file_id" . ".html";
				$previous_string = "<a href='" . "$previous_url" . "'>&lt;&lt;&lt; Previous Image</a>";
			}
			else {
				$previous_string="&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;";
			}
		} 
		
		## create ptp_link
		# quote safe
		my $ptp_headline = $headline;
		my $ptp_description = $description;
		my $ptp_preview = $preview;
		my $ptp_ftp_file_path = $ftp_file_path;
		# url encode them
		$ptp_headline =~ s/[\'\"]//g;
		$ptp_description =~ s/[\'\"]//g;
		#$ptp_preview =~ s/([^A-Za-z0-9])/sprintf("%%%02X", ord($1))/seg;
		$ptp_ftp_file_path =~ s/([^A-Za-z0-9])/sprintf("%%%02X", ord($1))/seg;
		
		my $ptp_link = "<a href=\"javascript:goPtp('$ptp_headline','$ptp_description','$ptp_preview','$ftp_file_path','Pricing_Standard');;\"> BUY A PRINT </a>\n";
	
		my %tasks = (
			PREVIEW => "$preview",
			THUMBNAIL => "$thumbnail",
			KEYWORDS => "$keywords",
			COPYRIGHT => "Copyright: $copyright",
			HEADLINE => "$headline",
			DESCRIPTION => "$description",
			LOCATION => "Location: $location",
			STATE => "State: $state",
			COUNTRY => "Country: $country",
			IMAGE_SIZE => "$image_size",
			KEYS_LINKED => "$keys_linked",
			FILE_NAME => "$file_name",
			ADDITIONAL_PATH => "$additional_path_linked",
			PREVIOUS => "$previous_string",
			NEXT => "$next_string",
			COLLECTION => "$collection",
			FLASH_LINK => "$flash_link",
			PTP_LINK => "$ptp_link",
			INSTRUCTIONS => "$instructions",
			GPS => "$gps",
			77.7777 => "$gps_linkns",
			88.8888 => "$gps_linkew"
			
		);
	
		for (keys %tasks) {
			$preview_template =~ s/$_/$tasks{$_}/g;
		}

	
		my $save_path = "$html_path" . "$additional_path" . "$file_name_root" . "_" . "$id" . ".html"; 
		open PREVIEW_PAGE , ">$save_path" or die "Can't open file: $save_path to write to. $!";
		print PREVIEW_PAGE $preview_template;
		close (PREVIEW_PAGE);
	}



	## Make Directory Home page:

	print "\tSaving html for directory indexes for each directory\n";
	
	find(\&wanted2, "$ftp_path");

	my @paths;

	sub wanted2 {
		 my $directory = $File::Find::dir;
		 $directory =~ s/$ftp_path//;
		 $directory .= "/";
		 unless ( $directory eq $ftp_path ) {
		 	push @paths, $directory;
		 }
	}

	@paths = sort ( @paths );
	my @paths_unique;
	my $previous;
	for ( @paths ) {
		if ( $previous ne $_ ) {
			push @paths_unique, $_;
		}
		$previous = $_;
	}

	# find all images from the dameasy database in each directory

	push @paths_unique, "";

	for ( @paths_unique ) {
		my $additional_path = $_;
		my $query = "SELECT id, file_name_root, headline, description, keywords, additional_path FROM dameasy WHERE additional_path LIKE BINARY '$additional_path'";
		my $sth=$global::dbh->prepare ( "$query" ) ||die "$query - failed: $DBI::errstr\n";
		$sth -> execute();

		my @row;
		my @thumbnails;
		while ( @row = $sth -> fetchrow_array ){
			push @thumbnails, [@row];
		}


		# find all links to other directories in this directory
	
		my $current_directory = "$html_path" . "$additional_path";
		my @directories;
		opendir DH, $current_directory or die "Couldn't open $current_directory to list the files from: $!";
		while ($_ = readdir(DH)) {
			next if $_ eq "." or $_ eq "..";
			my $file_test = "$current_directory" . "$_";
			if ( -d "$file_test" ) {
				my $path = "$html_doc_path" . "$additional_path" . "$_" . "/" ."index.html";
				push @directories, $_;
			}
		}	



		## create the THUMBNAIL
		my $thumbs;
		my $count = @thumbnails;
	
		for (@thumbnails) {
			my @thumbnail = @{$_};
			my $id = $thumbnail[0];
			my $file_name_root = $thumbnail[1];
			my $headline = $thumbnail[2];
			my $description = $thumbnail[3];
			my $keywords = $thumbnail[4];
			my $thumb = "$image_doc_path" . "$additional_path" . "$file_name_root" . "_" . "$id" . "_t.jpg";
			my $preview = $file_name_root . "_" . "$id" . ".html";
			$thumbs .= "<div id='thumbnail'><a href='$preview'><img src='$thumb' alt='$headline $description'></a><br> <div id='thumb_description'><a href='$preview'>$description</a></div></div>\n";
		}
		

		## create the DIRECTORIES
		my $directories = "";
		$directories .= "<ul>\n";
		if ( ( "$html_doc_path" . "$additional_path" ) ne "$html_doc_path" ) {
			$directories .= "<li><a href='../index.html'>Up One Directory</a>";
		}
		
		for (@directories) {
			my $path = "$html_doc_path" . "$additional_path" . "$_" . "/index.html";
			$directories .= "<li><a href='$path'> $_ </a></li>\n";
		}
		$directories .= "</ul>\n";
		
		## Create linked file path
		my @additional_path_split = split(/\//, $additional_path);
		my $additional_path_linked = "<a href='" . $html_doc_path . "index.html'>" . "home/</a><br>";
		my $accumulation;
		my $spacer='';
		foreach (@additional_path_split) {
			$spacer .= "&nbsp;&nbsp;";
			$accumulation .= $_ . "/";
			$additional_path_linked .= $spacer . "<a href='" . $html_doc_path . $accumulation . "index.html'>" . $_ . "/</a><br>";
		}

		## Create Flash embed
		my $flash_url = "http://jeffpflueger.com" . $html_doc_path . $additional_path . "flash.swf";
		my $flash = "<object classid='clsid:D27CDB6E-AE6D-11cf-96B8-444553540000' codebase='http://download.macromedia.com/pub/shockwave/cabs/flash/swflash.cab#version=6,0,29,0' width='550' height='400'>
		  		<param name='movie' value='$flash_url'>
		  		<param name='quality' value='high'>
		  		<param name='LOOP' value='false'>
		  		<embed src='$flash_url' quality='high' pluginspage='http://www.macromedia.com/go/getflashplayer' type='application/x-shockwave-flash' width='550' height='400'></embed>
			</object>";
		
		## Create the flash link
		my $flash_link = '';
		if ( $count > 0 ) {
			$flash_link = "<a href='" . $html_doc_path . $additional_path . "flash.html'>See Slide Show for this Collection</a>";
		}
		
		## Create the title
		my $title;
		my $title_path = $additional_path;
		$title_path =~ s/[\/_]/ /g;
		
		if ( $count > 0 ) {
			$title = "Pictures, images and photos from $title_path";
		}
		else {
			$title = "$title_path";
		}
			
		
		## Create the index link
		my $index_link = $html_doc_path . $additional_path . "index.html";
		
		# Create rss_link
		my $additional_path_safe = CGI::escapeHTML($additional_path);
		my $rss_link = $rss_folder_path . "?folder=" . "$additional_path_safe";
		
		## save the index page for this directory
		#my $index_template;
		#open (INDEX_TEMPLATE, "$index_template_path") or die "Can't open file: $index_template_path";
	
		#while (<INDEX_TEMPLATE>) {
		#	chomp;
		#	$index_template .= "$_\n";
		#}

		#close (INDEX_TEMPLATE);
		
		# new URL based template
		my $index_template = get $index_template_path;
  		die "Couldn't get $index_template_path" unless defined $index_template;
		
		my %tasks = (
			TITLE => "$title",
			DIRECTORIES => "$directories",
			THUMBNAILS => "$thumbs",
			ADDITIONAL_PATH => "$additional_path_linked",
			FLASH => "$flash",
			FLASH_LINK => "$flash_link",
			INDEX_LINK => "$index_link",
			RSS_LINK => "$rss_link",
			FOLDER => "$additional_path"
		);
		
		for (keys %tasks) {
			$index_template =~ s/$_/$tasks{$_}/g;
			
		}
	
	
		#save the index page
		my $index_name = $current_directory . "index.html";
		open INDEX_PAGE , ">$index_name" or die "Can't open file: $index_name to write to. $!";
		print INDEX_PAGE $index_template;
		close (INDEX_PAGE);
		
		if ( $count > 0 ) {
			## save the flash page for this directory
			my $flash_template;
			open (FLASH_TEMPLATE, "$flash_template_path") or die "Can't open file: $flash_template_path";
			
			while (<FLASH_TEMPLATE>) {
				chomp;
				$flash_template .= "$_\n";
			}
			
			## flash HTML
			my $flash_html = "
<button type='button' onclick=\"document.getElementById('source_textarea4').focus();document.getElementById('source_textarea4').select()\">Select code</button><br>
<textarea readonly='readonly' rows='9' cols='60' id='source_textarea4' name='source_textarea4' wrap='off'>
<object codebase='http://download.macromedia.com/pub/shockwave/cabs/flash/swflash.cab#version=6,0,29,0' width='550' height='400'>
	<param name='movie' value='http://jeffpflueger.com" . $html_doc_path . $additional_path . "flash.swf'>
	<param name='quality' value='high'>
	<param name='base' value ='.'>
	<param name='LOOP' value='false'>
	<embed base='.' src='http://jeffpflueger.com" . $html_doc_path . $additional_path . "flash.swf' quality='high' pluginspage='http://www.macromedia.com/go/getflashplayer' type='application/x-shockwave-flash' width='550' height='400'></embed>
</object>
</textarea>
";
				
			close (INDEX_TEMPLATE);
				
			my %tasks = (
				TITLE => "Pictures, images and photos from $title_path",
				DIRECTORIES => "$directories",
				THUMBNAILS => "$thumbs",
				ADDITIONAL_PATH => "$additional_path_linked",
				FLASH => "$flash",
				FLASH_LINK => "$flash_link",
				INDEX_LINK => "$index_link",
				FLASH_HTML => "$flash_html"
			);
				
			for (keys %tasks) {
				$flash_template =~ s/$_/$tasks{$_}/g;
					
			}
			
			
			#save the flash page
			my $flash_name = $current_directory . "flash.html";
			open FLASH_PAGE , ">$flash_name" or die "Can't open file: $flash_name to write to. $!";
			print FLASH_PAGE $flash_template;
			close (FLASH_PAGE);
		
			#save the images.php and the flash.swf files to the directory
			my $flash_name = $current_directory;
			my $xml_name = $current_directory;
		
			copy( $swf_template_path, $flash_name ) or warn "Can't : copy( $swf_template_path, $flash_name ).";
			copy( $flash_xml_template_path, $xml_name ) or warn "Can't : copy( $flash_xml_template_path, $xml_name ).";
		}
	}
	
	## Make Keyword Home page:
	
		print "\tSaving html for keyword indexes of images\n";
		
		my $query = "SELECT keyword FROM dameasy_keywords;";
		my $sth=$global::dbh->prepare ( "$query" ) ||die "$query - failed: $DBI::errstr\n";
		$sth -> execute();
		
		my @row;
		my @keywords_array;
		while ( @row = $sth -> fetchrow_array ){
			push @keywords_array, @row[0];
		}
	
		# alphabetize and remove redundant keywords
		@keywords_array = sort ( @keywords_array );
		my @keywords_unique;
		my $previous;
		for ( @keywords_array ) {
			if ( $previous ne $_ ) {
				push @keywords_unique, $_;
			}
			$previous = $_;
		}
		my @keywords_unique2 = @keywords_unique;
	
	
		for ( @keywords_unique ) {
			my $keyword = $_;
			my $keyword_safe = $global::dbh->quote($_);
			my $query = "SELECT dameasy.id,
					dameasy.file_name_root,
					dameasy.headline,
					dameasy.description,
					dameasy.keywords,
					dameasy.additional_path
					FROM
					dameasy,
					dameasy_keywords
					WHERE dameasy.id = dameasy_keywords.image_id
					AND
					dameasy_keywords.keyword = $keyword_safe;";
			my $sth=$global::dbh->prepare ( "$query" ) || die "$query - failed: $DBI::errstr\n";
			
			$sth -> execute();
			my @row;
			my @thumbnails;
			while ( @row = $sth -> fetchrow_array ){
				push @thumbnails, [@row];
			}
	
	
			# find all links to other directories in this directory
		
			my $current_directory = "$html_keywords_path";
			
			## create the THUMBNAIL
			my $thumbs;
			my $count = @thumbnails;
			my $additional_path;
			
			for (@thumbnails) {
				my @thumbnail = @{$_};
				my $id = $thumbnail[0];
				my $file_name_root = $thumbnail[1];
				my $headline = $thumbnail[2];
				my $description = $thumbnail[3];
				my $keywords = $thumbnail[4];
				$additional_path = $thumbnail[5];
				my $thumb = "$image_doc_path" . "$additional_path" . "$file_name_root" . "_" . "$id" . "_t.jpg";
				my $preview = $html_doc_path . $additional_path . $file_name_root . "_" . "$id" . ".html";
				$thumbs .= "<div id='thumbnail'><a href='$preview'><img src='$thumb' alt='$headline $description'></a><br> <div id='thumb_description'><a href='$preview'>$description</a></div></div>\n";
			}
			
			## rss link
			my $rss_link = $rss_keyword_path . "?keyword=" . $_;
		
	
			## save the index page for this directory
			#my $index_template;
			#open (INDEX_TEMPLATE, "$keyword_template_path") or die "Can't open file: $keyword_template_path";
		
			#while (<INDEX_TEMPLATE>) {
			#	chomp;
			#	$index_template .= "$_\n";
			#}
			#close (INDEX_TEMPLATE);
			
			# new URL based template
			my $index_template = get $keyword_template_path;
  			die "Couldn't get $keyword_template_path" unless defined $index_template;
		
			my $title_path = $additional_path;
			$title_path =~ s/\// /g;
			
			my %tasks = (
				TITLE => "Pictures of $keyword. Photos with $keyword. Images of $keyword",
				THUMBNAILS => "$thumbs",
				RSS_LINK => "$rss_link",
				KEYWORD => "$keyword"
			);
			
			for (keys %tasks) {
				$index_template =~ s/$_/$tasks{$_}/g;
				
			}
		
		
			#save the page
			$keyword =~ s/\W/_/g;
			my $index_name = $html_keywords_path . $keyword . ".html";
			open INDEX_PAGE , ">$index_name" or die "Can't open file: $index_name to write to. $!";
			print INDEX_PAGE $index_template;
			close (INDEX_PAGE);
		}
		
		## Make Keyword Index:
		# break unique keywords by letter	
		my $list;
		for ( @keywords_unique2 ) {
			my $keyword = $_;
			my $safe_keyword = CGI::escapeHTML ( $_ );
			$keyword =~ s/\W/_/g;
			my $path = $keyword_doc_path . $keyword . ".html";
			$list .= "<p><a href='$path'>" . $_ . "</a>  --  <a href='$rss_keyword_path?keyword=" . $safe_keyword . "'><img src='/images/rss_icon16x16.png'>&nbsp;" . $_ . " rss feed</a></p>";
		}
					
		## save the index page for this directory
		#my $index_template;
		#open (INDEX_TEMPLATE, "$keyword_template_path") or die "Can't open file: $keyword_template_path";
		#while (<INDEX_TEMPLATE>) {
		#	chomp;
		#	$index_template .= "$_\n";
		#}
			
		#close (INDEX_TEMPLATE);
		
		my $index_template = get $keyword_template_path;
  			die "Couldn't get $keyword_template_path" unless defined $index_template;
					
		## Keyword
		my $keyword = 'All Keywords';
		
		## rss link
		my $rss_link = $rss_keyword_path . "?keyword=" . $keyword;
		
		my %tasks = (
			TITLE => "A List of all Keywords for Images",
			THUMBNAILS => "$list",
			RSS_LINK => "$rss_link",
			KEYWORD => "$keyword"
		);
					
		for (keys %tasks) {
			$index_template =~ s/$_/$tasks{$_}/g;
						
		}
				
				
		#save the page
		my $index_name = $html_keywords_path . "index.html";
		open INDEX_PAGE , ">$index_name" or die "Can't open file: $index_name to write to. $!";
		print INDEX_PAGE $index_template;
		close (INDEX_PAGE);
	


	##end timer
	my $end_time = time();
	print "\nTask done in ", ($end_time - $start_time), " seconds\n";
	

} #end of the if there was a change
else {
	#print "Nothing changed, so nothing written\n";
}



## erase the lock file
unlink ( "$dameasy_path/lock.txt" );



## close the logfile 
#close (LOG);



sub extract_exif {
	my $filename = shift;
	my $name;
	my %exif_data;
	my $exifTool = new Image::ExifTool;
	$exifTool->Options(Unknown => 1);
	my $info = $exifTool->ImageInfo("$filename");
	my $group = '';
    	my $tag;
    	foreach $tag ($exifTool->GetFoundTags('Group0')) {
        	if ($group ne $exifTool->GetGroup($tag)) {
        	    	$group = $exifTool->GetGroup($tag);
        	}
        	my $val = $info->{$tag};
        	if (ref $val eq 'SCALAR') {
        	    if ($$val =~ /^Binary data/) {
        	        $val = "($$val)";
        	    }
        	    else {
        	        my $len = length($$val);
        	        $val = "(Binary data $len bytes)";
        	    }
        	}
        	
        	$name = $exifTool->GetDescription($tag);
        	$exif_data{$name} = "$val";
    	}
    	return %exif_data;
}

sub open_db {
	
	($db_name, $db_user, $db_password) = @_;
	
	



	$global::dbh = DBI -> connect( 
		"dbi:mysql:$db_name",
	 	"$db_user", "$db_password") ||
	 	die "Error opening database: $DBI::errstr\n";
}

sub close_db {
	$global::dbh -> disconnect() || die "Failed to 
	disconnect: $DBI::errstr\n";
}

sub imagemagick {
	my $filename = shift;
	my $thumb = shift;
	my $preview = shift;
	my $comp = shift;
	my $rotate = shift;
	my $thumb_size = shift;
	my $preview_size = shift;
	my $comp_size = shift;
	my $upload_dir = "../../$global::username/image";
	# add $comp_size to list if you want comps
	my @sizes = ( $thumb_size, $preview_size );
	# add $comp_size at the end if you want comp sizes saved.
	my $image = Image::Magick->new;
	my $copyright = Image::Magick->new;
	my $copyright_big = Image::Magick->new;
	my $x = $image->Read("$filename");
	warn "$x" if "$x";
	$image->Read("$filename");
	$image->Read("$filename");
	#$image->Read("$filename");
	# uncomment it if you want the comp sizes
	
	## rotate then if need be
	

	$x=$copyright->Read("$copyright_path");
	die "$x" if "$x";
	$x=$copyright_big->Read("$copyright_big_path");
	die "$x" if "$x";
	## is the image big, high quality and right type? ##
	my ( $width, $height, $magick  ) = $image->[0]->Get( 'columns', 'rows', 'magick'  );

	my $count = 0;

	if ( $width > $height ) {
		foreach my $imagesize ( @sizes ) {
			print "\tResizing the image into a $imagesize pixel image\n";
			my $newthumbwidth = $imagesize;
			my $newthumbheight = ( $imagesize/$width ) * $height;
			my $ylocation = $newthumbheight/2-40;
			annotate ( $x, $image, $newthumbheight, $newthumbwidth, $count, $ylocation, $rotate );
			$count += 1;
		}
	}
	else {
		foreach my $imagesize ( @sizes ) {
			print "\tResizing the image into a $imagesize pixel image\n";
			my $newthumbheight = $imagesize;
			my $newthumbwidth = ( $imagesize/$height ) * $width;
			my $ylocation = $newthumbheight/2-40;
			annotate ( $x, $image, $newthumbheight, $newthumbwidth, $count, $ylocation, $rotate );
			$count += 1;
	}
}

sub annotate {
	my $x = shift;
	my $image = shift;
	my $newthumbheight = shift;
	my $newthumbwidth = shift;
	my $count = shift;
	my $ylocation = shift;
	my $rotate = shift;
	$x = $image->[$count]->Scale(width=>"$newthumbwidth", height=>"$newthumbheight");
		warn "$x" if "$x";
	
	if ( $rotate != '' ) {
		$x = $image->[$count]->Rotate(degrees=>"$rotate");
		warn "$x" if "$x";
		$ylocation = $newthumbwidth/2-40;
				
	}
	
	$x = $image->[$count]->Set( quality=>'100' );
	
	
	if ( $count eq 1 ) {
		$x = $image -> [1] -> Annotate (
			font=>'@/home/jeff/fonts/VERDANA.TTF',
			pointsize=>'9', 
			gravity=>'South', 
			y=>'$ylocation', 
			x=>'0', 
			fill=>'white', 
			text=>"(c)Jeff Pflueger\njeffpflueger.com\n");
			die "$x" if "$x";
		if ( $preview_watermark == 1 ) {
			$x = $image -> [1] -> Composite (
				image => $copyright,
				gravity=>'Center'
			);
			die "$x" if "$x";
		}
			
	}
	# if you want comp, uncomment
	#if ( $count eq 2 ) {
	#	
	#	my $bottom_message = "$copyright" . "\n" . "$url";
	#	$x = $image -> [2] -> Annotate (
	#		font=>'@/home/jeff/fonts/VERDANA.TTF',
	#		pointsize=>'18',
	#		gravity=>'Center',
	#		y=>"$ylocation",
	#		x=>'0',
	#		fill=>'white',
	#		text=>"(c)Jeff Pflueger\njeffpflueger.com\n");
	#		die "$x" if "$x";
	#	if ( $comp_watermark == 1 ) {
	#		
	#		$x = $image -> [2] -> Composite (
	#			image => $copyright_big,
	#			gravity=>'Center'
	#		);
	#		die "$x" if "$x";
	#		
	#		
	#	}
	#}
} 
	
	## write the suckers ##
	
	print "\tSaving and converting profile of thumbnail and preview to sRGB\n";
	$x = $image->[0]->Write("$thumb");
	die "$x" if "$x";
	
	## convert to sRGB profile
	system ( "convert -profile $profile_path $thumb $thumb" );
	
	$x = $image->[1]->Write("$preview");
	die "$x" if "$x";
	## convert to sRGB profile
	system ( "convert -profile $profile_path $preview $preview" );
	# or warn "convert -profile $profile_path $preview $preview failed: $?";
	
	## uncomment if you want comps
	#$x = $image->[2]->Write("$comp");
	#die "$x" if "$x";
	### convert to sRGB profile
	#system ( "convert -profile $profile_path $comp $comp" );
	
	## if rotated, then change the exif to reflect it
		if ( $rotate != '' ) {
			print "\tRotated thumb and comp\n\tWrote EXIF data on both to Orientation: Horizontal (normal)\n";
			my $exifTool = new Image::ExifTool;
			my ($success, $errStr) = $exifTool->SetNewValue ( "Orientation", "Horizontal (normal)" );
			
			$exifTool->WriteInfo ( $thumb );
			my $errorMessage = $exifTool->GetValue('Error');
			my $warningMessage = $exifTool->GetValue('Warning');
			warn "$errorMessage" if "$errorMessage";
			warn "$warningMessage" if "$warningMessage";
			
			$exifTool->WriteInfo ( $preview );
			$errorMessage = $exifTool->GetValue('Error');
			$warningMessage = $exifTool->GetValue('Warning');
			warn "$errorMessage" if "$errorMessage";
			warn "$warningMessage" if "$warningMessage";
			
			$exifTool->WriteInfo ( $comp );
			$errorMessage = $exifTool->GetValue('Error');
			$warningMessage = $exifTool->GetValue('Warning');
			warn "$errorMessage" if "$errorMessage";
			warn "$warningMessage" if "$warningMessage";
		}
		
	


}


## piece for the keywords link:
# http://archive.jeffpflueger.com/search/SearchRemote.aspx?hidSearchMode=Basic&txtKeyword=KEYWORD HERE
