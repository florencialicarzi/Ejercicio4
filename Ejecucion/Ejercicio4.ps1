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
    #*PARAMETROS DEL CONTEXTO
    $PathLog = $event.MessageData.PathLog
    $directorio = $event.MessageData.Directorio

    #*PARAMETROS DEL EVENTO
    $filePath = $Event.SourceEventArgs.FullPath   # Ruta completa del archivo
    $fileName = $Event.SourceEventArgs.Name      # Nombre del archivo
    $fileSize = (Get-Item -Path $filePath).Length # Tamaño del archivo en bytes

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
        if ($diccionario_arch[$key].Count -lt 1) {
            $clavesAEliminar.Add($key) > $null
        }
    }

    foreach($key in $clavesAEliminar){
        $diccionario_arch.Remove($key)
    }

    #*VERIFICACION EVENTO-DUPLICADO
    # Obtener la fecha y hora actual en el formato deseado
    $timestamp = (Get-Date).ToString("yyyyMMdd-HHmmss")

    # Crear un archivo para imprimir el contenido del hashtable
    $hashTableLogFile = Join-Path -Path $PathLog -ChildPath "HashTable_$timestamp.txt"

    if ($dupHashTable.Count -eq 0) {
        # Si el hashtable está vacío
        "El hashtable de archivos duplicados está vacío." | Out-File -FilePath $hashTableLogFile -Encoding UTF8
    } else {
        # Si el hashtable tiene contenido
        "Contenido del hashtable de archivos duplicados:" | Out-File -FilePath $hashTableLogFile -Encoding UTF8
        foreach ($key in $dupHashTable.Keys) {
            $values = $dupHashTable[$key] -join ", "
            "Clave: $key - Valores: $values" | Out-File -FilePath $hashTableLogFile -Encoding UTF8 -Append
        }
    }


    $clave = "$fileName|$fileSize"
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
    
        # Crear el archivo ZIP de la carpeta
        $zipFile = Join-Path -Path $PathLog -ChildPath "$timestamp.zip"
        Compress-Archive -Path $logFolder -DestinationPath $zipFile
    
        # Eliminar la carpeta original después de comprimirla
        Remove-Item -Path $logFolder -Recurse -Force

    }


}

Register-ObjectEvent -InputObject $watcher -EventName Created -SourceIdentifier monitorCreador -Action $action -MessageData $messageData
    
$watcher.EnableRaisingEvents = $true

Start-Job -ScriptBlock {

    param($watcher)
        
    Wait-Event -SourceIdentifier monitorCreador 

} -ArgumentList $watcher


Get-EventSubscriber