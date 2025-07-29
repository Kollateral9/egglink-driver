#!/bin/bash -e

FILECONF=egglink-v3.conf

# Compute the new serial number
SERIAL=$(grep -Eo '^\s*serial=[^\s#$]*' "${FILECONF}")
NEWSERIAL="$SERIAL"
while echo "$NEWSERIAL" | grep '@' > /dev/null; do
    NEWSERIAL=$(echo "$NEWSERIAL" | sed "s/@/$(tr -dc A-Z0-9 </dev/urandom | head -c 1)/")
done
#echo "Cfg serial: $(eval ${SERIAL}; echo $serial; unset serial)"
echo "New serial: $(eval ${NEWSERIAL}; echo $serial; unset serial)"

set +e

# Write EEPROM
TMPFILE="$(mktemp)"
sed "s/^${SERIAL}/${NEWSERIAL}/" "${FILECONF}" > "${TMPFILE}"
#echo "Temporary config file: '${TMPFILE}'"

ftdi_eeprom --flash-eeprom "${TMPFILE}"
CMD_RES=$?

rm "${TMPFILE}"
if [ $CMD_RES -ne 0 ]; then
    echo "Failed (for non-standard VID/PID try to run with sudo)" >&2
    exit $CMD_RES
fi
echo "Success"
