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
    param($salida) 
    #$PathLog = "C:\Users\Florencia\Documents\Facultad\PLAN2023\3654-VirtualizacionDeHardware\log"
    $PathLog = $event.MessageData.PathLog

     # Obtener la fecha y hora actual en el formato deseado
     $timestamp = (Get-Date).ToString("yyyyMMdd-HHmmss")

     # Crear el archivo de log
     $logFile = Join-Path -Path $PathLog -ChildPath "log-$timestamp.txt"
     "Se creo un archivo el $((Get-Date).ToString("yyyy-MM-dd HH:mm:ss"))" | Out-File -FilePath $logFile -Encoding UTF8 -Append

     # Crear el archivo ZIP con el log
     $zipFile = Join-Path -Path $PathLog -ChildPath "$timestamp.zip"
     Compress-Archive -Path $logFile -DestinationPath $zipFile
}

Register-ObjectEvent -InputObject $watcher -EventName Created -SourceIdentifier monitorCreador -Action $action -MessageData $messageData
    
$watcher.EnableRaisingEvents = $true

Start-Job -ScriptBlock {

    param($watcher)
        
    Wait-Event -SourceIdentifier monitorCreador 

} -ArgumentList $watcher


Get-EventSubscriber