#!/bin/sh
# Copyright (C) 2022 Greenbone AG
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

[ -z "$USER" ] && USER="admin"
[ -z "$PASSWORD" ] && PASSWORD="admin"
[ -z "$GVMD_ARGS" ] && GVMD_ARGS="-f --listen-mode=666"
[ -z "$GVMD_USER" ] && GVMD_USER="gvmd"
[ -z "$PGRES_DATA" ] && PGRES_DATA="/var/lib/postgresql"

if [ -n "$GVM_CERTS" ] && [ "$GVM_CERTS" = true ]; then
    echo "Generating certs"
    gvm-manage-certs -a
fi

# check for psql connection
FILE=$PGRES_DATA/started
until test -f "$FILE"; do
    echo "waiting 1 second for ready postgres container"
    sleep 1
done
until psql -U "$GVMD_USER" -d gvmd -c "SELECT 'connected' as connection"; do
    echo "waiting 1 second to retry psql connection"
    sleep 1
done

# migrate db if necessary
gvmd --migrate || true

gvmd --create-user=$USER --password=$PASSWORD || true

# set the feed import owner
uid=$(gvmd --get-users --verbose | grep "^$USER " | awk '{print $2}')
gvmd --modify-setting 78eceaec-3385-11ea-b237-28d24461215b --value "$uid"
# set the agent owner
gvmd --modify-setting 1ee1f106-8b2e-461c-b426-7f5d76001b29 --value "$uid"

echo "starting gvmd"
gvmd $GVMD_ARGS ||
    (echo "Starting gvmd failed" && exit 1)