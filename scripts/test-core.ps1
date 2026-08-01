$ErrorActionPreference = 'Stop'

Push-Location (Join-Path $PSScriptRoot '..\core')
try {
    gofmt -w .
    go test ./...
    go vet ./...
}
finally {
    Pop-Location
}

