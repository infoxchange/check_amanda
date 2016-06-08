#!/usr/bin/perl
#
#############################################################################
#                                                                           #
# This script was initially developed by Infoxchange for internal use       #
# and has kindly been made available to the Open Source community for       #
# redistribution and further development under the terms of the             #
# GNU General Public License v2: http://www.gnu.org/licenses/gpl.html       #
#                                                                           #
#############################################################################
#                                                                           #
# This script is supplied 'as-is', in the hope that it will be useful, but  #
# neither Infoxchange nor the authors make any warranties or guarantees     #
# as to its correct operation, including its intended function.             #
#                                                                           #
# Or in other words:                                                        #
#       Test it yourself, and make sure it works for YOU.                   #
#                                                                           #
#############################################################################
# Author: George Hansper                     e-mail:  george@hansper.id.au  #
#############################################################################

use strict;
use File::Find;
use File::stat;
use Cwd 'realpath';
use Getopt::Std;
use Data::Dumper;
use POSIX qw(strftime);
use DateTime;

my $rcs_id = '$Id$';

my %optarg;
my $getopt_result;


my @message;
my @message_perf;

my $exit = 0;
my @exit = qw/OK: WARNING: CRITICAL: UNKNOWN:/;

my %backups;
my %backups_noconfig;
my $level0_total_size = 0;
my $level1_total_size = 0;

my $backup_sets_conf = 0;
# Worst case of age per backup-set
my %backup_sets_age_ok = ();
my %backup_sets_age_warn = ();
my %backup_sets_age_crit = ();
# Worst case of size per backup-set
my %backup_sets_size_ok = ();
my %backup_sets_size_warn = ();
my %backup_sets_size_crit = ();
my $backups_found = 0;
my %servers_found = ();
# We need %backup_sets_found for the case of looking for all backups for a given server regex
my %backup_sets_found = ();
my $backup_filesystems_conf = 0;
my $backup_filesystems_used_ok = 0;
my $backup_filesystems_used_warn = 0;
my $backup_filesystems_used_crit = 0;
my $media_dir = '/mnt/store1';
my $warn_hrs = 49;
my $crit_hrs = 73;
my $warn_size = 131072;
my $crit_size = 65536;
my %include_sets = ();
my %exclude_sets = ();
my $include_hosts = '';
my $exclude_hosts = '';
my $fail_safe = 1;
my $now = time();
my $timezone = DateTime::TimeZone->new( name => 'local' );

my %SI_exp = (
	'k'  => 1000,
	'ki' => 1024,
	'm'  => 1000000,
	'mi' => 1048576,
	'g'  => 1000000000,
	'gi' => 1073741824,
	't'  => 1000000000000,
	'ti' => 1099511627776,
);

$getopt_result = getopts('hVvldw:c:x:i:X:I:C:m:s:S:', \%optarg) ;

sub HELP_MESSAGE() {
	print <<EOF;
Usage:
	$0 [-v] [-l] [-d] [-w warn_hrs] [-c crit_hrs] [-x exclude_sets | -i include_sets] [ -X exclude_hosts_regex | -I include_hosts_regex ] [ -C min_backups ] [ -m media_dir ]

	-w  ... warning  if a backup less than warn_hrs old cannot be found for any backup item (default: $warn_hrs)
	-c  ... critical if a backup less than crit_hrs old cannot be found for any backup item (default: $crit_hrs)
	-C  ... critical is less that min_backups (filesystems, DBs, etc) are found in total (default: $fail_safe)
	-m  ... top-level directory where the backup files are stored (default: $media_dir)
	-v  ... verbose messages to STDERR - prints details for each backup item (DLE)
	-l  ... list files to STDERR - lists the latest backup files found for each backup item (DLE)
	-d  ... debug messages to STDERR for testing
	-x  ... exclude backup sets (comma or space separated list)
	-i  ... include only these backup sets (comma or space separated list)
	-X  ... exclude hosts which match this regex
	-I  ... include hosts which match this regex (only these hosts are checked)
	-s  ... minimum size for the latest level0 backup warning (default: $warn_size)
	-S  ... minimum size for the latest level0 backup critical (default: $crit_size)
	        These args allow suffixes: k Ki M Mi G Gi T Ti
		size excludes the 1st 32k of tha backup file, which is amanda metadata

Examples:
	$0 -m /backups
		... check all backups which have been configured, looking for backup files in /backup

	$0 -x weekly-backups
		... check all backup sets except 'weekly-backups', look for backups in the default $media_dir

	$0 -w 192 -c 360 -i weekly-backups
		... check only the backup set 'weekly-backups'.
		    warning  if the youngest backup is more than  8 days old
		    critical if the youngest backup is more than 15 days old

	$0 -s 10M -S 96Ki
		... warning  if any filesystem (DLE) is less than 10*1000*1000 bytes in size
		... critical if any filesystem (DLE) is less than 96*1024 bytes in size

Sample Output:
	Note that the 'size' value is given as X+Y where X in the sum of the latest level0 backups, and Y is the sum of any later level1 backups
	$0
	OK: 55 ok in 21 backup sets, size 1334Gi +145Gi|total_sets=21 total_servers=33 total_items=55 ok=55 warn=0 crit=0 l0size=1398509418k l1size=151648725k

	$0 -i win-servers -v
	Critical: win-servers     win-srv-01:         C:/App Archives           last backup l  never  (never) 0
	Warning:  win-servers     win-srv-01:         C:/App Data               last backup l0 20150120213008     (2d) 912Ki
	OK:       win-servers     win-srv-01:         C:/Datafiles              last backup l1 20150122213008     (17hrs) 1952Ki+569
	Oldest backup is 20150120213008 (2d)
	CRITICAL: 1 critical in win-servers (never), 1 warning in win-servers (2d), 1 ok in win-servers (17hrs,1952Ki), size 2864Ki +569|total_sets=1 total_servers=1 total_items=3 ok=1 warn=1 crit=1 l0size=2864k l1size=0k

	In this case, we are ONLY checking the backup set 'win-servers'
	Adding -v provides some detail on each backup item (ie. filesystem or Disk List Entry)
	There is one critical backup, that has never (not yet?) been backed up.
	There is one warning, because the backup is older than 2 days
	The ok message tells us that the total size of the level 0 backups (1952Ki) which are OK and the age of the oldest OK backup in the set, either level 0 or level 1
	The size message says that the total level 0 backups come to 2864Ki, plus newer level 1 backups of 569 bytes (excludes the 32k amanda header on the file)

	The size used for -s and -S and listed in the output excludes the 32k Amanda metadata header - it represents the actual backup data only
	If compression is used, the 'size' is the compressed size

EOF
}
sub VERSION_MESSAGE() {
	print "perl: $^V\n$0: $rcs_id\n";
}

sub parse_SI_suffix($) {
	my $arg = lc($_[0]);

	if( $arg =~ /^([0-9]+)([mkgt]i?)$/i ) {
		$arg = $1;
		$arg *= $SI_exp{"$2"};
	}

	return($arg);
}

sub printv($) {
	my $str = $_[0];
	if ( $optarg{v} || $optarg{l} ) {
		chomp $str;
		print STDERR $str;
		print STDERR "\n";
	}
}

sub print_debug($) {
	if ( $optarg{d} ) {
		chomp( $_[-1] );
		print STDERR @_;
		print STDERR "\n";
	}
}

# Any invalid options?
if ( $getopt_result == 0 ) {
	HELP_MESSAGE();
	exit 1;
}
if ( $optarg{h} ) {
	HELP_MESSAGE();
	exit 0;
}
if ( $optarg{V} ) {
	VERSION_MESSAGE();
	exit 0;
}

if ( defined($optarg{w}) ) {
	$warn_hrs = $optarg{w};
}

if ( defined($optarg{c}) ) {
	$crit_hrs = $optarg{c};
}

my $warn_timestamp =  strftime "%Y%m%d%H%M%S", localtime($now - 3600*$warn_hrs);
my $crit_timestamp =  strftime "%Y%m%d%H%M%S", localtime($now - 3600*$crit_hrs);
my $oldest_backup  =  strftime "%Y%m%d%H%M%S", localtime($now);

#print_debug( "$warn_timestamp\n");
#print_debug( "$crit_timestamp\n");

if ( defined($optarg{C}) ) {
	$fail_safe = $optarg{C};
}

if ( defined($optarg{i}) ) {
	%include_sets = map { ($_,1) } split(/[ ,]/,$optarg{i});
}

if ( defined($optarg{x}) ) {
	%exclude_sets = map { ($_,1) } split(/[ ,]/,$optarg{x});
}

if ( defined($optarg{I}) ) {
	$include_hosts = $optarg{I};
}

if ( defined($optarg{X}) ) {
	$exclude_hosts = $optarg{X};
}

if ( defined($optarg{m}) ) {
	$media_dir = $optarg{m};
}

if ( defined($optarg{s}) ) {
	$warn_size = parse_SI_suffix($optarg{s});
}

if ( defined($optarg{S}) ) {
	$crit_size = parse_SI_suffix($optarg{S});
}

sub add_SI_suffix($) {
	my $arg = $_[0];
	if ( $arg >= $SI_exp{'ti'}*10 ) {
		$arg = sprintf("%.0fTi",$arg/$SI_exp{'ti'});
	} elsif ( $arg >= $SI_exp{'gi'}*10 ) {
		$arg = sprintf("%.0fGi",$arg/$SI_exp{'gi'});
	} elsif ( $arg >= $SI_exp{'mi'}*10 ) {
		$arg = sprintf("%.0fMi",$arg/$SI_exp{'mi'});
	} elsif ( $arg >= $SI_exp{'ki'}*10 ) {
		$arg = sprintf("%.0fKi",$arg/$SI_exp{'ki'});
	}
	return($arg);
}

sub timestamp2t($) {
	my ($yy,$mm,$dd,$HH,$MM,$SS);
	my $timestamp = $_[0];
	my $dt;
	if ( $timestamp =~ /^(....)(..)(..)(..)(..)(..)$/ ){
		$yy = $1;
		$mm = $2+0;
		$dd = $3+0;
		$HH = $4+0;
		$MM = $5+0;
		$SS = $6+0;
		$dt = DateTime->new( year => $yy, month => $mm, day => $dd, hour => $HH, minute => $MM, second => $SS, time_zone  => $timezone);
		return($dt->epoch());
	} elsif ( $timestamp == 0 ) {
		return(0);
	}
}

sub append_age_size($$$) {
	my $set = $_[0];
	my $timestamp = $_[1];
	my $size = $_[2];
	my $age = undef;
	my $age_t = 0;
	my $age_hrs;
	if ( ! defined ( $timestamp ) ) {
		# Do nothing
	} elsif ( $timestamp == 0 ) {
		# size is always 0 for backups that haven't happened
		return("$set (never)");
	} else {
		$age_t = timestamp2t( $timestamp );
		$age_hrs = ( $now - $age_t ) / 3600;
		if ( $age_hrs > 24 ) {
			$age = int($age_hrs / 24) . 'd';
		} else {
			$age = int($age_hrs) . 'hrs';
		}
	}
	#print_debug(sprintf("Backup Set: %-20s, age_t=%s, age_hrs=%4s days=%s size=%s",$set,$age_t,$age_hrs,$age,$size));
	if ( defined($size) && defined($age) ) {
		$size = add_SI_suffix($size);
		return("$set ($age,$size)");
	} elsif ( defined($size) ) {
		$size = add_SI_suffix($size);
		return("$set ($size)");
	} elsif ( defined($age) ) {
		return("$set ($age)");
	} else {
		return($set);
	}
}

sub get_disk_lists() {
	# Find all backup sets
	#
	my $etc_amanda = '/etc/amanda';
	my %result = ();
	my $disklist_conf;
	my $skip_options = 0;
	if( opendir(ETC_AMANDA,$etc_amanda) ) {
		while(my $backup_set = readdir ETC_AMANDA ) {
			if ( $backup_set eq '.' || $backup_set eq '..' ) {
				next;
			}
			if ( chdir "$etc_amanda/$backup_set" ) {
				foreach $disklist_conf ( glob("disklist.conf disklist") ) {
					if ( -f "$etc_amanda/$backup_set/$disklist_conf" ) {
						if ( open(DISK_LIST,"<$etc_amanda/$backup_set/$disklist_conf") ) {
							while(<DISK_LIST>) {
								# Ignore comments
								s/#.*//;
								# Ignore empty lines
								if ( /^\s*$/ ) {
									next;
								}
								if ( /^\s*}/ ) {
									$skip_options = 0;
									next;
								} elsif ( /^([-0-9a-z_]\S*)\s+("[^"]*"|[^"]\S*)\s.*{/ ) {
									my $server = $1;
									my $filesystem = $2;
									if ( $filesystem =~ /^"([^"]+)"$/ ) {
										$filesystem = $1;
									}
									# Time of last backup
									$result{$backup_set}{$server}{$filesystem}{'timestamp'} = 0;
									$backup_filesystems_conf++;
									$skip_options = 1;
								} elsif ( $skip_options == 0 && /^\s*(\S+)\s+("[^"]*"|[^"]\S*)/ ) {
									my $server = $1;
									my $filesystem = $2;
									if ( $filesystem =~ /^"([^"]+)"$/ ) {
										$filesystem = $1;
									}
									# Time of last backup
									$result{$backup_set}{$server}{$filesystem}{'timestamp'} = 0;
									$backup_filesystems_conf++;
								}
							}
							close(DISK_LIST);
						} else {
							push @message, "$backup_set/disklist.conf: $!";
							$exit |= 1;
						}
					} # -f $backup_set/$disklist_conf
				} # foreach
				$backup_sets_conf++;
			} # chdir $backup_set
		}
		
		close(ETC_AMANDA);
		return (%result);
	} else {
		push @message, "Cannot open directory $etc_amanda: $!";
		$exit |= 2;
		return();
	}
}

my $backup_set;
my $back_head_failures = 0;

sub backup_head ($) {
	my ($server,$filesystem,$level,$timestamp);
	if ( open(HEAD,"<$_[0]" ) ) {
		my $head = <HEAD>;
		#print_debug($head);
		close(HEAD);
		if ( $head =~ /^AMANDA:\s+SPLIT_FILE\s+(\S+)\s+(\S+)\s+("[^"]*"|[^"]\S*)\s+.*lev\s(\S+)/ ) {
			$timestamp = $1;
			$server = $2;
			$filesystem = $3;
			$level = $4;
			$filesystem =~ s/^"|"$//g;
			print_debug( "  " . join(" ",($server,$filesystem,$level,$timestamp)));
			return($server,$filesystem,$level,$timestamp);
		}
	} else {
		if ( $back_head_failures++ < 3 ) {
			push @message, "Cannot open file $_[0]: $!";
		}
		$exit |= 1;
		warn("Cannot open $_[0]: $!");
	}
	return('',,,);
}

sub backup_file_check () {
	my $backup_set;
	my $backup_file;
	my $backup_file_realpath;
	my ($server,$filesystem,$level,$timestamp);
	# Weed out the 'TAPESTART' files by name, and ignore directories
	if ( $_ !~ /^00000\..*AA-[0-9]+$/ &&  -f $File::Find::name ) {
		print_debug("Examining " . $File::Find::name );
		my @backup_path = split ( /\/+/, $File::Find::name );
		$backup_file = $backup_path[-1];
		# The tape directories slotNNN also contain a symlink 'data' which points to one of the slotNNN directories
		# We prefer to report the real pathname, but still need to process the original pathname for extracting $backup_set
		$backup_file_realpath = realpath($File::Find::name);
		$backup_set = $File::Find::name;
		$backup_set =~ s{^$media_dir/*}{};
		$backup_set =~ s{/.*}{};
		$server = '';
		($server,$filesystem,$level,$timestamp) = backup_head($File::Find::name);
		if ( $server eq '' ) {
			return;
		}
		my $stat = stat("$File::Find::name");
		if ( $now - ($stat->mtime) < 30 ) {
			# This file has been written in the last 30s, so it's probably not complete yet
			# Ignore this file as a potential backup file until it is complete
			# A Level 1 backup with few or no changes on a largs fs could still result in a false positive (maybe)
			return;
		}
		# Size, without the amanda metadata header
		my $size = ($stat->size) - 32768;
		if ( $size < 0 ) {
			$size = 0;
		}
		if ( $size < 1024 ) {
			# This file is very small - is it OK ?
			if ( open(BACKUP,"<$File::Find::name") ) {
				# Skip over the Amanda metadata
				seek(BACKUP,32768,0);
				my $backup_data;
				read(BACKUP,$backup_data,$size);
				close(BACKUP);
				
				if ( substr($backup_data,0,2) eq "\x1f\x8b" && length($backup_data) <= 20 ) {
					# Data is gzipped, and empty
					print_debug("  Skipping L$level backup for $server:$filesystem (". $size . " bytes) empty gzip data");
					return;
				}
				$backup_data =~ s/\x00//g;
				if ( length($backup_data) == 0 ) {
					print_debug("  Skipping L$level backup for $server:$filesystem (". $size . " bytes) backup is empty");
					return;
				}
			} else {
				warn($File::Find::name . ": " . $!);
				# Failed to open file - don't include this file in analysis
				return;
			}
		}
		# If we look for ...{$server}{$filesystem} it will create the ...{$server} hash key quietly, which is not desirable
		# So we look for ...{server} first
		if ( defined($backups{$backup_set}{$server}) && defined($backups{$backup_set}{$server}{$filesystem}) ) {
			if ( $timestamp > $backups{$backup_set}{$server}{$filesystem}{"timestamp$level"} ) {
				$backups{$backup_set}{$server}{$filesystem}{"timestamp$level"} = $timestamp;
				$backups{$backup_set}{$server}{$filesystem}{"size$level"} = $size;
				$backups{$backup_set}{$server}{$filesystem}{"file$level"} = $backup_file_realpath;
				if ( $timestamp > $backups{$backup_set}{$server}{$filesystem}{timestamp} ) {
					$backups{$backup_set}{$server}{$filesystem}{'timestamp'} = $timestamp;
					$backups{$backup_set}{$server}{$filesystem}{'level'} = $level;
				}
				print_debug("  Found L$level backup for $server:$filesystem ". $stat->size . " bytes");
			}
		} else {
			if ( $timestamp > $backups_noconfig{$backup_set}{$server}{$filesystem}{"timestamp$level"} ) {
				$backups_noconfig{$backup_set}{$server}{$filesystem}{"timestamp$level"} = $timestamp;
				$backups_noconfig{$backup_set}{$server}{$filesystem}{"size$level"} = $size;
				$backups_noconfig{$backup_set}{$server}{$filesystem}{"file$level"} = $backup_file_realpath;
				if ( $timestamp > $backups_noconfig{$backup_set}{$server}{$filesystem}{'timestamp'} ) {
					$backups_noconfig{$backup_set}{$server}{$filesystem}{'timestamp'} = $timestamp;
					$backups_noconfig{$backup_set}{$server}{$filesystem}{'level'} = $level;
				}
				print_debug("Found backup file without a config: $backup_set $server:$filesystem on $timestamp ".append_age_size('',$timestamp,stat("$File::Find::name")->size)."\n");
			}
		}
	}

}

# Get the complete list of configured backups
# This list needs to comprehesive, because we don't know which servers appear in which backup set
%backups = get_disk_lists();

# In verbose mode, also scan the backup media for deleted backup sets
if ( $optarg{v} ) {
	my $dir;
	foreach $dir ( glob( "$media_dir/*/" ) ) {
		$backup_set = $dir;
		$backup_set =~ s{/$}{};
		$backup_set =~ s{.*/}{};
		if ( ( -f "$dir/state" || -l "$dir/state" ) && ( ! exists( $backups{$backup_set} ) ) ) {
			# We found a backup directory that's not in any config
			# Create a key, so that we will scan it later for backup files
			$backups{$backup_set} = undef;
		}
	}
}

print_debug(Dumper(\%backups));

##############################################################################
# Evaluate the latest backup for each backup set / server we are interested in
# Summarize all problems per-backup set
##############################################################################
foreach $backup_set ( keys(%backups) ) {
	if ( defined( $exclude_sets{$backup_set} ) ) {
		next;
	}
	if ( %include_sets ne '0' && ! defined($include_sets{$backup_set} ) ) {
		next;
	}
	# Find the latest backups for this backup set
	find ( { wanted => \&backup_file_check, follow => 1, follow_skip => 2 } , ( "$media_dir/$backup_set" ) );

	# Check the latest backup against our thresholds
	my $server;
	foreach $server ( keys($backups{$backup_set} ) ) {
		if ( $exclude_hosts ne '' && $server =~ /$exclude_hosts/  ) {
			next;
		}
		if ( $include_hosts ne '' && $server !~ /$include_hosts/ ) {
			next;
		}
		$servers_found{$server} = 0;
		print_debug("---- $server ----");
		my $filesystem;
		foreach $filesystem ( keys ( $backups{$backup_set}{$server} ) ) {
			#print "$backup_set $server $filesystem\n";
			my $backup_timestamp = $backups{$backup_set}{$server}{$filesystem}{'timestamp0'};
			my $l0_size = 0+$backups{$backup_set}{$server}{$filesystem}{'size0'};
			my $l1_size = 0;
			my $lN_size = 0;
			my $l0_size_SI = add_SI_suffix($l0_size);
			# Find all levelN backups with timestamps more recent than the level0 backup
			my $levelN = 1;
			my @files = ( $backups{$backup_set}{$server}{$filesystem}{'file0'} );
			while ( defined ( $backups{$backup_set}{$server}{$filesystem}{"timestamp$levelN"} ) ) {
				if ( $backups{$backup_set}{$server}{$filesystem}{"timestamp$levelN"} ge $backup_timestamp ) {
					# only if this level N backup is more recent than last level N-1
					$lN_size = $backups{$backup_set}{$server}{$filesystem}{"size$levelN"};
					$l1_size += $lN_size;
					$backup_timestamp = $backups{$backup_set}{$server}{$filesystem}{"timestamp$levelN"};
					push @files, $backups{$backup_set}{$server}{$filesystem}{"file$levelN"};
				} else {
					last;
				}
				$levelN += 1;
			}
			if ( $l1_size > 0 ) {
				$l0_size_SI .= '+' . add_SI_suffix($l1_size);
			}
			$level0_total_size += $l0_size;
			$level1_total_size += $l1_size;

			my $level;
			if ( defined( $backups{$backup_set}{$server}{$filesystem}{'level'} ) ) {
				$level = 'l' . $backups{$backup_set}{$server}{$filesystem}{'level'};
			} else {
				$level = '';
			}

			# Note that 0 or undef are both less than any timestamp string, for the purposes of comparing timestamps
			if ( $backup_timestamp lt $crit_timestamp || $l0_size <= $crit_size ) {
				if ( $backup_timestamp == 0 ) {
					# Note: '(' is lexographically lt '0'-'9', so (never) is less than any other timestamp, and is preserved as the worst case
					$backup_sets_age_crit{$backup_set} = '(never)';
				} elsif ( $backup_timestamp lt $crit_timestamp ) {
					# What's the worst case for this backup set?
					if ( $backup_sets_age_crit{$backup_set} eq undef || $backup_timestamp lt $backup_sets_age_crit{$backup_set} ) {
						$backup_sets_age_crit{$backup_set} = $backup_timestamp;
					}
				}
				printv( sprintf("Critical: %-16s %-21s%-25s last backup %2s %s%9s %s\n",$backup_set,$server.':',$filesystem,
					$level,
					$backup_timestamp == 0? 'never' : $backup_timestamp,
					append_age_size('',$backup_timestamp,undef),
					$l0_size_SI));

				if ( $l0_size <= $crit_size ) {
					if ( $backup_sets_size_crit{$backup_set} eq undef || $backup_sets_size_crit{$backup_set} > $l0_size ) {
						# worst size for this backup set
						$backup_sets_size_crit{$backup_set} = $l0_size;
					}
				}
				$backup_filesystems_used_crit++;
				$backup_sets_found{$backup_set} |= 2;
				$servers_found{$server} |= 2;
				$exit |= 2;
			} elsif ( $backup_timestamp lt $warn_timestamp || $l0_size <= $warn_size ) {
				printv( sprintf("Warning:  %-16s %-21s%-25s last backup %2s %s%9s %s\n",$backup_set,$server.':',$filesystem,$level,$backup_timestamp,append_age_size('',$backup_timestamp,undef),$l0_size_SI));
				# What's the worst case for this backup set?
				if ( $backup_timestamp lt $warn_timestamp ) {
					if ( $backup_sets_age_warn{$backup_set} == 0 || $backup_timestamp lt $backup_sets_age_warn{$backup_set} ) {
						$backup_sets_age_warn{$backup_set} = $backup_timestamp;
					}
				}
				if ( $l0_size <= $warn_size ) {
					if ( $backup_sets_size_warn{$backup_set} eq undef || $backup_sets_size_warn{$backup_set} > $l0_size ) {
						# worst size for this backup set
						$backup_sets_size_warn{$backup_set} = $l0_size;
					}
				}
				$backup_filesystems_used_warn++;
				$backup_sets_found{$backup_set} |= 1;
				$servers_found{$server} |= 1;
				$exit |= 1;
			} else {
				printv( sprintf("OK:       %-16s %-21s%-25s last backup %2s %s%9s %s\n",$backup_set,$server.':',$filesystem,$level,$backup_timestamp,append_age_size('',$backup_timestamp,undef),$l0_size_SI));
				# What's the worst case for this backup set?
				if ( ( ! defined( $backup_sets_age_ok{$backup_set} )) || $backup_timestamp lt $backup_sets_age_ok{$backup_set} ) {
					$backup_sets_age_ok{$backup_set} = $backup_timestamp;
				}
				# For the OK message, report the total size of the backup set
				$backup_sets_size_ok{$backup_set} += $l0_size;
				# initialize, but don't override any existing value
				$backup_sets_found{$backup_set} |= 0;
				$backup_filesystems_used_ok++;
			}
			if ( defined($optarg{l}) ) {
				printv( "   " . join("\n   ",@files)."\n");
			}
			if ( $backup_timestamp > 0 ) {
				if ( $oldest_backup gt $backup_timestamp ) {
					$oldest_backup = $backup_timestamp;
				}
				$backups_found++;
			} # if $backup_timestamp > 0
		} # foreach $filesystem
	}
}

printv("Oldest backup is $oldest_backup".append_age_size('',$oldest_backup,undef));

if ( defined($optarg{v}) || defined($optarg{l}) ) {
	# Verbose
	foreach $backup_set ( keys(%backups_noconfig) ) {
		# Apply the include/exclude criteria - otherwise the 'NO Conf' messages can outnumber the interesting ones
		if ( $exclude_sets{$backup_set} == 1 ) {
			next;
		}
		if ( %include_sets ne '0' && ! defined($include_sets{$backup_set} ) ) {
			next;
		}
		my $server;
		foreach $server ( keys($backups_noconfig{$backup_set} ) ) {
			if ( $exclude_hosts ne '' && $server =~ /$exclude_hosts/  ) {
				next;
			}
			if ( $include_hosts ne '' && $server !~ /$include_hosts/ ) {
				next;
			}
			my $filesystem;
			foreach $filesystem ( keys ( $backups_noconfig{$backup_set}{$server} ) ) {
				my $backup_timestamp = $backups_noconfig{$backup_set}{$server}{$filesystem}{'timestamp0'};
				my $l0_size = 0+$backups_noconfig{$backup_set}{$server}{$filesystem}{'size0'};
				my $l1_size = 0;
				my @files = ( $backups_noconfig{$backup_set}{$server}{$filesystem}{'file0'} );
				my $levelN = 1;
				while ( defined ( $backups_noconfig{$backup_set}{$server}{$filesystem}{"timestamp$levelN"} ) ) {
					if ( $backups_noconfig{$backup_set}{$server}{$filesystem}{"timestamp$levelN"} ge $backup_timestamp ) {
						# only if this level N backup is more recent than last level N-1
						$l1_size += $backups_noconfig{$backup_set}{$server}{$filesystem}{"size$levelN"};
						$backup_timestamp = $backups_noconfig{$backup_set}{$server}{$filesystem}{"timestamp$levelN"};
						push @files, $backups_noconfig{$backup_set}{$server}{$filesystem}{"file$levelN"};
					} else {
						last;
					}
					$levelN += 1;
				}
				my $l0_size_SI = add_SI_suffix($l0_size);
				if ( $l1_size > 0 ) {
					$l0_size_SI .= '+' . add_SI_suffix($l1_size);
				}
				my $level = $backups_noconfig{$backup_set}{$server}{$filesystem}{'level'};
				print STDERR sprintf("NO Conf:  %-16s %-21s%-25s last backup l%1s %s%9s\n",$backup_set,$server.':',$filesystem,$level,$backup_timestamp,append_age_size('',$backup_timestamp,$l0_size_SI));
				if ( defined($optarg{l}) ) {
					printv( "   " . join("\n   ",@files)."\n");
				}
			}
		}
	}
}

# Failsafe criteria - critical if too few backups found (eg amanda misconfiguration)
if ( $backups_found == 0 ) {
	$exit |= 2;
	push @message,"No backups found";
} elsif ( $backups_found < $fail_safe ) {
	$exit |= 2;
	push @message,"Only $backups_found backups found, $fail_safe required";
}

if ( $backup_filesystems_used_crit > 0 ) {
	my @sets = sort ( keys(%backup_sets_age_crit), grep { $backup_sets_age_crit{$_} eq undef } keys(%backup_sets_size_crit) );
	if ( @sets > 5 ) {
		$#sets = 5;
		grep { $_ = append_age_size($_,$backup_sets_age_crit{$_},$backup_sets_size_crit{$_}) } @sets;
		push @sets,'...';
	} else {
		grep { $_ = append_age_size($_,$backup_sets_age_crit{$_},$backup_sets_size_crit{$_}) } @sets;
	}
	push @message, $backup_filesystems_used_crit.' critical in '.join(", ",@sets);
}

if ( $backup_filesystems_used_warn > 0 ) {
	# This is necessary because the one backup set may have critical AND warning alerts
	my @sets = sort ( keys(%backup_sets_age_warn), grep { $backup_sets_age_warn{$_} eq undef } keys(%backup_sets_size_warn) );
	if ( @sets > 5 ) {
		$#sets = 5;
		grep { $_ = append_age_size($_,$backup_sets_age_warn{$_},$backup_sets_size_warn{$_}) } @sets;
		push @sets,'...';
	} else {
		grep { $_ = append_age_size($_,$backup_sets_age_warn{$_},$backup_sets_size_warn{$_}) } @sets;
	}
	push @message, $backup_filesystems_used_warn.' warning in '.join(", ",@sets);
}

if ( $backup_filesystems_used_ok > 0 ) {
	# Could use either %backup_sets_size_ok or %backup_sets_age_ok
	my @sets = sort( keys(%backup_sets_size_ok) );
	if ( @sets > 5 ) {
		#$#sets = 5;
		#push @sets,'...';
		@sets = ( @sets .' backup sets' );
	} else {
		grep { $_ = append_age_size($_,$backup_sets_age_ok{$_},$backup_sets_size_ok{$_}) } @sets;
	}
	push @message, $backup_filesystems_used_ok.' ok in '.join(", ",@sets);
}

# Add overall backup size to the status message
my $message_tmp;
$message_tmp = "size " . add_SI_suffix($level0_total_size) ." +". add_SI_suffix($level1_total_size);
push @message, $message_tmp;

if ( $optarg{d} ) {
	print_debug(Dumper(\%backups));
}
#print_debug('%backup_sets_age_crit ' . Dumper(\%backup_sets_age_crit));
#print_debug('%backup_sets_age_ok ' . Dumper(\%backup_sets_age_ok));
#print_debug('%backup_sets_age_warn ' . Dumper(\%backup_sets_age_warn));
#print_debug('%level0_backup_size ' . Dumper(\%level0_backup_size));
#print_debug('%level1_backup_size ' . Dumper(\%level1_backup_size));
#print_debug('%servers_found ' . Dumper(\%servers_found));
#print_debug('%backup_sets_found ' . Dumper(\%backup_sets_found));

my $total_sets = ( keys(%backup_sets_found) );

push @message_perf,"total_sets=".$total_sets;
push @message_perf,"total_servers=".keys(%servers_found);
push @message_perf,"total_items=".($backup_filesystems_used_ok+$backup_filesystems_used_warn+$backup_filesystems_used_crit);
push @message_perf,"ok=$backup_filesystems_used_ok";
push @message_perf,"warn=$backup_filesystems_used_warn";
push @message_perf,"crit=$backup_filesystems_used_crit";
push @message_perf,"l0size=".int($level0_total_size/1024)."k";
push @message_perf,"l1size=".int($level1_total_size/1024)."k";

if ( $exit == 3 ) {
	$exit = 2;
} elsif ( $exit > 3 || $exit < 0 ) {
	$exit = 3;
}

print "$exit[$exit] ". join(", ",@message)."|".join(" ",@message_perf) . "\n";
exit $exit;
