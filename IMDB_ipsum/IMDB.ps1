$DebugPreference = "continue"
$ErrorPreference = "stop"
$s3cmd = "python c:\s3cmd\s3cmd"
$here = "C:\anchor\hackfest\IMDB\"

$bucket="imdbipsum"


$RawContent = $Here+"raw_content\quotes_clean.txt"
$QuotesFolder = $Here+"Quotes"

$RawContent, $QuotesFolder | % { if (!(test-path $_)) { $suppress  = new-item -itemtype directory $_ } }

"" | out-file "IMDB.log" 
function out ($text) {
	"$(get-date) - $text" | out-file "IMDB.log" -append
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

#Make Quotes
out "Generating Quotes files..."

remove-item "$QuotesFolder\*"
$counter = 0;
$total = "lots" #(get-content $RawContent | measure-object -line).Lines
$maxcompute = 300000

$IpsumLines = 30

foreach ($_ in gc $RawContent)  { 
	$line = $_ -replace '\(([^\)]+)\)', ''
	
	$line = $_ -replace '\[([^\)]+)\]', ''
	if ($line -match ":") { 
		$Character = $line.split(':')[0]
		$Quote = ($line -replace "$Character", "").replace(": ","").replace("`"","")
		#"
		$CharFile = $QuotesFolder+"\"+$Character.replace(" ","_")+".html"
		if ($Character -notmatch '[#$é]') { 
		"quotes.push(`""+$Quote+" `");" | out-file $CharFile -append
		}
	} 
	$counter++
	if ($counter % 100 -eq 0  ) { out "$Counter of $total lines processed" }
	if ($counter -gt $maxcompute) { out "Breaking out of loop at $maxcompute records"; break} 
}



out "Make into pretty html files"
$prepend = "<a href=`"..\index.html`">Back</a> <i>F5 for new content</i><br><br><script language=`"javascript`" type=`"text/javascript`">"
$prepend +="var quotes = new Array(); "
$append ="var max = $IpsumLines; for (var i=0; i<max; i++) {selected = quotes[Math.floor(Math.random() * quotes.length)];"
$append += "document.write(selected);	;} </script> </p></body></html>"
$counter = 0;
gci $QuotesFolder | % { 
	$file = "$QuotesFolder\$_"
	if ( (get-content $file | measure-object -line).Lines -gt $IpsumLines) { 
		$Content = get-content  $file	
		$Char = $_.name.replace(".html","").replace("_"," ")
		"<h1>The Utterances of $Char </h1>" | set-content $file
		$prepend | add-content $file
		$Content | add-content $file
		$append | add-content $file
	} else { remove-item $file }
	$counter++; if ($counter % 100 -eq 0) { out "$counter records html'd" }
}
#>

"Geneating Index File..."


$index = "index.html"
function inapp ($text) { $text | out-file $index -append }

$indexCont = "<h1>IMDB Ipsum</h1><p><i><li> use case of quotes from <a href=`"http://www.imdb.com/interfaces`">imdb interfaces</a>"
$indexCont += "<li>Manipulate with powershell<li>Upload to <a href=`"http:\\support.beta.anchortrove.com/index.html`">Anchor Trove</a>"
$indexCont += "<li>...<li>Profit!</i><br><br><h2>Choose a Character</h2>"

 $indexCont | out-file $index
 
 inapp "Jump to Letter: "
97..122 | % { 
	$Ch = [char]$_
	inapp "<a href=`"#$ch`">$ch<a>"
	}

97..122 | % { 
	$Ch = [char]$_
	inapp "<br><br><a name=`"#$ch`">Characters being with <b>$CH</b><br/>"
	gci "$QuotesFolder\$Ch*" | %{ 
		$file = $_.name.split('\')[-1]
		$char = $file.replace(".html","")
		inapp "<a href=`"Quotes\$file`">$char</a> " 
	}

} 

out "upload..."

invoke-expression "$s3cmd put $index  s3://$bucket/ --acl-public"

invoke-expression "$s3cmd put Quotes --recursive s3://$bucket/ --acl-public"


out "Script END"#>
