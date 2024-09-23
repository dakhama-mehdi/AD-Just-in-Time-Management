
<#
.SYNOPSIS
    AD-Just-in-Time-Management is a PowerShell tool for managing Just-in-Time (JIT) access within Active Directory environments. 
    This tool allows for the temporary assignment of privileged roles, ensuring that administrative access is granted only when needed and for a limited time.

.DESCRIPTION
    This script facilitates the management of JIT access by:
    - Retrieving and displaying information about group members with Time-To-Live (TTL) attributes.
    - Adding new members to groups with a specified TTL.
    - Checking if a selected date is in the future.
    - Calculating the duration in minutes until a specified end date.
    - Handling errors effectively to ensure smooth operation.

.How to use
    Run only the script, and manage with GUI

.EXAMPLE
    .\Manage-JITAccess.ps1 

.NOTES
    Author: Dakhama Mehdi
    Helped : Thirrey Barcelo - Loic Vierment - Bastien Perez - Florian Burnel
    Version: 1.0
    Date: 08/2024
#>




#region Source: Startup.pss
#----------------------------------------------
#region Import Assemblies
#----------------------------------------------
[void][Reflection.Assembly]::Load('AspNetMMCExt.resources, Version=2.0.0.0, Culture=fr, PublicKeyToken=b03f5f7f11d50a3a')
#endregion Import Assemblies



function Main {
	Param ([String]$Commandline)

	if((Show-MainForm_psf) -eq 'OK')
	{
		
	}
	
	$script:ExitCode = 0 #Set the exit code for the Packager
}



#endregion Source: Startup.pss

#region Source: MainForm.psf
function Show-MainForm_psf
{
#region File Recovery Data (DO NOT MODIFY)
#endregion
	#----------------------------------------------
	#region Import the Assemblies
	#----------------------------------------------
	[void][reflection.assembly]::Load('AspNetMMCExt.resources, Version=2.0.0.0, Culture=fr, PublicKeyToken=b03f5f7f11d50a3a')
	[void][reflection.assembly]::Load('System.Windows.Forms, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089')
	[void][reflection.assembly]::Load('System.Design, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a')
	[void][reflection.assembly]::Load('System.Drawing, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a')
	#endregion Import Assemblies

	#----------------------------------------------
	#region Generated Form Objects
	#----------------------------------------------
	[System.Windows.Forms.Application]::EnableVisualStyles()
	$MainForm = New-Object 'System.Windows.Forms.Form'
	$buttonShowTTL = New-Object 'System.Windows.Forms.Button'
	$labelEnterGroupName = New-Object 'System.Windows.Forms.Label'
	$labelEnterUserName = New-Object 'System.Windows.Forms.Label'
	$buttonShowGroup = New-Object 'System.Windows.Forms.Button'
	$buttonAddUser = New-Object 'System.Windows.Forms.Button'
	$labelSelectMinutes = New-Object 'System.Windows.Forms.Label'
	$numericupdown1 = New-Object 'System.Windows.Forms.NumericUpDown'
	$richtextbox1 = New-Object 'System.Windows.Forms.RichTextBox'
	$labelSelectDateTTL = New-Object 'System.Windows.Forms.Label'
	$datetimepicker1 = New-Object 'System.Windows.Forms.DateTimePicker'
	$buttonSelectGroup = New-Object 'System.Windows.Forms.Button'
	$textbox2 = New-Object 'System.Windows.Forms.TextBox'
	$buttonSelectUser = New-Object 'System.Windows.Forms.Button'
	$textbox1 = New-Object 'System.Windows.Forms.TextBox'
	$menustrip1 = New-Object 'System.Windows.Forms.MenuStrip'
	$fileToolStripMenuItem = New-Object 'System.Windows.Forms.ToolStripMenuItem'
	$aboutToolStripMenuItem = New-Object 'System.Windows.Forms.ToolStripMenuItem'
	$exitToolStripMenuItem = New-Object 'System.Windows.Forms.ToolStripMenuItem'
	$InitialFormWindowState = New-Object 'System.Windows.Forms.FormWindowState'
	#endregion Generated Form Objects

	#----------------------------------------------
	# User Generated Script
	#----------------------------------------------
	
	$MainForm_Load={
	#TODO: Initialize Form Controls here
		$global:SelectedItem = $null
		$global:SearchType = $null
	}
	
	function Get-PAMGroupMembers
	{
		param (
			[string]$GroupName
		)
		
		# Retrieve group information with TTL
		$group = Get-ADGroup -Identity $GroupName -Property member -ShowMemberTimeToLive
		
		# Iterate through the members and extract the TTL
		$membersWithTTL = @()
		foreach ($member in $group.member)
		{
			if ($member -match "<TTL=(\d+)>")
			{
				$ttl = $matches[1]
				$userDN = $member -replace "<TTL=\d+>", ""
				$userDN = $userDN.TrimStart(',')
				
				$user = Get-ADUser -Identity $userDN
				$membersWithTTL += [PSCustomObject]@{
					UserName  = $user.Name
					TTL	      = $ttl
				}
			}
		}
		
		return $membersWithTTL
	}
	
	function Convert-TimeToReadableFormat
	{
		param (
			[int]$TotalSeconds
		)
		
		$days = [math]::Floor($TotalSeconds / 86400)
		$hours = [math]::Floor(($TotalSeconds % 86400) / 3600)
		$minutes = [math]::Floor(($TotalSeconds % 3600) / 60)
		$seconds = $TotalSeconds % 60
		
		$result = ""
		if ($days -gt 0)
		{
			$result += "$days day"
			if ($days -gt 1)
			{
				$result += "s"
			}
			$result += " "
		}
		if ($hours -gt 0)
		{
			$result += "$hours hour"
			if ($hours -gt 1)
			{
				$result += "s"
			}
			$result += " "
		}
		if ($minutes -gt 0)
		{
			$result += "$minutes minute"
			if ($minutes -gt 1)
			{
				$result += "s"
			}
			$result += " "
		}
		if ($seconds -gt 0)
		{
			$result += "$seconds second"
			if ($seconds -gt 1)
			{
				$result += "s"
			}
		}
		
		return $result.Trim()
	}
	
	
	$buttonSearch_Click={
		#TODO: Place custom script here
		
	}
	
	$buttonSelectUser_Click={
		#TODO: Place custom script here	
		$global:SearchType = $null
		$global:SearchType = 'user'	
		if ((Show-ChildForm_psf ) -eq 'OK')
		{
			$selectedUser = $global:SelectedItem		
		}	
		if ($selectedUser)
		{
			$richtextbox1.AppendText("User selected is : $selectedUser" + "`r`n")
			$textbox1.Text = $selectedUser
		}
	}
	
	$buttonSelectGroup_Click={	
		$global:SearchType = $null
		$global:SearchType = 'group'	
		if ((Show-ChildForm_psf ) -eq 'OK')
		{
			$selectedgroup = $global:SelectedItem		
		}	
		if ($selectedgroup)
		{
			$richtextbox1.AppendText("Group selected is : $selectedgroup" + "`r`n")
			$textbox2.Text = $selectedgroup
		}
	}
	
	$labelSelectMinutes_Click={
		#TODO: Place custom script here
		
	}
	
	$numericupdown1_ValueChanged={
		#TODO: Place custom script here
		
	}
	
	$buttonAddUser_Click={
		#TODO: Place custom script here
		$TTLMinutes = $numericupdown1.Value
		$UserName = $textbox1.Text
		$GroupName = $textbox2.Text
		$TTLDays = $datetimepicker1.Value
		$Now = Get-Date
		
		# Check if the selected date is in the future
		if ($TTLDays -gt $Now)
		{
			$TTL = ($TTLDays - $Now).TotalDays
			# Use the end date for the TTL
			$timeSpan = New-TimeSpan -Days $TTL
			$var = $TTLDays
		}
		elseif ($TTLMinutes -gt 0)
		{
			# "Use minutes for the TTL"
			$timeSpan = New-TimeSpan -Minutes $TTLMinutes
			$var = [string]$TTLMinutes + " minutes"
		}
		else
		{
			$richtextbox1.SelectionColor = 'red'
			$richtextbox1.AppendText("Time not be empty `r`n")
			return
		}
		
		try
		{
			# "Add a member to the group with TTL"
			Add-ADGroupMember -Identity $GroupName -Members $UserName -MemberTimeToLive $timeSpan
			$richtextbox1.Clear()
			$richtextbox1.SelectionColor = 'green'
			$richtextbox1.AppendText("User $UserName is temporarily added to the group : $GroupName`r`n Until $var.`r`n")
		}
		catch
		{
			# "Error handling"
			$richtextbox1.Clear()
			$richtextbox1.SelectionColor = 'red'
			$errorMessage = "Error to add $UserName to group $GroupName `r`n $_ `r`n"
			$richtextbox1.AppendText("$errorMessage")
		}
		
	}
	
	$textbox1_TextChanged={
		#TODO: Place custom script here
		
	}
	
	$textbox2_TextChanged={
		#TODO: Place custom script here
		
	}
	
	$buttonShowTTL_Click={
		#TODO: Place custom script here
	
		$richtextbox1.Clear()
		$TTLDate = $datetimepicker1.Value
		
		# "Check if the selected date is in the future"
		if ($TTLDate -gt (Get-Date))
		{
			# "Calculate the duration in minutes until the specified date"
			$Now = Get-Date
			$TtimeSpan = New-TimeSpan -End $TTLDate
			$richtextbox1.AppendText("Duration of addition in minutes : $TtimeSpan" + "`r`n")
		}
		else
		{
			$timeadd = $numericupdown1.Value
			$richtextbox1.AppendText("Addition time in minutes : $timeadd" + "`r`n")
		}
		
		
		
	}
	
	$buttonShowGroup_Click={
		# "Retrieve the members with TTL from a group and display them in the RichTextBox"
		$membersWithTTL = Get-PAMGroupMembers -GroupName $textbox2.Text
		
		# Check Members with TTL
		if ($membersWithTTL)
		{
			$richtextbox1.Clear()
			
			# List Members
			foreach ($member in $membersWithTTL)
			{
				$time = Convert-TimeToReadableFormat $($member.TTL)
				$text = "User: $($member.UserName), TTL:  $time"
				$richtextbox1.AppendText($text + "`r`n")
			}
		}
		else
		{
			$richtextbox1.Clear()
			$richtextbox1.AppendText("Not temporary member find")
		}
		
	}
	
	$datetimepicker1_ValueChanged={
		#TODO: Place custom script here
		
	}
	
	$datetimepicker1_ValueChanged={
		#TODO: Place custom script here
		
	}
	
	$aboutToolStripMenuItem_Click={
		[System.Windows.Forms.MessageBox]::Show("Developped By : Dakhama Mehdi `r`n`Project : HardenAD Toolbox `r`n`Thanks to : It-connect`r`n`HardenAD community
 	`r`n`Version 1.0 `r`nRelease   08/2024`r`nMicrosoft Windows NT 10.0.17763", 'AD Just-in-Time Management')
	}
	
	$richtextbox1_TextChanged={
		#TODO: Place custom script here
		
	}
	
	# --End User Generated Script--
	#----------------------------------------------
	#region Generated Events
	#----------------------------------------------
	
	$Form_StateCorrection_Load=
	{
		#Correct the initial state of the form to prevent the .Net maximized form issue
		$MainForm.WindowState = $InitialFormWindowState
	}
	
	$Form_StoreValues_Closing=
	{
		#Store the control values
		$script:MainForm_numericupdown1 = $numericupdown1.Value
		$script:MainForm_richtextbox1 = $richtextbox1.Text
		$script:MainForm_datetimepicker1 = $datetimepicker1.Value
		$script:MainForm_textbox2 = $textbox2.Text
		$script:MainForm_textbox1 = $textbox1.Text
	}

	
	$Form_Cleanup_FormClosed=
	{
		#Remove all event handlers from the controls
		try
		{
			$buttonShowTTL.remove_Click($buttonShowTTL_Click)
			$buttonShowGroup.remove_Click($buttonShowGroup_Click)
			$buttonAddUser.remove_Click($buttonAddUser_Click)
			$labelSelectMinutes.remove_Click($labelSelectMinutes_Click)
			$numericupdown1.remove_ValueChanged($numericupdown1_ValueChanged)
			$richtextbox1.remove_TextChanged($richtextbox1_TextChanged)
			$datetimepicker1.remove_ValueChanged($datetimepicker1_ValueChanged)
			$buttonSelectGroup.remove_Click($buttonSelectGroup_Click)
			$textbox2.remove_TextChanged($textbox2_TextChanged)
			$buttonSelectUser.remove_Click($buttonSelectUser_Click)
			$textbox1.remove_TextChanged($textbox1_TextChanged)
			$MainForm.remove_Load($MainForm_Load)
			$aboutToolStripMenuItem.remove_Click($aboutToolStripMenuItem_Click)
			$MainForm.remove_Load($Form_StateCorrection_Load)
			$MainForm.remove_Closing($Form_StoreValues_Closing)
			$MainForm.remove_FormClosed($Form_Cleanup_FormClosed)
		}
		catch { Out-Null <# Prevent PSScriptAnalyzer warning #> }
	}
	#endregion Generated Events

	#----------------------------------------------
	#region Generated Form Code
	#----------------------------------------------
	$MainForm.SuspendLayout()
	$numericupdown1.BeginInit()
	$menustrip1.SuspendLayout()
	#
	# MainForm
	#
	$MainForm.Controls.Add($buttonShowTTL)
	$MainForm.Controls.Add($labelEnterGroupName)
	$MainForm.Controls.Add($labelEnterUserName)
	$MainForm.Controls.Add($buttonShowGroup)
	$MainForm.Controls.Add($buttonAddUser)
	$MainForm.Controls.Add($labelSelectMinutes)
	$MainForm.Controls.Add($numericupdown1)
	$MainForm.Controls.Add($richtextbox1)
	$MainForm.Controls.Add($labelSelectDateTTL)
	$MainForm.Controls.Add($datetimepicker1)
	$MainForm.Controls.Add($buttonSelectGroup)
	$MainForm.Controls.Add($textbox2)
	$MainForm.Controls.Add($buttonSelectUser)
	$MainForm.Controls.Add($textbox1)
	$MainForm.Controls.Add($menustrip1)
	$MainForm.AutoScaleDimensions = '8, 17'
	$MainForm.AutoScaleMode = 'Font'
	$MainForm.ClientSize = '461, 486'
	$MainForm.Margin = '5, 5, 5, 5'
	$MainForm.Name = 'MainForm'
	$MainForm.StartPosition = 'CenterScreen'
	$MainForm.Text = 'AD Just-in-Time Management'
	$MainForm.add_Load($MainForm_Load)
	#
	# buttonShowTTL
	#
	$buttonShowTTL.Anchor = 'None'
	$buttonShowTTL.Location = '96, 432'
	$buttonShowTTL.Margin = '4, 4, 4, 4'
	$buttonShowTTL.Name = 'buttonShowTTL'
	$buttonShowTTL.Size = '88, 30'
	$buttonShowTTL.TabIndex = 26
	$buttonShowTTL.Text = 'Show TTL'
	$buttonShowTTL.UseCompatibleTextRendering = $True
	$buttonShowTTL.UseVisualStyleBackColor = $True
	$buttonShowTTL.add_Click($buttonShowTTL_Click)
	#
	# labelEnterGroupName
	#
	$labelEnterGroupName.Anchor = 'None'
	$labelEnterGroupName.AutoSize = $True
	$labelEnterGroupName.Location = '14, 124'
	$labelEnterGroupName.Margin = '5, 0, 5, 0'
	$labelEnterGroupName.Name = 'labelEnterGroupName'
	$labelEnterGroupName.Size = '124, 21'
	$labelEnterGroupName.TabIndex = 25
	$labelEnterGroupName.Text = 'Enter Group Name'
	$labelEnterGroupName.UseCompatibleTextRendering = $True
	#
	# labelEnterUserName
	#
	$labelEnterUserName.Anchor = 'None'
	$labelEnterUserName.AutoSize = $True
	$labelEnterUserName.Location = '15, 58'
	$labelEnterUserName.Margin = '5, 0, 5, 0'
	$labelEnterUserName.Name = 'labelEnterUserName'
	$labelEnterUserName.Size = '114, 21'
	$labelEnterUserName.TabIndex = 24
	$labelEnterUserName.Text = 'Enter User Name'
	$labelEnterUserName.UseCompatibleTextRendering = $True
	#
	# buttonShowGroup
	#
	$buttonShowGroup.Anchor = 'None'
	$buttonShowGroup.Location = '206, 432'
	$buttonShowGroup.Margin = '4, 4, 4, 4'
	$buttonShowGroup.Name = 'buttonShowGroup'
	$buttonShowGroup.Size = '122, 30'
	$buttonShowGroup.TabIndex = 23
	$buttonShowGroup.Text = 'Show group'
	$buttonShowGroup.UseCompatibleTextRendering = $True
	$buttonShowGroup.UseVisualStyleBackColor = $True
	$buttonShowGroup.add_Click($buttonShowGroup_Click)
	#
	# buttonAddUser
	#
	$buttonAddUser.Anchor = 'None'
	$buttonAddUser.Location = '346, 432'
	$buttonAddUser.Margin = '4, 4, 4, 4'
	$buttonAddUser.Name = 'buttonAddUser'
	$buttonAddUser.Size = '100, 30'
	$buttonAddUser.TabIndex = 22
	$buttonAddUser.Text = 'Add user'
	$buttonAddUser.UseCompatibleTextRendering = $True
	$buttonAddUser.UseVisualStyleBackColor = $True
	$buttonAddUser.add_Click($buttonAddUser_Click)
	#
	# labelSelectMinutes
	#
	$labelSelectMinutes.Anchor = 'None'
	$labelSelectMinutes.AutoSize = $True
	$labelSelectMinutes.Location = '336, 198'
	$labelSelectMinutes.Margin = '5, 0, 5, 0'
	$labelSelectMinutes.Name = 'labelSelectMinutes'
	$labelSelectMinutes.Size = '98, 21'
	$labelSelectMinutes.TabIndex = 21
	$labelSelectMinutes.Text = 'Select Minutes'
	$labelSelectMinutes.UseCompatibleTextRendering = $True
	$labelSelectMinutes.add_Click($labelSelectMinutes_Click)
	#
	# numericupdown1
	#
	$numericupdown1.Anchor = 'None'
	$numericupdown1.Location = '357, 222'
	$numericupdown1.Margin = '4, 4, 4, 4'
	$numericupdown1.Name = 'numericupdown1'
	$numericupdown1.Size = '66, 23'
	$numericupdown1.TabIndex = 20
	$numericupdown1.add_ValueChanged($numericupdown1_ValueChanged)
	#
	# richtextbox1
	#
	$richtextbox1.Anchor = 'Top, Left, Right'
	$richtextbox1.Font = 'Microsoft Sans Serif, 10pt'
	$richtextbox1.Location = '14, 268'
	$richtextbox1.Margin = '4, 4, 4, 4'
	$richtextbox1.Name = 'richtextbox1'
	$richtextbox1.Size = '435, 146'
	$richtextbox1.TabIndex = 19
	$richtextbox1.Text = ''
	$richtextbox1.add_TextChanged($richtextbox1_TextChanged)
	#
	# labelSelectDateTTL
	#
	$labelSelectDateTTL.AutoSize = $True
	$labelSelectDateTTL.Location = '14, 189'
	$labelSelectDateTTL.Margin = '5, 0, 5, 0'
	$labelSelectDateTTL.Name = 'labelSelectDateTTL'
	$labelSelectDateTTL.Size = '107, 21'
	$labelSelectDateTTL.TabIndex = 18
	$labelSelectDateTTL.Text = 'Select Date TTL'
	$labelSelectDateTTL.UseCompatibleTextRendering = $True
	#
	# datetimepicker1
	#
	$datetimepicker1.Location = '13, 214'
	$datetimepicker1.Margin = '4, 4, 4, 4'
	$datetimepicker1.Name = 'datetimepicker1'
	$datetimepicker1.Size = '265, 23'
	$datetimepicker1.TabIndex = 17
	$datetimepicker1.add_ValueChanged($datetimepicker1_ValueChanged)
	#
	# buttonSelectGroup
	#
	$buttonSelectGroup.Anchor = 'None'
	$buttonSelectGroup.Location = '332, 150'
	$buttonSelectGroup.Margin = '4, 4, 4, 4'
	$buttonSelectGroup.Name = 'buttonSelectGroup'
	$buttonSelectGroup.Size = '124, 30'
	$buttonSelectGroup.TabIndex = 16
	$buttonSelectGroup.Text = 'Select group'
	$buttonSelectGroup.UseCompatibleTextRendering = $True
	$buttonSelectGroup.UseVisualStyleBackColor = $True
	$buttonSelectGroup.add_Click($buttonSelectGroup_Click)
	#
	# textbox2
	#
	$textbox2.Anchor = 'None'
	$textbox2.BackColor = 'ButtonFace'
	$textbox2.Location = '15, 150'
	$textbox2.Margin = '5, 5, 5, 5'
	$textbox2.Name = 'textbox2'
	$textbox2.Size = '284, 23'
	$textbox2.TabIndex = 15
	$textbox2.add_TextChanged($textbox2_TextChanged)
	#
	# buttonSelectUser
	#
	$buttonSelectUser.Anchor = 'None'
	$buttonSelectUser.AutoSizeMode = 'GrowAndShrink'
	$buttonSelectUser.Location = '332, 84'
	$buttonSelectUser.Margin = '4, 4, 4, 4'
	$buttonSelectUser.Name = 'buttonSelectUser'
	$buttonSelectUser.Size = '122, 30'
	$buttonSelectUser.TabIndex = 14
	$buttonSelectUser.Text = 'Select user'
	$buttonSelectUser.UseCompatibleTextRendering = $True
	$buttonSelectUser.UseVisualStyleBackColor = $True
	$buttonSelectUser.add_Click($buttonSelectUser_Click)
	#
	# textbox1
	#
	$textbox1.Anchor = 'None'
	$textbox1.BackColor = 'ButtonFace'
	$textbox1.Location = '15, 84'
	$textbox1.Margin = '5, 5, 5, 5'
	$textbox1.Name = 'textbox1'
	$textbox1.Size = '284, 23'
	$textbox1.TabIndex = 13
	$textbox1.add_TextChanged($textbox1_TextChanged)
	#
	# menustrip1
	#
	$menustrip1.BackColor = 'InactiveCaption'
	$menustrip1.ImageScalingSize = '20, 20'
	[void]$menustrip1.Items.Add($fileToolStripMenuItem)
	[void]$menustrip1.Items.Add($aboutToolStripMenuItem)
	$menustrip1.Location = '0, 0'
	$menustrip1.Name = 'menustrip1'
	$menustrip1.Padding = '8, 3, 0, 3'
	$menustrip1.Size = '461, 30'
	$menustrip1.TabIndex = 12
	$menustrip1.Text = 'A'
	#
	# fileToolStripMenuItem
	#
	[void]$fileToolStripMenuItem.DropDownItems.Add($exitToolStripMenuItem)
	$fileToolStripMenuItem.Name = 'fileToolStripMenuItem'
	$fileToolStripMenuItem.Size = '44, 24'
	$fileToolStripMenuItem.Text = 'File'
	#
	# aboutToolStripMenuItem
	#
	$aboutToolStripMenuItem.Name = 'aboutToolStripMenuItem'
	$aboutToolStripMenuItem.Size = '62, 24'
	$aboutToolStripMenuItem.Text = 'About'
	$aboutToolStripMenuItem.add_Click($aboutToolStripMenuItem_Click)
	#
	# exitToolStripMenuItem
	#
	$exitToolStripMenuItem.Name = 'exitToolStripMenuItem'
	$exitToolStripMenuItem.Size = '108, 26'
	$exitToolStripMenuItem.Text = 'Exit'
	$menustrip1.ResumeLayout()
	$numericupdown1.EndInit()
	$MainForm.ResumeLayout()
	#endregion Generated Form Code

	#----------------------------------------------

	#Save the initial state of the form
	$InitialFormWindowState = $MainForm.WindowState
	#Init the OnLoad event to correct the initial state of the form
	$MainForm.add_Load($Form_StateCorrection_Load)
	#Clean up the control events
	$MainForm.add_FormClosed($Form_Cleanup_FormClosed)
	#Store the control values when form is closing
	$MainForm.add_Closing($Form_StoreValues_Closing)
	#Show the Form
	return $MainForm.ShowDialog()

}
#endregion Source: MainForm.psf

#region Source: Globals.ps1
	#--------------------------------------------
	# Declare Global Variables and Functions here
	#--------------------------------------------
	
	
	#Sample function that provides the location of the script
	function Get-ScriptDirectory
	{
		[OutputType([string])]
		param ()
		if ($null -ne $hostinvocation)
		{
			Split-Path $hostinvocation.MyCommand.path
		}
		else
		{
			Split-Path $script:MyInvocation.MyCommand.Path
		}
	}
	
	#Sample variable that provides the location of the script
	[string]$ScriptDirectory = Get-ScriptDirectory
	
	
	
#endregion Source: Globals.ps1

#region Source: ChildForm.psf
function Show-ChildForm_psf
{
	#----------------------------------------------
	#region Import the Assemblies
	#----------------------------------------------
	[void][reflection.assembly]::Load('AspNetMMCExt, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a')
	[void][reflection.assembly]::Load('AspNetMMCExt.resources, Version=2.0.0.0, Culture=fr, PublicKeyToken=b03f5f7f11d50a3a')
	[void][reflection.assembly]::Load('System.Windows.Forms, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089')
	[void][reflection.assembly]::Load('System.Drawing, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a')
	#endregion Import Assemblies

	#----------------------------------------------
	#region Generated Form Objects
	#----------------------------------------------
	[System.Windows.Forms.Application]::EnableVisualStyles()
	$formSearchItem = New-Object 'System.Windows.Forms.Form'
	$listbox1 = New-Object 'System.Windows.Forms.ListBox'
	$buttonOK = New-Object 'System.Windows.Forms.Button'
	$buttonCancel = New-Object 'System.Windows.Forms.Button'
	$InitialFormWindowState = New-Object 'System.Windows.Forms.FormWindowState'
	#endregion Generated Form Objects

	#----------------------------------------------
	# User Generated Script
	#----------------------------------------------
	
	
	$formSearchItem_Load={
		#TODO: Initialize Form Controls here
		
		$val = $null
		
		
		if ($global:SearchType -eq 'user')
		{
			$val = '*' + $textbox1.Text + '*'
			$compval = Get-ADUser -Filter "name -like '$val'"
		}
		elseif ($global:SearchType -eq 'group')
		{
			$val = '*' + $textbox2.Text + '*'
			$compval = Get-ADGroup -Filter "name -like '$val'"
		}
		
		# Vérifier si des résultats ont été trouvés
		if ($compval)
		{
			Write-Host "Résultats trouvés : $($compval.SamAccountName)"
			$listbox1.Items.Clear()
			foreach ($item in $compval)
			{
				$listbox1.Items.Add($item.SamAccountName)
			}
		}
		else
		{
			Write-Host "Aucun résultat trouvé"
			$listbox1.Items.Clear()
			$listbox1.Items.Add("Aucun résultat trouvé")
		}
		
	}
	
	
	#region Control Helper Functions
	function Update-ListBox
	{
		
		param
		(
			[Parameter(Mandatory = $true)]
			[ValidateNotNull()]
			[System.Windows.Forms.ListBox]
			$ListBox,
			[Parameter(Mandatory = $true)]
			[ValidateNotNull()]
			$Items,
			[Parameter(Mandatory = $false)]
			[string]
			$DisplayMember,
			[switch]
			$Append
		)
		
		if (-not $Append)
		{
			$listBox.Items.Clear()
		}
		
		if ($Items -is [System.Windows.Forms.ListBox+ObjectCollection] -or $Items -is [System.Collections.ICollection])
		{
			$listBox.Items.AddRange($Items)
		}
		elseif ($Items -is [System.Collections.IEnumerable])
		{
			$listBox.BeginUpdate()
			foreach ($obj in $Items)
			{
				$listBox.Items.Add($obj)
			}
			$listBox.EndUpdate()
		}
		else
		{
			$listBox.Items.Add($Items)
		}
		
		$listBox.DisplayMember = $DisplayMember
	}
	#endregion
	
	$listbox1_SelectedIndexChanged={
		#TODO: Place custom script here
		
	}
	
	$listbox1_DoubleClick={
		#TODO: Place custom script here
		$selectedItem = $listbox1.SelectedItem
		if ($selectedItem -ne "Aucun résultat trouvé")
		{
			$global:SelectedItem = $selectedItem
			Write-Host "Élément sélectionné : $global:SelectedItem"
			$formSearchItem.DialogResult = [System.Windows.Forms.DialogResult]::OK
			$formSearchItem.Close()
		}
	}
	
	$buttonOK_Click={
		#TODO: Place custom script here
		
	}
	
	# --End User Generated Script--
	#----------------------------------------------
	#region Generated Events
	#----------------------------------------------
	
	$Form_StateCorrection_Load=
	{
		#Correct the initial state of the form to prevent the .Net maximized form issue
		$formSearchItem.WindowState = $InitialFormWindowState
	}
	
	$Form_StoreValues_Closing=
	{
		#Store the control values
		$script:ChildForm_listbox1 = $listbox1.SelectedItems
	}

	
	$Form_Cleanup_FormClosed=
	{
		#Remove all event handlers from the controls
		try
		{
			$listbox1.remove_SelectedIndexChanged($listbox1_SelectedIndexChanged)
			$listbox1.remove_DoubleClick($listbox1_DoubleClick)
			$buttonOK.remove_Click($buttonOK_Click)
			$formSearchItem.remove_Load($formSearchItem_Load)
			$formSearchItem.remove_Load($Form_StateCorrection_Load)
			$formSearchItem.remove_Closing($Form_StoreValues_Closing)
			$formSearchItem.remove_FormClosed($Form_Cleanup_FormClosed)
		}
		catch { Out-Null <# Prevent PSScriptAnalyzer warning #> }
	}
	#endregion Generated Events

	#----------------------------------------------
	#region Generated Form Code
	#----------------------------------------------
	$formSearchItem.SuspendLayout()
	#
	# formSearchItem
	#
	$formSearchItem.Controls.Add($listbox1)
	$formSearchItem.Controls.Add($buttonOK)
	$formSearchItem.Controls.Add($buttonCancel)
	$formSearchItem.AutoScaleDimensions = '8, 17'
	$formSearchItem.AutoScaleMode = 'Font'
	$formSearchItem.ClientSize = '293, 221'
	$formSearchItem.Margin = '5, 5, 5, 5'
	$formSearchItem.Name = 'formSearchItem'
	$formSearchItem.StartPosition = 'CenterParent'
	$formSearchItem.Text = 'Search item'
	$formSearchItem.add_Load($formSearchItem_Load)
	#
	# listbox1
	#
	$listbox1.Anchor = 'Top, Bottom, Left, Right'
	$listbox1.FormattingEnabled = $True
	$listbox1.ItemHeight = 17
	$listbox1.Location = '13, 13'
	$listbox1.Margin = '4, 4, 4, 4'
	$listbox1.Name = 'listbox1'
	$listbox1.Size = '277, 157'
	$listbox1.TabIndex = 2
	$listbox1.add_SelectedIndexChanged($listbox1_SelectedIndexChanged)
	$listbox1.add_DoubleClick($listbox1_DoubleClick)
	#
	# buttonOK
	#
	$buttonOK.Anchor = 'Bottom, Right'
	$buttonOK.DialogResult = 'OK'
	$buttonOK.Location = '136, 186'
	$buttonOK.Margin = '4, 4, 4, 4'
	$buttonOK.Name = 'buttonOK'
	$buttonOK.Size = '70, 30'
	$buttonOK.TabIndex = 1
	$buttonOK.Text = '&OK'
	$buttonOK.UseCompatibleTextRendering = $True
	$buttonOK.UseVisualStyleBackColor = $True
	$buttonOK.Visible = $False
	$buttonOK.add_Click($buttonOK_Click)
	#
	# buttonCancel
	#
	$buttonCancel.Anchor = 'Bottom, Right'
	$buttonCancel.CausesValidation = $False
	$buttonCancel.DialogResult = 'Cancel'
	$buttonCancel.Location = '214, 186'
	$buttonCancel.Margin = '4, 4, 4, 4'
	$buttonCancel.Name = 'buttonCancel'
	$buttonCancel.Size = '73, 30'
	$buttonCancel.TabIndex = 0
	$buttonCancel.Text = '&Cancel'
	$buttonCancel.UseCompatibleTextRendering = $True
	$buttonCancel.UseVisualStyleBackColor = $True
	$formSearchItem.ResumeLayout()
	#endregion Generated Form Code

	#----------------------------------------------

	#Save the initial state of the form
	$InitialFormWindowState = $formSearchItem.WindowState
	#Init the OnLoad event to correct the initial state of the form
	$formSearchItem.add_Load($Form_StateCorrection_Load)
	#Clean up the control events
	$formSearchItem.add_FormClosed($Form_Cleanup_FormClosed)
	#Store the control values when form is closing
	$formSearchItem.add_Closing($Form_StoreValues_Closing)
	#Show the Form
	return $formSearchItem.ShowDialog()

}
#endregion Source: ChildForm.psf

#Start the application
Main ($CommandLine)
