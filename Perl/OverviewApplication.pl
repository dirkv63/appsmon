=head1 NAME

OverviewApplication.pl - This script tries to find Application Monitoring overview per application.

=head1 VERSION HISTORY

version 1.0 01 April 2015 DV

=over 4

=item *

Initial release.

=back

=head1 DESCRIPTION

This script will get a business application number, then collect all information available to database monitoring.

=head1 SYNOPSIS

 OverviewApplication.pl -b bedrijfsnummer

 OverviewApplication -h	Usage
 OverviewApplication -h 1  Usage and description of the options
 OverviewApplication -h 2  All documentation

=head1 OPTIONS

=over 4

=item B<-b bt_id>

Bedrijfstoepassingnummer. 

=back

=head1 ADDITIONAL DOCUMENTATION

=cut

###########
# Variables
########### 

my ($log, $dbh, $bt_number);

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

sub get_amaas_info($) {
	my ($application_id) = @_;
	my $query = "SELECT description, category, event
				 FROM amaas am, source src
				 WHERE am.application_id = $application_id
				   AND src.id = am.source_id
				 ORDER BY event";
	my $ref = do_select($dbh, $query);
	foreach my $arrayhdl (@$ref) {
		my $description = $$arrayhdl{description} || "";
		my $category = $$arrayhdl{category} || "";
		my $event = $$arrayhdl{event} || "";
		print "$event - " . substr($description,0,50) . " - $category\n";
	}
}

sub get_url_info($) {
	my ($application_id) = @_;
	my $query = "SELECT src.description, url.url, url.purpose,
						url.startdate, url.enddate, url.network_category,
						url.url2dns_id, url.url2appl_ip_id, url.id
				 FROM url url, source src
				 WHERE url.application_id = $application_id
				   AND src.id = url.source_id";
	my $ref = do_select($dbh, $query);
	foreach my $arrayhdl (@$ref) {
		my $description = $$arrayhdl{description} || "";
		my $url = $$arrayhdl{url};
		my $url_id = $$arrayhdl{id};
		my $purpose = $$arrayhdl{purpose} || "";
		my $startdate = $$arrayhdl{startdate} || "";
		my $enddate = $$arrayhdl{enddate} || "";
		my $network_category = $$arrayhdl{network_category};
		my $url2dns_id = $$arrayhdl{url2dns_id};
		my $url2appl_ip_id = $$arrayhdl{url2appl_ip_id};
		print "Source: " . substr($description,0,65) . "\n";
		print "URL for $purpose: $url\n";
		print "\nDNS Information:\n";
		print "----------------\n";
		if (defined $url2dns_id) {
			get_dns($url2dns_id);
		}
		if ((defined $network_category) and ($network_category eq "Direct")) {
			if (defined $url2appl_ip_id) {
				get_appl_path($url2appl_ip_id);
			} else {
				print "No Direct IP Address for Application Server known.\n";
			}
		}
		print "FMO Sitescope:\n";
		print "--------------\n";
		get_fmo_sitescope($url_id);
	}
}

sub get_fmo_sitescope($) {
	my ($url_id) = @_;
	my $query = "SELECT fmo.status, fmo.summary, src.description, src.event
				 FROM fmo_sitescope fmo, source src
				 WHERE fmo.url_id = $url_id
				   AND src.id = fmo.source_id
				 ORDER BY src.event ASC";
	my $ref = do_select($dbh, $query);
	foreach my $arrayhdl (@$ref) {
		my $status = $$arrayhdl{status} || "";
		my $summary = $$arrayhdl{summary} || "";
		my $description = $$arrayhdl{description} || "";
		my $event = $$arrayhdl{event} || "";
		print "$event: $description:\n$status\n$summary\n\n";
	}
}

sub get_dns($) {
	my ($id) = @_;
	my $query = "SELECT servername, ip_address, category, description,
						req_revproxy_tx_id, req_internet_whitelist_id
				 FROM url2dns dns, source src
				 WHERE dns.id = $id
				   AND src.id = dns.source_id";
	my $ref = do_select($dbh, $query);
	foreach my $arrayhdl (@$ref) {
		my $description = $$arrayhdl{description};
		my $servername = $$arrayhdl{servername};
		my $ip_address = $$arrayhdl{ip_address};
		my $category = $$arrayhdl{category};
		my $req_revproxy_tx_id = $$arrayhdl{req_revproxy_tx_id};
		my $req_internet_whitelist_id = $$arrayhdl{req_internet_whitelist_id};
		print "Source: $description\n";
		print "$servername ($ip_address) - $category\n";
		# Review DNS Information and handling
		if ($category eq "Internet") {
			if (defined $req_internet_whitelist_id) {
				get_req_int_whitelist($req_internet_whitelist_id);
			} else {
				print "No request to add server to forward proxy whitelist\n";
			}
		} elsif ($category eq "Reverse Proxy") {
			if (defined $req_revproxy_tx_id) {
				get_req_revproxy_tx($req_revproxy_tx_id);
			} else {
				print "No request to get IP address from Reverse Proxy\n";
			}
		} elsif ($category eq "Direct") {
			# no action required
		} else {
			print "Category $category not defined\n";
		}
	}
}

sub get_appl_path($) {
	my ($id) = @_;
	my $query = "select server, ip_address, port, req_network_path_id, description
				 from url2appl_ip url, source src
				 where src.id = url.source_id
				   and url.id = $id";
	my $ref = do_select($dbh, $query);
	foreach my $arrayhdl (@$ref) {
		my $description = $$arrayhdl{description};
		my $server = $$arrayhdl{server};
		my $ip_address = $$arrayhdl{ip_address};
		my $port = $$arrayhdl{port};
		my $req_network_path_id = $$arrayhdl{req_network_path_id};
		print "\nDirect Path Information:\n";
		print "------------------------\n";
		print "Server: $server, IP: $ip_address, Port: $port\n";
		if (defined $req_network_path_id) {
			get_req_network_path($req_network_path_id);
		} else {
			print "No request for direct path found.\n";
		}
	}
}

sub get_req_int_whitelist($) {
	my ($id) = @_;
	my $query = "SELECT server, port, description
				 FROM req_internet_whitelist req, source src
				 WHERE req.id = $id
				   AND src.id = req.source_id";
	my $ref = do_select($dbh, $query);
	foreach my $arrayhdl (@$ref) {
		my $description = $$arrayhdl{description};
		my $server = $$arrayhdl{server};
		my $port = $$arrayhdl{port};
		print "Request to add server ($server, $port) to forward proxy whitelist:\n";
		print $description ."\n";
	}
}

sub get_req_revproxy_tx($) {
	my ($id) = @_;
	my $query = "SELECT server, ip_address, port, description
				 FROM req_revproxy_tx req, source src
				 WHERE req.id = $id
				   AND src.id = req.source_id";
	my $ref = do_select($dbh, $query);
	foreach my $arrayhdl (@$ref) {
		my $description = $$arrayhdl{description};
		my $server = $$arrayhdl{server};
		my $ip_address = $$arrayhdl{ip_address};
		my $port = $$arrayhdl{port};
		print "Request to get Reverse Proxy translation:\n";
		print "$description\n";
		print "Result: $server - $ip_address - Port: $port\n";
	}
}

sub get_req_network_path($) {
	my ($id) = @_;
	my $query = "SELECT ip_address, port, description
				 FROM req_network_path req, source src
				 WHERE req.id = $id
				   AND src.id = req.source_id";
	my $ref = do_select($dbh, $query);
	foreach my $arrayhdl (@$ref) {
		my $description = $$arrayhdl{description};
		my $ip_address = $$arrayhdl{ip_address};
		my $port = $$arrayhdl{port};
		print "Request to configure Network path to $ip_address:$port\n";
		print "$description\n";
	}
}

sub get_remarks($) {
	my ($application_id) = @_;
	my $query = "SELECT remark, description, event
				 FROM appl_review rev, source src
				 WHERE application_id = $application_id
				   AND src.id = rev.source_id
				 ORDER BY event";	   
	my $ref = do_select($dbh, $query);
	foreach my $arrayhdl (@$ref) {
		my $description = $$arrayhdl{description};
		my $remark = $$arrayhdl{remark};
		my $event = $$arrayhdl{event};
		print "$event: $remark ($description)\n\n";
	}
}

######
# Main
######

# Handle input values
my %options;
getopts("h:b:", \%options) or pod2usage(-verbose => 0);
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
if (defined $options{b}) {
	$bt_number = $options{b};
} else {
	$log->fatal("Business application number not defined, exiting...");
	exit_application(1);
}
# End handle input values

# Make database connection for vo database
$dbh = db_connect("vo_appsmonitoring") or exit_application(1);

print "\n\n";
# Get Application Information
my $query =  "SELECT id, number, name, cmdb_id 
              FROM application
			  WHERE number=$bt_number";
my $ref = do_select($dbh, $query);
foreach my $arrayhdl (@$ref) {
	my $application_id = $$arrayhdl{id};
	my $name = $$arrayhdl{name};
	my $cmdb_id = $$arrayhdl{cmdb_id} || "";
	my $msg = "Application: $name ($bt_number), cmdb id: $cmdb_id (id: $application_id)";
	print "$msg\n";
	print "=" x length($msg);
	print "\n\n";
	print "Included in AmaaS Lists:\n";
	print "------------------------\n";
	get_amaas_info($application_id);
	print "\n\n";
	print "URL Information:\n";
	print "----------------\n";
	get_url_info($application_id);
	print "\n\n";
	print "Review Remark:\n";
	print "--------------\n";
	get_remarks($application_id);
	print "\n\n";
}

exit_application(0);

=head1 To Do

=over 4

=item *

Check for CMDB ID 60833. Double 'maakt gebruik van' relation??

=back

=head1 AUTHOR

Any suggestions or bug reports, please contact E<lt>dirk.vermeylen@hp.comE<gt>
