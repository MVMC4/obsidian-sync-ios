$ErrorActionPreference = 'Stop'

Push-Location (Join-Path $PSScriptRoot '..\core')
try {
    gofmt -w .
    go test -tags noassets ./...
    go vet -tags noassets ./...
}
finally {
    Pop-Location
}
