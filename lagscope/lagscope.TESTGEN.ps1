Param(
    [parameter(Mandatory=$false)] [switch] $Detail = $false,
    [parameter(Mandatory=$false)] [Int]    $Iterations = 1,
    [parameter(Mandatory=$true)]  [string] $DestIp,
    [parameter(Mandatory=$true)]  [string] $SrcIp,
    [parameter(Mandatory=$true)]  [ValidateScript({Test-Path $_ -PathType Container})] [String] $OutDir = "" 
)
$scriptName = $MyInvocation.MyCommand.Name 

function input_display {
    $g_path = Get-Location

    Write-Host "============================================"
    Write-Host "$g_path\$scriptName"
    Write-Host " Inputs:"
    Write-Host "  -Detail     = $Detail"
    Write-Host "  -Iterations = $Detail"
    Write-Host "  -DestIp     = $DestIp"
    Write-Host "  -SrcIp      = $SrcIp"
    Write-Host "  -OutDir     = $OutDir"
    Write-Host "============================================"
} # input_display()

#===============================================
# Internal Functions
#===============================================
function banner {
    [CmdletBinding()]
    Param(
        [parameter(Mandatory=$true)] [String] $Msg
    )

    Write-Host "==========================================================================="
    Write-Host "| $Msg"
    Write-Host "==========================================================================="
} # banner()

function test_recv {
    [CmdletBinding()]
    Param(
        [parameter(Mandatory=$true)]   [int]    $Port
    )
    [string] $cmd = "./lagscope -r -p$Port"
    Write-Output $cmd | Out-File -Encoding ascii -Append $g_log
    Write-Output $cmd | Out-File -Encoding ascii -Append $g_logRecv
    Write-Host   $cmd 
} # test_recv()

function test_send {
    [CmdletBinding()]
    Param(
        [parameter(Mandatory=$false)]  [string] $Iter,
        [parameter(Mandatory=$false)]  [int]    $Secs,
        [parameter(Mandatory=$true)]   [int]    $Port,
        [parameter(Mandatory=$false)]  [String] $Options,
        [parameter(Mandatory=$true)]   [String] $OutDir,
        [parameter(Mandatory=$true)]   [String] $Fname,
        [parameter(Mandatory=$false)]  [bool]   $NoDumpParam = $false
    )

    #[int] $msgbytes = 4  #lagscope default is 4B, no immediate need to specify.
    [int] $rangeus  = 10
    [int] $rangemax = 98

    [string] $out        = (Join-Path -Path $OutDir -ChildPath "$Fname")
    [string] $cmd = "./lagscope $Iter -s`"$g_DestIp`" -p$Port -V -H -c$rangemax -l$rangeus -P`"$out.per.json`" -R`"$out.data.csv`" > `"$out.txt`""
    Write-Output $cmd | Out-File -Encoding ascii -Append $g_log
    Write-Output $cmd | Out-File -Encoding ascii -Append $g_logSend
    Write-Host   $cmd 
} # test_send()

function test_lagscope_generate {
    [CmdletBinding()]
    Param(
        [parameter(Mandatory=$true)] [String] $OutDir
    )

    # Normalize output directory
    $dir = $OutDir

    # Iteration Tests capturing each transaction time
    # - Measures over input samples
    banner -Msg "Iteration Tests: [tcp] operations per bounded iterations"
    [int] $tmp  = 50001
    [int] $iter = 10000 
    for ($i=0; $i -lt $g_iters; $i++) {
        [int] $portstart = $tmp + ($i * $g_iters)

        test_send -Iter "-n$iter" -Port $portstart -OutDir $dir -Fname "tcp.i$iter.iter$i"
        test_recv -Port $portstart
    }

    # Transactions per 10s
    # - Measures operations per bounded time.
    banner -Msg "Time Tests: [tcp] operations per bounded time"
    [int] $tmp = 50001
    [int] $sec = 10
    for ($i=0; $i -lt $g_iters; $i++) {
        [int] $portstart = $tmp + ($i * $g_iters)
        
        # Default
        test_send -Iter "-t$sec" -Port $portstart -Options "" -OutDir $dir -Fname "tcp.t$sec.iter$i"
        test_recv -Port $portstart
        
    }
} # test_lagscope_generate()

#===============================================
# External Functions - Main Program
#===============================================
function test_main {
    Param(
        [parameter(Mandatory=$false)] [switch] $Detail = $false,
        [parameter(Mandatory=$false)] [Int]    $Iterations = 1,
        [parameter(Mandatory=$true)]  [string] $DestIp,
        [parameter(Mandatory=$true)]  [string] $SrcIp,
        [parameter(Mandatory=$true)]  [ValidateScript({Test-Path $_ -PathType Container})] [String] $OutDir = "" 
    )
    input_display
    
    [int]    $g_iters   = $Iterations
    [bool]   $g_detail  = $Detail
    [string] $g_DestIp  = $DestIp.Trim()
    [string] $g_SrcIp   = $SrcIp.Trim()
    [string] $dir       = (Join-Path -Path $OutDir -ChildPath "lagscope")  
    [string] $g_log     = "$dir\LAGSCOPE.Commands.txt"
    [string] $g_logSend = "$dir\LAGSCOPE.Commands.Send.txt"
    [string] $g_logRecv = "$dir\LAGSCOPE.Commands.Recv.txt" 

    New-Item -ItemType directory -Path $dir | Out-Null
    
    # Optional - Edit spaces in output path for Invoke-Expression compatibility
    # $dir  = $dir  -replace ' ','` '

    test_lagscope_generate -OutDir $dir
} test_main @PSBoundParameters # Entry Point