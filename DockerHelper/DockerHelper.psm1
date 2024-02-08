function Build-DockerImage {
    <#
    .SYNOPSIS
    The cmdlet builds a Docker image from the $Dockerfile with a name $Tag on a remote host $ComputerName, where Docker is installed. 
    If $ComputerName is omitted cmdlet is executed locally.

    .DESCRIPTION
    This function build Docker image with specific tag, Dockerfile and context path, either locally or on remote server.
    If the ComputerName paramter is omitted, the function tries to build Docker image locally, otherwise it tries to build the image on the specified remote server

    .PARAMETER Dockerfile
    Dockerfile filename used for building the image.
        - if building on local machine, the path can be relative to working dir or absolute
        - if building on remote machine, the path should be absolute to the remote machine
    Example:
        c:\Temp\Dockerfile
        .\Dockerfile

    .PARAMETER Tag
    Tag to use for image naming and versioning
    Example:
        dockerimage:1.0.0
        dockr:2.345.5

    .PARAMETER Context
    Path where the prerequisite files for the Dockerfile are located
        - if building on local machine, the path can be relative to working dir or absolute
        - if building on remote machine, the path should be absolute to the remote machine 
    Example:
        c:\temp\
        .\Temp
        .

    .PARAMETER ComputerName
    This parameter takes either the computer DNS name or its IP address.

    .EXAMPLE
    Build-DockerImage -ComputerName 192.168.0.83 -tag dockr:1.1.1 -Dockerfile c:\Docker\Dockerfile -Context c:\temp\
    This example will try to build a docker image named "dockr" with version "1.1.1", on a remote server with IP address 192.168.0.83, where the Dockerfile is located in the c:\Docker directory, and will use c:\temp directory for any prerequisites needed for building the image

    .EXAMPLE
    Build-DockerImage -tag dockr:1.2.3 -Dockerfile .\Dockerfile -Context c:\temp\
    This example will try to build a docker image named "dockr"with version "1.2.3", on the local server, where the Dockerfile is located in the same directory where this command is run from, and will use c:\temp directory for any prerequisites needed for building the image

    #>


    param (
        [Parameter(Mandatory=$true)]
        [string]$Dockerfile,

        [Parameter(Mandatory=$true)]
        [string]$Tag,

        [Parameter(Mandatory=$true)]
        [string]$Context,

        [Parameter(Mandatory=$false)]
        [string]$ComputerName
    )

    $command = "docker build -t $Tag -f `"$Dockerfile`" $Context"


    if ($ComputerName) {
        Invoke-Command -ComputerName $ComputerName -ScriptBlock {
            param($command)
            Invoke-Expression $command
        } -ArgumentList $command -ErrorAction Stop
    }
    else {
        Invoke-Expression $command
    }

}



function Copy-Prerequisites {
    <#
    .SYNOPSIS
    A function designed for helping of copying files to remote docker server, used as prerequisites.

    .DESCRIPTION
    The function copies files and/or directories from $Path on a local machine to $ComputerName local $Destination directory (these files could be reqired by some Dockerfiles). 
    Assuming you have admin access to a remote host, and you are able to use admin shares C$, D$, etc.

    .PARAMETER ComputerName
    This parameter takes either the computer DNS name or its IP address.

    .PARAMETER Path
    Local path(s) to the file(s) to be copied over to the remote server.
    For multiple paths, each path must be devided by a comma.
    Examples:
        c:\Temp\files.txt
        c:\Temp\dir1, c:\temp\dir2
        c:\Dir\*
        .\Dir\ (relative to current working directory)

    .PARAMETER Destination
    Remote destination path where the files will be copied.
    It can take 2 formats:
        - c:\Temp\  (according to destination on the remote server)
        - C$\Temp\ (like standard SMB share call)

    .EXAMPLE
    Copy-Prerequisites -ComputerName 192.168.0.14 -Path .\Prerequisities\Fibonacci.ps1 -Destination c:\temp\
    This example shows how to call Get-Something with IP address, relative file path and destination formated as viewed by the remote server.

    .EXAMPLE
    Copy-Prerequisites -ComputerName Computer1.domain.com -Path C:\Files\Fibonacci.ps1 -Destination c$\temp\
    This example shows how to call Get-Something with computername, absolute file path and destination formated as SMB call.

    #>


    param (
        [Parameter(Mandatory=$true)]
        [string]$ComputerName,

        [Parameter(Mandatory=$true)]
        [string[]]$Path,

        [Parameter(Mandatory=$true)]
        [string]$Destination
    )

    foreach ($p in $Path) {
        $remotePath = "\\$ComputerName\$($Destination.Replace(':', '$'))"
        # Maybe we like to define confirm preference
        # $ConfirmPreference = 'Medium'
        Copy-Item -Path $p -Destination $remotePath -Recurse -Confirm -Force
    }
}



function Run-DockerContainer {
    <#
    .SYNOPSIS
    The cmdlet runs a Docker container from a $ImageName on a remote host $ComputerName, where Docker is installed. 
    If $ComputerName is omitted cmdlet is executed locally.

    .DESCRIPTION
    This function runs a Docker containert either locally or on remote server.
    If the $ComputerName parameter is omitted, the function tries to build Docker image locally, otherwise it tries to build the image on the specified remote server.
    The function will also output the container name.
    Beside optional $ComputerName parameter, the function accepts 2 more optional parameters:
    
    DockerParams - optional docker run parameters
    FibNumber - specify number to calculate its Fibonacci number


    .PARAMETER ImageName
    This parameter specifies the image used for the container
    Examples:
        dockr:1.2.3
        dockr

    .PARAMETER ComputerName
    This parameter takes either the computer DNS name or its IP address.

    .PARAMETER DockerParams
    This parameter specifies parameters for the docker run command. Used if we want to specify any runtime parameters like publishing ports, attaching volumes, specify container name, deleting container after finishing etc.
    Examples:
        -p 80:80
        -v c:\Dir:c:\temp\dir -p 80:80
        --rm

    .PARAMETER FibNumber
    This parameter accepts the number for which the container will calculate its Fibonacci representative.

    .EXAMPLE
    Run-DockerContainer -ImageName dockr:1.2.3
    This example will run a docker container from image dockr:1.2.3

    .EXAMPLE
    Run-DockerContainer -ImageName dockr:1.2.3 -DockerParams "-p 80:80" -FibNumber 5
    This example will run a docker container from image dockr:1.2.3, publish port 80 from container to port 80 on the host and calculate the Fibonacci number for $FibNumber parameter

    #>

    param (
        [Parameter(Mandatory=$true)]
        [string]$ImageName,

        [string]$ComputerName,

        [string[]]$DockerParams,

        [string]$FibNumber
    )

    if ($PSBoundParameters.ContainsKey('DockerParams') -and $PSBoundParameters.ContainsKey('ComputerName')) {

        # Execute remotely and use parameters
        Invoke-Command -ComputerName $ComputerName -ScriptBlock {
            param($DockerParams, $ImageName, $FibNumber)

            # Execute remotely with DockerParams parameter
            # First create the container, so we can get the container name
            $containerID = "docker create " + ($DockerParams -join ' ') + " $ImageName $FibNumber"
            $containerID = Invoke-Expression $containerID

            # Get the container name and output its name
            $containerName = "docker inspect --format '{{.Name}}' $containerID"
            $containerName = Invoke-Expression $containerName
            $containerName = $containerName.TrimStart('/')
            Write-Output "containername is $containerName"

            # Start the container
            $dockerStartCommand = "docker start -a $containerName"
            Invoke-Expression $dockerStartCommand
        } -ArgumentList $DockerParams, $ImageName, $FibNumber
    }
    elseif ($PSBoundParameters.ContainsKey('ComputerName')) {
        Invoke-Command -ComputerName $ComputerName -ScriptBlock {
            param($ImageName, $FibNumber)

            # Execute remotely without DockerParams parameter
            # First create the container, so we can get the container name
            $containerID = "docker create $ImageName $FibNumber"
            $containerID = Invoke-Expression $containerID

            # Get the container name and output its name
            $containerName = "docker inspect --format '{{.Name}}' $containerID"
            $containerName = Invoke-Expression $containerName
            $containerName = $containerName.TrimStart('/')
            Write-Output "containername is $containerName"
        
            # Start the container
            $dockerStartCommand = "docker start -a $containerName"
            Invoke-Expression $dockerStartCommand
        } -ArgumentList $ImageName, $FibNumber
    }
    elseif ($PSBoundParameters.ContainsKey('DockerParams')) {
        # Execute locally with DockerParams parameter
        # First create the container, so we can get the container name
        $containerID = "docker create " + ($DockerParams -join ' ') + " $ImageName $FibNumber"
        $containerID = Invoke-Expression $containerID

        # Get the container name and output its name
        $containerName = "docker inspect --format '{{.Name}}' $containerID"
        $containerName = Invoke-Expression $containerName
        $containerName = $containerName.TrimStart('/')
        Write-Output "containername is $containerName"
        
        # Start the container
        docker start -a $containerName
    }
    else {
        # Execute locally without DockerParams parameter
        # First create the container, so we can get the container name
        $containerID = docker create $ImageName $FibNumber

        # Get the container name
        $containerName = docker inspect --format '{{.Name}}' $containerID
        $containerName = $containerName.TrimStart('/')
        Write-Output "containername is $containerName"
        # Start the container
        docker start -a $containerName
    }

}