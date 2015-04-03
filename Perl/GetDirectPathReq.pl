=head1 NAME

GetDirectPathReq - Connect Direct Path Definitions with Requests. 

=head1 VERSION HISTORY

version 1.0 02 April 2015 DV

=over 4

=item *

Initial release.

=back

=head1 DESCRIPTION

This script will review table url2appl_ip on records for which there is no connection to a request in the req_network_path table. It will establish connections based on IP address and port numbers.

=head1 SYNOPSIS

 GetDirectPathReq.pl

 GetDirectPathReq -h	Usage
 GetDirectPathReq -h 1  Usage and description of the options
 GetDirectPathReq -h 2  All documentation

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

sub validate_info($$$$$) {
	my ($url_id, $server, $ip_address, $port, $source_id) = @_;
	my $url2appl_ip_id = "undef";
	my @fields = qw(server ip_address port source_id);
	# Check if this info is known already
	my $query = "SELECT id FROM url2appl_ip
				 WHERE server = '$server'
				   AND ip_address = '$ip_address'
				   AND port = $port";
	my $ref = do_select($dbh, $query);
	if (@$ref < 1) {
		# No record found in url2appl_ip, create one.
		my (@vals) = map { eval ("\$" . $_ ) } @fields;
		print "Add record in url2appl_ip for  $server - $ip_address - $port\n";
		$url2appl_ip_id = create_record($dbh, "url2appl_ip", \@fields, \@vals);
	} elsif (@$ref > 1) {
			$log->error("Duplicate info found in url2appl_ip for $server - $ip_address - $port");
	} else {
		# Update existing url record with reference to url2appl_ip record.
		my $arrayhdl = $ref->[0];
		$url2appl_ip_id = $$arrayhdl{id};
	}
	my $upd_query = "UPDATE url SET url2appl_ip_id = $url2appl_ip_id WHERE id = $url_id";
	print "Update url Record ID $url_id with $url2appl_ip_id\n\n\n";
	$dbh->do($upd_query);
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

# Get Application Information
my $query =  "UPDATE url2appl_ip appl, req_network_path req
			  SET   appl.req_network_path_id = req.id
			  WHERE appl.req_network_path_id  is null
				AND appl.ip_address = req.ip_address
				AND appl.port = req.port";
$dbh->do($query);

exit_application(0);

=head1 To Do

=over 4

=item *

Nothing for now...

=back

=head1 AUTHOR

Any suggestions or bug reports, please contact E<lt>dirk.vermeylen@hp.comE<gt>
