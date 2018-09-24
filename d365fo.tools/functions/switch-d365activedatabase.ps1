﻿<#
.SYNOPSIS
Switches the 2 databases. The Old wil be renamed _original

.DESCRIPTION
Switches the 2 databases. The Old wil be renamed _original

.PARAMETER DatabaseServer
The database server where the switch should occur

.PARAMETER DatabaseName
The name of the database to be switched

.PARAMETER SqlUser
User with access to alter both databases

.PARAMETER SqlPwd
Password for the SqlUser

.PARAMETER NewDatabaseName
The database that takes the DatabaseName's place

.EXAMPLE
Switch-D365ActiveDatabase -NewDatabaseName "GoldenConfig"

.NOTES
General notes
#>
function Switch-D365ActiveDatabase {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, Position = 1)]
        [string]$DatabaseServer = $Script:DatabaseServer,

        [Parameter(Mandatory = $false, Position = 2)]
        [string]$DatabaseName = $Script:DatabaseName,

        [Parameter(Mandatory = $false, Position = 3)]
        [string]$SqlUser = $Script:DatabaseUserName,

        [Parameter(Mandatory = $false, Position = 4)]
        [string]$SqlPwd = $Script:DatabaseUserPassword,
        
        [Parameter(Mandatory = $true, Position = 5)]
        [string]$NewDatabaseName
    )

    $UseTrustedConnection = Test-TrustedConnection $PSBoundParameters

    $SqlParams = @{ DatabaseServer = $DatabaseServer; DatabaseName = "Master";
        SqlUser = $SqlUser; SqlPwd = $SqlPwd 
    }

    $SqlCommand = Get-SqlCommand @SqlParams -TrustedConnection $UseTrustedConnection

    $SqlCommand.CommandText = "SELECT COUNT(1) FROM $NewDatabaseName.dbo.USERINFO WHERE ID = 'Admin'"


    try {
        $sqlCommand.Connection.Open()
        $null = $sqlCommand.ExecuteScalar()
    }
    catch {
        Write-PSFMessage -Level Host -Message "It seems that the new database either doesn't exists, isn't a valid AxDB database or your don't have enough permissions." -Exception $PSItem.Exception
        Stop-PSFFunction -Message "Stopping because of errors"
        return
    }
    finally {
        if ($sqlCommand.Connection.State -ne [System.Data.ConnectionState]::Closed) {
            $sqlCommand.Connection.Close()    
        }
    }
    
    $commandText = (Get-Content "$script:ModuleRoot\internal\sql\switch-database.sql") -join [Environment]::NewLine
    
    $sqlCommand.CommandText = $commandText

    $null = $sqlCommand.Parameters.AddWithValue("@OrigName", $DatabaseName)
    $null = $sqlCommand.Parameters.AddWithValue("@NewName", $NewDatabaseName)

    try {
        $sqlCommand.Connection.Open()

        $null = $sqlCommand.ExecuteNonQuery()    
    }
    catch {
        Write-PSFMessage -Level Host -Message "Something went wrong while working against the DB" -Exception $PSItem.Exception
        Stop-PSFFunction -Message "Stopping because of errors"
        return
    }
    finally {
        if ($sqlCommand.Connection.State -ne [System.Data.ConnectionState]::Closed) {
            $sqlCommand.Connection.Close()    
        }
        
        $sqlCommand.Dispose()
    }
    
    [PSCustomObject]@{
        OldDatabaseNewName = "$DatabaseName`_original"
    }
}