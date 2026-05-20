param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]] $ArgsRest
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
& python (Join-Path $scriptDir "fcc.py") @ArgsRest
exit $LASTEXITCODE
