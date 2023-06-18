#!/bin/bash

# Get the filename from the command line arguments
filename=$1

while IFS= read -r domain
do
    # get the IP address
    ip=$(dig +short "$domain")

    # print the domain and its IP address on one line
    echo "$domain - $ip"
done < "$filename"
