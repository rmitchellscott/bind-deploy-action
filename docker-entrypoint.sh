#!/usr/bin/env bash
set -eo pipefail

log_info1() {
  echo "-----> $*"
}

log_info2() {
  echo "=====> $*"
}

cd zones/
ZONESERIAL=$(date +"%s")
if [ -z "$MAGICSTRING" ]; then
  MAGICSTRING="1 ; SERIALAUTOUPDATE"
fi
CHANGEDFILES="*.zone"
# if [ "$1" == "allzones" ]; then
#   log_info1 "acting on all *.zone files"
#   CHANGEDFILES="*.zone"
# elif [ -f .lasthash ]; then
#   LASTHASH=$(cat .lasthash)
#   log_info1 ".lasthash found: ${LASTHASH}"
#   CHANGEDFILES=$(git diff --name-only HEAD "$LASTHASH" -- '*.zone')
# else
#   log_info1 ".lasthash not found"
#   CHANGEDFILES=$(git diff --name-only HEAD HEAD~1 -- '*.zone')
# fi

rm -f .oldserials.new && touch .oldserials.new
for file in $CHANGEDFILES; do
  # search for magic string - only do sed when found
  if grep -q "$MAGICSTRING" "$file"; then
    log_info2 "updating serial to $ZONESERIAL in $file"
    sed -i "s/${MAGICSTRING}/${ZONESERIAL} : SERIAL/" "$file"
    echo "${file%.zone}: ${ZONESERIAL}" >> .oldserials.new
  else
    log_info2 "${MAGICSTRING} not found in ${file}"
  fi
done

# Re-construct old serials where auto-update requested
for file in *.zone ; do
  if grep -q "$MAGICSTRING" "$file"; then
    zone="${file%.zone}"
    old_serial="$( grep "^${zone}: " .oldserials | awk '{ print $2; }' | tr -cd 0-9 )"
    # If the file in question isn't known yet, try to restore the value quickly
    [ -z "$old_serial" ] && old_serial="$( date +"%s" -r "$file" )"
    log_info2 "resetting serial in $file to $old_serial"
    sed -i "s/${MAGICSTRING}/${old_serial}/" "$file"
    echo "${file%.zone}: ${old_serial}" >> .oldserials.new
  fi
done

mv -f .oldserials.new .oldserials 

## Initialize
CURRENTHASH=$(git rev-parse HEAD)
FINALRC=0
RSYNCPARAMS="--itemize-changes --verbose --human-readable --times --checksum --recursive --delete --exclude-from=/etc/rsyncignore --delete-excluded"

log_info1 "Deploying zonefiles to hidden master"

if [ -z "$SSH_USER" ]; then
  SSH_USER="github"
fi
if [ -z "$RSYNC_DEST_DIR" ]; then
  RSYNC_DEST_DIR="zones"
fi
if [ -z "$SSH_CONFIG" ]; then
  SSH_CONFIG="Host *\n\tStrictHostKeyChecking no\n\tLogLevel=quiet\n\n"
fi
if [ -z "$NS_HIDDENMASTER" ]; then
  echo "FAILED - NS_HIDDENMASTER not set - don't know where to sync to"
  exit 1
elif [ -z "$SSH_PRIVATE_KEY" ]; then
  echo "FAILED - SSH_PRIVATE_KEY not set - cannot sync without SSH key"
  exit 1
else
  log_info2 "rsync to ${SSH_USER}@${NS_HIDDENMASTER}:${RSYNC_DEST_DIR} using a temporary SSH agent"
  eval "$(ssh-agent -s)" > /dev/null 2>&1
  ssh-add <(echo "$SSH_PRIVATE_KEY") > /dev/null 2>&1
  echo -e $SSH_CONFIG > /etc/ssh/ssh_config.d/NS_HIDDENMASTER.conf
  cat ~/.ssh/config
  #rsync $RSYNCPARAMS '.' "$SSH_USER"@"$NS_HIDDENMASTER":"$RSYNC_DEST_DIR"
  rc=$?; if [[ $rc != 0 ]]; then echo "rsync failed with $rc"; exit 1; fi
fi

log_info2 "Reloading all zones with rndc"
ssh "$SSH_USER"@"$NS_HIDDENMASTER" -v
#ssh "$SSH_USER"@"$NS_HIDDENMASTER" sudo rndc reload

# save current hash for later execution
log_info1 "Saving ${CURRENTHASH} in .lasthash"
echo "$CURRENTHASH" > .lasthash

## End script
exit "$FINALRC"