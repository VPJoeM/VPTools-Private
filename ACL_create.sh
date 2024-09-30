#!/bin/bash

# Function to get user input for a variable
get_input() {
    read -p "$1: " response
    echo "$response"
}

if [ -f "./saved_token.txt" ]; then
    read -p "Do you want to use the saved token? (yes/no): " use_saved_token
    if [ "$use_saved_token" = "yes" ]; then
        TOKEN=$(<saved_token.txt)
    else
        TOKEN=$(get_input "Enter API Key (token)")
        read -p "Would you like to save the token for future use? (yes/no): " save_token
        if [ "$save_token" = "yes" ]; then
            echo "$TOKEN" > saved_token.txt
        fi
    fi
else
    TOKEN=$(get_input "Enter API Key (token)")
    read -p "Would you like to save the token for future use? (yes/no): " save_token
    if [ "$save_token" = "yes" ]; then
        echo "$TOKEN" > saved_token.txt
    fi
fi

CUSTOMER_NAME=$(get_input "Enter customer name")
ORDER_ID=$(get_input "Enter order ID (usually same as customer name)")

RULES=()

while true; do
    NEW_PRIVATE_IP=$(get_input "Enter new node private IP")
    NEW_PUBLIC_IP=$(get_input "Enter new node public IP")

    RULES+=("{
        \"private_ip\": \"$NEW_PRIVATE_IP\",
        \"public_ip\": \"$NEW_PUBLIC_IP\",
        \"source_ip\": \"any\",
        \"source_port\": \"any\",
        \"customer\": \"$CUSTOMER_NAME\",
        \"orderID\": \"$ORDER_ID\",
        \"action\": \"add\"
    }")

    read -p "Do you want to add more IPs? (yes/no): " add_more
    if [ "$add_more" != "yes" ]; then
        break
    fi
done

RULE_DATA="["
for RULE in "${RULES[@]}"; do
    RULE_DATA+="$RULE,"
done
RULE_DATA="${RULE_DATA%,}]"

curl -k -X POST https://10.15.231.200/vpa \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "$RULE_DATA"

echo "Firewall rule(s) added successfully."
