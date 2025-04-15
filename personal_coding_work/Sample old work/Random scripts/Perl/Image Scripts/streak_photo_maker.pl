#!c:/perl -w
# use strict;
use Image::Magick;

### Variables
#Directory is the path to the directory containing the images to be resized
$GLOBAL::directory = "blank";



print "\n\nStreak Photography Maker\n
Takes every tif,jpg and gif file in a given directory
and takes a strip out at a designated spot and stacks them
together in a composite image.
Please be sure that all the images are the same size and orientation.

Streak Photography Maker will not go down subdirectories,
nor alter or erase the original image files.

Type in the FULL path of the directory ending with a / or a \\.
";

while ($GLOBAL::directory ne "quit") {
	$GLOBAL::error = 0;
	print "\nPlease input the path to the image or directory
	\tExample:
	\tDirectory: C:/Jeff's Work/Images/Mars Pictures/
	\tSingle Image: C:/Jeff's Work/Images/Mars Pictures/me_on_olympus_mons.tif
	Path ( or 'quit' to exit)";
	
	$GLOBAL::directory = <STDIN>;
	$GLOBAL::directory =~ s/\n$//;


	my ( $singlefile, $newpath, @files_orig, @files );
	if ( ( $GLOBAL::directory =~ /\/$/ ) or ( $GLOBAL::directory =~ /\\$/ ) ) {
		#Open the directory
		if ( opendir(DIRECTORY, "$GLOBAL::directory") ) {
			@files_orig = readdir(DIRECTORY);
			foreach $filename ( @files_orig ) {
				if ( ($filename =~ /\.tif/) or ($filename =~ /\.TIF/) or
					($filename =~ /\.jpg/) or ($filename =~ /\.JPG/) or
					($filename =~ /\.gif/) or ($filename =~ /\.GIF/)) {
					push ( @files, $filename )
				}
			}
			mkdir "$GLOBAL::directory"."streak_image";
			# or warn "\n\tThe directory '$GLOBAL::directory"."1500jpg' already exists. Writing to the existing directory.";
			if ( $files == 0 ) {
				print"\n\tNo tif,jpg or gif can be found at $GLOBAL::directory\n";
			}
	
		}
		else {
			print "\n\tThe Directory $GLOBAL::directory either doesn't exist or can't be openned\n";
			$GLOBAL::error = 1;
		}
	}

	else {	
			print "\n\tPlease enter a directory path ending in a / or \ \n";
			$GLOBAL::error = 1;
	}

	my $we_have_an_image="no";
	
	
	# get the dimensions of the images and make the composite image\
	my $first_image = $GLOBAL::directory . $files[0];
	my $image = new Image::Magick;
	my $x = $image->Read("$first_image");
				warn "$x" if "$x";
	$GLOBAL::width = $image->Get( 'columns' );
	$GLOBAL::height = $image->Get( 'rows' );
	print "\n\nYour images are $GLOBAL::width pixels wide by $GLOBAL::height pixels high\n";
	my $count = @files;
	print "There are $count images in the directory\n";
	# make the composite
	$composite = new Image::Magick;
	my $comp_size = "$GLOBAL::width" . "x" . "$GLOBAL::height";
	$x = $composite -> Set(size=>"$comp_size");
		warn "$x" if "$x";
	$x = $composite->Read("gradient:white-black");
		warn "$x" if "$x";
	# $x = $composite->Write ( "$comp_path" );
	#	warn "$x" if "$x";
				
	## then ask the important questions
	print "Streak Orientation [h]orizontal, [v]ertical?";
	$GLOBAL::orientation = <STDIN>;
	$GLOBAL::orientation =~ s/\n$//;
				
	my $word_loc;
	if ( $GLOBAL::orientation eq "v" ) {
		$word_loc = "0=left edge, " . $GLOBAL::width/2 . "=center, " . $GLOBAL::width . "=right edge";
	}
	if ( $GLOBAL::orientation eq "h" ) {
		$word_loc = "0=top edge, " . $GLOBAL::height/2 . "=center, " . $GLOBAL::height . "=bottom edge";
		
	}
				
	print "Where to start to take streak (in pixels $word_loc )?";
	$GLOBAL::location = <STDIN>;
	$GLOBAL::location =~ s/\n$//;
				
	if ( $GLOBAL::orientation eq 'v' ) {
		print "Streak Thickness in pixels (" . int($GLOBAL::width/$count) . "=filled image) ?";
	}
	
	if ( $GLOBAL::orientation eq 'h' ) {
		print "Streak Thickness in pixels (" . int($GLOBAL::height/$count) . "=filled image) ?";
	}
	$GLOBAL::thickness = <STDIN>;
	$GLOBAL::thickness =~ s/\n$//;
	
	print "Would you like the streak location to progress each time moving by $GLOBAL::thickness pixels [y|n]?";
	$GLOBAL::progress = <STDIN>;
	$GLOBAL::progress =~ s/\n$//;
	
	
	
	if ( $GLOBAL::orientation eq 'h' ) {
		$GLOBAL::number_streaks = int ($GLOBAL::height/$GLOBAL::thickness);
	}
	
	if ( $GLOBAL::orientation eq 'v' ) {
		$GLOBAL::number_streaks = int ($GLOBAL::width/$GLOBAL::thickness);
	}
	
	print "Would you like as many composites as you have streaks? (you have $GLOBAL::number_streaks streaks) [y|n]?";
	$GLOBAL::more_composites = <STDIN>;
	$GLOBAL::more_composites =~ s/\n$//;
	
	if ( $GLOBAL::more_composites eq "y" ) {
		print "Would you like each composite to differ by moving the streak by $GLOBAL::thickness pixels [y|n]?";
		$GLOBAL::streak_move_composites = <STDIN>;
		$GLOBAL::streak_move_composites =~ s/\n$//;
	}

	#loop through each value and do the Magick on the image files
	my $time = "";
	my ( $crop_width, $crop_height, $x_loc, $y_loc );
	my $comp_x = 0;
	my $comp_y = 0;
	# if we are doing multiple composites, loop thrtough them
	my $comp_path;
	if ( $GLOBAL::more_composites ne "y" ) {
		$GLOBAL::number_streaks = 1;
	}
		
	for ( my $num = $GLOBAL::number_streaks; $num >=1; $num-- ) {
		if ( $GLOBAL::streak_move_composites eq "y" ) {
			$GLOBAL::location += $GLOBAL::thickness;
		}
	# loop through the directory
	my $count = 0;
	foreach my $filename (@files) {
		$count += 1;
		if ( $GLOBAL::error == 0) {
			if ( $GLOBAL::more_composites ne "y" ) {
				print "$num of " . $GLOBAL::number_streaks . "\n";
			}
			print "$count of " . $files . ": $filename"."\n";
			my $image = new Image::Magick;
			
			### READ the image
			my $path = $GLOBAL::directory . $filename;
			print "\t-Reading $filename"."\n";
			my $x = $image->Read("$path");
				warn "$x" if "$x";
			
			### crop to the streak
			# first figure out the orientation
			if ( $GLOBAL::orientation eq "v" ) {
				$crop_width = $GLOBAL::thickness;
				$crop_height = $GLOBAL::height;
				$x_loc = $GLOBAL::location;
				$y_loc = "0";	
			}
			if ( $GLOBAL::orientation eq "h" ) {
				$crop_width = $GLOBAL::width;
				$crop_height = $GLOBAL::thickness;
				$x_loc = "0";
				$y_loc = $GLOBAL::location;
			}
			print "\t-Cropping to a streak at $GLOBAL::location pixels $GLOBAL::thickness thick"."\n";
			$x = $image -> Crop( width=>"$crop_width", height=>"$crop_height", x=>"$x_loc", y=>"$y_loc");
				warn "$x" if "$x";
				
				# progress the streak if needed
				if ( $GLOBAL::progress = 'y' ) {
					$GLOBAL::location += $GLOBAL::thickness;
				}
			
			#composite the image on the composite image - we're not storing this in memory, we're writing it each time!
			#$composite = new Image::Magick;
			#$x = $composite->Read("$comp_path");
			#	warn "$x" if "$x";
			
			if ( $GLOBAL::orientation eq "v" ) {
				$x = $composite -> Composite ( image=>$image, compose=>'over', x=>$comp_x, y=>0 );
				warn "$x" if "$x";
				$comp_x += $GLOBAL::thickness;
			}
			
			if ( $GLOBAL::orientation eq "h" ) {
				$x = $composite -> Composite ( image => $image, compose => 'over', x => '0', y => $comp_y );
				warn "$x" if "$x";
				$comp_y += $GLOBAL::thickness;
			}
			
			## SAVE the new image 
			#$path = $GLOBAL::directory .'streak_image/'. $filename;
			#$path =~ s/\.\w\w\w$/\.tif/;
			#print "\tSaving $path"."\n";
			#$x = $image->Write("$path");
			#	warn "$x" if "$x";
			#$time = "1"; # so it can go through all the images
			print "\t-Added $filename to the composite"."\n";
		}
	
		close DIRECTORY;
		close FILEHANDLE;
	}
	# write the composite:
	$comp_path = $GLOBAL::directory . 'streak_image/streak' . $num . '.tif';
	$x = $composite->Write("$comp_path");
			warn "$x" if "$x";
	
	}
}
