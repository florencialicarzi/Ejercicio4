Param (

    [CmdletBinding()]
    [Parameter(Mandatory = $true, ParameterSetName = 'Inicio')]
#    [Parameter(Mandatory = $true, ParameterSetName = 'Kill')]
    [ValidateNotNullOrEmpty()]
    [string]$directorio,

    [CmdletBinding()]
    [Parameter(Mandatory = $true, ParameterSetName = 'Inicio')]
    [string]$salida

 #   [CmdletBinding()]
 #   [Parameter (Mandatory = $true, ParameterSetName = 'Kill')]
 #   [switch]$kill = $false
#
)

if( -not (Test-Path $directorio)) {
    Write-Output "El Path a monitorear enviado por parametro no existe."
    exit 1
}

if( -not (Test-Path $salida)) {
    Write-Output "El Path donde se crean los logs enviado por parametro no existe."
    exit 1
}

#if ($kill) {
#    Stop-Monitoring
#    exit 1
#}

New-Object System.IO.FileSystemWatcher | Get-Member -Type Event | Select-Object Name

# 1 - InputObject
# 2 - EventName -> Evento asociado al objeto.
# 3 - SourceIdentifier
# 4 - Action

$watcher = New-Object System.IO.FileSystemWatcher


$watcher.Path = $directorio

$watcher.NotifyFilter = [System.IO.NotifyFilters]'FileName'


$messageData = [PSCustomObject]@{
    PathLog    = $salida
    Directorio = $directorio
}
 
$action = {
    $PathLog = $event.MessageData.PathLog

    # Obtener la fecha y hora actual en el formato deseado
    $timestamp = (Get-Date).ToString("yyyyMMdd-HHmmss")

    # Crear una carpeta para almacenar el archivo de log
    $logFolder = Join-Path -Path $PathLog -ChildPath "BackUpLog-$timestamp"
    if (-not (Test-Path $logFolder)) {
        New-Item -Path $logFolder -ItemType Directory | Out-Null
    }

    # Crear el archivo de log dentro de la carpeta
    $logFile = Join-Path -Path $logFolder -ChildPath "log-$timestamp.txt"
    "Se creó un archivo el $((Get-Date).ToString("yyyy-MM-dd HH:mm:ss"))" | Out-File -FilePath $logFile -Encoding UTF8

    # Crear el archivo ZIP de la carpeta
    $zipFile = Join-Path -Path $PathLog -ChildPath "$timestamp.zip"
    Compress-Archive -Path $logFolder -DestinationPath $zipFile

    # Eliminar la carpeta original después de comprimirla
    Remove-Item -Path $logFolder -Recurse -Force
}

Register-ObjectEvent -InputObject $watcher -EventName Created -SourceIdentifier monitorCreador -Action $action -MessageData $messageData
    
$watcher.EnableRaisingEvents = $true

Start-Job -ScriptBlock {

    param($watcher)
        
    Wait-Event -SourceIdentifier monitorCreador 

} -ArgumentList $watcher


Get-EventSubscriber