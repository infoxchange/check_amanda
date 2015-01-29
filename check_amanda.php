<?php
#
# check_amanda.pl PNP4Nagios template
# v1.0 2015-01-27
# $Id$
#
# Uses the PNP4Nagios template helper: http://docs.pnp4nagios.org/pnp-0.6/tpl_helper

$opt[1] = "--title \"Backup items ok/failing for $servicedesc on $hostname\" -l 0 ";

$def[1] = '';
$ds_name[1]="$NAME[6],$NAME[5],$NAME[4]";
$ds_name[2]="$NAME[1],$NAME[2],$NAME[3]";

# Critial
$ds_ndx=6;
$def[1]  .= rrd::def(   "$NAME[$ds_ndx]",  $RRDFILE[$ds_ndx],   $DS[$ds_ndx],     "MAX");
$def[1]  .= rrd::area(  "$NAME[$ds_ndx]",  "#ffA0A0",                           $NAME[$ds_ndx]."\t");
$def[1]  .= rrd::gprint("$NAME[$ds_ndx]",  array("LAST", "AVERAGE", "MAX"),     "%4.0lf  ");

# Warning
$ds_ndx=5;
$def[1]  .= rrd::def(   "$NAME[$ds_ndx]",  $RRDFILE[$ds_ndx],   $DS[$ds_ndx],     "MAX");
$def[1]  .= rrd::area(  "$NAME[$ds_ndx]",  "#ffffA0",                           $NAME[$ds_ndx]."\t", 'STACK');
$def[1]  .= rrd::gprint("$NAME[$ds_ndx]",  array("LAST", "AVERAGE", "MAX"),     "%4.0lf  ");

# OK
$ds_ndx=4;
$def[1]  .= rrd::def(   "$NAME[$ds_ndx]",  $RRDFILE[$ds_ndx],   $DS[$ds_ndx],     "MAX");
$def[1]  .= rrd::area(  "$NAME[$ds_ndx]",  "#A0ffA0",                           $NAME[$ds_ndx]."\t", 'STACK');
$def[1]  .= rrd::gprint("$NAME[$ds_ndx]",  array("LAST", "AVERAGE", "MAX"),     "%4.0lf  ");


# Same again, with a line for emphasis
# These lines go last, so they don't get drawn over by the area graphs
$ds_ndx=6;	# Critical
$def[1]  .= rrd::line1( "$NAME[$ds_ndx]",  "#C00000",'');
$ds_ndx=5;	# Warning
$def[1]  .= rrd::line1( "$NAME[$ds_ndx]",  "#C08000",'', 'STACK');
$ds_ndx=4;	# OK
$def[1]  .= rrd::line1( "$NAME[$ds_ndx]",  "#00C000",'', 'STACK');

################
# 2nd graph - sets, servers and items
################
$opt[2] = "--title \"Number of backup sets/servers/items $servicedesc on $hostname\" -l 0 ";

$def[2] = '';

# Draw the total_items first, this is the 'background'
$ds_ndx=3;
$def[2]  .= rrd::def(   "$NAME[$ds_ndx]",  $RRDFILE[$ds_ndx],   $DS[$ds_ndx],     "MAX");
$def[2]  .= rrd::area(  "$NAME[$ds_ndx]",  "#A0A0A0",                           $NAME[$ds_ndx]."\t");
$def[2]  .= rrd::gprint("$NAME[$ds_ndx]",  array("LAST", "AVERAGE", "MAX"),     "%4.0lf  ");

# Draw the servers next (blue)
$ds_ndx=2;
$def[2]  .= rrd::def(   "$NAME[$ds_ndx]",  $RRDFILE[$ds_ndx],   $DS[$ds_ndx],     "MAX");
$def[2]  .= rrd::area(  "$NAME[$ds_ndx]",  "#A0A0ff",                           $NAME[$ds_ndx]."\t");
$def[2]  .= rrd::gprint("$NAME[$ds_ndx]",  array("LAST", "AVERAGE", "MAX"),     "%4.0lf  ");

# Draw the backup sets (purple)
$ds_ndx=1;
$def[2]  .= rrd::def(   "$NAME[$ds_ndx]",  $RRDFILE[$ds_ndx],   $DS[$ds_ndx],     "MAX");
$def[2]  .= rrd::area(  "$NAME[$ds_ndx]",  "#ffA0ff",                           $NAME[$ds_ndx]."\t");
$def[2]  .= rrd::gprint("$NAME[$ds_ndx]",  array("LAST", "AVERAGE", "MAX"),     "%4.0lf  ");

# Same again, with a line for emphasis
$ds_ndx=3; # total_items
$def[2]  .= rrd::line1( "$NAME[$ds_ndx]",  "#000000",'');
$ds_ndx=2; # total_servers
$def[2]  .= rrd::line1( "$NAME[$ds_ndx]",  "#0000C0",'');
$ds_ndx=1; # total_sets
$def[2]  .= rrd::line1( "$NAME[$ds_ndx]",  "#C000C0",'');

################
# 3rd graph - l0 and l1 size, not stacked
################
$opt[3] = "--title \"Size of level 0 and level 1 backups - $servicedesc on $hostname\" -l 0 ";

$def[3] = '';

$ds_ndx=7;
$def[3]  .= rrd::def(    "$NAME[$ds_ndx]",  $RRDFILE[$ds_ndx],   $DS[$ds_ndx],     "MAX");
$def[3]  .= rrd::cdef(          'l0bytes',   "$NAME[$ds_ndx],1024,*");
$def[3]  .= rrd::area(          'l0bytes',  "#A0E0E0",                           $NAME[$ds_ndx]."\t");
$def[3]  .= rrd::gprint(        'l0bytes',  array("LAST", "AVERAGE", "MAX"),     "%6.3lg %s");

$ds_ndx=8;
$def[3]  .= rrd::def(    "$NAME[$ds_ndx]",  $RRDFILE[$ds_ndx],   $DS[$ds_ndx],     "MAX");
$def[3]  .= rrd::cdef(          'l1bytes',   "$NAME[$ds_ndx],1024,*");
$def[3]  .= rrd::area(          'l1bytes',  "#C0C0ff",                           $NAME[$ds_ndx]."\t");
$def[3]  .= rrd::gprint(        'l1bytes',  array("LAST", "AVERAGE", "MAX"),     "%6.3lg %s");

# Same again, with a line for emphasis
$ds_ndx=7; # l0size
$def[3]  .= rrd::line1( 'l0bytes',  "#00C0C0",'');
$ds_ndx=8; # l1size
$def[3]  .= rrd::line1( 'l1bytes',  "#4040C0",'');

#error_log($def[1]);
#error_log("WARN: ". implode(", ",array_values($WARN)). "   WARN 2 = $WARN[2]   UNIT 2  = $UNIT[2]");
#error_log("CRIT: ". implode(", ",array_values($CRIT)) . "   CRIT 2 = $CRIT[2]   UNIT 2  = $UNIT[2]");
?>
