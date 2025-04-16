#!c:/perl -w
# use strict;
use Image::Magick;

### Variables
#Directory is the path to the directory containing the images to be resized
$GLOBAL::directory = "blank";

#Set the size of the longest dimension here
my $imagesize = 800;

print "\n\nDirectory Printer Outer\n
Takes every tif,jpg and gif file in a given directory and prints out their file names as a comma delimited text.

If you wish to name every image in a directory:
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
		$GLOBAL::output = $GLOBAL::output . "$filename, ";
	}
	open CATEGORY , ">filenames.txt" or warn "Can't open file ../../$global::username/category$catpage.html to write image html to.";
	print CATEGORY $GLOBAL::output;

	if ( $we_have_an_image eq "no" ) {
		print"\n\tNo tif,jpg,gif, or psd file can be found at $GLOBAL::directory\n";
	
	}
}
