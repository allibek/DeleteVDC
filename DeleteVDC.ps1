Import-Module VMware.PowerCLI
Add-Type -AssemblyName System.Windows.Forms
get-module VMware.VimAutomation.Cloud | Import-Module

$BackupServersArray = ('vbr-stand', 'test2', 'test3')
$PathToBackup = 'C:\Backup\'

########################  Functions #############################################
function BackupServerButtonClick{
    if ($BackupServerDropDown.SelectedItem) {
        $BackupServerButton.Enabled = $false
	    $BackupServerDropDown.Enabled = $false
        $Global:VdcServer = $BackupServerDropDown.SelectedItem.ToString()
        #write-host $Global:vdc_server
	    Disconnect-VBRServer
	    Connect-VBRServer -Server $Global:VdcServer
        $Global:OrganizationVdc = Find-VBRvCloudEntity -OrganizationVdc
        # write-host $OrganizationVdc
	    $OrganizationVdcDropDown.Items.AddRange($Global:OrganizationVdc.Path)
	    $Form.Controls.Add($OrganizationVdcDropDown)
	    $Form.Controls.Add($OrganizationVdcButton)
	}
}

function OrganizationVdcButtonClick{
    if ($OrganizationVdcDropDown.SelectedItem) {
        $OrganizationVdcButton.Enabled = $false
        $OrganizationVdcDropDown.Enabled = $false
        $Global:VdcToBackupPath = $OrganizationVdcDropDown.SelectedItem.ToString()
	    $Form.Controls.Add($RunButton)
	}	
}

function RunButtonClick{ 
    $RunButton.Enabled = $false
    $oReturn=[System.Windows.Forms.MessageBox]::Show("Wanna to continue?","Are you shure?",[System.Windows.Forms.MessageBoxButtons]::YesNo)	
    switch ($oReturn){
	    'Yes' {
            $Global:VdcToBackup = $Global:OrganizationVdc.where({$_.Path -eq $Global:VdcToBackupPath})
            $Session = Start-VBRZip -Folder $PathToBackup -Entity $Global:VdcToBackup -Compression 4 -DisableQuiesce -RunAsync -AutoDelete In3Months
            Write-Host $Session.ID
            while (!$(Get-VBRSession -Id $Session.ID).Result) {
                Start-Sleep -s 15
                Write-Host $(Get-VBRSession -Id $Session.ID).State
            }
	        $result = $(Get-VBRSession -Id $Session.ID).Result
            Write-Host $result
	        if ($result -eq 'Success') {
                Write-Host 'Deleting............'
				$CIServer = $Global:VdcToBackupPath.split("\")[0]
				$OrganizationName = $Global:VdcToBackupPath.split("\")[1] 
                $VcdName = $Global:VdcToBackupPath.split("\")[2]  				
                Write-Host $CIServer
                Connect-CIServer -Server $CIServer
				$orgvdc = Get-OrgVdc -Org $OrganizationName -Name $VcdName
				Write-Host 'Remove VMs.....'				
                $orgvdc | Get-CIVM | Stop-CIVM
                $orgvdc | Get-CIVM | Remove-CIVM				
				Write-Host 'Remove Vapps.....'				
                $orgvdc | Get-CIVApp | Stop-CIVApp
                $orgvdc | Get-CIVApp | Remove-CIVApp							
				Write-Host 'Remove networks.....'
                $orgvdc | Get-OrgvdcNetwork | Remove-OrgVdcNetwork 
                Write-Host 'Remove edges....'
                ($orgvdc | get-edgegateway | Get-CIView).delete() 
                Write-Host 'Remove VDC....'
				$orgvdc | Set-OrgVdc -Enabled $false
                $orgvdc | Remove-OrgVdc 
				Write-Host 'THE END'
	        }

	    } 
	    'No' {
		    Write-Host "Canceled"
	    } 
    }	
}

########################  DropDowns #############################################
$BackupServerDropDown = new-object System.Windows.Forms.ComboBox
$BackupServerDropDown.Location = new-object System.Drawing.Size(5,5)
$BackupServerDropDown.Size = new-object System.Drawing.Size(300,30)
$BackupServerDropDown.Items.AddRange($BackupServersArray)

$OrganizationVdcDropDown = new-object System.Windows.Forms.ComboBox
$OrganizationVdcDropDown.Location = new-object System.Drawing.Size(5,35)
$OrganizationVdcDropDown.Size = new-object System.Drawing.Size(300,30)

########################  Buttons #############################################
$BackupServerButton = new-object System.Windows.Forms.Button
$BackupServerButton.Location = new-object System.Drawing.Size(310,5)
$BackupServerButton.Size = new-object System.Drawing.Size(70,20)
$BackupServerButton.Text = 'Ok'
$BackupServerButton.Add_Click({BackupServerButtonClick})

$OrganizationVdcButton = new-object System.Windows.Forms.Button
$OrganizationVdcButton.Location = new-object System.Drawing.Size(310,35)
$OrganizationVdcButton.Size = new-object System.Drawing.Size(70,20)
$OrganizationVdcButton.Text = 'Ok'
$OrganizationVdcButton.Add_Click({OrganizationVdcButtonClick})

$RunButton = new-object System.Windows.Forms.Button
$RunButton.Location = new-object System.Drawing.Size(140,75)
$RunButton.Size = new-object System.Drawing.Size(70,20)
$RunButton.Text = 'Run'
$RunButton.Add_Click({RunButtonClick})

$Form = New-Object System.Windows.Forms.Form
$Form.width = 410
$Form.height = 150
$Form.FormBorderStyle = 'Fixed3D'
$Form.MaximizeBox = $false
$Form.Text = 'DeleteVDC'
$Form.Controls.Add($BackupServerDropDown)
$Form.Controls.Add($BackupServerButton)
$Form.Add_Shown({$Form.Activate()})
$Form.ShowDialog()
