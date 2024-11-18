Param (

    [CmdletBinding()]
    [Parameter(Mandatory = $true, ParameterSetName = 'Inicio')]
    [Parameter(Mandatory = $true, ParameterSetName = 'Kill')]
    [ValidateNotNullOrEmpty()]
    [string]$directorio,

    [CmdletBinding()]
    [Parameter(Mandatory = $true, ParameterSetName = 'Inicio')]
    [string]$salida,

    [CmdletBinding()]
    [Parameter (Mandatory = $true, ParameterSetName = 'Kill')]
    [switch]$kill = $false
#
)

if( -not (Test-Path $directorio)) {
    Write-Output "El Path a monitorear enviado por parametro no existe."
    exit 1
}


# Función para verificar si un directorio ya está siendo monitoreado
function VerificarMonitoreo {
    param ($directorio)
    return Get-EventSubscriber | Where-Object {
        $_.SourceObject.Path -eq $directorio -and $_.EventName -eq 'Created'
    }
}

# Lógica para detener monitoreo con el flag -kill
if ($kill) {
    $suscriptor = VerificarMonitoreo -directorio $directorio
    if ($null -ne $suscriptor) {
        $suscriptor | Unregister-Event
        Write-Output "Monitoreo detenido para el directorio $directorio."
    } else {
        Write-Output "No se encontró un monitoreo activo para el directorio $directorio."
    }
    exit
}

# Validar si el directorio ya está siendo monitoreado
if (VerificarMonitoreo -directorio $directorio) {
    Write-Output "Ya existe un proceso monitoreando el directorio $directorio."
    exit 1
}


if( -not (Test-Path $salida)) {
    Write-Output "El Path donde se crean los logs enviado por parametro no existe."
    exit 1
}
New-Object System.IO.FileSystemWatcher | Get-Member -Type Event | Select-Object Name

# 1 - InputObject
# 2 - EventName -> Evento asociado al objeto.
# 3 - SourceIdentifier
# 4 - Action

$watcher = New-Object System.IO.FileSystemWatcher


$watcher.Path = $directorio

$watcher.NotifyFilter = [System.IO.NotifyFilters]'FileName'

$watcher.Filter = "*"

$watcher.IncludeSubdirectories = $true


$messageData = [PSCustomObject]@{
    PathLog    = $salida
    Directorio = $directorio
}
 
$action = {
    #*PARAMETROS DEL CONTEXTO
    $PathLog = $event.MessageData.PathLog
    $directorio = $event.MessageData.Directorio

    #*PARAMETROS DEL EVENTO
    $filePath = $Event.SourceEventArgs.FullPath   # Ruta completa del archivo
    $fileName = Split-Path -Path $Event.SourceEventArgs.FullPath -Leaf
    $fileSize = (Get-Item -Path $filePath).Length # Tamaño del archivo en bytes

    #*TIMESTAMP
    $timestamp = (Get-Date).ToString("yyyyMMdd-HHmmss")

    #*LOGICA DE DUPLICADOS
    $diccionario_arch = @{}

    #Obtengo el listado de archivos
    $res_archivos = Get-ChildItem -Recurse -File -Path $directorio

    foreach ($arch in $res_archivos){
        $clave = "$($arch.Name)|$($arch.Length)"
        
        if($diccionario_arch.ContainsKey($clave)){
            $diccionario_arch[$clave].Add($arch.Directory) > $null
        }else{
            $diccionario_arch[$clave] = [System.Collections.ArrayList]::new()
            $diccionario_arch[$clave].Add($arch.Directory) > $null
        }
    }

    $clavesAEliminar = [System.Collections.ArrayList]::new();

    foreach ($key in $diccionario_arch.Keys) {
        if ($diccionario_arch[$key].Count -lt 2) {
            $clavesAEliminar.Add($key) > $null
        }
    }

    foreach($key in $clavesAEliminar){
        $diccionario_arch.Remove($key)
    }

    if($diccionario_arch.ContainsKey($clave))
    {
        #*CREACION ZIP
    
        # Crear una carpeta para almacenar el archivo de log
        $logFolder = Join-Path -Path $PathLog -ChildPath "BackUpLog-$timestamp"
        if (-not (Test-Path $logFolder)) {
            New-Item -Path $logFolder -ItemType Directory | Out-Null
        }
    
        # Crear el archivo de log dentro de la carpeta
        $logFile = Join-Path -Path $logFolder -ChildPath "log-$timestamp.txt"
        "Duplicado: $fileName Peso: $fileSize Creacion:$filePath $((Get-Date).ToString("yyyy-MM-dd HH:mm:ss")) Monitoreado en: $directorio" | Out-File -FilePath $logFile -Encoding UTF8

        #Mover el archivo duplicado
        $newFilePath = Join-Path -Path $logFolder -ChildPath $fileName
        Move-Item -Path $filePath -Destination $newFilePath -Force
    
        # Crear el archivo ZIP de la carpeta
        $zipFile = Join-Path -Path $PathLog -ChildPath "$timestamp.zip"
        Compress-Archive -Path $logFolder -DestinationPath $zipFile
    
        # Eliminar la carpeta original después de comprimirla
        Remove-Item -Path $logFolder -Recurse -Force

    }


}

$leaf = Split-Path -Path $directorio -Leaf
$time = (Get-Date).ToString("yyyyMMdd-HHmmss")
$sourceIdentifier = "MonitorCreador|$leaf|$time"

Register-ObjectEvent -InputObject $watcher -EventName Created -SourceIdentifier $sourceIdentifier -Action $action -MessageData $messageData
    
$watcher.EnableRaisingEvents = $true

Start-Job -ScriptBlock {

    param($watcher, $sourceIdentifier)
        
    Wait-Event -SourceIdentifier $sourceIdentifier

} -ArgumentList $watcher, $sourceIdentifier


Get-EventSubscriber