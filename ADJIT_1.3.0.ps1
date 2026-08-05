
<#
.SYNOPSIS
    AD-Just-in-Time-Management is a PowerShell tool for managing Just-in-Time (JIT) access within Active Directory environments. 
    This tool allows for the temporary assignment of privileged roles, ensuring that administrative access is granted only when needed and for a limited time.

.DESCRIPTION
    This tool simplifies the management of Active Directory Just-in-Time (JIT) group memberships by:

    - Retrieving and displaying group members with their Time-To-Live (TTL) information.
    - Adding users or groups with a configurable TTL membership.
    - Validating that the selected expiration date is in the future.
    - Calculating the remaining duration until membership expiration.
    - Logging all JIT operations to a dedicated Windows Event Log for auditing and traceability.
    - Providing a standard user mode for viewing JIT memberships without requiring administrative privileges.
    - Handling errors gracefully to ensure a reliable user experience.

.How to use
    Run only the script, and manage with GUI

.EXAMPLE
    .\ADJIT_v1.3.0.ps1 

.NOTES
    Author: Dakhama Mehdi
    Helped : Guillaume Matthieu - Florian Burnel - Alain Cuisner
    Credit : Harden Community
    Version: 1.3.0
    Date: 08/2026
#>

#region hide powershell window
Add-Type -AssemblyName PresentationFramework

Add-Type -Name Window -Namespace Console -MemberDefinition @'
[DllImport("Kernel32.dll")]
public static extern IntPtr GetConsoleWindow();

[DllImport("user32.dll")]
public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
'@

$consoleWindow = [Console.Window]::GetConsoleWindow()

if ($consoleWindow -ne [IntPtr]::Zero) {
    [Console.Window]::ShowWindow($consoleWindow, 2)
}

function Show-InfoDialog {
    param (
        [string]$Message,
        [string]$Title = "Information",
        [ValidateSet("Information", "Warning", "Error", "None")]
        [string]$MessageType = "Information"
    )

    # Convert the message type to the MessageBoxImage enum
    $icon = [System.Windows.MessageBoxImage]::$MessageType

    [System.Windows.MessageBox]::Show($Message, $Title, 'OK', $icon) | Out-Null
}
#endregion hide powershell windows

if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
    
    Show-InfoDialog -Message "The 'ActiveDirectory' module is required. Please install RSAT or import the module manually." -MessageType Error
    throw "The 'ActiveDirectory' module is required. Please install RSAT or import the module manually."
}

if (-not (Get-Module -Name ActiveDirectory)) {
    Import-Module ActiveDirectory -ErrorAction Stop
}

$BackgroundColor = "#34495e"

#region WPF
[xml]$XAML = @"
<Window 
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="AD-Just in Time Management"
    Background="#f0f2f5"
    Foreground="#2c3e50"
    Height="620"
    Width="500"
    ResizeMode="CanResize"
    WindowStartupLocation="CenterScreen"
    FontFamily="Segoe UI"
    FontSize="13">

    <Grid Background="Transparent" Margin="0">
        <Border Background="#f0f2f5" CornerRadius="8" Margin="0">
            <Grid>
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>   <!-- Menu -->
                    <RowDefinition Height="Auto"/>   <!-- Zone User/Group -->
                    <RowDefinition Height="Auto"/>   <!-- Expander Infos -->
                    <RowDefinition Height="*"/>      <!-- DataGrid -->
                    <RowDefinition Height="Auto"/>   <!-- Buttons -->
                </Grid.RowDefinitions>

                <!-- Menu -->
                <Menu Grid.Row="0" Background="Transparent" Foreground="Black" Margin="10,0,0,0" FontSize="14">
                    <MenuItem Header="File">
                        <MenuItem Name="menuOpen" Header="Open"/>
                        <Separator/>
                        <MenuItem Name="menuLogs" Header="Event Log"/>
                        <Separator/>
                        <MenuItem Name="menuHistory" Header="History"/>
                        <Separator/>
                        <MenuItem Name="menuExit" Header="Exit"/>
                    </MenuItem>
                    <MenuItem Name="menuAbout" Header="About"/>
                </Menu>

                <!-- Zone Group/User -->
                <StackPanel Grid.Row="1" Orientation="Vertical" Margin="12,10,12,5">

                    <!-- Group -->
                    <StackPanel Orientation="Horizontal" Margin="0,5">
                        <Label Content="Enter Group Name" Width="120" VerticalAlignment="Center"/>
                        <TextBox Name="txtGroup" Width="200"/>

                        <Button Name="btnSelectGroup" Width="120" Margin="5,0" Background="#0078D7" Foreground="White">
                         <StackPanel Orientation="Horizontal" HorizontalAlignment="Center">
                             <TextBlock Text="&#xE716;" FontFamily="Segoe MDL2 Assets" FontSize="12" Margin="0,0,6,0"/>
                        <TextBlock Text="Select Group"/>
                         </StackPanel>
                        </Button>

                    </StackPanel>

                    <!-- User -->
                    <StackPanel Orientation="Horizontal" Margin="0,5">
                        <Label Content="Enter Username" Width="120" VerticalAlignment="Center"/>
                        <TextBox Name="txtUser" Width="200"/>
                        <Button Name="btnSelectUser" Width="120" Margin="5,0" Background="#0078D7" Foreground="White">
                         <StackPanel Orientation="Horizontal" HorizontalAlignment="Center">
                             <TextBlock Text="&#xe77b;" FontFamily="Segoe MDL2 Assets" FontSize="12" Margin="0,0,6,0"/>
                        <TextBlock Text="Select Member"/>
                         </StackPanel>
                        </Button>
                    </StackPanel>

                    <!-- Duration -->
                    <StackPanel Orientation="Horizontal" Margin="0,5">

                        <Label Content="Duration (days)" Width="120" VerticalAlignment="Center"/>
                        <DatePicker Name="datePicker" Width="150" Margin="0,0,25,0"/>
                        <TextBlock FontFamily="Segoe MDL2 Assets" Text="&#xE823;" FontSize="16" VerticalAlignment="Center" Margin="5,0"/>
                        <Button Name="btnDecreaseDuration" Content="−" Width="25" Margin="5,0"/>
                        <TextBox Name="txtDuration" Width="40" Text="0" IsReadOnly="True" HorizontalContentAlignment="Center"/>
                        <Button Name="btnIncreaseDuration" Content="+" Width="25" Margin="2,0"/>
                    </StackPanel>
                </StackPanel>

                <!-- Infos du groupe -->
                <Expander Name="expanderGroupInfo" Grid.Row="2" IsExpanded="True" Margin="20,10,20,10">
                 <Expander.Header>
                     <TextBlock Text="Group Info" Foreground="#0078D7" FontSize="14" FontWeight="SemiBold"/>
                 </Expander.Header>


                    <Border Background="White" Padding="10" CornerRadius="6" BorderBrush="#d0d7de" BorderThickness="1" >
                        <StackPanel Orientation="Vertical" TextElement.FontSize="12">

                            <StackPanel Orientation="Horizontal" Margin="0,2">
                                <TextBlock Text="Privileged Group" Width="130" Foreground="#2c3e50"/>
                                <TextBlock Name="txtGroupPrivileg" Text="-" Foreground="#3498db"/>
                            </StackPanel>

                            <StackPanel Orientation="Horizontal" Margin="0,2">
                                <TextBlock Text="Category" Width="130"/>
                                <TextBlock Name="txtGroupNameType" Text="-" Foreground="#3498db"/>
                            </StackPanel>

                            <StackPanel Orientation="Horizontal" Margin="0,2">
                                <TextBlock Text="OU Path" Width="130"/>
                                <TextBlock Name="txtOUPath" Text="-"/>
                            </StackPanel>

                            <StackPanel Orientation="Horizontal" Margin="0,2">
                                <TextBlock Text="Last Edit" Width="130"/>
                                <TextBlock Name="txtGroupModified" Text="-"/>
                            </StackPanel>

                            <StackPanel Orientation="Horizontal" Margin="0,2">
                                <TextBlock Text="Description" Width="130"/>
                                <TextBlock Name="txtGroupDescInfo" Text="-" TextWrapping="Wrap"/>
                            </StackPanel>

                            <StackPanel Orientation="Horizontal" Margin="0,2">
                                <TextBlock Text="Members Count" Width="130"/>
                                <TextBlock Name="txtGroupMembersInfo" Text="-"/>
                            </StackPanel>

                            <StackPanel Orientation="Horizontal" Margin="0,2">
                                <TextBlock Text="Managed By" Width="130"/>
                                <TextBlock Name="txtGroupManageBy" Text="-" Foreground="#3498db"/>
                            </StackPanel>

                        </StackPanel>
                    </Border>
                </Expander>

                <!-- DataGrid encadrée -->
              <GroupBox Grid.Row="3" Margin="12,0,12,10">
             <GroupBox.Header>
              <StackPanel Orientation="Horizontal">
        <TextBlock Text="&#xed28;" FontFamily="Segoe MDL2 Assets" FontSize="14" Margin="0,0,5,0" Foreground="#0078D7"/>
        <TextBlock Text="Time-Limited Members" FontWeight="SemiBold" FontSize="14"  Foreground="#0078D7"/>
    </StackPanel>
             </GroupBox.Header>
    
            <DataGrid Name="dgMembers" Margin="5" HeadersVisibility="Column" IsReadOnly="True" AutoGenerateColumns="True" FontFamily="Consolas" 
            FontSize="12" GridLinesVisibility="All" ColumnWidth="*" Background="White" AlternatingRowBackground="#f2f2f2" AlternationCount="2"/>
            </GroupBox>
            
                <!-- Boutons bas -->
                <StackPanel Grid.Row="4" Orientation="Horizontal" HorizontalAlignment="Center" Margin="10,0,0,10">
                    <Button Name="btnShowGroup" Content="Show Group" Width="110" Background="#27ae60" Foreground="White" Margin="10,0"/>
                    <Button Name="btnRemoveUser" Content="Remove Member" Width="110" IsEnabled="False" Background="#2980b9" Foreground="Black" Margin="10,0"/>
                    <Button Name="btnAddUser" Content="Add Member" Width="110" IsEnabled="False" Background="#2980b9" Foreground="Black" Margin="10,0"/>
                </StackPanel>

            </Grid>
        </Border>
    </Grid>
</Window>
"@

# Function to show user interface
function Show-UserSelection {
	param (
		[string[]]$UserList
	)
	
	[xml]$XAML = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="Sélect Item" Height="250" Width="300" Background="#f1f1f1" >
    <Grid>
        <ListBox Name="lstUsers" Width="250" Height="190" 
                 HorizontalAlignment="Center" VerticalAlignment="Top" Margin="10"/>
    </Grid>
</Window>
"@
	
	$reader = (New-Object System.Xml.XmlNodeReader $XAML)
	$UserWindow = [Windows.Markup.XamlReader]::Load($reader)
	
	$lstUsers = $UserWindow.FindName("lstUsers")
    $UserWindow.Tag = $null # Reset before show
    
	foreach ($user in $UserList)
	{
        [void]$lstUsers.Items.Add($user)
	}
	
    $doubleClickHandler = {
        param($sender, $eventArgs)

        if ($null -eq $sender.SelectedItem) {
            return
        }

        # Store the selected value directly on the child window.
        # GetNewClosure() keeps the correct $UserWindow reference outside ISE.
        $UserWindow.Tag = [string]$sender.SelectedItem
        $UserWindow.DialogResult = $true
    }.GetNewClosure()

    $lstUsers.Add_MouseDoubleClick($doubleClickHandler)
	
	# Show new window selection
	$UserWindow.WindowStartupLocation = "Manual"
	$UserWindow.Left = $Window.Left + ($Window.Width - $UserWindow.Width) / 2
	$UserWindow.Top = $Window.Top + ($Window.Height - $UserWindow.Height) / 2
	#UserWindow.Icon = $Bitmap_Black
	$result = $UserWindow.ShowDialog()
	
	# Check if window if closed empty
	if (-not $result)
	{
		return $null
	}
	
    return $UserWindow.Tag
}

function Show-JITHistoryWindow {
    [xml]$XAML = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="Historique JIT" Height="400" Width="850" Background="#f2f2f2">
    <Grid>
        <DataGrid Name="dgHistory" 
          Margin="5" 
          AutoGenerateColumns="True"
          IsReadOnly="True"
          HeadersVisibility="Column"
          GridLinesVisibility="All"
          ColumnWidth="*"
          FontFamily="Segoe UI"
          FontSize="13"
          Background="White"
          AlternatingRowBackground="#f2f2f2"
          AlternationCount="2"/>
    </Grid>
</Window>
"@


    $reader = (New-Object System.Xml.XmlNodeReader $XAML)
    $HistoryWindow = [Windows.Markup.XamlReader]::Load($reader)
    $dgHistory = $HistoryWindow.FindName("dgHistory")


    # Lire les événements depuis le journal
    $logs = Get-EventLog -LogName "AD_Just-in-Time_Management" -Newest 200 | Sort-Object TimeGenerated -Descending

    $parsed = foreach ($log in $logs) {
        $firstLine = ($log.Message -split "`r?`n")[0]
        $fields = @{}
        foreach ($part in $firstLine -split '\s*\|\s*') {
            if ($part -match '^(.*?)=(.*)$') {
                $fields[$matches[1]] = $matches[2]
            }
        }

        # Objet affichable dans GridView
        [PSCustomObject]@{
            Date      = $log.TimeGenerated
            Type      = $log.EntryType
            EventID   = $log.EventID
            User      = $fields['User']
            Action    = $fields['Action']
            Group     = $fields['Group']
            Member    = $fields['Member']
        }
    }

    $dgHistory.ItemsSource = $parsed

    $HistoryWindow.WindowStartupLocation = "CenterScreen"
    $HistoryWindow.ShowDialog()
}

function Show-AboutWindow {
    [xml]$XAML = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="About" Height="250" Width="300" WindowStartupLocation="CenterScreen">
    <Grid Background="White">
        <StackPanel HorizontalAlignment="Center" VerticalAlignment="Center">
            <TextBlock Text="AD Just-in-Time Management" FontSize="18" FontWeight="Bold" Foreground="Black" TextAlignment="Center"/>
            <TextBlock Text="Version 1.3.0" FontSize="14" Foreground="Gray" TextAlignment="Center" Margin="0,5,0,5"/>
            <TextBlock Text="Developed by Dakhama Mehdi" FontSize="14" Foreground="Black" TextAlignment="Center"/>
            <TextBlock Text="Credit Harden community" FontSize="14" Foreground="Black" TextAlignment="Center"/>
            <TextBlock Text="Thanks to IT-Connect.fr" FontSize="14" Foreground="Black" TextAlignment="Center"/>
            <TextBlock Text="Thanks to doctorkloud.fr" FontSize="14" Foreground="Black" TextAlignment="Center"/>
            <TextBlock Text="© 2026 All rights reserved" FontSize="12" Foreground="Gray" TextAlignment="Center"/>
            <Button Name="btnClose" Content="Close" Width="100" Height="30" Margin="10" HorizontalAlignment="Center"/>
        </StackPanel>
    </Grid>
</Window>
"@

    # Charger la fenêtre
    $reader = (New-Object System.Xml.XmlNodeReader $XAML)
    $AboutWindow = [Windows.Markup.XamlReader]::Load($reader)

    # Récupérer le bouton
    $btnClose = $AboutWindow.FindName("btnClose")

    # Fermer la fenêtre quand on clique sur "Close"
    $btnClose.Add_Click({ $AboutWindow.Close() })

    #$AboutWindow.Icon = $Bitmap_Black
    # Afficher la fenêtre
    $AboutWindow.ShowDialog()
}
function clear-boxinfo {

        $dgMembers.ItemsSource = $null

        $expanderGroupInfo.IsExpanded = $true
        $txtGroupPrivileg.Text    = $null
        $txtGroupNameType.Text    = $null
        $txtOUPath.text           = $null
        $txtGroupDescInfo.Text    = $null
        $txtGroupMembersInfo.Text = $null
        $txtGroupManageBy.Text    = $null
        $txtGroupModified.Text    = $null
    }

#endregion WPF

$reader = (New-Object System.Xml.XmlNodeReader $XAML)
$Window = [Windows.Markup.XamlReader]::Load($reader)

# Load controls bouton
$txtGroup = $Window.FindName("txtGroup")
$txtUser = $Window.FindName("txtUser")
$richTextBox = $Window.FindName("richTextBox")
$dgMembers = $Window.FindName("dgMembers")
$datePicker = $Window.FindName("datePicker")
$txtDuration = $Window.FindName("txtDuration")
$btnSelectMember = $Window.FindName("btnSelectUser")
$btnSelectGroup = $Window.FindName("btnSelectGroup")
$btnRemoveUser = $Window.FindName("btnRemoveUser")
$btnAddUser = $Window.FindName("btnAddUser")
$btnShowGroup = $Window.FindName("btnShowGroup")
$btnIncreaseDuration = $Window.FindName("btnIncreaseDuration")
$btnDecreaseDuration = $Window.FindName("btnDecreaseDuration")
$txtGroupNameType = $Window.FindName("txtGroupNameType")
$txtGroupDescInfo = $Window.FindName("txtGroupDescInfo")
$txtGroupMembersInfo = $Window.FindName("txtGroupMembersInfo")
$txtGroupPrivileg = $Window.FindName("txtGroupPrivileg")
$txtGroupManageBy = $Window.FindName("txtGroupManageBy")
$txtGroupModified = $Window.FindName("txtGroupModified")
$txtOUPath = $Window.FindName("txtOUPath")
$expanderGroupInfo = $Window.FindName("expanderGroupInfo")
$menuLogs = $Window.FindName("menuLogs")
$menuHistory = $Window.FindName("menuHistory")
$menuExit = $Window.FindName("menuExit")
$menuAbout = $Window.FindName("menuAbout")


$datePicker.SelectedDate = get-date

#region fonction
function Get-PAMGroupMembers {
    param (
        [string]$GroupName
    )

    # Initialize the list of members
    $membersWithTTL = @()

    try {
        # Retrieve group information
        $group  = Get-ADGroup -Identity $GroupName -ShowMemberTimeToLive -Property admincount,Description,member,ManagedBy,Modified -ErrorAction Stop #-Server $DC

        $OUPath = Get-ADGroupParentPath -DistinguishedName $group.DistinguishedName 

        $groupsprivileged = "No"
        if ($group.admincount -eq 1) { $groupsprivileged = "Yes" } 
        $expanderGroupInfo.IsExpanded = $true
        $txtGroupPrivileg.Text    = "$groupsprivileged"
        $txtGroupNameType.Text    = "$($group.GroupCategory)  - $($group.GroupScope)"
        $txtOUPath.text           = "$OUPath"
        $txtGroupDescInfo.Text    = "$($group.Description)"
        $txtGroupMembersInfo.Text = "$($group.member.Count)"
        $txtGroupManageBy.Text    = "$($group.ManagedBy)"
        $txtGroupModified.Text    = "$($group.Modified)"

    }
    catch {
        # Return the error without displaying in the PowerShell console
        return "Error: $($_.Exception.Message)"
    }

    # Check if the group has members before processing
    if ($group -and $group.member) {
        foreach ($member in $group.member) {
            if ($member -match "<TTL=(\d+)>") {
                $ttl = $matches[1]
                $userDN = $member -replace "<TTL=\d+>", ""
                $userDN = $userDN.TrimStart(',')
                $formattedTTL = Convert-TimeToReadableFormat $ttl  

                try {
                    # Retrieve the user without displaying an error
                                        
                    $object = Get-ADObject -Identity $userDN -Properties ObjectClass

                    if ($object.ObjectClass -eq 'user') {
                    $user = Get-ADUser -Identity $userDN -Properties admincount
                    $type = 'User'
                    } elseif ($object.ObjectClass -eq 'Group') {
                    $user = Get-ADGroup -Identity $userDN -Properties admincount
                    $type = 'Group'
                    } elseif ($object.ObjectClass -eq 'Computer') {
                    $user = Get-ADComputer -Identity $userDN -Properties admincount
                    $type = 'Machine'
                    }

                    $membersWithTTL += [PSCustomObject]@{
                        UserName = $user.Name
                        "Time Left"  = $formattedTTL
                        Enabled  = $user.Enabled
                        Admin    = if ($user.admincount) { "True" } else { "False" }
                        Type = $type
                        DistinguishedName = $user.DistinguishedName
                    }
                }
                catch {
                    # In case of error on Get-ADUser, store the message
                    $membersWithTTL += [PSCustomObject]@{
                        UserName = "Unknown User ($userDN)"
                        "Time Left" = $formattedTTL
                        Enabled  = "-"
                        Admin    = "-"
                    }
                }
            }
        }
    }

    # Return the results or a message if no members found
    if ($membersWithTTL.Count -eq 0) {     
        Show-DataGridMessage -Message "No members with TTL found"
        $btnRemoveUser.IsEnabled = $false
        return
    } 

    $btnRemoveUser.IsEnabled = $true
    return ,$membersWithTTL
}	

function Show-DataGridMessage {
    param (
        [string]$Message
    )

    $dgMembers.ItemsSource = @(
        [PSCustomObject]@{
            Message = $Message
        }
    )
}

function Show-GroupMembers {
    $membersWithTTL = Get-PAMGroupMembers -GroupName $txtGroup.Text 
    if ($membersWithTTL) {
        $dgMembers.ItemsSource = $membersWithTTL
    }
}


function Convert-TimeToReadableFormat {
    param (
        [int]$Seconds
    )

    $ts = [TimeSpan]::FromSeconds($Seconds)
    $parts = @()

    $hasDays  = $ts.Days -gt 0
    $hasHours = $ts.Hours -gt 0
    $hasMins  = $ts.Minutes -gt 0

    if ($hasDays)     { $parts += "$($ts.Days) Days" }
    if ($hasHours)    { $parts += "$($ts.Hours)h" }

    # Only show minutes if not both days and hours
    if (-not ($hasDays -and $hasHours) -and $hasMins) {
        $parts += "$($ts.Minutes) minutes"
    }

    if ($parts.Count -eq 0) {
        return "0m"
    }

    return $parts -join " "
}

function Get-ADGroupParentPath {
    param (
        [string]$DistinguishedName
    )

    $dnParts = $DistinguishedName -split ','

    # Remove the first CN=... (the object itself)
    $parentParts = $dnParts | Select-Object -Skip 1

    # Keep only OU= or CN= (but no DC=)
    $ouOrCnParts = $parentParts | Where-Object { $_ -match '^(OU|CN)=' }

    if ($ouOrCnParts.Count -eq 0) {
        return ""
    }

    [array]::Reverse($ouOrCnParts)
    return ($ouOrCnParts -join ',')
}

# check logs

function Ensure-EventLogExists {
    param(
        [string]$LogName = 'AD_Just-in-Time_Management',
        [string]$Source = 'AD-JIT'
    )

    try {
        if (-not [System.Diagnostics.EventLog]::SourceExists($Source)) {
            New-EventLog -LogName $LogName -Source $Source
        }
        return $true
    }
    catch {
        return $false
    }
}

function Start-ElevatedEventLogCreation {
    $script = {
        if (-not [System.Diagnostics.EventLog]::SourceExists('AD-JIT')) {
            New-EventLog -LogName 'AD_Just-in-Time_Management' -Source 'AD-JIT'
        }
        Add-Type -AssemblyName PresentationFramework
        [System.Windows.MessageBox]::Show("The log has been successfully created.", "Elevation successful", "OK", "Information")
    }

    $scriptText = $script.ToString()

    $encodedCommand = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($scriptText))

    try {
    Start-Process powershell -ArgumentList "-NoProfile", "-ExecutionPolicy Bypass", "-EncodedCommand $encodedCommand" -Verb RunAs
    $menuLogs.IsEnabled = $false
    }
    catch {
    [System.Windows.MessageBox]::Show(
        "Unable to start the elevated PowerShell process.`n`nReason: $($_.Exception.Message)",
        "Error",
        [System.Windows.MessageBoxButton]::OK,
        [System.Windows.MessageBoxImage]::Error
    )
    }
}

function Write-JITEvent {
    param(
        [string]$Message,
        [ValidateSet('Information', 'Warning', 'Error')]
        [string]$Type = 'Information',
        [int]$ID
    )

    $logName   = 'AD_Just-in-Time_Management'
    $logSource = 'AD-JIT'

    # Check performed only once per session
    if ($menuLogs.IsEnabled -eq $true) {
            Write-Warning "Event log '$logName' does not exist. Run Start-ElevatedEventLogCreation in administrator mode."
            return
    }

    try {
        Write-EventLog -LogName $logName -Source $logSource -EntryType $Type -EventId $ID -Message $Message
    } catch {
        Write-Warning "Unable to write to the log '$logName'. Reason : $($_.Exception.Message)"
    }
}

#endregion fonction


#region button

   $btnSelectMember.Add_Click({

    if ($txtUser.Text.Length -lt 3) {
        $txtUser.Text = "Minimum 3 characters..."
        $txtUser.SelectAll()  
        return
    }

   if (!$txtUser.Text) {
        return
    }

    $allusers = "*$($txtUser.Text)*"
    $user = (Get-ADObject -Filter "((objectClass -eq 'user') -or (objectClass -eq 'group') -or (objectClass -eq 'computer')) -and (name -like '$allusers')" -Properties "SamAccountName").SamAccountName | select -First 40
    
    if ($user.Count -eq 0) {
        $txtUser.Text = "No Users Found"
        return
    }

    $SelectedUser = Show-UserSelection -UserList $user

    # Check if the window was closed without any selection
    if ($null -eq $SelectedUser) {
        Write-Host "No selection made, operation canceled."
        return
    }

    $txtUser.Text = [string]$SelectedUser

    if (-not $txtGroup.Text ) { $btnAddUser.IsEnabled = $false } else { $btnAddUser.IsEnabled = $true }
})

   $btnSelectGroup.Add_Click({

    if (!$txtGroup.Text) {
        return
    }

    if ($txtGroup.Text.Length -lt 3) {
        $txtGroup.Text = "Minimum 3 characters..."
        $txtGroup.SelectAll()  
        return
    }

    $allgroups = "*$($txtGroup.Text)*" 
    $Group = (Get-ADGroup -Filter "name -like '$allgroups'").samaccountname

    if ($Group.Count -eq 0) {
        $txtGroup.Text = "No Group Found"
        clear-boxinfo
        return
    }

    # Show the selection window with this list
    $SelectedGroup = Show-UserSelection -UserList $Group

    # Check if the window was closed without any selection
    if ($null -eq $SelectedGroup) {
        Write-Host "No selection made, operation canceled."
        return
    }

    $txtGroup.Text = [string]$SelectedGroup

    if (-not $txtUser.Text) { $btnAddUser.IsEnabled = $false } else { $btnAddUser.IsEnabled = $true }
    Show-GroupMembers

    # Update the TextBox with the selected group

})

   $txtUser.Add_KeyDown({
    if ($_.Key -eq "Return") {
        $btnSelectMember.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Button]::ClickEvent))
    }
})

    $txtGroup.Add_KeyDown({
    if ($_.Key -eq "Return") {
        $btnSelectGroup.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Button]::ClickEvent))
    }
})

    $txtUser.Add_TextChanged({
    $btnAddUser.IsEnabled = $false
})

    $txtGroup.Add_TextChanged({
    $btnAddUser.IsEnabled = $false

    if ([string]::IsNullOrWhiteSpace($txtGroup.Text)) {
        clear-boxinfo
    }
})

    $btnRemoveUser.Add_Click({
    
    $selectedUser = $dgMembers.SelectedItem

    if (-not $selectedUser) {
        Show-InfoDialog -Message "Please select a user." -Title "Warning" -MessageType "Warning"
        return
    }

    # Example: using the selected object’s data
    $username = $selectedUser.UserName
    $DN       = $selectedUser.DistinguishedName

    # Confirmation message with Yes/No
    $GroupName = $txtGroup.Text
    $confirmation = [System.Windows.MessageBox]::Show(
        "Do you want to remove $username from group $GroupName ?",
        "Confirmation",
        [System.Windows.MessageBoxButton]::YesNo,
        [System.Windows.MessageBoxImage]::Question
    )
    
    if ($confirmation -eq [System.Windows.MessageBoxResult]::Yes) {
        try {
            # Example: remove the user from an AD group (adapt to your context)
            Remove-ADGroupMember -Identity $GroupName -Members $DN -Confirm:$false

            Show-InfoDialog -Message "$username has been successfully removed." -Title "Success"

            $whoami = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
            $logMessage = "User=$whoami | Action=RemoveUserFromGroup | Group=$GroupName | Member=$username "

            Write-JITEvent -Type Warning -ID 1002 -Message $logMessage

        }
        catch {
            Show-InfoDialog -Message "An error occurred while removing the user: $_" -Title "Error" -MessageType "Error"
            $Errorremovemsg = "An error occurred while removing the user: $_"
            Write-JITEvent -Type Error -ID 2002 -Message $Errorremovemsg
        }
        Show-GroupMembers
    }
    else {
        Write-Verbose "User removal cancelled by the operator."
    }
})

    $btnShowGroup.Add_Click({
    
    $GroupName = $txtGroup.Text
    if (!$GroupName) {
        Write-Host ("Please enter a valid group name `r`n") -ForegroundColor Red
        clear-boxinfo
        return
    }

    $membersWithTTL = Get-PAMGroupMembers -GroupName $txtGroup.Text

    if ($membersWithTTL) {

        $dgMembers.ItemsSource = $membersWithTTL

         }
})

    $btnAddUser.Add_Click({

    $TTLHours  = $txtDuration.Text
    $UserName  = $txtUser.Text
    $GroupName = $txtGroup.Text
    $TTLDays   = $datePicker.SelectedDate
    $Now       = Get-Date
    
    # Check if the selected date is in the future
    if ($TTLDays -gt $Now)
    {
        $TTL = ($TTLDays - $Now).TotalDays
        $timeSpan = New-TimeSpan -Days $TTL
    }
    elseif ($TTLHours -gt 0)
    {
        # Use hours for the TTL
        $timeSpan = New-TimeSpan -Hours $TTLHours
    }
    else
    {
        Show-InfoDialog -Message "Time must not be empty. Please select a correct date or duration." -MessageType Warning 
        return
    }

    try
    {
        # Add a member to the group with TTL
        Add-ADGroupMember -Identity $GroupName -Members $UserName -MemberTimeToLive $timeSpan 

        # Log success to Event Log
    $whoami = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    $formattedTTL = Convert-TimeToReadableFormat $timeSpan.TotalSeconds
    $logMessage = "User=$whoami | Action=AddUserToGroup | Group=$GroupName | Member=$UserName | TTL=$formattedTTL"

    #Write-EventLog -LogName "HardenAD_JIT" -Source "HardenAD_JIT" -EventId 1001 -EntryType Information -Message $logMessage
    Write-JITEvent -Type Information -ID 1001 -Message $logMessage
    Write-Host "$UserName succefull add"
    Show-GroupMembers
    }
    catch
    {
        # Error handling
        $whoami = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
        $errorMessage = "User=$whoami | Action=AddUserToGroup-Failed | Group=$GroupName | Member=$UserName | `r`n Error=$_ `r`n" 
        
        # Log failure to Event Log
        Write-JITEvent -Type Error -ID 2001 -Message $errorMessage
        
        $errormsg = "The operation failed. See the AD-JIT event log for technical details."        
        Show-InfoDialog -Message $errormsg -MessageType Error
    }
    
    $btnAddUser.IsEnabled = $false
})

    $btnIncreaseDuration.Add_Click({
    $value = [int]$txtDuration.Text
    if ($value -lt 24) {
        $txtDuration.Text = ($value + 1).ToString()
    }
})

    $btnDecreaseDuration.Add_Click({
    $value = [int]$txtDuration.Text
    if ($value -gt 0) {
        $txtDuration.Text = ($value - 1).ToString()
    }
})

    $menuLogs.Add_click({
    if (-not (Ensure-EventLogExists)) {
    # If writing failed, retry the operation with elevation
    Start-ElevatedEventLogCreation
    }
else {
    [System.Windows.MessageBox]::Show("The event log is ready!", "Success", "OK", "Information")
}
 
})

    $menuHistory.Add_Click({
    Show-JITHistoryWindow
})

    $menuAbout.Add_Click({
    Show-AboutWindow
})

    $menuExit.Add_Click({
    $Window.Close()  
})

#endregion button

$menuLogs.IsEnabled = -not (Ensure-EventLogExists)

# Load GUI
$Window.ShowDialog() | Out-Null

# SIG # Begin signature block
# MIItjAYJKoZIhvcNAQcCoIItfTCCLXkCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBvgmn7zU0x7PS3
# qgUQoSqwmh4ne3dMWSD2lannlbaBKqCCEtUwggXJMIIEsaADAgECAhAbtY8lKt8j
# AEkoya49fu0nMA0GCSqGSIb3DQEBDAUAMH4xCzAJBgNVBAYTAlBMMSIwIAYDVQQK
# ExlVbml6ZXRvIFRlY2hub2xvZ2llcyBTLkEuMScwJQYDVQQLEx5DZXJ0dW0gQ2Vy
# dGlmaWNhdGlvbiBBdXRob3JpdHkxIjAgBgNVBAMTGUNlcnR1bSBUcnVzdGVkIE5l
# dHdvcmsgQ0EwHhcNMjEwNTMxMDY0MzA2WhcNMjkwOTE3MDY0MzA2WjCBgDELMAkG
# A1UEBhMCUEwxIjAgBgNVBAoTGVVuaXpldG8gVGVjaG5vbG9naWVzIFMuQS4xJzAl
# BgNVBAsTHkNlcnR1bSBDZXJ0aWZpY2F0aW9uIEF1dGhvcml0eTEkMCIGA1UEAxMb
# Q2VydHVtIFRydXN0ZWQgTmV0d29yayBDQSAyMIICIjANBgkqhkiG9w0BAQEFAAOC
# Ag8AMIICCgKCAgEAvfl4+ObVgAxknYYblmRnPyI6HnUBfe/7XGeMycxca6mR5rlC
# 5SBLm9qbe7mZXdmbgEvXhEArJ9PoujC7Pgkap0mV7ytAJMKXx6fumyXvqAoAl4Va
# qp3cKcniNQfrcE1K1sGzVrihQTib0fsxf4/gX+GxPw+OFklg1waNGPmqJhCrKtPQ
# 0WeNG0a+RzDVLnLRxWPa52N5RH5LYySJhi40PylMUosqp8DikSiJucBb+R3Z5yet
# /5oCl8HGUJKbAiy9qbk0WQq/hEr/3/6zn+vZnuCYI+yma3cWKtvMrTscpIfcRnNe
# GWJoRVfkkIJCu0LW8GHgwaM9ZqNd9BjuiMmNF0UpmTJ1AjHuKSbIawLmtWJFfzcV
# WiNoidQ+3k4nsPBADLxNF8tNorMe0AZa3faTz1d1mfX6hhpneLO/lv403L3nUlbl
# s+V1e9dBkQXcXWnjlQ1DufyDljmVe2yAWk8TcsbXfSl6RLpSpCrVQUYJIP4ioLZb
# MI28iQzV13D4h1L92u+sUS4Hs07+0AnacO+Y+lbmbdu1V0vc5SwlFcieLnhO+Nqc
# noYsylfzGuXIkosagpZ6w7xQEmnYDlpGizrrJvojybawgb5CAKT41v4wLsfSRvbl
# jnX98sy50IdbzAYQYLuDNbdeZ95H7JlI8aShFf6tjGKOOVVPORa5sWOd/7cCAwEA
# AaOCAT4wggE6MA8GA1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYEFLahVDkCw6A/joq8
# +tT4HKbROg79MB8GA1UdIwQYMBaAFAh2zcsH/yT2xc3tu5C84oQ3RnX3MA4GA1Ud
# DwEB/wQEAwIBBjAvBgNVHR8EKDAmMCSgIqAghh5odHRwOi8vY3JsLmNlcnR1bS5w
# bC9jdG5jYS5jcmwwawYIKwYBBQUHAQEEXzBdMCgGCCsGAQUFBzABhhxodHRwOi8v
# c3ViY2Eub2NzcC1jZXJ0dW0uY29tMDEGCCsGAQUFBzAChiVodHRwOi8vcmVwb3Np
# dG9yeS5jZXJ0dW0ucGwvY3RuY2EuY2VyMDkGA1UdIAQyMDAwLgYEVR0gADAmMCQG
# CCsGAQUFBwIBFhhodHRwOi8vd3d3LmNlcnR1bS5wbC9DUFMwDQYJKoZIhvcNAQEM
# BQADggEBAFHCoVgWIhCL/IYx1MIy01z4S6Ivaj5N+KsIHu3V6PrnCA3st8YeDrJ1
# BXqxC/rXdGoABh+kzqrya33YEcARCNQOTWHFOqj6seHjmOriY/1B9ZN9DbxdkjuR
# mmW60F9MvkyNaAMQFtXx0ASKhTP5N+dbLiZpQjy6zbzUeulNndrnQ/tjUoCFBMQl
# lVXwfqefAcVbKPjgzoZwpic7Ofs4LphTZSJ1Ldf23SIikZbr3WjtP6MZl9M7JYjs
# NhI9qX7OAo0FmpKnJ25FspxihjcNpDOO16hO0EoXQ0zF8ads0h5YbBRRfopUofbv
# n3l6XYGaFpAP4bvxSgD5+d2+7arszgowggZHMIIEL6ADAgECAhA12OBytW+cTayv
# VHUpRhwLMA0GCSqGSIb3DQEBCwUAMFYxCzAJBgNVBAYTAlBMMSEwHwYDVQQKExhB
# c3NlY28gRGF0YSBTeXN0ZW1zIFMuQS4xJDAiBgNVBAMTG0NlcnR1bSBDb2RlIFNp
# Z25pbmcgMjAyMSBDQTAeFw0yNTExMTYxMTAwMTlaFw0yNjExMTYxMTAwMThaMG0x
# CzAJBgNVBAYTAkZSMQ8wDQYDVQQHDAZUb3Vsb24xHjAcBgNVBAoMFU9wZW4gU291
# cmNlIERldmVsb3BlcjEtMCsGA1UEAwwkT3BlbiBTb3VyY2UgRGV2ZWxvcGVyLCBE
# QUtIQU1BIE1FSERJMIIBojANBgkqhkiG9w0BAQEFAAOCAY8AMIIBigKCAYEAp6Ku
# m/VmkWCqAaF/3zHh9f1FuJYY2ozbXOu7mo1/Q8i1c0fE0TXpkZXLY2GZbfpj9BmH
# AAFM0IhOsPR2vdxq3jOUJUb9TICneFor6YaPpySsXR3WSE7X42kgpkkmPELovm1Y
# hwSzhJ4a+E+NWL/MU8h5JpmGVlqPJ02/ZTlMj5kcpIQtq8hoQMcUEDkGFt9IcamE
# 1yN4IHkBA5nm4jJPaos0IuS77t805992JSGWhxBxWARH+2vyltv8Rmq1pZV1lE6n
# JgrWT7Ichjw2X/A+OP68ooTzQwCIpzXb4UuUcwHEfrmP3HGMQJoj//SNC4QPMao+
# 3Z8zbevl73E3d6Kfvra1S+pWM2Ze5YCsIqAd98GUHgi5E6GiG8FQq/+d6msL7l8B
# UASCqXlcAKIjRNMHp8BrUaaW6HS9Kpc+3O3t/LUmK6X3FFiW8QsWoh4K+7YSpopa
# CQbNXmEI4xftctwBOJrEU2oqRnYiwchfjqBNlrGwVGPK1rmM0iTt5KiLTus7AgMB
# AAGjggF4MIIBdDAMBgNVHRMBAf8EAjAAMD0GA1UdHwQ2MDQwMqAwoC6GLGh0dHA6
# Ly9jY3NjYTIwMjEuY3JsLmNlcnR1bS5wbC9jY3NjYTIwMjEuY3JsMHMGCCsGAQUF
# BwEBBGcwZTAsBggrBgEFBQcwAYYgaHR0cDovL2Njc2NhMjAyMS5vY3NwLWNlcnR1
# bS5jb20wNQYIKwYBBQUHMAKGKWh0dHA6Ly9yZXBvc2l0b3J5LmNlcnR1bS5wbC9j
# Y3NjYTIwMjEuY2VyMB8GA1UdIwQYMBaAFN10XUwA23ufoHTKsW73PMAywHDNMB0G
# A1UdDgQWBBSXTmfHi9BD9GDRwk5/doNtKHBXYzBLBgNVHSAERDBCMAgGBmeBDAEE
# ATA2BgsqhGgBhvZ3AgUBBDAnMCUGCCsGAQUFBwIBFhlodHRwczovL3d3dy5jZXJ0
# dW0ucGwvQ1BTMBMGA1UdJQQMMAoGCCsGAQUFBwMDMA4GA1UdDwEB/wQEAwIHgDAN
# BgkqhkiG9w0BAQsFAAOCAgEAe+khGqwUUkFYuFRsrvenX2/a+PIt2Tu9d3VoW6Or
# MX3YLpe7S2CgFkXwEi2Siq5KiD1labP9jsh/3G1ZQwwlnPv8dB7ocl/nOrQ9OZex
# GVE1r7IO6VYVa5F7XuJ/KadKLEbQSs1BpBVhESo1ZYr6w9NCLuO9q2Sh3H5MktET
# D6sB+g1TFOYMdwYl8eAawgI2kGPe3dRQSoumP0mHkm3x5SIwRCW+08md5uyzCIui
# 85WmcNPtM1QCqjkSpfdFGYPsnf/BO9NATpZkqFxhXwa9+PqseX+mofCIL49guCXG
# kU4RpeRHcUie14oYkxvBw7VUO4MT6wYbS2C3j2nyoAV4XqqNMfrhZIBJG5haj2RB
# V46bMJ+DsW6hxlm3lIlCaJT2pLbbk79OP+Bk0HIdC9mAbKzcqaZpBpn4+ljrcx7/
# X7OHv4XTCCDWwlZbaogy4Wci6TiSjjfpfXK5N/eJTEEh2w4qoYTTrR61ptkVnTUT
# vGRfPnVtS/3aOm2v4UahtOc/ygcL0A/J85r1e6CEeOaTm9eJbHoNdwNIYaZ81VlX
# /V/MoJgFCtioYOKiTf2Rdq7XrEEHLU2YGwCqJyKYz9tz10yXBcMW6/+gX+PGqAYz
# eKg5jbKLdi9lVrKspQUXAPHdcl6VJMXy799J0lbsQeJNgBVy6HWxOWvdLBGX3hPE
# 3aYwgga5MIIEoaADAgECAhEAmaOACiZVO2Wr3G6EprPqOTANBgkqhkiG9w0BAQwF
# ADCBgDELMAkGA1UEBhMCUEwxIjAgBgNVBAoTGVVuaXpldG8gVGVjaG5vbG9naWVz
# IFMuQS4xJzAlBgNVBAsTHkNlcnR1bSBDZXJ0aWZpY2F0aW9uIEF1dGhvcml0eTEk
# MCIGA1UEAxMbQ2VydHVtIFRydXN0ZWQgTmV0d29yayBDQSAyMB4XDTIxMDUxOTA1
# MzIxOFoXDTM2MDUxODA1MzIxOFowVjELMAkGA1UEBhMCUEwxITAfBgNVBAoTGEFz
# c2VjbyBEYXRhIFN5c3RlbXMgUy5BLjEkMCIGA1UEAxMbQ2VydHVtIENvZGUgU2ln
# bmluZyAyMDIxIENBMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAnSPP
# BDAjO8FGLOczcz5jXXp1ur5cTbq96y34vuTmflN4mSAfgLKTvggv24/rWiVGzGxT
# 9YEASVMw1Aj8ewTS4IndU8s7VS5+djSoMcbvIKck6+hI1shsylP4JyLvmxwLHtSw
# orV9wmjhNd627h27a8RdrT1PH9ud0IF+njvMk2xqbNTIPsnWtw3E7DmDoUmDQiYi
# /ucJ42fcHqBkbbxYDB7SYOouu9Tj1yHIohzuC8KNqfcYf7Z4/iZgkBJ+UFNDcc6z
# okZ2uJIxWgPWXMEmhu1gMXgv8aGUsRdaCtVD2bSlbfsq7BiqljjaCun+RJgTgFRC
# tsuAEw0pG9+FA+yQN9n/kZtMLK+Wo837Q4QOZgYqVWQ4x6cM7/G0yswg1ElLlJj6
# NYKLw9EcBXE7TF3HybZtYvj9lDV2nT8mFSkcSkAExzd4prHwYjUXTeZIlVXqj+ea
# YqoMTpMrfh5MCAOIG5knN4Q/JHuurfTI5XDYO962WZayx7ACFf5ydJpoEowSP07Y
# aBiQ8nXpDkNrUA9g7qf/rCkKbWpQ5boufUnq1UiYPIAHlezf4muJqxqIns/kqld6
# JVX8cixbd6PzkDpwZo4SlADaCi2JSplKShBSND36E/ENVv8urPS0yOnpG4tIoBGx
# VCARPCg1BnyMJ4rBJAcOSnAWd18Jx5n858JSqPECAwEAAaOCAVUwggFRMA8GA1Ud
# EwEB/wQFMAMBAf8wHQYDVR0OBBYEFN10XUwA23ufoHTKsW73PMAywHDNMB8GA1Ud
# IwQYMBaAFLahVDkCw6A/joq8+tT4HKbROg79MA4GA1UdDwEB/wQEAwIBBjATBgNV
# HSUEDDAKBggrBgEFBQcDAzAwBgNVHR8EKTAnMCWgI6Ahhh9odHRwOi8vY3JsLmNl
# cnR1bS5wbC9jdG5jYTIuY3JsMGwGCCsGAQUFBwEBBGAwXjAoBggrBgEFBQcwAYYc
# aHR0cDovL3N1YmNhLm9jc3AtY2VydHVtLmNvbTAyBggrBgEFBQcwAoYmaHR0cDov
# L3JlcG9zaXRvcnkuY2VydHVtLnBsL2N0bmNhMi5jZXIwOQYDVR0gBDIwMDAuBgRV
# HSAAMCYwJAYIKwYBBQUHAgEWGGh0dHA6Ly93d3cuY2VydHVtLnBsL0NQUzANBgkq
# hkiG9w0BAQwFAAOCAgEAdYhYD+WPUCiaU58Q7EP89DttyZqGYn2XRDhJkL6P+/T0
# IPZyxfxiXumYlARMgwRzLRUStJl490L94C9LGF3vjzzH8Jq3iR74BRlkO18J3zId
# mCKQa5LyZ48IfICJTZVJeChDUyuQy6rGDxLUUAsO0eqeLNhLVsgw6/zOfImNlARK
# n1FP7o0fTbj8ipNGxHBIutiRsWrhWM2f8pXdd3x2mbJCKKtl2s42g9KUJHEIiLni
# 9ByoqIUul4GblLQigO0ugh7bWRLDm0CdY9rNLqyA3ahe8WlxVWkxyrQLjH8ItI17
# RdySaYayX3PhRSC4Am1/7mATwZWwSD+B7eMcZNhpn8zJ+6MTyE6YoEBSRVrs0zFF
# IHUR08Wk0ikSf+lIe5Iv6RY3/bFAEloMU+vUBfSouCReZwSLo8WdrDlPXtR0gicD
# nytO7eZ5827NS2x7gCBibESYkOh1/w1tVxTpV2Na3PR7nxYVlPu1JPoRZCbH86gc
# 96UTvuWiOruWmyOEMLOGGniR+x+zPF/2DaGgK2W1eEJfo2qyrBNPvF7wuAyQfiFX
# LwvWHamoYtPZo0LHuH8X3n9C+xN4YaNjt2ywzOr+tKyEVAotnyU9vyEVOaIYMk3I
# eBrmFnn0gbKeTTyYeEEUz/Qwt4HOUBCrW602NCmvO1nm+/80nLy5r0AZvCQxaQ4x
# ghoNMIIaCQIBATBqMFYxCzAJBgNVBAYTAlBMMSEwHwYDVQQKExhBc3NlY28gRGF0
# YSBTeXN0ZW1zIFMuQS4xJDAiBgNVBAMTG0NlcnR1bSBDb2RlIFNpZ25pbmcgMjAy
# MSBDQQIQNdjgcrVvnE2sr1R1KUYcCzANBglghkgBZQMEAgEFAKB8MBAGCisGAQQB
# gjcCAQwxAjAAMBkGCSqGSIb3DQEJAzEMBgorBgEEAYI3AgEEMBwGCisGAQQBgjcC
# AQsxDjAMBgorBgEEAYI3AgEVMC8GCSqGSIb3DQEJBDEiBCBAoWZqNf2lpJ/DGt8H
# N2jx7I4fEGqK0b4Ml6Z0KWitNzANBgkqhkiG9w0BAQEFAASCAYCVRsk63J2TCICx
# cIVCLXTlDS1Zte2fjSUF83ci4z6xx/awkTh0B5PZ8PFAVteaoM0UQp0ESlkSmytV
# msE3x+Tg8A6XHFW9wZK3qXNS8LqwSCNpWSwnrAfXtSTBsa+LvlAb4bhIZxgvDJ7s
# RD3N2wM9Td6JmOxj+DA8HBhW5MPxpP74XkgXrQfVWRJyPzW65H0CsLMcflimCdiM
# R8MqF3YYwdZI6ZlZWctPtKbMr3daoW7SAUdIMI+NB14EInqJevQc/yOgzAwQL34C
# wBttytJdt6KkONsE/dCLaVmRCcsWQrgczH4UcEppYQ+R5yw0muZzpM5F2nGcJcbn
# l84DBjwyoTUCdHxSPMioeP1sfwAxCh45eJc6h6fkrOH0XuNHmzZScfD+DmLOXVbG
# C6tvfgLxdu7E9MXHc7QjjraBEcZN40ch2Ig88H/of1BO4NfTYz7anaH+N/FEdNG2
# 4FXRkf+5PPHVP2FeqCosJxEFl39lsowkj5gmpc0N8b13VohxqQuhghd2MIIXcgYK
# KwYBBAGCNwMDATGCF2IwghdeBgkqhkiG9w0BBwKgghdPMIIXSwIBAzEPMA0GCWCG
# SAFlAwQCAQUAMHcGCyqGSIb3DQEJEAEEoGgEZjBkAgEBBglghkgBhv1sBwEwMTAN
# BglghkgBZQMEAgEFAAQgOQMC9FIMq5l1KLpjIkRjAtXRd2VkDrbI5IFHBadxsiQC
# EGTj1kEaqOYvg+1HU0tgx4QYDzIwMjYwODA1MTUzMDA2WqCCEzowggbtMIIE1aAD
# AgECAhAKgO8YS43xBYLRxHanlXRoMA0GCSqGSIb3DQEBCwUAMGkxCzAJBgNVBAYT
# AlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwgSW5jLjFBMD8GA1UEAxM4RGlnaUNlcnQg
# VHJ1c3RlZCBHNCBUaW1lU3RhbXBpbmcgUlNBNDA5NiBTSEEyNTYgMjAyNSBDQTEw
# HhcNMjUwNjA0MDAwMDAwWhcNMzYwOTAzMjM1OTU5WjBjMQswCQYDVQQGEwJVUzEX
# MBUGA1UEChMORGlnaUNlcnQsIEluYy4xOzA5BgNVBAMTMkRpZ2lDZXJ0IFNIQTI1
# NiBSU0E0MDk2IFRpbWVzdGFtcCBSZXNwb25kZXIgMjAyNSAxMIICIjANBgkqhkiG
# 9w0BAQEFAAOCAg8AMIICCgKCAgEA0EasLRLGntDqrmBWsytXum9R/4ZwCgHfyjfM
# GUIwYzKomd8U1nH7C8Dr0cVMF3BsfAFI54um8+dnxk36+jx0Tb+k+87H9WPxNyFP
# JIDZHhAqlUPt281mHrBbZHqRK71Em3/hCGC5KyyneqiZ7syvFXJ9A72wzHpkBaMU
# Ng7MOLxI6E9RaUueHTQKWXymOtRwJXcrcTTPPT2V1D/+cFllESviH8YjoPFvZSjK
# s3SKO1QNUdFd2adw44wDcKgH+JRJE5Qg0NP3yiSyi5MxgU6cehGHr7zou1znOM8o
# dbkqoK+lJ25LCHBSai25CFyD23DZgPfDrJJJK77epTwMP6eKA0kWa3osAe8fcpK4
# 0uhktzUd/Yk0xUvhDU6lvJukx7jphx40DQt82yepyekl4i0r8OEps/FNO4ahfvAk
# 12hE5FVs9HVVWcO5J4dVmVzix4A77p3awLbr89A90/nWGjXMGn7FQhmSlIUDy9Z2
# hSgctaepZTd0ILIUbWuhKuAeNIeWrzHKYueMJtItnj2Q+aTyLLKLM0MheP/9w6Ct
# juuVHJOVoIJ/DtpJRE7Ce7vMRHoRon4CWIvuiNN1Lk9Y+xZ66lazs2kKFSTnnkrT
# 3pXWETTJkhd76CIDBbTRofOsNyEhzZtCGmnQigpFHti58CSmvEyJcAlDVcKacJ+A
# 9/z7eacCAwEAAaOCAZUwggGRMAwGA1UdEwEB/wQCMAAwHQYDVR0OBBYEFOQ7/PIx
# 7f391/ORcWMZUEPPYYzoMB8GA1UdIwQYMBaAFO9vU0rp5AZ8esrikFb2L9RJ7MtO
# MA4GA1UdDwEB/wQEAwIHgDAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDCBlQYIKwYB
# BQUHAQEEgYgwgYUwJAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNv
# bTBdBggrBgEFBQcwAoZRaHR0cDovL2NhY2VydHMuZGlnaWNlcnQuY29tL0RpZ2lD
# ZXJ0VHJ1c3RlZEc0VGltZVN0YW1waW5nUlNBNDA5NlNIQTI1NjIwMjVDQTEuY3J0
# MF8GA1UdHwRYMFYwVKBSoFCGTmh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9EaWdp
# Q2VydFRydXN0ZWRHNFRpbWVTdGFtcGluZ1JTQTQwOTZTSEEyNTYyMDI1Q0ExLmNy
# bDAgBgNVHSAEGTAXMAgGBmeBDAEEAjALBglghkgBhv1sBwEwDQYJKoZIhvcNAQEL
# BQADggIBAGUqrfEcJwS5rmBB7NEIRJ5jQHIh+OT2Ik/bNYulCrVvhREafBYF0RkP
# 2AGr181o2YWPoSHz9iZEN/FPsLSTwVQWo2H62yGBvg7ouCODwrx6ULj6hYKqdT8w
# v2UV+Kbz/3ImZlJ7YXwBD9R0oU62PtgxOao872bOySCILdBghQ/ZLcdC8cbUUO75
# ZSpbh1oipOhcUT8lD8QAGB9lctZTTOJM3pHfKBAEcxQFoHlt2s9sXoxFizTeHihs
# QyfFg5fxUFEp7W42fNBVN4ueLaceRf9Cq9ec1v5iQMWTFQa0xNqItH3CPFTG7aEQ
# JmmrJTV3Qhtfparz+BW60OiMEgV5GWoBy4RVPRwqxv7Mk0Sy4QHs7v9y69NBqycz
# 0BZwhB9WOfOu/CIJnzkQTwtSSpGGhLdjnQ4eBpjtP+XB3pQCtv4E5UCSDag6+iX8
# MmB10nfldPF9SVD7weCC3yXZi/uuhqdwkgVxuiMFzGVFwYbQsiGnoa9F5AaAyBjF
# BtXVLcKtapnMG3VH3EmAp/jsJ3FVF3+d1SVDTmjFjLbNFZUWMXuZyvgLfgyPehwJ
# VxwC+UpX2MSey2ueIu9THFVkT+um1vshETaWyQo8gmBto/m3acaP9QsuLj3FNwFl
# Txq25+T4QwX9xa6ILs84ZPvmpovq90K8eWyG2N01c4IhSOxqt81nMIIGtDCCBJyg
# AwIBAgIQDcesVwX/IZkuQEMiDDpJhjANBgkqhkiG9w0BAQsFADBiMQswCQYDVQQG
# EwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNl
# cnQuY29tMSEwHwYDVQQDExhEaWdpQ2VydCBUcnVzdGVkIFJvb3QgRzQwHhcNMjUw
# NTA3MDAwMDAwWhcNMzgwMTE0MjM1OTU5WjBpMQswCQYDVQQGEwJVUzEXMBUGA1UE
# ChMORGlnaUNlcnQsIEluYy4xQTA/BgNVBAMTOERpZ2lDZXJ0IFRydXN0ZWQgRzQg
# VGltZVN0YW1waW5nIFJTQTQwOTYgU0hBMjU2IDIwMjUgQ0ExMIICIjANBgkqhkiG
# 9w0BAQEFAAOCAg8AMIICCgKCAgEAtHgx0wqYQXK+PEbAHKx126NGaHS0URedTa2N
# DZS1mZaDLFTtQ2oRjzUXMmxCqvkbsDpz4aH+qbxeLho8I6jY3xL1IusLopuW2qft
# JYJaDNs1+JH7Z+QdSKWM06qchUP+AbdJgMQB3h2DZ0Mal5kYp77jYMVQXSZH++0t
# rj6Ao+xh/AS7sQRuQL37QXbDhAktVJMQbzIBHYJBYgzWIjk8eDrYhXDEpKk7RdoX
# 0M980EpLtlrNyHw0Xm+nt5pnYJU3Gmq6bNMI1I7Gb5IBZK4ivbVCiZv7PNBYqHEp
# NVWC2ZQ8BbfnFRQVESYOszFI2Wv82wnJRfN20VRS3hpLgIR4hjzL0hpoYGk81coW
# J+KdPvMvaB0WkE/2qHxJ0ucS638ZxqU14lDnki7CcoKCz6eum5A19WZQHkqUJfdk
# DjHkccpL6uoG8pbF0LJAQQZxst7VvwDDjAmSFTUms+wV/FbWBqi7fTJnjq3hj0Xb
# Qcd8hjj/q8d6ylgxCZSKi17yVp2NL+cnT6Toy+rN+nM8M7LnLqCrO2JP3oW//1sf
# uZDKiDEb1AQ8es9Xr/u6bDTnYCTKIsDq1BtmXUqEG1NqzJKS4kOmxkYp2WyODi7v
# QTCBZtVFJfVZ3j7OgWmnhFr4yUozZtqgPrHRVHhGNKlYzyjlroPxul+bgIspzOwb
# tmsgY1MCAwEAAaOCAV0wggFZMBIGA1UdEwEB/wQIMAYBAf8CAQAwHQYDVR0OBBYE
# FO9vU0rp5AZ8esrikFb2L9RJ7MtOMB8GA1UdIwQYMBaAFOzX44LScV1kTN8uZz/n
# upiuHA9PMA4GA1UdDwEB/wQEAwIBhjATBgNVHSUEDDAKBggrBgEFBQcDCDB3Bggr
# BgEFBQcBAQRrMGkwJAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNv
# bTBBBggrBgEFBQcwAoY1aHR0cDovL2NhY2VydHMuZGlnaWNlcnQuY29tL0RpZ2lD
# ZXJ0VHJ1c3RlZFJvb3RHNC5jcnQwQwYDVR0fBDwwOjA4oDagNIYyaHR0cDovL2Ny
# bDMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZFJvb3RHNC5jcmwwIAYDVR0g
# BBkwFzAIBgZngQwBBAIwCwYJYIZIAYb9bAcBMA0GCSqGSIb3DQEBCwUAA4ICAQAX
# zvsWgBz+Bz0RdnEwvb4LyLU0pn/N0IfFiBowf0/Dm1wGc/Do7oVMY2mhXZXjDNJQ
# a8j00DNqhCT3t+s8G0iP5kvN2n7Jd2E4/iEIUBO41P5F448rSYJ59Ib61eoalhnd
# 6ywFLerycvZTAz40y8S4F3/a+Z1jEMK/DMm/axFSgoR8n6c3nuZB9BfBwAQYK9FH
# aoq2e26MHvVY9gCDA/JYsq7pGdogP8HRtrYfctSLANEBfHU16r3J05qX3kId+ZOc
# zgj5kjatVB+NdADVZKON/gnZruMvNYY2o1f4MXRJDMdTSlOLh0HCn2cQLwQCqjFb
# qrXuvTPSegOOzr4EWj7PtspIHBldNE2K9i697cvaiIo2p61Ed2p8xMJb82Yosn0z
# 4y25xUbI7GIN/TpVfHIqQ6Ku/qjTY6hc3hsXMrS+U0yy+GWqAXam4ToWd2UQ1KYT
# 70kZjE4YtL8Pbzg0c1ugMZyZZd/BdHLiRu7hAWE6bTEm4XYRkA6Tl4KSFLFk43es
# aUeqGkH/wyW4N7OigizwJWeukcyIPbAvjSabnf7+Pu0VrFgoiovRDiyx3zEdmcif
# /sYQsfch28bZeUz2rtY/9TCA6TD8dC3JE3rYkrhLULy7Dc90G6e8BlqmyIjlgp2+
# VqsS9/wQD7yFylIz0scmbKvFoW2jNrbM1pD2T7m3XDCCBY0wggR1oAMCAQICEA6b
# GI750C3n79tQ4ghAGFowDQYJKoZIhvcNAQEMBQAwZTELMAkGA1UEBhMCVVMxFTAT
# BgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTEk
# MCIGA1UEAxMbRGlnaUNlcnQgQXNzdXJlZCBJRCBSb290IENBMB4XDTIyMDgwMTAw
# MDAwMFoXDTMxMTEwOTIzNTk1OVowYjELMAkGA1UEBhMCVVMxFTATBgNVBAoTDERp
# Z2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTEhMB8GA1UEAxMY
# RGlnaUNlcnQgVHJ1c3RlZCBSb290IEc0MIICIjANBgkqhkiG9w0BAQEFAAOCAg8A
# MIICCgKCAgEAv+aQc2jeu+RdSjwwIjBpM+zCpyUuySE98orYWcLhKac9WKt2ms2u
# exuEDcQwH/MbpDgW61bGl20dq7J58soR0uRf1gU8Ug9SH8aeFaV+vp+pVxZZVXKv
# aJNwwrK6dZlqczKU0RBEEC7fgvMHhOZ0O21x4i0MG+4g1ckgHWMpLc7sXk7Ik/gh
# YZs06wXGXuxbGrzryc/NrDRAX7F6Zu53yEioZldXn1RYjgwrt0+nMNlW7sp7XeOt
# yU9e5TXnMcvak17cjo+A2raRmECQecN4x7axxLVqGDgDEI3Y1DekLgV9iPWCPhCR
# cKtVgkEy19sEcypukQF8IUzUvK4bA3VdeGbZOjFEmjNAvwjXWkmkwuapoGfdpCe8
# oU85tRFYF/ckXEaPZPfBaYh2mHY9WV1CdoeJl2l6SPDgohIbZpp0yt5LHucOY67m
# 1O+SkjqePdwA5EUlibaaRBkrfsCUtNJhbesz2cXfSwQAzH0clcOP9yGyshG3u3/y
# 1YxwLEFgqrFjGESVGnZifvaAsPvoZKYz0YkH4b235kOkGLimdwHhD5QMIR2yVCkl
# iWzlDlJRR3S+Jqy2QXXeeqxfjT/JvNNBERJb5RBQ6zHFynIWIgnffEx1P2PsIV/E
# IFFrb7GrhotPwtZFX50g/KEexcCPorF+CiaZ9eRpL5gdLfXZqbId5RsCAwEAAaOC
# ATowggE2MA8GA1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYEFOzX44LScV1kTN8uZz/n
# upiuHA9PMB8GA1UdIwQYMBaAFEXroq/0ksuCMS1Ri6enIZ3zbcgPMA4GA1UdDwEB
# /wQEAwIBhjB5BggrBgEFBQcBAQRtMGswJAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3Nw
# LmRpZ2ljZXJ0LmNvbTBDBggrBgEFBQcwAoY3aHR0cDovL2NhY2VydHMuZGlnaWNl
# cnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElEUm9vdENBLmNydDBFBgNVHR8EPjA8MDqg
# OKA2hjRodHRwOi8vY3JsMy5kaWdpY2VydC5jb20vRGlnaUNlcnRBc3N1cmVkSURS
# b290Q0EuY3JsMBEGA1UdIAQKMAgwBgYEVR0gADANBgkqhkiG9w0BAQwFAAOCAQEA
# cKC/Q1xV5zhfoKN0Gz22Ftf3v1cHvZqsoYcs7IVeqRq7IviHGmlUIu2kiHdtvRoU
# 9BNKei8ttzjv9P+Aufih9/Jy3iS8UgPITtAq3votVs/59PesMHqai7Je1M/RQ0Sb
# QyHrlnKhSLSZy51PpwYDE3cnRNTnf+hZqPC/Lwum6fI0POz3A8eHqNJMQBk1Rmpp
# VLC4oVaO7KTVPeix3P0c2PR3WlxUjG/voVA9/HYJaISfb8rbII01YBwCA8sgsKxY
# oA5AY8WYIsGyWfVVa88nq2x2zm8jLfR+cWojayL/ErhULSd+2DrZ8LaHlv1b0Vys
# GMNNn3O3AamfV6peKOK5lDGCA3wwggN4AgEBMH0waTELMAkGA1UEBhMCVVMxFzAV
# BgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMUEwPwYDVQQDEzhEaWdpQ2VydCBUcnVzdGVk
# IEc0IFRpbWVTdGFtcGluZyBSU0E0MDk2IFNIQTI1NiAyMDI1IENBMQIQCoDvGEuN
# 8QWC0cR2p5V0aDANBglghkgBZQMEAgEFAKCB0TAaBgkqhkiG9w0BCQMxDQYLKoZI
# hvcNAQkQAQQwHAYJKoZIhvcNAQkFMQ8XDTI2MDgwNTE1MzAwNlowKwYLKoZIhvcN
# AQkQAgwxHDAaMBgwFgQU3WIwrIYKLTBr2jixaHlSMAf7QX4wLwYJKoZIhvcNAQkE
# MSIEIGvxo3su5PK0A6tjlp+HdGAYRbzbdbw65qHePJI9mkbeMDcGCyqGSIb3DQEJ
# EAIvMSgwJjAkMCIEIEqgP6Is11yExVyTj4KOZ2ucrsqzP+NtJpqjNPFGEQozMA0G
# CSqGSIb3DQEBAQUABIICALn5TvxcT1gkcz7NprYvxqyh9Tibtl6dI3fNmBOMmmVd
# P30+DH1qalpEMGKOQfz8q+0KmGXYI0JOIFm3RAWhFyGXYzQ/c1aOvNI57mW3T2yp
# tnamUpgPFDyQHl28/hMuEqBIXgk3VGFEGC1CaCNxRQ3cPhqLS9hsBy/8nyRHAMU8
# 0cURdSa8aNHNBHApt/uSIgrnLAZtfvc92lAta3OaLkX22qd4nEO8It1Sml00A8SJ
# p3haalGyUrpK4oXZvExdSpElc7gJpjSN6NKUyeh8wzSJ7sFuTHtU2v9woNWNqCZa
# 8ee/jmXWuDSEAitAakLwRDIhF9YMR4n44QEdwXYLoX+iXMJ2ltO1nz5TwTnVGlS/
# 17v6AlPJFVBJbsCkdPDLivt37jNlXJ7QG0hzvOqUzLI/1Tz5fUXEeMwYKMSZSJgu
# oK8LK4RlHTPiKJxcovbqayf9PGAE3z792V5/oN8Ozxr0HyZ6/RkolZiuYpDlV/E+
# xZw0E4CjD47OibUqRMOvpoQq6nbfl1nmAOoepKCiRTu/nXMZTxhbLoyifFsDC3ym
# STmH/PjQUnBmXTYHsvtlD85IwF/q/4AxNRUgxyHaeP4Tg39Iu8ur4hooNTaKbjB3
# Pdx7v9T2kBgOWzCseDHHkAgQjdvMjrVqL3OFO28mO7QnueTrm9nHHETA19QSmSLu
# SIG # End signature block
