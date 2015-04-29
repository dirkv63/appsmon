=head1 NAME

IdNameUrl.pl - Get application to URL report for Martin.

=head1 VERSION HISTORY

version 1.0 24 April 2015 DV

=over 4

=item *

Initial release.

=back

=head1 DESCRIPTION

This script will get a report Application ID, Application Name, Sitescope Name, Required URL and monitored URL. This will help Martin to configure Monitoring Instances.

=head1 SYNOPSIS

 IdNameUrl.pl -s source_id -f fmo_source_id

 IdNameUrl -h	Usage
 IdNameUrl -h 1  Usage and description of the options
 IdNameUrl -h 2  All documentation

=head1 OPTIONS

=over 4

=item B<-s source_id>

Source ID of the AmaaS reference period.

ID: 3 - for Update Guy 26/03/2015.

ID: 24 - for Application Inventory Sharepoint Extract 24/04/2015.

=item B<-f fmo_source_id>

Source ID of the FMO Sitescope Extract.

ID: 19 - for Sitescope Extract 08/04/2015

ID: 20 - for Sitescoep Extract 22/04/2015

=back

=head1 ADDITIONAL DOCUMENTATION

=cut

###########
# Variables
########### 

my ($log, $dbh, $source_id, $fmo_source_id);
my $reportdir = "c:/temp/";

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
	close Rep;
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
getopts("h:s:f:i:", \%options) or pod2usage(-verbose => 0);
my $arglength = scalar keys %options;  
if ($arglength == 0) {			# If no options specified,
	$options{"h"} = 0;			# display usage.
}
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
if (defined $options{s}) {
	$source_id = $options{s};
} else {
	$log->fatal("Source ID not defined, exiting...");
	exit_application(1);
}
if (defined $options{f}) {
	$fmo_source_id = $options{f};
} else {
	$log->fatal("FMO Sitescope Source ID not defined, exiting...");
	exit_application(1);
}
# Now print all input variables
while (my($key, $value) = each %options) {
  $log->trace("Input parameter $key: $value");
}

# End handle input values

# Make database connection for vo database
$dbh = db_connect("vo_appsmonitoring") or exit_application(1);

my $filename = "$reportdir/appl_url_$source_id" . "_" . time . ".csv"; 
# Open Report
my $openres = open(Rep, ">$filename");
if (not defined $openres) {
	$log->error("Could not open $filename for writing, exiting...");
	exit_application(1);
}

my $headerline = "Application Number;Application Name;Requested URL;Sitescope Name;Sitescope Status\n";
print Rep $headerline;

my @fields = qw(number name url fmo_name fmo_monitoring);
# Get Application Information
my $query =  "SELECT appl.number number, appl.name name, url.url url, 
					 fmo.name fmo_name, fmo.status fmo_monitoring
			  FROM amaas am
			  LEFT JOIN application appl on am.application_id = appl.id
			  LEFT JOIN appl_url applurl on applurl.appl_id = appl.id
			  LEFT JOIN url url on url.id = applurl.url_id
			  LEFT JOIN fmo_sitescope fmo on fmo.appl_id = appl.id 
			         AND fmo.source_id = $fmo_source_id
			  WHERE am.source_id = $source_id
				AND am.category = 'URL'";
my $ref = do_select($dbh, $query);
foreach my $arrayhdl (@$ref) {
	my $number			= $$arrayhdl{number};
	my $name			= $$arrayhdl{name};
	my $url				= $$arrayhdl{url}				|| "";
	my $fmo_name		= $$arrayhdl{fmo_name}			|| "";
	my $fmo_monitoring	= $$arrayhdl{fmo_monitoring}	|| "";
	$fmo_monitoring = substr($fmo_monitoring, 0, index($fmo_monitoring,";"));
	my (@vals) = map { eval ("\$" . $_ ) } @fields;
	print Rep join(";",@vals) . "\n";
}

exit_application(0);

=head1 To Do

=over 4

=item *

None...

=back

=head1 AUTHOR

Any suggestions or bug reports, please contact E<lt>dirk.vermeylen@hp.comE<gt>
