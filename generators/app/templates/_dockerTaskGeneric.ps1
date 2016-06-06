<#
.SYNOPSIS
Builds and runs a Docker image.
.PARAMETER Compose
Runs docker-compose.
.PARAMETER Build
Builds a Docker image.
.PARAMETER Clean
Removes the image <%= imageName %> and kills all containers based on that image.
.PARAMETER Environment
The enviorment to build for (Debug or Release), defaults to Debug
.EXAMPLE
C:\PS> .\dockerTask.ps1 -Build
Build a Docker image named <%= imageName %>
#>

Param(
    [Parameter(Mandatory=$True,ParameterSetName="Compose")]
    [switch]$Compose,
    [Parameter(Mandatory=$True,ParameterSetName="Build")]
    [switch]$Build,
    [Parameter(Mandatory=$True,ParameterSetName="Clean")]
    [switch]$Clean,
    [Parameter(Mandatory=$True,ParameterSetName="RemoteDebug")]
    [switch]$RemoteDebug,
    [parameter(ParameterSetName="Compose")]
    [parameter(ParameterSetName="Build")]
    [ValidateNotNullOrEmpty()]
    [String]$Environment = "Debug",
    [parameter(ParameterSetName="Compose")]
    [parameter(ParameterSetName="Build")]
    [parameter(ParameterSetName="RemoteDebug")]
    [String]$Machine,
    [parameter(ParameterSetName = "RemoteDebug", Mandatory = $True)]
    [ValidateNotNullOrEmpty()]
    [String]$Command,
    [parameter(Mandatory=$False,ParameterSetName="Compose")]
    [bool]$RemoteDebugging = $False
)

$imageName="<%= imageName %>"<% if (projectType === 'aspnet') { %>
$projectName="<%= projectName %>"
$containerName="<%= '${projectName}_${imageName}' %>_1"<% } %>
$publicPort=<%= portNumber %>

# Kills all running containers of an image and then removes them.
function CleanAll () {
    # List all running containers that use $imageName, kill them and then remove them.
    docker ps -a | select-string -pattern $imageName | foreach { $containerId =  $_.ToString().split()[0]; docker kill $containerId *>&1 | Out-Null; docker rm $containerId *>&1 | Out-Null }
}

# Builds the Docker image.
function BuildImage () {
    $dockerFileName="Dockerfile.$Environment"

    if (Test-Path $dockerFileName) {
        Write-Host "Building the image $imageName ($Environment)."
        docker build -f $dockerFileName -t $imageName .
    }
    else {
        Write-Error -Message "$Environment is not a valid parameter. File '$dockerFileName' does not exist." -Category InvalidArgument
    }
}

# Runs docker-compose.
function Compose () {
    $composeFileName="docker-compose.$Environment.yml"

    if (Test-Path $composeFileName) {
        if ($RemoteDebugging) {
            $env:REMOTE_DEBUGGING = 1
        }
        
        Write-Host "Running compose file $composeFileName"
        docker-compose -f $composeFileName kill
        docker-compose -f $composeFileName up -d --build<% if (isWebProject) { %>

        if (-not $RemoteDebugging) {
            OpenSite
        }<% } %>
    }
    else {
        Write-Error -Message "$Environment is not a valid parameter. File '$dockerFileName' does not exist." -Category InvalidArgument
    }
}<% if (projectType === 'aspnet') { %>

function RemoteDebug () {
    $url = "http://localhost:$publicPort"
    if (![System.String]::IsNullOrWhiteSpace($Machine)) {
        $url = "http://$(docker-machine ip $Machine):$publicPort"
    }
    Write-Host "Running on $url"

    $containerId = (docker ps -f "name=$containerName" -q -n=1)
    if ([System.String]::IsNullOrWhiteSpace($containerId)) {
        Write-Error "Could not find a container nammed $containerName"
    }

    $shellCommand = "docker exec -i $containerId $Command"
    Invoke-Expression $shellCommand
}<% } %><% if (isWebProject) { %>

# Opens the remote site
function OpenSite () {
    $url = "http://localhost:$publicPort"
    if (![System.String]::IsNullOrWhiteSpace($Machine)) {
        $url = "http://$(docker-machine ip $Machine):$publicPort"
    }
    Write-Host "Opening site" -NoNewline
    $status = 0

    #Check if the site is available
    while($status -ne 200) {
        try {
            $response = Invoke-WebRequest -Uri $url -Headers @{"Cache-Control"="no-cache";"Pragma"="no-cache"} -UseBasicParsing
            $status = [int]$response.StatusCode
        }
        catch [System.Net.WebException] { }
        if($status -ne 200) {
            Write-Host "." -NoNewline
            Start-Sleep 1
        }
    }

    Write-Host
    # Open the site.
    Start-Process $url
}<% } %>

function SetMachine () {
    if (![System.String]::IsNullOrWhiteSpace($Machine)) {
        docker-machine env $Machine --shell powershell | Invoke-Expression
    }
}

# Call the correct function for the parameter that was used
if($Compose) {
    SetMachine
    Compose
}
elseif($Build) {
    SetMachine
    BuildImage
}
elseif ($Clean) {
    SetMachine
    CleanAll
}
elseif ($RemoteDebug) {
    SetMachine
    RemoteDebug
}