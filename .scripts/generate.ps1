[CmdletBinding()]
param (
    [Parameter()]
    [string[]]
    $swaggers,

    [Parameter()]
    [string]
    [AllowEmptyString()]
    $outputRoot = '',

    [Parameter()]
    [switch]
    $autorestVersion
)
# load test names
. $PSScriptRoot/tests.ps1

if( $swaggers -ne $null) {
  $azureInputs = $azureInputs |% { if( $swaggers.indexOf( $_ ) -gt -1 )  { return $_ } }
  $inputs = $inputs |% { if( $swaggers.indexOf( $_ ) -gt -1 )  { return $_ } }
}

# generates the AutoRest tests into separate modules

$root = ( resolve-path "$PSScriptRoot/..").Path

if( ($outputRoot -eq $null ) -or ($outputRoot -eq ''))  {
  $outputRoot = ( resolve-path "$root/tests").Path
}
$null = New-Item $outputRoot  -force -ItemType Directory 
cd $root

# source location for swagger files
$swaggerRoot = "http://localhost:3000/__files/"
 
# AutoRest Choice
$autorest = (get-command autorest-beta -ea 0 ).Source 

if( -not $autorest )  {
  write-error "AutoRest command (autorest-beta) not found in path."
  return 1;
}

if( $autorestVersion ) {
  $autorestArgs = @( "--version:$($autorestVersion)" )
} else {
  $autorestArgs = @(  )
}


# use local generator
$powershellGenerator="--use:$(resolve-path $root/powershell)"

# use local remodeler if it's here.
if( test-path $root/../autorest.remodeler/remodeler ) {
  $remodeler="--use:$(resolve-path $root/../autorest.remodeler/remodeler)"
}

$success = @{}
$errors = @{}
$broken = @{}

function run-autorest($src) {
  $name = $src
  $src = "$name.json"
  
  $outputFolder = "$outputRoot/$name"
  
  $txt = "$autorest $autorestArgs $powershellGenerator $remodeler --input-file:$swaggerRoot$src --output-folder:$outputFolder --clear-output-folder --title:$name $args" 
  write-host -fore GREEN "`n--------------------------------------------------------`nGenerating [$name]`n--------------------------------------------------------`n"
  
  & $autorest $autorestArgs $powershellGenerator $remodeler "--input-file:$swaggerRoot$src" "--output-folder:$outputFolder" "--clear-output-folder" "--title:$name"  $args
  $rc = $LastExitCode
  if( $rc -gt 0 ) {
    write-host -fore RED "`n--------------------------------------------------------`nFAILED GENERATION [$name]`n--------------------------------------------------------`n"
    $errors[$src] = $txt
  } else {
    & "$outputFolder/build-module.ps1"
    $rc2 = $lastExitCode
    if( $rc2 -gt 0  ){
    write-host -fore RED "`n--------------------------------------------------------`nFAILED COMPILATION [$name]`n--------------------------------------------------------`n"
        $broken[$src] = $txt
    } else {
        write-host -fore GREEN "`n--------------------------------------------------------`nSUCCESS [$name]`n--------------------------------------------------------`n"
        $success[$src] = $txt
    }
  }
}


$n = 0;

$inputs |% {
 if( $n -le 99 ) {

    run-autorest $_
  }
  $n = $n + 1
}

$azureInputs |% {
  run-autorest $_ --azure 
}

$success.Keys |% {
    write-host -fore GREEN $_  
}
$errors.Keys |% {
    write-host -fore RED $_  
}
$broken.Keys |% {
    write-host -fore YELLOW $_  
}
