#!/usr/bin/pwsh

if ($args[0] -eq "--config") {
    write-host '{
        "configVersion":"v1",
        "kubernetes":[{
          "apiVersion": "v1",
          "kind": "Pod",
          "watchEvent":["Added","Deleted"]
        }]
    }'
} else {
    Write-Host "pwsh input"
    $hookdata=(gc $env:BINDING_CONTEXT_PATH | convertfrom-json)
    $podname=$hookdata.object.metadata.name
    $eventname=$hookdata.watchEvent
    write-host "$podname was $eventname!"
}
