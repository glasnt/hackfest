
$DebugPreference = "continue"
$ErrorPreference = "stop"
$s3cmd = "python c:\s3cmd\s3cmd"
$here = "C:\anchor\hackfest\StarTrek\"

$bucket="lcarsipsum"


$ScriptsFolder = $Here+"Scripts"
$QuotesFolder = $Here+"Quotes"
$QuoteHtml = "QuoteHtml"

$ScriptsFolder, $QuotesFolder, $QuoteHtml| % { if (!(test-path $_)) { $suppress  = new-item -itemtype directory $_ } }

$IpsumLines = 15
$IpsumCharacters = 10

function out ($text) {
	"$(get-date) - $text" | out-file "Startrek.log" -append
	$text
}

out "Script START"

function s3cmd ($cmd) { invoke-expression "python c:\s3cmd\s3cmd $cmd" }
function upload ($file, $rename="", $bucket="" ) { 
	test-path $file
	if (!$bucket) { $bucket = "s3://$Bucket_Default"} else {$bucket = "s3://$bucket" }
	write-debug "UPLOAD: $file to bucket $bucket rename $rename"
	$s3cmd = "$s3cmd put $file $bucket/$rename --acl-public"
	invoke-expression $s3cmd 
	
} 

function download ($URL, $Folder="", $file="") { 
	out "Downloading $File ..."
	$File = "$Folder\$File"
	$client = New-Object System.Net.WebClient
	try {  $client.DownloadFile($URL,$file)  }
	catch { 
		$Output = $_.Exception.Message;
		if ($output -match "404") {
			write-debug "File $URL 404.. skipping...";} 
		else { write-error $output}
	}	
}


$Source = "http://www.chakoteya.net/NextGen/"
$First = 101
$Last = 227
$Ext = ".htm"


out "Acquiring scripts..."
for ($i=$First; $i -le $Last; $i++) { 
	$file = "$i$Ext"
	$url = "$Source$File"
	download $url $ScriptsFolder $file	
}

#Make Quotes
out "Generating Quotes files..."
gci $ScriptsFolder | % {
	get-content "$ScriptsFolder\$_" | % { 
	if ($_ -notmatch "\[") { 
		$Person = $_.split(": ")[0]
		$Quote = $_.replace("$($Person): ", "").Replace("<br>","")
		$File = "$QuotesFolder\$Person.txt"
		if ([string]::Compare($Person,$Person.ToUpper()) -eq 0) { 
				$Quote | out-file $File -append
			#
		}
	}}
}
#Cleanup

out "Cleanup..."
if (test-path "$QuotesFolder\.txt") { remove-item "$QuotesFolder\.txt" }
gci $QuotesFolder | % { 
	$FileName = "$quotesFolder\$_" 
	$LineCount  +=  (get-content $FileName | measure-object -line).Lines
	if ((get-content $FileName | measure-object -line).Lines -lt $IpsumLines) { Remove-item $FileName; "$Filename culled due to size" }
	if (!($_.name.replace(".txt","") -match [regex]"^[A-Z]*$")) { REmove-Item $Filename; "$Filename culled due to invalid chars" }
}


out "Downloaded $((gci $ScriptsFolder).count) scripts, got $((gci $QuotesFolder).count) quote files, totalling $LineCount lines"

$landing = "landing.html"
$index = "index.html"
gc "index_pre.txt" | out-file $index

$charcount = 0
 gci  $QuotesFolder | sort-object length -descending | select -first 10 | %  { 
	$prepend = "<html><head><body color=`"white`"><p>`n<script language=`"javascript`" type=`"text/javascript`">`nvar quotes = new Array(); "
	$append = "var max = $IpsumLines; for (var i=0; i<max; i++) {selected = quotes[Math.floor(Math.random() * quotes.length)];document.write(selected);	;} </script> `n</p>`n</body>`n</html>"
	$Character =$_.name.replace(".txt","")
	$outFile  = "$here\$QuoteHtml\$Character.html"	
	$prepend  | out-file $outFile	
	$qcount = 0
	out "Generating $Character quotes..."
	gc "$QuotesFolder\$_" |  %{ 
		"quotes[$qcount] = `"$_`";" | out-file $outFile -append
		$qcount++
	}
	$append  | out-file $outFile -append
	"<li><a href=`"$QuoteHTML\$Character.html`" target=`"quotes`">$Character</a></li>"| out-file $index -append
	
	$charcount++
}
gc "index_post.txt" | out-file $index -append

$index, $landing | % { invoke-expression "$s3cmd put $_ s3://$bucket/ --acl-public" }
invoke-expression "$s3cmd put $QuoteHtml --recursive s3://$bucket/ --acl-public"

invoke-expression "$s3cmd put images --recursive s3://$bucket/ --acl-public"

invoke-expression "$s3cmd put css --recursive s3://$bucket/ --acl-public"

out "Script END"