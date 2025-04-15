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

print "\n\nConvert to TIFF\n
Takes every psd file in a given directory,
and saves another version as a TIF file by the same name.
in the same directory.

If you wish to simply convert a single image:
\tType in the full path of the image.
If you wish to convert every image in a directory:
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

		if ( ($filename =~ /\.psd/) ) {
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
				
			## FLATTEN the PSD image ....creating a new image object...
			print "\tFlattening $filename"."\n";
			$image = $image->Flatten();
				
			## set the COMPRESSION of the TIF  	
			print "\tSetting Compression to LZW"."\n";
			$x = $image->Set( compression=>"LZW" );
				warn "compression setting $x" if "$x";
				
			$x = $image->Set( magick=>"tif" );
				warn "magick setting $x" if "$x";
			
			## SAVE the new image 
			if ( $singlefile ) { 
				$path = $GLOBAL::directory;
			}
			else { 
				$path = $GLOBAL::directory . $filename;
			}
			$path =~ s/\.\w\w\w$/\.tif/;
			print "\tSaving $path"."\n";
			$x = $image->Write("$path");
				warn "$x" if "$x";
		}
		}
		close DIRECTORY;
		close FILEHANDLE;
	}

	if ( $we_have_an_image eq "no" ) {
		print"\n\tNo psd file can be found at $GLOBAL::directory\n";
	
	}
}
