#!c:/perl -w
# use strict;
use Image::Magick;

### Variables
#Directory is the path to the directory containing the images to be cropped
$GLOBAL::directory = "blank";

#Fuzz value is up to 256 for Q8 ImageMagick, and 65536 (256x256) for Q16
#can be set as a percentage of the total value, but causes errors in Perl
my $fuzz = 30000;

#Shave is the number of pixels to trim from the border after the autocrop. This
#will produce a crisp edge. %1.44 works with rounded corners %1.25 works with others.
my $shave = "1.25%";

print "\n\nDirectory Image Cropper\n
Takes every tif,jpg,gif and psd file in a given directory,
crops the edges of each image,
and saves each as a Photoshop file in new subdirectory called 'cropped'
with a 'c' added to the end of the filename for 'cropped'.
Especially useful for slides scanned that have a black, jagged border.
Directory Cropper will not go down subdirectories,
nor alter or erase the original image files.
If you point Image Cropper to a single file, it will not create a new
directory for the cropped image, but rather will save the image in the
same directory as the original file.

If you wish to simply crop a single image:
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

	my ( $singlefile, $newpath, @files );
	if ( ( $GLOBAL::directory =~ /\/$/ ) or ( $GLOBAL::directory =~ /\\$/ ) ) {
		#Open the directory
		if ( opendir(DIRECTORY, "$GLOBAL::directory") ) {
			@files= readdir(DIRECTORY);
#			foreach my $element ( @files ) { print "$element\n"; }
#			exit;
			mkdir "$GLOBAL::directory"."cropped" or warn "\n\tThe directory '$GLOBAL::directory"."cropped' already exists. Writing to the existing directory.";
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
#			mkdir "$GLOBAL::directory/cropped" or warn "\n\tThe directory '$GLOBAL::directory/cropped' already exists. Writing to the existing directory.";
		}
		else {
			print "\n\tThe File $GLOBAL::directory either doesn't exist or can't be openned\n";
			$GLOBAL::error = 1;
		}
	}

	my $we_have_an_image="no";
	#loop through each value and do the Magick on the image files
	foreach my $filename (@files) {
		unless ( $filename =~ /\._/) {
	
			if ( $GLOBAL::error == 0) {

			if ( ($filename =~ /\.tif/) or ($filename =~ /\.jpg/) or ($filename =~ /\.psd/) or ($filename =~ /\.gif/) ) {
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
	
				### CROP the image
				print "\tCropping $filename"."\n";
				print "\t\tFuzz $fuzz"."\n";
				$x = $image->Set(fuzz=>"$fuzz");
					warn "$x" if "$x";
				$x = $image->Crop(height=>0, width=>0);
					warn "$x" if "$x";
	
				## SHAVE the image
				print "\tShaving $filename"."\n";
				print "\t\tShave $shave"."\n";
				$x = $image->Shave( geometry=>"$shave x $shave" );
					warn "$x" if "$x";
				## SAVE the new image 
				if ( $singlefile ) { 
					$path = $GLOBAL::directory;
				}
				else { 
					$path = $GLOBAL::directory .'cropped/'. $filename;
				}
				$path =~ s/\.\w\w\w$/c\.psd/;
				print "\tSaving $path"."\n";
				$x = $image->Write("$path");
					warn "$x" if "$x";
			}
			}
			close DIRECTORY;
			close FILEHANDLE;
		}
	}

	if ( $we_have_an_image eq "no" ) {
		print"\n\tNo tif,jpg,gif, or psd file can be found at $GLOBAL::directory\n";
	
	}
}
