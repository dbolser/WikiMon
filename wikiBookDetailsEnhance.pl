use strict;
use warnings;
use MediaWiki::API;
use List::MoreUtils qw(uniq);
use Data::Dumper qw(Dumper);
use Getopt::Long;
use Time::localtime;
use DateTime ();
use DateTime::Duration ();
use DateTime::Format::Natural ();
use DateTime::Format::HTTP;
use File::Basename;

###################### Usage #########################################
sub usage{
	my $fileName = basename($0);
	print "\n=======================================================================\n";
	print "Usage : \n";
	print $fileName . " --bookName <Name of the Book> --username <Username> --password <Password> [--date <Date>] [--NoBot] \n";
	print "-----------------------------------------------------------------------\n";
	print "bookName : It takes the name of the book as argument and get the details for it.\n";
	print "username : Username of for the login.\n";
	print "password : Password for the login.\n";
	print "date     : Changes details after the specified date has to be calculated.\n";
	print "NoBot    : It will remove all the bot user details from the output.\n";
	print "help     : It will print this help content.\n";
	
	print "=======================================================================\n";
	
}

###################### VARIABLES #####################################
my $bookNameToGetData = "";
my $dateTimeForComparision = "";
my $botFlg = 0;
my $helpFlg = 0;
my $username = "";
my $password = "";
##-------------------------------------------------------------#
my $MAX_CHANGED_PAGES = 5;
my %allPageChanges = ();
my %allPageChangesByEditCnt = ();
my %allUserChanges = ();
my %allEditors = ();
my $sizeOfEdits = 0;
my $allChangesCount = 0;
#####################################################################

GetOptions ("bookName=s"   => \$bookNameToGetData,
			"username=s"   => \$username,
			"password=s"   => \$password,
			"date=s"	   => \$dateTimeForComparision,
			"noBot" 	   => \$botFlg,
			"help"	       => \$helpFlg);


######################### Verify inputs #######################
if ($helpFlg == 1){
	usage();
	exit 0;
}
if($bookNameToGetData eq "" || $username eq "" || $password eq ""){
	usage();
	exit 1;
}


#################################################################
printf "Book Name        : %s\n" , $bookNameToGetData ;
if($dateTimeForComparision ne ""){
	printf "Start Date       : %s\n", $dateTimeForComparision;
}
print "========================================================\n";




 

my $mw = MediaWiki::API->new();
$mw->{config}->{api_url} = 'https://en.wikibooks.org/w/api.php';

#Login 
$mw->login( { lgname => $username, lgpassword => $password } )
  || die $mw->{error}->{code} . ': ' . $mw->{error}->{details};


# Convert the given date as argument to object.
my $datetimeFormatNow = "";
if($dateTimeForComparision ne ""){
	$datetimeFormatNow=  DateTime::Format::HTTP->parse_datetime($dateTimeForComparision);
}

# list of Pages for " " in different languages.
my $allPages = $mw->api( {
action => 'query',
prop => 'links',
pllimit=> '100000',
titles=> $bookNameToGetData	} )
|| die $mw->{error}->{code} . ': ' . $mw->{error}->{details};

my @allPagesArr = keys %{ $allPages->{query}->{pages}};
foreach ( @{ $allPages->{query}->{pages}->{$allPagesArr[0]}->{links}} )
{
	getDetailsForEachPage($_->{'title'});
	
}


##############################################
## Prints the Output
printf "Total number of edits       : %s\n" , $sizeOfEdits;
my @allEditorsArr = keys %allEditors;
printf "Total number of editors     : %s\n" , ($#allEditorsArr +1);
printf "Total change                : %s\n" , $allChangesCount ;


## Prints the top 5 pages by the size of the change.
my $changesPageCount = 0;
print "Top 5 changed pages by size : " . "\n";
foreach my $pageName (sort { $allPageChanges{$b} <=> $allPageChanges{$a} } keys %allPageChanges) {
    
	if($changesPageCount < $MAX_CHANGED_PAGES){
		printf "\t%-3s. %-50s : %s\n", $changesPageCount + 1, $pageName, $allPageChanges{$pageName};
	}
	$changesPageCount++;
}

## Prints top 5 changed pages by Editors.
my $changesPageCountByEdit = 0;
print "Top 5 changed pages by Edits : " . "\n";
foreach my $pageName (sort { $allPageChangesByEditCnt{$b} <=> $allPageChangesByEditCnt{$a} } keys %allPageChangesByEditCnt) {
    
	if($changesPageCountByEdit < $MAX_CHANGED_PAGES){
		printf "\t%-3s. %-50s : %s\n", $changesPageCountByEdit + 1, $pageName, $allPageChangesByEditCnt{$pageName};
	}
	$changesPageCountByEdit++;
}

### Prints the top 5 contributors by the size
my $changesEditorCount = 0;
print "Top 5 contributors by size  : " . "\n";
foreach my $pageName (sort { $allUserChanges{$b} <=> $allUserChanges{$a} } keys %allUserChanges) {
	
	if($changesEditorCount < $MAX_CHANGED_PAGES && $pageName ne ""){
		printf "\t%-3s. %-50s %s\n", $changesEditorCount + 1, $pageName, $allUserChanges{$pageName};
	}
	$changesEditorCount++;
}



sub getDetailsForEachPage{
	
	my ($pageTitle) = @_;
	# list of authors 
	my $allAuthors = $mw->api( {
	action => 'query',
	prop => 'revisions',
	rvprop=> 'user|size|timestamp',
	titles=> $pageTitle,
	rvlimit=> '10000000'	} )
	|| die $mw->{error}->{code} . ': ' . $mw->{error}->{details};

	my @arr= qw();
	my @keyArr = keys %{ $allAuthors->{query}->{pages}};
	
	my $count = 0;
	my $lastChageSize = 0;
	my $firstChageSize = 0;
	
	my $prevUser = "";
	my $prevSize = 0;
	my $countRev = 1;
	
	foreach ( @{ $allAuthors->{query}->{pages}->{$keyArr[0]}->{revisions}} )
	{		
		my $datetimeFormat = DateTime::Format::HTTP->parse_datetime($_->{'timestamp'});
		
		my $botProces = 1;
		if($botFlg == 1){
			
			my $ano = $_->{'anon'};
			if(!defined $ano){
				#print "OK " . $_->{'user'} . "\n";
				$botProces = 1;
			}else {
				$botProces = 0;
			}
			#print ">>" . $_->{'anon'} ."<<";
		}
		my $comparisionValue = 2;
		if($datetimeFormatNow ne ""){
			$comparisionValue = DateTime->compare($datetimeFormat,$datetimeFormatNow);
		
		}
        if($botProces == 1){               
			if($comparisionValue >= 0 ){
								
				if($count ==0){
					$lastChageSize = $_->{'size'};
				} else {
					$firstChageSize = $_->{'size'};
				}
				
				$count++;
				$countRev++;
				
				#print $datetimeFormat . " Second : " . $datetimeFormatNow . "\n";
				push @arr, $_->{'user'};	#add list of users in array
				my $userName = $_->{'user'};
				#if(exists %allUserChanges{$userName}){
				
				if($count != 0){
					if(exists $allUserChanges{$prevUser}){
						$allUserChanges{$prevUser} = $prevSize - $_->{'size'} + $allUserChanges{$prevUser} ; 
					}else {
						$allUserChanges{$prevUser} = $prevSize - $_->{'size'} ; 
					}
					#print $prevUser;
				}
				
				$prevUser = $_->{'user'};
				$prevSize = $_->{'size'};
				
				if(! exists $allEditors{$userName}) {
					$allEditors{$userName} = 1;
				}
			}
		}
		
	}	

	if(exists $allUserChanges{$prevUser}){
		$allUserChanges{$prevUser} = $prevSize  + $allUserChanges{$prevUser} ; 
	}else {
		$allUserChanges{$prevUser} = $prevSize ; 
	}
	my @uni= uniq(@arr);	#get unique editors name for each page
	if ($sizeOfEdits < 0)
		{
		 $sizeOfEdits = $sizeOfEdits * -1;
		 $sizeOfEdits = $sizeOfEdits + $#arr + 1;
	}else {
		$sizeOfEdits = $sizeOfEdits + $#arr + 1;
	}
		
	my $sizeOfEditors = $#uni +1;
	my $sizeOfEditsTmp = $#arr + 1;
	my $totalChanges = $lastChageSize - $firstChageSize;
	
	if ( $totalChanges  < 0){
		$totalChanges = $totalChanges * -1;
	}
	
	$allChangesCount = $allChangesCount + $totalChanges;
	
	## following hash contains the name of the page and the changes in that page. 
	$allPageChanges{$pageTitle} = $totalChanges;
	
	$allPageChangesByEditCnt{$pageTitle} = $count ;
}
