Filter Remove-CommentsHC {
    <#
        .SYNOPSIS
            Filters out comments and full whitespace strings

        .DESCRIPTION
            Filters out comments and full whitespace strings from arrays. In case a string
            starts with '#', ' #' or '     #' it is considered to be a comment and the string
            will not be returned.

            In case a string is completely blank '    ', it will also not be returned.

        .EXAMPLE
            $ImportFile = $env:TEMP + '\test.txt'

@"
MailTo: bob@contoso.com

# Other stuff

  # Other stuff
 # Other stuff
    # Other stuff
# Other stuff
        # Other stuff
        No # comment
GITOU: OU=GIT,DC=contoso,DC=net
QuotaGroupName: BEL ATT Quota home
NoOCSGroupName: BEL ATT User No OCS
InactiveDays: 40
# OU=BEL,OU=EU,DC=contoso,DC=net
OU=BEL,OU=EU,DC=contoso,DC=net



   ###
   # #
   # d#
   #
   My stuff # that is ok
# Comment
"@ | Out-File $ImportFile


Get-Content $ImportFile

            The result will be:
            MailTo: bob@contoso.com
            No # comment
            GITOU: OU=GIT,DC=contoso,DC=net
            QuotaGroupName: BEL ATT Quota home
            NoOCSGroupName: BEL ATT User No OCS
            InactiveDays: 40
            OU=BEL,OU=EU,DC=contoso,DC=net
            My stuff # that is ok
#>

    if ($_ -notMatch '^\s*#|^\s*$') {
        $_.Trim()
    }
}

Function Add-FunctionHC {
    <#
    .SYNOPSIS
        Load the module of a function when it's not loaded yet.

    .DESCRIPTION
        Load the module of a function, only when it's not loaded yet. This can 
        be useful when a function needs to be known in the local session before 
        it can be used in a remote session by 'Invoke-Command'.

    .EXAMPLE
        Add-FunctionHC -Name 'Copy-FilesHC'

        Loads the module 'Toolbox.General' where the function 'Copy-FilesHC' is 
        available in. It does this only when the module has not been loaded yet.
#>

    [CmdletBinding()]
    Param(
        [String]$Name
    )
    Process {
        Try {
            $Module = (Get-Command $Name -EA Stop).ModuleName
        }
        Catch {
            Write-Error "Add-FunctionHC: Function '$Name' doesn't exist in any module"
            $Global:Error.RemoveAt('1')
            Break
        }

        if (-not (Get-Module -Name $Module)) {
            Import-Module -Name $Module
        }
    }
}

Function ConvertTo-ArrayHC {
    <#
    .SYNOPSIS
        Convert different types of collections (valueCollection, collection`1, 
        ...) to an array.

    .DESCRIPTION
        This function is convenient for Pester testing.
s#>

    Begin {
        $output = @();
    }
    Process {
        $output += $_;
    }
    End {
        return , $output;
    }
}

Function Copy-ObjectHC {
    <#
    .SYNOPSIS
        Make a deep copy of an object.

    .DESCRIPTION
        In PowerShell, when you copy an object (array, hashtable, ..), there's 
        always a link with the original. So if you change a property in the new 
        object it will also be changed in the original one. To avoid this from 
        happening, a deep copy with .NET is required.

    .PARAMETER Name
        Name of the object we need to copy.

    .EXAMPLE
        The $NewArray object contains a full copy of the $OriginalArray
        $NewArray = Copy-ObjectHC -Original $OriginalArray

    .EXAMPLE
        Make a deep copy of a hashtable

        $OriginalHash = @{
            'SrvBatch' = 'FullControl'
        }

        $NewHash = Copy-ObjectHC $OriginalHash
        $NewHash.Add('bob', 'FullControl')
        Write-Host 'New hash:' -ForegroundColor Yellow
        $NewHash

        Write-Host 'Original hash:' -ForegroundColor Yellow
        $OriginalHash
#>

    [CmdletBinding()]
    Param (
        [parameter(Mandatory)]
        [Object]$Name
    )

    Process {
        # Serialize and Deserialize data using BinaryFormatter
        $ms = New-Object System.IO.MemoryStream
        $bf = New-Object System.Runtime.Serialization.Formatters.Binary.BinaryFormatter
        $bf.Serialize($ms, $Name)
        $ms.Position = 0

        #Deep copied data
        $bf.Deserialize($ms)
        $ms.Close()
    }
}

Function Format-JsonHC {
    <#
    .SYNOPSIS
        Format a .json file to look prettier
    #>

    Param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [String]$json
    )

    $indent = 0;
    ($json -Split '\n' |
        ForEach-Object {
            if ($_ -match '[\}\]]') {
                # This line contains  ] or }, decrement the indentation level
                $indent--
            }
            $line = (' ' * $indent * 2) + $_.TrimStart().Replace(':  ', ': ')
            if ($_ -match '[\{\[]') {
                # This line contains [ or {, increment the indentation level
                $indent++
            }
            $line
        }) -Join "`n"
}

Function Merge-ObjectsHC {
    <#
    .SYNOPSIS
        Combine two objects into one.
 
    .DESCRIPTION
        Combine two objects into one. These can be custom PowerShell objects or 
        other system objects
 
    .EXAMPLE
        Combine objects allow you to combine two separate custom objects into one.
 
        $Object1 = [PsCustomObject]@{firstName = 'Bob'; lastName = 'Lee Swagger'}
        $Object2 = [PsCustomObject]@{hobby = 'Shooting'; rank = 'Sergeant'}
    
        Combine-Object -Object1 $Object1 -Object2 $Object2
    
        Name          Value                                                                                     
        ----          ----                                                                    
        fistName      Bob
        lastName      Lee Swagger
        hobby         Shooting
        rank          Sergeant
	
    .EXAMPLE
        Combining system objects
 
        $User = Get-ADUser -identity vanGulick
        $Bios = Get-wmiObject -class win32_bios
    
        Combine-Objects -Object1 $bios -Object2 $User
 #>
 
    Param (
        [Parameter(Mandatory)]$Object1, 
        [Parameter(Mandatory)]$Object2
    )
    
    $hash = [Ordered]@{ }
 
    foreach ( $Property in $Object1.psObject.Properties) {
        $hash[$Property.Name] = $Property.value
    }
 
    foreach ( $Property in $Object2.psObject.Properties) {
        $hash[$Property.Name] = $Property.value
    }
    
    [psCustomObject]$hash
}

Function ConvertFrom-RobocopyExitCodeHC {
    <#
    .SYNOPSIS
        Convert exit codes of Robocopy.exe.

    .DESCRIPTION
        Convert exit codes of Robocopy.exe to readable formats.

    .EXAMPLE
        Robocopy.exe $Source $Target $RobocopySwitches
        ConvertFrom-RobocopyExitCodeHC -ExitCode $LASTEXITCODE
        'COPY'

    .NOTES
        $LASTEXITCODE of Robocopy.exe

        Hex Bit Value Decimal Value Meaning If Set
        0×10 16 Serious error. Robocopy did not copy any files. This is either 
             a usage error or an error due to insufficient access privileges on 
             the source or destination directories.
        0×08 8 Some files or directories could not be copied (copy errors   
             occurred and the retry limit was exceeded). Check these errors 
             further.
        0×04 4 Some Mismatched files or directories were detected. Examine the 
             output log. Housekeeping is probably necessary.
        0×02 2 Some Extra files or directories were detected. Examine the 
             output log. Some housekeeping may be needed.
        0×01 1 One or more files were copied successfully (that is, new files 
             have arrived).
        0×00 0 No errors occurred, and no copying was done. The source and 
             destination directory trees are completely synchronized.

        (https://support.microsoft.com/en-us/kb/954404?wa=wsignin1.0)

        0	No files were copied. No failure was encountered. No files were 
            mismatched. The files already exist in the destination directory; 
            therefore, the copy operation was skipped.
        1	All files were copied successfully.
        2	There are some additional files in the destination directory that 
            are not present in the source directory. No files were copied.
        3	Some files were copied. Additional files were present. No failure 
            was encountered.
        5	Some files were copied. Some files were mismatched. No failure was 
            encountered.
        6	Additional files and mismatched files exist. No files were copied 
            and no failures were encountered. This means that the files already 
            exist in the destination directory.
        7	Files were copied, a file mismatch was present, and additional  
            files were present.
        8	Several files did not copy.
        
        * Note Any value greater than 8 indicates that there was at least one 
        failure during the copy operation.
        #>

    Param (
        [int]$ExitCode
    )

    Process {
        Switch ($ExitCode) {
            0 { $Message = 'NO CHANGE'; break }
            1 { $Message = 'COPY'; break }
            2 { $Message = 'EXTRA'; break }
            3 { $Message = 'EXTRA + COPY'; break }
            4 { $Message = 'MISMATCH'; break }
            5 { $Message = 'MISMATCH + COPY'; break }
            6 { $Message = 'MISMATCH + EXTRA'; break }
            7 { $Message = 'MISMATCH + EXTRA + COPY'; break }
            8 { $Message = 'FAIL'; break }
            9 { $Message = 'FAIL + COPY'; break }
            10 { $Message = 'FAIL + EXTRA'; break }
            11 { $Message = 'FAIL + EXTRA + COPY'; break }
            12 { $Message = 'FAIL + MISMATCH'; break }
            13 { $Message = 'FAIL + MISMATCH + COPY'; break }
            14 { $Message = 'FAIL + MISMATCH + EXTRA'; break }
            15 { $Message = 'FAIL + MISMATCH + EXTRA + COPY'; break }
            16 { $Message = 'FATAL ERROR'; break }
            default { 'UNKNOWN' }
        }
        return $Message
    }
}

Function ConvertFrom-RobocopyLogHC {
    <#
        .SYNOPSIS
            Create a PSCustomObject from a Robocopy log file.

        .DESCRIPTION
            Parses Robocopy logs into a collection of objects summarizing each 
            Robocopy operation.

        .EXAMPLE
            ConvertFrom-RobocopyLogHC 'C:\robocopy.log'
            Source      : \\contoso.net\folder1\
            Destination : \\contoso.net\folder2\
            Dirs        : @{
                Total=2; Copied=0; Skipped=2; 
                Mismatch=0; FAILED=0; Extras=0
            }
            Files       : @{
                Total=203; Copied=0; Skipped=203; 
                Mismatch=0; FAILED=0; Extras=0
            }
            Times       : @{
                Total=0:00:00; Copied=0:00:00; 
                FAILED=0:00:00; Extras=0:00:00
            }
#>

    Param (
        [Parameter(Mandatory, ValueFromPipelineByPropertyName, Position = 0)]
        [ValidateScript( { Test-Path $_ -PathType Leaf })]
        [String]$LogFile
    )

    Process {
        $Header = Get-Content $LogFile | Select-Object -First 12
        $Footer = Get-Content $LogFile | Select-Object -Last 9

        $Header | ForEach-Object {
            if ($_ -like "*Source :*") {
                $Source = (($_.Split(':', 2))[1]).trim()
            }
            if ($_ -like "*Dest :*") {
                $Destination = (($_.Split(':', 2))[1]).trim()
            }
            # in case of robo error log
            if ($_ -like "*Source -*") {
                $Source = (($_.Split('-', 2))[1]).trim()
            }
            if ($_ -like "*Dest -*") {
                $Destination = (($_.Split('-', 2))[1]).trim()
            }
        }

        $Footer | ForEach-Object {
            if ($_ -like "*Dirs :*") {
                $Array = (($_.Split(':')[1]).trim()) -split '\s+'
                $Dirs = [PSCustomObject][Ordered]@{
                    Total    = $Array[0]
                    Copied   = $Array[1]
                    Skipped  = $Array[2]
                    Mismatch = $Array[3]
                    FAILED   = $Array[4]
                    Extras   = $Array[5]
                }
            }
            if ($_ -like "*Files :*") {
                $Array = ($_.Split(':')[1]).trim() -split '\s+'
                $Files = [PSCustomObject][Ordered]@{
                    Total    = $Array[0]
                    Copied   = $Array[1]
                    Skipped  = $Array[2]
                    Mismatch = $Array[3]
                    FAILED   = $Array[4]
                    Extras   = $Array[5]
                }
            }
            if ($_ -like "*Times :*") {
                $Array = ($_.Split(':', 2)[1]).trim() -split '\s+'
                $Times = [PSCustomObject][Ordered]@{
                    Total  = $Array[0]
                    Copied = $Array[1]
                    FAILED = $Array[2]
                    Extras = $Array[3]
                }
            }
        }

        $Obj = [PSCustomObject][Ordered]@{
            'Source'      = $Source
            'Destination' = $Destination
            'Dirs'        = $Dirs
            'Files'       = $Files
            'Times'       = $Times
        }
        Write-Output $Obj
    }
}

Function Get-DiskSpaceInfoHC {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $True, ValueFromPipeline = $True)]
        [String[]]$ComputerName
    )
    PROCESS {
        foreach ($computer in $computername) {
            try {
                $params = @{'ComputerName' = $computer
                    'Filter'               = "DriveType=3"
                    'Class'                = 'Win32_LogicalDisk'
                    'ErrorAction'          = 'Stop'
                }
                $ok = $True
                $disks = Get-WmiObject @params
            }
            catch {
                Write-Warning "Error connecting to $computer"
                $ok = $False
            }

            if ($ok) {
                foreach ($disk in $disks) {
                    $obj = [PSCustomObject][Ordered]@{
                        'ComputerName' = $computer
                        'DeviceID'     = $disk.deviceid
                        'FreeSpace'    = $disk.freespace
                        'Size'         = $disk.size
                        'Collected'    = (Get-Date)
                    }
                    $obj.PSObject.TypeNames.Insert(0, 'Report.DiskSpaceInfo')
                    $obj
                }
            }
        }
    }
}

Function Get-DefaultParameterValuesHC {
    <#
.SYNOPSIS
    Get the default values for parameters set in a script or function.

.DESCRIPTION
    A hash table is returned containing the name and the default value of the 
    parameters used in a script or function. When a parameter is mandatory but
    still has a default value this value will not be returned.

.PARAMETER Path
    Function name or path to the script file

.EXAMPLE
    Function Test-Function {
        Param (
            [Parameter(Mandatory)]
            [String]$PrinterName,
            [Parameter(Mandatory)]
            [String]$PrinterColor,
            [String]$ScriptName = 'Get printers',
            [String]$PaperSize = 'A4'
        )
    }
    Get-DefaultParameterValuesHC -Path 'Test-Function'

    Get the default values for parameters that are not mandatory.
    @{
        ScriptName = 'Get printers'
        PaperSize = 'A4'
    }
#>

    [CmdletBinding()]
    [OutputType([hashtable])]
    Param (
        [Parameter(Mandatory)]
        [String]$Path
    )
    try {
        $ast = (Get-Command $Path).ScriptBlock.Ast

        $selectParams = @{
            Property = @{ 
                Name       = 'Name'; 
                Expression = { $_.Name.VariablePath.UserPath } 
            },
            @{ 
                Name       = 'Value'; 
                Expression = { 
                    if ($_.DefaultValue.StaticType.IsArray) {
                        $_.DefaultValue.SubExpression.Statements.PipelineElements.Expression.Elements.Extent.Text
                    }
                    else {
                        if ($_.DefaultValue.Value) { $_.DefaultValue.Value }
                        else { $_.DefaultValue.Extent.Text }
                    }
                }
            }
        }
    
        $result = @{ }

        $defaultValueParameters = @($ast.FindAll( {
                    $args[0] -is 
                    [System.Management.Automation.Language.ParameterAst] 
                } , $true) | 
            Where-Object { 
                ($_.DefaultValue) -and
                (-not ($_.Attributes | 
                        Where-Object { $_.TypeName.Name -eq 'Parameter' } | 
                        ForEach-Object -MemberName NamedArguments | 
                        Where-Object { $_.ArgumentName -eq 'Mandatory' }))
            } | 
            Select-Object @selectParams)
        
        foreach ($d in $defaultValueParameters) {
            $result[$d.Name] = foreach ($value in $d.Value) {
                $ExecutionContext.InvokeCommand.ExpandString($value) -replace 
                "^`"|`"$|'$|^'" 
            }
        }
        $result
    }
    catch {
        throw "Failed retrieving the default parameter values: $_"
    }
}

Function Install-RemoteAppHC {
    <#
    .SYNOPSIS
        Install software on a remote machine

    .DESCRIPTION
        Install software on a remote machine and copy the install files from 
        SCCM to the C:\Cabs folder
#>
    [CmdletBinding()]
    Param (
        [parameter(Mandatory)]
        [ValidateScript( { Test-Path $_ -PathType Leaf })]
        [String]$Software,
        [parameter(Mandatory)]
        [ValidateScript( { Test-Connection $_ -Quiet })]
        [String]$Computer
    )

    $TempFolder = "\\$Computer\c$\Cabs"

    if (!(Test-Path $TempFolder)) {
        New-Item -Path $TempFolder -ItemType Directory
    }
    Copy-Item -LiteralPath (Split-Path $Software -Parent) -Destination $TempFolder -Container -Recurse -Force
    $LocalPath = Join-Path ('C:\' + (Split-Path $TempFolder -Leaf)) (Join-Path (Split-Path $Software -Parent | Split-Path -Leaf) (Split-Path $Software -Leaf))
    Invoke-Command -ScriptBlock { cscript.exe $Using:LocalPath } -Computer $Computer
}

Function Remove-EmptyParamsHC {
    <#
    .SYNOPSIS
        Removes empty key/values pairs from a hashtable.

    .DESCRIPTION
        Removes empty key/values pairs from a hashtable. This can be useful for 
        functions that are used with splatting.

    .EXAMPLE
        Remove-EmptyParamsHC $CopyParams
        
        Removes all the pairs that are empty and corrects the original 
        hashtable to only contain key/value pairs where their are values 
        available.
#>

    Param(
        [HashTable]$Name
    )
    Begin {
        $list = New-Object System.Collections.ArrayList($null)
    }
    Process {
        foreach ($h in $Name.Keys) {
            if (($($Name.Item($h)) -eq $null) -or ($($Name.Item($h)) -eq '')) {
                $null = $list.Add($h)
            }
        }
        foreach ($h in $list) {
            $Name.Remove($h)
        }
    }
}

Function Remove-InvalidFileNameCharsHC {
    <#
    .SYNOPSIS
        Removes characters from a string that are not valid in Windows file 
        names.

    .DESCRIPTION
        Remove-InvalidFileNameCharsHC accepts a string and removes characters 
        that are invalid in Windows file names.

    .PARAMETER Name
        Specifies the file name to strip of invalid characters.

    .PARAMETER IncludeSpace
        The IncludeSpace parameter will include the space character (U+0032) in 
        the removal process.

    .EXAMPLE
        'Clôture Yess 06/2015 - afsluit Yess 06/2015 - Closure Yess 06/2015' | 
        Remove-InvalidFileNameCharsHC

        Clôture Yess 062015 - afsluit Yess 062015 - Closure Yess 062015
#>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [String]$Name,
        [switch]$IncludeSpace
    )
    Process {
        if ($IncludeSpace) {
            [RegEx]::Replace($Name, "[{0}]" -f ([RegEx]::Escape([String][System.IO.Path]::GetInvalidFileNameChars())), '')
        }
        else {
            [RegEx]::Replace($Name, "[{0}]" -f ([RegEx]::Escape( -join [System.IO.Path]::GetInvalidFileNameChars())), '')
        }
    }
}

Function Remove-PowerShellWildcardCharsHC {
    <#
    .SYNOPSIS
        Removes PowerShell wildcard characters from a string

    .DESCRIPTION
        Removes PowerShell wildcard characters from a string. This can be 
        useful when wildcards are not accepted by other CmdLets like 
        'Send-MailMessage -Attachment'.

    .PARAMETER Name
        Specifies the string where the wildcard characters will be removed from.

    .EXAMPLE
        'My file[0].txt' | Remove-PowerShellWildcardCharsHC
        Removes the brackets '[]' from the string to end up with 'My file0.txt'
#>

    [CmdletBinding()]
    Param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [String]$Name
    )

    Process {
        $Name = $Name -replace '\['
        $Name = $Name -replace '\]'
        $Name = $Name -replace '\*'
        $Name = $Name -replace '\?'
        $Name
    }
}

Function Test-ErrorHandlingInModuleHC {
    Try {
        throw 'My custom error'
    }
    Catch {
        $Global:Error.RemoveAt(0)
        throw "Failure reported: $_"

    }
    Finally {
        'do this always'
    }
}

Function Test-IsAdminHC {
    <#
        .SYNOPSIS
            Check if a user is local administrator.

        .DESCRIPTION
            Check if a user is member of the local group 'Administrators' and returns
            TRUE if he is, FALSE if not.

        .EXAMPLE
            Test-IsAdminHC -SamAccountName SrvBatch
            Returns TRUE in case SrvBatch is admin on this machine

        .EXAMPLE
            Test-IsAdminHC
            Returns TRUE if the current user is admin on this machine

        .NOTES
            CHANGELOG
            2017/05/29 Added parameter to check for a specific user
    #>

    Param (
        $SamAccountName = [Security.Principal.WindowsIdentity]::GetCurrent()
    )

    Try {
        $Identity = [Security.Principal.WindowsIdentity]$SamAccountName
        $Principal = New-Object Security.Principal.WindowsPrincipal -ArgumentList $Identity
        $Result = $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        Write-Verbose "Administrator permissions: $Result"
        $Result
    }
    Catch {
        throw "Failed to determine if the user '$SamAccountName' is local admin: $_"
    }
}

Function Test-ParameterInPositionAndMandatoryHC {
    <#
    .SYNOPSIS
        Test for parameters in a specific position that are mandatory.

    .DESCRIPTION
        Test for parameters in a specific position that are mandatory. When the
        parameter is not in that position, the name is incorrect or it's not
        mandatory, the incorrect parameter's name is generated as output. In 
        case all parameters are correct, no output is generated.

    .PARAMETER Collection
        The parameters from the script/function.

    .PARAMETER Requirement
        The desired position and parameter name.

    .EXAMPLE
        Check if parameter 'ScriptName' is in the first position and if 
        parameter 'Number' is in the second position. They also need to be 
        'Mandatory'.

        "Param (
            [Parameter(Mandatory)]
            [String]`$ScriptName,
            [Parameter(Mandatory = `$false)]
            [Int]`$Number
        )" | Out-File TestScript.ps1

        Test-ParameterInPositionAndMandatoryHC -Collection (
            (Get-Command ".\TestScript.ps1").Parameters
        ) -Requirement @{
            1 = 'ScriptName'
            2 = 'Number'
        }

    .EXAMPLE
        Will output 'Time' because it's not a mandatory parameter.

        Function Get-Foo {
            Param (
                [Parameter(Mandatory=$true)]
                [String]$Name,
                [Parameter(Mandatory=$false)]
                [String]$Time
            )

            'Foo'
        }

        Test-ParameterInPositionAndMandatoryHC -Collection (
            (Get-Command Get-Foo).Parameters
        ) -Requirement @{
            1 = 'Name'
            2 = 'Time'
        }
#>

    Param (
        [Parameter(Mandatory)]
        [Object]$Collection,
        [Parameter(Mandatory)]
        [HashTable]$Requirement
    )

    Process {
        $ParameterSet = $Collection.GetEnumerator() | ForEach-Object -Begin { $i = 0 } -Process {
            $i++
            [PSCustomObject]@{
                Position  = $i
                Name      = $_.Key
                Mandatory = $_.Value.Attributes.Mandatory
            }
        }

        foreach ($R in ($Requirement.GetEnumerator())) {
            $Ok = $ParameterSet | Where-Object {
                ($_.Position -eq $R.Key) -and
                ($_.Name -eq $R.Value) -and
                ($_.Mandatory) }

            if (-not $Ok) {
                Write-Verbose "Parameter '$($R.Value)' not found in position '$($R.Key)' or is not 'Mandatory'"
                $R.Value
            }
            else {
                Write-Verbose "Parameter '$($R.Value)' is mandatory and in the correct position"
            }
        }
    }
}

Function Use-CultureHC {
    <#
    .SYNOPSIS
        Run PowerShell code in another culture 

    .DESCRIPTION
        This function allows us to run PowerShell code in another culture 
        (regional settings).

    .PARAMETER Culture
        The culture ID you want to use: 
        en-US (English), de-DE (German), nl-BE (Belgium), ..

    .PARAMETER Code
        PowerShell code, like a script block, that you want to run using the 
        specified culture.

    .EXAMPLE
        Use-CultureHC en-US {Get-Date}
        Outputs the current date in US format.

    .EXAMPLE
        Use-CultureHC de-DE {Get-Date}
        Outputs the current date in German format.

    .EXAMPLE
        Use-CultureHC nl-BE {Get-TimeStamp}
        Outputs the current date and time in a Belgium format.

    .EXAMPLE
         [system.Globalization.CultureInfo]::GetCultures('AllCultures')
         This command will list all the supported cultures on the system.
#>

    Param (
        [Parameter(Mandatory)]
        [System.Globalization.CultureInfo]$Culture,
        [Parameter(Mandatory)]
        [ScriptBlock]$Code
    )

    Process {
        Trap {
            [System.Threading.Thread]::CurrentThread.CurrentCulture = $currentCulture
        }
        $currentCulture = [System.Threading.Thread]::CurrentThread.CurrentCulture
        [System.Threading.Thread]::CurrentThread.CurrentCulture = $culture
        Invoke-Command $code
        [System.Threading.Thread]::CurrentThread.CurrentCulture = $currentCulture
    }
}

Export-ModuleMember -Function * -Alias *