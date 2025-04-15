#!c:/perl -w
# use strict;
use Image::Magick;

### Variables
#Directory is the path to the directory containing the images to be resized
$GLOBAL::directory = "blank";

#Set the size of the longest dimension here
my $imagesize = 1500;

print "\n\nDirectory Image Resizer\n
Takes every tif,jpg,gif and psd file in a given directory,
and saves each as an 800 pixel JPG file in new subdirectory called '800jpgs'.
Directory Resizer will not go down subdirectories,
nor alter or erase the original image files.
If you point Image Resizer to a single file, it will not create a new
directory for the cropped image, but rather will save the image in the
same directory as the original file.

If you wish to simply resize a single image:
\tType in the full path of the image.
If you wish to crop every image in a directory:
\tType in the FULL path of the directory ending with a / or a \\.
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

print "\n\nResize to? (longest dimension in pixels)";
	
	$imagesize = <STDIN>;
	$imagesize =~ s/\n$//;

	my ( $singlefile, $newpath, @files );
	if ( ( $GLOBAL::directory =~ /\/$/ ) or ( $GLOBAL::directory =~ /\\$/ ) ) {
		#Open the directory
		if ( opendir(DIRECTORY, "$GLOBAL::directory") ) {
			@files= readdir(DIRECTORY);
			mkdir "$GLOBAL::directory". $imagesize . "jpg" or warn "\n\tThe directory '$GLOBAL::directory". $imagesize . "jpg' already exists. Writing to the existing directory.";
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
#			mkdir "$GLOBAL::directory/1500jpgs" or warn "\n\tThe directory '$GLOBAL::directory/1500jpgs' already exists. Writing to the existing directory.";
		}
		else {
			print "\n\tThe File $GLOBAL::directory either doesn't exist or can't be openned\n";
			$GLOBAL::error = 1;
		}
	}

	my $we_have_an_image="no";
	#loop through each value and do the Magick on the image files
	foreach my $filename (@files) {
		if ( $GLOBAL::error == 0) {

		if ( ($filename =~ /\.tif/) or ($filename =~ /\.TIF/) or
			($filename =~ /\.jpg/) or ($filename =~ /\.JPG/) or
			($filename =~ /\.psd/) or ($filename =~ /\.PSD/) or
			($filename =~ /\.gif/) or ($filename =~ /\.GIF/)) {
			$we_have_an_image = 'yes';
			print "$filename"."\n";
	
			my $image = new Image::Magick;
	
			### READ the image
			my $path;
			if ( $singlefile ) { 
				$path = $GLOBAL::directory;
			}
			else { 
				$path = $GLOBAL::directory . $filename;
			}
			print "\tReading $filename"."\n";
			my $x = $image->Read("$path");
				warn "$x" if "$x";
				
#			### Flatten the image
#			print "\tFlattening $filename"."\n";
#			$x = $image->Flatten();
#				warn "$x" if "$x";
			
	
			### Resize the image
			print "\tResizing $filename"."\n";
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
			$x = $image->Set( quality=>'100' );
				warn "$x" if "$x";
			if ( $singlefile ) { 
				$path = $GLOBAL::directory;
			}
			else { 
				$path = $GLOBAL::directory . $imagesize . 'jpg/'. $filename;
			}
			$path =~ s/\.\w\w\w$/\.jpg/;
			print "\tSaving $path"."\n";
			$x = $image->Write("$path");
				warn "$x" if "$x";
		}
		}
		close DIRECTORY;
		close FILEHANDLE;
	}

	if ( $we_have_an_image eq "no" ) {
		print"\n\tNo tif,jpg,gif, or psd file can be found at $GLOBAL::directory\n";
	
	}
}
