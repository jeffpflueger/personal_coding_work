<?php
header('Content-Type: application/vnd.google-earth.kml+xml');

function DMStoDEC($deg,$min,$sec) {

	// Converts DMS ( Degrees / minutes / seconds ) 
	// to decimal format longitude / latitude
    return $deg+((($min*60)+($sec))/3600);
}    

## sanitize GET
$folder = preg_replace('/[^-a-zA-Z0-9_\/]/', '', $_GET['folder']);

## begin output
echo "<?xml version='1.0' encoding='UTF-8'?>\n
<kml xmlns='http://www.opengis.net/kml/2.2'>\n
  <Document>\n
";
    
# get Pantheon ENV variables for DB connection
$db_host = $_ENV['DB_HOST'];
#echo "DB host:" . $db_host . "<br>";

$db_port = $_ENV['DB_PORT'];
#echo "DB port:" . $db_port . "<br>";

$db_name = $_ENV['DB_NAME'];
#echo "DB Name:" . $db_name . "<br>";

$db_user = $_ENV['DB_USER'];
#echo "DB User:" . $db_user . "<br>";

$db_password = $_ENV['DB_PASSWORD'];
#echo "DB password:" . $db_password . "<br>";

# Create connection
$conn = new mysqli($db_host, $db_user, $db_password, $db_name, $db_port );

# Check connection
if ($conn->connect_error) {
    die("Connection failed: " . $conn->connect_error);
} 

#DB QUERY
$query = "SELECT
				http_path,
				thumb_http,
				headline,
				description,
				keywords,
				http_path,
				additional_path,
				gps_latitude,
				gps_longitude,
				gps_altitude
				FROM
				dameasy
				WHERE additional_path REGEXP '^" . "$folder" . "'
				ORDER BY id DESC
				";

$result = $conn->query($query);

while ( $row = $result -> fetch_assoc() ){
	$http_path  = $row['http_path'];
	$thumb_http  = $row['thumb_http'];
	$headline  = $row['headline'];
	$description  = $row['description'];
	$keywords  = $row['keywords'];
	$http_path  = $row['http_path'];
	$additional_path  = $row['additional_path'];
	$gps_latitude  = $row['gps_latitude'];
	$gps_longitude  = $row['gps_longitude'];
	$gps_altitude  = $row['gps_altitude'];
	
		## Create GPS
		$gps = '';
		$gps_linkns;
		$gps_linkew;
		if ( $gps_latitude != '' ) {
		#latitude
			$latsec = $gps_latitude;
			preg_match("/^([0-9]{1,3})/", $gps_latitude, $found);
			$latint = $found[0];
			
			preg_match("/(.{1})$/", $gps_latitude, $found) ;
			$ns = $found[0];

			preg_match("/([0-9]{1,2})\'/", $gps_latitude, $found);
			$latmin = $found[0];
			
			preg_match("/([0-9\.]{2,6})\"/", $gps_latitude, $found );
			$latsec = $found[0];
			
			$decimal_degreesns = DMStoDEC($latint, $latmin, $latsec);
			$gps_linkns = $decimal_degreesns;
			
			if ( $ns == "S" ) {
				$gps_linkns = 0 - $gps_linkns;
			}
			
			#longitude
			$longsec = $gps_longitude;
			
			preg_match("/^([0-9]{1,3})/", $gps_longitude, $found);
			$longint = $found[0];

			preg_match("/(.{1})$/", $gps_longitude, $found);
			$ew = $found[0];

			preg_match("/([0-9]{1,2})\'/", $gps_longitude, $found);
			$longmin = $found[0];

			preg_match("/([0-9\.]{2,6})\"/", $gps_longitude, $found);
			$longsec = $found[0];

			$decimal_degreesew = DMStoDEC($longint, $longmin, $longsec);
			
			$gps_linkew = "$decimal_degreesew";
			if ( $ew == "W" ) {
				$gps_linkew = 0 - $gps_linkew;
			}

			#altitude
			$gps_altitude = preg_replace("/([A-Za-z\s])/", "", $gps_altitude );
		}
			
	# make this placemark
	$http_path = "http://photomountains.com" . $http_path;
	$thumb_http = "http://photomountains.com" . $thumb_http;
	if ( ( $gps_linkew != '' ) and ( $gps_linkns != '' ) ) {
		print "<Placemark>\n";
	#	print "<name>$headline</name>\n";
		print "<description>\n
		 <![CDATA[
          <p class='map'>$headline<br>\n
          <a href='$http_path'>Click here for more detail</a></p>\n
          <a href='$http_path'><img src='$thumb_http' alt='$description'></a>\n
          
     	   ]]>
     	 </description>\n
    	  <Point>\n
    	    <coordinates>$gps_linkew,$gps_linkns</coordinates>\n
    	    <altitude>$gps_altitude</altitude>\n
    	    <altitudeMode>absolute</altitudeMode>\n
   	   </Point>\n
  	  </Placemark>\n
		";
	}	
}

# end output
print "
	</Document>\n
</kml>\n";

$result->close();
$conn->close();

?>