<#
.SYNOPSIS
  List PSM Sessions
.DESCRIPTION
  List the number of PSM sessions in a few minutes
.PARAMETER <Parameter_Name>
ServerList
numCycles
numMinutes
.INPUTS
  
.OUTPUTS
  Not log
.NOTES
  Version:        1.0
  Author:         Antonino Bambino
  Creation Date:  12/08/2023
  Purpose/Change: 
  
.EXAMPLE
  PSM-RDP-Session-Table -ServerList  C:\TMP\ServerList.csv
  
  Run with Cycles 
  PSM-RDP-Session-Table -ServerList C:\TMP\ServerList.csv -numCycles 3
  
  Run with Minutes
  PSM-RDP-Session-Table -ServerList C:\TMP\ServerList.csv -numMinutes 2

  Run with Cycles and Minutes
  PSM-RDP-Session-Table -ServerList C:\TMP\ServerList.csv -numCycles 5 -numMinutes 2
#>

Param ([Parameter(Mandatory)]$ServerList, [Int32][ValidateRange(1,13)]$numCycles = 7, [Int32][ValidateRange(1,5)]$numMinutes = 5)

Clear-Host

# Import list of servers
if (!$ServerList) { exit }
if ( -Not (Test-Path $ServerList) ) {
	Write-Host ''
	Write-Host ''
	Write-Host $ServerList 'not found...' -ForegroundColor Red
	Start-Sleep -Seconds 5
	Return
}

$ServerList = import-csv $ServerList

# Input credential
$credential = Get-Credential -Message "Credential are required for run the script"
if (!$credential) { exit }

# Number of servers in the list computername,role,description
$numservers = $ServerList.Count

# Initialize array
$Hostnames = $null
$Hostnames = @()

Clear-Host
Write-Host "Number of scanned Servers: " $numservers
Write-Host

# Adding rows Header
for ($i = 0; $i -le $numservers-1; $i++) {
	$iComputer = ""
	$Hostname = ""
	$FQDN = $ServerList[$i].computername
	$Position = $fqdn.IndexOf(".")
	$Hostname = $fqdn.Substring(0,$Position)

	Write-Host "Hostname: " $Hostname
	
	#$iComputer = $ServerList[$i].computername
	$iComputer = $Hostname
	$Hostnames += $iComputer
}
timeout /t 5

# Cycle of the time
for ($e = 1; $e -le $numCycles; $e++) {		
	Clear-Host
	Write-Host "Cycle" $e "of" $numCycles
	Write-Host
	
	# Cycle of servers
	for ($i = 0; $i -le $numservers-1; $i++) {
		
		$iComputer = ""
		$iComputer = $ServerList[$i].computername
				
		# Verify connection
		$TestConnection = Test-Connection -ComputerName $iComputer -Quiet -Count 1
		If (-Not $TestConnection) { }
			
		# Set session
		$Session = New-PSSession -ComputerName $iComputer -Credential $credential -ErrorAction Stop
			
		# Get RDP Sessions
		$RDPSessions = Invoke-Command -Session $Session -ScriptBlock { qwinsta /server:$iComputer; $lastexitcode } 2>&1
	
		$TotRDPActiveSessions = 0
		$TotRDPInactiveSessions = 0
	
		foreach ($row in $RDPSessions) {                
			$regex = "Disc|Active"
			#$regex = "Disc|Attivo"

			if ($row -NotMatch "services|console" -and $row -match $regex) {
				if ($row -match "Active") { $TotRDPActiveSessions ++ }
				if ($row -match "Disc") { $TotRDPInactiveSessions ++ }
			}
		}
		Write-Host $iComputer" - "$TotRDPActiveSessions "RDP session(s)"
		Write-Host		
	
		# Adding rows
		$Hostnames += $TotRDPActiveSessions
		
	}
	Start-Sleep -Seconds 2
	
	# Progress Bar 
	if ($e -lt $numCycles) {
		Clear-Host
		Write-Host "Cycle" $e "of" $numCycles
		Write-Host "Please wait $numMinutes Minute(s)"
		$seconds = $numMinutes * 60
		for ($w = 1; $w -le $seconds; $w++ ) {
			$Percent = [Math]::Round(($w/$seconds * 100),0)
			Write-Progress -Activity "Waiting" -Status "$Percent% Complete" -PercentComplete $Percent
			Start-Sleep -Second 1
		}
		Write-Progress -Activity "Complete" -Completed
		Clear-Host
	}
}

Clear-Host
$Hostnames | Select-Object @{n="column";e={$_}} | Format-Wide -column $numservers | Format-Table