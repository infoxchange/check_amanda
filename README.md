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

Then this plugin is for you.

### What it can do

This check reads the files named **disklist.conf** which are present in the directory **/etc/amanda/**_backup-set-name/_

It creates a list of all Disk List Entries (DLEs).

A DLE is a backup item - normally a file-system on a client host.

Other than specifying the top of the the backup file-tree using `-m /path/to/backups` no other configuration is required.

For the backup items (DLEs) found, 3 things are checked by this plugin:

* Minimum backup age
  * warning or critical if the most recent backup (for any item/DLE) is more than 2 or 3 days old.
    This is configurable in hours.
    Either level 0 or level 1+ backups qualify.
* Minimum backup size
  * warning or critical if the most recent *level 0* backup is less than 64k or 128k, respectively.
    This is configurable in k, M, G or T
* Minumum number of backup items (DLEs) found.
  * Critical if less than 1 backup item found, configurable.

In addition, the plugin will also

* Report as performance data the total size of all level 0 backups plus the most recent level 1 backups (for capacity planning), suitable for use with PNP4Nagios.

By default, every backup item (DLE) which is configured is checked, but the check can be restricted to a particular backup-set or client server.

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

'proxy' has no OK backups, as it does not appear after the '3 ok in...' message.

'size' reports that the latest level 0 backups in 'proxy' and 'redmine' use 42 Gi bytes, and this includes OK and non-OK backups.

Detailed, per-backup-item information can be obtained by adding '-v' to the command line.

#### Sample Output - Verbose
**`/usr/lib/nagios/plugins/check_amanda.pl -I nagios -s 10M -v`**

```
OK:       offsite-servers  cloud-nagios:        /var                      last backup l1 20150129040006   (6hrs) 146Mi+72Mi
OK:       internal-servers onsite-nagios:       /var                      last backup l0 20150128210024  (13hrs) 818Mi
Warning:  internal-servers onsite-nagios:       /etc                      last backup l0 20150128210024  (13hrs) 1268Ki
NO Conf:  test-servers     test-nagios:         /etc                      last backup l0 20150105034106    (24d) 894Ki
Oldest backup is 20150128210024 (13hrs)
WARNING: 1 warning in internal-servers (1268Ki), 2 ok in internal-servers (14hrs,818Mi), offsite-servers (7hrs,146Mi), size 965Mi +72Mi|total_sets=2 total_servers=2 total_items=3 ok=2 warn=1 crit=0 l0size=988216k l1size=73873k
```

The '-v' flag turns on verbose output.

In this case, we have used `-I` to search all backup-sets for servers with 'nagios' in their name.

The status message is telling us that one of the item in internal-servers is in state warning because it's size is only 1268Ki, and `-s 10M` asks for a warning if any item is less than 10M in size.

The status message also tells us there are 2 items which are OK, and that these are within the backup-sets internal-servers and offsite-servers. The total l0 size of OK backups and age of the oldest OK backup is shown for each OK backup-set.

The verbose messages shown above go to stderr output, and show us the state of each backup-item that was examined and included in the status message.

There is an additional message, 'NO Conf' that says that it found a backup-item for the server 'test-nagios' that did not have a corresponding disklist.conf entry. This means that the backup-item or backup-set was removed, but the files were not purged from the disk.

Items which appear as 'NO Conf' are not included in the status message, nor in the performance data.

The 'Oldest backup' message is the oldest of all the most-recent backups which were considered (OK, Warning and Critical), excluding the 'No Conf' items.

#### Sample Output - List Files
```
# /usr/lib/nagios/plugins/ixa/check_amanda.pl -I samba -l
OK:       samba-set         samba-srv-01:          /data/groups               last backup l1 20150729183007  (15hrs) 766Gi+425Mi
   /mnt/store1/samba-set/slot60/00001.samba-srv-01._data_groups.0
   /mnt/store1/samba-set/slot68/00001.samba-srv-01._data_groups.1
OK:       samba-set         samba-srv-01:          /data/homes                last backup l2 20150729183007  (15hrs) 154Gi+68Gi
   /mnt/store1/samba-set/slot59/00001.samba-srv-01._data_homes.0
   /mnt/store1/samba-set/slot65/00001.samba-srv-01._data_homes.1
   /mnt/store1/samba-set/slot67/00001.samba-srv-01._data_homes.2
Oldest backup is 20150729183007 (15hrs)
OK: 2 ok in samba-set (15hrs,920Gi), size 920Gi +69Gi|total_sets=1 total_servers=1 total_items=2 ok=2 warn=0 crit=0 l0size=965122950k l1size=72047326k
```
The '-l' flag turns on the 'list files' output and also turns on verbose output.

In the above output, we have 2 backup items (DLE's) for the server `samba-srv-01` these being `/homes` and `/groups`
The individual status messages `OK: ...` tells us the size and age of the most recent backup. Underneath the status message are listed the most recent level 0, level 1 and (if applicable) level 2 backup-files that would be required to restore the most recent backup.

This can be useful if there is a problem with the most-recent backup, and makes it easy to locate the files in question.

It is also useful for `NO Conf: ...` backups, which still have a presence on the backup file-system, but are not present in the Zmanda web-interface.

### Use-case examples

#### Default use case

**`check_amanda.pl`**

Check all backup items with default settings:

* Warning if more than 2 days old, critical if more than 3 days old
* Warning if the most recent level 0 backup is less than 64k, critical if less than 32k
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

The `-X ...` option is particularly useful for excluding servers which have been retired (decomissioned), but for which the backup config and data are still kept (in order to make it easy to restore data if required).

### Notes

The arguments -i and -x expect a comma-seperated list of specific backup-set names (not regular expressions)

The arguments -I and -X expect a single regular expression and select by hostname. ie. to include a specific hostname only, use:

`-I '^my-db-server$'`

A backup with a file-size of zero (after subtracting the header) is considered a failed backup, and is ignored.

Other than checking size and date, no further integrity checking is done.
ie. this plugin will not detect corrupted or truncated backups.
Although this would be feasible, such a check would not be likely complete in under 60s.

This plugin will normally be used with NRPE. The default timeout for check_nrpe is 10 seconds. Increase this to at least 60 seconds to avoid 'false criticals' due to the plugin taking a long time to go through the whole tree of backup items on the backup-media disk.

The plugin reads the 1st line of each backup item.

This plugin distinguishs between a backup-in-progress and a completed-backup by using the time-stamp on the file.
Any backup file modified in the last 30 seconds is considered 'in-progress' and is excluded from the check results.
The next-oldest file is used instead.

### Sample config

```
define service {
  use                            generic-service-quiet          ; template name
  service_description            amanda-backups
  hostgroup_name                 backup-servers
  check_interval                 60
  max_check_attempts             12
  retry_interval                 5
  notification_interval          120
  stalking_options               o,w,c    ; save output when it changes - should be infrequent}
  check_command                  check_nrpe_1arg!check_amanda -t 60
```

`nrpe.cfg` config

```
command[check_amanda]=/usr/bin/sudo -u amandabackup /usr/lib/nagios/plugins/check_amanda.pl -C 50
```

`/etc/sudoers` config

```
Defaults:nagios !requiretty
nagios	ALL=(amandabackup) NOPASSWD: /usr/lib/nagios/plugins/check_amanda.pl
```

### Performance Data

This plugin generates some summary information as Nagios performance data. This can be graphed using PNP4Nagios.

Of particular interest are the items:

* l0size - the total size of the most recent level 0 backup for each backup item (DLE)
* l1size - the total size of the most recent level 1 backup which is more recent than the level 0 backup for each backup item

These statistics are reported for the selected backup-sets and servers only. ie. after -i/-x/-I/-X have been applied.

A PNP4Nagios template is supplied.

![Sample pnp4nagios graphs](check_amanda.pnp4nagios.png)

In the sample graph, there are a number of failing checks on the 22nd of the month.
This is due to new backups being added, and not having been backed up yet.

This shows on the output as 
```
CRITICAL: 14 critical in internal-servers (never), 43 ok in 19 backup sets, size 1785Gi +75Gi
```
Running a manual backup will clear this alert, once the backup is complete.

The l0size and l1size statistics are useful for estimating what retention is feasible.

The l0size and l1size give a simple answer to the question:
* Q. How much disk space do I need to store 4 weeks of full weekly backups and their daily incremental backups?
* A. 4 * l0size + 24 * l1size = 1.92T * 4 + 89.7G * 24 = 9.8 TB

Note that the plugin is reporting 1785 GiB (gibi bytes, ie 1024^3), while rrdtool is reporting 1917 GB (giga bytes, ie 10^9)

l0size and l1size are also useful for observing trends in the size of a complete backup of all servers.
Simple disk-usage statistics are difficult to interpret, because they do not show how many complete backups are present at any time.

