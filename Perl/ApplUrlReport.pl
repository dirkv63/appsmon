=head1 NAME

ApplUrlReport.pl - Get the Application - URL Report.

=head1 VERSION HISTORY

version 1.0 03 April 2015 DV

=over 4

=item *

Initial release.

=back

version 1.1 29 April 2015 DV

=over 4

=item *

Relation between Application and URL via appl_url table (many-to-many).

=item *

Table fmo_sitescope now links to applications, not to urls.

=back

=head1 DESCRIPTION

This script will get full Application to URL Report for a specific period.

=head1 SYNOPSIS

 ApplUrlReport.pl -s source_id -f fmo_source_id -d dwh_source_id

 ApplUrlReport -h	Usage
 ApplUrlReport -h 1  Usage and description of the options
 ApplUrlReport -h 2  All documentation

=head1 OPTIONS

=over 4

=item B<-s source_id>

Source ID of the AmaaS reference period.

=item B<-f fmo_source_id>

Source ID of the FMO Sitescope Extract.

=item B<-d source_id>

Source ID of the DWH Extract.

=back

=head1 ADDITIONAL DOCUMENTATION

=cut

###########
# Variables
########### 

my ($log, $dbh, $source_id, $fmo_source_id, $dwh_source_id);
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

sub get_appl_review($) {
	my ($appl_id) = @_;
	my $revline = "";
	my $query = "SELECT remark, event, description
				 FROM appl_review rev, source src
				 WHERE rev.application_id = $appl_id
				   AND src.id = rev.source_id
				 ORDER BY event";
	my $ref = do_select($dbh, $query);
	foreach my $arrayhdl (@$ref) {
		my $remark = $$arrayhdl{remark} || "";
		my $event = $$arrayhdl{event} || "";
		my $description = $$arrayhdl{description} || "";
		$revline .= "$remark ($event) -";
	}
	if (length($revline) > 3) {
		$revline = substr($revline,0,-2);
	}
	return $revline;
}



######
# Main
######

# Handle input values
my %options;
getopts("h:s:f:d:", \%options) or pod2usage(-verbose => 0);
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
if (defined $options{d}) {
	$dwh_source_id = $options{d};
} else {
	$log->fatal("DWH Extract Source ID not defined, exiting...");
	exit_application(1);
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

my $headerline = "Appl. id;nr;name;url;network type;dns server;dns ip address;";
$headerline   .= "rev. proxy server;rev. proxy ip;rev. proxy port;internet whitelist;";
$headerline   .= "appl. server;appl. ip;appl. port;id req to network team;";
$headerline   .= "dwh sla binnen;dwh sla buiten;cmo monitoring;";
$headerline   .= "fmo monitoring;fmo result;fmo category;Review Remarks\n";
print Rep $headerline;

my @fields = qw(appl_id number name url dns_category dns_servername dns_ip_address
			    rev_server rev_ip_address rev_port nt_source_id
				dir_server dir_ip_address dir_port path_source_id
				sla_binnen sla_buiten cmo_monitoring
				fmo_monitoring fmo_result fmo_source_id appl_review);
# Get Application Information
my $query =  "SELECT am.id id, appl.id appl_id, appl.number number, appl.name name, url.url url,
					 dns.category dns_category, dns.servername dns_servername, dns.ip_address dns_ip_address, 
					 rev.server rev_server, rev.ip_address rev_ip_address, rev.port rev_port, 
					 nt.source_id nt_source_id, 
					 dir.server dir_server, dir.ip_address dir_ip_address, dir.port dir_port, 
					 path.source_id path_source_id,
					 dwh.onb_binnen onb_binnen, dwh.onb_buiten onb_buiten, dwh.monitoring cmo_monitoring,
					 fmo.status fmo_monitoring, fmo.summary fmo_result, fmo.source_id fmo_source_id
			  FROM amaas am
			  LEFT JOIN application appl on am.application_id = appl.id
			  LEFT JOIN appl_url applurl on applurl.appl_id = appl.id
			  LEFT JOIN url url on url.id = applurl.url_id
			  LEFT JOIN url2dns dns on url.url2dns_id = dns.id
			  LEFT JOIN req_revproxy_tx rev on rev.id = dns.req_revproxy_tx_id
			  LEFT JOIN req_internet_whitelist nt on nt.id = dns.req_internet_whitelist_id
			  LEFT JOIN url2appl_ip dir on dir.id=url.url2appl_ip_id
			  LEFT JOIN req_network_path path on path.id = dir.req_network_path_id
			  LEFT JOIN dwh_status dwh on dwh.application_id = appl.id
					AND dwh.source_id = $dwh_source_id
			  LEFT JOIN fmo_sitescope fmo on fmo.appl_id = appl.id 
			        AND fmo.source_id = $fmo_source_id
			  WHERE am.source_id = $source_id
				AND am.category = 'URL'";
my $ref = do_select($dbh, $query);
foreach my $arrayhdl (@$ref) {
	my $id				= $$arrayhdl{id};
	my $appl_id			= $$arrayhdl{appl_id};
	my $number			= $$arrayhdl{number};
	my $name			= $$arrayhdl{name};
	my $url				= $$arrayhdl{url}				|| "";
	my $dns_category	= $$arrayhdl{dns_category}		|| "";
	my $dns_servername	= $$arrayhdl{dns_servername}	|| "";
	my $dns_ip_address	= $$arrayhdl{dns_ip_address}	|| "";
	my $rev_server		= $$arrayhdl{rev_server}		|| "";
	my $rev_ip_address	= $$arrayhdl{rev_ip_address}	|| "";
	my $rev_port		= $$arrayhdl{rev_port}			|| "";
	my $nt_source_id	= $$arrayhdl{nt_source_id}		|| "";
	my $dir_server		= $$arrayhdl{dir_server}		|| "";
	my $dir_ip_address	= $$arrayhdl{dir_ip_address}	|| "";
	my $dir_port		= $$arrayhdl{dir_port}			|| "";
	my $path_source_id	= $$arrayhdl{path_source_id}	|| "";
	my $sla_binnen		= $$arrayhdl{sla_binnen}		|| "";
	my $sla_buiten		= $$arrayhdl{sla_buiten}		|| "";
	my $cmo_monitoring	= $$arrayhdl{cmo_monitoring}	|| "";
	my $fmo_monitoring	= $$arrayhdl{fmo_monitoring}	|| "";
	my $fmo_result		= $$arrayhdl{fmo_result}		|| "";
	my $fmo_source_id	= $$arrayhdl{fmo_source_id}		|| "";
	my $appl_review		= get_appl_review($appl_id);
	$fmo_monitoring = substr($fmo_monitoring, 0, index($fmo_monitoring,";"));
	my (@vals) = map { eval ("\$" . $_ ) } @fields;
	print Rep join(";",@vals) . "\n";
}

exit_application(0);

=head1 To Do

=over 4

=item *

Check for CMDB ID 60833. Double 'maakt gebruik van' relation??

=back

=head1 AUTHOR

Any suggestions or bug reports, please contact E<lt>dirk.vermeylen@hp.comE<gt>
