check_amanda.pl
===============

This is a Nagios plugin to check that

* All configured backups have a recent backup item
* Backup sizes exceed a minumum size
* A least N backup items are configured

### Prerequisites

* If you are using Amanda backup,
    and
* If your backups go to disk (Disk-to-Disk backups)

This this plugin is for you.

### What it can do

This check reads the files named **disklist.conf** which are present in **/etc/amanda/backup-set-name/**

It creates a list of all Disk List Entries.

A DLE is a backup item - normally a file-system on a client host.

No additional configuration is required.

For the backup items (DLEs) found 3 things checked by this plugin:

* Minimum backup age
  * warning or critical if the most recent backup (for any item/DLE) is more than 2 or 3 days old.
    This is configurable in hours.
    Either level 0 or level 1+ backups qualify.
* Minimum backup size
  * warning or critical if the most recent *level 0* backup is less than 32k or 64k, respectively.
    This is configurable in k, M, G or T
* Minumum number of backup items (DLEs) found.
  * Critical if less than 1 backup item found, configurable.

In addition, the plugin will also

* Report as performance data the total size of all level 0 backups plus the most recent level 1 backups (for capacity planning), suitable for use with PNP4Nagios.

By default, every backup item (DLE) which is configured is checked, but the check can be restricted to a particular backup-set or server.

A PNP4Nagios template is also provided.

#### Sample Output - OK

**`/usr/lib/nagios/plugins/check_amanda.pl -C 50`**

`OK: 52 ok in 20 backup sets, size 1625Gi +314Gi|total_sets=20 total_servers=32 total_items=52 ok=52 warn=0 crit=0 l0size=1704404516k l1size=329119065k`

#### Sample Output - Errors

**`/usr/lib/nagios/plugins/check_amanda.pl -C 6 -i proxy,redmine -w 18 -s 1G`**

`CRITICAL: Only 5 backups found, 6 required, 2 warning in proxy (20hrs), redmine (49Mi), 3 ok in redmine (17hrs,15Gi), size 42Gi +397Mi|total_sets=2 total_servers=3 total_items=5 ok=3 warn=2 crit=0 l0size=44175852k l1size=406706k`

In this case, the plugin is reporting critical because there were only 5 items found, and we specified '-C 6' on the commmand line.

The backup-set 'proxy' is reporting a warning because of the most-recent backups in the set, the oldest is 20 hrs old, and we specified '-w 18' on the command line.

The backup-set 'redmine' is reporting a warning because the smallest backup in the set is 49M, and we specified '-s 1G' on the command line.

There are 3 backups which are OK in the backup set redmine, the oldest of which is 17 hrs old, and the total size of which is 15G, excluding the one which is not OK.

'proxy' has no OK backups, as it does not appear after the 'NN ok in...' message.

The latest level 0 backups in 'proxy' and 'redmine' use 42 Gi bytes, and this includes OK and non-OK backups.

Detailed per-backup-item information can be obtained by adding '-v' to the command line.

#### Sample Output - Verbose
**`/usr/lib/nagios/plugins/check_amanda.pl -I nagios -s 10M -v`**

`OK:       offsite-servers  cloud-nagios:        /var                      last backup l1 20150129040006   (6hrs) 146Mi+72Mi`
`OK:       internal-servers onsite-nagios:       /var                      last backup l0 20150128210024  (13hrs) 818Mi`
`Warning:  internal-servers onsite-nagios:       /etc                      last backup l0 20150128210024  (13hrs) 1268Ki`
`NO Conf:  test-servers     test-nagios:         /etc                      last backup l0 20150105034106    (24d) 894Ki`
`Oldest backup is 20150128210024 (13hrs)`
`WARNING: 1 warning in internal-servers (1268Ki), 2 ok in internal-servers (14hrs,818Mi), offsite-servers (7hrs,146Mi), size 965Mi +72Mi|total_sets=2 total_servers=2 total_items=3 ok=2 warn=1 crit=0 l0size=988216k l1size=73873k`

The '-v' flag turns on verbose output.

In this case, we have used -I to search all backup-sets for servers with 'nagios' in their name.

The status message is telling us that one of the item in internal-servers is in state warning because it's size is only 1268Ki, and '-s 10M' asks for a warning if any item is less than 10M in size.

The status message also tells us there are 2 items which are OK, and that these are within the backup-sets internal-servers and offsite-servers. The total l0 size of OK backups and oldest OK backup is show for each OK set.

The verbose messages above go to stderr output, and show us the state of each backup-item that was examined and included in the status message.

There is an additional message, 'NO Conf' that says that it found a backup-item for the server 'test-nagios' that did not have a corresponding disklist.conf entry. This means that the backup item or backup-set was removed, but the files were not purged from the disk.

Items which appear as 'NO Conf' are not included in the status message, nor in the performance data.

The 'Oldest backup' message is the oldest of all the most-recent backups which were considered (OK, Warning and Critical), excluding the 'No Conf' items.

### Use-case examples

#### Default use case

**`check_amanda.pl`**

Check all backup items with default settings:

* Warning if more than 2 days old, critical if more than 3 days old
* Warning if the most level 0 backup is less than 64k, critical if less and 32k
* Critical if no backup items found

**`check_amanda.pl -m /mnt/bigdisk`**

As above, but the 'backup media' directory is **/mnt/bigdisk** instead of the default **/mnt/store1**

#### Check specific backup sets
**`check_amanda.pl -i weekly-backups -w 168 -c 336`**

Check *only* the backup set named weekly-backups, warning if any item is more than *7 days* old (168 hours), critical if more than *14 days* old.

#### Search for specific client hosts
**`check_amanda.pl -I '(prod|prd)' -C 7 -w 24`**

Look for backup items for servers with 'prod' or 'prd' in their name, and ensure that **at least 7 items** (DLE's) are found. Generate a warning if any of these items are less than 24 hours old. (Other checks are performed as per the default settings).

#### Exclude specific backup sets
**`check_amanda.pl -x weekly-backups`**

Exclude the backup set named 'weekly-backups'. Check everything else against the default settings.

#### Exclude specific client hosts
**`check_amanda.pl -X '(dev|test)' -C 30`**

Exclude backup items for servers with 'dev' or 'test' in the name from the check. Check that at least 30 backup items are included in the check. Check everything else with the default settings.

### Notes

The arguments -i and -x expect a comma-seperated list of specific backup-set names (not regular expressions)

The arguments -I and -X expect a single regular expression and select by hostname. ie. to include a specific hostname only, use:

`-I '^my-db-server$'`

Other than checking size and date, no further integrity checking is done.

This plugin will normally be used with NRPE. The default timeout for check_nrpe is 10 seconds. Increase this to at least 60 seconds to avoid 'false criticals' due to the plugin taking a long time to go through the whole tree of backup items on the backup-media disk.

The plugin reads the 1st line of each backup item.

This plugin does not distinguish between a backup-in-progress and a completed-backup. 
ie. the total size reported may include backups-in-progress, and be lower than it should be.

#### Performance Data

This plugin generates some summary information as Nagios performance data. This can be graphed using PNP4Nagios.

Of particular interest are the items:

* l0size - the total size of the most recent level 0 backup for each backup item (DLE)
* l1size - the total size of the most recent level 1 backup which is more recent than the level 0 backup for each backup item

These statistics are reported for the selected backup-sets and servers only. ie. after -i/-x/-I/-X have been applied.

A PNP4Nagios template is supplied.