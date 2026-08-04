
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

                    $ttl = $matches[1]
                    $formattedTTL = Convert-TimeToReadableFormat $ttl  

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
            Write-JITEvent -Type Error -ID 2002 -Message $logMessage
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
# MIItjQYJKoZIhvcNAQcCoIItfjCCLXoCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDzZEUBFkw+j7tq
# 0xarjXEjCjxDBepTN2t/xmPHVmSBlqCCEtUwggXJMIIEsaADAgECAhAbtY8lKt8j
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
# ghoOMIIaCgIBATBqMFYxCzAJBgNVBAYTAlBMMSEwHwYDVQQKExhBc3NlY28gRGF0
# YSBTeXN0ZW1zIFMuQS4xJDAiBgNVBAMTG0NlcnR1bSBDb2RlIFNpZ25pbmcgMjAy
# MSBDQQIQNdjgcrVvnE2sr1R1KUYcCzANBglghkgBZQMEAgEFAKB8MBAGCisGAQQB
# gjcCAQwxAjAAMBkGCSqGSIb3DQEJAzEMBgorBgEEAYI3AgEEMBwGCisGAQQBgjcC
# AQsxDjAMBgorBgEEAYI3AgEVMC8GCSqGSIb3DQEJBDEiBCDa6Cx5n1hs8bU6OU/E
# eQZgooGnxHXtsmywNrrJ/zIErzANBgkqhkiG9w0BAQEFAASCAYCPxoCSik9exxpn
# XisrWCbdhO7fv4Cx9NDZX9R0k+lqm8ZadQ0EHHN7j9btvUJvFbrZyJkj7KEoNLom
# 1ZxK/dJeFLGzs/VyksIlUR6aZbfUThhew9UHvESDPK9VSt5wYlZW2Eyu/l/L97Ps
# D9OQ/u6jGQK8cQEzHq/HOvu64fnkvwRpPYfB+k+rtVDGJQg0cpsRWjlteqwTMFT4
# XnQTHC+j6kLMfiMiswad3HawO4nx4q6SfrSEDaTRqTReQY8vlLOu7Yz1OVmJbhpR
# oTBLImZ1n/arcqGGYG8b9ADS8hqYw/ZgQYm2RUHp9L/2VV758lLjghyIMqQS6Igw
# MRnEBYe2v9EfnVj37DgU0VrraUviwL+Lq0l5suI/7J+B4Flt1/ZlLlf07qKV48BV
# BjDfQC6e9htLlQIw92L7HSMD/Jhtxp0UJ/jfUs/P9dBSoHjiU2sojYySKomaCtGi
# kFXGgnjZk+api7gKFddkXRnLT7mOzhaercq/ploWvdI0jjjiNgKhghd3MIIXcwYK
# KwYBBAGCNwMDATGCF2MwghdfBgkqhkiG9w0BBwKgghdQMIIXTAIBAzEPMA0GCWCG
# SAFlAwQCAQUAMHgGCyqGSIb3DQEJEAEEoGkEZzBlAgEBBglghkgBhv1sBwEwMTAN
# BglghkgBZQMEAgEFAAQgGO6aylIsK5jtzmAOKYVnkskQJQ3oWZTciTA2MfS0LYgC
# EQDKUzm48tmLGWuMnmMzu+vUGA8yMDI2MDgwNDEyNTUzNFqgghM6MIIG7TCCBNWg
# AwIBAgIQCoDvGEuN8QWC0cR2p5V0aDANBgkqhkiG9w0BAQsFADBpMQswCQYDVQQG
# EwJVUzEXMBUGA1UEChMORGlnaUNlcnQsIEluYy4xQTA/BgNVBAMTOERpZ2lDZXJ0
# IFRydXN0ZWQgRzQgVGltZVN0YW1waW5nIFJTQTQwOTYgU0hBMjU2IDIwMjUgQ0Ex
# MB4XDTI1MDYwNDAwMDAwMFoXDTM2MDkwMzIzNTk1OVowYzELMAkGA1UEBhMCVVMx
# FzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMTswOQYDVQQDEzJEaWdpQ2VydCBTSEEy
# NTYgUlNBNDA5NiBUaW1lc3RhbXAgUmVzcG9uZGVyIDIwMjUgMTCCAiIwDQYJKoZI
# hvcNAQEBBQADggIPADCCAgoCggIBANBGrC0Sxp7Q6q5gVrMrV7pvUf+GcAoB38o3
# zBlCMGMyqJnfFNZx+wvA69HFTBdwbHwBSOeLpvPnZ8ZN+vo8dE2/pPvOx/Vj8Tch
# TySA2R4QKpVD7dvNZh6wW2R6kSu9RJt/4QhguSssp3qome7MrxVyfQO9sMx6ZAWj
# FDYOzDi8SOhPUWlLnh00Cll8pjrUcCV3K3E0zz09ldQ//nBZZREr4h/GI6Dxb2Uo
# yrN0ijtUDVHRXdmncOOMA3CoB/iUSROUINDT98oksouTMYFOnHoRh6+86Ltc5zjP
# KHW5KqCvpSduSwhwUmotuQhcg9tw2YD3w6ySSSu+3qU8DD+nigNJFmt6LAHvH3KS
# uNLoZLc1Hf2JNMVL4Q1OpbybpMe46YceNA0LfNsnqcnpJeItK/DhKbPxTTuGoX7w
# JNdoRORVbPR1VVnDuSeHVZlc4seAO+6d2sC26/PQPdP51ho1zBp+xUIZkpSFA8vW
# doUoHLWnqWU3dCCyFG1roSrgHjSHlq8xymLnjCbSLZ49kPmk8iyyizNDIXj//cOg
# rY7rlRyTlaCCfw7aSUROwnu7zER6EaJ+AliL7ojTdS5PWPsWeupWs7NpChUk555K
# 096V1hE0yZIXe+giAwW00aHzrDchIc2bQhpp0IoKRR7YufAkprxMiXAJQ1XCmnCf
# gPf8+3mnAgMBAAGjggGVMIIBkTAMBgNVHRMBAf8EAjAAMB0GA1UdDgQWBBTkO/zy
# Me39/dfzkXFjGVBDz2GM6DAfBgNVHSMEGDAWgBTvb1NK6eQGfHrK4pBW9i/USezL
# TjAOBgNVHQ8BAf8EBAMCB4AwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwgwgZUGCCsG
# AQUFBwEBBIGIMIGFMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdpY2VydC5j
# b20wXQYIKwYBBQUHMAKGUWh0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNvbS9EaWdp
# Q2VydFRydXN0ZWRHNFRpbWVTdGFtcGluZ1JTQTQwOTZTSEEyNTYyMDI1Q0ExLmNy
# dDBfBgNVHR8EWDBWMFSgUqBQhk5odHRwOi8vY3JsMy5kaWdpY2VydC5jb20vRGln
# aUNlcnRUcnVzdGVkRzRUaW1lU3RhbXBpbmdSU0E0MDk2U0hBMjU2MjAyNUNBMS5j
# cmwwIAYDVR0gBBkwFzAIBgZngQwBBAIwCwYJYIZIAYb9bAcBMA0GCSqGSIb3DQEB
# CwUAA4ICAQBlKq3xHCcEua5gQezRCESeY0ByIfjk9iJP2zWLpQq1b4URGnwWBdEZ
# D9gBq9fNaNmFj6Eh8/YmRDfxT7C0k8FUFqNh+tshgb4O6Lgjg8K8elC4+oWCqnU/
# ML9lFfim8/9yJmZSe2F8AQ/UdKFOtj7YMTmqPO9mzskgiC3QYIUP2S3HQvHG1FDu
# +WUqW4daIqToXFE/JQ/EABgfZXLWU0ziTN6R3ygQBHMUBaB5bdrPbF6MRYs03h4o
# bEMnxYOX8VBRKe1uNnzQVTeLni2nHkX/QqvXnNb+YkDFkxUGtMTaiLR9wjxUxu2h
# ECZpqyU1d0IbX6Wq8/gVutDojBIFeRlqAcuEVT0cKsb+zJNEsuEB7O7/cuvTQasn
# M9AWcIQfVjnzrvwiCZ85EE8LUkqRhoS3Y50OHgaY7T/lwd6UArb+BOVAkg2oOvol
# /DJgddJ35XTxfUlQ+8Hggt8l2Yv7roancJIFcbojBcxlRcGG0LIhp6GvReQGgMgY
# xQbV1S3CrWqZzBt1R9xJgKf47CdxVRd/ndUlQ05oxYy2zRWVFjF7mcr4C34Mj3oc
# CVccAvlKV9jEnstrniLvUxxVZE/rptb7IRE2lskKPIJgbaP5t2nGj/ULLi49xTcB
# ZU8atufk+EMF/cWuiC7POGT75qaL6vdCvHlshtjdNXOCIUjsarfNZzCCBrQwggSc
# oAMCAQICEA3HrFcF/yGZLkBDIgw6SYYwDQYJKoZIhvcNAQELBQAwYjELMAkGA1UE
# BhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2lj
# ZXJ0LmNvbTEhMB8GA1UEAxMYRGlnaUNlcnQgVHJ1c3RlZCBSb290IEc0MB4XDTI1
# MDUwNzAwMDAwMFoXDTM4MDExNDIzNTk1OVowaTELMAkGA1UEBhMCVVMxFzAVBgNV
# BAoTDkRpZ2lDZXJ0LCBJbmMuMUEwPwYDVQQDEzhEaWdpQ2VydCBUcnVzdGVkIEc0
# IFRpbWVTdGFtcGluZyBSU0E0MDk2IFNIQTI1NiAyMDI1IENBMTCCAiIwDQYJKoZI
# hvcNAQEBBQADggIPADCCAgoCggIBALR4MdMKmEFyvjxGwBysddujRmh0tFEXnU2t
# jQ2UtZmWgyxU7UNqEY81FzJsQqr5G7A6c+Gh/qm8Xi4aPCOo2N8S9SLrC6Kbltqn
# 7SWCWgzbNfiR+2fkHUiljNOqnIVD/gG3SYDEAd4dg2dDGpeZGKe+42DFUF0mR/vt
# La4+gKPsYfwEu7EEbkC9+0F2w4QJLVSTEG8yAR2CQWIM1iI5PHg62IVwxKSpO0Xa
# F9DPfNBKS7Zazch8NF5vp7eaZ2CVNxpqumzTCNSOxm+SAWSuIr21Qomb+zzQWKhx
# KTVVgtmUPAW35xUUFREmDrMxSNlr/NsJyUXzdtFUUt4aS4CEeIY8y9IaaGBpPNXK
# FifinT7zL2gdFpBP9qh8SdLnEut/GcalNeJQ55IuwnKCgs+nrpuQNfVmUB5KlCX3
# ZA4x5HHKS+rqBvKWxdCyQEEGcbLe1b8Aw4wJkhU1JrPsFfxW1gaou30yZ46t4Y9F
# 20HHfIY4/6vHespYMQmUiote8ladjS/nJ0+k6MvqzfpzPDOy5y6gqztiT96Fv/9b
# H7mQyogxG9QEPHrPV6/7umw052AkyiLA6tQbZl1KhBtTasySkuJDpsZGKdlsjg4u
# 70EwgWbVRSX1Wd4+zoFpp4Ra+MlKM2baoD6x0VR4RjSpWM8o5a6D8bpfm4CLKczs
# G7ZrIGNTAgMBAAGjggFdMIIBWTASBgNVHRMBAf8ECDAGAQH/AgEAMB0GA1UdDgQW
# BBTvb1NK6eQGfHrK4pBW9i/USezLTjAfBgNVHSMEGDAWgBTs1+OC0nFdZEzfLmc/
# 57qYrhwPTzAOBgNVHQ8BAf8EBAMCAYYwEwYDVR0lBAwwCgYIKwYBBQUHAwgwdwYI
# KwYBBQUHAQEEazBpMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdpY2VydC5j
# b20wQQYIKwYBBQUHMAKGNWh0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNvbS9EaWdp
# Q2VydFRydXN0ZWRSb290RzQuY3J0MEMGA1UdHwQ8MDowOKA2oDSGMmh0dHA6Ly9j
# cmwzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFRydXN0ZWRSb290RzQuY3JsMCAGA1Ud
# IAQZMBcwCAYGZ4EMAQQCMAsGCWCGSAGG/WwHATANBgkqhkiG9w0BAQsFAAOCAgEA
# F877FoAc/gc9EXZxML2+C8i1NKZ/zdCHxYgaMH9Pw5tcBnPw6O6FTGNpoV2V4wzS
# UGvI9NAzaoQk97frPBtIj+ZLzdp+yXdhOP4hCFATuNT+ReOPK0mCefSG+tXqGpYZ
# 3essBS3q8nL2UwM+NMvEuBd/2vmdYxDCvwzJv2sRUoKEfJ+nN57mQfQXwcAEGCvR
# R2qKtntujB71WPYAgwPyWLKu6RnaID/B0ba2H3LUiwDRAXx1Neq9ydOal95CHfmT
# nM4I+ZI2rVQfjXQA1WSjjf4J2a7jLzWGNqNX+DF0SQzHU0pTi4dBwp9nEC8EAqox
# W6q17r0z0noDjs6+BFo+z7bKSBwZXTRNivYuve3L2oiKNqetRHdqfMTCW/NmKLJ9
# M+MtucVGyOxiDf06VXxyKkOirv6o02OoXN4bFzK0vlNMsvhlqgF2puE6FndlENSm
# E+9JGYxOGLS/D284NHNboDGcmWXfwXRy4kbu4QFhOm0xJuF2EZAOk5eCkhSxZON3
# rGlHqhpB/8MluDezooIs8CVnrpHMiD2wL40mm53+/j7tFaxYKIqL0Q4ssd8xHZnI
# n/7GELH3IdvG2XlM9q7WP/UwgOkw/HQtyRN62JK4S1C8uw3PdBunvAZapsiI5YKd
# vlarEvf8EA+8hcpSM9LHJmyrxaFtoza2zNaQ9k+5t1wwggWNMIIEdaADAgECAhAO
# mxiO+dAt5+/bUOIIQBhaMA0GCSqGSIb3DQEBDAUAMGUxCzAJBgNVBAYTAlVTMRUw
# EwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20x
# JDAiBgNVBAMTG0RpZ2lDZXJ0IEFzc3VyZWQgSUQgUm9vdCBDQTAeFw0yMjA4MDEw
# MDAwMDBaFw0zMTExMDkyMzU5NTlaMGIxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxE
# aWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xITAfBgNVBAMT
# GERpZ2lDZXJ0IFRydXN0ZWQgUm9vdCBHNDCCAiIwDQYJKoZIhvcNAQEBBQADggIP
# ADCCAgoCggIBAL/mkHNo3rvkXUo8MCIwaTPswqclLskhPfKK2FnC4SmnPVirdprN
# rnsbhA3EMB/zG6Q4FutWxpdtHauyefLKEdLkX9YFPFIPUh/GnhWlfr6fqVcWWVVy
# r2iTcMKyunWZanMylNEQRBAu34LzB4TmdDttceItDBvuINXJIB1jKS3O7F5OyJP4
# IWGbNOsFxl7sWxq868nPzaw0QF+xembud8hIqGZXV59UWI4MK7dPpzDZVu7Ke13j
# rclPXuU15zHL2pNe3I6PgNq2kZhAkHnDeMe2scS1ahg4AxCN2NQ3pC4FfYj1gj4Q
# kXCrVYJBMtfbBHMqbpEBfCFM1LyuGwN1XXhm2ToxRJozQL8I11pJpMLmqaBn3aQn
# vKFPObURWBf3JFxGj2T3wWmIdph2PVldQnaHiZdpekjw4KISG2aadMreSx7nDmOu
# 5tTvkpI6nj3cAORFJYm2mkQZK37AlLTSYW3rM9nF30sEAMx9HJXDj/chsrIRt7t/
# 8tWMcCxBYKqxYxhElRp2Yn72gLD76GSmM9GJB+G9t+ZDpBi4pncB4Q+UDCEdslQp
# JYls5Q5SUUd0viastkF13nqsX40/ybzTQRESW+UQUOsxxcpyFiIJ33xMdT9j7CFf
# xCBRa2+xq4aLT8LWRV+dIPyhHsXAj6KxfgommfXkaS+YHS312amyHeUbAgMBAAGj
# ggE6MIIBNjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBTs1+OC0nFdZEzfLmc/
# 57qYrhwPTzAfBgNVHSMEGDAWgBRF66Kv9JLLgjEtUYunpyGd823IDzAOBgNVHQ8B
# Af8EBAMCAYYweQYIKwYBBQUHAQEEbTBrMCQGCCsGAQUFBzABhhhodHRwOi8vb2Nz
# cC5kaWdpY2VydC5jb20wQwYIKwYBBQUHMAKGN2h0dHA6Ly9jYWNlcnRzLmRpZ2lj
# ZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RDQS5jcnQwRQYDVR0fBD4wPDA6
# oDigNoY0aHR0cDovL2NybDMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElE
# Um9vdENBLmNybDARBgNVHSAECjAIMAYGBFUdIAAwDQYJKoZIhvcNAQEMBQADggEB
# AHCgv0NcVec4X6CjdBs9thbX979XB72arKGHLOyFXqkauyL4hxppVCLtpIh3bb0a
# FPQTSnovLbc47/T/gLn4offyct4kvFIDyE7QKt76LVbP+fT3rDB6mouyXtTP0UNE
# m0Mh65ZyoUi0mcudT6cGAxN3J0TU53/oWajwvy8LpunyNDzs9wPHh6jSTEAZNUZq
# aVSwuKFWjuyk1T3osdz9HNj0d1pcVIxv76FQPfx2CWiEn2/K2yCNNWAcAgPLILCs
# WKAOQGPFmCLBsln1VWvPJ6tsds5vIy30fnFqI2si/xK4VC0nftg62fC2h5b9W9Fc
# rBjDTZ9ztwGpn1eqXijiuZQxggN8MIIDeAIBATB9MGkxCzAJBgNVBAYTAlVTMRcw
# FQYDVQQKEw5EaWdpQ2VydCwgSW5jLjFBMD8GA1UEAxM4RGlnaUNlcnQgVHJ1c3Rl
# ZCBHNCBUaW1lU3RhbXBpbmcgUlNBNDA5NiBTSEEyNTYgMjAyNSBDQTECEAqA7xhL
# jfEFgtHEdqeVdGgwDQYJYIZIAWUDBAIBBQCggdEwGgYJKoZIhvcNAQkDMQ0GCyqG
# SIb3DQEJEAEEMBwGCSqGSIb3DQEJBTEPFw0yNjA4MDQxMjU1MzRaMCsGCyqGSIb3
# DQEJEAIMMRwwGjAYMBYEFN1iMKyGCi0wa9o4sWh5UjAH+0F+MC8GCSqGSIb3DQEJ
# BDEiBCB1PxHqXwzdlIRgT0A3Gfzyxhn3YNJJKmn/njQnXjtalzA3BgsqhkiG9w0B
# CRACLzEoMCYwJDAiBCBKoD+iLNdchMVck4+CjmdrnK7Ksz/jbSaaozTxRhEKMzAN
# BgkqhkiG9w0BAQEFAASCAgC7msP77JIcSkDwZzz6HSXKv9uDJnLYd+B40Xc9y7Aa
# wwyyNi6sQl2Kdi1F+f/ZHfZVGET8CyJ6T7tvcHwfSFDTfCEow2cREcTv4aFRzDyW
# IfWN/VwYK+3by5R75JhsMCqiNgFaV4u2CL3mDv0LLTfsBnF43D2yKPPSqSEYc10J
# 9CHYNSHyzkG5wzp00CvCnM3aCPzksJJW1x5oCkwc8V4LZsCAE0Q+JlyigAji3nts
# uX+ZtC/TxulKAnk83ZYVVC5pegkErSv51Pqor+9OlzMYkxvXgje2ylapuK8K71jL
# uydxIUllMVR4Xw+y0NSzPmnzmAA6cfPttFuaJaxzYIMS0lCaxXzdv2UDmvV3IFNd
# lSAZB99qW407ouDUieM4Tquauqp3WbFZyS56cbxIAfuW0fpoOUDrobBh5rTS3oIp
# EN9ThPMw3dz3jp2Hn42ABVtweUsM0b8/FfhDVxaSILrUl+0bGiw5ztNwQgKS/KOM
# AiNf3C8hMdN4S3kSgPxn2RoGoKYGSouIfhTdZ1K4v89r3EMguXZRrvhqraFxNaS2
# lnZ14L4ds2396rzGBwVKCoMAMtldNQuBo9fo956X+kAiTkl1Ok/BfKnab/qEqBP+
# samp7OVs+cZgqD6+VcopxSBcf/c204Y8/Jj54rLU3/pfRjGKJLgpaErecnCKONdh
# tw==
# SIG # End signature block
