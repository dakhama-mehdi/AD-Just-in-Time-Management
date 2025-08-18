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
    .\ADJIT_v1.0.1.ps1 

.NOTES
    Author: Dakhama Mehdi
    Helped : Thirrey Barcelo - Florian Burnel
    Version: 1.0.1
    Date: 08/2025
#>

Add-Type -AssemblyName PresentationFramework

$BackgroundColor = "#34495e"

[xml]$XAML = @"
<Window 
xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:d="http://schemas.microsoft.com/expression/blend/2008"
        xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
        Title="AD-JIT Management" Background="#f1f1f1" Height="450" Width="450" WindowStartupLocation="CenterScreen" >
    
    <Grid Margin="0,-30,0,7.4" HorizontalAlignment="Left" Width="490">
        <Grid.RowDefinitions>
            <RowDefinition Height="273*"/>
            <RowDefinition Height="220*"/>
        </Grid.RowDefinitions>
        <Grid.ColumnDefinitions>
            <ColumnDefinition Width="254*"/>
            <ColumnDefinition Width="63*"/>
            <ColumnDefinition Width="17*"/>
            <ColumnDefinition Width="160*"/>
        </Grid.ColumnDefinitions>

    <Menu Name="mainMenu" HorizontalAlignment="Left" Background="$BackgroundColor" Height="33" Margin="0,29,0,0" VerticalAlignment="Top" Width="443" Grid.ColumnSpan="4">
    <MenuItem Header="" Width="Auto"/> <!-- Espace flexible -->
    <MenuItem Header="File" Foreground="White" FontSize="15" >
        <MenuItem Name="menuOpen" Header="Open" Foreground="White" Background="$BackgroundColor"/>
        <Separator/>
        <MenuItem Name="menuExit" Header="Exit" Foreground="White" Background="$BackgroundColor"/>
    </MenuItem>
    <MenuItem Name="menuAbout" Header="About" Foreground="White" FontSize="15"/>
    </Menu>


        <TextBox Name="txtGroup" HorizontalAlignment="Left" Height="25" Margin="26,147,0,0" TextWrapping="Wrap" VerticalAlignment="Top" Width="268" Grid.ColumnSpan="2"/>
        <TextBox Name="txtUser" HorizontalAlignment="Left" Height="25" Margin="26,96,0,0" TextWrapping="Wrap" VerticalAlignment="Top" Width="268" Grid.ColumnSpan="2"/>
        
        <Button Name="btnSelectUser" Content="Select User" HorizontalAlignment="Left" Margin="0.8,96,0,0" VerticalAlignment="Top" Width="86" Grid.Column="3" Height="24"/>
        <Button Name="btnSelectGroup" Content="Select Group" HorizontalAlignment="Left" Margin="0.8,149,0,0" VerticalAlignment="Top" Width="86" Grid.Column="3" Height="23"/>
        
        <RichTextBox Name="richTextBox" IsReadOnly="True" HorizontalAlignment="Left" Height="126" Margin="25,10.2,0,0" 
        VerticalAlignment="Top" Width="393" Grid.ColumnSpan="4" Grid.Row="1"
         VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto">
            <FlowDocument/>
        </RichTextBox>

                   
        <Button Name="btnShowTTL" Style="{DynamicResource ButtonStyle}" Content="Show TTL" Foreground="White" Background="#34495e" HorizontalAlignment="Left" Margin="27,156.2,0,0" VerticalAlignment="Top" Width="100" Grid.Row="1" Height="25"/>
        <Button Name="btnShowGroup" Content="Show group" Foreground="White" Background="#34495e" HorizontalAlignment="Left" Margin="177,156.2,0,0" VerticalAlignment="Top" Width="100" Grid.ColumnSpan="2" Grid.Row="1" Height="25"/>
        <Button Name="btnAddUser" Content="Add user" Foreground="White" Background="#34495e" HorizontalAlignment="Left" Margin="5.6,156.2,0,0" VerticalAlignment="Top" Width="100" Grid.Column="2" Grid.Row="1" Height="25" Grid.ColumnSpan="2"/>

        <DatePicker Name="datePicker" HorizontalAlignment="Left" Margin="27,199,0,0" VerticalAlignment="Top" Width="267" Grid.ColumnSpan="2" Height="25"/>
        
        <TextBox Name="txtDuration" Grid.Column="3" HorizontalAlignment="Left" Height="21" Margin="1.8,198,0,0" TextWrapping="Wrap" Text="0" VerticalAlignment="Top" Width="35"/>
        <Button Name="btnIncreaseDuration" Content="+" Grid.Column="3" HorizontalAlignment="Left" Margin="43.8,197,0,0" VerticalAlignment="Top" Width="19" Height="21"/>
        <Button Name="btnDecreaseDuration" Content="-" Grid.Column="3" HorizontalAlignment="Left" Margin="67.8,197,0,0" VerticalAlignment="Top" Width="19" Height="21"/>
        
        <Label Content="Duration by Days" HorizontalAlignment="Left" Height="29" Margin="27,173,0,0" VerticalAlignment="Top" Width="267" FontWeight="Bold" Grid.ColumnSpan="2"/>
        <Label Content="Enter Group Name" HorizontalAlignment="Left" Height="29" Margin="25,121,0,0" VerticalAlignment="Top" Width="134" FontWeight="Bold"/>
        <Label Content="Enter Username" HorizontalAlignment="Left" Height="29" Margin="25,67,0,0" VerticalAlignment="Top" Width="109" FontWeight="Bold"/>
        <Label Content="Minutes" HorizontalAlignment="Left" Height="29" Margin="16.6,172,0,0" VerticalAlignment="Top" Width="56"  Grid.ColumnSpan="2" Grid.Column="2"/>


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
	$global:selectedUser = $null # Reset before show
	foreach ($user in $UserList)
	{
		$lstUsers.Items.Add($user)
	}
	
	$lstUsers.Add_MouseDoubleClick({
			$global:selectedUser = $lstUsers.SelectedItem
			$UserWindow.DialogResult = $true # Confirm selection
			$UserWindow.Close()
		})
	
	# Show new window selection
	$UserWindow.WindowStartupLocation = "Manual"
	$UserWindow.Left = $Window.Left + ($Window.Width - $UserWindow.Width) / 2
	$UserWindow.Top = $Window.Top + ($Window.Height - $UserWindow.Height) / 2
	$UserWindow.Icon = $Bitmap_Black
	$result = $UserWindow.ShowDialog()
	
	# Check if window if closed empty
	if (-not $result -or $null -eq $global:selectedUser)
	{
		return $null
	}
	
	return $global:selectedUser
}

function Show-AboutWindow {
    [xml]$XAML = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="About" Height="250" Width="300" WindowStartupLocation="CenterScreen">
    <Grid Background="White">
        <StackPanel HorizontalAlignment="Center" VerticalAlignment="Center">
            <TextBlock Text="AD Just-in-Time Management" FontSize="18" FontWeight="Bold" Foreground="Black" TextAlignment="Center"/>
            <TextBlock Text="Version 1.0.1" FontSize="14" Foreground="Gray" TextAlignment="Center" Margin="0,5,0,5"/>
            <TextBlock Text="Developed by Dakhama Mehdi" FontSize="14" Foreground="Black" TextAlignment="Center"/>
            <TextBlock Text="Thanks to IT-Connect.fr" FontSize="14" Foreground="Black" TextAlignment="Center"/>
            <TextBlock Text="© 2025 All rights reserved" FontSize="12" Foreground="Gray" TextAlignment="Center"/>
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

    $AboutWindow.Icon = $Bitmap_Black
    # Afficher la fenêtre
    $AboutWindow.ShowDialog()
}


$reader = (New-Object System.Xml.XmlNodeReader $XAML)
$Window = [Windows.Markup.XamlReader]::Load($reader)

# Load controls bouton
$txtGroup = $Window.FindName("txtGroup")
$txtUser = $Window.FindName("txtUser")
$richTextBox = $Window.FindName("richTextBox")
$datePicker = $Window.FindName("datePicker")
$txtDuration = $Window.FindName("txtDuration")
$btnSelectUser = $Window.FindName("btnSelectUser")
$btnSelectGroup = $Window.FindName("btnSelectGroup")
$btnShowTTL = $Window.FindName("btnShowTTL")
$btnAddUser = $Window.FindName("btnAddUser")
$btnShowGroup = $Window.FindName("btnShowGroup")
$btnIncreaseDuration = $Window.FindName("btnIncreaseDuration")
$btnDecreaseDuration = $Window.FindName("btnDecreaseDuration")

$datePicker.SelectedDate = get-date

#region fonction

    function Get-PAMGroupMembers {
    param (
        [string]$GroupName
    )

    # Initialiser la liste des membres
    $membersWithTTL = @()

    try {
        # Récupérer les informations du groupe
        $group = Get-ADGroup -Identity $GroupName -Property member -ShowMemberTimeToLive -ErrorAction Stop
    }
    catch {
        # Retourner l'erreur sans afficher dans la console PowerShell
        return "Error: $($_.Exception.Message)"
    }

    # Vérifier si le groupe a des membres avant de parcourir
    if ($group -and $group.member) {
        foreach ($member in $group.member) {
            if ($member -match "<TTL=(\d+)>") {
                $ttl = $matches[1]
                $userDN = $member -replace "<TTL=\d+>", ""
                $userDN = $userDN.TrimStart(',')

                try {
                    # Récupérer l'utilisateur sans afficher d'erreur
                    $user = Get-ADUser -Identity $userDN -ErrorAction Stop
                    
                    $ttl = $matches[1]
                    $formattedTTL = Convert-TimeToReadableFormat $ttl  

                    $membersWithTTL += [PSCustomObject]@{
                        UserName = $user.Name
                        TTL      = $formattedTTL
                    }
                }
                catch {
                    # En cas d'erreur sur Get-ADUser, on stocke le message
                    $membersWithTTL += [PSCustomObject]@{
                        UserName = "Unknown User ($userDN)"
                        TTL      = $ttl
                    }
                }
            }
        }
    }

    # Retourner les résultats ou un message si aucun membre trouvé
    if ($membersWithTTL.Count -gt 0) {
    return $membersWithTTL
    } else {
    return "No members found or invalid TTL format."
    }
}
	
	function Convert-TimeToReadableFormat {
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

#endregion fonction

#Icons
[string]$base64_Black=@"
iVBORw0KGgoAAAANSUhEUgAAAQAAAAEACAMAAABrrFhUAAADAFBMVEVHcEykpKSkpKSkpKSkpKSkpKSkpKSkpKSkpKSgpKakpKSkpKSkpKSkpKSkpKRIhqKkpKSkpKSkpKSkpKSkpKSkpKRlszOkpKSkpKSkpKSkpKSkpKSkpKSvuhikpKSkpKSkpKSkpKSkpKSkpKSkpKSkpKTeiACkpKSkpKSkpKSkpKTHtg+kpKSkpKSK0x+kpKRGhqKN1h2FziLsnwDxpgB3wiqkpKSH0CF3wiz8uQDnmQP9ugCJ0iBUpM53wiqFzyKkpKST2xqFziLpmgBQnsY5hqqI0SBgr9zzqQBGl7/qmwD/vgD4sgBzjXVPn8rjjwBfrttHl8DuogCO1h3nlgBNnMNgr9z0rAD3sABImMJvmpU1g6ZVpdBgr91Km8TlpA18mKP+vABkpomTn6QrgxwyhKo1h62T2hotf6QwgqcrfqIxg6iQ2Bw0hquO1h2L0x9yviz/vgBuuy5HmMAvgaYugKVTpM/llAA4irDnlgDkkwB2wipLnMWFzyLdhwBbq9dElb35swBwvS33sQDfigDijgD0rABotTI6i7JPn8romQA3iK7hjABNnsiN1R5Xp9ODzSNerdlZqdU4ia9JmsOS2RuU2xp9yCZBkrrpmgD+vAA7jbNRocx0vyz/vQA9jrX7uABWptL6tgB1wCvsnwD2rgCJ0iDzqQDqnACH0CFtuTDxpwBfr9uAyyVruDB5xCnvpABqtzHuogDijwB7xSg/j7dptjFSos1QoMtVpdFlszRksjVhsN38uQDwpgB8vdd3utTjkQDA7Ez/3QB4wyn0xQBntDOc1O1WocGs3mlxttH8ugDywACo4zNorsu050D/1gCw4GZIlrh1u+D/zQCe3ihfqMf/xgDtrgBrtd1/wuSe11ar3l+LyuiKzUHxuwCGzDV9xTej2WLvtQCV0Op4q5+T0UQ/jaBBj69jsEfDkSKZ1U9KmZGkrG1aqVygi0FPn3uLzFFcqm09iqZamqhejIyKjl7OrDOwizDitSHyuA27rU2Wi0yooVak/yBHABsesp6+AAAA/3RSTlMAHTPvB/xvAfgQsI/izE/8BAv9FyPqgCzeTFiFehA4qcnSQEdo2YChmL3EILb1v1/3fUZAYOiTpJylpINmOGDpkegw6WZDz8MwpIXncPwg56bvUI/HxInXv4X5zFDs3/fQv3nl/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////zOrm8ZTAAAVCElEQVR42uyc3UsbWR/H5y70rld7l78gEFAj8V18Wfsm3bZWW0tf2L3xJrgEIQ+iS5TCAwasT8QkGkrRNk+bpRFFBCu0slilT7Fp0p1JY1KjtkYvnuLFsxRKtxSe35mJMaOT5JzRnsnF+ZzJeOYlTr7f8z0nY5wJxzEYDAaDwWAwGAwGg8FgMBgMBoPBYDAYDAaDwWAwGAwGg8FgMBgMBoPBYDAYDAaDwWAwGAyGHH2JqRJhKtF/v4MYiotEqooLS7yhufycdZ9z5Ze+w0Hqi4x17n2aWuoLRv0VEB2NCkIYIQhR5EHl8ebA0CKKjwSDIUQwGIGluqoCkH+6HKkXws8zCQvIguM7SLERiQ8tyghFCsACA5IvSKKh7QWIQcoLZMHp45O/px61PcQgKC0G3W6jQTv1On0lNH5YbPFoxhCQCgSsMh2HxyBf0ivGPk0kKKWgTrvx8DQMfKJ8mfqUB7AhbLWWH73566TWl6uXQL5ACLTqBs1S+AXrPasSYMExOGAGmVLWFYFtIa0cKBebX7BmR3Sg+UjnFk3uiCi/I4sBHe4QcqBYE/1RMeQ5uCegHUqOpF9q4lwgB+oM2ugXrHlADpzTH01/0O3O50DQbdREfzSffpQBwXr4fKD6elvbKaCtrbE6x0GaOkB/pCMfrhDsVERXvwlPvzgOWK2y04HqtlNPM7lxofGE8kFaOiKQ7g4MQosddXqK8nWGcyAMSz84ELb+nH7m+bYbSDTPxxMi8TiPli+cP3yQk8XY+l2RxSDdCPwM0Y7ewyP63HovNQ5Wo7aPxRMvZCSQBxcOpUBf1xHCyL/kQHDRTTMCJm/0ueDFJSx40cmADsmPxZOi6CS0PSIhLcahJzQe6gBBXP0dHRa6ETjnDYex9Xutz61ePXfiAsgX2z4hxX4PPo5W8gdDYOhwgyhsIjAKUA2AFd8AryB4m6/fCIjyk/zT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
"@

$Bitmap_Black = New-Object System.Windows.Media.Imaging.BitMapImage
$Bitmap_Black.BeginInit()
$Bitmap_Black.StreamSource = [System.IO.MemoryStream][System.Convert]::FromBase64String($base64_Black)
$Bitmap_Black.EndInit()
$Bitmap_Black.Freeze()

# Set images
$Window.Icon = $Bitmap_Black


#region boutton

$btnSelectUser.Add_Click({

    $val = '*' + $txtUser.Text + '*'
    $users = (Get-ADUser -Filter "name -like '$val'").samaccountname

    if ($users.Count -eq 0) {
        $txtUser.Text = "No users found"
        return
    }

    $selectedUser = Show-UserSelection -UserList $users

    # Vérifier si la fenêtre a été fermée sans sélection
    if ($null -eq $selectedUser) {
        Write-Host "No selection made, operation canceled."
        return
    }

    $txtUser.Text = [string]::Join("", @($global:selectedUser))
})

$btnSelectGroup.Add_Click({

    $val = '*' + $txtGroup.Text + '*'
    $Group = (Get-ADGroup -Filter "name -like '$val'").samaccountname

    # Afficher la fenêtre de sélection avec cette liste
    $selectedUser = Show-UserSelection -UserList $Group

    # Mettre à jour le TextBox avec l'utilisateur sélectionné
    if ($selectedUser) {
        $txtGroup.Text =  [string]::Join("", $global:selectedUser) 
    }

})

$btnShowTTL.Add_Click({

    $richTextBox.Document.Blocks.Clear()
	$TTLDate = $datePicker.SelectedDate
	
	# "Check if the selected date is in the future"
	if ($TTLDate -gt (Get-Date))
	{
		# "Calculate the duration in minutes until the specified date"
		$Now = Get-Date
		$TtimeSpan = (New-TimeSpan -End $TTLDate).ToString("dd\:hh\:mm")
        $richTextBox.Foreground = [System.Windows.Media.Brushes]::DarkBlue
		$richTextBox.AppendText("Duration of addition in minutes : $TtimeSpan" + "`r`n")
	}
	else
	{
		$timeadd = $txtDuration.Text
        $richTextBox.Foreground = [System.Windows.Media.Brushes]::Red
		$richtextbox.AppendText("Addition time in minutes : $timeadd" + "`r`n")
	}
})

$btnShowGroup.Add_Click({
    
    $GroupName = $txtGroup.Text
    if (!$GroupName) {
        $richTextBox.Foreground = [System.Windows.Media.Brushes]::Red
        $richTextBox.AppendText("Pls enter a valid groupname `r`n")
        return
    }

    $membersWithTTL = Get-PAMGroupMembers -GroupName $txtGroup.Text

    $richTextBox.Document.Blocks.Clear()

    if ($membersWithTTL -is [array] -and $membersWithTTL.Count -gt 0) {
        foreach ($member in $membersWithTTL) {
            $text = "User: $($member.UserName) TTL : $($member.TTL)"
  $paragraph = New-Object System.Windows.Documents.Paragraph
    $paragraph.Inlines.Add($text)
    $paragraph.Foreground = [System.Windows.Media.Brushes]::DarkBlue

    # Ajouter au FlowDocument du RichTextBox
    $richTextBox.Document.Blocks.Add($paragraph)
        }
    }
    else {
        # Si `$membersWithTTL` est une erreur ou vide, afficher le message
        $richTextBox.AppendText("$membersWithTTL `r`n")
    }
})


$btnAddUser.add_Click({

	$TTLMinutes = $txtDuration.Text
	$UserName = $txtUser.Text
	$GroupName = $txtGroup.Text
	$TTLDays = $datePicker.SelectedDate
	$Now = Get-Date
    
    $richTextBox.Document.Blocks.Clear()

    # Check if the selected date is in the future
    if (!$UserName -or !$GroupName) {
        $richTextBox.Foreground = [System.Windows.Media.Brushes]::Red
        $richTextBox.AppendText("Pls enter a valid username and groupname `r`n")
		return
    }

	if ($TTLDays -gt $Now)
	{
		$TTL = ($TTLDays - $Now).TotalDays
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
        $richTextBox.Foreground = [System.Windows.Media.Brushes]::Red
        $richTextBox.AppendText("Time not be empty, pls select correct date or minutes `r`n")
		return
	}

    try
	{
		# "Add a member to the group with TTL"
		Add-ADGroupMember -Identity $GroupName -Members $UserName -MemberTimeToLive $timeSpan
		$richTextBox.Document.Blocks.Clear()
	    $richTextBox.Foreground = [System.Windows.Media.Brushes]::Green
		$richTextBox.AppendText("User $UserName is temporarily added to the group : $GroupName`r`n Until $var.`r`n")
	}
	catch
	{
		# "Error handling"
		$richTextBox.Document.Blocks.Clear()
        $richTextBox.Selection.ApplyPropertyValue([System.Windows.Documents.TextElement]::ForegroundProperty, "red")
		$errorMessage = "Error to add $UserName to group $GroupName `r`n $_ `r`n"
        $richTextBox.Foreground = [System.Windows.Media.Brushes]::Red
		$richTextBox.AppendText("$errorMessage")
	}

})

$btnIncreaseDuration.Add_Click({
    $value = [int]$txtDuration.Text
    if ($value -lt 999) {
        $txtDuration.Text = ($value + 1).ToString()
    }
})

$btnDecreaseDuration.Add_Click({
    $value = [int]$txtDuration.Text
    if ($value -gt 0) {
        $txtDuration.Text = ($value - 1).ToString()
    }
})

#endregion boutton

$menuAbout = $Window.FindName("menuAbout")
$menuAbout.Add_Click({
    Show-AboutWindow
})

$menuExit = $Window.FindName("menuExit")
$menuExit.Add_Click({
    $Window.Close()  
})

# Load GUI
$Window.ShowDialog() | Out-Null

