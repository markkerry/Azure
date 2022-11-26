$end = Get-Date

# Log name in Log Analytics
$logType = "makemeadmin"

# Log name in Event Viewer
$logName = "Make Me Admin"

$computerName = $env:COMPUTERNAME
$userName = Get-CimInstance -Class Win32_ComputerSystem | Select-Object -ExpandProperty UserName
if ($userName.StartsWith("AzureAD\")) {
    $userName = $userName.Substring(8)
}

# Ensure Make Me Admin is registered i.e. has been run before
$events = Get-EventLog -LogName Application -Source $logName -InstanceId 0,1 -ErrorAction SilentlyContinue
if (!($events)) {
    Write-Host "Make Me Admin has not been run on this machine yet"
    exit 0
}
else {
    Write-Host "Make Me Admin events found on $computerName"
}

$lastPosted = Get-EventLog -LogName Application -Source $logName -InstanceId 3001 -Newest 1 -ErrorAction SilentlyContinue | Select-Object -ExpandProperty TimeWritten

# Replace with your Workspace ID
$customerId = ""  

# Replace with your Primary Key
$sharedKey = ""

# Optional name of a field that includes the timestamp for the data. If the time field is not specified, Azure Monitor assumes the time is the message ingestion time
$TimeStampField = $end

# Create the function to create the authorization signature
function Build-Signature ($customerId, $sharedKey, $date, $contentLength, $method, $contentType, $resource)
{
    $xHeaders = "x-ms-date:" + $date
    $stringToHash = $method + "`n" + $contentLength + "`n" + $contentType + "`n" + $xHeaders + "`n" + $resource

    $bytesToHash = [Text.Encoding]::UTF8.GetBytes($stringToHash)
    $keyBytes = [Convert]::FromBase64String($sharedKey)

    $sha256 = New-Object System.Security.Cryptography.HMACSHA256
    $sha256.Key = $keyBytes
    $calculatedHash = $sha256.ComputeHash($bytesToHash)
    $encodedHash = [Convert]::ToBase64String($calculatedHash)
    $authorization = 'SharedKey {0}:{1}' -f $customerId,$encodedHash
    return $authorization
}

# Create the function to create and post the request
function Post-LogAnalyticsData($customerId, $sharedKey, $body, $logType)
{
    $method = "POST"
    $contentType = "application/json"
    $resource = "/api/logs"
    $rfc1123date = [DateTime]::UtcNow.ToString("r")
    $contentLength = $body.Length
    $signature = Build-Signature `
        -customerId $customerId `
        -sharedKey $sharedKey `
        -date $rfc1123date `
        -contentLength $contentLength `
        -method $method `
        -contentType $contentType `
        -resource $resource
    $uri = "https://" + $customerId + ".ods.opinsights.azure.com" + $resource + "?api-version=2016-04-01"

    $headers = @{
        "Authorization" = $signature;
        "Log-Type" = $logType;
        "x-ms-date" = $rfc1123date;
        "time-generated-field" = $TimeStampField;
    }

    $response = Invoke-WebRequest -Uri $uri -Method $method -ContentType $contentType -Headers $headers -Body $body -UseBasicParsing
    return $response.StatusCode
}

# Get MakeMeAdmin events
if ($lastPosted) {
    Write-Host "Events have been posted before. Gathering MakeMeAdmin events since last POST"
    $newEvents = Get-EventLog -LogName Application -Source $logName -InstanceId 0,1 -After $lastPosted -ErrorAction SilentlyContinue | Select-Object TimeWritten,Message
}
else {
    Write-Host "Events have NOT been posted before. Gathering all MakeMeAdmin events to POST"
    $newEvents = Get-EventLog -LogName Application -Source $logName -InstanceId 0,1 -ErrorAction SilentlyContinue | Select-Object TimeWritten,Message
}

if ($newEvents) {
    Write-Host "New events have been found since the last POST"
    $List = New-Object System.Collections.ArrayList
    foreach ($e in $newevents) {
        $date = $e.TimeWritten | Select-Object -ExpandProperty DateTime
        $y = New-Object PSCustomObject
        $y | Add-Member -Membertype NoteProperty -Name EventTime -Value $date
        $y | Add-Member -Membertype NoteProperty -Name UserName -value $userName
        $y | Add-Member -Membertype NoteProperty -Name ComputerName -value $computerName
        $y | Add-Member -Membertype NoteProperty -Name Message -Value $e.Message
        $List.Add($y) | Out-Null
    }

    $json = ConvertTo-Json $List
}
else {
    Write-Host "No events have been found since the last POST"
    exit 0
}

# Submit the data to the API endpoint
if ($json) {
    Write-Host "Events gathered. Posting to Azure Log Analytics"
    $post = Post-LogAnalyticsData -customerId $customerId -sharedKey $sharedKey -body ([System.Text.Encoding]::UTF8.GetBytes($json)) -logType $logType
    if ($post -eq 200) {
        Write-Host "Response 200. Writing Events Posted to Event Log"
        Write-EventLog -LogName "Application" -Source "Make Me Admin" -EventID 3001 -EntryType Information -Message "MakeMeAdmin events sent to Azure Log Analytics" -Category 0 -RawData 10,20
    }
    else {
        Write-Host "Post failed"
    }
}