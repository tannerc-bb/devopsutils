# The contents of this file should be placed in your PowerShell profile file.
# This can be done by running `notepad $PROFILE` and adding the contents of this file to the end of the file.

function fullhistory {
    param(
        [string]$SearchTerm
    )

    if ($SearchTerm) {
        Get-Content (Get-PSReadlineOption).HistorySavePath | Select-String -Pattern $SearchTerm
    } else {
        Get-Content (Get-PSReadlineOption).HistorySavePath
    }
}
