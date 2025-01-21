# Ensure you're logged into Azure and the correct subscription is selected
.\az_logins.ps1  # Run your script to log in and select the desired subscription

# Confirm the current subscription
$currentSubscription = az account show --query "{Name:name, Id:id}" -o json | ConvertFrom-Json
Write-Output "Using subscription: $($currentSubscription.Name) ($($currentSubscription.Id))"

# Get all Service Bus namespaces in the current subscription
$serviceBusNamespaces = az servicebus namespace list --query "[].{Name:name, ResourceGroup:resourceGroup}" -o json | ConvertFrom-Json

# Check if there are any Service Bus namespaces
if (-not $serviceBusNamespaces) {
    Write-Output "No Service Bus namespaces found in the subscription: $($currentSubscription.Name)"
    return
}

# Initialize an array to store results
$results = @()

# Loop through each Service Bus namespace and get the Minimum TLS Version
foreach ($namespace in $serviceBusNamespaces) {
    $name = $namespace.Name
    $resourceGroup = $namespace.ResourceGroup

    # Get the configuration details for the Service Bus namespace
    $tlsVersion = az servicebus namespace show --name $name --resource-group $resourceGroup --query "minimumTlsVersion" -o tsv

    # Add the result to the array
    $results += [pscustomobject]@{
        ServiceBusName = $name
        ResourceGroup  = $resourceGroup
        MinimumTLS     = $tlsVersion
    }
}

# Output the results
if ($results.Count -eq 0) {
    Write-Output "No TLS settings found for Service Bus namespaces."
} else {
    $results | Format-Table -AutoSize
}

# Optional: Export results to a CSV file for further analysis
$results | Export-Csv -Path "./ServiceBusTLSSettings.csv" -NoTypeInformation
Write-Output "Service Bus TLS settings exported to ServiceBusTLSSettings.csv"