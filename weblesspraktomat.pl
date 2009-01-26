#!/usr/bin/perl
# (c) 2009 Simon Stroh <ps@k0de.de>
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

use WWW::Mechanize;
use strict;
use warnings;

# Edit these as you please
# username in Praktomat
my $username = "tut_foo";
# password in Praktomat
my $password = "geheimespasswort";
# directory to download the data into
my $datadir = "data";
# verbose output?
my $verbose = 1;
# start and stop vpnc?
my $start_vpnc = 1;
# matrikel numbers
my @numbers = (
	1234567,
	1234568,
	1234569,
	1234570,
	1234571,
);
# enable this to make the Program work.
my $work = 0;
#end of configuration

$work || die "please edit the configuration (in this file).\n";
$^O =~ /win/ && die 	"This program has _not_ been tested under windows. It uses system(),\n".
			"directly creates paths, and probably does other evil foodoo, that won't\n".
			"work with legacy OS's. You should consider upgrading.\n";

my $mech = WWW::Mechanize->new();
$mech->credentials( $username => $password );

$start_vpnc && system('sudo vpnc-connect');

my $arg = $ARGV[0] || '';
if($arg eq 'get') {
	download_testing($mech);
}
elsif ($arg eq 'put') {
	commit($mech);
}
elsif ($arg eq 'start') {
	my $task = $ARGV[1] || '';
	$task =~ /^\d+$/ || die("Invalid task :-(\n");
	for my $num (@numbers) {
		start_testing($mech, $num, $task);
	}
}
else {
	print "valid options: get, put, start [number]\n";
}

$start_vpnc && system('sudo vpnc-disconnect');

sub commit {
	my $mech = shift;
	$mech->get("https://praktomat.info.uni-karlsruhe.de/praktomat_2008_WS");
	my @working = grep {$_->text() =~ /in Bearbeitung/} grep {$_->url() =~ /OpenDocumentPage/} $mech->find_all_links();
	for my $studdir (<$datadir/*>) {
		$studdir =~ m{.*/(.+)$};
		my $matnr = $1;
		for my $taskdir (<$studdir/*>) {
			$taskdir =~ m{.*/(.+)$};
			my $task = $1;
			my $textfeld = slurp($taskdir."/_textfeld.txt");
			my $bewertungsfeld = slurp($taskdir."/_bewertungsfeld.txt");
			my $aufdenweggeben = slurp($taskdir."/_aufdenweggeben.txt");
			my $punktezahl = slurp($taskdir."/_punktezahl.txt");
			my ($link) = grep {$_->url() =~ m{review/$matnr/$task}} @working;
			die unless $link;
			$mech->get($link->url());
			$mech->form_with_fields("solution", "annotated_solution");
			$mech->set_fields(
				"annotated_solution" => $textfeld,
				"comment_rating" => $bewertungsfeld,
				"comment_general" => $aufdenweggeben,
				"review_comment" => $punktezahl,
			);
			$mech->click_button(name => "PreviewJudgmentPage");
			$verbose && print "Uploading Mat: $matnr Aufg: $task\n";
		}
	}
}

sub download_testing {
	my $mech = shift;
	$mech->get("https://praktomat.info.uni-karlsruhe.de/praktomat_2008_WS");
	my @working = grep {$_->text() =~ /in Bearbeitung/} grep {$_->url() =~ /OpenDocumentPage/} $mech->find_all_links();
	for my $link (@working) {
		$link->url() =~ m{review/(\d+)/(\d+)/};
		my $matnr = $1;
		my $task = $2;
		$verbose && print "Getting   Mat: $matnr Aufg: $task\n";
		$mech->get($link);
		mkdir $datadir."/".$matnr;
		mkdir $datadir."/".$matnr."/".$task;
		my $form = $mech->form_with_fields("solution", "annotated_solution");
		my ($textarea) = grep {$_->name() eq 'annotated_solution'} @{$form->{inputs}};
		my @list = content_split($textarea->{value});
		for my $file(@list) {
			open(my $output, ">", $datadir."/".$matnr."/".$task."/".$file->[0]) || die $!;
			print $output $file->[1];
			close $output;
		}
		open(my $output, ">", $datadir."/".$matnr."/".$task."/_textfeld.txt") || die $!;
		print $output $textarea->{value};
		close $output;
		my $field;
		open($output, ">", $datadir."/".$matnr."/".$task."/_bewertungsfeld.txt") || die $!;
		($field) = grep {$_->name() eq 'comment_rating'} @{$form->{inputs}};
		print $output $field->{value};
		close $output;
		open($output, ">", $datadir."/".$matnr."/".$task."/_aufdenweggeben.txt") || die $!;
		($field) = grep {$_->name() eq 'comment_general'} @{$form->{inputs}};
		print $output $field->{value};
		close $output;
		open($output, ">", $datadir."/".$matnr."/".$task."/_punktezahl.txt") || die $!;
		($field) = grep {$_->name() eq 'review_comment'} @{$form->{inputs}};
		print $output $field->{value};
		close $output;
		$mech->back();
	}
}

sub start_testing {
	my $mech = shift;
	my $matnr = shift;
	my $task = shift;
	$verbose && print "Starting  Mat: $matnr Aufg: $task\n";
	$mech->get("https://praktomat.info.uni-karlsruhe.de/praktomat_2008_WS");
	my ($link) = grep {$_->url() =~ /JudgeSolutionPage$/} $mech->find_all_links();
	$mech->get($link->url());
	$mech->form_with_fields("a_user_id", "task");
	$mech->set_fields("a_user_id" => $matnr, "task" => $task);
	$mech->click_button(name => "PickJudgmentPage");
	$mech->content =~ /hat keine L..?sung f..?r Aufgabe / && print "no solution.\n";
	$mech->content =~ /wird gerade testiert/ && print "already there.\n";
	$mech->content =~ /Benutzer nicht gefunden/ && print "no such user.\n";
}

sub content_split {
	my $str = shift;
	my @out;
	for my $line (split /\n/, $str) {
		if($line =~ /^	=== (.+) ===$/) {
			push @out, [$1, ""];
		}
		elsif($line =~ /^	--- (.+) ---$/) {
		}
		elsif($#out == -1) {
			next;
		}
		else {
			$out[$#out][1] .= "$line\n";
		}
	}
	return @out;
}

sub slurp {
	my $filename = shift;
	open(my $in, "<", $filename) || die $!." $filename\n";
	my $cont = do{local$/;<$in>};
	close $in;
	return $cont;
}
