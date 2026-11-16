/*
 * Author: andip71, 01.09.2017
 *
 * Version 1.1.0
 *
 * This software is licensed under the terms of the GNU General Public
 * License version 2, as published by the Free Software Foundation, and
 * may be copied, distributed, and modified under those terms.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 */

#define BOEFFLA_WL_BLOCKER_VERSION	"1.1.0"

/*
 * odin adaptation (2026-11-15): the compiled-in default list MUST stay
 * empty. Do not preset any wakelock names here - names are only ever
 * added at runtime via sysfs, after on-device evidence from
 * /sys/kernel/wakeup_sources (see prep REPORT.md). With both lists
 * empty the search string is ";;;" and wl_blocker_active stays false,
 * i.e. the hook in wakeup.c is a no-op and suspend behaviour is
 * identical to a kernel without this driver.
 */
#define LIST_WL_DEFAULT				""

#define LENGTH_LIST_WL				255
#define LENGTH_LIST_WL_DEFAULT		100
#define LENGTH_LIST_WL_SEARCH		LENGTH_LIST_WL + LENGTH_LIST_WL_DEFAULT + 5
