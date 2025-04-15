#!c:/perl -w
use strict;
use Image::Magick;

### Variables
#Directory is the path to the directory containing the images to be resized
$GLOBAL::directory = "blank";

#Set the size of the longest dimension here
my $imagesize = 350;

print "\n\nDirectory Image GIF Animator\n
Takes every tif,jpg,gif file in a given directory,
and builds an animated GIF. Images will be sequenced in alpha order.
Image GIF Animator will not go down subdirectories,
nor alter or erase the original image files.\n


\tType in the FULL path of the directory ending with a / or a \\.
";

while ( ( $GLOBAL::directory ne "quit" ) or ( $GLOBAL::directory ne "exit" ) ) {
	$GLOBAL::error = 0;
	print "\nPlease input the path to the image or directory
	\tExample:
	\tDirectory: C:/Jeff's Work/Images/Mars Pictures/
	Path ( or 'quit' to exit)";
	
	$GLOBAL::directory = <STDIN>;
	$GLOBAL::directory =~ s/\n$//;

	my ( $singlefile, $newpath, @files );
	if ( ( $GLOBAL::directory =~ /\/$/ ) or ( $GLOBAL::directory =~ /\\$/ ) ) {
		#Open the directory
		if ( opendir(DIRECTORY, "$GLOBAL::directory") ) {
			@files= readdir(DIRECTORY);
			mkdir "$GLOBAL::directory"."gif" or warn "\n\tThe directory '$GLOBAL::directory"."gif' already exists. Writing to the existing directory.";
		}
		else {
			print "\n\tThe Directory $GLOBAL::directory either doesn't exist or can't be openned\n";
			$GLOBAL::error = 1;
		}
	}

	else {	
		if (open FILEHANDLE, "$GLOBAL::directory") {
			push @files, $GLOBAL::directory;
			$singlefile = 'true';
#			mkdir "$GLOBAL::directory/gif" or warn "\n\tThe directory '$GLOBAL::directory/gif' already exists. Writing to the existing directory.";
		}
		else {
			print "\n\tThe File $GLOBAL::directory either doesn't exist or can't be openned\n";
			$GLOBAL::error = 1;
		}
	}

	close DIRECTORY;
	close FILEHANDLE;
	
	my $we_have_an_image="no";
	#loop through each value and do the Magick on the image files
	my $image = new Image::Magick;
	my $x;
	my $path;
	my @images;
	foreach my $filename (@files) {
		if ( $GLOBAL::error == 0) {

			if ( ($filename =~ /\.tif/) or ($filename =~ /\.jpg/) or ($filename =~ /\.JPG/) or ($filename =~ /\.psd/) or ($filename =~ /\.gif/) ) {
				$we_have_an_image = 'yes';
				print "$filename"."\n";
				
				$filename = $GLOBAL::directory . "/" . $filename;
				push @images,$filename;
	
				
			
	
			}
		}
		
	
	}
	
	
	print "\tReading...."."\n";
	$x = $image->Read(@images);
		warn "$x" if "$x";
	
	### Resize the image
	print "\tResizing "."\n";
	my ( $width, $height ) = $image->Get( 'columns', 'rows' );
	my ( $newthumbwidth, $newthumbheight);
	if ( $width > $height ) {
		$newthumbwidth = $imagesize;
		$newthumbheight = ( $imagesize/$width ) * $height;
	
	}
	else {
		$newthumbheight = $imagesize;
		$newthumbwidth = ( $imagesize/$height ) * $width;
						
	}
	
	$x = $image->Scale(width=>"$newthumbwidth", height=>"$newthumbheight");
	warn "$x" if "$x";
	
	## SAVE the new image 
	$x = $image->Set( quality=>'50' );
		warn "$x" if "$x";
	$x = $image->Set( delay=>'40' );
		warn "$x" if "$x";
	$x = $image->Set( monochrome=>'True' );
		warn "$x" if "$x";
	if ( $singlefile ) { 
		$path = $GLOBAL::directory;
	}
	else { 
		$path = $GLOBAL::directory .'gif/'. 'movie.gif';
	}
	print "\tSaving $path"."\n";
	
	$x = $image->Write("$path");
	warn "$x" if "$x";
	
	if ( $we_have_an_image eq "no" ) {
		print"\n\tNo tif,jpg,gif, or psd file can be found at $GLOBAL::directory\n";
	
	}
}
