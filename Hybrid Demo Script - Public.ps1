# Script Variables Required

# VMC values
$oauth = "" # example: 8a109942-75a9-4bbc-a58c-e2190ae9ccde
$org = "" # example: 1f522z5-6221-b57d-c12d-g356bffd3fcb
$sddc = "" # example: f652e10e-6381-497d-911c-f26c8bacafcb

# ----- Validation Section
    Write-host "[SECTION] Validating Correct PowerShell Modules have been installed" -ForegroundColor Yellow
    
    # Check to see if AWSPowerShell has been installed
    if (get-module -ListAvailable | where-object {$_.name -eq "AWSPowerShell"}) {
        Import-Module AWSPowerShell
        $mod = get-module AWSPowerShell
        write-host "    - [SUCCESS] " -ForegroundColor Green -nonewline
        write-host "Imported " -ForegroundColor Yellow -nonewline
        write-host "`'AWSPowerShell`' " -ForegroundColor Green -nonewline
        write-host "Module Version: " -ForegroundColor Yellow -nonewline
        write-host "`'$($mod.Version)`'" -ForegroundColor Green

        # If it's not installed, throw an error
    } else {
        write-error "AWSPowerShell Module not found. Please open PowerShell as Administrator and run 'install-module AWSPowerShell -Force -Confirm:$false' and then re-run this script"
    } #Endif

    # Check to see if PowerCLI has been installed
    if (get-module -ListAvailable | where-object {$_.name -eq "VMware.Powercli"}){
        Import-Module VMware.VimAutomation.Core
        $mod = get-module VMware.VimAutomation.Core
        write-host "    - [SUCCESS] " -ForegroundColor Green -nonewline
        write-host "Imported " -ForegroundColor Yellow -nonewline
        write-host "`'PowerCLI`' " -ForegroundColor Green -nonewline
        write-host "Module Version: " -ForegroundColor Yellow -nonewline
        write-host "`'$($mod.Version)`'" -ForegroundColor Green

        # If it's not installed, throw an error
    } else {
        write-error "PowerCLI Module not found. Please open PowerShell as Administrator and run 'install-module VMware.PowerCLI -Force -Confirm:$false' and then re-run this script"
    
    } #Endif


    Write-host "
[SECTION] Checking AWS Credentials" -ForegroundColor Yellow

    # Check to see if AWS Credentials have been configured on this machine already
    # If more than one profile shows up
    if ((Get-AWSCredential -ListProfileDetail).count -ge 1) {

        Write-host "    - [ALERT] More than one AWS Profile exists on this machine. Choosing the first profile" -ForegroundColor Yellow
        # Get the profiles and select the first profile
        $listprofiles = Get-AWSCredential -ListProfileDetail | select-object -First 1
        
        # Get the selected profile
        $prof = Get-AWSCredentials $listprofiles.profilename

        Write-host "    - [INFO] Initializing AWS Default Configuration from profile " -NoNewline -ForegroundColor Yellow
        Write-host "`'$($listprofiles.profilename)`'" -ForegroundColor Green

        # Initialize the AWS Settings 
        Initialize-AWSDefaultConfiguration -ProfileName $listprofiles.profilename
        
        # Bring back the access Key for the profile
        $credentials = $prof.GetCredentials()

        write-host "    - [INFO] Using AWSProfile " -nonewline -ForegroundColor Yellow
        write-host "`'$($listprofiles.ProfileName)`'" -NoNewline -ForegroundColor Green
        write-host " with AccessKey: " -nonewline -ForegroundColor Yellow
        write-host "`'$($credentials.AccessKey)`'" -ForegroundColor Green
        #$AccessKey = $credentials.AccessKey
        #$SecretKey = $credentials.SecretKey

    } else {Write-Error "No AWS Profile has been setup on this machine. run 'Set-AWSCredential -AccessKey ExampleAccessKey -SecretKey EXAMPLEKEY -StoreAs profilename' "}

    Write-host "    - [INFO] Checking for default AWS region in profile settings" -ForegroundColor Yellow

    # If there is no default region
    if (!(Get-DefaultAWSRegion)){
        Write-host "    - [INPUT REQUIRED] No default AWS Region has been set. Here are the available Regions to choose from: " -ForegroundColor Yellow

        # Show all available regions
        foreach ($region in (Get-AWSRegion)) {
            write-host $region -ForegroundColor Green
        }
        
        # Keep doing the following until it's validated correctly
        do {

            # Require user to input their desired region
            $AWSRegion = read-host -Prompt "Please type the name of the region exactly as it appears above and hit enter to continue"
            
            # Validate the input
            $testRegion = get-AWSRegion $AWSRegion
        }
        # Validation String
        until ($testRegion.Name -ne "Unknown")

        # Set the region
        Set-DefaultAWSRegion -Region $AWSRegion
        Write-host "    - [INFO] The default region has been set to " -nonewline -ForegroundColor Yellow
        write-host "`'$AWSRegion`'" -ForegroundColor Green
    } else {

        # Set the default AWS Region to a variable
        $AWSRegion = Get-DefaultAWSRegion
        Write-host "    - [INFO] The default region being used is " -nonewline -ForegroundColor Yellow
        write-host "`'$AWSRegion`'" -ForegroundColor Green
    }

Write-Host "
[SECTION] Checking VMware Cloud on AWS Information" -ForegroundColor Yellow 
Write-Host "    - [INFO] Retrieving Access Token for VMC" -ForegroundColor Yellow

# oauth validation
if ($oauth -eq $Null){
    Write-host "    - [INPUT REQUIRED] No VMC OAUTH Token Entered. Please enter your token. 
        To generate a token or find your current token, go to: " -ForegroundColor Yellow
    Write-host "        'https://console.cloud.vmware.com/csp/gateway/portal/#/user/tokens' " -ForegroundColor Green    

    # Keep asking for the oath token until it is successful
    do {
        # Require input from user until OAUTH is successful
        $oauth = read-host -Prompt "Please paste your oauth token here (do not add parentheses or quotation marks)"
        
        # Create the parameters string
        $params = @{refresh_token="$oauth"}

        # REST Command for getting the access token
        $connection = Invoke-WebRequest -Uri 'https://console.cloud.vmware.com/csp/gateway/am/api/auth/api-tokens/authorize' -Body $params -Method Post

        # Pull access key from REST body
        $accesskey = ($connection.content | Convertfrom-json).access_token
    }
    # Do the above until this is successful
    until ($connection.statuscode -eq "200")
} else { 
        # Create the parameters string
        $params = @{refresh_token="$oauth"}

        # REST Command for getting the access token
        $connection = Invoke-WebRequest -Uri 'https://console.cloud.vmware.com/csp/gateway/am/api/auth/api-tokens/authorize' -Body $params -Method Post

        # Pull access key from REST body
        $accesskey = ($connection.content | Convertfrom-json).access_token

        # If the status is not successful
        if ($connection.statuscode -ne "200"){

            Write-host "    - [INPUT REQUIRED] There appears to be an issue with the token you've provided. Please re-enter your token. 
            To generate a token or find your current token, go to: " -ForegroundColor Yellow
        Write-host "        'https://console.cloud.vmware.com/csp/gateway/portal/#/user/tokens' " -ForegroundColor Green    
        
        
        do {
            Write-Host "    - [ALERT] Something went wrong. Please re-enter your oauth token." -ForegroundColor Yellow
            
            # Require input from user until OAUTH is successful
            $oauth = read-host -Prompt "Please paste your oauth token here (do not add parentheses or quotation marks)"
            
            # Create the parameters string
            $params = @{refresh_token="$oauth"}
            
            # REST Command for getting the access token
            $connection = Invoke-WebRequest -Uri 'https://console.cloud.vmware.com/csp/gateway/am/api/auth/api-tokens/authorize' -Body $params -Method Post
            
            # Pull access key from REST body
            $accesskey = ($connection.content | Convertfrom-json).access_token
        }

        # Do the above until this is successful
        until ($connection.statuscode -eq "200") 
        }

}
    Write-Host "    - [SUCCESS] " -NoNewline -ForegroundColor Green
    write-host "Access Token Retrieved" -ForegroundColor Yellow


# Parameters for AWS Linking REST Call
$params = @{org="$org";sddc="$sddc"}

# REST Call for AWS Linking info
$sddcInfo = Invoke-WebRequest -Uri "https://vmc.vmware.com/vmc/api/orgs/$org/account-link/sddc-connections" -headers @{"csp-auth-token"="$accesskey"} -Method Get -body $params -ContentType "application/json" | ConvertFrom-Json

# If nothing is returned, something went wrong
if ($connection -eq $null) {
    Write-Error "Something went wrong retrieving your SDDC Information. Please ensure the correct organization ID and SDDC ID are used and try again"

} else {
    # If it returned, throw a success
    Write-Host "    - [SUCCESS] " -noNewLine -foregroundcolor green
    Write-Host "SDDC Information Retrieved" -ForegroundColor Yellow
}

# Save pertinent SDDC info 
$mysddc = $sddcInfo | where-object {$_.sddc_id -eq "$sddc"}

Write-host "    - [INFO] Grabbing Information on Connected VPC" -ForegroundColor Yellow

# Created VPCINFO Object
$VPCproperties = [ordered]@{
    'VPC_ID'=$mysddc.vpc_id;
    'SUBNET_ID'=$mysddc.subnet_id;
    'SUBNET_AZ'=$mysddc.subnet_availability_zone;
    'VPC_CIDR'=$mysddc.cidr_block_vpc;
    'CIDR_SUBNET'=$mysddc.cidr_block_subnet;
    'DEFAULT_ROUTE_TABLE'=$mysddc.default_route_table;
}
$VPCINFO = New-Object –TypeName PSObject –Prop $VPCproperties

# If the object is not created, there is an error
if (!($VPCINFO)) {
    Write-Error "Cannot retrieve VPC Information. Make Sure your SDDC is Linked to an AWS Account"
} else {
    # If successful, post message
    Write-Host "    - [SUCCESS] SDDC is Connected to: " -ForegroundColor Yellow -NoNewline
    Write-Host "`'$($mysddc.vpc_id)`'" -ForegroundColor Green
    Write-Host "    - [SUCCESS] SDDC is in: " -ForegroundColor Yellow -NoNewline
    Write-Host "`'$($mysddc.subnet_availability_zone)`'" -ForegroundColor Green
}

# GET AWS INFORMATION
Write-Host "
[SECTION] AWS VPC AND SUBNET VERIFICATION" -ForegroundColor Yellow
Write-Host "    - [INFO] Connecting to AWS and Verifying VPC Information" -ForegroundColor Yellow

# Save the Default Security Group
$AWSDefaultSecurityGroup = (Get-EC2SecurityGroup | where-object {$_.vpcId -eq $mysddc.vpc_id -and $_.groupname -eq "Default"} )

Write-Host "    - [SUCCESS] " -NoNewline -ForegroundColor Green
Write-Host "Required AWS Information Validated" -ForegroundColor Yellow

# Create RDS Instance

# RDS Variables
$DBName = "vmcrds" # <-Change values for your environment
$DBInstanceIdentifier = "VMC-Automated-Demo" # <-Change values for your environment
$SecurityGroupID = $AWSDefaultSecurityGroup.groupid
$allocatedStorageGB = '5' # <-Change values for your environment
$InstanceClass = 'db.m1.small' # <-Change values for your environment
$MasterUsername = 'vmcadmin' # <-Change values for your environment
$MasterPass = 'VMware1!' # <-Change values for your environment
$Engine = 'mysql' # <-Change values for your environment

Write-Host "
[SECTION] RELATIONAL DATABASE SERVICE (RDS)" -ForegroundColor Yellow
Write-Host "    - [INFO] Validate RDS Subnet Group for " -NoNewline -ForegroundColor Yellow
Write-Host "`'$($mysddc.vpc_id)`'" -ForegroundColor Green

# Save the RDS Subnet Group for the VPC
$RDSDBSubnetGroup = Get-RDSDBSubnetGroup | where-object {$_.VpcID -eq $mysddc.vpc_id -and $_.dbsubnetGroupName -like "*default*"}

# Save the RDS Subnet Group Name 
$RDSDBSubnetGroupName = $RDSDBSubnetGroup.DBSubnetGroupName

Write-Host "    - [SUCCESS] " -NoNewline -ForegroundColor Green
Write-Host "RDS Subnet Group Validated" -ForegroundColor Yellow

Write-host "    - [INFO] Creating RDS Database " -NoNewline -ForegroundColor Yellow
Write-Host "$DBInstanceIdentifier " -NoNewline -ForegroundColor Green
Write-host "in " -NoNewline -ForegroundColor Yellow
Write-Host "`'$AWSSubnetAZ`'" -ForegroundColor Green

# Create the new Database
$newDB = New-RDSDBInstance `
    -AllocatedStorage $allocatedStorageGB `
    -AvailabilityZone $AWSSubnetAZ `
    -DBInstanceClass $InstanceClass `
    -DBInstanceIdentifier $DBInstanceIdentifier `
    -DBName $DBName `
    -MasterUsername $MasterUsername `
    -MasterUserPassword $MasterPass `
    -PubliclyAccessible $false `
    -engine $Engine `
    -VpcSecurityGroupId "$($AWSDefaultSecurityGroup.groupid)" `
    -DBSubnetGroupName $RDSDBSubnetGroupName

    Write-host "    - [INFO] RDS Database Provisioning Started" -ForegroundColor yellow 
    
    # Find the RDS Database and save to variable
    $currentrun = Get-RDSDBInstance | where-object {$_.DBInstanceIdentifier -eq $DBInstanceIdentifier} | select-object DBInstanceIdentifier, DBInstanceStatus

Write-Host "
[SECTION] VMC VM DEPLOY" -ForegroundColor Yellow

    # Connect to vCenter
    Write-Host "    - [INFO] Connecting to VMC vCenter Server" -ForegroundColor Yellow

    # Parameters for AWS Linking REST Call
    
    # REST Call for AWS Linking info
    $vCInfo = Invoke-WebRequest -Uri "https://vmc.vmware.com/vmc/api/orgs/$org/sddcs/$sddc" -headers @{"csp-auth-token"="$accesskey"} -Method Get -ContentType "application/json" | ConvertFrom-Json
    
    $cleansevcaddress = ($vCinfo.resource_config.vc_url).replace("https://","")
    
    $VcAddress = $cleansevcaddress.replace("/","")
    $VcUser = $VcInfo.resource_config.cloud_username
    $VcPass = $VcInfo.resource_config.cloud_password

    # vCenter Connection
    $vmcconnection = Connect-VIServer -Server $VcAddress -Protocol https -User $VcUser -Password $VcPass
    
    # If connection is successful, continue
    if ($vmcconnection.IsConnected -eq "True"){
    Write-Host "    - [SUCCESS] " -NoNewline -ForegroundColor Green
    Write-Host "Connection to vCenter Succeeded" -ForegroundColor Yellow
    } else {
        # Otherwise, throw an error
        Write-Error "Could not connect to VMC vCenter."
    }

    $cisserver = Connect-CISServer $VcAddress -User $VcUser -Password $VcPass
    
    # Connect to the content library service
    $contentLibaryService = Get-CisService com.vmware.content.library
    
    # Save the Content Library IDs
    $libraryIDs = $contentLibaryService.list()

    # Empty array to be used in a sec
    $results = @()

    # Foreach Content Library ID
    foreach($libraryID in $libraryIDs) {

        # Get the Content Library
        $library = $contentLibaryService.get($libraryID)

        # Create each content library as a custom object
        $libraryResult = [pscustomobject] @{
            Name = $library.Name;
            Type = $library.Type;
            Description = $library.Description;
            Id = $library.Id
        }
        # Only save the the CL if it meets the below requirements (if we've already created this one)
        if ($libraryResult.Type -eq "SUBSCRIBED" -and $libraryResult.Name -eq "VMC-DEMO-CL"){ # <-Change values for your environment
        
        # Add the content library to the results
        $results+=$libraryResult
        }
    }

    # Once Content Library is added or verified, Deploy a VM
    # Deploy a VM from Content Library that is ready to connect
    $VMName = "Lychee-Automated-Demo"
    Write-Host "    - [INFO] Deploying " -NoNewline -ForegroundColor Yellow
    Write-Host "`'$VMName`'" -ForegroundColor Green

    # Get the Content Library Item from the correct content library
    $clitems = Get-ContentLibraryItem -Name "Lychee-Demo.ovf" | where-object {$_.contentLibrary.name -eq "VMC-DEMO-CL"} # <-Change values for your environment

    # Create the VM in the resource pool
    $VM = New-VM -ContentLibraryItem $clitems -Name $VMname -ResourcePool (get-resourcepool "Compute-ResourcePool") -Location (get-folder "workloads")
    
    
    $VM | Start-VM -Confirm:$false | Out-Null

    write-host "    - [INFO] Waiting for VMware Tools to run on " -nonewline -foregroundcolor yellow
    write-host "`'$VMName`'" -ForegroundColor Green
    do {
        $currentVM = Get-VM $VMName
        start-sleep -seconds 5
    } until (((get-VM $VMName).ExtensionData.guest.ToolsRunningStatus -eq "guestToolsRunning"))

    Write-Host "    - [INFO] VMware tools is running" -ForegroundColor Yellow

    # Get VM Network Portgroup
    Write-Host "    - [INFO] Retrieving VM Network PortGroup" -ForegroundColor Yellow
    $CurrentVMPortGroup = Get-VM $VMName | Get-VirtualPortGroup 
    Write-Host "    - [INFO] VM Running on " -NoNewline -ForegroundColor Yellow
    write-host "`'$($CurrentVMPortGroup.Name)`' " -NoNewline -ForegroundColor Green
    Write-Host "PortGroup" -ForegroundColor Yellow

    # Get VM IP Address 
    Write-Host "    - [INFO] Retrieving VM IP Address" -ForegroundColor Yellow
    $CurrentVmIp = $currentVM.ExtensionData.Guest.IpAddress
    Write-Host "    - [INFO] VM IP is " -NoNewline -ForegroundColor Yellow
    write-host "`'$CurrentVmIp`' " -ForegroundColor Green

    # Create Application Load Balancer
    Write-Host "    - [INFO] Creating Application Load Balancer " -ForegroundColor Yellow
    $httpListener = New-Object Amazon.ElasticLoadBalancing.Model.Listener
    $httpListener.Protocol = "http"
    $httpListener.LoadBalancerPort = 80
    $httpListener.InstanceProtocol = "http"
    $httpListener.InstancePort = 80
    $SG = Get-EC2SecurityGroup | where-object {$_.VpcId -eq $mysddc.vpc_id -and $_.GroupName -eq "Default"}
    
    $subnets = @()
    foreach ($subnet in (Get-EC2Subnet | where-object {$_.vpcid -eq $mysddc.vpc_id})){
        $subnets += $subnet.SubnetId
    }

    # Create the Load Balancer. It'll take time for it to become active
    $alb = New-ELB2LoadBalancer -IpAddressType ipv4 -Name "VMC-Automated-DEMO-ALB" -Scheme internet-facing -SecurityGroup $SG.groupId -Subnet $subnets # <-Change values for your environment
    

    # Create Target Group with IP of VM
    Write-Host "    - [INFO] Creating Target Group for Load Balancer" -ForegroundColor Yellow

    # Create the target group with settings for web server
    $NewELB2TargetGroup = New-ELB2TargetGroup  -HealthCheckProtocol HTTP -Name "TG-VMC-DEMO-RDS" -Port 80 -Protocol HTTP -TargetType ip -VpcId $mysddc.vpc_id # <-Change values for your environment
    
    # Save Target Group to Variable
    $TG = Get-ELB2TargetGroup -Name "TG-VMC-DEMO-RDS" # <-Change values for your environment

    # Create the target spec
    $target1 = New-object Amazon.ElasticLoadBalancingV2.Model.TargetDescription

    # Add AZ to Target Spec
    $target1.AvailabilityZone = "all"

    # Add IP address of web VM
    $target1.Id = "$CurrentVmIp"

    # Add port of web VM
    $target1.Port = '80'

    # Register the target to the Load Balancer
    start-sleep -Seconds 20
    
    $ELB2Target = Register-ELB2Target -TargetGroupArn $TG.TargetGroupArn -Target $target1

    # Check to see if Load Balancer is ready
    do {
        $ALB1 = Get-ELB2LoadBalancer | where-object {$_.LoadBalancerName -eq $alb.LoadBalancerName}
        start-sleep -Seconds 5
    } until (
        $ALB1.state.code.value -eq "Active"
    )

    Write-Host "    - [INFO] Applying Target Group to Load Balancer" -ForegroundColor Yellow

    # Create the action spec
    $defaultactions = new-object Amazon.ElasticLoadBalancingV2.Model.Action

    #Add the Target's ARN
    $defaultactions.TargetGroupArn = $TG.TargetGroupArn

    # Forward target calls
    $defaultactions.Type = "forward"

    # Create the Listener on the Load Balancer with the above rule
    $NewELB2Listener = New-ELB2Listener -LoadBalancerArn $alb1.LoadBalancerArn -DefaultAction $defaultactions -Port 80 -Protocol HTTP
    

    # CHECK STATUS OF LONGER TASKS
    Write-Host "    - [INFO] Waiting for RDS Database Provisioning to complete. This can 5-10 minutes" -ForegroundColor Yellow
    
    # RDS INSTANCE
    
    do {
        # Get the RDS Instance we are deploying
        $currentrun = Get-RDSDBInstance | where-object {$_.DBInstanceIdentifier -eq $DBInstanceIdentifier} | select-object DBInstanceIdentifier, DBInstanceStatus 

        # Check the status. If the status has changed since the last run (10 seconds) put it on screen
        if ($currentrun.DBInstanceSTatus -ne $previousrun.DBInstanceStatus -and $currentrun.DBInstanceSTatus -ne "Available") {
            write-host ""
            $currentrun | select-object DBInstanceIdentifier, DBInstanceStatus
        } else {
            # Otherwise just add a '.' every 10 seconds the status is the same
            write-host "." -NoNewline
        }
        # Update the previous run variable
        $previousrun = $currentrun

        # Wait 10 seconds
        start-sleep -seconds 10

} until (Get-RDSDBInstance | where-object {$_.DBInstanceIdentifier -eq $DBInstanceIdentifier -and $_.DBInstanceStatus -eq "Available"})
    write-host ""
    Start-Sleep -Seconds 3

    # Save the instance to variable
    $RDSDB = Get-RDSDBInstance | where-object {$_.DBInstanceIdentifier -eq $DBInstanceIdentifier}
    
    # Display DB Information
    Get-RDSDBInstance | where-object {$_.DBInstanceIdentifier -eq $DBInstanceIdentifier} | select-object DBName, DBInstanceStatus, DBInstanceClass, AvailabilityZone, PubliclyAccessible,Engine,VPCSecurityGroups,allocate

    Write-Host "    - [SUCCESS] " -NoNewline -ForegroundColor Green
    Write-Host "RDS Database Provisioning Completed" -ForegroundColor Yellow

    # return Database connection details/credentials
    Write-Host "    - [INFO] Returning Database Details and Credentials" -ForegroundColor Yellow
    Write-Host "***NOTE: THE FOLLOWING SENSITIVE DATA IS ONLY SHOWN BECAUSE THIS IS A DEMO***" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Application Load Balancer Address: " -NoNewline -ForegroundColor Yellow
    Write-Host "$($ALB1.DNSName)" -ForegroundColor Green
    Write-Host ""
    Write-Host "Database Hostname: " -NoNewline -ForegroundColor Yellow
    Write-Host "$($RDSDB.Endpoint.Address)" -ForegroundColor Green
    Write-Host "Database Username: " -NoNewline -ForegroundColor Yellow
    Write-Host "$($RDSDB.MasterUsername)" -ForegroundColor Green
    Write-Host "Database Password: " -NoNewline -ForegroundColor Yellow
    Write-Host "$MasterPass" -ForegroundColor Green
    Write-Host "Database Name: " -NoNewline -ForegroundColor Yellow
    Write-Host "$($RDSDB.DBName)" -ForegroundColor Green
    Write-Host ""
    Write-Host "Front-end VM Name: " -NoNewline -ForegroundColor Yellow
    Write-Host "$VMName" -ForegroundColor Green
    Write-Host "Front-End VM Internal IP: " -NoNewline -ForegroundColor Yellow
    Write-Host "$CurrentVmIp" -ForegroundColor Green
    Write-Host "Front-end VM Username: " -NoNewline -ForegroundColor Yellow
    Write-Host "vmware" -ForegroundColor Green
    Write-Host "Front-end VM Password: " -NoNewline -ForegroundColor Yellow
    Write-Host "VMw@re123" -ForegroundColor Green
    Write-Host ""

    Write-Host "
[SECTION] VMC and AWS NETWORKING" -ForegroundColor Yellow

    # Configure Security Group
    Write-Host "    - [INFO] Checking for MYSQL Rules in Security Group" -ForegroundColor Yellow
    #Used up top --- $AWSDefaultSecurityGroup = (Get-EC2SecurityGroup | where-object {$_.vpcId -eq $mysddc.vpc_id -and $_.groupname -eq "Default"} )
     
    if (!($AWSDefaultSecurityGroup.IpPermissions.FromPort -eq "3306")){
        write-host "No SQL Port Exists"
        $IPRange = "$currentVMIP" + "/24"
        $SGIPSubnet = $currentvmip -replace "(?<=\.)[^.]*$","0"
        $SGCIDR = "$SGIPSubnet" + "/24"
        Grant-EC2SecurityGroupIngress -GroupId $AWSDefaultSecurityGroup.GroupId -IpPermission  @{IpProtocol = "tcp"; FromPort = 3306; ToPort = 3306; IpRanges = @("$SGCIDR")}
    }else {
        write-host "SQL Port Exists. Ensuring it's open to the VM Subnet"
        $ok = $AWSDefaultSecurityGroup.IpPermission | where {$_.fromport -eq "3306"}
        if ($ok.ipranges.count -gt 1){
            $SGIPSubnet = $currentvmip -replace "(?<=\.)[^.]*$","0"
            $SGCIDR = "$SGIPSubnet" + "/24"
            if ($ok.ipranges -eq $SGCIDR) {
                Write-Host "Security Group Already Contains a Rule for Port 3306 and $SGCIDR"
            } else {
                Write-Host "No rule is set for Port 3306 for $SGCIDR. Adding Now" -ForegroundColor Yellow
                Grant-EC2SecurityGroupIngress -GroupId $AWSDefaultSecurityGroup.GroupId -IpPermission  @{IpProtocol = "tcp"; FromPort = 3306; ToPort = 3306; IpRanges = @("$SGCIDR")}

            }
        }
    }

