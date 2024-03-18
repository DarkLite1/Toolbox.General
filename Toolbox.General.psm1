#Requires -Version 5.1
using namespace System.Management.Automation

Function Copy-ObjectHC {
    <#
    .SYNOPSIS
        Make a deep copy of an object.

    .DESCRIPTION
        Use the serializer to create an independent copy of an object,
        useful when using an object as a template

    .PARAMETER Name
        The object to copy.

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
        [Parameter(Mandatory)]
        [Object]$Name
    )

    [PSSerializer]::Deserialize(
        [PSSerializer]::Serialize(
            $Name
        )
    )
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
Function Get-ComputerAudioVolumeHC {
    <#
    .SYNOPSIS
        Get the volume of the speakers on a computer.

    .DESCRIPTION
        Get the audio volume on a computer.

    .PARAMETER ComputerName
        Name of the computer where to get the volume from.

    .EXAMPLE
        Get-ComputerAudioVolumeHC -ComputerName PC1

        Get the audio volume on PC1
    #>

    Param (
        [Parameter(Mandatory)]
        [String[]]$ComputerName
    )

    Invoke-Command -ComputerName $ComputerName -ScriptBlock {
        Add-Type -Language CSharpVersion3 -TypeDefinition @'
    using System.Runtime.InteropServices;
    [Guid("5CDF2C82-841E-4546-9722-0CF74078229A"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IAudioEndpointVolume
    {
        // f(), g(), ... are unused COM method slots. Define these if you care
        int f(); int g(); int h(); int i();
        int SetMasterVolumeLevelScalar(float fLevel, System.Guid pguidEventContext);
        int j();
        int GetMasterVolumeLevelScalar(out float pfLevel);
        int k(); int l(); int m(); int n();
        int SetMute([MarshalAs(UnmanagedType.Bool)] bool bMute, System.Guid pguidEventContext);
        int GetMute(out bool pbMute);
    }
    [Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IMMDevice
    {
        int Activate(ref System.Guid id, int clsCtx, int activationParams, out IAudioEndpointVolume aev);
    }
    [Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IMMDeviceEnumerator
    {
        int f(); // Unused
        int GetDefaultAudioEndpoint(int dataFlow, int role, out IMMDevice endpoint);
    }
    [ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")] class MMDeviceEnumeratorComObject { }
    public class Audio
    {
        static IAudioEndpointVolume Vol()
        {
            var enumerator = new MMDeviceEnumeratorComObject() as IMMDeviceEnumerator;
            IMMDevice dev = null;
            Marshal.ThrowExceptionForHR(enumerator.GetDefaultAudioEndpoint(/*eRender*/ 0, /*eMultimedia*/ 1, out dev));
            IAudioEndpointVolume epv = null;
            var epvid = typeof(IAudioEndpointVolume).GUID;
            Marshal.ThrowExceptionForHR(dev.Activate(ref epvid, /*CLSCTX_ALL*/ 23, 0, out epv));
            return epv;
        }
        public static float Volume
        {
            get { float v = -1; Marshal.ThrowExceptionForHR(Vol().GetMasterVolumeLevelScalar(out v)); return v; }
            set { Marshal.ThrowExceptionForHR(Vol().SetMasterVolumeLevelScalar(value, System.Guid.Empty)); }
        }
        public static bool Mute
        {
            get { bool mute; Marshal.ThrowExceptionForHR(Vol().GetMute(out mute)); return mute; }
            set { Marshal.ThrowExceptionForHR(Vol().SetMute(value, System.Guid.Empty)); }
        }
    }
'@

        [PSCustomObject]@{
            Muted  = [audio]::Mute
            Volume = [int]([audio]::Volume * 100)
        }
    } |
    Select-Object @{Name = 'ComputerName'; Expression = { $_.PSComputerName } },
    Muted, Volume
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
                Expression = { $_.DefaultValue.Extent.Text }
            }
        }

        $defaultValueParameters = $ast.FindAll( {
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
        Select-Object @selectParams

        $result = @{ }

        foreach ($d in $defaultValueParameters) {
            $result[$d.Name] = foreach ($value in $d.Value) {
                $ExecutionContext.InvokeCommand.InvokeScript($value, $true)
            }
        }
        $result
    }
    catch {
        throw "Failed retrieving the default parameter values: $_"
    }
}
Function Get-TimeServerHC {
    <#
    .SYNOPSIS
        Get the time server used on a specific computer

    .DESCRIPTION
        Get the time server used on a specific computer.
        The default is current computer.

    .EXAMPLE
        Get-TimeServerHC
        Get the time server on the current computer

    .EXAMPLE
        Get-TimeServerHC -ComputerName 'PC1', 'PC2'
        Get the time servers for PC1 and PC2
    #>
    [CmdletBinding()]
    Param (
        [String[]]$ComputerName = $env:COMPUTERNAME
    )

    process {
        $HKLM = 2147483650

        foreach ($Computer in $ComputerName) {
            try {
                $Output = [PSCustomObject]@{
                    ComputerName = $Computer
                    TimeServer   = $null
                    Type         = $null
                    Description  = $null
                }
                $reg = [wmiClass]"\\$Computer\root\default:StdRegprov"
                $key = 'SYSTEM\CurrentControlSet\Services\W32Time\Parameters'

                $type = $reg.GetStringValue($HKLM, $key, 'Type')
                $Output.Type = $Type.sValue

                if ($Output.Type -eq 'NTP') {
                    $Output.Description = 'Get time from configured NTP source'
                    $server = $reg.GetStringValue($HKLM, $key, 'NtpServer')
                    $Output.TimeServer = ($server.sValue -split ',')[0]
                }
                else {
                    $Output.Description = 'Get time from the domain hierarchy'
                    $Output.TimeServer = w32tm /query /source
                }

                $Output
            }
            catch {
                Write-Error "Failed to get NTP server from computer '$Computer': $_"
            }
        }
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
Function New-PSCodeHC {
    <#
    .SYNOPSIS
        Generate a unique PSCode.

    .DESCRIPTION
        Generate a unique PSCode starting by the country code, followed by the date and a random number.

    .PARAMETER CountryCode
        The string used to identify a specific country or group of countries.
        Example: BNL = BEL, FRA, LUX and NLD

    .EXAMPLE
        New-PSCodeHC -CountryCode DEU
        DEUPSCODE150729094858889906
    #>

    [CmdletBinding()]
    Param (
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [String]$CountryCode
    )

    $PSCode = $CountryCode + 'PSCODE' + (Get-Date -Format 'yyMMddHHmmssfff') + (Get-Random -Minimum 100 -Maximum 999)

    Write-Verbose "New PSCode '$PSCode'"
    $PSCode
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
            if (
                ($($Name.Item($h)) -eq $null) -or
                ($($Name.Item($h)) -eq '') -or
                ($($Name.Item($h)) -is [DBNull])
            ) {
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
Function Set-ComputerAudioVolumeHC {
    <#
    .SYNOPSIS
        Control the volume of the speakers on a computer.

    .DESCRIPTION
        Set the audio volume, mute or un-mute speakers, have the computer
        say something.

    .PARAMETER ComputerName
        Name of the computer where to set the volume

    .PARAMETER Volume
        The audio volume in percentage (0 is off and 50 is half way)

    .PARAMETER TextToSay
        Text that will be announced on the computer. This can be convenient
        to test if the volume reached the desired setting.

    .PARAMETER Mute
        When this switch is used the audio volume is muted and you can't hear
        anything on the system, despite the volume level being set.

    .EXAMPLE
        Set-ComputerAudioVolumeHC -ComputerName PC1 -Volume 20 -TextToSay 'hi there'

        Set the audio volume to 20% on PC1 and say the text 'hi there'.

    .EXAMPLE
        Set-ComputerAudioVolumeHC -ComputerName PC1 -Volume 70 -Mute

        Set the audio volume to 70% on PC1 and mute the audio. All sound will be
        blocked completely.
    #>

    Param (
        [Parameter(Mandatory)]
        [String[]]$ComputerName,
        [Parameter(Mandatory)]
        [ValidateRange(0, 100)]
        [Int]$Volume,
        [String]$TextToSay,
        [Switch]$Mute
    )

    Invoke-Command -ComputerName $ComputerName -ScriptBlock {
        Add-Type -Language CSharpVersion3 -TypeDefinition @'
    using System.Runtime.InteropServices;
    [Guid("5CDF2C82-841E-4546-9722-0CF74078229A"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IAudioEndpointVolume
    {
        // f(), g(), ... are unused COM method slots. Define these if you care
        int f(); int g(); int h(); int i();
        int SetMasterVolumeLevelScalar(float fLevel, System.Guid pguidEventContext);
        int j();
        int GetMasterVolumeLevelScalar(out float pfLevel);
        int k(); int l(); int m(); int n();
        int SetMute([MarshalAs(UnmanagedType.Bool)] bool bMute, System.Guid pguidEventContext);
        int GetMute(out bool pbMute);
    }
    [Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IMMDevice
    {
        int Activate(ref System.Guid id, int clsCtx, int activationParams, out IAudioEndpointVolume aev);
    }
    [Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IMMDeviceEnumerator
    {
        int f(); // Unused
        int GetDefaultAudioEndpoint(int dataFlow, int role, out IMMDevice endpoint);
    }
    [ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")] class MMDeviceEnumeratorComObject { }
    public class Audio
    {
        static IAudioEndpointVolume Vol()
        {
            var enumerator = new MMDeviceEnumeratorComObject() as IMMDeviceEnumerator;
            IMMDevice dev = null;
            Marshal.ThrowExceptionForHR(enumerator.GetDefaultAudioEndpoint(/*eRender*/ 0, /*eMultimedia*/ 1, out dev));
            IAudioEndpointVolume epv = null;
            var epvid = typeof(IAudioEndpointVolume).GUID;
            Marshal.ThrowExceptionForHR(dev.Activate(ref epvid, /*CLSCTX_ALL*/ 23, 0, out epv));
            return epv;
        }
        public static float Volume
        {
            get { float v = -1; Marshal.ThrowExceptionForHR(Vol().GetMasterVolumeLevelScalar(out v)); return v; }
            set { Marshal.ThrowExceptionForHR(Vol().SetMasterVolumeLevelScalar(value, System.Guid.Empty)); }
        }
        public static bool Mute
        {
            get { bool mute; Marshal.ThrowExceptionForHR(Vol().GetMute(out mute)); return mute; }
            set { Marshal.ThrowExceptionForHR(Vol().SetMute(value, System.Guid.Empty)); }
        }
    }
'@

        [audio]::Mute = $using:Mute
        [audio]::Volume = $using:Volume / 100

        if ($using:TextToSay) {
            Add-Type -AssemblyName System.Speech
            $speak = New-Object System.Speech.Synthesis.SpeechSynthesizer
            $speak.Speak($using:TextToSay)
        }
    }
}
Function Show-MenuHC {
    <#
    .SYNOPSIS
        Show a selection menu in the console

    .DESCRIPTION
        Allow the user to select an option in the console and return the
        selected value afterwards. When the parameter `-QuitSelector` is used
        the user is also able to select nothing and just leave the menu with no
        return value.

    .PARAMETER Items
        The options to display in the selection menu. Can be any type like
        string, hashtable, PSCustomObjects, ... .

    .PARAMETER Properties


    .EXAMPLE
        Show-MenuHC -Items @('a', 'b', 'c') -QuitSelector @{ 'E' = 'Exit' }

        1) a
        2) b
        3) c
        E) Exit
        Select an option:

        Displays the menu with an option to select nothing by pressing `q`

    .EXAMPLE
        $fruits = @(
            [PSCustomObject]@{ Name='banana'; Color='yellow'; Shape='long' }
            [PSCustomObject]@{ Name='kiwi'; Color='green'; Shape='oval' }
            [PSCustomObject]@{ Name='apples'; Color='red'; Shape='round' }
        )

        $params = @{
            Items           = $fruits
            QuitSelector    = $null
            SelectionPrompt = 'Select a fruit you like:'
        }
        $myFavoriteFruit = Show-MenuHC @params

        1) @{Name=banana; Color=yellow; Shape=long}
        2) @{Name=kiwi; Color=green; Shape=oval}
        3) @{Name=apples; Color=red; Shape=round}
        'Select a fruit you like:'

        Displays the menu where the user is forced to select one of the 3
        options. When selected the result is stored in the variable
        '$myFavoriteFruit'

    .EXAMPLE
        $fruits = @(
            @{ Name='banana'; Color='yellow'; Shape='long' }
            @{ Name='kiwi'; Color='green'; Shape='oval' }
            @{ Name='apples'; Color='red'; Shape='round' }
        )

        Show-MenuHC -Items $fruits -Properties Name

        1) @{Name=banana}
        2) @{Name=kiwi}
        3) @{Name=apples}
        Q) Quit
        'Select an option:'

        Displays the menu with only the 'Name' property and not al other
        properties of the object. It will still return the complete
        object on selection.
    #>

    [CmdLetBinding()]
    Param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [Array]$Items,
        [String[]]$Properties,
        [HashTable]$QuitSelector = @{ 'Q' = 'Quit' },
        [String]$DisplayTemplate = '{0}) {1}',
        [String]$SelectionPrompt = 'Select an option:'
    )
    Begin {
        $counter = 0
        $hash = [Ordered]@{}

        #region Get the quit selector key if there is one
        $quitSelectorKey = $null

        if ($QuitSelector) {
            if ($QuitSelector.Keys[0] -match '^[0-9]+$') {
                throw 'The quit selector cannot be a number'
            }
            if ($QuitSelector.Count -ne 1) {
                throw 'The quit selector can hold only one key value pair'
            }

            $quitSelectorKey = $quitSelector.GetEnumerator() |
            Select-Object -ExpandProperty Key

            if ($quitSelectorKey -isNot [String]) {
                throw 'The quit selector key needs to be of type string'
            }
        }
        #endregion
    }
    Process {
        #region Build hash table with selector and value
        foreach ($item in $items) {
            $counter++
            $hash["$counter"] = $item
        }
        #endregion
    }
    End {
        #region Display the menu
        do {
            foreach ($item in $hash.getEnumerator()) {
                $valueToDisplay = $item.Value

                if (
                    ($item.Value -is [HashTable]) -or
                    ($item.Value -is [System.Collections.Specialized.OrderedDictionary])
                ) {
                    $valueToDisplay = [PSCustomObject]$item.Value
                }

                if (($valueToDisplay -is [String]) -and ($Properties)) {
                    $Properties = $null
                    Write-Warning 'Property selection not supported for strings'
                }

                if ($Properties) {
                    $valueToDisplay = $valueToDisplay |
                    Select-Object -Property $Properties
                }

                $params = @{
                    Object          = $DisplayTemplate -f
                    $item.key, "$($valueToDisplay)"
                    ForegroundColor = 'yellow'
                }
                Write-Host @params
            }

            if ($QuitSelector) {
                $params = @{
                    Object          = $DisplayTemplate -f
                    $quitSelectorKey, "$($QuitSelector.Values[0])"
                    ForegroundColor = 'DarkGray'
                }
                Write-Host @params
            }

            $selected = Read-Host -Prompt $SelectionPrompt
        } until (
            ($hash.Keys -contains $selected) -or
            ($selected -eq $quitSelectorKey)
        )
        #endregion

        #region Return the selected value
        if ($selected -ne $quitSelectorKey) {
            $returnValue = $hash[$selected]
            Write-Verbose "Selected: $selected) $returnValue"
            $returnValue
        }
        #endregion
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
            Check if a user is member of the local group 'Administrators' and
            return true if he is and false if not.

        .EXAMPLE
            Test-IsAdminHC -SamAccountName bob
            Returns true in case bob is admin on this machine

        .EXAMPLE
            Test-IsAdminHC
            Returns true if the current user is admin on this machine
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