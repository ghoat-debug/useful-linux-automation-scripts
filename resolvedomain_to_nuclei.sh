#!/bin/bash

#this script will take a domain and resolve it then redirect output to nuclei
# Prompt for a domain name or website
read -p "Enter a domain name or website: " domain

# Resolve the domain to HTTPS or HTTP using httpx
protocol=$(httpx -silent -j $domain | jq -r '.protocol')

# Redirect the output to nuclei
nuclei -l $protocol://$domain

# Write all the domains to a new file with the resolved extension
echo $protocol://$domain >> domains.txt

# Redirect the file to nuclei
nuclei -l -f domains.txt

