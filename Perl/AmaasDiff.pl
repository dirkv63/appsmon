=head1 NAME

AmaasDiff.pl - This script will show source ids per Category.

=head1 VERSION HISTORY

version 1.0 30 April 2015 DV

=over 4

=item *

Initial release.

=back

=head1 DESCRIPTION

This script will calculate the difference between two AMAAS Loads.

=head1 SYNOPSIS

 AmaasDiff.pl -f first_load_id -s second_load_id

 AmaasDiff -h	Usage
 AmaasDiff -h 1  Usage and description of the options
 AmaasDiff -h 2  All documentation

=head1 OPTIONS

=over 4

=item B<-f first_load_id>

Source ID for the first AMAAS File in the comparison.

=item B<-s second_load_id>

Source ID for the second AMAAS File in the comparison.

=back

=head1 ADDITIONAL DOCUMENTATION

=cut

###########
# Variables
########### 

my ($log, $dbh, $first_id, $second_id, $first_name, $second_name, $first_cnt, $second_cnt);

#####
# use
#####

use FindBin;
use lib "$FindBin::Bin/lib";

use warnings;			    # show warning messages
use strict 'vars';
use strict 'refs';
use strict 'subs';
use Getopt::Std;		    # Handle input params
use Pod::Usage;			    # Allow Usage information
use DBI();
use DbUtil qw(db_connect do_select);

use Log::Log4perl qw(get_logger);
use SimpleLog qw(setup_logging);
use IniUtil qw(load_ini get_ini);

################
# Trace Warnings
################

use Carp;
$SIG{__WARN__} = sub { Carp::confess( @_ ) };

#############
# subroutines
#############

sub exit_application($) {
    my ($return_code) = @_;
	if (defined $dbh) {
		$dbh->disconnect;
	}
	$log->info("Exit application with return code $return_code.");
	exit $return_code;
}

sub trim {
    my @out = @_;
    for (@out) {
        s/^\s+//;
        s/\s+$//;
    }
    return wantarray ? @out : $out[0];
}

######
# Main
######

# Handle input values
my %options;
getopts("h:f:s:", \%options) or pod2usage(-verbose => 0);
my $arglength = scalar keys %options;  
if ($arglength == 0) {			# If no options specified,
	$options{"h"} = 0;			# display usage.
} 
# Print Usage
if (defined $options{"h"}) {
    if ($options{"h"} == 0) {
        pod2usage(-verbose => 0);
    } elsif ($options{"h"} == 1) {
        pod2usage(-verbose => 1);
    } else {
		pod2usage(-verbose => 2);
	}
}
# Get ini file configuration
my $ini = { project => "appsmonitoring" };
my $cfg = load_ini($ini);
# Start logging
setup_logging;
$log = get_logger();
$log->info("Start Application");
if (defined $options{f}) {
	$first_id = $options{f};
} else {
	$log->fatal("First Source ID not defined, exiting...");
	exit_application(1);
}
if (defined $options{s}) {
	$second_id = $options{s};
} else {
	$log->fatal("Second Source ID not defined, exiting...");
	exit_application(1);
}
# End handle input values

# Make database connection for vo database
$dbh = db_connect("vo_appsmonitoring") or exit_application(1);

my $query = "SELECT src1.description first_name, src2.description second_name
			 FROM source src1, source src2
			 WHERE src1.id=$first_id
			   AND src2.id=$second_id";
my $ref = do_select($dbh, $query);
foreach my $arrayhdl (@$ref) {
	$first_name  = $$arrayhdl{first_name} || "";
	$second_name = $$arrayhdl{second_name} || "";
}

$query = "SELECT count(*) cnt
		  FROM amaas 
		  WHERE source_id=$first_id";
$ref = do_select($dbh, $query);
foreach my $arrayhdl (@$ref) {
	$first_cnt  = $$arrayhdl{cnt} || 0;
}

$query = "SELECT count(*) cnt
		  FROM amaas 
		  WHERE source_id=$second_id";
$ref = do_select($dbh, $query);
foreach my $arrayhdl (@$ref) {
	$second_cnt  = $$arrayhdl{cnt} || 0;
}

print "\n\nComparing Source Set \n$first_name ($first_cnt records)\nwith\n";
print "$second_name ($second_cnt records)";
# Get Applications in First Load not in Second Load
print "\n\nApplications In **$first_name**,\nNot In **$second_name**\n\n";
$query =  "SELECT appl.number, appl.name, am.category 
			  FROM amaas am, application appl 
			  WHERE am.source_id = $first_id 
			    AND appl.id=am.application_id
			    AND am.application_id NOT IN 
				(SELECT application_id FROM amaas WHERE source_id=$second_id)";
$ref = do_select($dbh, $query);
foreach my $arrayhdl (@$ref) {
	my $number = $$arrayhdl{number} || "";
	my $name = $$arrayhdl{name} || "";
	my $category = $$arrayhdl{category} || "";
	print "$number - $name - $category\n";
}

# Get Applications in Second Load not in First Load
print "\n\nApplications In **$second_name**,\nNot In **$first_name**\n\n";
$query =  "SELECT appl.number, appl.name, am.category 
			  FROM amaas am, application appl 
			  WHERE am.source_id = $second_id 
			    AND appl.id=am.application_id
			    AND am.application_id NOT IN 
				(SELECT application_id FROM amaas WHERE source_id=$first_id)";
$ref = do_select($dbh, $query);
foreach my $arrayhdl (@$ref) {
	my $number = $$arrayhdl{number} || "";
	my $name = $$arrayhdl{name} || "";
	my $category = $$arrayhdl{category} || "";
	print "$number - $name - $category\n";
}

# Get changes in category between loads
print "\n\nCategory Change between **$first_name**\nand **$second_name**\n\n";
$query = "SELECT appl.number, appl.name, am1.category category_1, am2.category category_2
		  FROM amaas am1, amaas am2, application appl 
		  WHERE am1.source_id = $first_id
			AND am2.source_id = $second_id
			AND am1.application_id = am2.application_id
			AND not (am1.category = am2.category)
			AND appl.id=am1.application_id";
$ref = do_select($dbh, $query);
foreach my $arrayhdl (@$ref) {
	my $number = $$arrayhdl{number} || "";
	my $name = $$arrayhdl{name} || "";
	my $category_1 = $$arrayhdl{category_1} || "";
	my $category_2 = $$arrayhdl{category_2} || "";
	print "$number - $name - $category_1 - $category_2\n";
}



print "\n\n";

exit_application(0);

=head1 To Do

=over 4

=item *

Check for CMDB ID 60833. Double 'maakt gebruik van' relation??

=back

=head1 AUTHOR

Any suggestions or bug reports, please contact E<lt>dirk.vermeylen@hp.comE<gt>
