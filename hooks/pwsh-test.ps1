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
    $args[0] | convertfrom-json
    Write-Host "json input"
    $args[0]
}
