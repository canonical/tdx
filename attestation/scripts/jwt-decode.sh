function jwt-decode() {
  sed 's/\./\n/g' <<< $(cut -d. -f1,2 <<< $1) | base64 --decode | jq
}

# This script will allow to dump the attestation token we receive from the intel trust authority
# the attestation is a JWT

# Usage
# echo "xxxx" | jwt-decode.sh

read JWT

jwt-decode $JWT
