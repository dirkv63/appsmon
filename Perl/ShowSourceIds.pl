=head1 NAME

ShowSourceIds.pl - This script will show source ids per Category.

=head1 VERSION HISTORY

version 1.0 29 April 2015 DV

=over 4

=item *

Initial release.

=back

=head1 DESCRIPTION

This script will display the source IDs that can be selected per category.

=head1 SYNOPSIS

 ShowSourceIds.pl

 ShowSourceIds -h	Usage
 ShowSourceIds -h 1  Usage and description of the options
 ShowSourceIds -h 2  All documentation

=head1 OPTIONS

=over 4

=back

=head1 ADDITIONAL DOCUMENTATION

=cut

###########
# Variables
########### 

my ($log, $dbh);

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
getopts("h:", \%options) or pod2usage(-verbose => 0);
# my $arglength = scalar keys %options;  
# if ($arglength == 0) {			# If no options specified,
# 	$options{"h"} = 0;			# display usage.
# }
#Print Usage
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
$log->info("Start application");
# End handle input values

# Make database connection for vo database
$dbh = db_connect("vo_appsmonitoring") or exit_application(1);

print "\n\n";
print "-s AMAAS Selection List\n";
print "-----------------------\n";
# Get Source IDs for AMAAS List
my $query =  "SELECT distinct source_id, description, event 
              FROM amaas, source src
			  WHERE src.id = source_id
			  ORDER BY event";
my $ref = do_select($dbh, $query);
foreach my $arrayhdl (@$ref) {
	my $source_id = $$arrayhdl{source_id};
	my $description = $$arrayhdl{description} || "";
	my $event = $$arrayhdl{event} || "";
	$description = substr($description, 0, 50);
	print "$source_id\t$event\t$description\n";
}

print "\n\n";
print "-f FMO_Sitescope Selection List\n";
print "-------------------------------\n";
# Get Source IDs for AMAAS List
my $query =  "SELECT distinct source_id, description, event 
              FROM fmo_sitescope, source src
			  WHERE src.id = source_id
			  ORDER BY event";
my $ref = do_select($dbh, $query);
foreach my $arrayhdl (@$ref) {
	my $source_id = $$arrayhdl{source_id};
	my $description = $$arrayhdl{description} || "";
	my $event = $$arrayhdl{event} || "";
	$description = substr($description, 0, 50);
	print "$source_id\t$event\t$description\n";
}

print "\n\n";
print "-i Issue Selection List\n";
print "-----------------------\n";
# Get Source IDs for AMAAS List
my $query =  "SELECT distinct source_id, description, event 
              FROM appl_review, source src
			  WHERE src.id = source_id
			  ORDER BY event";
my $ref = do_select($dbh, $query);
foreach my $arrayhdl (@$ref) {
	my $source_id = $$arrayhdl{source_id};
	my $description = $$arrayhdl{description} || "";
	my $event = $$arrayhdl{event} || "";
	$description = substr($description, 0, 50);
	print "$source_id\t$event\t$description\n";
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
